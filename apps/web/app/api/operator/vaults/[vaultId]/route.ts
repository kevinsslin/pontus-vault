import { NextResponse } from "next/server";
import {
  OperatorUpdateVaultRequestSchema,
  OperatorUpdateVaultResponseSchema,
} from "@pti/shared";
import {
  getDataSource,
  getVaultById,
  updateVaultMetadata,
} from "../../../../../lib/data/vaults";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type RouteContext = {
  params: Promise<{
    vaultId: string;
  }>;
};

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

export async function GET(_: Request, { params }: RouteContext) {
  try {
    const { vaultId } = await params;
    const vault = await getVaultById(vaultId, getDataSource());
    if (!vault) {
      return NextResponse.json({ error: "Vault not found." }, { status: 404 });
    }

    return NextResponse.json(
      OperatorUpdateVaultResponseSchema.parse({ vault })
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to load vault.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function PATCH(request: Request, { params }: RouteContext) {
  try {
    const { vaultId } = await params;
    const source = getDataSource();

    const body = await request.json();
    const parsed = OperatorUpdateVaultRequestSchema.parse(body);
    assertOperatorPermission(parsed.requestedBy, source);

    const vault = await updateVaultMetadata(
      vaultId,
      {
        name: parsed.name,
        uiConfig: parsed.uiConfig,
      },
      source
    );

    return NextResponse.json(
      OperatorUpdateVaultResponseSchema.parse({ vault })
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to update vault.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
