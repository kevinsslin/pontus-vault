"use client";

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import type { TooltipProps } from "recharts";
import type { AssetAllocationSlice } from "../../lib/asset-allocation";
import { formatUsd } from "../../lib/format";

type VaultAssetAllocationChartProps = {
  slices: AssetAllocationSlice[];
};

const tooltipFormatter: NonNullable<TooltipProps<number, string>["formatter"]> = (
  _value,
  _name,
  item
) => {
  const payload = item.payload as AssetAllocationSlice | undefined;
  if (!payload) return ["--", "Allocation"];
  return [
    `${(payload.bps / 100).toFixed(2)}%`,
    `${payload.label} · ${formatUsd(payload.tvlValue)}`,
  ];
};

export default function VaultAssetAllocationChart({ slices }: VaultAssetAllocationChartProps) {
  if (slices.length === 0) {
    return null;
  }

  return (
    <article className="card allocation-card">
      <div className="allocation-card__header">
        <div>
          <p className="eyebrow">Asset allocation</p>
          <h3>Where vault capital is allocated</h3>
        </div>
      </div>

      <div className="allocation-card__grid">
        <div className="allocation-pie" role="img" aria-label="Vault asset allocation pie chart">
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={slices}
                dataKey="bps"
                nameKey="label"
                innerRadius={64}
                outerRadius={104}
                paddingAngle={2}
                strokeWidth={2}
                stroke="rgba(255,255,255,0.8)"
              >
                {slices.map((slice) => (
                  <Cell key={slice.label} fill={slice.color} />
                ))}
              </Pie>
              <Tooltip
                formatter={tooltipFormatter}
                contentStyle={{
                  borderRadius: "12px",
                  border: "1px solid rgba(27, 78, 128, 0.16)",
                  background: "rgba(245, 252, 255, 0.96)",
                  boxShadow: "0 12px 32px rgba(10, 30, 60, 0.12)",
                }}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="allocation-legend">
          {slices.map((slice) => (
            <div className="allocation-item" key={slice.label}>
              <div className="allocation-item__head">
                <span className="allocation-dot" style={{ backgroundColor: slice.color }} />
                <strong>{slice.label}</strong>
              </div>
              <div className="allocation-item__meta">
                <span>{(slice.bps / 100).toFixed(2)}%</span>
                <span>{formatUsd(slice.tvlValue)}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </article>
  );
}
