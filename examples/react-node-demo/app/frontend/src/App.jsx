import { useState, useEffect, useCallback } from "react";
import ArchDiagram from "./ArchDiagramScene.jsx";
import Charts from "./Charts.jsx";

const API = import.meta.env.VITE_API_URL ?? "/api";

const ENDPOINTS = [
  { id: "ok",         label: "Healthy",          description: "Fast 200 — normal traffic",                url: `${API}/ok`,                                    method: "GET", badgeColor: "#3fb950" },
  { id: "slow",       label: "Slow (3s)",         description: "3-second delay — P99 latency spike",      url: `${API}/slow?ms=3000`,                          method: "GET", badgeColor: "#d29922" },
  { id: "slow5",      label: "Very slow (5s)",    description: "5-second delay — triggers latency alarm", url: `${API}/slow?ms=5000`,                          method: "GET", badgeColor: "#d29922" },
  { id: "fail",       label: "500 Error",         description: "Intentional 500 — triggers 5xx alarm",   url: `${API}/fail`,                                  method: "GET", badgeColor: "#f85149" },
  { id: "dependency", label: "Dependency (30%↯)", description: "Flaky downstream — shows dependency path", url: `${API}/dependency?failRate=0.3&latencyMs=800`, method: "GET", badgeColor: "#bc8cff" },
  { id: "items",      label: "List items",        description: "Normal business read — clean 200 traffic", url: `${API}/items`,                                method: "GET", badgeColor: "#58a6ff" },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

function statusColor(s) {
  if (!s || s === 0) return "#f85149";
  if (s >= 500) return "#f85149";
  if (s >= 400) return "#d29922";
  return "#3fb950";
}

function endpointPath(url) {
  try {
    const q = url.indexOf("?");
    return new URL(q === -1 ? url : url.slice(0, q), location.href).pathname;
  } catch {
    const q = url.indexOf("?");
    return q === -1 ? url : url.slice(0, q);
  }
}

// Visual animation timing — decoupled from actual request latency so the packet
// is always visible regardless of how fast the server responds.
const VISUAL_MS = 1600;      // per-edge animateMotion duration
const RECEIVED_AT_MS = 1850; // trigger "received" state when packet is ~95% across last edge

// ── Endpoint card ─────────────────────────────────────────────────────────────

function EndpointCard({ endpoint, onFlight, onComplete }) {
  const [loading, setLoading] = useState(false);

  const call = async () => {
    setLoading(true);
    const flightId = `${endpoint.id}-${Date.now()}`;
    const animStart = Date.now();
    const edges = endpoint.id === "dependency"
      ? ["e-br-cf", "e-cf-al", "e-al-be", "e-be-ds"]
      : ["e-br-cf", "e-cf-al", "e-al-be"];
    const dest = endpoint.id === "dependency" ? "downstream" : "backend";

    onFlight({
      id: flightId,
      endpointId: endpoint.id,
      edges,
      dest,
      durationMs: VISUAL_MS,
      phase: "flying",
      error: false,
    });

    const start = Date.now();
    try {
      const res = await fetch(endpoint.url, { method: endpoint.method });
      await res.json().catch(() => {});
      const durationMs = Date.now() - start;
      // Re-enable the button as soon as the response arrives.
      setLoading(false);
      // Log with real timing immediately so the request log is accurate.
      onComplete({ id: flightId, method: endpoint.method, path: endpointPath(endpoint.url), status: res.status, durationMs, ts: Date.now() });
      // For fast requests: wait until the packet is near the end of the path before flashing.
      // For slow requests (> RECEIVED_AT_MS): transition happens immediately.
      const wait = Math.max(0, RECEIVED_AT_MS - (Date.now() - animStart));
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      onFlight((f) => f?.id === flightId ? { ...f, phase: "received", error: res.status >= 500 } : f);
      setTimeout(() => onFlight((f) => f?.id === flightId ? null : f), 1500);
    } catch (err) {
      const durationMs = Date.now() - start;
      setLoading(false);
      onComplete({ id: flightId, method: endpoint.method, path: endpointPath(endpoint.url), status: 0, durationMs, ts: Date.now() });
      const wait = Math.max(0, RECEIVED_AT_MS - (Date.now() - animStart));
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      onFlight((f) => f?.id === flightId ? { ...f, phase: "received", error: true } : f);
      setTimeout(() => onFlight((f) => f?.id === flightId ? null : f), 1500);
    }
  };

  return (
    <div style={{
      background: "#161b22",
      border: `1px solid ${loading ? "#388bfd44" : "#30363d"}`,
      borderRadius: 8,
      padding: "10px 12px",
      transition: "border-color 0.15s",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 3 }}>
        <span style={{
          fontSize: 9,
          fontWeight: 700,
          padding: "1px 5px",
          borderRadius: 3,
          background: endpoint.badgeColor + "22",
          color: endpoint.badgeColor,
          border: `1px solid ${endpoint.badgeColor}44`,
          letterSpacing: 0.5,
        }}>
          {endpoint.method}
        </span>
        <span style={{ fontSize: 12, fontWeight: 600, color: "#e6edf3" }}>{endpoint.label}</span>
        {loading && (
          <span style={{ marginLeft: "auto", color: "#388bfd", fontSize: 12, fontWeight: 700, letterSpacing: 2 }}>
            ···
          </span>
        )}
      </div>
      <div style={{ fontSize: 11, color: "#6e7681", marginBottom: 8, lineHeight: 1.4 }}>
        {endpoint.description}
      </div>
      <button
        onClick={call}
        disabled={loading}
        style={{
          width: "100%",
          padding: "5px 0",
          borderRadius: 5,
          border: `1px solid ${loading ? "#21262d" : "#388bfd"}`,
          background: loading ? "transparent" : "#1c2d4a",
          color: loading ? "#484f58" : "#58a6ff",
          cursor: loading ? "not-allowed" : "pointer",
          fontWeight: 600,
          fontSize: 11,
          transition: "all 0.15s",
        }}
      >
        {loading ? "In flight…" : "Fire request"}
      </button>
    </div>
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

function StatCard({ label, value, unit = "", accent, note }) {
  return (
    <div style={{
      background: "#161b22",
      border: "1px solid #30363d",
      borderTop: `2px solid ${accent}`,
      borderRadius: 8,
      padding: "14px 16px",
      flex: 1,
      minWidth: 0,
    }}>
      <div style={{
        fontSize: 26,
        fontWeight: 700,
        color: "#e6edf3",
        fontVariantNumeric: "tabular-nums",
        lineHeight: 1.1,
      }}>
        {value}
        {unit && (
          <span style={{ fontSize: 13, fontWeight: 400, color: "#6e7681", marginLeft: 2 }}>
            {unit}
          </span>
        )}
      </div>
      <div style={{ fontSize: 11, color: "#8b949e", marginTop: 5 }}>{label}</div>
      {note && <div style={{ fontSize: 10, color: "#484f58", marginTop: 2 }}>{note}</div>}
    </div>
  );
}

// ── Section heading ───────────────────────────────────────────────────────────

function SectionHeading({ children }) {
  return (
    <div style={{
      fontSize: 11,
      fontWeight: 600,
      color: "#8b949e",
      letterSpacing: "0.08em",
      textTransform: "uppercase",
      marginBottom: 10,
      paddingBottom: 6,
      borderBottom: "1px solid #21262d",
    }}>
      {children}
    </div>
  );
}

// ── Request log ───────────────────────────────────────────────────────────────

function RequestLog({ log }) {
  if (!log.length) {
    return (
      <div style={{ padding: "14px 16px", color: "#484f58", fontSize: 12, textAlign: "center" }}>
        No requests yet — fire one above
      </div>
    );
  }
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 3, maxHeight: 180, overflowY: "auto" }}>
      {log.map((r, i) => (
        <div
          key={r.id}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            padding: "4px 10px",
            borderRadius: 5,
            background: i === 0 ? "#161b22" : "transparent",
            border: `1px solid ${i === 0 ? "#30363d" : "transparent"}`,
            fontFamily: "'Consolas', 'Courier New', monospace",
            fontSize: 11,
            animation: i === 0 ? "slide-in 0.2s ease-out" : "none",
          }}
        >
          <span style={{ color: statusColor(r.status), fontWeight: 700, minWidth: 30 }}>
            {r.status || "ERR"}
          </span>
          <span style={{ color: "#6e7681", fontSize: 10 }}>{r.method}</span>
          <span style={{ color: "#8b949e" }}>{r.path}</span>
          <span style={{ marginLeft: "auto", color: "#484f58", fontSize: 10 }}>{r.durationMs}ms</span>
        </div>
      ))}
    </div>
  );
}

