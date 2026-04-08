# Cost notes

The observability resources created by this package have predictable costs. This document covers the main contributors and safe defaults.

All figures are approximate and based on eu-west-2 (London) pricing as of 2024. Verify current pricing at [aws.amazon.com/cloudwatch/pricing](https://aws.amazon.com/cloudwatch/pricing).

---

## CloudWatch dashboards

**Pricing:** $3.00 per dashboard per month (first 3 dashboards free).

This package creates 4 dashboards per deployment:
- `overview`
- `service`
- `operations`
- `log-analysis`

**Estimated cost:** ~$3/month (1 free tier dashboard, 3 billed).

---

## CloudWatch alarms

**Pricing:** $0.10 per alarm per month for standard resolution alarms.

This package creates up to 8 alarms per deployment:
- 4 ALB alarms
- 3 ECS alarms
- 1 canary failure alarm (when canaries are enabled)

**Estimated cost:** ~$0.70–$0.80/month.

---

## CloudWatch Logs Insights

**Pricing:** $0.0057 per GB of data scanned.

Logs Insights queries are charged per GB scanned, not per query run. The 10 saved query definitions themselves have no cost — you only pay when you run them.

**Recommendation:** Use time-scoped queries (last 15 minutes, last 1 hour) rather than querying all time. The log analysis dashboard widgets are scoped to 1 hour by default.

**Estimated cost:** Varies by log volume. At 1 GB/day of logs, scanning 1 hour of data costs roughly $0.01 per query run.

---

## CloudWatch Synthetics canaries

**Pricing:** $0.0012 per canary run.

At the default schedule of `rate(5 minutes)`:
- 12 runs/hour × 24 hours × 30 days = 8,640 runs/month per canary

**Estimated cost per canary:** ~$10.37/month.

With both the frontend and API canary enabled: ~$20.74/month.

**To reduce cost**, increase the schedule interval:
```hcl
canary_schedule_expression = "rate(15 minutes)"  # ~$3.46/month per canary
```

Canaries are disabled by default (`enable_canaries = false`).

---

## Log storage

**Pricing:** $0.03 per GB ingested, $0.03 per GB stored per month (after free tier).

The demo log groups have a 30-day retention period. Adjust in `main.tf` of the demo infra if needed:

```hcl
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}/backend"
  retention_in_days = 14  # reduce for lower cost
}
```

---

## Container Insights

**Pricing:** $0.50 per vCPU per month + $0.10 per GB RAM per month for ECS Container Insights.

Container Insights is enabled on the ECS cluster in the demo. For a single `t3.small` instance (2 vCPU, 2 GB RAM):
- vCPU: 2 × $0.50 = $1.00/month
- RAM: 2 × $0.10 = $0.20/month

**Estimated cost:** ~$1.20/month.

---

## Total estimated cost — demo environment

| Component                          | Monthly cost  |
|------------------------------------|---------------|
| Dashboards (4, 1 free)             | ~$3.00        |
| Alarms (8)                         | ~$0.80        |
| Container Insights (1 × t3.small)  | ~$1.20        |
| Log storage (30-day retention)     | Varies        |
| Logs Insights queries              | ~$0.01–$0.50  |
| Canaries (disabled by default)     | $0.00         |
| **Subtotal (no canaries)**         | **~$5–6/month** |
| Canaries (2 × rate(5 min))         | ~$20.74       |
| **Subtotal (with canaries)**       | **~$26/month** |

These figures do not include ECS, ALB, EC2, or ECR costs for the demo app itself.

---

## Recommendations for production

1. **Alarm evaluation periods:** The default is 2 periods × 60 seconds. Increasing the period to 300 seconds reduces alarm evaluation costs and avoids false alarms on short spikes.

2. **Dashboard refresh rate:** Use on-demand refresh rather than auto-refresh to avoid unnecessary API calls.

3. **Log retention:** Match log retention to your compliance requirements. 30 days is the demo default; production may need 90 days or longer, which increases storage cost.

4. **Canary schedule:** Start with `rate(15 minutes)` or `rate(30 minutes)` and tighten if needed. Most SLAs do not require 5-minute synthetic monitoring.

5. **Log volume:** Structured logging at INFO level generates substantial volume under load. Use sampling or conditional DEBUG logging in production.
