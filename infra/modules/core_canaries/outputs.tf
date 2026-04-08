output "frontend_canary_name" {
  description = "Name of the frontend health-check canary. Pass to core_alarms as canary_name."
  value       = aws_synthetics_canary.frontend.name
}

output "frontend_canary_arn" {
  description = "ARN of the frontend health-check canary."
  value       = aws_synthetics_canary.frontend.arn
}

output "api_canary_name" {
  description = "Name of the API health-check canary. Null if api_endpoint was not provided."
  value       = try(aws_synthetics_canary.api[0].name, null)
}

output "api_canary_arn" {
  description = "ARN of the API health-check canary. Null if api_endpoint was not provided."
  value       = try(aws_synthetics_canary.api[0].arn, null)
}

output "canary_role_arn" {
  description = "ARN of the IAM execution role shared by all canaries in this module."
  value       = aws_iam_role.canary.arn
}
