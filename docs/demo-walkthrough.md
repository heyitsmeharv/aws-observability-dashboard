# Demo walkthrough

This guide walks through deploying the `react-node-demo` example and verifying that the observability package lights up correctly.

---

## Prerequisites

- AWS CLI authenticated to the target account
- Terraform >= 1.6
- Docker (for building and pushing images)
- Git Bash (on Windows)

---

## Step 1 — Bootstrap remote state

From the repo root:

```bash
export ENVIRONMENT="sandbox"
source infra/scripts/use-env.sh "$ENVIRONMENT"
bash infra/scripts/whoami.sh   # confirm the right account

bash infra/scripts/bootstrap-state.sh "$ENVIRONMENT" --region eu-west-2
```

---

## Step 2 — Initialise the demo environment

```bash
cd examples/react-node-demo/infra

# Write the backend.hcl for this environment
# (uses the same state bucket created in step 1)
bash ../../../infra/scripts/write-backend-hcl.sh sandbox \
  --region eu-west-2 \
  --project-name obs-demo

terraform init -backend-config=backend.hcl
```

---

## Step 3 — Deploy the infrastructure

```bash
terraform plan -var-file=env.tfvars
terraform apply -var-file=env.tfvars
```

This creates:
- VPC (uses your account's default VPC)
- ECR repositories for frontend and backend
- ECS cluster (EC2 launch type, Container Insights enabled)
- ALB with path-based routing
- ECS task definitions and services
- CloudWatch log groups
- **Observability package** — 4 dashboards, 7 alarms, 10 Logs Insights queries

Note the outputs — you'll need `alb_dns_name` and the ECR repository URLs.

---

## Step 4 — Build and push container images

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-2"

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Backend
cd examples/react-node-demo/app/backend
docker build -t obs-demo-backend .
docker tag obs-demo-backend \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/obs-demo-sandbox-backend:latest"
docker push \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/obs-demo-sandbox-backend:latest"

# Frontend
cd ../frontend
docker build -t obs-demo-frontend \
  --build-arg VITE_API_URL=/api .
docker tag obs-demo-frontend \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/obs-demo-sandbox-frontend:latest"
docker push \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/obs-demo-sandbox-frontend:latest"
```

---

## Step 5 — Force new ECS deployments

```bash
CLUSTER="obs-demo-sandbox-cluster"

aws ecs update-service \
  --cluster $CLUSTER \
  --service obs-demo-sandbox-backend \
  --force-new-deployment

aws ecs update-service \
  --cluster $CLUSTER \
  --service obs-demo-sandbox-frontend \
  --force-new-deployment
```

Wait for the services to stabilise (1–2 minutes):

```bash
aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services obs-demo-sandbox-backend obs-demo-sandbox-frontend
```

---

## Step 6 — Verify the app is running

```bash
ALB_DNS=$(terraform -chdir=examples/react-node-demo/infra \
  output -raw alb_dns_name)

curl "http://${ALB_DNS}/health"
# => {"status":"ok","service":"obs-demo-backend","env":"sandbox"}

curl "http://${ALB_DNS}/api/ok"
# => {"message":"Everything is fine.",...}
```

Open `http://<ALB_DNS>` in your browser to see the React UI.

---

## Step 7 — Generate signals

Use the React UI's "Run burst" button, or hit the endpoints directly:

```bash
# Normal traffic
curl "http://${ALB_DNS}/api/ok"
curl "http://${ALB_DNS}/api/items"

# Latency spike
curl "http://${ALB_DNS}/api/slow?ms=4000"

# 500 errors (triggers 5xx alarm after 2+ per minute)
for i in $(seq 1 15); do curl -s "http://${ALB_DNS}/api/fail" > /dev/null; done

# Flaky dependency
for i in $(seq 1 10); do curl -s "http://${ALB_DNS}/api/dependency" > /dev/null; done
```

---

## Step 8 — Inspect the dashboards

Open the CloudWatch console and navigate to **Dashboards**. You should see:

| Dashboard                      | What to look for                                          |
|--------------------------------|-----------------------------------------------------------|
| `obs-demo-sandbox-overview`    | ALB request count rising, 5xx spike if you ran errors     |
| `obs-demo-sandbox-service`     | Latency percentile split, ECS task count stable           |
| `obs-demo-sandbox-operations`  | Alarm status strip — 5xx alarm should be IN ALARM         |
| `obs-demo-sandbox-log-analysis`| Latest errors table populated with structured log entries |

---

## Step 9 — Run Logs Insights queries

In the CloudWatch console under **Logs → Logs Insights**, select the log groups:
- `/ecs/obs-demo-sandbox/backend`
- `/ecs/obs-demo-sandbox/frontend`

Your saved queries appear under `obs-demo/sandbox/`. Run:

- `errors/latest-errors` — see the structured error entries from `/api/fail`
- `latency/p99-by-route` — compare `/api/slow` vs `/api/ok`
- `errors/top-failing-routes` — confirm `/api/fail` leads the list

---

## Step 10 — Enable canaries (optional)

```bash
# Re-apply with canaries enabled
terraform apply \
  -var-file=env.tfvars \
  -var="enable_canaries=true"
```

This creates:
- A frontend health-check canary probing `http://<ALB_DNS>`
- An API health canary probing `http://<ALB_DNS>/health`
- A canary failure alarm wired into the dashboards

View canary run results under **CloudWatch → Synthetics Canaries**.

---

## Tear down

```bash
terraform destroy -var-file=env.tfvars
```

This removes all ECS, ALB, ECR, CloudWatch, and observability resources. ECR repositories with images require manual deletion or add `force_delete = true` to the ECR resource.
