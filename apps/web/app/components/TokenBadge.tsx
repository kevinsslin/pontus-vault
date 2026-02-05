import Image from "next/image";

const TOKEN_LOGOS: Record<string, string> = {
  USDC: "/tokens/usdc.png",
  USDT: "/tokens/usdt.png",
};

export default function TokenBadge({ symbol }: { symbol: string }) {
  const normalized = symbol.toUpperCase();
  const src = TOKEN_LOGOS[normalized] ?? "/tokens/generic.svg";

  return (
    <span className="token-badge" title={normalized}>
      <Image src={src} alt={`${normalized} logo`} width={26} height={26} />
      <span className="sr-only">{normalized}</span>
    </span>
  );
}
