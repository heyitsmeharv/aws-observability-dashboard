output "dashboard_names" {
  description = "Map of dashboard role to CloudWatch dashboard name."
  value = {
    overview     = aws_cloudwatch_dashboard.overview.dashboard_name
    service      = aws_cloudwatch_dashboard.service.dashboard_name
    operations   = aws_cloudwatch_dashboard.operations.dashboard_name
    log_analysis = aws_cloudwatch_dashboard.log_analysis.dashboard_name
  }
}

output "dashboard_arns" {
  description = "Map of dashboard role to CloudWatch dashboard ARN."
  value = {
    overview     = aws_cloudwatch_dashboard.overview.dashboard_arn
    service      = aws_cloudwatch_dashboard.service.dashboard_arn
    operations   = aws_cloudwatch_dashboard.operations.dashboard_arn
    log_analysis = aws_cloudwatch_dashboard.log_analysis.dashboard_arn
  }
}
