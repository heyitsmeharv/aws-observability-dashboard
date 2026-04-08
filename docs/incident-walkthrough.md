# Incident walkthrough

This walkthrough simulates a realistic incident using the demo app and shows how the alarms, dashboards, Logs Insights queries, and canaries work together to identify and resolve it.

---

## Scenario: elevated 5xx errors and P99 latency spike

You receive an alarm notification: `obs-demo-sandbox-alb-5xx-count` is in ALARM.

---

## Step 1 — Orient on the dashboard alarm section

Open the `obs-demo-sandbox` dashboard and look at the alarm strip near the top. Two alarms are red:

- `obs-demo-sandbox-alb-5xx-count` — ALARM
- `obs-demo-sandbox-alb-latency-p99` — ALARM

The ECS running task count and CPU/memory widgets look normal. The problem is in the application, not the infrastructure.

---

## Step 2 — Check the service widgets

Stay on `obs-demo-sandbox` and scroll to the service widgets. The **Request Count by Status Class** chart shows a clear spike in `5xx` starting at 14:32. The **ALB Target Response Time Percentiles** chart shows P99 climbing from ~200ms to ~4s at the same time.

This pattern — 5xx errors alongside elevated latency — suggests the application is struggling under load or a specific code path is failing slowly.

---

## Step 3 — Query Logs Insights

Open **CloudWatch → Logs → Logs Insights** and select the `/ecs/obs-demo-sandbox/backend` log group.

Run the saved query `errors/top-failing-routes`:

```
Result:
route            statusCode    errorCount
/api/dependency  503           47
/api/fail        500           12
```

The `/api/dependency` route is generating the bulk of errors with 503s. This points to a downstream dependency problem, not a general application failure.

---

## Step 4 — Investigate the slow requests

Run the saved query `latency/slowest-requests` scoped to the same time window:

```
timestamp              route              durationMs    statusCode
2024-01-01T14:33:01Z   /api/dependency    4821          503
2024-01-01T14:33:00Z   /api/dependency    4650          503
2024-01-01T14:32:58Z   /api/dependency    4540          200
...
```

The `/api/dependency` route is timing out on the downstream service and waiting for the full timeout (4–5s) before returning 503. This explains both the latency spike and the elevated 5xx count — it is the same root cause.

---

## Step 5 — Confirm with the deploy-window query

Check whether the problem started with a recent deploy. Run `deploy/error-rate-1min-buckets` scoped to the last 30 minutes:

```
@timestamp              errorCount
2024-01-01T14:32:00Z    0
2024-01-01T14:33:00Z    12
2024-01-01T14:34:00Z    18
2024-01-01T14:35:00Z    21
```

The error count started at 14:33, which correlates with an ECS deployment that completed at 14:32 (visible in the ECS service events). A code change to the dependency timeout or retry logic is likely the cause.

---

## Step 6 — Check the canary (if enabled)

If canaries are enabled, open **CloudWatch → Synthetics Canaries**. The `obs-demo-sandbox-frontend` canary shows 100% success (the frontend itself is fine). The `obs-demo-sandbox-api` canary shows failures starting at 14:33, confirming the API health endpoint is now affected.

The `obs-demo-sandbox-canary-success-rate` alarm should also be in ALARM, corroborating the ALB 5xx alarm.

---

## Step 7 — Validate the fix

After rolling back or fixing the dependency timeout:

```bash
# Check errors stopped
curl "http://${ALB_DNS}/api/dependency"
# Should return 200 consistently

# Run the error rate query again — errorCount should be 0
```

Within 2 evaluation periods (2 minutes), the alarms return to OK and the canary success rate returns to 100%.

---

## Summary

| Signal          | What it showed                                                    |
|-----------------|-------------------------------------------------------------------|
| Alarm           | ALB 5xx and P99 latency in ALARM — confirmed something was wrong  |
| Dashboard       | ECS healthy, narrowed to application layer and pinpointed timing  |
| Logs Insights   | Identified `/api/dependency` as the top failing route             |
| Logs Insights   | Confirmed slow response times on that route                       |
| Deploy query    | Correlated the error spike with the deployment window             |
| Canary          | Confirmed outside-in that the API health check was also failing   |

This is the end-to-end loop: alarm triggers awareness, dashboard narrows context, Logs Insights identifies the root cause, canary validates the fix from outside.
