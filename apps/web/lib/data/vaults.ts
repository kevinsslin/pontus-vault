import { cache } from "react";
import type {
  ActivityEvent,
  DataSource,
  PortfolioSnapshot,
  VaultRecord,
  VaultsApiResponse,
} from "@pti/shared";
import { normalizeVaultUiConfig, VaultsApiResponseSchema } from "@pti/shared";
import { fetchIndexerVaults, normalizeAddress } from "./indexer";
import { MOCK_ACTIVITY, MOCK_PORTFOLIO, MOCK_VAULTS } from "./mock";
import { fetchVaultRegistry } from "./supabase";

const DEFAULT_SOURCE: DataSource = "mock";

type LiveConfig = {
  supabaseUrl: string;
  supabaseKey: string;
  indexerUrl: string | null;
};

type LiveVaultsResult = {
  vaults: VaultRecord[];
  errors: string[];
  source: {
    supabase: string;
    indexer: string | null;
  };
};

export function getDataSource(): DataSource {
  const value =
    process.env.NEXT_PUBLIC_DATA_SOURCE ??
    process.env.DATA_SOURCE ??
    DEFAULT_SOURCE;
  return value === "live" ? "live" : "mock";
}

function getLiveConfig(): LiveConfig {
  const supabaseUrl =
    process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const supabaseKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ??
    process.env.SUPABASE_ANON_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    "";
  const indexerUrl =
    process.env.GOLDSKY_SUBGRAPH_URL ??
    process.env.INDEXER_URL ??
    process.env.NEXT_PUBLIC_INDEXER_URL ??
    "";

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Missing Supabase configuration.");
  }

  return {
    supabaseUrl,
    supabaseKey,
    indexerUrl: indexerUrl || null,
  };
}

const getLiveVaults = cache(async (): Promise<LiveVaultsResult> => {
  const { supabaseUrl, supabaseKey, indexerUrl } = getLiveConfig();
  const errors: string[] = [];

  const registryPromise = fetchVaultRegistry(supabaseUrl, supabaseKey);
  const indexerPromise = indexerUrl
    ? fetchIndexerVaults(indexerUrl).catch((err) => {
        errors.push(err instanceof Error ? err.message : "Indexer fetch failed");
        return new Map();
      })
    : Promise.resolve(new Map());

  if (!indexerUrl) {
    errors.push("Missing indexer URL.");
  }

  const [registry, indexerMap] = await Promise.all([
    registryPromise,
    indexerPromise,
  ]);

  const vaults = registry.map((row) => {
    const controllerKey = normalizeAddress(
      row.controller_address || row.vault_address || row.manager_address || ""
    );
    const metrics = indexerMap.get(controllerKey);

    return {
      productId: row.product_id,
      chain: row.chain,
      name: row.name,
      route: row.route,
      assetSymbol: row.asset_symbol,
      assetAddress: row.asset_address,
      controllerAddress: row.controller_address,
      seniorTokenAddress: row.senior_token_address,
      juniorTokenAddress: row.junior_token_address,
      vaultAddress: row.vault_address,
      tellerAddress: row.teller_address,
      managerAddress: row.manager_address,
      uiConfig: normalizeVaultUiConfig(row.ui_config),
      metrics: {
        tvl: metrics?.tvl ?? null,
        seniorPrice: metrics?.seniorPrice ?? null,
        juniorPrice: metrics?.juniorPrice ?? null,
        seniorDebt: metrics?.seniorDebt ?? null,
        seniorSupply: metrics?.seniorSupply ?? null,
        juniorSupply: metrics?.juniorSupply ?? null,
        updatedAt: metrics?.updatedAt ?? null,
      },
    } satisfies VaultRecord;
  });

  return {
    vaults,
    errors,
    source: {
      supabase: supabaseUrl,
      indexer: indexerUrl,
    },
  };
});

export async function getVaultsResponse(
  source: DataSource = getDataSource()
): Promise<VaultsApiResponse> {
  if (source === "mock") {
    return VaultsApiResponseSchema.parse({
      generatedAt: new Date().toISOString(),
      source: {
        supabase: "mock",
        indexer: null,
      },
      vaults: MOCK_VAULTS,
    } satisfies VaultsApiResponse);
  }

  const live = await getLiveVaults();
  return VaultsApiResponseSchema.parse({
    generatedAt: new Date().toISOString(),
    source: live.source,
    errors: live.errors.length > 0 ? live.errors : undefined,
    vaults: live.vaults,
  } satisfies VaultsApiResponse);
}

export async function getVaults(
  source: DataSource = getDataSource()
): Promise<VaultRecord[]> {
  try {
    const response = await getVaultsResponse(source);
    return [...response.vaults].sort((a, b) => {
      const orderA = a.uiConfig.displayOrder ?? 999;
      const orderB = b.uiConfig.displayOrder ?? 999;
      return orderA - orderB;
    });
  } catch {
    return MOCK_VAULTS;
  }
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
