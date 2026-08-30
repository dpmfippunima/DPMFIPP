import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function getCount(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  table: string,
  filter?: (query: any) => any
) {
  let query = supabase
    .from(table)
    .select("*", { count: "exact", head: true });

  if (filter) {
    query = filter(query);
  }

  const { count, error } = await query;

  if (error) {
    console.error(`Error counting ${table}:`, error);
    return 0;
  }

  return count ?? 0;
}

function formatAspirationStatus(status: string) {
  const labels: Record<string, string> = {
    submitted: "Masuk",
    in_review: "Ditinjau",
    forwarded: "Diteruskan",
    followed_up: "Ditindaklanjuti",
    completed: "Selesai",
    rejected: "Ditolak",
    archived: "Diarsipkan",
  };

  return labels[status] ?? status;
}

export default async function AdminDashboard() {
  const supabase = await createSupabaseServerClient();

  const [
  activePeriodResult,
  organizationsCount,

  aspirationsCount,
  aspirationsSubmittedCount,
  aspirationsReviewCount,
  aspirationsForwardedCount,
  aspirationsFollowedUpCount,
  aspirationsCompletedCount,

  pendingContentsCount,
  pendingAccessCount,
  usersCount,
] = await Promise.all([
  supabase
    .from("periods")
    .select("id,name,year_start,year_end")
    .eq("is_active", true)
    .maybeSingle(),

  getCount(
    supabase,
    "organizations",
    (query) =>
      query
        .eq("status", "active")
        .is("deleted_at", null)
  ),

  // TOTAL ASPIRASI
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query.is("deleted_at", null)
  ),

  // ASPIRASI MASUK
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query
        .eq("status", "submitted")
        .is("deleted_at", null)
  ),

  // SEDANG DITINJAU
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query
        .eq("status", "in_review")
        .is("deleted_at", null)
  ),

  // DITERUSKAN
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query
        .eq("status", "forwarded")
        .is("deleted_at", null)
  ),

  // DITINDAKLANJUTI
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query
        .eq("status", "followed_up")
        .is("deleted_at", null)
  ),

  // SELESAI
  getCount(
    supabase,
    "aspirations",
    (query) =>
      query
        .eq("status", "completed")
        .is("deleted_at", null)
  ),

  // KONTEN MENUNGGU APPROVAL
  getCount(
    supabase,
    "contents",
    (query) =>
      query
        .in("status", [
          "pending_secretary",
          "pending_super_admin",
        ])
        .is("deleted_at", null)
  ),

  // PERMINTAAN AKSES
  getCount(
    supabase,
    "access_requests",
    (query) =>
      query.eq("status", "pending")
  ),

  // PENGGUNA AKTIF
  getCount(
    supabase,
    "profiles",
    (query) =>
      query
        .eq("status", "active")
        .is("deleted_at", null)
  ),
]);

  const activePeriod = activePeriodResult.data;

const { data: latestAspirations, error: latestAspirationsError } =
  await supabase
    .from("aspirations")
    .select(`
      id,
      ticket_number,
      title,
      category,
      status,
      submitted_at
    `)
    .is("deleted_at", null)
    .order("submitted_at", { ascending: false })
    .limit(5);

if (latestAspirationsError) {
  console.error(
    "Error loading latest aspirations:",
    latestAspirationsError
  );
}

const activeAspirationsCount =
  aspirationsSubmittedCount +
  aspirationsReviewCount +
  aspirationsForwardedCount +
  aspirationsFollowedUpCount;

