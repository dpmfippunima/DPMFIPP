"use client";

import { usePathname } from "next/navigation";

const pageTitles: Record<string, string> = {
  "/admin/dashboard": "Dashboard",
  "/admin/aspirasi": "D-DAS",
  "/admin/kajian": "D-SIGHT",
  "/admin/monitoring": "D-TRACE",
  "/admin/laporan": "Laporan",

  "/admin/program-kerja": "Program Kerja",
  "/admin/berita": "Publikasi",
  "/admin/survei": "Survei",
  "/admin/media": "Media",

  "/admin/approval": "Approval",
  "/admin/request-access": "Request Access",
  "/admin/periode-organisasi": "Periode & Organisasi",

  "/admin/users": "Pengguna",
  "/admin/audit-log": "Audit Log",

  "/admin/notifikasi": "Notifikasi",
};

export default function AdminPageHeader() {
  const pathname = usePathname();

  const pageTitle =
    pageTitles[pathname] ??
    Object.entries(pageTitles).find(([path]) =>
      pathname.startsWith(`${path}/`)
    )?.[1] ??
    "Admin Panel";

  return (
    <div className="adminPageHeader">
      <span className="adminPageBreadcrumb">
        Admin Panel
      </span>

      <h1>
        {pageTitle}
      </h1>

      <p>
        Kelola dan pantau aktivitas melalui halaman {pageTitle}.
      </p>
    </div>
  );
}