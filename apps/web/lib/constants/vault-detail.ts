export const VAULT_TREND_POINTS = [
  { label: "W-12", seniorFactor: 0.994, juniorFactor: 0.91 },
  { label: "W-10", seniorFactor: 0.996, juniorFactor: 0.94 },
  { label: "W-8", seniorFactor: 0.998, juniorFactor: 0.97 },
  { label: "W-6", seniorFactor: 0.999, juniorFactor: 0.99 },
  { label: "W-4", seniorFactor: 1.001, juniorFactor: 1.03 },
  { label: "W-2", seniorFactor: 1.003, juniorFactor: 1.07 },
  { label: "Now", seniorFactor: 1.0, juniorFactor: 1.0 },
] as const;

export type VaultOperationalSnapshot = {
  holders: string;
  avgRedemption: string;
  maxRedeem: string;
};

export const DEFAULT_VAULT_OPERATIONAL_SNAPSHOT: VaultOperationalSnapshot = {
  holders: "—",
  avgRedemption: "—",
  maxRedeem: "—",
};

export const VAULT_OPERATIONAL_SNAPSHOTS: Record<string, VaultOperationalSnapshot> = {
  "0": {
    holders: "14,579",
    avgRedemption: "30 min",
    maxRedeem: "4 days",
  },
  "1": {
    holders: "1,904",
    avgRedemption: "2 hours",
    maxRedeem: "2 days",
  },
  "2": {
    holders: "827",
    avgRedemption: "4 hours",
    maxRedeem: "5 days",
  },
};
