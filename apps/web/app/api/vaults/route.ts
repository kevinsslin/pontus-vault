import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

const INDEXER_QUERY = `
  query Vaults {
    vaults(first: 1000) {
      id
      controller
      productId
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

type VaultRow = {
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

type IndexerVault = {
  id: string;
  controller?: string | null;
  productId?: string | null;
  tvl?: string | null;
  seniorPrice?: string | null;
  juniorPrice?: string | null;
  seniorDebt?: string | null;
  seniorSupply?: string | null;
  juniorSupply?: string | null;
  updatedAt?: string | null;
};

type IndexerResponse = {
  data?: { vaults?: IndexerVault[] };
  errors?: { message: string }[];
};

function normalizeAddress(value: string): string {
  return value.toLowerCase();
}

async function fetchIndexerVaults(indexerUrl: string): Promise<Map<string, IndexerVault>> {
  const response = await fetch(indexerUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: INDEXER_QUERY }),
  });

  if (!response.ok) {
    throw new Error(`Indexer request failed: ${response.status}`);
  }

  const payload = (await response.json()) as IndexerResponse;
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

export async function GET() {
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
    return NextResponse.json(
      { error: "Missing Supabase configuration." },
      { status: 500 }
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase.from("vault_registry").select("*");
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  let indexerMap = new Map<string, IndexerVault>();
  const errors: string[] = [];

  if (indexerUrl) {
    try {
      indexerMap = await fetchIndexerVaults(indexerUrl);
    } catch (err) {
      errors.push(err instanceof Error ? err.message : "Indexer fetch failed");
    }
  } else {
    errors.push("Missing indexer URL.");
  }

  const vaults = (data as VaultRow[]).map((row) => {
    const controller = normalizeAddress(row.controller_address);
    const metrics = indexerMap.get(controller);

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
      uiConfig: row.ui_config ?? {},
      metrics: {
        tvl: metrics?.tvl ?? null,
        seniorPrice: metrics?.seniorPrice ?? null,
        juniorPrice: metrics?.juniorPrice ?? null,
        seniorDebt: metrics?.seniorDebt ?? null,
        seniorSupply: metrics?.seniorSupply ?? null,
        juniorSupply: metrics?.juniorSupply ?? null,
        updatedAt: metrics?.updatedAt ?? null,
      },
    };
  });

  return NextResponse.json({
    generatedAt: new Date().toISOString(),
    source: {
      supabase: supabaseUrl,
      indexer: indexerUrl || null,
    },
    errors: errors.length > 0 ? errors : undefined,
    vaults,
  });
}
