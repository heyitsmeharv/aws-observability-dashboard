output "alb_dns_name" {
  description = "Public DNS name of the demo Application Load Balancer."
  value       = module.demo.alb_dns_name
}

output "frontend_url" {
  description = "URL for the demo React frontend."
  value       = module.demo.frontend_url
}

output "api_url" {
  description = "Base URL for the demo Node API."
  value       = module.demo.api_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for the demo frontend."
  value       = module.demo.cloudfront_domain_name
}

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend image."
  value       = module.demo.backend_ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.demo.ecs_cluster_name
}

output "backend_service_name" {
  description = "ECS backend service name."
  value       = module.demo.backend_service_name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "alarm_names" {
  description = "CloudWatch alarm names."
  value       = module.observability.alarm_names
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL."
  value       = module.observability.dashboard_url
}

output "trace_map_url" {
  description = "Trace map URL for the demo backend. Null when tracing is disabled."
  value       = module.observability.xray_trace_map_url
}

output "trace_details_url" {
  description = "Trace details URL for the demo backend. Null when tracing is disabled."
  value       = module.observability.xray_traces_url
}
