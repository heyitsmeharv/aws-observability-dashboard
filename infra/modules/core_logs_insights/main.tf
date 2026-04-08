locals {
  query_prefix = "${var.project}/${var.environment}"
}

# ── Error analysis ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "latest_errors" {
  name = "${local.query_prefix}/errors/latest-errors"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, level, statusCode, route, @message
    | filter level = "error" or statusCode >= 500
    | sort @timestamp desc
    | limit 100
  EOQ
}

resource "aws_cloudwatch_query_definition" "top_failing_routes" {
  name = "${local.query_prefix}/errors/top-failing-routes"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields route, statusCode
    | filter statusCode >= 400
    | stats count(*) as errorCount by route, statusCode
    | sort errorCount desc
    | limit 20
  EOQ
}

resource "aws_cloudwatch_query_definition" "error_rate_over_time" {
  name = "${local.query_prefix}/errors/error-rate-over-time"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, statusCode
    | filter ispresent(statusCode)
    | stats
        sum(statusCode >= 500) as serverErrors,
        sum(statusCode >= 400 and statusCode < 500) as clientErrors,
        count(*) as totalRequests
      by bin(5m)
    | sort @timestamp asc
  EOQ
}

# ── Latency analysis ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "slowest_requests" {
  name = "${local.query_prefix}/latency/slowest-requests"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, route, durationMs, statusCode, @requestId
    | filter ispresent(durationMs)
    | sort durationMs desc
    | limit 50
  EOQ
}

resource "aws_cloudwatch_query_definition" "p99_latency_by_route" {
  name = "${local.query_prefix}/latency/p99-by-route"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields route, durationMs
    | filter ispresent(durationMs) and ispresent(route)
    | stats
        pct(durationMs, 99) as p99Ms,
        pct(durationMs, 95) as p95Ms,
        pct(durationMs, 50) as p50Ms,
        count(*) as requestCount
      by route
    | sort p99Ms desc
  EOQ
}

# ── Traffic analysis ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "request_volume_over_time" {
  name = "${local.query_prefix}/traffic/request-volume-over-time"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, route, statusCode
    | filter ispresent(route)
    | stats count(*) as requestCount by bin(5m)
    | sort @timestamp asc
  EOQ
}

resource "aws_cloudwatch_query_definition" "request_volume_by_route" {
  name = "${local.query_prefix}/traffic/request-volume-by-route"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields route
    | filter ispresent(route)
    | stats count(*) as requestCount by route
    | sort requestCount desc
    | limit 20
  EOQ
}

resource "aws_cloudwatch_query_definition" "noisy_callers" {
  name = "${local.query_prefix}/traffic/noisy-callers"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields sourceIp, route
    | filter ispresent(sourceIp)
    | stats count(*) as requestCount by sourceIp
    | sort requestCount desc
    | limit 20
  EOQ
}

# ── Deploy-window helpers ─────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "deploy_window_errors" {
  name = "${local.query_prefix}/deploy/error-rate-1min-buckets"

  log_group_names = var.log_group_names

  # Useful during a deploy: run this scoped to the deploy window
  # to compare pre- and post-deploy error counts.
  query_string = <<-EOQ
    fields @timestamp, level, statusCode, route, @message
    | filter level = "error" or statusCode >= 500
    | stats count(*) as errorCount by bin(1m)
    | sort @timestamp asc
  EOQ
}

resource "aws_cloudwatch_query_definition" "deploy_window_latency" {
  name = "${local.query_prefix}/deploy/latency-1min-buckets"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, durationMs
    | filter ispresent(durationMs)
    | stats
        pct(durationMs, 99) as p99Ms,
        pct(durationMs, 50) as p50Ms,
        count(*) as requestCount
      by bin(1m)
    | sort @timestamp asc
  EOQ
}
