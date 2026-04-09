# Architecture

## What this project is

`aws-observability-dashboard` is a reusable Terraform module set that attaches standardised CloudWatch observability to an AWS workload. Given a small set of service, logging, alerting, and canary inputs, it creates:

- A CloudWatch dashboard with overview, service, operations, and log analysis sections
- CloudWatch alarms (ALB front-door, ECS health, canary failure)
- CloudWatch Logs Insights query packs (error analysis, latency, traffic, deploy helpers)
- CloudWatch Synthetics canaries for outside-in endpoint monitoring

The product is the observability package. The package provisions CloudWatch-native observability assets around an existing workload. The `examples/react-node-demo` app is a realistic target used to prove the package works end to end against a real AWS stack.

---

## Supported workload pattern — v1

| Dimension         | Supported shape                                      |
|-------------------|------------------------------------------------------|
| Compute           | ECS with the EC2 launch type                         |
| Front door        | Application Load Balancer (ALB)                      |
| Logging           | Structured JSON logs to CloudWatch Logs              |
| Metrics           | CloudWatch Container Insights (enabled on cluster)   |
| Service visibility| Optional: Application Signals (custom ECS setup)     |

---

## Module structure

```
infra/modules/
├── core_alarms/            CloudWatch metric alarms
├── core_canaries/          CloudWatch Synthetics canaries + IAM
├── core_dashboards/        Single CloudWatch dashboard composition
├── core_logs_insights/     CloudWatch Logs Insights query definitions
└── adapters/
    ├── platform_service/   Recommended public adapter for platform teams
    └── ecs_service/        Lower-level ECS+ALB adapter used by platform_service

examples/
└── react-node-demo/
    ├── app/
    │   ├── backend/        Node/Express API (generates observable signals)
    │   └── frontend/       React UI (exercises all API endpoints)
    └── infra/              Terraform: ECS cluster, ALB, ECR + observability adapter

docs/
infra/                      Repo-level Terraform boilerplate (state bootstrap, CI)
```

---

## Data flow

```
Internet
    │
    ▼
Application Load Balancer
    │  metrics ──────────────────────────────► CloudWatch (AWS/ApplicationELB)
    │
    ▼
ECS Service (EC2 launch type)
    │  container metrics ────────────────────► CloudWatch (ECS/ContainerInsights)
    │  structured logs ──────────────────────► CloudWatch Logs ─► Logs Insights queries
    ▼
CloudWatch Synthetics Canaries ─────────────► CloudWatch (CloudWatchSynthetics)
                                                        │
                                                        ▼
                                              CloudWatch Alarms
                                                        │
                                                        ▼
                                              CloudWatch Dashboard
                                              (single composed view assembled from above signals)
```

---

## Public vs internal surface

`platform_service` is the recommended public contract. It presents the package as:

- `service` — workload identity plus ECS/ALB attachment points
- `logging` — log groups plus optional field mappings
- `dashboard` — owner and runbook metadata for the operator home page
- `alerts` — thresholds and notification routing
- `canaries` — optional outside-in probes

- `tracing` - optional X-Ray drilldowns plus canary active tracing

The `core_*` modules are internal building blocks. The lower-level `ecs_service` adapter remains available for advanced consumers, but platform teams should integrate through `platform_service` so the package can evolve without forcing them to think in CloudWatch-specific suffixes and widget wiring.

---

## Package vs companion UI

The package itself creates CloudWatch resources:

- CloudWatch dashboard
- CloudWatch alarms
- Logs Insights saved queries
- Optional Synthetics canaries

It also exposes tracing drilldowns into X-Ray when you enable the `tracing` block, and it can turn on active X-Ray tracing for canaries. It does not instrument the target ECS workload for you or provision a separate bespoke operator UI. If you want a richer custom frontend for demos or internal validation, that UI should sit alongside the package and read from the signals the package creates.

The `examples/react-node-demo` frontend is one example of that companion layer. It is useful for testing and showcasing the module, but teams onboarding the package to an existing AWS account do not need to deploy it.

---

## Two-level integration story

### Level 1 — metrics, alarms, logs, canaries (no app changes required)

The core modules observe the AWS infrastructure layer: ALB metrics, ECS service utilisation metrics, ECS Container Insights task-count metrics, application logs already flowing to CloudWatch Logs, and outside-in canary checks. No changes to the application are required beyond structured JSON logging.

### Level 2 — Application Signals (requires app instrumentation)

For service maps, distributed traces, and correlated service-level views, the target application must be onboarded to [AWS Application Signals on ECS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). This requires:

1. Installing the CloudWatch agent on ECS instances with a daemon task
2. Configuring the ADOT collector for the application
3. Instrumenting the application code with OpenTelemetry

This package cannot generate trace data if the application emits none. Level 2 is explicitly optional for v1, and the package currently helps with trace drilldown rather than managed application instrumentation.

---

## What v1 does not include

- Lambda adapter
- API Gateway adapter
- Cross-account observability (CloudWatch OAM)
- RUM (Real User Monitoring) as a core feature
- Custom CloudWatch widget plugins
- Multi-account rollout orchestration
- Anomaly detection alarms (planned for v2)

These are explicitly deferred to keep v1 deliverable and well-defined.