// ── Main app ──────────────────────────────────────────────────────────────────

export default function App() {
  const [flight, setFlight] = useState(null);
  const [metrics, setMetrics] = useState(null);
  const [burstLoading, setBurstLoading] = useState(false);
  const [burstResults, setBurstResults] = useState(null);
  const [requestLog, setRequestLog] = useState([]);

  useEffect(() => {
    const poll = () =>
      fetch(`${API}/metrics`)
        .then((r) => r.json())
        .then(setMetrics)
        .catch(() => {});
    poll();
    const id = setInterval(poll, 5000);
    return () => clearInterval(id);
  }, []);

  const handleComplete = useCallback((entry) => {
    setRequestLog((prev) => [entry, ...prev].slice(0, 20));
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
      const b = s >= 500 ? "5xx" : s >= 400 ? "4xx" : s >= 200 ? "2xx" : "err";
      acc[b] = (acc[b] ?? 0) + 1;
      return acc;
    }, {});
    setBurstResults(summary);
    setBurstLoading(false);
  };

  const t = metrics?.total;
  const errorAccent = t
    ? t.errorRate >= 50 ? "#f85149" : t.errorRate >= 10 ? "#d29922" : "#3fb950"
    : "#484f58";

  return (
    <div style={{ maxWidth: 1400, margin: "0 auto", padding: "24px 20px 48px" }}>

      {/* ── Header ── */}
      <div style={{
        display: "flex",
        alignItems: "flex-start",
        justifyContent: "space-between",
        marginBottom: 20,
      }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700, color: "#e6edf3", margin: 0, letterSpacing: "-0.02em" }}>
            aws-observability-dashboard
          </h1>
          <p style={{ fontSize: 13, color: "#6e7681", margin: "4px 0 0", lineHeight: 1.5 }}>
            Fire requests to generate CloudWatch signals — watch metrics, alarms, and traffic flow in real time.
          </p>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, paddingTop: 4, flexShrink: 0 }}>
          <div style={{
            width: 7,
            height: 7,
            borderRadius: "50%",
            background: "#3fb950",
            animation: "live-pulse 2s ease-in-out infinite",
          }} />
          <span style={{ fontSize: 11, color: "#3fb950", fontWeight: 700, letterSpacing: "0.08em" }}>
            LIVE
          </span>
        </div>
      </div>

      {/* ── Stat cards ── */}
      <div style={{ display: "flex", gap: 10, marginBottom: 20 }}>
        <StatCard
          label="Requests (last 60s)"
          value={t?.requests ?? "—"}
          accent="#58a6ff"
          note="rolling window"
        />
        <StatCard
          label="Error rate"
          value={t ? `${t.errorRate}` : "—"}
          unit="%"
          accent={errorAccent}
          note={t?.errors ? `${t.errors} error${t.errors !== 1 ? "s" : ""}` : "no errors"}
        />
        <StatCard
          label="Avg latency"
          value={t?.avgLatencyMs ?? "—"}
          unit="ms"
          accent="#d29922"
          note="all routes"
        />
        <StatCard
          label="Package surface"
          value="5"
          accent="#bc8cff"
          note="dashboard + alarms + logs + canaries + app signals"
        />
      </div>

      {/* ── Architecture diagram ── */}
      <div style={{ marginBottom: 20 }}>
        <SectionHeading>Architecture</SectionHeading>
        <ArchDiagram flight={flight} metrics={metrics} />
      </div>

      {/* ── Two-column layout ── */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 340px", gap: 20, marginBottom: 20 }}>

        {/* Left: endpoint cards + burst */}
        <div>
          <SectionHeading>Endpoints</SectionHeading>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 12 }}>
            {ENDPOINTS.map((ep) => (
              <EndpointCard
                key={ep.id}
                endpoint={ep}
                onFlight={setFlight}
                onComplete={handleComplete}
              />
            ))}
          </div>

          {/* Burst panel */}
          <div style={{
            background: "#161b22",
            border: "1px solid #30363d",
            borderRadius: 8,
            padding: "14px 16px",
          }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: "#e6edf3", marginBottom: 4 }}>
              Burst traffic
            </div>
            <div style={{ fontSize: 11, color: "#6e7681", marginBottom: 12, lineHeight: 1.5 }}>
              10 concurrent requests across all endpoints — generates immediate signal spikes visible in CloudWatch.
            </div>
            <button
              onClick={runBurst}
              disabled={burstLoading}
              style={{
                width: "100%",
                padding: "7px 0",
                borderRadius: 6,
                border: `1px solid ${burstLoading ? "#21262d" : "#3fb95055"}`,
                background: burstLoading ? "transparent" : "#0f2819",
                color: burstLoading ? "#484f58" : "#3fb950",
                cursor: burstLoading ? "not-allowed" : "pointer",
                fontWeight: 600,
                fontSize: 12,
                transition: "all 0.15s",
              }}
            >
              {burstLoading ? "Running burst…" : "Run burst"}
            </button>
            {burstResults && (
              <div style={{ marginTop: 10, display: "flex", gap: 6, flexWrap: "wrap" }}>
                {Object.entries(burstResults).map(([b, count]) => (
                  <div
                    key={b}
                    style={{
                      padding: "3px 8px",
                      borderRadius: 4,
                      background: b === "5xx" || b === "err" ? "#2d1117" : "#0f2819",
                      color: b === "5xx" || b === "err" ? "#f85149" : "#3fb950",
                      fontFamily: "monospace",
                      fontSize: 11,
                      fontWeight: 600,
                      border: `1px solid ${b === "5xx" || b === "err" ? "#f8514933" : "#3fb95033"}`,
                    }}
                  >
                    {b}: {count}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right: sparkline charts + route breakdown */}
        <div>
          <SectionHeading>Signals (last 5 min)</SectionHeading>
          <Charts history={metrics?.history} />

          {metrics?.routes && Object.keys(metrics.routes).length > 0 && (
            <div style={{
              background: "#161b22",
              border: "1px solid #30363d",
              borderRadius: 8,
              overflow: "hidden",
              marginTop: 8,
            }}>
              <div style={{
                padding: "8px 12px",
                borderBottom: "1px solid #21262d",
                fontSize: 10,
                color: "#6e7681",
                fontWeight: 600,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
              }}>
                Routes · last 60s
              </div>
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 11 }}>
                <tbody>
                  {Object.entries(metrics.routes).map(([route, r]) => (
                    <tr key={route} style={{ borderBottom: "1px solid #21262d" }}>
                      <td style={{
                        padding: "5px 12px",
                        fontFamily: "'Consolas', monospace",
                        color: "#8b949e",
                        fontSize: 10,
                      }}>
                        {route}
                      </td>
                      <td style={{
                        padding: "5px 6px",
                        textAlign: "right",
                        color: "#e6edf3",
                        fontVariantNumeric: "tabular-nums",
                      }}>
                        {r.requests}
                      </td>
                      <td style={{
                        padding: "5px 6px",
                        textAlign: "right",
                        color: r.errorRate > 0 ? "#f85149" : "#3fb950",
                        fontVariantNumeric: "tabular-nums",
                      }}>
                        {r.errorRate > 0 ? `${r.errorRate}%` : "✓"}
                      </td>
                      <td style={{
                        padding: "5px 12px",
                        textAlign: "right",
                        color: "#6e7681",
                        fontVariantNumeric: "tabular-nums",
                      }}>
                        {r.avgLatencyMs}ms
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* ── Request log ── */}
      <div style={{ background: "#161b22", border: "1px solid #30363d", borderRadius: 8, overflow: "hidden" }}>
        <div style={{
          padding: "10px 14px",
          borderBottom: "1px solid #21262d",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}>
          <div style={{
            fontSize: 11,
            fontWeight: 600,
            color: "#8b949e",
            letterSpacing: "0.08em",
            textTransform: "uppercase",
          }}>
            Request log
          </div>
          <div style={{ fontSize: 10, color: "#484f58" }}>
            {requestLog.length > 0 ? `last ${requestLog.length}` : "empty"}
          </div>
        </div>
        <div style={{ padding: "8px 6px" }}>
          <RequestLog log={requestLog} />
        </div>
      </div>
    </div>
  );
}
