import { NextResponse } from "next/server";
import {
  OperatorCreateOperationResponseSchema,
  OperatorUpdateStepRequestSchema,
} from "@pti/shared";
import { updateOperatorOperationStep } from "../../../../../../../lib/operator/store";
import { resolveDataSource } from "../../../../../../../lib/constants/runtime";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type RouteContext = {
  params: Promise<{
    operationId: string;
    stepIndex: string;
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
    throw new Error("Operator address header is required.");
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

export async function PATCH(request: Request, { params }: RouteContext) {
  try {
    const { operationId, stepIndex } = await params;
    const index = Number(stepIndex);
    if (!Number.isFinite(index) || index < 0) {
      return NextResponse.json({ error: "Invalid step index." }, { status: 400 });
    }

    const operatorAddress = request.headers.get("x-operator-address") ?? "";
    assertOperatorPermission(operatorAddress, resolveDataSource());

    const body = await request.json();
    const patch = OperatorUpdateStepRequestSchema.parse(body);
    const operation = await updateOperatorOperationStep(operationId, index, patch);
    return NextResponse.json(OperatorCreateOperationResponseSchema.parse(operation));
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to update step.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
