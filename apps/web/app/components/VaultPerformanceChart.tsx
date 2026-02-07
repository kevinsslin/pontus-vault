type TrendPoint = {
  label: string;
  seniorNav: number;
  juniorNav: number;
  seniorApy: number;
  juniorApy: number;
};

type VaultPerformanceChartProps = {
  points: TrendPoint[];
};

type Point = {
  x: number;
  y: number;
};

const CHART_WIDTH = 720;
const CHART_HEIGHT = 300;
const CHART_PADDING = { top: 22, right: 18, bottom: 34, left: 18 };

function round(value: number, decimals = 2): string {
  return value.toFixed(decimals);
}

function toLinePath(points: Point[]): string {
  return points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`).join(" ");
}

function toAreaPath(points: Point[], baseline: number): string {
  if (points.length === 0) return "";
  const start = points[0];
  const end = points[points.length - 1];
  const line = toLinePath(points);
  return `${line} L ${end.x} ${baseline} L ${start.x} ${baseline} Z`;
}

export default function VaultPerformanceChart({ points }: VaultPerformanceChartProps) {
  if (points.length === 0) {
    return null;
  }

  const seniorSeries = points.map((point) => point.seniorNav);
  const juniorSeries = points.map((point) => point.juniorNav);

  const merged = [...seniorSeries, ...juniorSeries];
  const min = Math.min(...merged);
  const max = Math.max(...merged);
  const span = max - min || 1;
  const usableWidth = CHART_WIDTH - CHART_PADDING.left - CHART_PADDING.right;
  const usableHeight = CHART_HEIGHT - CHART_PADDING.top - CHART_PADDING.bottom;
  const step = points.length === 1 ? 0 : usableWidth / (points.length - 1);

  const chartPoints = points.map((point, index) => {
    const x = CHART_PADDING.left + step * index;
    const toY = (value: number) =>
      CHART_PADDING.top + usableHeight - ((value - min) / span) * usableHeight;
    return {
      label: point.label,
      x,
      seniorY: toY(point.seniorNav),
      juniorY: toY(point.juniorNav),
    };
  });

  const seniorLine = toLinePath(chartPoints.map((point) => ({ x: point.x, y: point.seniorY })));
  const juniorLine = toLinePath(chartPoints.map((point) => ({ x: point.x, y: point.juniorY })));
  const areaPath = toAreaPath(
    chartPoints.map((point) => ({ x: point.x, y: point.seniorY })),
    CHART_HEIGHT - CHART_PADDING.bottom
  );

  const lastPoint = points[points.length - 1];
  const firstPoint = points[0];
  const seniorChange = ((lastPoint.seniorNav - firstPoint.seniorNav) / firstPoint.seniorNav) * 100;
  const juniorChange = ((lastPoint.juniorNav - firstPoint.juniorNav) / firstPoint.juniorNav) * 100;
  const avgSeniorApy =
    points.reduce((acc, point) => acc + point.seniorApy, 0) / points.length;
  const avgJuniorApy =
    points.reduce((acc, point) => acc + point.juniorApy, 0) / points.length;

  const gridValues = [0, 0.25, 0.5, 0.75, 1];
  const yTicks = gridValues.map((ratio) => {
    const value = min + (1 - ratio) * span;
    const y = CHART_PADDING.top + ratio * usableHeight;
    return { y, value };
  });

  return (
    <article className="card trend-card">
      <div className="trend-card__header">
        <div>
          <p className="eyebrow">Performance trend</p>
          <h3>Historical yield trend</h3>
        </div>
        <div className="trend-kpis">
          <div className="trend-kpi">
            <span className="label">Senior historical yield</span>
            <strong>{round(seniorChange)}%</strong>
          </div>
          <div className="trend-kpi">
            <span className="label">Junior historical yield</span>
            <strong>{round(juniorChange)}%</strong>
          </div>
        </div>
      </div>

      <div className="trend-chart-wrap" role="img" aria-label="Senior and junior yield trend line chart">
        <svg viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`} className="trend-chart">
          {yTicks.map((tick) => (
            <g key={tick.y}>
              <line
                x1={CHART_PADDING.left}
                x2={CHART_WIDTH - CHART_PADDING.right}
                y1={tick.y}
                y2={tick.y}
                className="trend-gridline"
              />
              <text x={CHART_PADDING.left + 4} y={tick.y - 4} className="trend-axis-label">
                {round(tick.value, 3)}x
              </text>
            </g>
          ))}

          <path d={areaPath} className="trend-area" />
          <path d={juniorLine} className="trend-line trend-line--junior" />
          <path d={seniorLine} className="trend-line trend-line--senior" />

          {chartPoints.map((point, index) => (
            <g key={point.label}>
              <circle cx={point.x} cy={point.seniorY} r="3" className="trend-dot trend-dot--senior" />
              <circle cx={point.x} cy={point.juniorY} r="3" className="trend-dot trend-dot--junior" />
              {index % 2 === 0 || index === chartPoints.length - 1 ? (
                <text x={point.x} y={CHART_HEIGHT - 10} textAnchor="middle" className="trend-axis-label">
                  {point.label}
                </text>
              ) : null}
            </g>
          ))}
        </svg>
      </div>

      <div className="trend-legend">
        <span className="trend-legend__item">
          <span className="trend-swatch trend-swatch--senior" />
          Senior avg APY {round(avgSeniorApy, 2)}%
        </span>
        <span className="trend-legend__item">
          <span className="trend-swatch trend-swatch--junior" />
          Junior avg APY {round(avgJuniorApy, 2)}%
        </span>
      </div>
    </article>
  );
}
