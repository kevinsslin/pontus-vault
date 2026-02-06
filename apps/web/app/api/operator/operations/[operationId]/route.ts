import { NextResponse } from "next/server";
import { OperatorCreateOperationResponseSchema } from "@pti/shared";
import { getOperatorOperation } from "../../../../../lib/operator/store";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type RouteContext = {
  params: Promise<{
    operationId: string;
  }>;
};

export async function GET(_: Request, { params }: RouteContext) {
  try {
    const { operationId } = await params;
    const payload = await getOperatorOperation(operationId);
    if (!payload) {
      return NextResponse.json({ error: "Operation not found." }, { status: 404 });
    }
    return NextResponse.json(OperatorCreateOperationResponseSchema.parse(payload));
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to load operation.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
