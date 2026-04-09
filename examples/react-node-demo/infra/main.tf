terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Resolve VPC and subnets: use provided values or fall back to defaults
  vpc_id     = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids

  # Explicit tags on every resource so the demo shows up under var.project
  # ("obs-demo") in the console, overriding the root default_tags which carry
  # the root project name ("aws-observability-dashboard").
  common_tags = {
    Project     = var.project
    Environment = var.environment
  }

  tracing_service_name = "${local.name_prefix}-backend"

  cwagent_config_content = jsonencode({
    traces = {
      traces_collected = {
        application_signals = {}
      }
    }
    logs = {
      metrics_collected = {
        application_signals = {}
      }
    }
  })

  otel_resource_attributes = join(",", compact([
    "service.name=${local.tracing_service_name}",
    "deployment.environment=${var.environment}",
    "aws.log.group.names=${aws_cloudwatch_log_group.backend.name}",
  ]))

  backend_container_environment = concat([
    { name = "NODE_ENV", value = var.environment },
    { name = "PORT", value = "4000" },
    ], var.enable_tracing ? [
    { name = "OTEL_RESOURCE_ATTRIBUTES", value = local.otel_resource_attributes },
    { name = "OTEL_LOGS_EXPORTER", value = "none" },
    { name = "OTEL_METRICS_EXPORTER", value = "none" },
    { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4316" },
    { name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", value = "http://localhost:4316/v1/traces" },
    { name = "OTEL_AWS_APPLICATION_SIGNALS_ENABLED", value = "true" },
    { name = "OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT", value = "http://localhost:4316/v1/metrics" },
    { name = "OTEL_TRACES_SAMPLER", value = "xray" },
    { name = "OTEL_TRACES_SAMPLER_ARG", value = "endpoint=http://localhost:2000" },
    { name = "NODE_OPTIONS", value = "--import @aws/aws-distro-opentelemetry-node-autoinstrumentation/register --experimental-loader=@opentelemetry/instrumentation/hook.mjs" },
  ] : [])

  backend_container_definitions = concat([
    merge({
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true
      cpu       = 256
      memory    = 512
      portMappings = [
        { containerPort = 4000, hostPort = 4000, protocol = "tcp" }
      ]
      environment = local.backend_container_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
      }, var.enable_tracing ? {
      dependsOn = [
        {
          containerName = "ecs-cwagent"
          condition     = "START"
        }
      ]
    } : {})
    ], var.enable_tracing ? [
    {
      name      = "ecs-cwagent"
      image     = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest"
      essential = true
      cpu       = 128
      memory    = 256
      portMappings = [
        { containerPort = 4316, hostPort = 4316, protocol = "tcp" },
        { containerPort = 2000, hostPort = 2000, protocol = "tcp" },
      ]
      environment = [
        {
          name  = "CW_CONFIG_CONTENT"
          value = local.cwagent_config_content
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cwagent[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "cwagent"
        }
      }
    }
  ] : [])
}

data "aws_caller_identity" "current" {}

# ── Default VPC lookup (skipped if vpc_id is provided) ───────────────────────

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# ── ECS-optimised AMI ─────────────────────────────────────────────────────────

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# ── ECR repository ────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "backend" {
  name                 = "${local.name_prefix}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ── CloudWatch log group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}/backend"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "cwagent" {
  count = var.enable_tracing ? 1 : 0

  name              = "/ecs/${local.name_prefix}/cwagent"
  retention_in_days = 30

  tags = local.common_tags
}

# ── S3 bucket for canary artifacts ───────────────────────────────────────────

resource "aws_s3_bucket" "canary_artifacts" {
  count  = var.enable_canaries ? 1 : 0
  bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-canary-artifacts"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  count  = var.enable_canaries ? 1 : 0
  bucket = aws_s3_bucket.canary_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── S3 bucket for frontend static assets ─────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-frontend"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CloudFront Origin Access Control (OAC) ───────────────────────────────────

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront distribution ───────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  comment = "${local.name_prefix} demo frontend"
  tags    = local.common_tags

  # S3 origin for static frontend assets
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # ALB origin for API and health traffic
  origin {
    domain_name = aws_lb.demo.dns_name
    origin_id   = "alb-backend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default: serve from S3 (SPA)
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # /api/* → ALB backend (no caching)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # /health → ALB backend (no caching)
  ordered_cache_behavior {
    path_pattern           = "/health"
    target_origin_id       = "alb-backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # SPA routing: serve index.html for 403/404 from S3
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ── S3 bucket policy: allow CloudFront OAC ───────────────────────────────────

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipal"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
        }
      }
    }]
  })
}

