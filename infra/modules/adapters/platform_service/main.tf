locals {
  service_kind = lower(try(var.service.kind, null) != null ? var.service.kind : "ecs_ec2_alb")

  ingress = try(var.service.ingress, null)
  ecs     = try(var.service.ecs, null)
  ec2     = try(var.service.ec2, null)

  ingress_kind = lower(try(local.ingress.kind, null) != null ? local.ingress.kind : "alb")

  resolved_alb_arn = (
    try(local.ingress.alb_arn, null) != null ?
    local.ingress.alb_arn :
    try(var.service.alb_arn, null)
  )

  resolved_target_group_arn = (
    try(local.ingress.target_group_arn, null) != null ?
    local.ingress.target_group_arn :
    try(var.service.target_group_arn, null)
  )

  ecs_service_arn = (
    try(local.ecs.service_arn, null) != null ?
    local.ecs.service_arn :
    try(var.service.ecs_service_arn, null)
  )

  ecs_cluster_arn = try(local.ecs.cluster_arn, null)

  ecs_service_arn_parts = local.ecs_service_arn != null ? split("/", local.ecs_service_arn) : []
  ecs_cluster_arn_parts = local.ecs_cluster_arn != null ? split("/", local.ecs_cluster_arn) : []

  resolved_ecs_cluster_name_from_arn = (
    length(local.ecs_cluster_arn_parts) >= 2 ?
    local.ecs_cluster_arn_parts[length(local.ecs_cluster_arn_parts) - 1] :
    null
  )

  resolved_ecs_cluster_name_from_service_arn = (
    length(local.ecs_service_arn_parts) >= 3 ?
    local.ecs_service_arn_parts[length(local.ecs_service_arn_parts) - 2] :
    null
  )

  resolved_ecs_service_name_from_arn = (
    length(local.ecs_service_arn_parts) >= 2 ?
    local.ecs_service_arn_parts[length(local.ecs_service_arn_parts) - 1] :
    null
  )

  ecs_cluster_name = (
    try(local.ecs.cluster_name, null) != null ?
    local.ecs.cluster_name :
    (
      try(var.service.ecs_cluster_name, null) != null ?
      var.service.ecs_cluster_name :
      (
        local.resolved_ecs_cluster_name_from_arn != null ?
        local.resolved_ecs_cluster_name_from_arn :
        local.resolved_ecs_cluster_name_from_service_arn
      )
    )
  )

  ecs_service_name = (
    try(local.ecs.service_name, null) != null ?
    local.ecs.service_name :
    (
      try(var.service.ecs_service_name, null) != null ?
      var.service.ecs_service_name :
      local.resolved_ecs_service_name_from_arn
    )
  )

  ecs_app_container_name = try(local.ecs.app_container_name, null)

  ec2_autoscaling_group_name = try(local.ec2.autoscaling_group_name, null)
  ec2_instance_ids = (
    try(local.ec2.instance_ids, null) != null ?
    local.ec2.instance_ids :
    []
  )
  ec2_instance_tag_selector = (
    try(local.ec2.instance_tag_selector, null) != null ?
    local.ec2.instance_tag_selector :
    {}
  )
  ec2_selector_configured = (
    local.ec2_autoscaling_group_name != null ||
    length(local.ec2_instance_ids) > 0 ||
    length(keys(local.ec2_instance_tag_selector)) > 0
  )

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
    frontend_url          = try(var.canaries.frontend_url, null) != null ? var.canaries.frontend_url : try(local.ingress.public_base_url, null)
    api_endpoint          = try(var.canaries.api_endpoint, null) != null ? var.canaries.api_endpoint : try(local.ingress.api_health_url, null)
    artifacts_bucket_name = try(var.canaries.artifacts_bucket_name, null)
    schedule_expression   = coalesce(try(var.canaries.schedule_expression, null), "rate(5 minutes)")
  }

  tracing_enabled = coalesce(try(var.tracing.enabled, null), false)
  tracing_mode = lower(
    try(var.tracing.mode, null) != null ?
    var.tracing.mode :
    (local.tracing_enabled ? "external" : "off")
  )

  tracing_service_name = (
    try(var.tracing.service_name, null) != null ?
    var.tracing.service_name :
    var.service.name
  )

  enable_canary_active_tracing = coalesce(try(var.tracing.enable_canary_tracing, null), local.tracing_enabled)

  log_group_names = coalesce(
    try(var.service.log_group_names, null),
    try(var.logging.log_group_names, null),
    []
  )

  log_field_names = {
    level       = coalesce(try(var.logging.fields.level, null), "level")
    route       = coalesce(try(var.logging.fields.route, null), "route")
    method      = coalesce(try(var.logging.fields.method, null), "method")
    status_code = coalesce(try(var.logging.fields.status_code, null), "statusCode")
    latency_ms  = coalesce(try(var.logging.fields.latency_ms, null), "durationMs")
    request_id  = coalesce(try(var.logging.fields.request_id, null), "requestId")
    source_ip   = coalesce(try(var.logging.fields.source_ip, null), "sourceIp")
  }

  alb_arn_suffix          = try(split("loadbalancer/", local.resolved_alb_arn)[1], "")
  target_group_arn_suffix = try(regex("targetgroup/.+$", local.resolved_target_group_arn), "")
}

