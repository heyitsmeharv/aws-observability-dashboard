output "alarm_arns" {
  description = "Map of logical alarm keys to ARNs."
  value       = module.observability.alarm_arns
}

output "alarm_names" {
  description = "Map of logical alarm keys to CloudWatch alarm names."
  value       = module.observability.alarm_names
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN."
  value       = module.observability.dashboard_arn
}

output "dashboard_url" {
  description = "CloudWatch console URL for the dashboard."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.service.region}#dashboards:name=${module.observability.dashboard_name}"
}

output "tracing_service_name" {
  description = "Tracing service name used for X-Ray/Application Signals drilldowns. Null when tracing is disabled."
  value       = module.observability.tracing_service_name
}

output "xray_trace_map_url" {
  description = "AWS X-Ray trace map URL. Null when tracing is disabled."
  value       = module.observability.xray_trace_map_url
}

output "xray_traces_url" {
  description = "AWS X-Ray traces URL filtered to the tracing service. Null when tracing is disabled."
  value       = module.observability.xray_traces_url
}

output "query_definition_ids" {
  description = "Map of logical query keys to Logs Insights query definition IDs."
  value       = module.observability.query_definition_ids
}

output "logs_insights_url" {
  description = "CloudWatch Logs Insights console URL for this region."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.service.region}#logsV2:logs-insights"
}

output "alarms_url" {
  description = "CloudWatch Alarms console URL for this region."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.service.region}#alarmsV2:"
}

output "frontend_canary_name" {
  description = "Frontend canary name. Null when canaries are disabled."
  value       = module.observability.frontend_canary_name
}

output "api_canary_name" {
  description = "API canary name. Null when canaries are disabled or no API endpoint is configured."
  value       = module.observability.api_canary_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS alarms topic. Null when no topic was created or provided."
  value       = module.observability.sns_topic_arn
}
