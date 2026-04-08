/**
 * ArchDiagram — SVG architecture diagram with animated request flows.
 *
 * Nodes: Browser → CloudFront → ALB → ECS Backend → Downstream
 * When a request is in-flight, a packet dot travels from the browser
 * along the relevant path. On completion the destination node briefly
 * flashes green (success) or red (error). Live metrics from /api/metrics
 * are shown on the Backend and Downstream nodes.
 */

import { useEffect, useRef } from "react";

// ── Layout constants ──────────────────────────────────────────────────────────

const W = 780;
const H = 260;

const NODES = {
  browser:     { x: 30,  y: 110, label: "Browser",     icon: "🌐", monitored: false },
  cloudfront:  { x: 175, y: 110, label: "CloudFront",  icon: "☁️",  monitored: false },
  alb:         { x: 340, y: 110, label: "ALB",          icon: "⚖️",  monitored: true  },
  backend:     { x: 510, y: 110, label: "ECS Backend",  icon: "📦", monitored: true  },
  downstream:  { x: 510, y: 210, label: "Downstream",   icon: "🔗", monitored: false },
};

const NODE_W = 110;
const NODE_H = 50;

// Centre of each node box
function cx(id) { return NODES[id].x + NODE_W / 2; }
function cy(id) { return NODES[id].y + NODE_H / 2; }

// Edges: [from, to, pathId]
const EDGES = [
  ["browser",    "cloudfront", "e-br-cf"],
  ["cloudfront", "alb",        "e-cf-al"],
  ["alb",        "backend",    "e-al-be"],
  ["backend",    "downstream", "e-be-ds"],
];

