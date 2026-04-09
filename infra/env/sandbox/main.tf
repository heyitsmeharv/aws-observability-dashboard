locals {
  demo_project = "obs-demo"
}

module "demo" {
  source = "../../../examples/react-node-demo/infra"

  # Hardcoded to "obs-demo" — ALB names have a 32-char limit, the root
  # project name ("aws-observability-dashboard") would exceed it.
  project     = local.demo_project
  environment = var.environment
  aws_region  = var.aws_region

  instance_type    = var.demo_instance_type
  desired_capacity = var.demo_desired_capacity
  max_capacity     = var.demo_max_capacity

  enable_canaries = var.demo_enable_canaries
  enable_tracing  = var.demo_enable_tracing
}

module "observability" {
  source = "../../../infra/modules/adapters/platform_service"

  service = {
    name        = local.demo_project
    environment = var.environment
    region      = var.aws_region
    kind        = "ecs_ec2_alb"
    ingress = {
      alb_arn          = module.demo.alb_arn
      target_group_arn = module.demo.backend_target_group_arn
      public_base_url  = module.demo.frontend_url
      api_health_url   = module.demo.api_health_url
    }
    log_group_names = module.demo.log_group_names
    ecs = {
      cluster_arn        = module.demo.ecs_cluster_arn
      service_arn        = module.demo.backend_service_arn
      app_container_name = "backend"
    }
  }

  dashboard = {
    owner = local.demo_project
  }

  alerts = {
    create_sns_topic = var.demo_create_sns_topic
  }

  canaries = {
    enabled               = var.demo_enable_canaries
    artifacts_bucket_name = var.demo_enable_canaries ? module.demo.canary_artifacts_bucket_name : null
  }

  tracing = {
    enabled               = var.demo_enable_tracing
    mode                  = "managed"
    service_name          = module.demo.tracing_service_name
    enable_canary_tracing = var.demo_enable_tracing && var.demo_enable_canaries
  }

  depends_on = [module.demo]
}
