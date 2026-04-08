# aws-observability-dashboard

A reusable Terraform module set that attaches standardised CloudWatch observability to an AWS workload — dashboards, alarms, Logs Insights queries, and synthetic monitoring from a small set of workload inputs.

---

## What this is

Point it at your ECS service and ALB, and it generates the core observability package around them:

- **4 CloudWatch dashboards** — overview, service detail, operations, and log analysis
- **7+ CloudWatch alarms** — ALB front-door errors and latency, ECS health, canary failures
- **10 Logs Insights saved queries** — error analysis, latency, traffic, and deploy-window helpers
- **CloudWatch Synthetics canaries** — outside-in endpoint monitoring (optional)

The product is the Terraform module set. The `examples/react-node-demo` app is a realistic ECS target used to prove the package works end to end.

---

## Supported workload pattern — v1

| Dimension   | Supported shape                                      |
|-------------|------------------------------------------------------|
| Compute     | ECS with the EC2 launch type                         |
| Front door  | Application Load Balancer (ALB)                      |
| Logging     | Structured JSON logs to CloudWatch Logs              |
| Metrics     | CloudWatch Container Insights (enabled on cluster)   |

---

## Repo structure

```
modules/
├── core_alarms/            CloudWatch metric alarms
├── core_canaries/          CloudWatch Synthetics canaries + IAM
├── core_dashboards/        4 CloudWatch dashboard views
├── core_logs_insights/     10 saved Logs Insights query definitions
└── adapters/
    └── ecs_service/        Wires all core modules for an ECS+ALB workload

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
  source = "github.com/your-org/aws-observability-dashboard//modules/adapters/ecs_service"

  project     = "my-app"
  environment = "production"
  region      = "eu-west-2"

  ecs_cluster_name        = "my-cluster"
  ecs_service_name        = "my-service"
  alb_arn_suffix          = aws_lb.main.arn_suffix
  target_group_arn_suffix = aws_lb_target_group.main.arn_suffix
  log_group_names         = ["/ecs/my-app/production"]

  create_sns_topic = true

  # Optional: outside-in synthetic monitoring
  enable_canaries              = true
  frontend_url                 = "https://my-app.example.com"
  api_endpoint                 = "https://my-app.example.com/health"
  canary_artifacts_bucket_name = aws_s3_bucket.canary_artifacts.bucket
}
```

See [docs/integration-guide.md](docs/integration-guide.md) for the full variable reference and structured logging requirements.

---

## Running the demo

The `examples/react-node-demo` directory deploys a complete ECS stack — React frontend, Node API, ALB — and wires the observability package against it.

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

For service maps, distributed traces, and correlated service-level views, the application must be onboarded to [AWS Application Signals on ECS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-ECS.html). This package cannot generate trace data if the application emits none.

---

## Honest limitations

- v1 supports one workload pattern: ECS on EC2 behind an ALB. Lambda, API Gateway, and Fargate adapters are planned for later versions.
- For Application Signals and service maps, the target application must install and configure the CloudWatch agent and ADOT. The package standardises the observability layer but cannot invent tracing data.
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
