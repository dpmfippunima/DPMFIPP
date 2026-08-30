import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "DPM FIPP UNIMA",
  description: "Portal digital kelembagaan DPM FIPP UNIMA.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="id"><body>{children}</body></html>;
}
