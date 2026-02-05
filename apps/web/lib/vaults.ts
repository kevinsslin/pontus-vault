export type VaultStatus = "LIVE" | "COMING_SOON";
export type DataSource = "mock" | "live";

export type VaultMetrics = {
  tvl: string | null;
  seniorPrice: string | null;
  juniorPrice: string | null;
  seniorDebt: string | null;
  seniorSupply: string | null;
  juniorSupply: string | null;
  updatedAt: string | null;
};

export type VaultRecord = {
  productId: string;
  chain: string;
  name: string;
  route: string;
  assetSymbol: string;
  assetAddress: string;
  controllerAddress: string;
  seniorTokenAddress: string;
  juniorTokenAddress: string;
  vaultAddress: string;
  tellerAddress: string;
  managerAddress: string;
  uiConfig: {
    status: VaultStatus;
    displayOrder?: number;
    risk?: string;
    routeLabel?: string;
    summary?: string;
    tags?: string[];
    banner?: string;
  };
  metrics: VaultMetrics;
};

export type ActivityEvent = {
  id: string;
  type: "DEPOSIT" | "REDEEM" | "ACCRUE";
  tranche: "SENIOR" | "JUNIOR" | "SYSTEM";
  amount: string;
  time: string;
  actor: string;
};

export type PortfolioSnapshot = {
  totalValue: string;
  dayChange: string;
  positions: Array<{
    productId: string;
    name: string;
    tranche: "SENIOR" | "JUNIOR";
    shares: string;
    value: string;
    pnl: string;
  }>;
};

const MOCK_VAULTS: VaultRecord[] = [
  {
    productId: "0",
    chain: "pharos-atlantic",
    name: "Pontus Vault USDC Lending S1",
    route: "lending",
    assetSymbol: "USDC",
    assetAddress: "0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8",
    controllerAddress: "0x0000000000000000000000000000000000000000",
    seniorTokenAddress: "0x0000000000000000000000000000000000000000",
    juniorTokenAddress: "0x0000000000000000000000000000000000000000",
    vaultAddress: "0x0000000000000000000000000000000000000000",
    tellerAddress: "0x0000000000000000000000000000000000000000",
    managerAddress: "0x0000000000000000000000000000000000000000",
    uiConfig: {
      status: "LIVE",
      displayOrder: 1,
      risk: "LOW",
      routeLabel: "OpenFi lending",
      summary: "Blue-chip USDC lending routed through OpenFi. Senior is capped; junior takes the volatility.",
      tags: ["USDC", "Lending", "OpenFi"],
      banner: "Senior cap 8% APR · Junior absorbs tail risk",
    },
    metrics: {
      tvl: "12500000000000",
      seniorPrice: "1005000000000000000",
      juniorPrice: "1090000000000000000",
      seniorDebt: "8000000000000",
      seniorSupply: "8000000000000",
      juniorSupply: "4000000000000",
      updatedAt: "1738790400",
    },
  },
  {
    productId: "1",
    chain: "pharos-atlantic",
    name: "Pontus Vault USDT T-Bills S1",
    route: "t-bill",
    assetSymbol: "USDT",
    assetAddress: "0xE7E84B8B4f39C507499c40B4ac199B050e2882d5",
    controllerAddress: "0x0000000000000000000000000000000000000000",
    seniorTokenAddress: "0x0000000000000000000000000000000000000000",
    juniorTokenAddress: "0x0000000000000000000000000000000000000000",
    vaultAddress: "0x0000000000000000000000000000000000000000",
    tellerAddress: "0x0000000000000000000000000000000000000000",
    managerAddress: "0x0000000000000000000000000000000000000000",
    uiConfig: {
      status: "COMING_SOON",
      displayOrder: 2,
      risk: "LOW",
      routeLabel: "Tokenized T-Bills",
      summary: "Short-duration treasury exposure for the senior tranche with conservative drawdown control.",
      tags: ["USDT", "RWA", "T-Bill"],
      banner: "Underwriting in progress",
    },
    metrics: {
      tvl: null,
      seniorPrice: null,
      juniorPrice: null,
      seniorDebt: null,
      seniorSupply: null,
      juniorSupply: null,
      updatedAt: null,
    },
  },
  {
    productId: "2",
    chain: "pharos-atlantic",
    name: "Pontus Vault Delta Neutral Credit S1",
    route: "credit",
    assetSymbol: "USDC",
    assetAddress: "0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8",
    controllerAddress: "0x0000000000000000000000000000000000000000",
    seniorTokenAddress: "0x0000000000000000000000000000000000000000",
    juniorTokenAddress: "0x0000000000000000000000000000000000000000",
    vaultAddress: "0x0000000000000000000000000000000000000000",
    tellerAddress: "0x0000000000000000000000000000000000000000",
    managerAddress: "0x0000000000000000000000000000000000000000",
    uiConfig: {
      status: "COMING_SOON",
      displayOrder: 3,
      risk: "MEDIUM",
      routeLabel: "Delta-neutral credit",
      summary: "Structured credit sleeve with volatility hedged down to senior-friendly ranges.",
      tags: ["USDC", "Credit", "Delta Neutral"],
      banner: "Strategy calibration pending",
    },
    metrics: {
      tvl: null,
      seniorPrice: null,
      juniorPrice: null,
      seniorDebt: null,
      seniorSupply: null,
      juniorSupply: null,
      updatedAt: null,
    },
  },
];

