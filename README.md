# aws-observability-dashboard

A reusable Terraform module set that attaches standardised CloudWatch observability to an AWS workload — dashboards, alarms, Logs Insights queries, and synthetic monitoring from a small set of workload ARNs and log inputs.

---

## What this is

Point it at your existing ECS service, ALB, target group, and log groups, and it generates the core observability package around them:

- **1 CloudWatch dashboard** — overview, service detail, operations, and log analysis sections in a single view
- **7+ CloudWatch alarms** — ALB front-door errors and latency, ECS health, canary failures
- **10 Logs Insights saved queries** — error analysis, latency, traffic, and deploy-window helpers
- **CloudWatch Synthetics canaries** — outside-in endpoint monitoring (optional)

The product is the Terraform module set. The dashboard created by the module is a CloudWatch dashboard backed by CloudWatch metrics, alarms, Logs Insights queries, and optional canaries.

The `examples/react-node-demo` app is a realistic ECS target used to prove the package works end to end. Its separate React UI is a companion demo and validation surface, not a required part of the package contract.

---

## Supported workload pattern — v1

| Dimension   | Supported shape                                      |
|-------------|------------------------------------------------------|
| Compute     | ECS with the EC2 or Fargate launch type              |
| Front door  | Application Load Balancer (ALB)                      |
| Logging     | Structured JSON logs to CloudWatch Logs              |
| Metrics     | CloudWatch Container Insights (enabled on cluster)   |

---

## Repo structure

```
infra/modules/
├── core_alarms/            CloudWatch metric alarms
├── core_canaries/          CloudWatch Synthetics canaries + IAM
├── core_dashboards/        Single CloudWatch dashboard with overview/service/ops/log sections
├── core_logs_insights/     10 saved Logs Insights query definitions
└── adapters/
    ├── platform_service/   Recommended public adapter for platform teams
    ├── ecs_ec2_alb/        Internal ECS-on-EC2 wrapper used by platform_service
    ├── ecs_fargate_alb/    Internal Fargate wrapper used by platform_service
    ├── ec2_alb/            Future EC2 adapter scaffold
    └── ecs_service/        Lower-level ECS+ALB adapter used by the wrappers

examples/
└── react-node-demo/
    ├── app/
    │   ├── backend/        Node/Express API that generates observable signals
    │   └── frontend/       React UI that exercises all API endpoints
    └── infra/              ECS cluster, ALB, ECR + the observability adapter

docs/
├── architecture.md
├── integration-guide.md
├── demo-walkthrough.md
├── incident-walkthrough.md
└── cost-notes.md

infra/                      Repo-level Terraform boilerplate (state bootstrap, CI)
```

---

## Quick start

```hcl
module "observability" {
  source = "github.com/your-org/aws-observability-dashboard//infra/modules/adapters/platform_service"

  service = {
    name        = "my-app"
    environment = "production"
    region      = "eu-west-2"
    kind        = "ecs_fargate_alb"
    ingress = {
      alb_arn          = var.alb_arn
      target_group_arn = var.target_group_arn
      public_base_url  = "https://my-app.example.com"
      api_health_url   = "https://my-app.example.com/health"
    }
    log_group_names = ["/ecs/my-app/production"]
    ecs = {
      cluster_arn        = var.ecs_cluster_arn
      service_arn        = var.ecs_service_arn
      app_container_name = "api"
    }
  }

  dashboard = {
    owner = "payments-team"
  }

  alerts = {
    sns_topic_arn = aws_sns_topic.platform_alerts.arn
  }

  # Optional: outside-in synthetic monitoring
  canaries = {
    enabled               = true
    artifacts_bucket_name = aws_s3_bucket.canary_artifacts.bucket
  }

  # Optional: OpenTelemetry/Application Signals drilldowns.
  # Use mode = managed when the surrounding stack owns workload instrumentation.
  tracing = {
    enabled = true
    mode    = "managed"
  }
}
```

