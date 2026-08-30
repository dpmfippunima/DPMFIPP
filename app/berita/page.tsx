import { ContentGrid } from "@/components/content-grid";
import { PublicLayout } from "@/components/public-layout";
import { getPublishedContent } from "@/lib/public-data";
import Link from "next/link";

export default async function PublicationPage() { return <PublicLayout><section className="shell section"><p className="eyebrow">Publikasi</p><h1>Berita dan informasi DPM</h1><ContentGrid items={await getPublishedContent()} /></section></PublicLayout>; }


<div className="adminState">
  <div className="adminStateIcon">
    📰
  </div>

  <h2>Belum Ada Berita</h2>

  <p>
    Belum ada konten berita yang dibuat.
    Mulai tambahkan berita untuk ditampilkan
    di portal publik.
  </p>

  <Link
    href="/admin/berita/tambah"
    className="adminStateAction"
  >
    + Tambah Berita
  </Link>
</div>