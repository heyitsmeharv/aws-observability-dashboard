# ── App endpoints ─────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "Public DNS name of the demo Application Load Balancer."
  value       = aws_lb.demo.dns_name
}

output "frontend_url" {
  description = "URL for the demo React frontend (served via CloudFront)."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "api_url" {
  description = "Base URL for the demo Node API."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}/api"
}

# ── ECR repository ────────────────────────────────────────────────────────────

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

# ── ECS ───────────────────────────────────────────────────────────────────────

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.demo.name
}

output "backend_service_name" {
  description = "ECS backend service name."
  value       = aws_ecs_service.backend.name
}

# ── Observability ─────────────────────────────────────────────────────────────

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "alarm_names" {
  description = "CloudWatch alarm names created by the observability module."
  value       = module.observability.alarm_names
}

output "trace_map_url" {
  description = "Trace map URL for the demo backend. Null when tracing is disabled."
  value       = module.observability.xray_trace_map_url
}

output "trace_details_url" {
  description = "Trace details URL for the demo backend. Null when tracing is disabled."
  value       = module.observability.xray_traces_url
}

output "log_group_names" {
  description = "CloudWatch log group names for the demo services."
  value       = [aws_cloudwatch_log_group.backend.name]
}
