const W = 980;
const H = 420;
const NODE_W = 150;
const NODE_H = 64;
const ICON_SIZE = 30;

const COLORS = {
  bg: "#0d1117",
  panel: "#161b22",
  border: "#30363d",
  muted: "#6e7681",
  text: "#e6edf3",
  traffic: "#58a6ff",
  healthy: "#3fb950",
  warn: "#d29922",
  danger: "#f85149",
  trace: "#bc8cff",
  logs: "#f59e0b",
  dashboard: "#2ea8ff",
  canary: "#2bd0a7",
};

const NODES = {
  browser: {
    x: 24,
    y: 160,
    label: "Browser",
    sublabel: "User traffic",
    icon: "browser",
    tone: "#6e7681",
  },
  canary: {
    x: 196,
    y: 36,
    label: "Synthetics",
    sublabel: "Frontend + API probes",
    icon: "canary",
    tone: COLORS.canary,
    monitored: true,
    tag: "pkg",
  },
  cloudfront: {
    x: 196,
    y: 160,
    label: "CloudFront",
    sublabel: "CDN edge",
    icon: "cloudfront",
    tone: "#8f63ff",
  },
  alb: {
    x: 368,
    y: 160,
    label: "ALB",
    sublabel: "Front door metrics",
    icon: "alb",
    tone: "#ff9f40",
    monitored: true,
  },
  backend: {
    x: 540,
    y: 160,
    label: "ECS Service",
    sublabel: "App + task health",
    icon: "ecs",
    tone: "#2bb3ff",
    monitored: true,
  },
  downstream: {
    x: 712,
    y: 160,
    label: "Dependency",
    sublabel: "External call path",
    icon: "dependency",
    tone: "#8b949e",
  },
  alarms: {
    x: 712,
    y: 36,
    label: "Alarms",
    sublabel: "ALB + ECS + canary",
    icon: "alarms",
    tone: COLORS.danger,
    monitored: true,
    tag: "pkg",
  },
  dashboard: {
    x: 368,
    y: 320,
    label: "Dashboard",
    sublabel: "Operator home",
    icon: "dashboard",
    tone: COLORS.dashboard,
    monitored: true,
    tag: "pkg",
  },
  logs: {
    x: 540,
    y: 320,
    label: "Logs Insights",
    sublabel: "10 saved queries",
    icon: "logs",
    tone: COLORS.logs,
    monitored: true,
    tag: "pkg",
  },
  xray: {
    x: 712,
    y: 320,
    label: "X-Ray",
    sublabel: "Trace drilldown",
    icon: "xray",
    tone: COLORS.trace,
    monitored: true,
    tag: "opt",
  },
};

function point(id, side) {
  const node = NODES[id];
  if (side === "left") return { x: node.x, y: node.y + NODE_H / 2 };
  if (side === "right") return { x: node.x + NODE_W, y: node.y + NODE_H / 2 };
  if (side === "top") return { x: node.x + NODE_W / 2, y: node.y };
  return { x: node.x + NODE_W / 2, y: node.y + NODE_H };
}

function linePath(fromId, fromSide, toId, toSide) {
  const from = point(fromId, fromSide);
  const to = point(toId, toSide);
  return `M ${from.x} ${from.y} L ${to.x} ${to.y}`;
}

function curvePath(fromId, fromSide, toId, toSide, c1dx, c1dy, c2dx, c2dy) {
  const from = point(fromId, fromSide);
  const to = point(toId, toSide);
  return `M ${from.x} ${from.y} C ${from.x + c1dx} ${from.y + c1dy}, ${to.x + c2dx} ${to.y + c2dy}, ${to.x} ${to.y}`;
}

const EDGES = [
  { id: "e-br-cf", d: linePath("browser", "right", "cloudfront", "left") },
  { id: "e-cf-al", d: linePath("cloudfront", "right", "alb", "left") },
  { id: "e-al-be", d: linePath("alb", "right", "backend", "left") },
  { id: "e-be-ds", d: linePath("backend", "right", "downstream", "left") },
  { id: "e-ca-cf", d: curvePath("canary", "bottom", "cloudfront", "top", 0, 54, 0, -42) },
  { id: "e-ca-ar", d: linePath("canary", "right", "alarms", "left") },
  { id: "e-al-ar", d: curvePath("alb", "top", "alarms", "left", 0, -56, -46, 0) },
  { id: "e-ar-da", d: curvePath("alarms", "bottom", "dashboard", "right", 0, 84, 44, -10) },
  { id: "e-al-da", d: curvePath("alb", "bottom", "dashboard", "top", 0, 68, 0, -54) },
  { id: "e-be-lo", d: curvePath("backend", "bottom", "logs", "top", 0, 68, 0, -54) },
  { id: "e-lo-da", d: linePath("logs", "left", "dashboard", "right") },
  { id: "e-be-xr", d: curvePath("backend", "bottom", "xray", "top", 38, 88, 0, -56) },
];

