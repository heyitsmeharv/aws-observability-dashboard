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

## Usage — recommended public adapter

```hcl
module "observability" {
  source = "github.com/your-org/aws-observability-dashboard//infra/modules/adapters/platform_service"

  service = {
    name            = "my-app"
    environment     = "production"
    region          = "eu-west-2"
    kind            = "ecs_ec2_alb"
    ecs_service_arn = var.ecs_service_arn
    alb_arn         = var.alb_arn
    target_group_arn = var.target_group_arn
  }

  logging = {
    log_group_names = ["/ecs/my-app/production"]
  }

  dashboard = {
    owner       = "payments-team"
    runbook_url = "https://internal.example/runbooks/my-app"
  }

  alerts = {
    sns_topic_arn = aws_sns_topic.platform_alerts.arn
  }

  canaries = {
    enabled               = true
    frontend_url          = "https://my-app.example.com"
    api_endpoint          = "https://my-app.example.com/health"
    artifacts_bucket_name = aws_s3_bucket.canary_artifacts.bucket
  }

  tracing = {
    enabled = true
  }
}
```

---

## Onboarding an existing service

The intended integration path is to point the module at AWS resources that already exist. The module does not take ownership of your ECS service or ALB. Instead, it attaches a standard observability layer around them by creating new CloudWatch resources that reference those services. The recommended public contract is ARN-first: pass the ECS service ARN, ALB ARN, target group ARN, and log groups, and let the module derive the CloudWatch dimensions internally.

In v1, that means:

- A CloudWatch dashboard for the service
- CloudWatch alarms for ALB, ECS, and optional canary signals
- Logs Insights saved queries for the supplied log groups
- Optional Synthetics canaries for outside-in checks

If you also have a separate internal UI or demo dashboard, treat that as a consumer of the observability signals, not as a required dependency for onboarding.

---

## Contract overview

### `service` (required)

| Field                  | Type   | Description |
|------------------------|--------|-------------|
| `name`                 | string | Service/project name used in resource naming |
| `environment`          | string | Environment name such as `sandbox`, `staging`, or `production` |
| `region`               | string | AWS region |
| `kind`                 | string | Workload shape. v1 supports `ecs_ec2_alb` |
| `ecs_service_arn`      | string | Recommended public attachment point. The module derives cluster and service names from this ARN |
| `ecs_cluster_name`     | string | Optional compatibility input when you are not passing `ecs_service_arn` |
| `ecs_service_name`     | string | Optional compatibility input when you are not passing `ecs_service_arn` |
| `alb_arn`              | string | Full ALB ARN |
| `target_group_arn`     | string | Full target group ARN |

Provide either `ecs_service_arn` or both `ecs_cluster_name` and `ecs_service_name`.

### `logging` (required)

| Field             | Type         | Description |
|-------------------|--------------|-------------|
| `log_group_names` | list(string) | CloudWatch log group names. Saved queries use the full list; embedded dashboard log widgets use the first entry |
| `fields`          | object       | Optional field mappings when your logs do not use the default names |

Default log field mappings:

| Logical field | Default log field |
|---------------|-------------------|
| `level`       | `level` |
| `route`       | `route` |
| `method`      | `method` |
| `status_code` | `statusCode` |
| `latency_ms`  | `durationMs` |
| `request_id`  | `requestId` |
| `source_ip`   | `sourceIp` |

### `dashboard` (optional)

| Field         | Default | Description |
|---------------|---------|-------------|
| `owner`       | null    | Team/owner label shown in the dashboard header |
| `runbook_url` | null    | Runbook URL linked from the dashboard quick links |

### `alerts` (optional)

| Field                               | Default           | Description |
|-------------------------------------|-------------------|-------------|
| `sns_topic_arn`                     | null              | Existing SNS topic ARN for alarm notifications |
| `create_sns_topic`                  | false             | Create a new SNS topic if no ARN is supplied |
| `alb_5xx_threshold`                 | 10                | ALB 5xx count threshold per period |
| `alb_latency_p99_threshold_seconds` | 2                 | ALB P99 latency threshold in seconds |
| `ecs_cpu_threshold_percent`         | 80                | ECS CPU percentage threshold |
| `ecs_memory_threshold_percent`      | 80                | ECS memory percentage threshold |

### `canaries` (optional)

| Field                   | Default           | Description |
|-------------------------|-------------------|-------------|
| `enabled`               | false             | Provision Synthetics canaries |
| `frontend_url`          | null              | Frontend URL for the browser canary |
| `api_endpoint`          | null              | API health URL for the API canary |
| `artifacts_bucket_name` | null              | S3 bucket for canary artifacts |
| `schedule_expression`   | "rate(5 minutes)" | Canary run schedule |

### `tracing` (optional)

| Field                   | Default        | Description |
|-------------------------|----------------|-------------|
| `enabled`               | false          | Adds Application Signals / trace drilldowns to the dashboard and outputs |
| `service_name`          | `service.name` | Trace service name used for filtering and labels |
| `enable_canary_tracing` | `enabled`      | Enables active tracing for CloudWatch Synthetics canaries |

The reusable module only publishes tracing links and optional canary tracing. The monitored workload must still be instrumented separately with OpenTelemetry/Application Signals. The demo stack in `examples/react-node-demo` shows one ECS EC2 reference setup using a CloudWatch agent sidecar plus Node.js ESM auto-instrumentation.

---

## Outputs

The primary operator surface created by the package is the CloudWatch dashboard exposed through `dashboard_name`, `dashboard_arn`, and `dashboard_url`.

```hcl
# Dashboard identity
module.observability.dashboard_name
module.observability.dashboard_arn
module.observability.dashboard_url

# Tracing drilldown
module.observability.tracing_service_name
module.observability.xray_trace_map_url
module.observability.xray_traces_url

# Alarm references
module.observability.alarm_arns
module.observability.alarm_names

# Logs drilldown
module.observability.query_definition_ids
module.observability.logs_insights_url
module.observability.alarms_url

# Synthetic monitoring
module.observability.frontend_canary_name
module.observability.api_canary_name
```

---

## Logging field mappings

If your service logs use different field names, you can override them without rewriting the built-in queries or dashboard widgets:

```hcl
logging = {
  log_group_names = ["/ecs/my-app/production"]
  fields = {
    status_code = "httpStatus"
    latency_ms  = "latencyMs"
    source_ip   = "clientIp"
  }
}
```

---

## Lower-level adapter

If you need direct control over the lower-level CloudWatch wiring, the `ecs_service` adapter is still available at:

```hcl
source = "github.com/your-org/aws-observability-dashboard//infra/modules/adapters/ecs_service"
```

That adapter exposes ALB and target group ARN suffixes directly and is intended for advanced consumers. The recommended public entry point is `platform_service`.

---

## Enabling Container Insights

Container Insights must be enabled on the ECS cluster for the running-task alarm and dashboard widgets to have data. CPU and memory percentage alarms use the built-in ECS service utilisation metrics in the `AWS/ECS` namespace.

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

For service maps and distributed traces, follow the [AWS ECS Application Signals setup guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). This package does not provision Application Signals infrastructure automatically for arbitrary existing services — it requires manual instrumentation of the target application and a sidecar-based CloudWatch agent setup for ECS or Fargate workloads. Daemon mode is intentionally out of scope.
