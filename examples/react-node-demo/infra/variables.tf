variable "project" {
  type        = string
  description = "Project name used for naming and tagging all resources."
  default     = "obs-demo"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "sandbox"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-west-2"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy into. Leave null to use the default VPC."
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ALB and ECS instances. Leave empty to discover subnets from the default VPC."
  default     = []
}

# ── ECS / EC2 ─────────────────────────────────────────────────────────────────

variable "instance_type" {
  type        = string
  description = "EC2 instance type for ECS container instances."
  default     = "t3.small"
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of ECS EC2 container instances."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of ECS EC2 container instances for the Auto Scaling group."
  default     = 3
}

# ── Container images ──────────────────────────────────────────────────────────

variable "backend_image_tag" {
  type        = string
  description = "Docker image tag for the Node API. Defaults to 'latest' — override after pushing to ECR."
  default     = "latest"
}

# ── Observability ─────────────────────────────────────────────────────────────

variable "enable_canaries" {
  type        = bool
  description = "Provision CloudWatch Synthetics canaries for outside-in monitoring."
  default     = false
}

variable "create_sns_topic" {
  type        = bool
  description = "Create an SNS topic for alarm notifications."
  default     = false
}
