/**
 * ArchDiagram — Dark-themed SVG architecture diagram with animated request flows.
 *
 * Nodes: Browser → CloudFront → ALB → ECS Backend → Downstream
 * Features:
 *   - Dot-grid dark background
 *   - Glowing edges with marching dashes when requests are in flight
 *   - Pulse rings on destination node during flight
 *   - Glowing packet orb travelling along the active path
 *   - Node health colouring based on live error-rate metrics
 *   - Live metrics badge above backend node
 */

// ── Layout constants ──────────────────────────────────────────────────────────

const W = 800;
const H = 248;
const NODE_W = 130;
const NODE_H = 52;

const NODES = {
  browser:    { x: 14,  y: 88,  label: "Browser",    icon: "🌐", monitored: false },
  cloudfront: { x: 182, y: 88,  label: "CloudFront", icon: "☁️",  monitored: false },
  alb:        { x: 350, y: 88,  label: "ALB",         icon: "⚖️",  monitored: true  },
  backend:    { x: 518, y: 88,  label: "Backend",     icon: "📦", monitored: true  },
  downstream: { x: 518, y: 178, label: "Downstream",  icon: "🔗", monitored: false },
};

function cx(id) { return NODES[id].x + NODE_W / 2; }
function cy(id) { return NODES[id].y + NODE_H / 2; }

const EDGES = [
  ["browser",    "cloudfront", "e-br-cf"],
  ["cloudfront", "alb",        "e-cf-al"],
  ["alb",        "backend",    "e-al-be"],
  ["backend",    "downstream", "e-be-ds"],
];

function edgePath(fromId, toId) {
  if (fromId === "backend" && toId === "downstream") {
    return `M ${cx("backend")} ${NODES.backend.y + NODE_H} L ${cx("downstream")} ${NODES.downstream.y}`;
  }
  return `M ${NODES[fromId].x + NODE_W} ${cy(fromId)} L ${NODES[toId].x} ${cy(toId)}`;
}

// ── Node state ────────────────────────────────────────────────────────────────

function nodeStyle(id, flight, metrics) {
  const node = NODES[id];

  if (flight?.dest === id && flight.phase === "received") {
    return flight.error
      ? { fill: "#2d1117", stroke: "#f85149", sw: 2.5, filter: "url(#glow)", textColor: "#e6edf3" }
      : { fill: "#0d2010", stroke: "#3fb950", sw: 2.5, filter: "url(#glow)", textColor: "#e6edf3" };
  }

  if (id === "alb" && flight?.phase === "flying" && flight.edges.includes("e-al-be")) {
    return { fill: "#0d1f40", stroke: "#58a6ff", sw: 2, filter: "url(#glow)", textColor: "#e6edf3" };
  }

  if (id === "backend" && metrics?.total.requests > 0) {
    const r = metrics.total.errorRate;
    if (r >= 50) return { fill: "#2d1117", stroke: "#f85149", sw: 2, filter: "url(#glow)",    textColor: "#e6edf3" };
    if (r >= 10) return { fill: "#1e180a", stroke: "#d29922", sw: 2, filter: "url(#glow-sm)", textColor: "#e6edf3" };
    return         { fill: "#0d2010", stroke: "#3fb950", sw: 1.5, filter: "url(#glow-sm)",    textColor: "#e6edf3" };
  }

  if (node.monitored) {
    return { fill: "#0d1831", stroke: "#1f4788", sw: 1.5, filter: null, textColor: "#6e7681" };
  }

  return { fill: "#161b22", stroke: "#30363d", sw: 1.5, filter: null, textColor: "#6e7681" };
}

// ── Sub-components ────────────────────────────────────────────────────────────

function PulseRing({ nodeId, flight }) {
  if (flight?.dest !== nodeId || flight.phase !== "flying") return null;
  const color = flight.error ? "#f85149" : "#58a6ff";
  const ncx = cx(nodeId);
  const ncy = cy(nodeId);
  return (
    <>
      <circle cx={ncx} cy={ncy} r={30} fill="none" stroke={color} strokeWidth={1.5} opacity={0}>
        <animate attributeName="r"       from="28" to="52" dur="1.3s" repeatCount="indefinite" />
        <animate attributeName="opacity" from="0.7" to="0" dur="1.3s" repeatCount="indefinite" />
      </circle>
      <circle cx={ncx} cy={ncy} r={30} fill="none" stroke={color} strokeWidth={1} opacity={0}>
        <animate attributeName="r"       from="28" to="52" dur="1.3s" begin="0.65s" repeatCount="indefinite" />
        <animate attributeName="opacity" from="0.5" to="0" dur="1.3s" begin="0.65s" repeatCount="indefinite" />
      </circle>
    </>
  );
}

function PacketDot({ flightEdges, phase, durationMs, error }) {
  if (phase !== "flying") return null;
  const color = error ? "#f85149" : "#58a6ff";
  const glowFilter = "url(#glow)";

  return flightEdges.map((edgeId, i) => {
    const edge = EDGES.find((e) => e[2] === edgeId);
    if (!edge) return null;
    const delay = (i * durationMs) / (flightEdges.length * 2.5);
    const dur = `${durationMs / 1000}s`;
    const begin = `${delay / 1000}s`;
    return (
      <g key={edgeId}>
        <circle r={12} fill={color} opacity={0.12} filter="url(#blur-corona)">
          <animateMotion dur={dur} begin={begin} fill="freeze" calcMode="spline" keySplines="0.4 0 0.6 1">
            <mpath href={`#${edgeId}`} />
          </animateMotion>
        </circle>
        <circle r={5} fill={color} opacity={0.95} filter={glowFilter}>
          <animateMotion dur={dur} begin={begin} fill="freeze" calcMode="spline" keySplines="0.4 0 0.6 1">
            <mpath href={`#${edgeId}`} />
          </animateMotion>
        </circle>
      </g>
    );
  });
}

