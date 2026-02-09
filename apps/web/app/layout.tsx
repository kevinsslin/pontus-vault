import "./globals.css";
import type { ReactNode } from "react";
import { Manrope, Plus_Jakarta_Sans } from "next/font/google";
import DynamicBoundary from "./components/DynamicBoundary";
import SiteHeader from "./components/SiteHeader";
import SiteFooter from "./components/SiteFooter";
import Atmosphere from "./components/Atmosphere";

const displayFont = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-display",
  weight: ["500", "600", "700", "800"],
});

const bodyFont = Manrope({
  subsets: ["latin"],
  variable: "--font-body",
  weight: ["400", "500", "600", "700", "800"],
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
        <div className="shell">
          <DynamicBoundary>
            <Atmosphere />
            <SiteHeader />
            {children}
            <SiteFooter />
          </DynamicBoundary>
        </div>
      </body>
    </html>
  );
}
