import {
  IndexerVaultsResponseSchema,
  type IndexerVault,
} from "@pti/shared";

const INDEXER_QUERY = `
  query Vaults {
    vaults(first: 1000) {
      id
      controller
      vaultId
      paramsHash
      asset
      teller
      manager
      rateModel
      paused
      maxSeniorRatioBps
      maxRateAge
      seniorRatePerSecondWad
      tvl
      seniorApyBps
      juniorApyBps
      seniorPrice
      juniorPrice
      seniorDebt
      seniorSupply
      juniorSupply
      updatedAt
      dailySnapshots(first: 2, orderBy: periodStart, orderDirection: desc) {
        periodStart
        closeTvl
        closeSeniorPrice
        closeJuniorPrice
        txCount
      }
    }
  }
`;

const WAD_SCALE = 1e18;
const SECONDS_PER_YEAR = 31_536_000;

export function normalizeAddress(value: string): string {
  return value.toLowerCase();
}

function toNumber(value: string | null | undefined): number | null {
  if (!value) return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return parsed;
}

function annualizedApyBps(
  latestPriceWad: string | null | undefined,
  priorPriceWad: string | null | undefined,
  latestTs: string | null | undefined,
  priorTs: string | null | undefined
): string | null {
  const latestPrice = toNumber(latestPriceWad);
  const priorPrice = toNumber(priorPriceWad);
  const latestPeriod = toNumber(latestTs);
  const priorPeriod = toNumber(priorTs);

  if (!latestPrice || !priorPrice || !latestPeriod || !priorPeriod) {
    return null;
  }
  if (latestPrice <= 0 || priorPrice <= 0 || latestPeriod <= priorPeriod) {
    return null;
  }

  const dt = latestPeriod - priorPeriod;
  const ratio = latestPrice / priorPrice;
  const annualized = (ratio - 1) * (SECONDS_PER_YEAR / dt);
  if (!Number.isFinite(annualized)) {
    return null;
  }

  const bps = Math.round(annualized * 10_000);
  return `${bps}`;
}

export async function fetchIndexerVaults(
  indexerUrl: string
): Promise<Map<string, IndexerVault>> {
  const response = await fetch(indexerUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: INDEXER_QUERY }),
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`Indexer request failed: ${response.status}`);
  }

  const payload = IndexerVaultsResponseSchema.parse(await response.json());
  if (payload.errors && payload.errors.length > 0) {
    throw new Error(payload.errors.map((error) => error.message).join("; "));
  }

  const vaults = payload.data?.vaults ?? [];
  const map = new Map<string, IndexerVault>();
  for (const vault of vaults) {
    const latest = vault.dailySnapshots?.[0];
    const prior = vault.dailySnapshots?.[1];
    const derivedSeniorApyBps = annualizedApyBps(
      latest?.closeSeniorPrice,
      prior?.closeSeniorPrice,
      latest?.periodStart,
      prior?.periodStart
    );
    const derivedJuniorApyBps = annualizedApyBps(
      latest?.closeJuniorPrice,
      prior?.closeJuniorPrice,
      latest?.periodStart,
      prior?.periodStart
    );

    const key = normalizeAddress(vault.controller ?? vault.id);
    map.set(key, {
      ...vault,
      seniorApyBps: derivedSeniorApyBps ?? vault.seniorApyBps ?? null,
      juniorApyBps: derivedJuniorApyBps ?? vault.juniorApyBps ?? null,
    });
  }

  return map;
}

export type { IndexerVault };
