# ── Workload identity ─────────────────────────────────────────────────────────

variable "project" {
  type        = string
  description = "Project name used for naming and tagging all resources."

  validation {
    condition     = length(trimspace(var.project)) > 0
    error_message = "project must be a non-empty string."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. sandbox, staging, production)."

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must be a non-empty string."
  }
}

variable "region" {
  type        = string
  description = "AWS region where the workload is deployed."

  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "region must be a non-empty AWS region string."
  }
}

# ── ECS inputs ────────────────────────────────────────────────────────────────

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster running the target service."
}

variable "ecs_service_name" {
  type        = string
  description = "Name of the ECS service to observe."
}

# ── ALB inputs ────────────────────────────────────────────────────────────────

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix (the portion after 'loadbalancer/' in the ARN). Found in the ALB resource's arn_suffix attribute."

  validation {
    condition     = startswith(var.alb_arn_suffix, "app/")
    error_message = "alb_arn_suffix must be an ALB arn_suffix beginning with 'app/'."
  }
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Primary target group ARN suffix (the portion after 'targetgroup/' in the ARN). Found in the target group resource's arn_suffix attribute."

  validation {
    condition     = startswith(var.target_group_arn_suffix, "targetgroup/")
    error_message = "target_group_arn_suffix must be a target group arn_suffix beginning with 'targetgroup/'."
  }
}

# ── Logging inputs ────────────────────────────────────────────────────────────

variable "log_group_names" {
  type        = list(string)
  description = "List of CloudWatch log group names where the target service writes structured logs."

  validation {
    condition     = length(var.log_group_names) > 0 && alltrue([for name in var.log_group_names : length(trimspace(name)) > 0])
    error_message = "log_group_names must contain at least one non-empty CloudWatch Logs group name."
  }
}

variable "log_field_names" {
  type = object({
    level       = string
    route       = string
    method      = string
    status_code = string
    latency_ms  = string
    request_id  = string
    source_ip   = string
  })
  description = "Mapping of logical HTTP log fields to the actual field names present in CloudWatch Logs."
  default = {
    level       = "level"
    route       = "route"
    method      = "method"
    status_code = "statusCode"
    latency_ms  = "durationMs"
    request_id  = "requestId"
    source_ip   = "sourceIp"
  }

  validation {
    condition = alltrue([
      for field_name in values(var.log_field_names) :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", field_name))
    ])
    error_message = "log_field_names values must be simple Logs Insights field identifiers such as route or statusCode."
  }
}

variable "dashboard_owner" {
  type        = string
  description = "Optional owner/team label rendered in the dashboard header."
  default     = null

  validation {
    condition     = var.dashboard_owner == null || length(trimspace(var.dashboard_owner)) > 0
    error_message = "dashboard_owner must be null or a non-empty string."
  }
}

variable "runbook_url" {
  type        = string
  description = "Optional runbook URL linked from the dashboard."
  default     = null

  validation {
    condition     = var.runbook_url == null || can(regex("^https?://", var.runbook_url))
    error_message = "runbook_url must be null or a fully-qualified http(s) URL."
  }
}

variable "tracing_enabled" {
  type        = bool
  description = "When true, adds X-Ray tracing drilldowns to outputs and the CloudWatch dashboard."
  default     = false
}

variable "tracing_service_name" {
  type        = string
  description = "Tracing service name used for X-Ray/Application Signals drilldowns."
  default     = null

  validation {
    condition     = var.tracing_service_name == null || length(trimspace(var.tracing_service_name)) > 0
    error_message = "tracing_service_name must be null or a non-empty string."
  }
}

# ── Alarm configuration ───────────────────────────────────────────────────────

variable "sns_topic_arn" {
  type        = string
  description = "ARN of an existing SNS topic to receive alarm notifications. Set to null to create a new topic, or set create_sns_topic = false to skip notifications entirely."
  default     = null

  validation {
    condition     = var.sns_topic_arn == null || can(regex("^arn:[^:]+:sns:[^:]+:[0-9]{12}:[A-Za-z0-9_-]+$", var.sns_topic_arn))
    error_message = "sns_topic_arn must be null or a valid SNS topic ARN."
  }
}

variable "create_sns_topic" {
  type        = bool
  description = "When true and sns_topic_arn is null, creates a new SNS topic for alarm notifications."
  default     = false
}

variable "alb_5xx_threshold" {
  type        = number
  description = "ALB 5xx count threshold before alarming."
  default     = 10

  validation {
    condition     = var.alb_5xx_threshold >= 0
    error_message = "alb_5xx_threshold must be greater than or equal to 0."
  }
}

variable "alb_latency_p99_threshold_seconds" {
  type        = number
  description = "ALB P99 response time threshold in seconds."
  default     = 2

  validation {
    condition     = var.alb_latency_p99_threshold_seconds > 0
    error_message = "alb_latency_p99_threshold_seconds must be greater than 0."
  }
}

variable "ecs_cpu_threshold_percent" {
  type        = number
  description = "ECS CPU utilisation alarm threshold (0–100)."
  default     = 80

  validation {
    condition     = var.ecs_cpu_threshold_percent > 0 && var.ecs_cpu_threshold_percent <= 100
    error_message = "ecs_cpu_threshold_percent must be between 0 and 100."
  }
}

variable "ecs_memory_threshold_percent" {
  type        = number
  description = "ECS memory utilisation alarm threshold (0–100)."
  default     = 80

  validation {
    condition     = var.ecs_memory_threshold_percent > 0 && var.ecs_memory_threshold_percent <= 100
    error_message = "ecs_memory_threshold_percent must be between 0 and 100."
  }
}

# ── Canary configuration ──────────────────────────────────────────────────────

variable "enable_canaries" {
  type        = bool
  description = "When true, provisions CloudWatch Synthetics canaries for outside-in endpoint monitoring."
  default     = false
}

variable "frontend_url" {
  type        = string
  description = "Fully-qualified URL for the frontend health-check canary. Required when enable_canaries = true."
  default     = null

  validation {
    condition     = var.frontend_url == null || can(regex("^https?://", var.frontend_url))
    error_message = "frontend_url must be null or a fully-qualified http(s) URL."
  }
}

variable "api_endpoint" {
  type        = string
  description = "Fully-qualified URL for the API health canary. Set to null to skip the API canary."
  default     = null

  validation {
    condition     = var.api_endpoint == null || can(regex("^https?://", var.api_endpoint))
    error_message = "api_endpoint must be null or a fully-qualified http(s) URL."
  }
}

variable "canary_artifacts_bucket_name" {
  type        = string
  description = "S3 bucket name for canary run artifacts. Required when enable_canaries = true."
  default     = null

  validation {
    condition     = var.canary_artifacts_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.canary_artifacts_bucket_name))
    error_message = "canary_artifacts_bucket_name must be null or a valid S3 bucket name."
  }
}

variable "canary_schedule_expression" {
  type        = string
  description = "CloudWatch Synthetics schedule expression for canaries."
  default     = "rate(5 minutes)"

  validation {
    condition     = can(regex("^(rate|cron)\\(", var.canary_schedule_expression))
    error_message = "canary_schedule_expression must start with rate( or cron(."
  }
}

variable "enable_canary_active_tracing" {
  type        = bool
  description = "When true, enables active X-Ray tracing for CloudWatch Synthetics canaries."
  default     = false
}