resource "terraform_data" "validate" {
  input = true

  lifecycle {
    precondition {
      condition     = contains(["ec2_alb", "ecs_ec2_alb", "ecs_fargate_alb"], local.service_kind)
      error_message = "platform_service supports ecs_ec2_alb and ecs_fargate_alb today. ec2_alb is reserved as a scaffolded contract for a future adapter."
    }

    precondition {
      condition     = local.ingress_kind == "alb"
      error_message = "service.ingress.kind must be alb. Additional ingress adapters will be added later."
    }

    precondition {
      condition     = can(regex("^app/.+", local.alb_arn_suffix))
      error_message = "Provide a valid ALB ARN via service.ingress.alb_arn or the legacy service.alb_arn."
    }

    precondition {
      condition     = can(regex("^targetgroup/.+", local.target_group_arn_suffix))
      error_message = "Provide a valid target group ARN via service.ingress.target_group_arn or the legacy service.target_group_arn."
    }

    precondition {
      condition     = local.service_kind != "ec2_alb" || local.ec2 != null
      error_message = "service.ec2 is required when service.kind = ec2_alb."
    }

    precondition {
      condition     = local.service_kind != "ec2_alb" || local.ec2_selector_configured
      error_message = "service.ec2 must include autoscaling_group_name, instance_ids, or instance_tag_selector when service.kind = ec2_alb."
    }

    precondition {
      condition     = local.service_kind == "ec2_alb" || (local.ecs_service_arn == null || can(regex("^arn:[^:]+:ecs:[^:]+:[0-9]{12}:service/.+$", local.ecs_service_arn)))
      error_message = "service.ecs.service_arn must be null or a valid ECS service ARN."
    }

    precondition {
      condition     = local.service_kind == "ec2_alb" || (local.ecs_cluster_arn == null || can(regex("^arn:[^:]+:ecs:[^:]+:[0-9]{12}:cluster/.+$", local.ecs_cluster_arn)))
      error_message = "service.ecs.cluster_arn must be null or a valid ECS cluster ARN."
    }

    precondition {
      condition     = local.service_kind == "ec2_alb" || (local.ecs_cluster_name != null && length(trimspace(local.ecs_cluster_name)) > 0)
      error_message = "ECS cluster name could not be resolved. Provide service.ecs.service_arn, service.ecs.cluster_name, service.ecs.cluster_arn, or the legacy service.ecs_cluster_name."
    }

    precondition {
      condition     = local.service_kind == "ec2_alb" || (local.ecs_service_name != null && length(trimspace(local.ecs_service_name)) > 0)
      error_message = "ECS service name could not be resolved. Provide service.ecs.service_arn, service.ecs.service_name, or the legacy service.ecs_service_name."
    }

    precondition {
      condition     = length(local.log_group_names) > 0 && alltrue([for name in local.log_group_names : length(trimspace(name)) > 0])
      error_message = "Provide at least one non-empty CloudWatch Logs group name via service.log_group_names or the legacy logging.log_group_names."
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
      condition     = contains(["off", "external", "managed"], local.tracing_mode)
      error_message = "tracing.mode must be one of: off, external, managed."
    }

    precondition {
      condition = (
        local.tracing_mode != "managed" ||
        (local.service_kind == "ec2_alb" && local.ec2_selector_configured) ||
        (local.service_kind != "ec2_alb" && local.ecs_app_container_name != null && length(trimspace(local.ecs_app_container_name)) > 0)
      )
      error_message = "Managed tracing requires service.ecs.app_container_name for ECS kinds, or a concrete service.ec2 selector for ec2_alb."
    }

    precondition {
      condition     = try(var.tracing.service_name, null) == null || length(trimspace(local.tracing_service_name)) > 0
      error_message = "tracing.service_name must be null or a non-empty string."
    }
  }
}

