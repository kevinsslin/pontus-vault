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
