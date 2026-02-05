import { NextResponse } from "next/server";
import { getVaultsResponse } from "../../../lib/data/vaults";

export async function GET() {
  try {
    const response = await getVaultsResponse();
    return NextResponse.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to load vaults.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