const MOCK_ACTIVITY: Record<string, ActivityEvent[]> = {
  "0": [
    {
      id: "evt-1",
      type: "DEPOSIT",
      tranche: "SENIOR",
      amount: "1,200,000 USDC",
      time: "2h ago",
      actor: "0x7b...39c1",
    },
    {
      id: "evt-2",
      type: "DEPOSIT",
      tranche: "JUNIOR",
      amount: "450,000 USDC",
      time: "4h ago",
      actor: "0x90...a812",
    },
    {
      id: "evt-3",
      type: "ACCRUE",
      tranche: "SYSTEM",
      amount: "+0.18% senior debt",
      time: "6h ago",
      actor: "Rate model",
    },
    {
      id: "evt-4",
      type: "REDEEM",
      tranche: "SENIOR",
      amount: "250,000 USDC",
      time: "1d ago",
      actor: "0x2d...b4f0",
    },
  ],
  "1": [
    {
      id: "evt-5",
      type: "ACCRUE",
      tranche: "SYSTEM",
      amount: "Policy review in progress",
      time: "~",
      actor: "Operator",
    },
  ],
  "2": [
    {
      id: "evt-6",
      type: "ACCRUE",
      tranche: "SYSTEM",
      amount: "Strategy onboarding",
      time: "~",
      actor: "Operator",
    },
  ],
};

const MOCK_PORTFOLIO: PortfolioSnapshot = {
  totalValue: "$2.48m",
  dayChange: "+1.3%",
  positions: [
    {
      productId: "0",
      name: "Pontus Vault USDC Lending S1",
      tranche: "SENIOR",
      shares: "1,000,000 pvS",
      value: "$1.02m",
      pnl: "+0.9%",
    },
    {
      productId: "0",
      name: "Pontus Vault USDC Lending S1",
      tranche: "JUNIOR",
      shares: "700,000 pvJ",
      value: "$1.46m",
      pnl: "+2.8%",
    },
  ],
};

export function getDataSource(): DataSource {
  const value =
    process.env.NEXT_PUBLIC_DATA_SOURCE ??
    process.env.DATA_SOURCE ??
    "mock";
  return value === "live" ? "live" : "mock";
}

function resolveBaseUrl(): string {
  if (process.env.NEXT_PUBLIC_SITE_URL) return process.env.NEXT_PUBLIC_SITE_URL;
  if (process.env.SITE_URL) return process.env.SITE_URL;
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return "http://localhost:3000";
}

async function fetchLiveVaults(): Promise<VaultRecord[]> {
  const baseUrl = resolveBaseUrl();
  const response = await fetch(`${baseUrl}/api/vaults`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status}`);
  }
  const payload = (await response.json()) as { vaults?: VaultRecord[] };
  return payload.vaults ?? [];
}

export async function getVaults(source: DataSource = getDataSource()): Promise<VaultRecord[]> {
  if (source === "live") {
    try {
      const liveVaults = await fetchLiveVaults();
      return [...liveVaults].sort((a, b) => {
        const orderA = a.uiConfig.displayOrder ?? 999;
        const orderB = b.uiConfig.displayOrder ?? 999;
        return orderA - orderB;
      });
    } catch {
      return MOCK_VAULTS;
    }
  }

  return MOCK_VAULTS;
}

export async function getVaultById(
  id: string,
  source: DataSource = getDataSource()
): Promise<VaultRecord | null> {
  const vaults = await getVaults(source);
  return vaults.find((vault) => vault.productId === id) ?? null;
}

export function getActivityForVault(productId: string): ActivityEvent[] {
  return MOCK_ACTIVITY[productId] ?? [];
}

export function getPortfolioSnapshot(): PortfolioSnapshot {
  return MOCK_PORTFOLIO;
}
