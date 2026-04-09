module "service" {
  source = "../ecs_service"

  project     = var.project
  environment = var.environment
  region      = var.region

  ecs_cluster_name        = var.ecs_cluster_name
  ecs_service_name        = var.ecs_service_name
  alb_arn_suffix          = var.alb_arn_suffix
  target_group_arn_suffix = var.target_group_arn_suffix

  log_group_names = var.log_group_names
  log_field_names = var.log_field_names

  dashboard_owner      = var.dashboard_owner
  runbook_url          = var.runbook_url
  tracing_enabled      = var.tracing_enabled
  tracing_service_name = var.tracing_service_name

  sns_topic_arn                     = var.sns_topic_arn
  create_sns_topic                  = var.create_sns_topic
  alb_5xx_threshold                 = var.alb_5xx_threshold
  alb_latency_p99_threshold_seconds = var.alb_latency_p99_threshold_seconds
  ecs_cpu_threshold_percent         = var.ecs_cpu_threshold_percent
  ecs_memory_threshold_percent      = var.ecs_memory_threshold_percent

  enable_canaries              = var.enable_canaries
  frontend_url                 = var.frontend_url
  api_endpoint                 = var.api_endpoint
  canary_artifacts_bucket_name = var.canary_artifacts_bucket_name
  canary_schedule_expression   = var.canary_schedule_expression
  enable_canary_active_tracing = var.enable_canary_active_tracing
}
