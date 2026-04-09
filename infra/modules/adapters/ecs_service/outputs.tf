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

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.dashboards.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN."
  value       = module.dashboards.dashboard_arn
}

output "tracing_service_name" {
  description = "Tracing service name used for Application Signals and trace drilldowns. Null when tracing is disabled."
  value       = var.tracing_enabled ? local.resolved_tracing_service_name : null
}

output "xray_trace_map_url" {
  description = "Trace map console URL. Null when tracing is disabled."
  value       = var.tracing_enabled ? "https://console.aws.amazon.com/xray/home?region=${var.region}#/service-map" : null
}

output "xray_traces_url" {
  description = "Trace console URL filtered to the tracing service. Null when tracing is disabled."
  value       = var.tracing_enabled ? "https://console.aws.amazon.com/xray/home?region=${var.region}#/traces?filter=${urlencode(format("service(\"%s\")", local.resolved_tracing_service_name))}" : null
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
