import { NextResponse } from "next/server";
import {
  OperatorCreateOperationResponseSchema,
  OperatorUpdateStepRequestSchema,
} from "@pti/shared";
import { updateOperatorOperationStep } from "../../../../../../../lib/operator/store";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type RouteContext = {
  params: Promise<{
    operationId: string;
    stepIndex: string;
  }>;
};

export async function PATCH(request: Request, { params }: RouteContext) {
  try {
    const { operationId, stepIndex } = await params;
    const index = Number(stepIndex);
    if (!Number.isFinite(index) || index < 0) {
      return NextResponse.json({ error: "Invalid step index." }, { status: 400 });
    }

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
