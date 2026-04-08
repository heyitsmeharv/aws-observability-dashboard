locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "core_canaries"
  }
}

# ── IAM role for canary execution ─────────────────────────────────────────────

data "aws_iam_policy_document" "canary_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "canary" {
  name               = "${local.name_prefix}-canary-execution"
  assume_role_policy = data.aws_iam_policy_document.canary_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "canary_permissions" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid    = "S3Artifacts"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.artifacts_bucket_name}",
      "arn:aws:s3:::${var.artifacts_bucket_name}/*",
    ]
  }

  statement {
    sid    = "S3ListArtifacts"
    effect = "Allow"
    actions = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    actions = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CloudWatchSynthetics"]
    }
  }

  statement {
    sid    = "XRay"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "canary" {
  name   = "${local.name_prefix}-canary-permissions"
  role   = aws_iam_role.canary.id
  policy = data.aws_iam_policy_document.canary_permissions.json
}

# ── Zip canary scripts ────────────────────────────────────────────────────────

data "archive_file" "frontend_canary" {
  type        = "zip"
  output_path = "${path.module}/.build/frontend-health-check.zip"

  source {
    content  = file("${path.module}/scripts/frontend-health-check.js")
    filename = "nodejs/node_modules/frontend-health-check.js"
  }
}

data "archive_file" "api_canary" {
  count       = var.api_endpoint != null ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.build/api-health-check.zip"

  source {
    content  = file("${path.module}/scripts/api-health-check.js")
    filename = "nodejs/node_modules/api-health-check.js"
  }
}

# ── Frontend health-check canary ──────────────────────────────────────────────

resource "aws_synthetics_canary" "frontend" {
  name                 = "${local.name_prefix}-frontend"
  artifact_s3_location = "s3://${var.artifacts_bucket_name}/canaries/${local.name_prefix}-frontend/"
  execution_role_arn   = aws_iam_role.canary.arn
  runtime_version      = var.runtime_version
  handler  = "frontend-health-check.handler"
  zip_file = data.archive_file.frontend_canary.output_path

  schedule {
    expression = var.schedule_expression
  }

  run_config {
    timeout_in_seconds = var.timeout_seconds
    environment_variables = {
      TARGET_URL        = var.frontend_url
      EXPECTED_SELECTOR = "#root"
    }
  }

  success_retention_period = var.success_retention_days
  failure_retention_period = var.failure_retention_days

  start_canary = true

  tags = local.common_tags
}

# ── API health-check canary ───────────────────────────────────────────────────

resource "aws_synthetics_canary" "api" {
  count = var.api_endpoint != null ? 1 : 0

  name                 = "${local.name_prefix}-api"
  artifact_s3_location = "s3://${var.artifacts_bucket_name}/canaries/${local.name_prefix}-api/"
  execution_role_arn   = aws_iam_role.canary.arn
  runtime_version      = var.runtime_version
  handler              = "api-health-check.handler"
  zip_file             = data.archive_file.api_canary[0].output_path

  schedule {
    expression = var.schedule_expression
  }

  run_config {
    timeout_in_seconds = var.timeout_seconds
    environment_variables = {
      TARGET_URL      = var.api_endpoint
      EXPECTED_STATUS = "200"
      MAX_DURATION_MS = "3000"
    }
  }

  success_retention_period = var.success_retention_days
  failure_retention_period = var.failure_retention_days

  start_canary = true

  tags = local.common_tags
}
