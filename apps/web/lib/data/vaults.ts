import type {
  ActivityEvent,
  DataSource,
  OperatorEditableVaultUiConfig,
  PortfolioSnapshot,
  VaultRecord,
  VaultsApiResponse,
} from "@pti/shared";
import { normalizeVaultUiConfig, VaultsApiResponseSchema } from "@pti/shared";
import {
  resolveDataSource,
  resolveLiveDataRuntimeConfig,
  type LiveDataRuntimeConfig,
} from "../constants/runtime";
import { fetchIndexerVaults, normalizeAddress } from "./indexer";
import { MOCK_ACTIVITY, MOCK_PORTFOLIO, MOCK_VAULTS } from "./mock";
import { fetchVaultRegistry, updateVaultRegistryRow } from "./supabase";

type LiveVaultsResult = {
  vaults: VaultRecord[];
  errors: string[];
  source: {
    supabase: string;
    indexer: string | null;
  };
};

type VaultMetadataPatch = {
  name?: string;
  uiConfig?: OperatorEditableVaultUiConfig;
};

const DEMO_VAULT_OVERRIDES = new Map<string, VaultMetadataPatch>();

function cleanOptionalText(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function cleanUiConfig(
  uiConfig: OperatorEditableVaultUiConfig | undefined
): OperatorEditableVaultUiConfig | undefined {
  if (!uiConfig) return undefined;

  return {
    ...uiConfig,
    risk: cleanOptionalText(uiConfig.risk),
    routeLabel: cleanOptionalText(uiConfig.routeLabel),
    summary: cleanOptionalText(uiConfig.summary),
    banner: cleanOptionalText(uiConfig.banner),
    tags: uiConfig.tags?.map((tag) => tag.trim()).filter((tag) => tag.length > 0),
  };
}

function applyVaultPatch(vault: VaultRecord, patch: VaultMetadataPatch): VaultRecord {
  const nextUiConfig = patch.uiConfig
    ? {
        ...vault.uiConfig,
        ...cleanUiConfig(patch.uiConfig),
      }
    : vault.uiConfig;

  return {
    ...vault,
    name: cleanOptionalText(patch.name) ?? vault.name,
    uiConfig: nextUiConfig,
  };
}

function applyDemoOverrides(vaults: VaultRecord[]): VaultRecord[] {
  return vaults.map((vault) => {
    const override = DEMO_VAULT_OVERRIDES.get(vault.vaultId);
    if (!override) return vault;
    return applyVaultPatch(vault, override);
  });
}

export function getDataSource(): DataSource {
  return resolveDataSource();
}

async function getLiveVaults(): Promise<LiveVaultsResult> {
  const { supabaseUrl, supabaseKey, indexerUrl }: LiveDataRuntimeConfig =
    resolveLiveDataRuntimeConfig();
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
    const normalizedUiConfig = normalizeVaultUiConfig(row.ui_config);
    const uiConfig =
      normalizedUiConfig.strategyKeys || !row.route
        ? normalizedUiConfig
        : { ...normalizedUiConfig, strategyKeys: [row.route] };

    return {
      vaultId: row.vault_id,
      chain: row.chain,
      name: row.name,
      assetSymbol: row.asset_symbol,
      assetAddress: row.asset_address,
      controllerAddress: row.controller_address,
      seniorTokenAddress: row.senior_token_address,
      juniorTokenAddress: row.junior_token_address,
      vaultAddress: row.vault_address,
      tellerAddress: row.teller_address,
      managerAddress: row.manager_address,
      uiConfig,
      metrics: {
        tvl: metrics?.tvl ?? null,
        seniorApyBps: metrics?.seniorApyBps ?? null,
        juniorApyBps: metrics?.juniorApyBps ?? null,
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
}

export async function getVaultsResponse(
  source: DataSource = getDataSource()
): Promise<VaultsApiResponse> {
  if (source === "demo") {
    const demoVaults = applyDemoOverrides(MOCK_VAULTS);
    return VaultsApiResponseSchema.parse({
      generatedAt: new Date().toISOString(),
      source: {
        supabase: "demo",
        indexer: null,
      },
      vaults: demoVaults,
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
    if (source === "live") {
      throw new Error("Failed to load live vault data.");
    }
    return applyDemoOverrides(MOCK_VAULTS);
  }
}

export async function getVaultById(
  id: string,
  source: DataSource = getDataSource()
): Promise<VaultRecord | null> {
  const vaults = await getVaults(source);
  return vaults.find((vault) => vault.vaultId === id) ?? null;
}

export async function updateVaultMetadata(
  vaultId: string,
  patch: VaultMetadataPatch,
  source: DataSource = getDataSource()
): Promise<VaultRecord> {
  if (source === "demo") {
    const current = await getVaultById(vaultId, "demo");
    if (!current) {
      throw new Error("Vault not found.");
    }

    const priorPatch = DEMO_VAULT_OVERRIDES.get(vaultId) ?? {};
    const nextPatch: VaultMetadataPatch = {
      ...priorPatch,
      name: patch.name ?? priorPatch.name,
      uiConfig: {
        ...(priorPatch.uiConfig ?? {}),
        ...(cleanUiConfig(patch.uiConfig) ?? {}),
      },
    };
    DEMO_VAULT_OVERRIDES.set(vaultId, nextPatch);

    return applyVaultPatch(current, nextPatch);
  }

  const { supabaseUrl, supabaseKey } = resolveLiveDataRuntimeConfig();
  const liveVault = await getVaultById(vaultId, "live");
  if (!liveVault) {
    throw new Error("Vault not found.");
  }

  const mergedUiConfig = {
    ...liveVault.uiConfig,
    ...(cleanUiConfig(patch.uiConfig) ?? {}),
  };

  await updateVaultRegistryRow(supabaseUrl, supabaseKey, vaultId, {
    name: cleanOptionalText(patch.name),
    uiConfig: mergedUiConfig,
  });

  const updatedVault = await getVaultById(vaultId, "live");
  if (!updatedVault) {
    throw new Error("Vault update did not return a record.");
  }
  return updatedVault;
}

export function getActivityForVault(vaultId: string): ActivityEvent[] {
  return MOCK_ACTIVITY[vaultId] ?? [];
}

export function getPortfolioSnapshot(): PortfolioSnapshot {
  return MOCK_PORTFOLIO;
}
