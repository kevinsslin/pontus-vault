import { createClient } from "@supabase/supabase-js";
import {
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

export type { SupabaseVaultRegistryRow as VaultRegistryRow };
