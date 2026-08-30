import { ContentGrid } from "@/components/content-grid";
import { PublicLayout } from "@/components/public-layout";
import { getPublishedContent } from "@/lib/public-data";

export default async function StudyPage() { return <PublicLayout><section className="shell section"><p className="eyebrow">D-SIGHT</p><h1>Kajian dan produk pemikiran</h1><ContentGrid items={await getPublishedContent("kajian")} /></section></PublicLayout>; }


