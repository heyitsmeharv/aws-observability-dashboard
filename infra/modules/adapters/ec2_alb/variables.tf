variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "log_group_names" {
  type = list(string)
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
}

variable "dashboard_owner" {
  type    = string
  default = null
}

variable "runbook_url" {
  type    = string
  default = null
}

variable "tracing_enabled" {
  type = bool
}

variable "tracing_service_name" {
  type    = string
  default = null
}

variable "sns_topic_arn" {
  type    = string
  default = null
}

variable "create_sns_topic" {
  type = bool
}

variable "alb_5xx_threshold" {
  type = number
}

variable "alb_latency_p99_threshold_seconds" {
  type = number
}

variable "enable_canaries" {
  type = bool
}

variable "frontend_url" {
  type    = string
  default = null
}

variable "api_endpoint" {
  type    = string
  default = null
}

variable "canary_artifacts_bucket_name" {
  type    = string
  default = null
}

variable "canary_schedule_expression" {
  type = string
}

variable "enable_canary_active_tracing" {
  type = bool
}

variable "autoscaling_group_name" {
  type    = string
  default = null
}

variable "instance_ids" {
  type    = list(string)
  default = []
}

variable "instance_tag_selector" {
  type    = map(string)
  default = {}
}
