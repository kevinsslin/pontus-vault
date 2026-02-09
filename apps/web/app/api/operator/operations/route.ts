import { NextResponse } from "next/server";
import {
  OperatorCreateOperationRequestSchema,
  OperatorCreateOperationResponseSchema,
  OperatorListOperationsResponseSchema,
} from "@pti/shared";
import { buildOperationSteps } from "../../../../lib/operator/plans";
import {
  createOperatorOperation,
  listOperatorOperations,
} from "../../../../lib/operator/store";
import { getDataSource, getVaultById } from "../../../../lib/data/vaults";

export const dynamic = "force-dynamic";
export const revalidate = 0;

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

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const vaultId = url.searchParams.get("vaultId") ?? undefined;
    const limit = Number(url.searchParams.get("limit") ?? "50");
    const operations = await listOperatorOperations(
      vaultId,
      Number.isFinite(limit) ? limit : 50
    );
    return NextResponse.json(
      OperatorListOperationsResponseSchema.parse({ operations })
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to list operations.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = OperatorCreateOperationRequestSchema.parse(body);
    assertOperatorPermission(parsed.requestedBy, getDataSource());

    const vault = await getVaultById(parsed.vaultId, getDataSource());
    if (!vault) {
      return NextResponse.json(
        { error: "Vault not found." },
        { status: 404 }
      );
    }

    const stepTemplates = buildOperationSteps(vault, parsed);
    const operation = await createOperatorOperation(parsed, stepTemplates);
    return NextResponse.json(
      OperatorCreateOperationResponseSchema.parse(operation)
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to create operation.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
