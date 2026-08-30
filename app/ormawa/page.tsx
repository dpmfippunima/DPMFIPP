import { PublicLayout } from "@/components/public-layout";
import { getActiveOrganizations } from "@/lib/public-data";

export default async function OrganizationsPage() { const organizations = await getActiveOrganizations(); return <PublicLayout><section className="shell section"><p className="eyebrow">ORMAWA</p><h1>Organisasi mahasiswa FIPP</h1>{organizations.length ? <div className="grid">{organizations.map((item) => <article className="card" key={item.id}><span className="tag">{item.code}</span><h3>{item.name}</h3><p>{item.description || "Profil organisasi mahasiswa periode aktif."}</p></article>)}</div> : <div className="empty">Belum ada organisasi aktif yang dipublikasikan.</div>}</section></PublicLayout>; }
