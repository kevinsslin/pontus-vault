import { NextResponse } from "next/server";
import { getDataSource, getVaultsResponse } from "../../../lib/data/vaults";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET() {
  try {
    const response = await getVaultsResponse(getDataSource());
    return NextResponse.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to load vaults.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