# ── SSM: persist CloudFront distribution ID for workflow invalidation ─────────

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "/${var.project}/${var.environment}/cloudfront_distribution_id"
  type  = "String"
  value = aws_cloudfront_distribution.this.id

  tags = local.common_tags
}

# ── Security groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Allow inbound HTTP to the demo ALB"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "ecs_instances" {
  name        = "${local.name_prefix}-ecs-instances"
  description = "Security group for ECS EC2 container instances"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ── IAM: EC2 instance profile for ECS container instances ─────────────────────

resource "aws_iam_role" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ec2_container_service" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance"
  role = aws_iam_role.ecs_instance.name

  tags = local.common_tags
}

# ── IAM: ECS task execution role ──────────────────────────────────────────────

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_security_group" "backend_tasks" {
  name        = "${local.name_prefix}-backend-tasks"
  description = "Allow traffic from the ALB to backend ECS tasks"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Backend HTTP from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "application_signals_endpoints" {
  count = var.enable_tracing ? 1 : 0

  name        = "${local.name_prefix}-appsignals-endpoints"
  description = "Allow backend ECS tasks to reach AWS interface endpoints used by Application Signals"
  vpc_id      = local.vpc_id

  ingress {
    description     = "HTTPS from backend ECS tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "cloudwatch_monitoring" {
  count = var.enable_tracing ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.application_signals_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-monitoring-endpoint"
  })
}

resource "aws_vpc_endpoint" "xray" {
  count = var.enable_tracing ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.xray"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.application_signals_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-xray-endpoint"
  })
}

resource "aws_vpc_endpoint" "logs" {
  count = var.enable_tracing ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.application_signals_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-logs-endpoint"
  })
}

resource "aws_iam_role" "backend_task" {
  count = var.enable_tracing ? 1 : 0

  name = "${local.name_prefix}-backend-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "backend_task_cloudwatch_agent" {
  count = var.enable_tracing ? 1 : 0

  role       = aws_iam_role.backend_task[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "demo" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.subnet_ids

  tags = local.common_tags
}

resource "aws_lb_target_group" "backend" {
  # Use a generated target group name so Terraform can replace the target group
  # safely when immutable attributes like target_type change.
  name_prefix = substr(replace(local.name_prefix, "-", ""), 0, 6)
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.demo.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ── ECS cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "demo" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "demo" {
  cluster_name       = aws_ecs_cluster.demo.name
  capacity_providers = [aws_ecs_capacity_provider.demo.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.demo.name
  }
}

# ── EC2 Auto Scaling group for ECS container instances ───────────────────────

resource "aws_launch_template" "ecs_instance" {
  name_prefix   = "${local.name_prefix}-ecs-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.demo.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_ENI=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-ecs-instance"
      Project     = var.project
      Environment = var.environment
    }
  }

  tags = local.common_tags
}

resource "aws_autoscaling_group" "ecs_instances" {
  name                = "${local.name_prefix}-ecs-asg"
  vpc_zone_identifier = local.subnet_ids
  desired_capacity    = var.desired_capacity
  min_size            = 1
  max_size            = var.max_capacity

  launch_template {
    id      = aws_launch_template.ecs_instance.id
    version = "$Latest"
  }

  protect_from_scale_in = true

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = false
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "demo" {
  name = "${local.name_prefix}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_instances.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
  }

  tags = local.common_tags
}

# ── ECS task definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.enable_tracing ? aws_iam_role.backend_task[0].arn : null
  cpu                      = var.enable_tracing ? 384 : 256
  memory                   = var.enable_tracing ? 768 : 512
  tags                     = local.common_tags

  container_definitions = jsonencode(local.backend_container_definitions)
}

# ── ECS service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend"
  cluster         = aws_ecs_cluster.demo.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  tags            = local.common_tags

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.demo.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 4000
  }

  network_configuration {
    subnets         = local.subnet_ids
    security_groups = [aws_security_group.backend_tasks.id]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.task_execution,
    aws_iam_role_policy_attachment.backend_task_cloudwatch_agent,
    aws_vpc_endpoint.cloudwatch_monitoring,
    aws_vpc_endpoint.xray,
    aws_vpc_endpoint.logs,
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ── Observability: ECS service adapter ───────────────────────────────────────