const completionRate =
  aspirationsCount > 0
    ? Math.round(
        (aspirationsCompletedCount / aspirationsCount) * 100
      )
    : 0;

  return (
    <>
      

      <div className="notice">
        {activePeriod ? (
          <>
            Periode aktif saat ini:{" "}
            <strong>{activePeriod.name}</strong>{" "}
            ({activePeriod.year_start}–{activePeriod.year_end})
          </>
        ) : (
          <>
            Belum ada periode kepengurusan yang ditetapkan sebagai periode aktif.
          </>
        )}
      </div>

<div className="sectionHead">

  <div className="sectionHeadContent">

    <p className="eyebrow">
      Admin Panel
    </p>

 
  </div>

</div>

      {/* OVERVIEW */}
      <section className="dashboardGrid">
        <article className="statCard">
          <span className="tag">PERIODE</span>

          <h2>
            {activePeriod
              ? `${activePeriod.year_start}–${activePeriod.year_end}`
              : "Belum aktif"}
          </h2>

          <p>
            {activePeriod?.name ?? "Tidak ada periode aktif"}
          </p>
        </article>

        <article className="statCard">
          <span className="tag">ORGANISASI</span>

          <h2>{organizationsCount}</h2>

          <p>Organisasi aktif</p>
        </article>

        <article className="statCard">
          <span className="tag">D-DAS</span>

          <h2>{aspirationsCount}</h2>

          <p>Total aspirasi</p>
        </article>

        <article className="statCard">
          <span className="tag">PENGGUNA</span>

          <h2>{usersCount}</h2>

          <p>Pengguna aktif</p>
        </article>
      </section>

{/* D-DAS MONITORING */}
<section className="dashboardSection">
  <div>
    <p className="eyebrow">D-DAS Monitoring</p>

    <h2>Ringkasan Penanganan Aspirasi</h2>
  </div>

  <div className="grid">
    <article className="card">
      <span className="tag">TOTAL</span>

      <h3>{aspirationsCount}</h3>

      <p>
        Total aspirasi yang tercatat dalam sistem.
      </p>
    </article>

    <article className="card">
      <span className="tag">AKTIF</span>

      <h3>{activeAspirationsCount}</h3>

      <p>
        Aspirasi yang masih berada dalam proses penanganan.
      </p>
    </article>

    <article className="card">
      <span className="tag">SELESAI</span>

      <h3>{aspirationsCompletedCount}</h3>

      <p>
        Aspirasi yang telah menyelesaikan seluruh proses penanganan.
      </p>
    </article>

    <article className="card">
      <span className="tag">PENYELESAIAN</span>

      <h3>{completionRate}%</h3>

      <p>
        Persentase aspirasi yang telah berhasil diselesaikan.
      </p>
    </article>
  </div>
</section>


      {/* WORKFLOW */}
      <section className="dashboardSection">
        <div>
          <p className="eyebrow">Workflow</p>

          <h2>Status Operasional</h2>
        </div>

        <div className="grid">
          <article className="card">
            <span className="tag">APPROVAL</span>

            <h3>{pendingContentsCount}</h3>

            <p>
              Konten sedang menunggu proses approval.
            </p>
          </article>

          <article className="card">
            <span className="tag">D-DAS</span>

            <h3>{aspirationsReviewCount}</h3>       
            <p>
              Aspirasi sedang dalam tahap peninjauan.
            </p>
          </article>

          <article className="card">
            <span className="tag">ACCESS</span>

            <h3>{pendingAccessCount}</h3>

            <p>
              Permintaan akses dokumen yang belum diproses.
            </p>
          </article>
        </div>
      </section>

{/* QUICK ACTIONS */}
<section className="dashboardSection">
  <div>
    <p className="eyebrow">Quick Actions</p>

    <h2>Akses Cepat</h2>

    <p>
      Akses langsung ke fitur utama panel administrasi.
    </p>
  </div>

  <div className="quickActionsGrid">
    <Link
      href="/admin/aspirasi"
      className="quickActionCard"
    >
      <span className="quickActionIcon">📥</span>

      <div>
        <h3>Kelola Aspirasi</h3>

        <p>
          Tinjau, teruskan, dan pantau penanganan aspirasi mahasiswa.
        </p>
      </div>

      <span className="quickActionArrow">
        →
      </span>
    </Link>

    <Link
      href="/admin/periode-organisasi"
      className="quickActionCard"
    >
      <span className="quickActionIcon">🏢</span>

      <div>
        <h3>Kelola Organisasi</h3>

        <p>
          Kelola organisasi dan struktur kelembagaan.
        </p>
      </div>

      <span className="quickActionArrow">
        →
      </span>
    </Link>

    <Link
      href="/admin/berita"
      className="quickActionCard"
    >
      <span className="quickActionIcon">📝</span>

      <div>
        <h3>Kelola Konten</h3>

        <p>
          Tinjau dan kelola konten yang tersedia di website.
        </p>
      </div>

      <span className="quickActionArrow">
        →
      </span>
    </Link>

    <Link
      href="/admin/users"
      className="quickActionCard"
    >
      <span className="quickActionIcon">👥</span>

      <div>
        <h3>Kelola Pengguna</h3>

        <p>
          Pantau dan kelola akun pengguna sistem.
        </p>
      </div>

      <span className="quickActionArrow">
        →
      </span>
    </Link>

    <Link
      href="/admin/request-access"
      className="quickActionCard"
    >
      <span className="quickActionIcon">📄</span>

      <div>
        <h3>Permintaan Akses</h3>

        <p>
          Proses permintaan akses dokumen dan informasi.
        </p>
      </div>

      <span className="quickActionArrow">
        →
      </span>
    </Link>
  </div>
</section>

    </>
  );
}