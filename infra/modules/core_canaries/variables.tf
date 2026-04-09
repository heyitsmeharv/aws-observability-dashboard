variable "project" {
  type        = string
  description = "Project name used for naming and tagging."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "artifacts_bucket_name" {
  type        = string
  description = "S3 bucket name for storing canary run artifacts (screenshots, HAR files, logs)."
}

variable "frontend_url" {
  type        = string
  description = "Fully-qualified URL for the frontend health-check canary to probe."
}

variable "api_endpoint" {
  type        = string
  description = "Fully-qualified URL for the API health canary to probe. Set to null to skip the API canary."
  default     = null
}

variable "schedule_expression" {
  type        = string
  description = "CloudWatch Synthetics schedule expression (e.g. 'rate(5 minutes)')."
  default     = "rate(5 minutes)"
}

variable "timeout_seconds" {
  type        = number
  description = "Maximum run time for each canary execution in seconds."
  default     = 60
}

variable "success_retention_days" {
  type        = number
  description = "Days to retain canary run data for successful runs."
  default     = 7
}

variable "failure_retention_days" {
  type        = number
  description = "Days to retain canary run data for failed runs."
  default     = 14
}

variable "runtime_version" {
  type        = string
  description = "CloudWatch Synthetics runtime version for the canary."
  default     = "syn-nodejs-puppeteer-9.1"
}

variable "enable_active_tracing" {
  type        = bool
  description = "When true, enables active X-Ray tracing for canary runs."
  default     = false
}
