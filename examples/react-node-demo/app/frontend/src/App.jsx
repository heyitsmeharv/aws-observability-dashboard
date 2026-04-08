import { useState, useEffect, useRef } from "react";
import ArchDiagram from "./ArchDiagram.jsx";

const API = import.meta.env.VITE_API_URL ?? "/api";

const ENDPOINTS = [
  {
    id: "ok",
    label: "Healthy",
    description: "Fast 200 — normal traffic",
    url: `${API}/ok`,
    method: "GET",
    badgeColor: "#2ca02c",
    expectedMs: 200,
  },
  {
    id: "slow",
    label: "Slow (3s)",
    description: "3-second delay — P99 latency spike",
    url: `${API}/slow?ms=3000`,
    method: "GET",
    badgeColor: "#ff7f0e",
    expectedMs: 3200,
  },
  {
    id: "slow5",
    label: "Very slow (5s)",
    description: "5-second delay — triggers latency alarm",
    url: `${API}/slow?ms=5000`,
    method: "GET",
    badgeColor: "#ff7f0e",
    expectedMs: 5200,
  },
  {
    id: "fail",
    label: "500 Error",
    description: "Intentional 500 — triggers 5xx alarm",
    url: `${API}/fail`,
    method: "GET",
    badgeColor: "#d62728",
    expectedMs: 200,
  },
  {
    id: "dependency",
    label: "Dependency (30% fail)",
    description: "Flaky downstream — shows dependency path",
    url: `${API}/dependency?failRate=0.3&latencyMs=800`,
    method: "GET",
    badgeColor: "#9467bd",
    expectedMs: 900,
  },
  {
    id: "items",
    label: "List items",
    description: "Normal business read — clean 200 traffic",
    url: `${API}/items`,
    method: "GET",
    badgeColor: "#1f77b4",
    expectedMs: 200,
  },
];

// ── Result box ────────────────────────────────────────────────────────────────

