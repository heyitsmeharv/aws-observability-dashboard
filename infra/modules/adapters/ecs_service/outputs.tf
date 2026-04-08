# ── Alarm outputs ─────────────────────────────────────────────────────────────

output "alarm_arns" {
  description = "Map of logical alarm keys to ARNs."
  value       = module.alarms.alarm_arns
}

output "alarm_names" {
  description = "Map of logical alarm keys to CloudWatch alarm names."
  value       = module.alarms.alarm_names
}

# ── Dashboard outputs ─────────────────────────────────────────────────────────

output "dashboard_names" {
  description = "Map of dashboard role to CloudWatch dashboard name."
  value       = module.dashboards.dashboard_names
}

output "dashboard_arns" {
  description = "Map of dashboard role to CloudWatch dashboard ARN."
  value       = module.dashboards.dashboard_arns
}

# ── Logs Insights outputs ─────────────────────────────────────────────────────

output "query_definition_ids" {
  description = "Map of logical query keys to Logs Insights query definition IDs."
  value       = module.logs_insights.query_definition_ids
}

# ── Canary outputs ────────────────────────────────────────────────────────────

output "frontend_canary_name" {
  description = "Frontend canary name. Null when enable_canaries = false."
  value       = try(module.canaries[0].frontend_canary_name, null)
}

output "api_canary_name" {
  description = "API canary name. Null when enable_canaries = false or api_endpoint is not set."
  value       = try(module.canaries[0].api_canary_name, null)
}

# ── SNS outputs ───────────────────────────────────────────────────────────────

output "sns_topic_arn" {
  description = "ARN of the SNS alarms topic. Null when no topic was created or provided."
  value       = local.resolved_sns_topic_arn
}
