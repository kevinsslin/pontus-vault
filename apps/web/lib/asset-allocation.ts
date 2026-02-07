export type AssetAllocationSlice = {
  label: string;
  bps: number;
  color: string;
  tvlValue: string | null;
};

type AllocationTemplate = {
  label: string;
  bps: number;
  color: string;
};

function getAllocationTemplate(route: string): AllocationTemplate[] {
  const normalized = route.toLowerCase();

  if (normalized.includes("lending")) {
    return [
      { label: "OpenFi USDC/USDT supply", bps: 6000, color: "#1f6eb3" },
      { label: "BoringVault reserve buffer", bps: 1800, color: "#2bb8b3" },
      { label: "Treasury collateral sleeve", bps: 1400, color: "#8db7e4" },
      { label: "Pending deployment cash", bps: 800, color: "#d2e4f7" },
    ];
  }

  if (normalized.includes("t-bill") || normalized.includes("bill")) {
    return [
      { label: "Tokenized T-Bills", bps: 6200, color: "#1f6eb3" },
      { label: "Money market sleeve", bps: 1700, color: "#2bb8b3" },
      { label: "Stable cash reserve", bps: 1300, color: "#8db7e4" },
      { label: "Settlement liquidity", bps: 800, color: "#d2e4f7" },
    ];
  }

  if (normalized.includes("credit") || normalized.includes("delta")) {
    return [
      { label: "Structured credit sleeve", bps: 4700, color: "#1f6eb3" },
      { label: "Delta hedge routes", bps: 2600, color: "#2bb8b3" },
      { label: "Treasury collateral", bps: 1700, color: "#8db7e4" },
      { label: "Cash and redemptions", bps: 1000, color: "#d2e4f7" },
    ];
  }

  return [
    { label: "Primary strategy sleeve", bps: 6500, color: "#1f6eb3" },
    { label: "Secondary strategy sleeve", bps: 2000, color: "#2bb8b3" },
    { label: "Liquidity reserve", bps: 1500, color: "#8db7e4" },
  ];
}

export function buildAssetAllocation(route: string, tvl: string | null): AssetAllocationSlice[] {
  const template = getAllocationTemplate(route);
  const totalBps = template.reduce((sum, slice) => sum + slice.bps, 0);
  const adjust = totalBps === 10_000 ? 0 : 10_000 - totalBps;
  const tvlRaw = tvl ? BigInt(tvl) : null;

  return template.map((slice, index) => {
    const bps = index === template.length - 1 ? slice.bps + adjust : slice.bps;
    const tvlValue = tvlRaw === null ? null : ((tvlRaw * BigInt(Math.max(0, bps))) / 10_000n).toString();

    return {
      label: slice.label,
      bps: Math.max(0, bps),
      color: slice.color,
      tvlValue,
    };
  });
}
