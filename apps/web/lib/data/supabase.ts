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
  route?: string;
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
  if (update.route !== undefined) {
    payload.route = update.route;
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

export type { SupabaseVaultRegistryRow as VaultRegistryRow };
