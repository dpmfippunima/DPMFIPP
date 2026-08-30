import { notFound } from "next/navigation";

const modules: Record<string, { title: string; copy: string }> = {
  aspirasi: { title: "D-DAS", copy: "Triage aspirasi, forwarding, respons, dan audit status akan tersedia melalui layanan yang terotorisasi." },
  kajian: { title: "D-SIGHT", copy: "Kelola kajian, opini, kebijakan, media, dan lifecycle konten." },
  legislasi: { title: "Legislasi", copy: "Kelola draft legislasi internal hingga publikasi yang disetujui." },
  monitoring: { title: "D-TRACE", copy: "Kelola laporan monitoring dan proyeksi publik yang aman." },
  laporan: { title: "Laporan", copy: "Kelola laporan transparansi dan arsip publik." },
  "program-kerja": { title: "Program Kerja", copy: "Kelola agenda, progres, evaluasi, dan dokumentasi." },
  berita: { title: "Publikasi", copy: "Kelola berita, pengumuman, artikel, galeri, dan media terurut." },
  survei: { title: "Survei", copy: "Kelola pertanyaan, periode terbuka, hasil publik, dan respons terlindungi." },
  media: { title: "Media", copy: "Kelola cover, gallery, caption, alt text, serta file sesuai klasifikasi." },
  users: { title: "Pengguna", copy: "Undang pengguna dan tetapkan assignment tanpa menaikkan role sendiri." },
  "audit-log": { title: "Audit Log", copy: "Audit log bersifat append-only dan tidak dapat diubah dari UI." },
};

export default async function AdminModulePage({ params }: { params: Promise<{ module: string }> }) { const { module } = await params; const current = modules[module]; if (!current) notFound(); return <><p className="eyebrow">Admin Panel</p><h1>{current.title}</h1><div className="notice">{current.copy}</div></>; }
