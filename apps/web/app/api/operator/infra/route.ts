import { NextResponse } from "next/server";
import { OperatorInfraResponseSchema, PHAROS_ATLANTIC } from "@pti/shared";

function isAddressLike(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET() {
  try {
    const trancheFactoryRaw = (process.env.TRANCHE_FACTORY ?? PHAROS_ATLANTIC.pontusInfra.trancheFactory).trim();
    const trancheRegistryRaw = (process.env.TRANCHE_REGISTRY ?? PHAROS_ATLANTIC.pontusInfra.trancheRegistry).trim();

    const payload = OperatorInfraResponseSchema.parse({
      chainId: PHAROS_ATLANTIC.chainId,
      trancheFactory: isAddressLike(trancheFactoryRaw) ? trancheFactoryRaw : null,
      trancheRegistry: isAddressLike(trancheRegistryRaw) ? trancheRegistryRaw : null,
    });

    return NextResponse.json(payload);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to load infra settings.";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