function edgeById(id) {
  return EDGES.find((edge) => edge.id === id);
}

function alarmState(metrics) {
  const total = metrics?.total;
  if (!total || total.requests === 0) return "idle";
  if (total.errors > 0 || total.errorRate >= 10) return "alert";
  if (total.avgLatencyMs >= 2500) return "warn";
  return "watching";
}

function activity(metrics) {
  const total = metrics?.total;
  const routes = metrics?.routes ?? {};
  return {
    hasTraffic: (total?.requests ?? 0) > 0,
    tracesHot: (routes["/api/dependency"]?.requests ?? 0) > 0,
    logsHot: (total?.requests ?? 0) > 0,
    dashboardHot: (total?.requests ?? 0) > 0,
  };
}

function nodeVisual(id, flight, metrics) {
  const node = NODES[id];
  const total = metrics?.total;
  const alarms = alarmState(metrics);
  const signals = activity(metrics);

  if (id === "backend" && total?.requests > 0) {
    if (total.errorRate >= 10) {
      return { fill: "#2d1117", stroke: COLORS.danger, textColor: COLORS.text, glow: "url(#glow-lg)", badge: `${total.errorRate}% err` };
    }
    if (total.avgLatencyMs >= 2500) {
      return { fill: "#20180d", stroke: COLORS.warn, textColor: COLORS.text, glow: "url(#glow-md)", badge: `${total.avgLatencyMs}ms` };
    }
    return { fill: "#0d2010", stroke: COLORS.healthy, textColor: COLORS.text, glow: "url(#glow-md)", badge: `${total.requests} req` };
  }

  if (id === "alarms") {
    if (alarms === "alert") return { fill: "#2d1117", stroke: COLORS.danger, textColor: COLORS.text, glow: "url(#glow-lg)", badge: "triggered" };
    if (alarms === "warn") return { fill: "#1f180d", stroke: COLORS.warn, textColor: COLORS.text, glow: "url(#glow-md)", badge: "watching" };
  }

  if (id === "xray" && (signals.tracesHot || flight?.endpointId === "dependency")) {
    return { fill: "#1d1431", stroke: COLORS.trace, textColor: COLORS.text, glow: "url(#glow-md)", badge: "active" };
  }

  if (id === "logs" && signals.logsHot) {
    return { fill: "#211709", stroke: COLORS.logs, textColor: COLORS.text, glow: "url(#glow-md)", badge: "queryable" };
  }

  if (id === "dashboard" && signals.dashboardHot) {
    return { fill: "#0d1f33", stroke: COLORS.dashboard, textColor: COLORS.text, glow: "url(#glow-md)", badge: "live" };
  }

  if (id === "canary") {
    return { fill: "#10221b", stroke: COLORS.canary, textColor: COLORS.text, glow: "url(#glow-sm)", badge: "outside-in" };
  }

  if (id === "alb" && (flight?.phase === "flying" || flight?.phase === "received")) {
    return { fill: "#1d1a0d", stroke: node.tone, textColor: COLORS.text, glow: "url(#glow-sm)", badge: "metrics" };
  }

  if (id === "cloudfront" && (flight?.phase === "flying" || flight?.phase === "received")) {
    return { fill: "#1a1633", stroke: node.tone, textColor: COLORS.text, glow: "url(#glow-sm)", badge: "edge" };
  }

  if (id === "downstream" && (flight?.endpointId === "dependency" || flight?.dest === "downstream")) {
    return { fill: "#151d28", stroke: COLORS.traffic, textColor: COLORS.text, glow: "url(#glow-sm)", badge: "path" };
  }

  if (id === "browser" && flight?.phase) {
    return { fill: "#151b23", stroke: COLORS.traffic, textColor: COLORS.text, glow: "url(#glow-sm)", badge: "live" };
  }

  return {
    fill: node.monitored ? "#101722" : COLORS.panel,
    stroke: node.tone,
    textColor: node.monitored ? "#c9d1d9" : COLORS.muted,
    glow: null,
    badge: node.tag === "pkg" ? "pkg" : node.tag === "opt" ? "opt" : null,
  };
}

