output "alarm_arns" {
  description = "Map of logical alarm keys to their ARNs. Pass to the dashboards module for alarm widgets."
  value = {
    alb_5xx              = aws_cloudwatch_metric_alarm.alb_5xx.arn
    alb_target_5xx       = aws_cloudwatch_metric_alarm.alb_target_5xx.arn
    alb_latency_p99      = aws_cloudwatch_metric_alarm.alb_latency_p99.arn
    alb_unhealthy_hosts  = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn
    ecs_running_tasks    = aws_cloudwatch_metric_alarm.ecs_running_task_count.arn
    ecs_cpu              = aws_cloudwatch_metric_alarm.ecs_cpu.arn
    ecs_memory           = aws_cloudwatch_metric_alarm.ecs_memory.arn
    canary_failure       = try(aws_cloudwatch_metric_alarm.canary_failure[0].arn, null)
  }
}

output "alarm_names" {
  description = "Map of logical alarm keys to their CloudWatch alarm names. Used for alarm widgets in dashboards."
  value = {
    alb_5xx              = aws_cloudwatch_metric_alarm.alb_5xx.alarm_name
    alb_target_5xx       = aws_cloudwatch_metric_alarm.alb_target_5xx.alarm_name
    alb_latency_p99      = aws_cloudwatch_metric_alarm.alb_latency_p99.alarm_name
    alb_unhealthy_hosts  = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.alarm_name
    ecs_running_tasks    = aws_cloudwatch_metric_alarm.ecs_running_task_count.alarm_name
    ecs_cpu              = aws_cloudwatch_metric_alarm.ecs_cpu.alarm_name
    ecs_memory           = aws_cloudwatch_metric_alarm.ecs_memory.alarm_name
    canary_failure       = try(aws_cloudwatch_metric_alarm.canary_failure[0].alarm_name, null)
  }
}
