import type { DataSource } from "@pti/shared";

export const APP_ROUTE_PREFIXES = ["/discover", "/portfolio", "/operator", "/vaults"] as const;

export const DATA_SOURCE_LABEL: Record<DataSource, string> = {
  demo: "Demo data",
  live: "Live data",
};
