# Architecture

## What this project is

`aws-observability-dashboard` is a reusable Terraform module set that attaches standardised CloudWatch observability to an AWS workload. Given a small set of workload inputs — cluster name, service name, ALB ARN, log groups — it creates:

- CloudWatch dashboards (overview, service, operations, log analysis)
- CloudWatch alarms (ALB front-door, ECS health, canary failure)
- CloudWatch Logs Insights query packs (error analysis, latency, traffic, deploy helpers)
- CloudWatch Synthetics canaries for outside-in endpoint monitoring

The product is the observability package. The `examples/react-node-demo` app is a realistic target used to prove the package works end to end against a real AWS stack.

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
modules/
├── core_alarms/            CloudWatch metric alarms
├── core_canaries/          CloudWatch Synthetics canaries + IAM
├── core_dashboards/        CloudWatch dashboards (4 views)
├── core_logs_insights/     CloudWatch Logs Insights query definitions
└── adapters/
    └── ecs_service/        Wires all four core modules for an ECS+ALB workload

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
                                              CloudWatch Dashboards
                                              (4 views assembled from above signals)
```

---

## Two-level integration story

### Level 1 — metrics, alarms, logs, canaries (no app changes required)

The core modules observe the AWS infrastructure layer: ALB metrics, ECS Container Insights metrics, application logs already flowing to CloudWatch Logs, and outside-in canary checks. No changes to the application are required beyond structured JSON logging.

### Level 2 — Application Signals (requires app instrumentation)

For service maps, distributed traces, and correlated service-level views, the target application must be onboarded to [AWS Application Signals on ECS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). This requires:

1. Installing the CloudWatch agent on ECS instances with a daemon task
2. Configuring the ADOT collector for the application
3. Instrumenting the application code with OpenTelemetry

This package cannot generate trace data if the application emits none. Level 2 is explicitly optional for v1.

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
