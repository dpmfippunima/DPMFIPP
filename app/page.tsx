import Link from "next/link";
import { ContentGrid } from "@/components/content-grid";
import { PublicLayout } from "@/components/public-layout";
import { getPublishedContent } from "@/lib/public-data";

export default async function HomePage() {
  const items = await getPublishedContent();
  return <PublicLayout><section className="hero"><div className="shell"><p className="eyebrow">Portal digital kelembagaan</p><h1>Suara mahasiswa, kerja yang terbuka.</h1><p>DPM FIPP UNIMA menerima aspirasi, mengawal kebijakan, dan membagikan informasi kelembagaan secara transparan.</p><Link className="button secondary" href="/d-das">Sampaikan aspirasi</Link></div></section><section className="shell section"><div className="sectionHead"><div><p className="eyebrow">Publikasi terbaru</p><h2>Informasi DPM</h2></div><Link href="/berita">Lihat semua →</Link></div><ContentGrid items={items.slice(0, 6)} /></section></PublicLayout>;
}
