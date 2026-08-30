import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DPM FIPP UNIMA",
  description: "Portal digital kelembagaan DPM FIPP UNIMA.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="id"><body>{children}</body></html>;
}