function MetricBadge({ metrics }) {
  if (!metrics?.total.requests) return null;
  const { requests, errorRate, avgLatencyMs } = metrics.total;
  const color = errorRate >= 50 ? "#f85149" : errorRate >= 10 ? "#d29922" : "#3fb950";
  const nx = NODES.backend.x;
  const ny = NODES.backend.y;
  return (
    <g>
      <rect x={nx} y={ny - 24} width={NODE_W} height={18} rx={4}
        fill="#0d1117" stroke={color} strokeWidth={0.75} opacity={0.95} />
      <text x={nx + NODE_W / 2} y={ny - 11} textAnchor="middle"
        fontSize={9.5} fill={color}
        fontFamily="'Consolas', 'Courier New', monospace" fontWeight={600}>
        {requests}req · {errorRate}%err · {avgLatencyMs}ms avg
      </text>
    </g>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function ArchDiagram({ flight, metrics }) {
  const activeEdges = flight?.phase === "flying" ? flight.edges : [];

  return (
    <div style={{
      background: "#0d1117",
      border: "1px solid #30363d",
      borderRadius: 10,
      padding: "12px 10px 8px",
    }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: "block" }}>
        <defs>
          {/* Dot-grid background pattern */}
          <pattern id="dot-grid" patternUnits="userSpaceOnUse" width="22" height="22">
            <circle cx="11" cy="11" r="0.85" fill="#21262d" />
          </pattern>

          {/* Glow filters — colour comes from SourceGraphic, blur creates the halo */}
          <filter id="glow" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="3.5" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
          <filter id="glow-sm" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="2.5" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
          <filter id="blur-corona" x="-150%" y="-150%" width="400%" height="400%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="5" />
          </filter>

          {/* Arrow markers */}
          <marker id="arr-off" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
            <path d="M0,0.5 L0,5.5 L7,3 z" fill="#30363d" />
          </marker>
          <marker id="arr-on" markerWidth="7" markerHeight="7" refX="5" refY="3" orient="auto">
            <path d="M0,0.5 L0,5.5 L7,3 z" fill="#58a6ff" />
          </marker>

          {/* Edge paths for animateMotion mpath references */}
          {EDGES.map(([from, to, id]) => (
            <path key={id} id={id} d={edgePath(from, to)} fill="none" />
          ))}
        </defs>

        {/* Background */}
        <rect width={W} height={H} fill="#0d1117" />
        <rect width={W} height={H} fill="url(#dot-grid)" opacity={0.65} />

        {/* Edges */}
        {EDGES.map(([from, to, id]) => {
          const active = activeEdges.includes(id);
          return (
            <path
              key={id}
              d={edgePath(from, to)}
              fill="none"
              stroke={active ? "#58a6ff" : "#21262d"}
              strokeWidth={active ? 2.5 : 1.5}
              strokeDasharray={active ? "6 3" : "none"}
              markerEnd={active ? "url(#arr-on)" : "url(#arr-off)"}
              filter={active ? "url(#glow)" : undefined}
              style={active ? { animation: "march 0.4s linear infinite" } : {}}
            />
          );
        })}

        {/* Pulse rings (behind nodes) */}
        {Object.keys(NODES).map((id) => (
          <PulseRing key={id} nodeId={id} flight={flight} />
        ))}

        {/* Packet orb */}
        <PacketDot
          key={flight?.id}
          flightEdges={flight?.edges ?? []}
          phase={flight?.phase}
          durationMs={flight?.durationMs ?? 600}
          error={flight?.error}
        />

        {/* Nodes */}
        {Object.entries(NODES).map(([id, node]) => {
          const { fill, stroke, sw, filter, textColor } = nodeStyle(id, flight, metrics);
          const isReceived = flight?.dest === id && flight?.phase === "received";
          return (
            <g key={id}>
              <rect
                x={node.x} y={node.y}
                width={NODE_W} height={NODE_H}
                rx={9}
                fill={fill}
                stroke={stroke}
                strokeWidth={sw}
                filter={filter ?? undefined}
                style={isReceived ? { animation: "flash-in 0.3s ease-out" } : {}}
              />
              {/* Monitored pulse dot */}
              {node.monitored && (
                <circle cx={node.x + NODE_W - 9} cy={node.y + 9} r={3} fill="#388bfd" opacity={0.8}>
                  <animate attributeName="opacity" values="0.8;0.3;0.8" dur="2.5s" repeatCount="indefinite" />
                </circle>
              )}
              {/* Icon */}
              <text x={node.x + NODE_W / 2} y={node.y + 22} textAnchor="middle" fontSize={15}>
                {node.icon}
              </text>
              {/* Label */}
              <text
                x={node.x + NODE_W / 2}
                y={node.y + 41}
                textAnchor="middle"
                fontSize={10.5}
                fontWeight={600}
                fill={textColor}
                fontFamily="system-ui, -apple-system, sans-serif"
              >
                {node.label}
              </text>
            </g>
          );
        })}

        {/* Metric badge — rendered after nodes so it sits on top */}
        <MetricBadge metrics={metrics} />

        {/* Legend */}
        <text x={8} y={H - 6} fontSize={9} fill="#484f58" fontFamily="system-ui">
          Last 60s · auto-refreshes every 5s · ● = CloudWatch alarm
        </text>
        <text x={W - 8} y={H - 6} fontSize={9} fill="#484f58" fontFamily="system-ui" textAnchor="end">
          Browser → CloudFront → ALB → ECS
        </text>
      </svg>
    </div>
  );
}
