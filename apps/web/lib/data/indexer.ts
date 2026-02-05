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
      tvl
      seniorPrice
      juniorPrice
      seniorDebt
      seniorSupply
      juniorSupply
      updatedAt
    }
  }
`;

export function normalizeAddress(value: string): string {
  return value.toLowerCase();
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
    const key = normalizeAddress(vault.controller ?? vault.id);
    map.set(key, vault);
  }

  return map;
}

export type { IndexerVault };
