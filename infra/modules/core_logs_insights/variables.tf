variable "project" {
  type        = string
  description = "Project name used for naming query definitions."
}

variable "environment" {
  type        = string
  description = "Environment name used for naming query definitions."
}

variable "log_group_names" {
  type        = list(string)
  description = "List of CloudWatch log group names to scope each saved query against."
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
