locals {
  name_prefix = "${var.project}-${var.environment}"

  # Resolve the SNS topic ARN: use provided, created, or null
  resolved_sns_topic_arn = (
    var.sns_topic_arn != null ? var.sns_topic_arn :
    var.create_sns_topic ? aws_sns_topic.alarms[0].arn :
    null
  )

  # Canary name is known deterministically once resources exist
  frontend_canary_name = var.enable_canaries ? module.canaries[0].frontend_canary_name : null

  resolved_tracing_service_name = coalesce(var.tracing_service_name, var.project)
}

# ── Optional SNS topic ────────────────────────────────────────────────────────

resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic && var.sns_topic_arn == null ? 1 : 0

  name = "${local.name_prefix}-alarms"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Core: canaries ────────────────────────────────────────────────────────────
# Deployed first so the canary name is available to the alarms module.

module "canaries" {
  count  = var.enable_canaries ? 1 : 0
  source = "../../core_canaries"

  project     = var.project
  environment = var.environment

  artifacts_bucket_name = var.canary_artifacts_bucket_name
  frontend_url          = var.frontend_url
  api_endpoint          = var.api_endpoint
  schedule_expression   = var.canary_schedule_expression
  enable_active_tracing = var.enable_canary_active_tracing
}

# ── Core: alarms ──────────────────────────────────────────────────────────────

module "alarms" {
  source = "../../core_alarms"

  project     = var.project
  environment = var.environment

  alb_arn_suffix          = var.alb_arn_suffix
  target_group_arn_suffix = var.target_group_arn_suffix
  ecs_cluster_name        = var.ecs_cluster_name
  ecs_service_name        = var.ecs_service_name

  canary_name   = local.frontend_canary_name
  sns_topic_arn = local.resolved_sns_topic_arn

  alb_5xx_threshold                 = var.alb_5xx_threshold
  alb_latency_p99_threshold_seconds = var.alb_latency_p99_threshold_seconds
  ecs_cpu_threshold_percent         = var.ecs_cpu_threshold_percent
  ecs_memory_threshold_percent      = var.ecs_memory_threshold_percent
}

# ── Core: Logs Insights query pack ───────────────────────────────────────────

module "logs_insights" {
  source = "../../core_logs_insights"

  project         = var.project
  environment     = var.environment
  log_group_names = var.log_group_names
  log_field_names = var.log_field_names
}

# ── Core: dashboards ──────────────────────────────────────────────────────────

module "dashboards" {
  source = "../../core_dashboards"

  project     = var.project
  environment = var.environment
  region      = var.region

  alb_arn_suffix          = var.alb_arn_suffix
  target_group_arn_suffix = var.target_group_arn_suffix
  ecs_cluster_name        = var.ecs_cluster_name
  ecs_service_name        = var.ecs_service_name
  log_group_names         = var.log_group_names
  service_owner           = var.dashboard_owner
  runbook_url             = var.runbook_url
  tracing_enabled         = var.tracing_enabled
  tracing_service_name    = local.resolved_tracing_service_name

  canary_name     = local.frontend_canary_name
  alarm_arns      = module.alarms.alarm_arns
  log_field_names = var.log_field_names

  depends_on = [module.alarms]
}
