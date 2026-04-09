output "alarm_arns" {
  value = module.service.alarm_arns
}

output "alarm_names" {
  value = module.service.alarm_names
}

output "dashboard_name" {
  value = module.service.dashboard_name
}

output "dashboard_arn" {
  value = module.service.dashboard_arn
}

output "tracing_service_name" {
  value = module.service.tracing_service_name
}

output "xray_trace_map_url" {
  value = module.service.xray_trace_map_url
}

output "xray_traces_url" {
  value = module.service.xray_traces_url
}

output "query_definition_ids" {
  value = module.service.query_definition_ids
}

output "frontend_canary_name" {
  value = module.service.frontend_canary_name
}

output "api_canary_name" {
  value = module.service.api_canary_name
}

output "sns_topic_arn" {
  value = module.service.sns_topic_arn
}
