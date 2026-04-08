import { useState } from "react";

const API = import.meta.env.VITE_API_URL ?? "/api";

const ENDPOINTS = [
  {
    id: "ok",
    label: "Healthy",
    description: "Fast 200 response — normal traffic",
    url: `${API}/ok`,
    method: "GET",
    badgeColor: "#2ca02c",
  },
  {
    id: "slow",
    label: "Slow (3s)",
    description: "3-second artificial delay — triggers P99 latency spike",
    url: `${API}/slow?ms=3000`,
    method: "GET",
    badgeColor: "#ff7f0e",
  },
  {
    id: "slow5",
    label: "Very slow (5s)",
    description: "5-second artificial delay — triggers latency alarm",
    url: `${API}/slow?ms=5000`,
    method: "GET",
    badgeColor: "#ff7f0e",
  },
  {
    id: "fail",
    label: "500 Error",
    description: "Intentional 500 — triggers 5xx alarm and error logs",
    url: `${API}/fail`,
    method: "GET",
    badgeColor: "#d62728",
  },
  {
    id: "dependency",
    label: "Dependency (30% fail)",
    description: "Simulates a flaky downstream service",
    url: `${API}/dependency?failRate=0.3&latencyMs=800`,
    method: "GET",
    badgeColor: "#9467bd",
  },
  {
    id: "items",
    label: "List items",
    description: "Normal business read — clean 200 traffic",
    url: `${API}/items`,
    method: "GET",
    badgeColor: "#1f77b4",
  },
];

function ResultBox({ result }) {
  if (!result) return null;

  const isError = result.status >= 400;
  const color = isError ? "#d62728" : "#2ca02c";

  return (
    <div
      style={{
        marginTop: 12,
        padding: "12px 16px",
        borderRadius: 6,
        border: `1px solid ${color}`,
        background: isError ? "#fff5f5" : "#f6fff6",
        fontFamily: "monospace",
        fontSize: 13,
      }}
    >
      <div style={{ marginBottom: 6, color }}>
        <strong>HTTP {result.status}</strong> — {result.durationMs}ms
      </div>
      <pre style={{ margin: 0, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
        {JSON.stringify(result.body, null, 2)}
      </pre>
    </div>
  );
}

function EndpointCard({ endpoint }) {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  const call = async () => {
    setLoading(true);
    setResult(null);
    const start = Date.now();
    try {
      const res = await fetch(endpoint.url, { method: endpoint.method });
      const body = await res.json().catch(() => ({}));
      setResult({ status: res.status, body, durationMs: Date.now() - start });
    } catch (err) {
      setResult({ status: 0, body: { error: err.message }, durationMs: Date.now() - start });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        border: "1px solid #e0e0e0",
        borderRadius: 8,
        padding: 16,
        marginBottom: 12,
        background: "#fff",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
        <span
          style={{
            background: endpoint.badgeColor,
            color: "#fff",
            borderRadius: 4,
            padding: "2px 8px",
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          {endpoint.method}
        </span>
        <strong>{endpoint.label}</strong>
      </div>
      <div style={{ fontSize: 13, color: "#555", marginBottom: 10 }}>
        {endpoint.description}
      </div>
      <div style={{ fontSize: 12, color: "#999", fontFamily: "monospace", marginBottom: 10 }}>
        {endpoint.url}
      </div>
      <button
        onClick={call}
        disabled={loading}
        style={{
          padding: "6px 16px",
          borderRadius: 5,
          border: "none",
          background: loading ? "#ccc" : "#1f77b4",
          color: "#fff",
          cursor: loading ? "not-allowed" : "pointer",
          fontWeight: 600,
        }}
      >
        {loading ? "Calling…" : "Call endpoint"}
      </button>
      <ResultBox result={result} />
    </div>
  );
}

export default function App() {
  const [burstLoading, setBurstLoading] = useState(false);
  const [burstResults, setBurstResults] = useState(null);

  const runBurst = async () => {
    setBurstLoading(true);
    setBurstResults(null);

    // Fire 10 mixed requests to generate visible traffic
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
    <div
      style={{
        maxWidth: 760,
        margin: "0 auto",
        padding: "32px 16px",
        fontFamily: "'Segoe UI', system-ui, sans-serif",
        color: "#222",
      }}
    >
      <h1 style={{ margin: "0 0 4px" }}>aws-observability-dashboard</h1>
      <p style={{ color: "#666", marginTop: 0, marginBottom: 24 }}>
        Demo app — fire requests to generate signals for CloudWatch dashboards,
        alarms, and Logs Insights queries.
      </p>

      <div
        style={{
          background: "#f8f8f8",
          border: "1px solid #ddd",
          borderRadius: 8,
          padding: "16px 20px",
          marginBottom: 28,
        }}
      >
        <h3 style={{ margin: "0 0 8px" }}>Generate burst traffic</h3>
        <p style={{ margin: "0 0 12px", fontSize: 14, color: "#555" }}>
          Fires 10 mixed requests across all endpoints simultaneously — useful
          for populating dashboards quickly.
        </p>
        <button
          onClick={runBurst}
          disabled={burstLoading}
          style={{
            padding: "8px 20px",
            borderRadius: 5,
            border: "none",
            background: burstLoading ? "#ccc" : "#2ca02c",
            color: "#fff",
            cursor: burstLoading ? "not-allowed" : "pointer",
            fontWeight: 600,
            fontSize: 14,
          }}
        >
          {burstLoading ? "Running burst…" : "Run burst"}
        </button>
        {burstResults && (
          <div style={{ marginTop: 10, fontFamily: "monospace", fontSize: 13 }}>
            Burst results: {JSON.stringify(burstResults)}
          </div>
        )}
      </div>

      <h2 style={{ marginBottom: 12 }}>Individual endpoints</h2>
      {ENDPOINTS.map((ep) => (
        <EndpointCard key={ep.id} endpoint={ep} />
      ))}

      <div style={{ marginTop: 32, paddingTop: 16, borderTop: "1px solid #eee", fontSize: 13, color: "#999" }}>
        Backend API:{" "}
        <code style={{ background: "#f0f0f0", padding: "2px 6px", borderRadius: 3 }}>
          {API}
        </code>
      </div>
    </div>
  );
}
