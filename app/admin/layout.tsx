import "./admin.css";

import Link from "next/link";
import { redirect } from "next/navigation";

import AdminPageHeader from "./AdminPageHeader";
import AdminSidebarNav from "./AdminSidebarNav";
import AdminMobileMenu from "./AdminMobileMenu";

import { adminNavigation } from "@/lib/permissions";
import { createSupabaseServerClient } from "@/lib/supabase/server";

import type { AppRole } from "@/lib/types";

/* =========================================================
   NAVIGATION LABELS
========================================================= */

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

/* =========================================================
   NAVIGATION HREFS
========================================================= */

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

/* =========================================================
   ROLE NORMALIZATION
========================================================= */

function normalizeRole(role: string): AppRole {
  if (
    role === "commission_1" ||
    role === "commission_2"
  ) {
    return "commission";
  }

  return role as AppRole;
}

/* =========================================================
   ADMIN LAYOUT
========================================================= */

export default async function AdminLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const supabase = await createSupabaseServerClient();

  /* =======================================================
     AUTHENTICATION
  ======================================================= */

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  /* =======================================================
     USER PROFILE
  ======================================================= */

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, role, status")
    .eq("id", user.id)
    .single();

  if (!profile || profile.status !== "active") {
    redirect("/login?error=inactive");
  }

  /* =======================================================
     ROLE
  ======================================================= */

  const role = normalizeRole(profile.role);
  function formatRole(role: string) {
  const roleLabels: Record<string, string> = {
    super_admin: "Administrator",
    chairperson: "Ketua Umum",
    secretary: "Sekretaris Umum",

    commission_1: "Komisi 1",
    commission_2: "Komisi 2",

    viewer: "Pengunjung",
  };

  return roleLabels[role] ?? role;
}

  /* =======================================================
     ADMIN NAVIGATION
  ======================================================= */

  const navigationItems = adminNavigation(role);

  /* =======================================================
     NOTIFICATION COUNT
  ======================================================= */

  const {
    count: unreadNotificationsCount,
    error: notificationsCountError,
  } = await supabase
    .from("admin_notifications")
    .select("*", {
      count: "exact",
      head: true,
    })
    .eq("is_read", false);

  if (notificationsCountError) {
    console.error(
      "Error counting unread notifications:",
      notificationsCountError
    );
  }

  const unreadCount = unreadNotificationsCount ?? 0;

  /* =======================================================
     RENDER
  ======================================================= */

  return (
    <div className="admin">

      {/* =====================================================
          DESKTOP SIDEBAR
      ===================================================== */}

      <aside className="sidebar">

        {/* BRAND */}

        <Link
          className="brand"
          href="/admin/dashboard"
        >
          DPM FIPP

          <small>
            ADMIN
          </small>
        </Link>

        {/* USER */}

        <p className="sidebarUserName">
          {profile.full_name}
        </p>

        {/* NAVIGATION */}

        <AdminSidebarNav
          items={navigationItems}
          hrefs={hrefs}
          labels={labels}
        />

        {/* PUBLIC PORTAL */}

        <Link
          className="publicPortalLink"
          href="/"
        >
          ← Portal Publik
        </Link>

      </aside>

      {/* =====================================================
          MAIN CONTENT
      ===================================================== */}

      <main className="adminMain">

        {/* ===================================================
            ADMIN HEADER
        =================================================== */}

        <header className="adminHeader">

          <div className="adminHeaderInfo">

            <span className="adminHeaderLabel">
              DPM FIPP UNIMA
            </span>

            <span className="adminHeaderRole">
              {formatRole (profile.role)}
            </span>

          </div>

          <div className="adminHeaderActions">

            {/* NOTIFICATION */}

            <Link
  href="/admin/notifikasi"
  className="notificationBell"
  aria-label="Notifikasi"
>
  <span className="notificationBellIcon">
    🔔
  </span>

  {unreadCount > 0 && (
    <span className="notificationBadge">
      {unreadCount > 99
        ? "99+"
        : unreadCount}
    </span>
  )}
</Link>

            {/* MOBILE MENU */}

            <AdminMobileMenu
              items={navigationItems}
              hrefs={hrefs}
              labels={labels}
              userName={profile.full_name}
            />

          </div>

        </header>

        {/* ===================================================
            DYNAMIC PAGE HEADER
        =================================================== */}

        <AdminPageHeader />

        {/* ===================================================
            PAGE CONTENT
        =================================================== */}

        {children}

      </main>

    </div>
  );
}