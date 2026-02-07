"use client";

import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { TooltipProps } from "recharts";

type TrendPoint = {
  label: string;
  seniorSharePrice: number;
  juniorSharePrice: number;
};

type VaultPerformanceChartProps = {
  points: TrendPoint[];
};

function formatPrice(value: number, digits = 4): string {
  return `$${value.toFixed(digits)}`;
}

function formatPct(value: number): string {
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value.toFixed(2)}%`;
}

const tooltipFormatter: NonNullable<TooltipProps<number, string>["formatter"]> = (
  value,
  name
) => {
  const numeric = typeof value === "number" ? value : Number(value ?? 0);
  return [
    formatPrice(numeric),
    name === "seniorSharePrice" ? "Senior share price" : "Junior share price",
  ];
};

export default function VaultPerformanceChart({ points }: VaultPerformanceChartProps) {
  if (points.length === 0) {
    return null;
  }

  const first = points[0];
  const last = points[points.length - 1];
  const seniorChange =
    ((last.seniorSharePrice - first.seniorSharePrice) / first.seniorSharePrice) * 100;
  const juniorChange =
    ((last.juniorSharePrice - first.juniorSharePrice) / first.juniorSharePrice) * 100;

  const merged = points.flatMap((point) => [
    point.seniorSharePrice,
    point.juniorSharePrice,
  ]);
  const yMin = Math.max(0, Math.min(...merged) - 0.01);
  const yMax = Math.max(...merged) + 0.01;

  return (
    <article className="card trend-card">
      <div className="trend-card__header">
        <div>
          <p className="eyebrow">Performance trend</p>
          <h3>Vault share price based on NAV</h3>
        </div>
        <div className="trend-kpis">
          <div className="trend-kpi">
            <span className="label">Senior share price</span>
            <strong>{formatPrice(last.seniorSharePrice)}</strong>
            <small>{formatPct(seniorChange)} since {first.label}</small>
          </div>
          <div className="trend-kpi">
            <span className="label">Junior share price</span>
            <strong>{formatPrice(last.juniorSharePrice)}</strong>
            <small>{formatPct(juniorChange)} since {first.label}</small>
          </div>
        </div>
      </div>

      <div
        className="trend-chart-wrap"
        role="img"
        aria-label="Senior and junior vault share price trend chart"
      >
        <ResponsiveContainer width="100%" height={300}>
          <LineChart
            data={points}
            margin={{ top: 10, right: 16, left: 4, bottom: 8 }}
          >
            <CartesianGrid stroke="rgba(27, 78, 128, 0.14)" strokeDasharray="4 4" />
            <XAxis
              dataKey="label"
              axisLine={false}
              tickLine={false}
              tick={{ fill: "#5f7da0", fontSize: 12 }}
            />
            <YAxis
              domain={[yMin, yMax]}
              axisLine={false}
              tickLine={false}
              tick={{ fill: "#5f7da0", fontSize: 12 }}
              tickFormatter={(value: number) => `$${value.toFixed(3)}`}
              width={68}
            />
            <Tooltip
              formatter={tooltipFormatter}
              labelFormatter={(label) => `Period ${label}`}
              contentStyle={{
                borderRadius: "12px",
                border: "1px solid rgba(27, 78, 128, 0.16)",
                background: "rgba(245, 252, 255, 0.96)",
                boxShadow: "0 12px 32px rgba(10, 30, 60, 0.12)",
              }}
            />
            <Line
              type="monotone"
              dataKey="seniorSharePrice"
              name="seniorSharePrice"
              stroke="#1f6eb3"
              strokeWidth={2.8}
              dot={false}
              activeDot={{ r: 4 }}
            />
            <Line
              type="monotone"
              dataKey="juniorSharePrice"
              name="juniorSharePrice"
              stroke="#2bb8b3"
              strokeWidth={2.8}
              dot={false}
              activeDot={{ r: 4 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="trend-legend">
        <span className="trend-legend__item">
          <span className="trend-swatch trend-swatch--senior" />
          Senior share price trajectory
        </span>
        <span className="trend-legend__item">
          <span className="trend-swatch trend-swatch--junior" />
          Junior share price trajectory
        </span>
      </div>
    </article>
  );
}
