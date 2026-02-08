import "server-only";
import type { DataSource } from "@pti/shared";

const DEFAULT_DATA_SOURCE: DataSource = "demo";

export type LiveDataRuntimeConfig = {
  supabaseUrl: string;
  supabaseKey: string;
  indexerUrl: string | null;
};

export function resolveDataSource(): DataSource {
  const value = process.env.NEXT_PUBLIC_DATA_SOURCE ?? process.env.DATA_SOURCE ?? DEFAULT_DATA_SOURCE;
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
    process.env.NEXT_PUBLIC_INDEXER_URL ??
    process.env.INDEXER_URL ??
    process.env.GOLDSKY_SUBGRAPH_URL ??
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