function edgeVisual(id, flight, metrics) {
  const alarms = alarmState(metrics);
  const signals = activity(metrics);
  const isTraffic = flight?.phase === "flying" && flight.edges.includes(id);

  if (isTraffic) {
    return {
      stroke: flight.error ? COLORS.danger : COLORS.traffic,
      strokeWidth: 3,
      dash: "8 5",
      marker: "url(#arr-on)",
      filter: "url(#glow-md)",
      animated: true,
      duration: "0.45s",
    };
  }

  if (id === "e-ca-cf") {
    return {
      stroke: COLORS.canary,
      strokeWidth: 2,
      dash: "6 6",
      marker: "url(#arr-canary)",
      filter: null,
      animated: true,
      duration: "1.2s",
    };
  }

  if (id === "e-ca-ar" && alarms !== "idle") {
    return {
      stroke: alarms === "alert" ? COLORS.danger : COLORS.warn,
      strokeWidth: 2,
      dash: "5 5",
      marker: alarms === "alert" ? "url(#arr-danger)" : "url(#arr-warn)",
      filter: "url(#glow-sm)",
      animated: true,
      duration: "0.7s",
    };
  }

  if ((id === "e-al-ar" || id === "e-ar-da") && alarms !== "idle") {
    return {
      stroke: alarms === "alert" ? COLORS.danger : COLORS.warn,
      strokeWidth: 2.5,
      dash: "6 4",
      marker: alarms === "alert" ? "url(#arr-danger)" : "url(#arr-warn)",
      filter: "url(#glow-md)",
      animated: true,
      duration: "0.55s",
    };
  }

  if ((id === "e-al-da" || id === "e-be-lo" || id === "e-lo-da") && signals.hasTraffic) {
    return {
      stroke: id === "e-be-lo" || id === "e-lo-da" ? COLORS.logs : COLORS.dashboard,
      strokeWidth: 2.2,
      dash: "5 4",
      marker: "url(#arr-info)",
      filter: "url(#glow-sm)",
      animated: true,
      duration: "0.6s",
    };
  }

  if (id === "e-be-xr" && (signals.tracesHot || flight?.endpointId === "dependency")) {
    return {
      stroke: COLORS.trace,
      strokeWidth: 2.2,
      dash: "5 4",
      marker: "url(#arr-trace)",
      filter: "url(#glow-sm)",
      animated: true,
      duration: "0.6s",
    };
  }

  return {
    stroke: "#21262d",
    strokeWidth: 1.4,
    dash: null,
    marker: "url(#arr-off)",
    filter: null,
    animated: false,
    duration: "0.45s",
  };
}

