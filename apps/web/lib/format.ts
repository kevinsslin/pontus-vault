const usdCompact = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  notation: "compact",
  maximumFractionDigits: 2,
});

const usdStandard = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

export function formatUsd(value: string | null, decimals = 6): string {
  if (!value) return "—";
  try {
    const base = BigInt(10) ** BigInt(decimals);
    const raw = BigInt(value);
    const whole = raw / base;
    const fraction = raw % base;
    const numeric = Number(whole) + Number(fraction) / Number(base);
    return usdCompact.format(numeric);
  } catch {
    return "—";
  }
}

export function formatUsdLong(value: string | null, decimals = 6): string {
  if (!value) return "—";
  try {
    const base = BigInt(10) ** BigInt(decimals);
    const raw = BigInt(value);
    const whole = raw / base;
    const fraction = raw % base;
    const numeric = Number(whole) + Number(fraction) / Number(base);
    return usdStandard.format(numeric);
  } catch {
    return "—";
  }
}

export function formatWad(value: string | null, decimals = 18): string {
  if (!value) return "—";
  try {
    const base = BigInt(10) ** BigInt(decimals);
    const raw = BigInt(value);
    const whole = raw / base;
    const fraction = raw % base;
    const numeric = Number(whole) + Number(fraction) / Number(base);
    return numeric.toFixed(3);
  } catch {
    return "—";
  }
}

export function formatTimestamp(value: string | null): string {
  if (!value) return "—";
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return "—";
  return new Date(seconds * 1000).toLocaleString();
}
