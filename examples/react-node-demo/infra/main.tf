locals {
  name_prefix = "${var.project}-${var.environment}"

  # Resolve VPC and subnets: use provided values or fall back to defaults
  vpc_id     = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids
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
}

# ── CloudWatch log group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}/backend"
  retention_in_days = 30
}

# ── S3 bucket for canary artifacts ───────────────────────────────────────────

resource "aws_s3_bucket" "canary_artifacts" {
  count  = var.enable_canaries ? 1 : 0
  bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-canary-artifacts"
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
}

resource "aws_security_group" "ecs_instances" {
  name        = "${local.name_prefix}-ecs-instances"
  description = "Allow traffic from ALB to ECS container instances"
  vpc_id      = local.vpc_id

  ingress {
    description     = "All from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "demo" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.subnet_ids
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-backend"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
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
}

# ── ECS task definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true
      cpu       = 256
      memory    = 512

      portMappings = [
        { containerPort = 4000, hostPort = 0, protocol = "tcp" }
      ]

      environment = [
        { name = "NODE_ENV", value = var.environment },
        { name = "PORT", value = "4000" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])
}

# ── ECS service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend"
  cluster         = aws_ecs_cluster.demo.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.demo.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 4000
  }

  depends_on = [aws_lb_listener.http, aws_iam_role_policy_attachment.task_execution]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# ── Observability: ECS service adapter ───────────────────────────────────────

module "observability" {
  source = "../../../infra/modules/adapters/ecs_service"

  project     = var.project
  environment = var.environment
  region      = var.aws_region

  ecs_cluster_name        = aws_ecs_cluster.demo.name
  ecs_service_name        = aws_ecs_service.backend.name
  alb_arn_suffix          = aws_lb.demo.arn_suffix
  target_group_arn_suffix = aws_lb_target_group.backend.arn_suffix

  log_group_names = [aws_cloudwatch_log_group.backend.name]

  create_sns_topic = var.create_sns_topic

  enable_canaries              = var.enable_canaries
  frontend_url                 = var.enable_canaries ? "https://${aws_cloudfront_distribution.this.domain_name}" : null
  api_endpoint                 = var.enable_canaries ? "https://${aws_cloudfront_distribution.this.domain_name}/health" : null
  canary_artifacts_bucket_name = var.enable_canaries ? aws_s3_bucket.canary_artifacts[0].bucket : null

  depends_on = [
    aws_ecs_service.backend,
    aws_cloudwatch_log_group.backend,
  ]
}