function ResultBox({ result }) {
  if (!result) return null;
  const isError = result.status >= 400;
  const color = isError ? "#d62728" : "#2ca02c";
  return (
    <div style={{
      marginTop: 10,
      padding: "10px 14px",
      borderRadius: 6,
      border: `1px solid ${color}`,
      background: isError ? "#fff5f5" : "#f6fff6",
      fontFamily: "monospace",
      fontSize: 12,
    }}>
      <div style={{ marginBottom: 4, color }}>
        <strong>HTTP {result.status}</strong> — {result.durationMs}ms
      </div>
      <pre style={{ margin: 0, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
        {JSON.stringify(result.body, null, 2)}
      </pre>
    </div>
  );
}

// ── Endpoint card ─────────────────────────────────────────────────────────────

function EndpointCard({ endpoint, onFlight }) {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  const call = async () => {
    setLoading(true);
    setResult(null);

    const flightId = `${endpoint.id}-${Date.now()}`;
    onFlight({
      id: flightId,
      endpointId: endpoint.id,
      edges: endpointEdges(endpoint.id),
      dest: endpointDest(endpoint.id),
      durationMs: endpoint.expectedMs,
      phase: "flying",
      error: false,
    });

    const start = Date.now();
    try {
      const res = await fetch(endpoint.url, { method: endpoint.method });
      const body = await res.json().catch(() => ({}));
      const durationMs = Date.now() - start;
      setResult({ status: res.status, body, durationMs });
      onFlight((f) => f?.id === flightId
        ? { ...f, phase: "received", error: res.status >= 500 }
        : f
      );
      setTimeout(() => onFlight((f) => f?.id === flightId ? null : f), 1200);
    } catch (err) {
      const durationMs = Date.now() - start;
      setResult({ status: 0, body: { error: err.message }, durationMs });
      onFlight((f) => f?.id === flightId ? { ...f, phase: "received", error: true } : f);
      setTimeout(() => onFlight((f) => f?.id === flightId ? null : f), 1200);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      border: "1px solid #e0e0e0",
      borderRadius: 8,
      padding: "12px 14px",
      marginBottom: 10,
      background: "#fff",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
        <span style={{
          background: endpoint.badgeColor,
          color: "#fff",
          borderRadius: 4,
          padding: "1px 7px",
          fontSize: 11,
          fontWeight: 600,
        }}>
          {endpoint.method}
        </span>
        <strong style={{ fontSize: 14 }}>{endpoint.label}</strong>
      </div>
      <div style={{ fontSize: 12, color: "#666", marginBottom: 8 }}>
        {endpoint.description}
      </div>
      <button
        onClick={call}
        disabled={loading}
        style={{
          padding: "5px 14px",
          borderRadius: 5,
          border: "none",
          background: loading ? "#ccc" : "#1f77b4",
          color: "#fff",
          cursor: loading ? "not-allowed" : "pointer",
          fontWeight: 600,
          fontSize: 13,
        }}
      >
        {loading ? "Calling…" : "Call"}
      </button>
      <ResultBox result={result} />
    </div>
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function endpointEdges(id) {
  const base = ["e-br-cf", "e-cf-al", "e-al-be"];
  if (id === "dependency") return [...base, "e-be-ds"];
  return base;
}

function endpointDest(id) {
  return id === "dependency" ? "downstream" : "backend";
}

// ── App ───────────────────────────────────────────────────────────────────────

export default function App() {
  const [flight, setFlight] = useState(null);
  const [metrics, setMetrics] = useState(null);
  const [burstLoading, setBurstLoading] = useState(false);
  const [burstResults, setBurstResults] = useState(null);

  // Poll metrics every 5 seconds
  useEffect(() => {
    const fetchMetrics = () =>
      fetch(`${API}/metrics`)
        .then((r) => r.json())
        .then(setMetrics)
        .catch(() => {});
    fetchMetrics();
    const id = setInterval(fetchMetrics, 5000);
    return () => clearInterval(id);
  }, []);

  const runBurst = async () => {
    setBurstLoading(true);
    setBurstResults(null);
    const calls = Array.from({ length: 10 }, (_, i) => {
      const ep = ENDPOINTS[i % ENDPOINTS.length];
      return fetch(ep.url, { method: ep.method })
        .then((r) => r.status)
        .catch(() => 0);
    });
    const statuses = await Promise.all(calls);
    const summary = statuses.reduce((acc, s) => {
      const bucket = s >= 500 ? "5xx" : s >= 400 ? "4xx" : s >= 200 ? "2xx" : "err";
      acc[bucket] = (acc[bucket] ?? 0) + 1;
      return acc;
    }, {});
    setBurstResults(summary);
    setBurstLoading(false);
  };

  return (
    <div style={{
      maxWidth: 1100,
      margin: "0 auto",
      padding: "28px 16px",
      fontFamily: "'Segoe UI', system-ui, sans-serif",
      color: "#222",
    }}>
      <h1 style={{ margin: "0 0 2px", fontSize: 22 }}>aws-observability-dashboard</h1>
      <p style={{ color: "#666", margin: "0 0 20px", fontSize: 14 }}>
        Fire requests to generate CloudWatch signals — watch the diagram animate the flow.
      </p>

      {/* Architecture diagram */}
      <ArchDiagram flight={flight} metrics={metrics} />

      <div style={{ height: 20 }} />

      {/* Two-column layout below the diagram */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 300px", gap: 20, alignItems: "start" }}>

        {/* Endpoint cards */}
        <div>
          <h2 style={{ margin: "0 0 12px", fontSize: 16 }}>Endpoints</h2>
          {ENDPOINTS.map((ep) => (
            <EndpointCard key={ep.id} endpoint={ep} onFlight={setFlight} />
          ))}
        </div>

        {/* Right column: burst + metrics summary */}
        <div>
          <div style={{
            border: "1px solid #e0e0e0",
            borderRadius: 8,
            padding: "14px 16px",
            background: "#fff",
            marginBottom: 16,
          }}>
            <h3 style={{ margin: "0 0 8px", fontSize: 15 }}>Burst traffic</h3>
            <p style={{ margin: "0 0 10px", fontSize: 13, color: "#555" }}>
              10 mixed requests across all endpoints simultaneously.
            </p>
            <button
              onClick={runBurst}
              disabled={burstLoading}
              style={{
                padding: "6px 16px",
                borderRadius: 5,
                border: "none",
                background: burstLoading ? "#ccc" : "#2ca02c",
                color: "#fff",
                cursor: burstLoading ? "not-allowed" : "pointer",
                fontWeight: 600,
                fontSize: 13,
              }}
            >
              {burstLoading ? "Running…" : "Run burst"}
            </button>
            {burstResults && (
              <div style={{ marginTop: 10, fontFamily: "monospace", fontSize: 12 }}>
                {JSON.stringify(burstResults)}
              </div>
            )}
          </div>

          {/* Live metrics summary */}
          {metrics && (
            <div style={{
              border: "1px solid #e0e0e0",
              borderRadius: 8,
              padding: "14px 16px",
              background: "#fff",
            }}>
              <h3 style={{ margin: "0 0 10px", fontSize: 15 }}>Last 60s</h3>
              <MetricRow label="Requests" value={metrics.total.requests} />
              <MetricRow label="Error rate" value={`${metrics.total.errorRate}%`} color={metrics.total.errorRate > 10 ? "#d62728" : "#2ca02c"} />
              <MetricRow label="Avg latency" value={`${metrics.total.avgLatencyMs}ms`} />
              {Object.entries(metrics.routes).length > 0 && (
                <>
                  <div style={{ borderTop: "1px solid #f0f0f0", margin: "10px 0 8px", fontSize: 11, color: "#999" }}>by route</div>
                  {Object.entries(metrics.routes).map(([route, r]) => (
                    <div key={route} style={{ fontSize: 11, marginBottom: 4, display: "flex", justifyContent: "space-between" }}>
                      <code style={{ color: "#555" }}>{route}</code>
                      <span style={{ color: r.errorRate > 0 ? "#d62728" : "#2ca02c" }}>
                        {r.requests}req {r.errorRate > 0 ? `· ${r.errorRate}%err` : ""}
                      </span>
                    </div>
                  ))}
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function MetricRow({ label, value, color }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6, fontSize: 13 }}>
      <span style={{ color: "#666" }}>{label}</span>
      <strong style={{ color: color ?? "#222" }}>{value}</strong>
    </div>
  );
}
