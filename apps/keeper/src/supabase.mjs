import {createClient} from "@supabase/supabase-js";

import {getEnv, getRequiredEnv} from "./env.mjs";

export function getSupabaseAdminClient() {
  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {persistSession: false}
  });
}

export function getRequiredSupabaseAdminClient() {
  const supabaseUrl = getRequiredEnv("SUPABASE_URL");
  const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {persistSession: false}
  });
}

