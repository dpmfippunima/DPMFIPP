import "./admin.css";
import Link from "next/link";
import { redirect } from "next/navigation";
import { adminNavigation } from "@/lib/permissions";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AppRole } from "@/lib/types";

const labels: Record<string, string> = {
  dashboard: "Dashboard",
  aspirasi: "D-DAS",
  kajian: "D-SIGHT",
  monitoring: "D-TRACE",
  laporan: "Laporan",
  "program-kerja": "Program Kerja",
  berita: "Publikasi",
  survei: "Survei",
  media: "Media",
  "workflow/approval": "Approval",
  "access/requests": "Request Access",
  "organization/periods": "Periode & Organisasi",
  users: "Pengguna",
  "audit-log": "Audit Log",
};

const hrefs: Record<string, string> = {
  dashboard: "/admin/dashboard",
  aspirasi: "/admin/aspirasi",
  kajian: "/admin/kajian",
  monitoring: "/admin/monitoring",
  laporan: "/admin/laporan",
  "program-kerja": "/admin/program-kerja",
  berita: "/admin/berita",
  survei: "/admin/survei",
  media: "/admin/media",

  "workflow/approval": "/admin/approval",
  "access/requests": "/admin/request-access",
  "organization/periods": "/admin/periode-organisasi",

  users: "/admin/users",
  "audit-log": "/admin/audit-log",
};

function normalizeRole(role: string): AppRole {
  return role === "commission_1" || role === "commission_2"
    ? "commission"
    : (role as AppRole);
}

export default async function AdminLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name,role,status")
    .eq("id", user.id)
    .single();

  if (!profile || profile.status !== "active") {
    redirect("/login?error=inactive");
  }

  const role = normalizeRole(profile.role);

  return (
    <div className="admin">
      <aside className="sidebar">
        <Link className="brand" href="/admin/dashboard">
          DPM FIPP
          <small>ADMIN</small>
        </Link>

        <p>{profile.full_name}</p>

        <nav>
          {adminNavigation(role).map((item) => (
            <Link
              key={item}
              href={hrefs[item] || `/admin/${item}`}
            >
              {labels[item] || item}
            </Link>
          ))}
        </nav>

        <Link href="/">← Portal publik</Link>
      </aside>

      <main className="adminMain">
        {children}
      </main>
    </div>
  );
}