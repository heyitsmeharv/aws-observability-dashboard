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
