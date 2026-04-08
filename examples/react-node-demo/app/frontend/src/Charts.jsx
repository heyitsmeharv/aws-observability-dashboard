import {
  AreaChart, Area, XAxis, YAxis, Tooltip,
  ResponsiveContainer, CartesianGrid,
} from "recharts";

// ── Custom dark tooltip ───────────────────────────────────────────────────────

function DarkTooltip({ active, payload, unit }) {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: "#161b22",
      border: "1px solid #30363d",
      borderRadius: 6,
      padding: "6px 10px",
      fontSize: 11,
      fontFamily: "'Consolas', monospace",
    }}>
      {payload.map((p) => (
        <div key={p.dataKey} style={{ color: p.stroke }}>
          {p.value}{unit}
        </div>
      ))}
    </div>
  );
}

// ── Single sparkline chart ────────────────────────────────────────────────────

function MiniChart({ label, data, dataKey, stroke, unit, domain }) {
  const hasData = (data?.length ?? 0) >= 2;

  return (
    <div style={{
      background: "#161b22",
      border: "1px solid #30363d",
      borderRadius: 8,
      padding: "10px 14px",
      marginBottom: 8,
    }}>
      <div style={{
        fontSize: 11,
        color: "#8b949e",
        fontWeight: 500,
        marginBottom: 6,
        letterSpacing: "0.02em",
      }}>
        {label}
      </div>

      {!hasData ? (
        <div style={{
          height: 58,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#484f58",
          fontSize: 11,
        }}>
          Waiting for data…
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={58}>
          <AreaChart data={data} margin={{ top: 2, right: 0, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id={`grad-${dataKey}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%"  stopColor={stroke} stopOpacity={0.25} />
                <stop offset="95%" stopColor={stroke} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke="#21262d" strokeDasharray="3 3" vertical={false} />
            <XAxis dataKey="t" hide />
            <YAxis hide domain={domain} />
            <Tooltip content={<DarkTooltip unit={unit} />} />
            <Area
              type="monotone"
              dataKey={dataKey}
              stroke={stroke}
              strokeWidth={1.5}
              fill={`url(#grad-${dataKey})`}
              dot={false}
              isAnimationActive={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

// ── Exported component ────────────────────────────────────────────────────────

export default function Charts({ history }) {
  const data = history ?? [];
  return (
    <>
      <MiniChart
        label="Requests / 10s"
        data={data} dataKey="requests"
        stroke="#58a6ff" unit="" domain={[0, "auto"]}
      />
      <MiniChart
        label="Error rate (%)"
        data={data} dataKey="errorRate"
        stroke="#f85149" unit="%" domain={[0, 100]}
      />
      <MiniChart
        label="Avg latency (ms)"
        data={data} dataKey="avgLatencyMs"
        stroke="#d29922" unit="ms" domain={[0, "auto"]}
      />
    </>
  );
}
