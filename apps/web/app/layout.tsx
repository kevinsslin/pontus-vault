import "./globals.css";
import type { ReactNode } from "react";

export const metadata = {
  title: "Pontus Vault",
  description: "Pharos Tranche Vault Infra"
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
