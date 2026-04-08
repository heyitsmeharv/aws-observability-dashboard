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

variable "canary_name" {
  type        = string
  description = "Name of the CloudWatch Synthetics canary to include on the service dashboard. Set to null to omit the canary widget."
  default     = null
}

variable "alarm_names" {
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
  description = "Map of alarm names from the core_alarms module. Used to render alarm widgets on dashboards."
}
