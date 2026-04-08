# ── Workload identity ─────────────────────────────────────────────────────────

variable "project" {
  type        = string
  description = "Project name used for naming and tagging all resources."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. sandbox, staging, production)."
}

variable "region" {
  type        = string
  description = "AWS region where the workload is deployed."
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
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Primary target group ARN suffix (the portion after 'targetgroup/' in the ARN). Found in the target group resource's arn_suffix attribute."
}

# ── Logging inputs ────────────────────────────────────────────────────────────

variable "log_group_names" {
  type        = list(string)
  description = "List of CloudWatch log group names where the target service writes structured logs."
}

# ── Alarm configuration ───────────────────────────────────────────────────────

variable "sns_topic_arn" {
  type        = string
  description = "ARN of an existing SNS topic to receive alarm notifications. Set to null to create a new topic, or set create_sns_topic = false to skip notifications entirely."
  default     = null
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
}

variable "alb_latency_p99_threshold_seconds" {
  type        = number
  description = "ALB P99 response time threshold in seconds."
  default     = 2
}

variable "ecs_cpu_threshold_percent" {
  type        = number
  description = "ECS CPU utilisation alarm threshold (0–100)."
  default     = 80
}

variable "ecs_memory_threshold_percent" {
  type        = number
  description = "ECS memory utilisation alarm threshold (0–100)."
  default     = 80
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
}

variable "api_endpoint" {
  type        = string
  description = "Fully-qualified URL for the API health canary. Set to null to skip the API canary."
  default     = null
}

variable "canary_artifacts_bucket_name" {
  type        = string
  description = "S3 bucket name for canary run artifacts. Required when enable_canaries = true."
  default     = null
}

variable "canary_schedule_expression" {
  type        = string
  description = "CloudWatch Synthetics schedule expression for canaries."
  default     = "rate(5 minutes)"
}
