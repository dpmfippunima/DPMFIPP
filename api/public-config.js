/**
 * Publishes only values that are explicitly safe to expose in a browser.
 * The publishable key is intentionally not a server secret; Supabase RLS
 * controls exactly which rows the browser may read.
 */
export default function handler(_request, response) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  response.setHeader("Cache-Control", "public, s-maxage=300, stale-while-revalidate=600");

  if (!url || !key) {
    return response.status(503).json({
      error: "Konfigurasi Supabase publik belum tersedia.",
    });
  }

  return response.status(200).json({
    url,
    publishableKey: key,
  });
}
