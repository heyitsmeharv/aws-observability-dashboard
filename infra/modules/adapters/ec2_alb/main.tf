locals {
  scaffold_context = {
    project                      = var.project
    environment                  = var.environment
    region                       = var.region
    alb_arn_suffix               = var.alb_arn_suffix
    target_group_arn_suffix      = var.target_group_arn_suffix
    log_group_names              = var.log_group_names
    log_field_names              = var.log_field_names
    dashboard_owner              = var.dashboard_owner
    runbook_url                  = var.runbook_url
    tracing_enabled              = var.tracing_enabled
    tracing_service_name         = var.tracing_service_name
    sns_topic_arn                = var.sns_topic_arn
    create_sns_topic             = var.create_sns_topic
    alb_5xx_threshold            = var.alb_5xx_threshold
    alb_latency_p99_threshold    = var.alb_latency_p99_threshold_seconds
    enable_canaries              = var.enable_canaries
    frontend_url                 = var.frontend_url
    api_endpoint                 = var.api_endpoint
    canary_artifacts_bucket_name = var.canary_artifacts_bucket_name
    canary_schedule_expression   = var.canary_schedule_expression
    enable_canary_active_tracing = var.enable_canary_active_tracing
    autoscaling_group_name       = var.autoscaling_group_name
    instance_ids                 = var.instance_ids
    instance_tag_selector        = var.instance_tag_selector
  }
}

resource "terraform_data" "validate" {
  input = local.scaffold_context

  lifecycle {
    precondition {
      condition     = length(local.scaffold_context.log_group_names) < 0
      error_message = "service.kind = ec2_alb is scaffolded into the public contract, but the v1 EC2 adapter is not implemented yet. Today the package creates monitoring and alerting for ECS-backed ALB services."
    }
  }
}