See [docs/integration-guide.md](docs/integration-guide.md) for the full contract, outputs, onboarding guidance for existing services, log field mapping support, and the lower-level `ecs_service` adapter.

---

## Running the demo

The `examples/react-node-demo` directory deploys a complete ECS stack — React frontend, Node API, ALB — and wires the observability package against it.

Use this demo when you want a realistic workload plus a separate UI that helps generate traffic and validate the package behaviour. It is a companion test harness for the module, not a runtime dependency for consumers.

The sandbox demo enables Application Signals tracing by default. It does this with a CloudWatch agent sidecar plus the AWS-documented Node CommonJS init-container pattern: an `init` container copies `autoinstrumentation.js` into a shared task volume, and the backend starts with `NODE_OPTIONS=--require /otel-auto-instrumentation-node/autoinstrumentation.js`.

See [docs/demo-walkthrough.md](docs/demo-walkthrough.md) for step-by-step instructions.

**Quick version:**

```bash
# 1. Bootstrap remote state (first time only)
bash infra/scripts/bootstrap-state.sh sandbox --region eu-west-2

# 2. Deploy
cd examples/react-node-demo/infra
terraform init -backend-config=backend.hcl
terraform apply -var-file=env.tfvars

# 3. Build and push images, then force new ECS deployments
# (see docs/demo-walkthrough.md for full commands)
```

---

## Integration levels

### Level 1 — infrastructure observability (no app changes required)

Dashboards, alarms, Logs Insights, and canaries around existing AWS resources. The only requirement from the application is structured JSON logging to CloudWatch Logs.

### Level 2 — Application Signals (requires app instrumentation)

For service maps, distributed traces, and correlated service-level views, the application must be onboarded to [AWS Application Signals on ECS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). The module exposes trace drilldown links and can enable active tracing for canaries, but it still cannot generate service trace data if the workload emits none. The demo stack now follows AWS’s documented Node CommonJS pattern: a CloudWatch agent sidecar plus an `init` container that injects the ADOT Node auto-instrumentation into the backend task. AWS still documents Node ESM support as limited.

---

## Honest limitations

- v1 supports two implemented workload attachment patterns: ECS on EC2 behind an ALB and ECS on Fargate behind an ALB. The `ec2_alb` public contract is scaffolded for a future adapter, but compute-specific EC2 alarms and dashboards are not implemented yet.
- For Application Signals and service maps, the target application must install and configure the CloudWatch agent and ADOT. The package standardises the observability layer but cannot invent tracing data for arbitrary existing services it does not own.
- For ECS and Fargate tracing, the supported collector pattern is a task sidecar. Daemon mode is intentionally out of scope for v1.
- Cross-account observability (CloudWatch OAM) is explicitly out of scope for v1.

---

## Docs

| Document                                        | What it covers                                              |
|-------------------------------------------------|-------------------------------------------------------------|
| [Architecture](docs/architecture.md)            | Module structure, data flow, integration levels, v1 scope  |
| [Integration guide](docs/integration-guide.md)  | Variables, structured logging format, usage examples        |
| [Demo walkthrough](docs/demo-walkthrough.md)    | Step-by-step: deploy, push images, generate signals         |
| [Incident walkthrough](docs/incident-walkthrough.md) | Using alarms + logs + canaries to diagnose an incident |
| [Cost notes](docs/cost-notes.md)                | Per-component cost breakdown and production recommendations |

---

## Local development (repo tooling)

```bash
# Verify prerequisites (Terraform, tflint, AWS CLI)
bash infra/scripts/prereqs.sh

# Switch AWS context
source infra/scripts/use-env.sh sandbox

# Format all Terraform
npm run tf:fmt

# Validate all modules
npm run tf:validate

# Plan the main infra environment
npm run tf:plan
```

---

## Contributing

This project follows [Conventional Commits](https://www.conventionalcommits.org/). Use `npm run release` to cut a version.
