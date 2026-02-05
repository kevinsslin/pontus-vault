import { createClient } from "@supabase/supabase-js";

type VaultRegistryRow = {
  product_id: string;
  chain: string;
  name: string;
  route: string;
  asset_symbol: string;
  asset_address: string;
  controller_address: string;
  senior_token_address: string;
  junior_token_address: string;
  vault_address: string;
  teller_address: string;
  manager_address: string;
  ui_config: Record<string, unknown> | null;
};

export async function fetchVaultRegistry(
  supabaseUrl: string,
  supabaseKey: string
): Promise<VaultRegistryRow[]> {
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase.from("vault_registry").select("*");
  if (error) {
    throw new Error(error.message);
  }

  return (data as VaultRegistryRow[]) ?? [];
}

export type { VaultRegistryRow };
