output "alarm_arns" {
  description = "Map of logical alarm keys to ARNs."
  value       = try(module.ecs_ec2_alb[0].alarm_arns, module.ecs_fargate_alb[0].alarm_arns, module.ec2_alb[0].alarm_arns)
}

output "alarm_names" {
  description = "Map of logical alarm keys to CloudWatch alarm names."
  value       = try(module.ecs_ec2_alb[0].alarm_names, module.ecs_fargate_alb[0].alarm_names, module.ec2_alb[0].alarm_names)
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = try(module.ecs_ec2_alb[0].dashboard_name, module.ecs_fargate_alb[0].dashboard_name, module.ec2_alb[0].dashboard_name)
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN."
  value       = try(module.ecs_ec2_alb[0].dashboard_arn, module.ecs_fargate_alb[0].dashboard_arn, module.ec2_alb[0].dashboard_arn)
}

output "dashboard_url" {
  description = "CloudWatch console URL for the dashboard."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.service.region}#dashboards:name=${try(module.ecs_ec2_alb[0].dashboard_name, module.ecs_fargate_alb[0].dashboard_name, module.ec2_alb[0].dashboard_name)}"
}

output "tracing_service_name" {
  description = "Tracing service name used for Application Signals and trace drilldowns. Null when tracing is disabled."
  value       = try(module.ecs_ec2_alb[0].tracing_service_name, module.ecs_fargate_alb[0].tracing_service_name, module.ec2_alb[0].tracing_service_name)
}

output "xray_trace_map_url" {
  description = "Trace map console URL. Null when tracing is disabled."
  value       = try(module.ecs_ec2_alb[0].xray_trace_map_url, module.ecs_fargate_alb[0].xray_trace_map_url, module.ec2_alb[0].xray_trace_map_url)
}

output "xray_traces_url" {
  description = "Trace console URL filtered to the tracing service. Null when tracing is disabled."
  value       = try(module.ecs_ec2_alb[0].xray_traces_url, module.ecs_fargate_alb[0].xray_traces_url, module.ec2_alb[0].xray_traces_url)
}

output "query_definition_ids" {
  description = "Map of logical query keys to Logs Insights query definition IDs."
  value       = try(module.ecs_ec2_alb[0].query_definition_ids, module.ecs_fargate_alb[0].query_definition_ids, module.ec2_alb[0].query_definition_ids)
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
  value       = try(module.ecs_ec2_alb[0].frontend_canary_name, module.ecs_fargate_alb[0].frontend_canary_name, module.ec2_alb[0].frontend_canary_name)
}

output "api_canary_name" {
  description = "API canary name. Null when canaries are disabled or no API endpoint is configured."
  value       = try(module.ecs_ec2_alb[0].api_canary_name, module.ecs_fargate_alb[0].api_canary_name, module.ec2_alb[0].api_canary_name)
}

output "sns_topic_arn" {
  description = "ARN of the SNS alarms topic. Null when no topic was created or provided."
  value       = try(module.ecs_ec2_alb[0].sns_topic_arn, module.ecs_fargate_alb[0].sns_topic_arn, module.ec2_alb[0].sns_topic_arn)
}
