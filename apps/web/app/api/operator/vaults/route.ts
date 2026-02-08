import { NextResponse } from "next/server";
import { z } from "zod";

import {
  OperatorUpdateVaultResponseSchema,
  type VaultStatus,
} from "@pti/shared";

import { resolveDataSource, resolveLiveDataRuntimeConfig } from "../../../../lib/constants/runtime";
import { getVaultById } from "../../../../lib/data/vaults";
import { upsertVaultRegistryRow } from "../../../../lib/data/supabase";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const AddressSchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{40}$/, "Invalid address");

const CreateDraftVaultRequestSchema = z.object({
  requestedBy: AddressSchema,
  vaultId: z.string().min(1).max(120).optional(),
  chain: z.string().min(1).max(80).default("pharos-atlantic"),
  name: z.string().min(1).max(140),
  route: z.string().min(1).max(120),
  assetSymbol: z.string().min(1).max(40),
  assetAddress: AddressSchema,
  status: z.enum(["LIVE", "COMING_SOON"]).optional(),
});

function isAddressLike(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function getOperatorAllowlist(): Set<string> {
  return new Set(
    (process.env.OPERATOR_ADMIN_ADDRESSES ?? "")
      .split(",")
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.length > 0)
  );
}

function assertOperatorPermission(requestedBy: string, source: "demo" | "live") {
  const allowlist = getOperatorAllowlist();
  const normalized = requestedBy.trim().toLowerCase();

  if (!isAddressLike(normalized)) {
    throw new Error("requestedBy must be a valid EVM address.");
  }

  if (allowlist.size === 0 && source === "demo") {
    return;
  }

  if (allowlist.size === 0) {
    throw new Error("Operator allowlist is required in live mode.");
  }

  if (!allowlist.has(normalized)) {
    throw new Error("Operator wallet is not authorized.");
  }
}

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = CreateDraftVaultRequestSchema.parse(body);

    const source = resolveDataSource();
    assertOperatorPermission(parsed.requestedBy, source);

    const vaultId = parsed.vaultId ?? crypto.randomUUID();
    const status: VaultStatus = parsed.status ?? "COMING_SOON";

    if (source === "demo") {
      const draft = await getVaultById(vaultId, "demo");
      if (draft) {
        throw new Error("Vault ID already exists.");
      }

      return NextResponse.json(
        OperatorUpdateVaultResponseSchema.parse({
          vault: {
            vaultId,
            chain: parsed.chain,
            name: parsed.name,
            route: parsed.route,
            assetSymbol: parsed.assetSymbol,
            assetAddress: parsed.assetAddress,
            controllerAddress: ZERO_ADDRESS,
            seniorTokenAddress: ZERO_ADDRESS,
            juniorTokenAddress: ZERO_ADDRESS,
            vaultAddress: ZERO_ADDRESS,
            tellerAddress: ZERO_ADDRESS,
            managerAddress: ZERO_ADDRESS,
            uiConfig: {
              status,
            },
            metrics: {
              tvl: null,
              seniorApyBps: null,
              juniorApyBps: null,
              seniorPrice: null,
              juniorPrice: null,
              seniorDebt: null,
              seniorSupply: null,
              juniorSupply: null,
              updatedAt: null,
            },
          },
        })
      );
    }

    const runtime = resolveLiveDataRuntimeConfig();
    await upsertVaultRegistryRow(runtime.supabaseUrl, runtime.supabaseKey, {
      vaultId,
      chain: parsed.chain,
      name: parsed.name,
      route: parsed.route,
      assetSymbol: parsed.assetSymbol,
      assetAddress: parsed.assetAddress,
      controllerAddress: ZERO_ADDRESS,
      seniorTokenAddress: ZERO_ADDRESS,
      juniorTokenAddress: ZERO_ADDRESS,
      vaultAddress: ZERO_ADDRESS,
      tellerAddress: ZERO_ADDRESS,
      managerAddress: ZERO_ADDRESS,
      uiConfig: {
        status,
      },
    });

    const vault = await getVaultById(vaultId, "live");
    if (!vault) {
      throw new Error("Vault creation did not return a record.");
    }

    return NextResponse.json(
      OperatorUpdateVaultResponseSchema.parse({ vault })
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to create vault.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
