import type { CSSProperties } from "react";
import type { AssetAllocationSlice } from "../../lib/asset-allocation";

type VaultAllocationMiniChartProps = {
  slices: AssetAllocationSlice[];
};

function donutBackground(slices: AssetAllocationSlice[]): string {
  let cursor = 0;
  const segments = slices.map((slice) => {
    const start = cursor;
    const width = slice.bps / 100;
    const end = start + width;
    cursor = end;
    return `${slice.color} ${start.toFixed(2)}% ${end.toFixed(2)}%`;
  });
  return `conic-gradient(${segments.join(", ")})`;
}

export default function VaultAllocationMiniChart({ slices }: VaultAllocationMiniChartProps) {
  if (slices.length === 0) return null;

  const topSlices = slices.slice(0, 3);
  const style = { background: donutBackground(slices) } as CSSProperties;

  return (
    <div className="allocation-mini">
      <div className="allocation-mini__donut" style={style} aria-label="Asset allocation donut chart" role="img">
        <span className="allocation-mini__hole" />
      </div>

      <div className="allocation-mini__legend">
        {topSlices.map((slice) => (
          <div className="allocation-mini__item" key={slice.label}>
            <span className="allocation-mini__dot" style={{ backgroundColor: slice.color }} />
            <span className="allocation-mini__label">{slice.label}</span>
            <span className="allocation-mini__value">{(slice.bps / 100).toFixed(1)}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}
