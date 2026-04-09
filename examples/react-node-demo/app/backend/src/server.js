/**
 * Demo Node/Express API
 *
 * Intentional behaviours for generating observable signals:
 *   GET /health             — always healthy (used by ALB health check + canary)
 *   GET /api/ok             — normal fast response
 *   GET /api/slow           — configurable artificial delay (default 2–5s)
 *   GET /api/fail           — returns 500 with a structured error log
 *   GET /api/dependency     — simulates a downstream dependency call (may timeout)
 *   GET /api/items          — normal business endpoint with structured logging
 *   POST /api/items         — normal write with structured logging
 *
 * All logs are emitted as structured JSON to stdout so CloudWatch Logs Insights
 * can parse them with the field-extraction queries in the Logs Insights module.
 *
 * Log fields: timestamp, level, route, method, statusCode, durationMs,
 *             requestId, sourceIp, message
 */

import express from "express";
import { randomUUID } from "crypto";

const PORT = parseInt(process.env.PORT ?? "4000", 10);
const NODE_ENV = process.env.NODE_ENV ?? "development";

const app = express();
app.use(express.json());

// CORS — permissive for local development (Vite proxy handles this in dev;
// CloudFront provides same-origin in prod, but the header is harmless either way).
app.use((_req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  next();
});

// ── Structured logger ──────────────────────────────────────────────────────

function log(level, message, fields = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields,
  };
  console.log(JSON.stringify(entry));
}

// ── In-process metrics store (rolling 60-second window) ────────────────────

const metricsStore = {
  entries: [],

  record(route, statusCode, durationMs) {
    const cutoff = Date.now() - 300_000; // keep 5 minutes for history charts
    this.entries = this.entries.filter((e) => e.ts > cutoff);
    this.entries.push({ route, statusCode, durationMs, ts: Date.now() });
  },

  summary() {
    const cutoff = Date.now() - 60_000;
    const recent = this.entries.filter((e) => e.ts > cutoff);
    const blank = () => ({ requests: 0, errors: 0, latencySum: 0 });
    const total = blank();
    const byRoute = {};

    for (const e of recent) {
      total.requests++;
      if (e.statusCode >= 500) total.errors++;
      total.latencySum += e.durationMs;
      if (!byRoute[e.route]) byRoute[e.route] = blank();
      byRoute[e.route].requests++;
      if (e.statusCode >= 500) byRoute[e.route].errors++;
      byRoute[e.route].latencySum += e.durationMs;
    }

    const fmt = (r) => ({
      requests: r.requests,
      errors: r.errors,
      errorRate: r.requests > 0 ? +(r.errors / r.requests * 100).toFixed(1) : 0,
      avgLatencyMs: r.requests > 0 ? Math.round(r.latencySum / r.requests) : 0,
    });

    return {
      windowSeconds: 60,
      total: fmt(total),
      routes: Object.fromEntries(Object.entries(byRoute).map(([k, v]) => [k, fmt(v)])),
    };
  },

  // Bin all entries into 10-second intervals for sparkline charts.
  history() {
    const BIN = 10_000;
    const bins = new Map();
    for (const e of this.entries) {
      const key = Math.floor(e.ts / BIN) * BIN;
      if (!bins.has(key)) bins.set(key, { requests: 0, errors: 0, latencySum: 0 });
      const b = bins.get(key);
      b.requests++;
      if (e.statusCode >= 500) b.errors++;
      b.latencySum += e.durationMs;
    }
    return [...bins.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([ts, b]) => ({
        t: ts,
        requests: b.requests,
        errorRate: b.requests > 0 ? +(b.errors / b.requests * 100).toFixed(1) : 0,
        avgLatencyMs: b.requests > 0 ? Math.round(b.latencySum / b.requests) : 0,
      }));
  },
};

// ── Request logging middleware ─────────────────────────────────────────────

app.use((req, _res, next) => {
  req.startTime = Date.now();
  req.requestId = randomUUID();
  next();
});

app.use((req, res, next) => {
  const originalEnd = res.end.bind(res);

  res.end = function (...args) {
    const durationMs = Date.now() - req.startTime;
    // Keep internal dependency simulator traffic out of the demo metrics/log widgets.
    if (!req.path.startsWith("/internal/")) {
      log("info", "request completed", {
        requestId: req.requestId,
        method: req.method,
        route: req.path,
        statusCode: res.statusCode,
        durationMs,
        sourceIp: req.ip ?? req.headers["x-forwarded-for"] ?? "unknown",
        userAgent: req.headers["user-agent"] ?? "",
      });
    }
    // Record in metrics store (skip internal routes and the metrics endpoint itself)
    if (!req.path.startsWith("/internal/") && req.path !== "/api/metrics") {
      metricsStore.record(req.path, res.statusCode, durationMs);
    }
    return originalEnd(...args);
  };

  next();
});

