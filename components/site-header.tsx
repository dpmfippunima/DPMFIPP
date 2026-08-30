import Link from "next/link";

export function SiteHeader() {
  return <header className="siteHeader"><nav className="shell nav" aria-label="Navigasi utama"><Link className="brand" href="/">DPM FIPP<small>UNIMA</small></Link><div className="navLinks"><Link href="/tentang">Tentang</Link><Link href="/d-das">D-DAS</Link><Link href="/kajian">D-SIGHT</Link><Link href="/monitoring">D-TRACE</Link><Link href="/arsip">D-DAR</Link><Link href="/berita">Publikasi</Link><Link className="button" href="/admin/dashboard">Admin</Link></div></nav></header>;
}
