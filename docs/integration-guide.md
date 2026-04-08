# Integration guide

## Prerequisites

- Terraform >= 1.6
- AWS provider ~> 5.0
- An ECS service on the EC2 launch type, running behind an ALB
- Application logs already flowing to CloudWatch Logs in structured JSON format
- Container Insights enabled on the ECS cluster

---

## Minimum required log format

The Logs Insights queries expect these fields in each log line. Your application must emit structured JSON to stdout/stderr.

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "level": "info",
  "message": "request completed",
  "route": "/api/items",
  "method": "GET",
  "statusCode": 200,
  "durationMs": 45,
  "requestId": "abc123",
  "sourceIp": "203.0.113.1"
}
```

Fields used by specific queries:

| Field        | Used by                                        |
|--------------|------------------------------------------------|
| `level`      | Latest errors, error rate over time            |
| `statusCode` | Top failing routes, error rate, request volume |
| `route`      | All route-level queries                        |
| `durationMs` | Slowest requests, P99 latency by route         |
| `sourceIp`   | Noisy callers                                  |

---

## Usage — ECS service adapter

```hcl
module "observability" {
  source = "github.com/your-org/aws-observability-dashboard//modules/adapters/ecs_service"

  project     = "my-app"
  environment = "production"
  region      = "eu-west-2"

  # ECS inputs
  ecs_cluster_name = "my-cluster"
  ecs_service_name = "my-service"

  # ALB inputs — use .arn_suffix from your aws_lb / aws_lb_target_group resources
  alb_arn_suffix          = aws_lb.main.arn_suffix
  target_group_arn_suffix = aws_lb_target_group.main.arn_suffix

  # Logging
  log_group_names = ["/ecs/my-app/production"]

  # Alarm notifications (optional)
  create_sns_topic = true

  # Canaries (optional)
  enable_canaries              = true
  frontend_url                 = "https://my-app.example.com"
  api_endpoint                 = "https://my-app.example.com/health"
  canary_artifacts_bucket_name = aws_s3_bucket.canary_artifacts.bucket
}
```

---

## Variable reference

### Required

| Variable                  | Type           | Description                                               |
|---------------------------|----------------|-----------------------------------------------------------|
| `project`                 | string         | Project name — prefixes all resource names                |
| `environment`             | string         | Environment name (sandbox / staging / production)         |
| `region`                  | string         | AWS region                                                |
| `ecs_cluster_name`        | string         | ECS cluster name                                          |
| `ecs_service_name`        | string         | ECS service name                                          |
| `alb_arn_suffix`          | string         | ALB `arn_suffix` attribute                                |
| `target_group_arn_suffix` | string         | Target group `arn_suffix` attribute                       |
| `log_group_names`         | list(string)   | CloudWatch log group names                                |

### Optional

| Variable                       | Default           | Description                                               |
|--------------------------------|-------------------|-----------------------------------------------------------|
| `sns_topic_arn`                | null              | Existing SNS topic ARN for alarm notifications            |
| `create_sns_topic`             | false             | Create a new SNS topic                                    |
| `alb_5xx_threshold`            | 10                | ALB 5xx count threshold per period                        |
| `alb_latency_p99_threshold_seconds` | 2           | ALB P99 latency threshold in seconds                      |
| `ecs_cpu_threshold_percent`    | 80                | ECS CPU % threshold                                       |
| `ecs_memory_threshold_percent` | 80                | ECS memory % threshold                                    |
| `enable_canaries`              | false             | Provision Synthetics canaries                             |
| `frontend_url`                 | null              | Frontend URL for health-check canary                      |
| `api_endpoint`                 | null              | API URL for API canary (omit to skip)                     |
| `canary_artifacts_bucket_name` | null              | S3 bucket for canary artifacts                            |
| `canary_schedule_expression`   | "rate(5 minutes)" | Canary run schedule                                       |

---

## Outputs

```hcl
# Dashboard names — open directly in the CloudWatch console
module.observability.dashboard_names
# => { overview = "my-app-production-overview", service = "...", ... }

# Alarm ARNs — reference in other modules or EventBridge rules
module.observability.alarm_arns

# Canary names
module.observability.frontend_canary_name
module.observability.api_canary_name
```

---

## ALB ARN suffix — finding the right value

The CloudWatch ALB metrics use the `arn_suffix` rather than the full ARN. In Terraform:

```hcl
resource "aws_lb" "main" { ... }

# Use this in the adapter:
alb_arn_suffix = aws_lb.main.arn_suffix
# Example value: "app/my-app-production-alb/1234567890abcdef"
```

---

## Enabling Container Insights

Container Insights must be enabled on the ECS cluster for the ECS metric alarms and dashboard widgets to have data.

```hcl
resource "aws_ecs_cluster" "main" {
  name = "my-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

---

## Structured logging setup — Node.js example

```js
function log(level, message, fields = {}) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields,
  }));
}

// In your request handler:
log("info", "request completed", {
  route: req.path,
  method: req.method,
  statusCode: res.statusCode,
  durationMs: Date.now() - req.startTime,
  requestId: req.requestId,
  sourceIp: req.ip,
});
```

---

## Application Signals (Level 2 — optional)

For service maps and distributed traces, follow the [AWS ECS Application Signals setup guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). This package does not provision Application Signals infrastructure automatically — it requires manual instrumentation of the target application and a CloudWatch agent daemon task.
