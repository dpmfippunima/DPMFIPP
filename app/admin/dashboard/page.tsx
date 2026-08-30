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

export default async function AdminDashboard() {
  const supabase = await createSupabaseServerClient();

  const [
    activePeriodResult,
    organizationsCount,
    aspirationsCount,
    aspirationsReviewCount,
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

    getCount(
      supabase,
      "aspirations",
      (query) =>
        query.is("deleted_at", null)
    ),

    getCount(
      supabase,
      "aspirations",
      (query) =>
        query
          .eq("status", "in_review")
          .is("deleted_at", null)
    ),

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

    getCount(
      supabase,
      "access_requests",
      (query) =>
        query.eq("status", "pending")
    ),

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

  return (
    <>
      <p className="eyebrow">Admin Panel</p>

      <h1>Dashboard</h1>

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
    </>
  );
}