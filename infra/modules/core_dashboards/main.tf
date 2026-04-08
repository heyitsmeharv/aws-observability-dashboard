locals {
  name_prefix = "${var.project}-${var.environment}"

  # Full ARNs required by the alarm widget type (names are rejected by the API)
  all_alarm_arns = compact([
    var.alarm_arns.alb_5xx,
    var.alarm_arns.alb_target_5xx,
    var.alarm_arns.alb_latency_p99,
    var.alarm_arns.alb_unhealthy_hosts,
    var.alarm_arns.ecs_running_tasks,
    var.alarm_arns.ecs_cpu,
    var.alarm_arns.ecs_memory,
    try(var.alarm_arns.canary_failure, null),
  ])

  # Primary log group for Logs Insights widgets (first in the list)
  primary_log_group = var.log_group_names[0]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}"

  dashboard_body = jsonencode({
    widgets = [

      # ════════════════════════════════════════════════════════════════════════
      # Header
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# ${var.project} — ${var.environment}\nCluster: `${var.ecs_cluster_name}` · Service: `${var.ecs_service_name}` · Region: `${var.region}`"
        }
      },

      # ════════════════════════════════════════════════════════════════════════
      # Alarm status
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "alarm"
        x      = 0
        y      = 2
        width  = 24
        height = 6
        properties = {
          title  = "Alarm Status"
          alarms = local.all_alarm_arns
        }
      },

      # ════════════════════════════════════════════════════════════════════════
      # Front door
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "text"
        x      = 0
        y      = 8
        width  = 24
        height = 1
        properties = {
          markdown = "### Front door"
        }
      },

      # Request count by status class (stacked)
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 12
        height = 6
        properties = {
          title   = "Request Count by Status Class"
          region  = var.region
          view    = "timeSeries"
          stacked = true
          period  = 60
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "2xx", color = "#2ca02c" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_3XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "3xx", color = "#1f77b4" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "4xx", color = "#ff7f0e" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "5xx", color = "#d62728" }],
          ]
        }
      },

      # Latency percentiles
      {
        type   = "metric"
        x      = 12
        y      = 9
        width  = 12
        height = 6
        properties = {
          title  = "Target Response Time (P50 / P95 / P99)"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50", label = "P50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95", label = "P95", color = "#ff7f0e" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99", label = "P99", color = "#d62728" }],
          ]
        }
      },

      # ALB 5xx errors
      {
        type   = "metric"
        x      = 0
        y      = 15
        width  = 8
        height = 6
        properties = {
          title  = "ALB 5xx Errors"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ELB 5xx", color = "#d62728" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "Target 5xx", color = "#ff7f0e" }],
          ]
        }
      },

      # Rejected connections
      {
        type   = "metric"
        x      = 8
        y      = 15
        width  = 8
        height = 6
        properties = {
          title  = "ALB Rejected Connections"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RejectedConnectionCount", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },

      # Request processing time P99
      {
        type   = "metric"
        x      = 16
        y      = 15
        width  = 8
        height = 6
        properties = {
          title  = "ALB Request Processing Time (P99)"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestProcessingTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99" }]
          ]
        }
      },

      # ════════════════════════════════════════════════════════════════════════
      # ECS health
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "text"
        x      = 0
        y      = 21
        width  = 24
        height = 1
        properties = {
          markdown = "### ECS health"
        }
      },

      # CPU gauge
      {
        type   = "metric"
        x      = 0
        y      = 22
        width  = 8
        height = 6
        properties = {
          title  = "ECS CPU Utilisation"
          region = var.region
          view   = "gauge"
          stat   = "Average"
          period = 60
          yAxis  = { left = { min = 0, max = 100 } }
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
        }
      },

      # Memory gauge
      {
        type   = "metric"
        x      = 8
        y      = 22
        width  = 8
        height = 6
        properties = {
          title  = "ECS Memory Utilised (MB)"
          region = var.region
          view   = "gauge"
          stat   = "Average"
          period = 60
          yAxis  = { left = { min = 0, max = 1024 } }
          metrics = [
            ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
        }
      },

      # ALB active connections gauge
      {
        type   = "metric"
        x      = 16
        y      = 22
        width  = 8
        height = 6
        properties = {
          title  = "ALB Active Connections"
          region = var.region
          view   = "gauge"
          stat   = "Average"
          period = 60
          yAxis  = { left = { min = 0, max = 1024 } }
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },

      # Healthy / unhealthy host count
      {
        type   = "metric"
        x      = 0
        y      = 28
        width  = 12
        height = 6
        properties = {
          title  = "ALB Healthy / Unhealthy Host Count"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum", label = "Healthy", color = "#2ca02c" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Maximum", label = "Unhealthy", color = "#d62728" }],
          ]
        }
      },

      # Running vs desired task count
      {
        type   = "metric"
        x      = 12
        y      = 28
        width  = 12
        height = 6
        properties = {
          title  = "ECS Running vs Desired Task Count"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { label = "Running", color = "#2ca02c" }],
            ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { label = "Desired", color = "#1f77b4" }],
          ]
        }
      },

      # ════════════════════════════════════════════════════════════════════════
      # Log analysis
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "text"
        x      = 0
        y      = 34
        width  = 24
        height = 1
        properties = {
          markdown = "### Log analysis — log groups: ${join(", ", formatlist("`%s`", var.log_group_names))}"
        }
      },

      # Latest errors table
      {
        type   = "log"
        x      = 0
        y      = 35
        width  = 24
        height = 8
        properties = {
          title  = "Latest Errors (last 1 hour)"
          region = var.region
          view   = "table"
          query  = "SOURCE '${local.primary_log_group}' | fields @timestamp, level, statusCode, route, @message | filter level = \"error\" or statusCode >= 500 | sort @timestamp desc | limit 50"
        }
      },

      # Error rate over time
      {
        type   = "log"
        x      = 0
        y      = 43
        width  = 12
        height = 6
        properties = {
          title  = "Error Rate Over Time (5-min buckets)"
          region = var.region
          view   = "bar"
          query  = "SOURCE '${local.primary_log_group}' | filter statusCode >= 500 or level = \"error\" | stats count(*) as errors by bin(5m) | sort @timestamp asc"
        }
      },

      # Request volume over time
      {
        type   = "log"
        x      = 12
        y      = 43
        width  = 12
        height = 6
        properties = {
          title  = "Request Volume Over Time (5-min buckets)"
          region = var.region
          view   = "bar"
          query  = "SOURCE '${local.primary_log_group}' | filter ispresent(route) | stats count(*) as requestCount by bin(5m) | sort @timestamp asc"
        }
      },

      # Top failing routes
      {
        type   = "log"
        x      = 0
        y      = 49
        width  = 12
        height = 6
        properties = {
          title  = "Top Failing Routes"
          region = var.region
          view   = "table"
          query  = "SOURCE '${local.primary_log_group}' | filter statusCode >= 400 | stats count(*) as errorCount by route, statusCode | sort errorCount desc | limit 20"
        }
      },

      # P99 latency by route
      {
        type   = "log"
        x      = 12
        y      = 49
        width  = 12
        height = 6
        properties = {
          title  = "P99 Latency by Route"
          region = var.region
          view   = "table"
          query  = "SOURCE '${local.primary_log_group}' | filter ispresent(durationMs) | stats pct(durationMs, 99) as p99Ms, pct(durationMs, 50) as p50Ms, count(*) as requests by route | sort p99Ms desc"
        }
      },

      # ════════════════════════════════════════════════════════════════════════
      # Runbook links
      # ════════════════════════════════════════════════════════════════════════

      {
        type   = "text"
        x      = 0
        y      = 55
        width  = 24
        height = 3
        properties = {
          markdown = "### Quick links\n- [ECS service console](https://console.aws.amazon.com/ecs/v2/clusters/${var.ecs_cluster_name}/services/${var.ecs_service_name})\n- [Logs Insights](https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#logsV2:logs-insights)\n- [CloudWatch Alarms](https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#alarmsV2:)"
        }
      },
    ]
  })
}
