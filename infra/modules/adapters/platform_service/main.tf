locals {
  service_kind = coalesce(try(var.service.kind, null), "ecs_ec2_alb")

  dashboard = {
    owner       = try(var.dashboard.owner, null)
    runbook_url = try(var.dashboard.runbook_url, null)
  }

  alerts = {
    sns_topic_arn                     = try(var.alerts.sns_topic_arn, null)
    create_sns_topic                  = coalesce(try(var.alerts.create_sns_topic, null), false)
    alb_5xx_threshold                 = coalesce(try(var.alerts.alb_5xx_threshold, null), 10)
    alb_latency_p99_threshold_seconds = coalesce(try(var.alerts.alb_latency_p99_threshold_seconds, null), 2)
    ecs_cpu_threshold_percent         = coalesce(try(var.alerts.ecs_cpu_threshold_percent, null), 80)
    ecs_memory_threshold_percent      = coalesce(try(var.alerts.ecs_memory_threshold_percent, null), 80)
  }

  canaries = {
    enabled               = coalesce(try(var.canaries.enabled, null), false)
    frontend_url          = try(var.canaries.frontend_url, null)
    api_endpoint          = try(var.canaries.api_endpoint, null)
    artifacts_bucket_name = try(var.canaries.artifacts_bucket_name, null)
    schedule_expression   = coalesce(try(var.canaries.schedule_expression, null), "rate(5 minutes)")
  }

  tracing_enabled = coalesce(try(var.tracing.enabled, null), false)

  tracing_service_name = coalesce(try(var.tracing.service_name, null), var.service.name)

  enable_canary_active_tracing = coalesce(try(var.tracing.enable_canary_tracing, null), local.tracing_enabled)

  log_field_names = {
    level       = coalesce(try(var.logging.fields.level, null), "level")
    route       = coalesce(try(var.logging.fields.route, null), "route")
    method      = coalesce(try(var.logging.fields.method, null), "method")
    status_code = coalesce(try(var.logging.fields.status_code, null), "statusCode")
    latency_ms  = coalesce(try(var.logging.fields.latency_ms, null), "durationMs")
    request_id  = coalesce(try(var.logging.fields.request_id, null), "requestId")
    source_ip   = coalesce(try(var.logging.fields.source_ip, null), "sourceIp")
  }

  alb_arn_suffix = try(split("loadbalancer/", var.service.alb_arn)[1], "")

  target_group_arn_suffix = try(split("targetgroup/", var.service.target_group_arn)[1], "")
}

resource "terraform_data" "validate" {
  input = true

  lifecycle {
    precondition {
      condition     = local.service_kind == "ecs_ec2_alb"
      error_message = "platform_service currently supports one workload kind: ecs_ec2_alb."
    }

    precondition {
      condition     = can(regex("^app/.+", local.alb_arn_suffix))
      error_message = "service.alb_arn must be a valid Application Load Balancer ARN."
    }

    precondition {
      condition     = can(regex("^targetgroup/.+", local.target_group_arn_suffix))
      error_message = "service.target_group_arn must be a valid target group ARN."
    }

    precondition {
      condition = alltrue([
        for field_name in values(local.log_field_names) :
        can(regex("^[A-Za-z_][A-Za-z0-9_]*$", field_name))
      ])
      error_message = "logging.fields values must be simple Logs Insights field identifiers such as route or statusCode."
    }

    precondition {
      condition     = local.dashboard.runbook_url == null || can(regex("^https?://", local.dashboard.runbook_url))
      error_message = "dashboard.runbook_url must be null or a fully-qualified http(s) URL."
    }

    precondition {
      condition     = !local.canaries.enabled || (local.canaries.frontend_url != null && local.canaries.artifacts_bucket_name != null)
      error_message = "canaries.frontend_url and canaries.artifacts_bucket_name are required when canaries.enabled = true."
    }

    precondition {
      condition     = local.canaries.frontend_url == null || can(regex("^https?://", local.canaries.frontend_url))
      error_message = "canaries.frontend_url must be null or a fully-qualified http(s) URL."
    }

    precondition {
      condition     = local.canaries.api_endpoint == null || can(regex("^https?://", local.canaries.api_endpoint))
      error_message = "canaries.api_endpoint must be null or a fully-qualified http(s) URL."
    }

    precondition {
      condition     = try(var.tracing.service_name, null) == null || length(trimspace(local.tracing_service_name)) > 0
      error_message = "tracing.service_name must be null or a non-empty string."
    }
  }
}

module "observability" {
  source = "../ecs_service"

  project     = var.service.name
  environment = var.service.environment
  region      = var.service.region

  ecs_cluster_name        = var.service.ecs_cluster_name
  ecs_service_name        = var.service.ecs_service_name
  alb_arn_suffix          = local.alb_arn_suffix
  target_group_arn_suffix = local.target_group_arn_suffix

  log_group_names = var.logging.log_group_names
  log_field_names = local.log_field_names

  dashboard_owner      = local.dashboard.owner
  runbook_url          = local.dashboard.runbook_url
  tracing_enabled      = local.tracing_enabled
  tracing_service_name = local.tracing_service_name

  sns_topic_arn                     = local.alerts.sns_topic_arn
  create_sns_topic                  = local.alerts.create_sns_topic
  alb_5xx_threshold                 = local.alerts.alb_5xx_threshold
  alb_latency_p99_threshold_seconds = local.alerts.alb_latency_p99_threshold_seconds
  ecs_cpu_threshold_percent         = local.alerts.ecs_cpu_threshold_percent
  ecs_memory_threshold_percent      = local.alerts.ecs_memory_threshold_percent

  enable_canaries              = local.canaries.enabled
  frontend_url                 = local.canaries.enabled ? local.canaries.frontend_url : null
  api_endpoint                 = local.canaries.enabled ? local.canaries.api_endpoint : null
  canary_artifacts_bucket_name = local.canaries.enabled ? local.canaries.artifacts_bucket_name : null
  canary_schedule_expression   = local.canaries.schedule_expression
  enable_canary_active_tracing = local.canaries.enabled ? local.enable_canary_active_tracing : false

  depends_on = [terraform_data.validate]
}
