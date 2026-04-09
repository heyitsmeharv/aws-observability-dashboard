variable "service" {
  type = object({
    name             = string
    environment      = string
    region           = string
    kind             = optional(string)
    ecs_service_arn  = optional(string)
    ecs_cluster_name = optional(string)
    ecs_service_name = optional(string)
    alb_arn          = string
    target_group_arn = string
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
    condition = (
      length(trimspace(var.service.ecs_service_arn != null ? var.service.ecs_service_arn : "")) > 0
      ) || (
      length(trimspace(var.service.ecs_cluster_name != null ? var.service.ecs_cluster_name : "")) > 0 &&
      length(trimspace(var.service.ecs_service_name != null ? var.service.ecs_service_name : "")) > 0
    )
    error_message = "Provide either service.ecs_service_arn or both service.ecs_cluster_name and service.ecs_service_name."
  }
}

variable "logging" {
  type = object({
    log_group_names = list(string)
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
  description = "Structured logging configuration used for saved Logs Insights queries and dashboard log widgets."

  validation {
    condition     = length(var.logging.log_group_names) > 0 && alltrue([for name in var.logging.log_group_names : length(trimspace(name)) > 0])
    error_message = "logging.log_group_names must contain at least one non-empty CloudWatch Logs group name."
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
    service_name          = optional(string)
    enable_canary_tracing = optional(bool)
  })
  description = "Optional OpenTelemetry/Application Signals metadata. The workload must still be instrumented outside this module."
  default     = {}
}
