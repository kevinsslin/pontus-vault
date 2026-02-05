import "./globals.css";
import type { ReactNode } from "react";
import { Cormorant_Garamond, Sora } from "next/font/google";
import SiteHeader from "./components/SiteHeader";
import SiteFooter from "./components/SiteFooter";
import AppProviders from "./components/AppProviders";
import Atmosphere from "./components/Atmosphere";

const displayFont = Cormorant_Garamond({
  subsets: ["latin"],
  variable: "--font-display",
  weight: ["500", "600", "700"],
});

const bodyFont = Sora({
  subsets: ["latin"],
  variable: "--font-body",
  weight: ["400", "500", "600", "700"],
});

export const metadata = {
  title: "Pontus Vault",
  description:
    "Institutional-grade tranche vault infrastructure built on Pharos.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className={`${displayFont.variable} ${bodyFont.variable}`}>
        <AppProviders>
          <div className="shell">
            <Atmosphere />
            <SiteHeader />
            {children}
            <SiteFooter />
          </div>
        </AppProviders>
      </body>
    </html>
  );
}
