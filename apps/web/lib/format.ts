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

export function formatBps(value: string | null): string {
  if (!value) return "—";
  const bps = Number(value);
  if (!Number.isFinite(bps)) return "—";
  return `${(bps / 100).toFixed(2)}%`;
}

export function apySpreadBps(seniorBps: string | null, juniorBps: string | null): string {
  if (!seniorBps || !juniorBps) return "—";
  const senior = Number(seniorBps);
  const junior = Number(juniorBps);
  if (!Number.isFinite(senior) || !Number.isFinite(junior)) return "—";
  const spread = (junior - senior) / 100;
  return `${spread.toFixed(2)}%`;
}

export function formatTimestamp(value: string | null): string {
  if (!value) return "—";
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return "—";
  return new Date(seconds * 1000).toLocaleString();
}

export function formatRelativeTimestamp(value: string | null): string {
  if (!value) return "—";
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return "—";

  const ts = seconds * 1000;
  const deltaMs = ts - Date.now();
  const deltaAbs = Math.abs(deltaMs);
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;

  if (deltaAbs < hour) {
    return rtf.format(Math.round(deltaMs / minute), "minute");
  }
  if (deltaAbs < day) {
    return rtf.format(Math.round(deltaMs / hour), "hour");
  }
  return rtf.format(Math.round(deltaMs / day), "day");
}
