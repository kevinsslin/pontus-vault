import { createClient } from "@supabase/supabase-js";
import {
  normalizeVaultUiConfig,
  SupabaseVaultRegistryRowSchema,
  type SupabaseVaultRegistryRow,
} from "@pti/shared";

export async function fetchVaultRegistry(
  supabaseUrl: string,
  supabaseKey: string
): Promise<SupabaseVaultRegistryRow[]> {
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase.from("vault_registry").select("*");
  if (error) {
    throw new Error(error.message);
  }

  return SupabaseVaultRegistryRowSchema.array().parse(data ?? []);
}

type VaultRegistryUpdate = {
  name?: string;
  uiConfig?: Record<string, unknown>;
};

type VaultRegistryUpsert = {
  vaultId: string;
  chain: string;
  name: string;
  assetSymbol: string;
  assetAddress: string;
  controllerAddress: string;
  seniorTokenAddress: string;
  juniorTokenAddress: string;
  vaultAddress: string;
  tellerAddress: string;
  managerAddress: string;
  uiConfig?: Record<string, unknown>;
};

export async function updateVaultRegistryRow(
  supabaseUrl: string,
  supabaseKey: string,
  vaultId: string,
  update: VaultRegistryUpdate
): Promise<SupabaseVaultRegistryRow> {
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const { data: existingData, error: existingError } = await supabase
    .from("vault_registry")
    .select("*")
    .eq("vault_id", vaultId)
    .maybeSingle();

  if (existingError) {
    throw new Error(existingError.message);
  }
  if (!existingData) {
    throw new Error("Vault not found in registry.");
  }

  const existingRow = SupabaseVaultRegistryRowSchema.parse(existingData);
  const mergedUiConfig = {
    ...normalizeVaultUiConfig(existingRow.ui_config),
    ...(update.uiConfig ?? {}),
  };

  const payload: Record<string, unknown> = {
    ui_config: mergedUiConfig,
  };

  if (update.name !== undefined) {
    payload.name = update.name;
  }

  const { data, error } = await supabase
    .from("vault_registry")
    .update(payload)
    .eq("vault_id", vaultId)
    .select("*")
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }
  if (!data) {
    throw new Error("Vault update returned no rows.");
  }

  return SupabaseVaultRegistryRowSchema.parse(data);
}

export async function upsertVaultRegistryRow(
  supabaseUrl: string,
  supabaseKey: string,
  payload: VaultRegistryUpsert
): Promise<SupabaseVaultRegistryRow> {
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase
    .from("vault_registry")
    .upsert(
      {
        vault_id: payload.vaultId,
        chain: payload.chain,
        name: payload.name,
        asset_symbol: payload.assetSymbol,
        asset_address: payload.assetAddress,
        controller_address: payload.controllerAddress,
        senior_token_address: payload.seniorTokenAddress,
        junior_token_address: payload.juniorTokenAddress,
        vault_address: payload.vaultAddress,
        teller_address: payload.tellerAddress,
        manager_address: payload.managerAddress,
        ui_config: normalizeVaultUiConfig(payload.uiConfig),
      },
      { onConflict: "vault_id" }
    )
    .select("*")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return SupabaseVaultRegistryRowSchema.parse(data);
}

export type { SupabaseVaultRegistryRow as VaultRegistryRow };
