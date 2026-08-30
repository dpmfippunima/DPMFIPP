import { ContentGrid } from "@/components/content-grid";
import { PublicLayout } from "@/components/public-layout";
import { getPublishedContent } from "@/lib/public-data";

export default async function PublicationPage() { return <PublicLayout><section className="shell section"><p className="eyebrow">Publikasi</p><h1>Berita dan informasi DPM</h1><ContentGrid items={await getPublishedContent()} /></section></PublicLayout>; }
