output "query_definition_ids" {
  description = "Map of logical query keys to their CloudWatch Logs Insights query definition IDs."
  value = {
    latest_errors            = aws_cloudwatch_query_definition.latest_errors.id
    top_failing_routes       = aws_cloudwatch_query_definition.top_failing_routes.id
    error_rate_over_time     = aws_cloudwatch_query_definition.error_rate_over_time.id
    slowest_requests         = aws_cloudwatch_query_definition.slowest_requests.id
    p99_latency_by_route     = aws_cloudwatch_query_definition.p99_latency_by_route.id
    request_volume_over_time = aws_cloudwatch_query_definition.request_volume_over_time.id
    request_volume_by_route  = aws_cloudwatch_query_definition.request_volume_by_route.id
    noisy_callers            = aws_cloudwatch_query_definition.noisy_callers.id
    deploy_window_errors     = aws_cloudwatch_query_definition.deploy_window_errors.id
    deploy_window_latency    = aws_cloudwatch_query_definition.deploy_window_latency.id
  }
}