// ── Routes ─────────────────────────────────────────────────────────────────

// Health check — always returns 200, used by ALB and canaries
app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "obs-demo-backend", env: NODE_ENV });
});

// Normal fast response
app.get("/api/ok", (_req, res) => {
  res.json({ message: "Everything is fine.", timestamp: new Date().toISOString() });
});

// Configurable slow response — triggers latency alarms and shows up in
// the "slowest requests" Logs Insights query
app.get("/api/slow", async (req, res) => {
  const delayMs = parseInt(req.query.ms ?? "3000", 10);
  const clamped = Math.min(Math.max(delayMs, 100), 10_000);

  await new Promise((resolve) => setTimeout(resolve, clamped));

  res.json({
    message: `Responded after ${clamped}ms artificial delay.`,
    delayMs: clamped,
  });
});

// Intentional failure — triggers the ALB 5xx alarm and populates the
// "latest errors" and "top failing routes" Logs Insights queries
app.get("/api/fail", (req, res) => {
  const errorType = req.query.type ?? "generic";

  log("error", "intentional failure triggered", {
    route: "/api/fail",
    errorType,
    message: `Simulated ${errorType} error for observability demo`,
  });

  res.status(500).json({
    error: "InternalServerError",
    message: `Simulated ${errorType} failure.`,
    requestId: req.requestId,
  });
});

// Private downstream simulator used to generate a real outbound HTTP span for
// the tracing demo without relying on external network dependencies.
app.get("/internal/downstream", async (req, res) => {
  const latencyMs = parseInt(req.query.latencyMs ?? "500", 10);
  const clamped = Math.min(Math.max(latencyMs, 50), 10_000);

  await new Promise((resolve) => setTimeout(resolve, clamped));

  if ((req.query.mode ?? "ok") === "fail") {
    return res.status(503).json({
      error: "DependencyUnavailable",
      message: "Simulated downstream dependency failure.",
      latencyMs: clamped,
    });
  }

  res.json({
    message: "Simulated downstream dependency succeeded.",
    latencyMs: clamped,
    data: { id: randomUUID(), value: Math.random() * 100 },
  });
});

// Dependency simulation — sometimes fails, sometimes succeeds.
// Uses a real internal HTTP request so OpenTelemetry can emit a client span.
app.get("/api/dependency", async (req, res) => {
  const failRate = parseFloat(req.query.failRate ?? "0.3");
  const latencyMs = parseInt(req.query.latencyMs ?? "500", 10);
  const shouldFail = Math.random() < failRate;
  const internalUrl = new URL(`http://127.0.0.1:${PORT}/internal/downstream`);

  internalUrl.searchParams.set("latencyMs", String(latencyMs));
  internalUrl.searchParams.set("mode", shouldFail ? "fail" : "ok");

  const response = await fetch(internalUrl);
  const payload = await response.json();

  if (!response.ok) {
    log("error", "downstream dependency unavailable", {
      route: "/api/dependency",
      dependency: "downstream-service",
      latencyMs,
    });

    return res.status(503).json({
      error: "ServiceUnavailable",
      message: payload.message ?? "Downstream dependency did not respond in time.",
      requestId: req.requestId,
    });
  }

  res.json({
    message: payload.message ?? "Dependency call succeeded.",
    latencyMs,
    data: payload.data ?? { id: randomUUID(), value: Math.random() * 100 },
  });
});

// Normal business endpoint — read
app.get("/api/items", (_req, res) => {
  const items = Array.from({ length: 5 }, (_, i) => ({
    id: `item-${i + 1}`,
    name: `Demo Item ${i + 1}`,
    createdAt: new Date().toISOString(),
  }));

  res.json({ items, count: items.length });
});

// Normal business endpoint — write
app.post("/api/items", (req, res) => {
  const { name } = req.body;

  if (!name || typeof name !== "string") {
    log("error", "validation failed", {
      route: "/api/items",
      method: "POST",
      message: "Missing or invalid name field",
    });
    return res.status(400).json({ error: "BadRequest", message: "name is required." });
  }

  const item = {
    id: randomUUID(),
    name: name.trim(),
    createdAt: new Date().toISOString(),
  };

  res.status(201).json({ item });
});

// Live metrics — rolling 60-second summary + 5-minute history, polled by the frontend
app.get("/api/metrics", (_req, res) => {
  res.json({ ...metricsStore.summary(), history: metricsStore.history() });
});

// ── Start ──────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  log("info", "server started", { port: PORT, env: NODE_ENV });
});
