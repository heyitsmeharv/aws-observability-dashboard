locals {
  query_prefix = "${var.project}/${var.environment}"
  log_fields   = var.log_field_names
}

# ── Error analysis ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "latest_errors" {
  name = "${local.query_prefix}/errors/latest-errors"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, ${local.log_fields.level}, ${local.log_fields.status_code}, ${local.log_fields.route}, @message
    | filter ${local.log_fields.level} = "error" or ${local.log_fields.status_code} >= 500
    | sort @timestamp desc
    | limit 100
  EOQ
}

resource "aws_cloudwatch_query_definition" "top_failing_routes" {
  name = "${local.query_prefix}/errors/top-failing-routes"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields ${local.log_fields.route}, ${local.log_fields.status_code}
    | filter ${local.log_fields.status_code} >= 400
    | stats count(*) as errorCount by ${local.log_fields.route}, ${local.log_fields.status_code}
    | sort errorCount desc
    | limit 20
  EOQ
}

resource "aws_cloudwatch_query_definition" "error_rate_over_time" {
  name = "${local.query_prefix}/errors/error-rate-over-time"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, ${local.log_fields.status_code}
    | filter ispresent(${local.log_fields.status_code})
    | stats
        sum(${local.log_fields.status_code} >= 500) as serverErrors,
        sum(${local.log_fields.status_code} >= 400 and ${local.log_fields.status_code} < 500) as clientErrors,
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
    fields @timestamp, ${local.log_fields.route}, ${local.log_fields.latency_ms}, ${local.log_fields.status_code}, ${local.log_fields.request_id}
    | filter ispresent(${local.log_fields.latency_ms})
    | sort ${local.log_fields.latency_ms} desc
    | limit 50
  EOQ
}

resource "aws_cloudwatch_query_definition" "p99_latency_by_route" {
  name = "${local.query_prefix}/latency/p99-by-route"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields ${local.log_fields.route}, ${local.log_fields.latency_ms}
    | filter ispresent(${local.log_fields.latency_ms}) and ispresent(${local.log_fields.route})
    | stats
        pct(${local.log_fields.latency_ms}, 99) as p99Ms,
        pct(${local.log_fields.latency_ms}, 95) as p95Ms,
        pct(${local.log_fields.latency_ms}, 50) as p50Ms,
        count(*) as requestCount
      by ${local.log_fields.route}
    | sort p99Ms desc
  EOQ
}

# ── Traffic analysis ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_query_definition" "request_volume_over_time" {
  name = "${local.query_prefix}/traffic/request-volume-over-time"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, ${local.log_fields.route}, ${local.log_fields.status_code}
    | filter ispresent(${local.log_fields.route})
    | stats count(*) as requestCount by bin(5m)
    | sort @timestamp asc
  EOQ
}

resource "aws_cloudwatch_query_definition" "request_volume_by_route" {
  name = "${local.query_prefix}/traffic/request-volume-by-route"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields ${local.log_fields.route}
    | filter ispresent(${local.log_fields.route})
    | stats count(*) as requestCount by ${local.log_fields.route}
    | sort requestCount desc
    | limit 20
  EOQ
}

resource "aws_cloudwatch_query_definition" "noisy_callers" {
  name = "${local.query_prefix}/traffic/noisy-callers"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields ${local.log_fields.source_ip}, ${local.log_fields.route}
    | filter ispresent(${local.log_fields.source_ip})
    | stats count(*) as requestCount by ${local.log_fields.source_ip}
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
    fields @timestamp, ${local.log_fields.level}, ${local.log_fields.status_code}, ${local.log_fields.route}, @message
    | filter ${local.log_fields.level} = "error" or ${local.log_fields.status_code} >= 500
    | stats count(*) as errorCount by bin(1m)
    | sort @timestamp asc
  EOQ
}

resource "aws_cloudwatch_query_definition" "deploy_window_latency" {
  name = "${local.query_prefix}/deploy/latency-1min-buckets"

  log_group_names = var.log_group_names

  query_string = <<-EOQ
    fields @timestamp, ${local.log_fields.latency_ms}
    | filter ispresent(${local.log_fields.latency_ms})
    | stats
        pct(${local.log_fields.latency_ms}, 99) as p99Ms,
        pct(${local.log_fields.latency_ms}, 50) as p50Ms,
        count(*) as requestCount
      by bin(1m)
    | sort @timestamp asc
  EOQ
}
