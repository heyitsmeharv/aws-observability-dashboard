variable "project" {
  type        = string
  description = "Project name used for naming and tagging."
}

variable "environment" {
  type        = string
  description = "Environment name (matches folder under infra/env/)."
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-west-2"
}

# ── Demo app ──────────────────────────────────────────────────────────────────

variable "demo_instance_type" {
  type        = string
  description = "EC2 instance type for the demo ECS container instances."
  default     = "t3.small"
}

variable "demo_desired_capacity" {
  type        = number
  description = "Desired number of ECS EC2 instances for the demo cluster."
  default     = 1
}

variable "demo_max_capacity" {
  type        = number
  description = "Maximum number of ECS EC2 instances for the demo Auto Scaling group."
  default     = 3
}

variable "demo_enable_canaries" {
  type        = bool
  description = "Provision CloudWatch Synthetics canaries for the demo app."
  default     = false
}

variable "demo_enable_tracing" {
  type        = bool
  description = "Enable OpenTelemetry/Application Signals for the demo backend."
  default     = true
}

variable "demo_create_sns_topic" {
  type        = bool
  description = "Create an SNS topic for demo alarm notifications."
  default     = false
}
