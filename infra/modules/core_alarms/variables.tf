variable "project" {
  type        = string
  description = "Project name used for naming and tagging."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix (the portion after 'loadbalancer/' in the ARN, used in CloudWatch metric dimensions)."
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Target group ARN suffix (the portion after 'targetgroup/' in the ARN, used in CloudWatch metric dimensions)."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name."
}

variable "canary_name" {
  type        = string
  description = "Name of the CloudWatch Synthetics canary to alarm on. Set to null to skip the canary failure alarm."
  default     = null
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN to notify on alarm state transitions. Set to null to create alarms without actions."
  default     = null
}

variable "alb_5xx_threshold" {
  type        = number
  description = "ALB 5xx HTTP error count threshold per evaluation period before alarming."
  default     = 10
}

variable "alb_latency_p99_threshold_seconds" {
  type        = number
  description = "ALB target response time P99 threshold in seconds before alarming."
  default     = 2
}

variable "ecs_cpu_threshold_percent" {
  type        = number
  description = "ECS service CPU utilisation alarm threshold (0–100)."
  default     = 80
}

variable "ecs_memory_threshold_percent" {
  type        = number
  description = "ECS service memory utilisation alarm threshold (0–100)."
  default     = 80
}

variable "evaluation_periods" {
  type        = number
  description = "Number of consecutive evaluation periods that must breach the threshold before alarming."
  default     = 2
}

variable "period_seconds" {
  type        = number
  description = "CloudWatch metric evaluation period in seconds."
  default     = 60
}
