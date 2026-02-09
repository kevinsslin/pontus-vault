import type { ReactNode } from "react";
import DynamicBoundary from "../components/DynamicBoundary";

export default function VaultsLayout({ children }: { children: ReactNode }) {
  return <DynamicBoundary>{children}</DynamicBoundary>;
}