function ServiceTile({ kind, x, y, tone }) {
  const stroke = "#f8fafc";
  const common = { stroke, strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round", fill: "none" };

  return (
    <g transform={`translate(${x}, ${y})`}>
      <rect x="0" y="0" width={ICON_SIZE} height={ICON_SIZE} rx="8" fill={tone} opacity="0.92" />

      {kind === "browser" && (
        <>
          <rect x="5" y="7" width="20" height="14" rx="3" {...common} />
          <path d="M9 23h12" {...common} />
          <path d="M13 21.5v2.5M17 21.5v2.5" {...common} />
        </>
      )}

      {kind === "cloudfront" && (
        <>
          <circle cx="15" cy="15" r="3" fill={stroke} />
          <circle cx="8" cy="10" r="1.5" fill={stroke} />
          <circle cx="22" cy="10" r="1.5" fill={stroke} />
          <circle cx="8" cy="20" r="1.5" fill={stroke} />
          <circle cx="22" cy="20" r="1.5" fill={stroke} />
          <path d="M10 10l4 4M20 10l-4 4M10 20l4-4M20 20l-4-4" {...common} />
        </>
      )}

      {kind === "alb" && (
        <>
          <rect x="6" y="8" width="5" height="14" rx="2" fill={stroke} />
          <rect x="19" y="8" width="5" height="14" rx="2" fill={stroke} />
          <path d="M11 12h8M11 18h8" {...common} />
          <path d="M15 10l4 2-4 2M15 16l4 2-4 2" {...common} />
        </>
      )}

      {kind === "ecs" && (
        <>
          <rect x="6" y="7" width="8" height="6" rx="1.5" fill={stroke} />
          <rect x="16" y="7" width="8" height="6" rx="1.5" fill={stroke} />
          <rect x="6" y="17" width="8" height="6" rx="1.5" fill={stroke} />
          <rect x="16" y="17" width="8" height="6" rx="1.5" fill={stroke} />
          <path d="M10 13v4M20 13v4M14 10h2M14 20h2" {...common} />
        </>
      )}

      {kind === "dependency" && (
        <>
          <ellipse cx="15" cy="9" rx="7" ry="3" {...common} />
          <path d="M8 9v9c0 1.7 3.1 3 7 3s7-1.3 7-3V9" {...common} />
          <path d="M8 14c0 1.7 3.1 3 7 3s7-1.3 7-3" {...common} />
        </>
      )}

      {kind === "dashboard" && (
        <>
          <rect x="7" y="7" width="7" height="7" rx="1.5" fill={stroke} />
          <rect x="17" y="7" width="7" height="7" rx="1.5" fill={stroke} />
          <rect x="7" y="17" width="7" height="7" rx="1.5" fill={stroke} />
          <rect x="17" y="17" width="7" height="7" rx="1.5" fill={stroke} />
        </>
      )}

      {kind === "logs" && (
        <>
          <path d="M7 10h16M7 15h11M7 20h14" {...common} />
          <circle cx="22" cy="22" r="2.6" {...common} />
          <path d="M24 24l2 2" {...common} />
        </>
      )}

      {kind === "alarms" && (
        <>
          <path d="M15 7c-3.3 0-6 2.7-6 6v3.5l-2.5 3.5h17L21 16.5V13c0-3.3-2.7-6-6-6Z" {...common} />
          <path d="M12 23c.8 1.4 1.7 2 3 2s2.2-.6 3-2" {...common} />
        </>
      )}

      {kind === "canary" && (
        <>
          <circle cx="15" cy="15" r="8" {...common} />
          <path d="M10.5 15.5l3 3 6-7" {...common} />
        </>
      )}

      {kind === "xray" && (
        <>
          <circle cx="8" cy="10" r="2" fill={stroke} />
          <circle cx="21" cy="9" r="2" fill={stroke} />
          <circle cx="15" cy="22" r="2.5" fill={stroke} />
          <path d="M10 10l9-1M9 12l5 8M20 11l-4 9" {...common} />
        </>
      )}
    </g>
  );
}

function PulseRing({ nodeId, color, active }) {
  if (!active) return null;
  const center = {
    x: NODES[nodeId].x + NODE_W / 2,
    y: NODES[nodeId].y + NODE_H / 2,
  };

  return (
    <>
      <circle cx={center.x} cy={center.y} r="30" fill="none" stroke={color} strokeWidth="1.5" opacity="0">
        <animate attributeName="r" from="28" to="54" dur="1.4s" repeatCount="indefinite" />
        <animate attributeName="opacity" from="0.65" to="0" dur="1.4s" repeatCount="indefinite" />
      </circle>
      <circle cx={center.x} cy={center.y} r="30" fill="none" stroke={color} strokeWidth="1" opacity="0">
        <animate attributeName="r" from="28" to="54" dur="1.4s" begin="0.7s" repeatCount="indefinite" />
        <animate attributeName="opacity" from="0.45" to="0" dur="1.4s" begin="0.7s" repeatCount="indefinite" />
      </circle>
    </>
  );
}

function PacketDot({ flight }) {
  if (flight?.phase !== "flying") return null;
  const color = flight.error ? COLORS.danger : COLORS.traffic;
  const edgeCount = Math.max(1, flight.edges?.length ?? 0);

  return (flight.edges ?? []).map((edgeId, index) => {
    const edge = edgeById(edgeId);
    if (!edge) return null;
    const delaySeconds = (index * flight.durationMs) / (edgeCount * 2.4 * 1000);

    return (
      <g key={edgeId}>
        <circle r="11" fill={color} opacity="0.15" filter="url(#blur-corona)">
          <animateMotion dur={`${flight.durationMs / 1000}s`} begin={`${delaySeconds}s`} fill="freeze">
            <mpath href={`#${edge.id}`} />
          </animateMotion>
        </circle>
        <circle r="4.5" fill={color} opacity="0.95" filter="url(#glow-sm)">
          <animateMotion dur={`${flight.durationMs / 1000}s`} begin={`${delaySeconds}s`} fill="freeze">
            <mpath href={`#${edge.id}`} />
          </animateMotion>
        </circle>
      </g>
    );
  });
}

function NodeCard({ id, node, flight, metrics }) {
  const visual = nodeVisual(id, flight, metrics);
  const iconX = node.x + 12;
  const iconY = node.y + 17;
  const labelX = node.x + 54;

  return (
    <g>
      <rect
        x={node.x}
        y={node.y}
        width={NODE_W}
        height={NODE_H}
        rx="12"
        fill={visual.fill}
        stroke={visual.stroke}
        strokeWidth="1.7"
        filter={visual.glow ?? undefined}
      />

      <ServiceTile kind={node.icon} x={iconX} y={iconY} tone={node.tone} />

      {node.tag && (
        <g>
          <rect
            x={node.x + NODE_W - 34}
            y={node.y + 8}
            width="24"
            height="14"
            rx="7"
            fill={node.tag === "opt" ? `${COLORS.trace}22` : `${COLORS.dashboard}1c`}
            stroke={node.tag === "opt" ? `${COLORS.trace}66` : `${COLORS.dashboard}55`}
            strokeWidth="1"
          />
          <text
            x={node.x + NODE_W - 22}
            y={node.y + 18}
            textAnchor="middle"
            fontSize="8.5"
            fontWeight="700"
            fill={node.tag === "opt" ? COLORS.trace : COLORS.dashboard}
            fontFamily="system-ui, sans-serif"
            letterSpacing="0.08em"
          >
            {node.tag.toUpperCase()}
          </text>
        </g>
      )}

      {node.monitored && (
        <circle cx={node.x + NODE_W - 14} cy={node.y + NODE_H - 13} r="3.5" fill={visual.stroke} opacity="0.9">
          <animate attributeName="opacity" values="0.9;0.25;0.9" dur="2.1s" repeatCount="indefinite" />
        </circle>
      )}

      <text
        x={labelX}
        y={node.y + 31}
        fill={visual.textColor}
        fontSize="12"
        fontWeight="700"
        fontFamily="system-ui, sans-serif"
      >
        {node.label}
      </text>

      <text
        x={labelX}
        y={node.y + 46}
        fill="#8b949e"
        fontSize="10"
        fontFamily="system-ui, sans-serif"
      >
        {node.sublabel}
      </text>

      {visual.badge && (
        <g>
          <rect
            x={labelX}
            y={node.y + 8}
            width={Math.max(34, visual.badge.length * 6.3)}
            height="14"
            rx="7"
            fill={`${visual.stroke}20`}
            stroke={`${visual.stroke}55`}
            strokeWidth="1"
          />
          <text
            x={labelX + Math.max(34, visual.badge.length * 6.3) / 2}
            y={node.y + 18}
            textAnchor="middle"
            fontSize="8.5"
            fontWeight="700"
            fill={visual.stroke}
            fontFamily="system-ui, sans-serif"
          >
            {visual.badge}
          </text>
        </g>
      )}
    </g>
  );
}

function SummaryBadge({ metrics }) {
  const total = metrics?.total;
  const alarms = alarmState(metrics);
  if (!total || total.requests === 0) return null;

  const color = alarms === "alert" ? COLORS.danger : alarms === "warn" ? COLORS.warn : COLORS.healthy;

  return (
    <g>
      <rect
        x={NODES.backend.x - 12}
        y={NODES.backend.y - 26}
        width="212"
        height="18"
        rx="9"
        fill="#0d1117"
        stroke={color}
        strokeWidth="0.9"
        opacity="0.96"
      />
      <text
        x={NODES.backend.x + 94}
        y={NODES.backend.y - 14}
        textAnchor="middle"
        fontSize="9.5"
        fontWeight="700"
        fill={color}
        fontFamily="'Consolas', 'Courier New', monospace"
      >
        {`${total.requests} req | ${total.errorRate}% err | ${total.avgLatencyMs}ms avg`}
      </text>
    </g>
  );
}

export default function ArchDiagramScene({ flight, metrics }) {
  const alarms = alarmState(metrics);
  const signals = activity(metrics);
  const pulses = {
    cloudfront: Boolean(flight?.phase),
    alb: Boolean(flight?.phase) || alarms !== "idle",
    backend: Boolean(flight?.phase),
    logs: signals.logsHot,
    dashboard: signals.dashboardHot,
    alarms: alarms !== "idle",
    canary: true,
    xray: signals.tracesHot || flight?.endpointId === "dependency",
    downstream: flight?.endpointId === "dependency" && Boolean(flight?.phase),
  };

  const pulseColors = {
    cloudfront: NODES.cloudfront.tone,
    alb: alarms === "alert" ? COLORS.danger : alarms === "warn" ? COLORS.warn : NODES.alb.tone,
    backend: nodeVisual("backend", flight, metrics).stroke,
    logs: COLORS.logs,
    dashboard: COLORS.dashboard,
    alarms: alarms === "alert" ? COLORS.danger : alarms === "warn" ? COLORS.warn : NODES.alarms.tone,
    canary: COLORS.canary,
    xray: COLORS.trace,
    downstream: COLORS.traffic,
  };

  return (
    <div
      style={{
        background: COLORS.bg,
        border: `1px solid ${COLORS.border}`,
        borderRadius: 14,
        padding: "14px 12px 10px",
      }}
    >
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: "block" }}>
        <defs>
          <pattern id="dot-grid" patternUnits="userSpaceOnUse" width="24" height="24">
            <circle cx="12" cy="12" r="0.9" fill="#20262d" />
          </pattern>

          <filter id="glow-sm" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="2.2" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <filter id="glow-md" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="3.2" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <filter id="glow-lg" x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="4.4" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <filter id="blur-corona" x="-150%" y="-150%" width="400%" height="400%">
            <feGaussianBlur in="SourceGraphic" stdDeviation="5.5" />
          </filter>

          <marker id="arr-off" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill="#30363d" />
          </marker>
          <marker id="arr-on" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.traffic} />
          </marker>
          <marker id="arr-info" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.dashboard} />
          </marker>
          <marker id="arr-canary" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.canary} />
          </marker>
          <marker id="arr-warn" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.warn} />
          </marker>
          <marker id="arr-danger" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.danger} />
          </marker>
          <marker id="arr-trace" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
            <path d="M0 1 L0 7 L7 4 z" fill={COLORS.trace} />
          </marker>

          {EDGES.map((edge) => (
            <path key={edge.id} id={edge.id} d={edge.d} fill="none" />
          ))}
        </defs>

        <rect width={W} height={H} rx="16" fill={COLORS.bg} />
        <rect width={W} height={H} rx="16" fill="url(#dot-grid)" opacity="0.72" />

        <text x="10" y="26" fill="#8b949e" fontSize="11" fontWeight="700" letterSpacing="0.08em" fontFamily="system-ui, sans-serif">
          WORKLOAD PATH
        </text>
        <text x="10" y="296" fill="#8b949e" fontSize="11" fontWeight="700" letterSpacing="0.08em" fontFamily="system-ui, sans-serif">
          PACKAGE SURFACE
        </text>
        <path d="M 12 282 L 968 282" stroke="#20262d" strokeWidth="1" strokeDasharray="4 8" />

        {EDGES.map((edge) => {
          const visual = edgeVisual(edge.id, flight, metrics);
          return (
            <path
              key={edge.id}
              d={edge.d}
              fill="none"
              stroke={visual.stroke}
              strokeWidth={visual.strokeWidth}
              strokeDasharray={visual.dash ?? undefined}
              markerEnd={visual.marker}
              filter={visual.filter ?? undefined}
              style={visual.animated ? { animation: `march ${visual.duration} linear infinite` } : undefined}
            />
          );
        })}

        {Object.keys(pulses).map((id) => (
          <PulseRing key={id} nodeId={id} active={pulses[id]} color={pulseColors[id]} />
        ))}

        <PacketDot flight={flight} />

        {Object.entries(NODES).map(([id, node]) => (
          <NodeCard key={id} id={id} node={node} flight={flight} metrics={metrics} />
        ))}

        <SummaryBadge metrics={metrics} />

        <text x="12" y={H - 10} fill="#6e7681" fontSize="10" fontFamily="system-ui, sans-serif">
          Solid = request flow | Dashed = monitoring flow | PKG = provisioned by the module | OPT = optional feature
        </text>
        <text x={W - 12} y={H - 10} textAnchor="end" fill="#6e7681" fontSize="10" fontFamily="system-ui, sans-serif">
          Dashboard | Alarms | Logs Insights | Synthetics | X-Ray
        </text>
      </svg>
    </div>
  );
}
