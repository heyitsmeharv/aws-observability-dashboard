locals {
  name_prefix   = "${var.project}-${var.environment}"
  alarm_actions = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "core_alarms"
  }
}

# ── ALB alarms ──────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx-count"
  alarm_description   = "ALB is returning an elevated number of 5xx errors. Check ECS service health and application logs."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${local.name_prefix}-alb-target-5xx-count"
  alarm_description   = "ECS targets behind the ALB are returning 5xx errors. Indicates an application-level problem."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p99" {
  alarm_name          = "${local.name_prefix}-alb-latency-p99"
  alarm_description   = "ALB P99 target response time exceeds threshold. Application may be slow or under load."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = var.period_seconds
  extended_statistic  = "p99"
  threshold           = var.alb_latency_p99_threshold_seconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-alb-unhealthy-host-count"
  alarm_description   = "One or more targets in the ALB target group are unhealthy. ECS tasks may be failing health checks."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.period_seconds
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# ── ECS / Container Insights alarms ─────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ecs_running_task_count" {
  alarm_name          = "${local.name_prefix}-ecs-running-task-count"
  alarm_description   = "ECS service has fewer running tasks than the minimum expected. Possible task crashes or placement failures."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = var.period_seconds
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${local.name_prefix}-ecs-cpu-utilisation"
  alarm_description   = "ECS service CPU utilisation is above threshold. Consider scaling out or investigating a CPU spike."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.period_seconds
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${local.name_prefix}-ecs-memory-utilisation"
  alarm_description   = "ECS service memory utilisation is above threshold. Risk of OOM kills if sustained."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.period_seconds
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}

# ── Canary alarm ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "canary_failure" {
  count = var.canary_name != null ? 1 : 0

  alarm_name          = "${local.name_prefix}-canary-success-rate"
  alarm_description   = "CloudWatch Synthetics canary '${var.canary_name}' success rate has dropped below 100%. The endpoint may be unreachable or returning errors."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = var.canary_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.common_tags
}
