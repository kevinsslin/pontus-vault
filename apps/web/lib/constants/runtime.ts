import "server-only";
import type { DataSource } from "@pti/shared";

const DEFAULT_DATA_SOURCE: DataSource = "demo";

export type LiveDataRuntimeConfig = {
  supabaseUrl: string;
  supabaseKey: string;
  indexerUrl: string | null;
};

export function resolveDataSource(): DataSource {
  // This module is server-only. Prefer server-side config to avoid accidental overrides
  // from NEXT_PUBLIC_* vars that might be set for the browser bundle.
  const value =
    process.env.DATA_SOURCE ??
    process.env.NEXT_PUBLIC_DATA_SOURCE ??
    DEFAULT_DATA_SOURCE;
  return value === "live" ? "live" : "demo";
}

export function resolveLiveDataRuntimeConfig(): LiveDataRuntimeConfig {
  const supabaseUrl = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const supabaseKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ??
    process.env.SUPABASE_ANON_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    "";
  const indexerUrl =
    process.env.INDEXER_URL ?? process.env.GOLDSKY_SUBGRAPH_URL ?? "";

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Missing Supabase configuration.");
  }

  return {
    supabaseUrl,
    supabaseKey,
    indexerUrl: indexerUrl || null,
  };
}
