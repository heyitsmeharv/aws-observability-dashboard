variable "service" {
  type = object({
    name        = string
    environment = string
    region      = string
    kind        = optional(string)
    ingress = optional(object({
      kind             = optional(string)
      alb_arn          = optional(string)
      target_group_arn = optional(string)
      public_base_url  = optional(string)
      api_health_url   = optional(string)
    }))
    log_group_names = optional(list(string))
    ecs = optional(object({
      cluster_arn        = optional(string)
      service_arn        = optional(string)
      cluster_name       = optional(string)
      service_name       = optional(string)
      app_container_name = optional(string)
    }))
    ec2 = optional(object({
      autoscaling_group_name = optional(string)
      instance_ids           = optional(list(string))
      instance_tag_selector  = optional(map(string))
    }))

    # Legacy compatibility fields. New consumers should prefer service.ingress
    # and service.ecs.
    alb_arn          = optional(string)
    target_group_arn = optional(string)
    ecs_service_arn  = optional(string)
    ecs_cluster_name = optional(string)
    ecs_service_name = optional(string)
  })
  description = "Top-level workload identity and infrastructure attachment points for the service being observed."

  validation {
    condition     = length(trimspace(var.service.name)) > 0
    error_message = "service.name must be a non-empty string."
  }

  validation {
    condition     = length(trimspace(var.service.environment)) > 0
    error_message = "service.environment must be a non-empty string."
  }

  validation {
    condition     = length(trimspace(var.service.region)) > 0
    error_message = "service.region must be a non-empty AWS region string."
  }

  validation {
    condition = try(var.service.log_group_names, null) == null ? true : (
      length(var.service.log_group_names) > 0 &&
      alltrue([for name in var.service.log_group_names : length(trimspace(name)) > 0])
    )
    error_message = "service.log_group_names must be null or contain at least one non-empty CloudWatch Logs group name."
  }

  validation {
    condition = try(var.service.ecs, null) == null ? true : (
      try(var.service.ecs.app_container_name, null) == null ||
      length(trimspace(var.service.ecs.app_container_name)) > 0
    )
    error_message = "service.ecs.app_container_name must be null or a non-empty string."
  }

  validation {
    condition = try(var.service.ec2, null) == null ? true : (
      try(var.service.ec2.instance_ids, null) == null ? true : (
        length(var.service.ec2.instance_ids) > 0 &&
        alltrue([for id in var.service.ec2.instance_ids : length(trimspace(id)) > 0])
      )
    )
    error_message = "service.ec2.instance_ids must be null or contain at least one non-empty EC2 instance ID."
  }

  validation {
    condition = try(var.service.ingress, null) == null ? true : (
      try(var.service.ingress.public_base_url, null) == null ||
      can(regex("^https?://", var.service.ingress.public_base_url))
    )
    error_message = "service.ingress.public_base_url must be null or a fully-qualified http(s) URL."
  }

  validation {
    condition = try(var.service.ingress, null) == null ? true : (
      try(var.service.ingress.api_health_url, null) == null ||
      can(regex("^https?://", var.service.ingress.api_health_url))
    )
    error_message = "service.ingress.api_health_url must be null or a fully-qualified http(s) URL."
  }
}

variable "logging" {
  type = object({
    log_group_names = optional(list(string))
    fields = optional(object({
      level       = optional(string)
      route       = optional(string)
      method      = optional(string)
      status_code = optional(string)
      latency_ms  = optional(string)
      request_id  = optional(string)
      source_ip   = optional(string)
    }))
  })
  description = "Optional structured logging configuration. service.log_group_names is the preferred public input; logging.log_group_names remains as a compatibility fallback."
  default     = {}

  validation {
    condition = try(var.logging.log_group_names, null) == null ? true : (
      length(var.logging.log_group_names) > 0 &&
      alltrue([for name in var.logging.log_group_names : length(trimspace(name)) > 0])
    )
    error_message = "logging.log_group_names must be null or contain at least one non-empty CloudWatch Logs group name."
  }
}

variable "dashboard" {
  type = object({
    owner       = optional(string)
    runbook_url = optional(string)
  })
  description = "Optional dashboard metadata rendered in the dashboard header and quick links."
  default     = {}
}

variable "alerts" {
  type = object({
    sns_topic_arn                     = optional(string)
    create_sns_topic                  = optional(bool)
    alb_5xx_threshold                 = optional(number)
    alb_latency_p99_threshold_seconds = optional(number)
    ecs_cpu_threshold_percent         = optional(number)
    ecs_memory_threshold_percent      = optional(number)
  })
  description = "Alarm routing and threshold configuration."
  default     = {}
}

variable "canaries" {
  type = object({
    enabled               = optional(bool)
    frontend_url          = optional(string)
    api_endpoint          = optional(string)
    artifacts_bucket_name = optional(string)
    schedule_expression   = optional(string)
  })
  description = "Outside-in synthetic monitoring configuration."
  default     = {}
}

variable "tracing" {
  type = object({
    enabled               = optional(bool)
    mode                  = optional(string)
    service_name          = optional(string)
    enable_canary_tracing = optional(bool)
  })
  description = "Optional OpenTelemetry/Application Signals metadata. Use mode = managed when the surrounding stack owns workload instrumentation; use external when traces already exist."
  default     = {}
}