// Which edges + destination are active for each endpoint id
const FLOW_MAP = {
  ok:         { edges: ["e-br-cf", "e-cf-al", "e-al-be"], dest: "backend"    },
  slow:       { edges: ["e-br-cf", "e-cf-al", "e-al-be"], dest: "backend"    },
  slow5:      { edges: ["e-br-cf", "e-cf-al", "e-al-be"], dest: "backend"    },
  fail:       { edges: ["e-br-cf", "e-cf-al", "e-al-be"], dest: "backend"    },
  dependency: { edges: ["e-br-cf", "e-cf-al", "e-al-be", "e-be-ds"], dest: "downstream" },
  items:      { edges: ["e-br-cf", "e-cf-al", "e-al-be"], dest: "backend"    },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function edgePath(fromId, toId) {
  const x1 = NODES[fromId].x + NODE_W;
  const y1 = NODES[fromId].y + NODE_H / 2;

  // backend → downstream is vertical
  if (fromId === "backend" && toId === "downstream") {
    const x2 = NODES[toId].x + NODE_W / 2;
    const y2 = NODES[toId].y;
    return `M ${cx("backend")} ${NODES["backend"].y + NODE_H} L ${x2} ${y2}`;
  }

  const x2 = NODES[toId].x;
  const y2 = NODES[toId].y + NODE_H / 2;
  return `M ${x1} ${y1} L ${x2} ${y2}`;
}

function nodeColor(id, flight, metrics) {
  if (flight?.dest === id && flight.phase === "received") {
    return flight.error ? "#d62728" : "#2ca02c";
  }
  if (flight?.edges?.includes(`e-al-be`) && id === "alb" && flight.phase === "flying") {
    return "#1f77b4";
  }
  // Colour by recent error rate
  if (metrics && id === "backend") {
    const r = metrics.total.errorRate;
    if (r >= 50) return "#d62728";
    if (r >= 10) return "#ff7f0e";
    if (metrics.total.requests > 0) return "#2ca02c";
  }
  return "#f0f4ff";
}

function nodeStroke(id, flight) {
  if (flight?.dest === id && flight.phase !== "idle") return 2.5;
  if (NODES[id].monitored) return 1.5;
  return 1;
}

function nodeStrokeColor(id, flight, metrics) {
  const bg = nodeColor(id, flight, metrics);
  if (bg !== "#f0f4ff") return bg;
  if (NODES[id].monitored) return "#6b9bd1";
  return "#ccc";
}

// ── Packet dot animation ──────────────────────────────────────────────────────

function PacketDot({ flightEdges, phase, durationMs, error }) {
  if (phase !== "flying") return null;

  // Animate one dot per active edge, staggered
  return flightEdges.map((edgeId, i) => {
    const edge = EDGES.find((e) => e[2] === edgeId);
    if (!edge) return null;
    const d = edgePath(edge[0], edge[1]);
    const delay = (i * durationMs) / (flightEdges.length * 2.5);
    return (
      <circle key={edgeId} r={6} fill={error ? "#d62728" : "#1f77b4"} opacity={0.9}>
        <animateMotion
          dur={`${durationMs / 1000}s`}
          begin={`${delay / 1000}s`}
          fill="freeze"
          calcMode="spline"
          keySplines="0.4 0 0.6 1"
        >
          <mpath href={`#${edgeId}`} />
        </animateMotion>
      </circle>
    );
  });
}

// ── Metric badge on a node ────────────────────────────────────────────────────

function MetricBadge({ nodeId, metrics }) {
  if (!metrics || nodeId !== "backend") return null;
  const { requests, errorRate, avgLatencyMs } = metrics.total;
  if (requests === 0) return null;

  const bg = errorRate >= 50 ? "#d62728" : errorRate >= 10 ? "#ff7f0e" : "#2ca02c";
  const nx = NODES[nodeId].x;
  const ny = NODES[nodeId].y;

  return (
    <g>
      <rect x={nx} y={ny - 28} width={NODE_W} height={22} rx={4} fill={bg} opacity={0.9} />
      <text x={nx + NODE_W / 2} y={ny - 13} textAnchor="middle" fontSize={10} fill="#fff" fontFamily="monospace">
        {requests}req · {errorRate}%err · {avgLatencyMs}ms
      </text>
    </g>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function ArchDiagram({ flight, metrics }) {
  const activeEdges = flight?.phase === "flying" ? flight.edges : [];

  return (
    <div style={{ background: "#fafbff", border: "1px solid #dde4f0", borderRadius: 8, padding: "12px 8px 4px" }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: "block" }}>
        <defs>
          <marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#bbb" />
          </marker>
          {/* Define edge paths for animateMotion mpath references */}
          {EDGES.map(([from, to, id]) => (
            <path key={id} id={id} d={edgePath(from, to)} fill="none" />
          ))}
        </defs>

        {/* ── Edges ── */}
        {EDGES.map(([from, to, id]) => {
          const active = activeEdges.includes(id);
          return (
            <path
              key={id}
              d={edgePath(from, to)}
              fill="none"
              stroke={active ? "#1f77b4" : "#ccc"}
              strokeWidth={active ? 2.5 : 1.5}
              strokeDasharray={active ? "6 3" : "none"}
              markerEnd="url(#arrow)"
              style={active ? { animation: "march 0.4s linear infinite" } : {}}
            />
          );
        })}

        {/* ── Packet dots ── */}
        <PacketDot
          key={flight?.id}
          flightEdges={flight?.edges ?? []}
          phase={flight?.phase}
          durationMs={flight?.durationMs ?? 600}
          error={flight?.error}
        />

        {/* ── Nodes ── */}
        {Object.entries(NODES).map(([id, node]) => {
          const bg = nodeColor(id, flight, metrics);
          const stroke = nodeStrokeColor(id, flight, metrics);
          const sw = nodeStroke(id, flight);
          const isActive = flight?.dest === id && flight.phase !== "idle";

          return (
            <g key={id}>
              <MetricBadge nodeId={id} metrics={metrics} />
              <rect
                x={node.x}
                y={node.y}
                width={NODE_W}
                height={NODE_H}
                rx={8}
                fill={bg}
                stroke={stroke}
                strokeWidth={sw}
                style={isActive && flight.phase === "received" ? { animation: "pulse 0.4s ease-out" } : {}}
              />
              {/* Monitored badge */}
              {node.monitored && (
                <text x={node.x + NODE_W - 6} y={node.y + 12} textAnchor="end" fontSize={9} fill="#6b9bd1">
                  ◉ monitored
                </text>
              )}
              <text x={node.x + NODE_W / 2} y={node.y + 19} textAnchor="middle" fontSize={16}>
                {node.icon}
              </text>
              <text
                x={node.x + NODE_W / 2}
                y={node.y + 38}
                textAnchor="middle"
                fontSize={11}
                fontWeight={600}
                fill={bg === "#f0f4ff" ? "#333" : "#fff"}
                fontFamily="system-ui, sans-serif"
              >
                {node.label}
              </text>
            </g>
          );
        })}

        {/* ── Legend ── */}
        <text x={8} y={H - 6} fontSize={10} fill="#aaa" fontFamily="system-ui">
          Last 60s · auto-refreshes every 5s
        </text>
      </svg>

      <style>{`
        @keyframes march {
          to { stroke-dashoffset: -18; }
        }
        @keyframes pulse {
          0%   { opacity: 1; }
          50%  { opacity: 0.4; }
          100% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}
