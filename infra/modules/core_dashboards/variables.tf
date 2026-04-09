variable "project" {
  type        = string
  description = "Project name used for naming dashboards."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "region" {
  type        = string
  description = "AWS region where the workload and dashboards reside."
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix (the portion after 'loadbalancer/' in the ARN)."
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Primary target group ARN suffix (the portion after 'targetgroup/' in the ARN)."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name."
}

variable "log_group_names" {
  type        = list(string)
  description = "List of CloudWatch log group names to include in log analysis widgets."
}

variable "service_owner" {
  type        = string
  description = "Optional owner/team label rendered in the dashboard header."
  default     = null
}

variable "runbook_url" {
  type        = string
  description = "Optional runbook URL linked from the dashboard."
  default     = null
}

variable "tracing_enabled" {
  type        = bool
  description = "When true, renders trace drilldowns in the dashboard."
  default     = false
}

variable "tracing_service_name" {
  type        = string
  description = "Tracing service name used for trace drilldowns."
  default     = null
}

variable "canary_name" {
  type        = string
  description = "Name of the CloudWatch Synthetics canary. Set to null to omit the canary widget."
  default     = null
}

variable "alarm_arns" {
  type = object({
    alb_5xx             = string
    alb_target_5xx      = string
    alb_latency_p99     = string
    alb_unhealthy_hosts = string
    ecs_running_tasks   = string
    ecs_cpu             = string
    ecs_memory          = string
    canary_failure      = optional(string)
  })
  description = "Map of alarm ARNs from the core_alarms module. Used for alarm widgets — CloudWatch requires full ARNs, not names."
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
}
