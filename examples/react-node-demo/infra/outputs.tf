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

output "api_health_url" {
  description = "Health endpoint URL for the demo API."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}/health"
}

# ── ECR repository ────────────────────────────────────────────────────────────

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

output "alb_arn" {
  description = "Application Load Balancer ARN for the demo workload."
  value       = aws_lb.demo.arn
}

output "backend_target_group_arn" {
  description = "ALB target group ARN for the demo backend service."
  value       = aws_lb_target_group.backend.arn
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.demo.arn
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

output "backend_service_arn" {
  description = "ECS backend service ARN."
  value       = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.demo.name}/${aws_ecs_service.backend.name}"
}

# ── Observability ─────────────────────────────────────────────────────────────

output "log_group_names" {
  description = "CloudWatch log group names for the demo services."
  value       = [aws_cloudwatch_log_group.backend.name]
}

output "canary_artifacts_bucket_name" {
  description = "S3 bucket name used for demo canary artifacts. Null when canaries are disabled."
  value       = var.enable_canaries ? aws_s3_bucket.canary_artifacts[0].bucket : null
}

output "tracing_service_name" {
  description = "Application Signals service name emitted by the demo backend when tracing is enabled."
  value       = local.tracing_service_name
}