module "ecs_ec2_alb" {
  count  = local.service_kind == "ecs_ec2_alb" ? 1 : 0
  source = "../ecs_ec2_alb"

  project     = var.service.name
  environment = var.service.environment
  region      = var.service.region

  ecs_cluster_name        = local.ecs_cluster_name
  ecs_service_name        = local.ecs_service_name
  alb_arn_suffix          = local.alb_arn_suffix
  target_group_arn_suffix = local.target_group_arn_suffix

  log_group_names = local.log_group_names
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

module "ecs_fargate_alb" {
  count  = local.service_kind == "ecs_fargate_alb" ? 1 : 0
  source = "../ecs_fargate_alb"

  project     = var.service.name
  environment = var.service.environment
  region      = var.service.region

  ecs_cluster_name        = local.ecs_cluster_name
  ecs_service_name        = local.ecs_service_name
  alb_arn_suffix          = local.alb_arn_suffix
  target_group_arn_suffix = local.target_group_arn_suffix

  log_group_names = local.log_group_names
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

module "ec2_alb" {
  count  = local.service_kind == "ec2_alb" ? 1 : 0
  source = "../ec2_alb"

  project     = var.service.name
  environment = var.service.environment
  region      = var.service.region

  alb_arn_suffix          = local.alb_arn_suffix
  target_group_arn_suffix = local.target_group_arn_suffix
  log_group_names         = local.log_group_names
  log_field_names         = local.log_field_names

  dashboard_owner      = local.dashboard.owner
  runbook_url          = local.dashboard.runbook_url
  tracing_enabled      = local.tracing_enabled
  tracing_service_name = local.tracing_service_name

  sns_topic_arn                     = local.alerts.sns_topic_arn
  create_sns_topic                  = local.alerts.create_sns_topic
  alb_5xx_threshold                 = local.alerts.alb_5xx_threshold
  alb_latency_p99_threshold_seconds = local.alerts.alb_latency_p99_threshold_seconds

  enable_canaries              = local.canaries.enabled
  frontend_url                 = local.canaries.enabled ? local.canaries.frontend_url : null
  api_endpoint                 = local.canaries.enabled ? local.canaries.api_endpoint : null
  canary_artifacts_bucket_name = local.canaries.enabled ? local.canaries.artifacts_bucket_name : null
  canary_schedule_expression   = local.canaries.schedule_expression
  enable_canary_active_tracing = local.canaries.enabled ? local.enable_canary_active_tracing : false

  autoscaling_group_name = local.ec2_autoscaling_group_name
  instance_ids           = local.ec2_instance_ids
  instance_tag_selector  = local.ec2_instance_tag_selector

  depends_on = [terraform_data.validate]
}
