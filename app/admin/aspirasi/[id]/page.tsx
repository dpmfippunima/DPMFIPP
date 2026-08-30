import Link from "next/link";
import { notFound } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { startReview, forwardAspiration, markAsFollowedUp, completeAspiration, saveFollowUpNote } from "./actions";
import { FollowUpForm } from "./follow-up-form";

function formatDate(date: string | null) {
  if (!date) return "-";

  return new Intl.DateTimeFormat("id-ID", {
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(date));
}

function formatCategory(category: string) {
  const labels: Record<string, string> = {
    academic: "Akademik",
    facility: "Fasilitas",
    organization: "Organisasi",
    policy: "Kebijakan",
    advocacy: "Advokasi",
    sexual_harassment: "Pelecehan Seksual",
    corruption: "Korupsi",
    bullying: "Perundungan",
    abuse_of_authority: "Penyalahgunaan Wewenang",
    serious_ethics_violation: "Pelanggaran Etik Serius",
    violence: "Kekerasan",
    other: "Lainnya",
  };

  return labels[category] ?? category;
}

function formatStatus(status: string) {
  const labels: Record<string, string> = {
    submitted: "Masuk",
    in_review: "Sedang Ditinjau",
    forwarded: "Diteruskan",
    followed_up: "Ditindaklanjuti",
    completed: "Selesai",
    rejected: "Ditolak",
    archived: "Diarsipkan",
  };

  return labels[status] ?? status;
}

function getActivityIcon(action: string) {
  const icons: Record<string, string> = {
    review_started: "🔍",
    forwarded: "📤",
    followed_up: "✓",
    completed: "🎉",
    follow_up_note_updated: "📝",
  };

  return icons[action] ?? "•";
}

function formatLogStatus(status: string | null) {
  if (!status) return null;

  return formatStatus(status);
}

export default async function AspirationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const supabase = await createSupabaseServerClient();

  const { data: aspiration, error } = await supabase
    .from("aspirations")
    .select(`
      id,
      ticket_number,
      title,
      description,
      category,
      status,
      is_anonymous,
      sender_name,
      sender_email,
      sender_phone,
      otp_verified,
      submitted_at,
      reviewed_at,
      forwarded_at,
      followed_up_at,
      completed_at,
      follow_up_note,
      assigned_organization_id,
      assigned_organization:organizations (id, name, code)
`)
    .eq("id", id)
    .is("deleted_at", null)
    .maybeSingle();

  if (error) {
    console.error("Error loading aspiration:", error);
  }

  if (!aspiration) {
    notFound();
  }

console.log("CURRENT ASPIRATION STATUS:", aspiration.status);

  const { data: organizations, error: organizationsError } = await supabase
  .from("organizations")
  .select("id,name,code")
  .eq("status", "active")
  .is("deleted_at", null)
  .order("name");

if (organizationsError) {
  console.error(
    "Error loading organizations:",
    organizationsError
  );
}

const { data: activityLogs, error: activityLogsError } =
  await supabase
    .from("aspiration_activity_logs")
    .select(`
  id,
  action,
  description,
  actor_name,
  previous_status,
  new_status,
  metadata,
  created_at
`)
    .eq("aspiration_id", aspiration.id)
    .order("created_at", { ascending: false });

if (activityLogsError) {
  console.error(
    "Error loading aspiration activity logs:",
    activityLogsError
  );
}

const timelineSteps = [
  {
    key: "submitted",
    title: "Aspirasi Masuk",
    description:
      "Aspirasi telah berhasil diterima oleh sistem.",
    date: aspiration.submitted_at,
  },
  {
    key: "in_review",
    title: "Sedang Ditinjau",
    description:
      "Aspirasi sedang ditinjau oleh DPM FIPP.",
    date: aspiration.reviewed_at,
  },
  {
    key: "forwarded",
    title: "Diteruskan",
    description:
      "Aspirasi telah diteruskan kepada organisasi atau pihak terkait.",
    date: aspiration.forwarded_at,
  },
  {
  key: "followed_up",
  title: "Ditindaklanjuti",
  description:
    "Aspirasi sedang atau telah mendapatkan tindak lanjut dari pihak terkait.",
  date: aspiration.followed_up_at,
},
  {
    key: "completed",
    title: "Selesai",
    description:
      "Proses penanganan aspirasi telah dinyatakan selesai.",
    date: aspiration.completed_at,
  },
];

const getTimelineState = (stepIndex: number) => {
  const statusProgress: Record<string, number> = {
    submitted: 0,
    in_review: 1,
    forwarded: 2,
    followed_up: 3,
    completed: 4,
  };

  const currentProgress =
    statusProgress[aspiration.status] ?? 0;

  if (
    aspiration.status === "rejected" ||
    aspiration.status === "archived"
  ) {
    return "inactive";
  }

  // Jika aspirasi sudah selesai,
  // semua tahap dianggap completed
  if (aspiration.status === "completed") {
    return "completed";
  }

  if (stepIndex < currentProgress) {
    return "completed";
  }

  if (stepIndex === currentProgress) {
    return "current";
  }

  return "pending";
};


  return (
    <>
      <Link href="/admin/aspirasi">
        ← Kembali ke daftar aspirasi
      </Link>

      <div style={{ marginTop: "24px" }}>
        <p className="eyebrow">D-DAS / Detail Aspirasi</p>

        <h1>{aspiration.title}</h1>
        </div>

        <div className="notice">
  <strong>{aspiration.ticket_number}</strong>
  {" · "}
  {formatStatus(aspiration.status)}
</div>

{aspiration.status === "submitted" && (
  <form action={startReview} style={{ marginTop: "16px" }}>
    <input type="hidden" name="id" value={aspiration.id} />

    <button type="submit" className="button">
      Mulai Review
    </button>
  </form>
)}

{aspiration.status === "in_review" && (
  
  
  <section className="dashboardSection">
    <div>
      <p className="eyebrow">Penugasan</p>


      <h2>Teruskan ke Organisasi</h2>
    </div>

    <article className="card">
      <form action={forwardAspiration} className="form">
        <input
          type="hidden"
          name="id"
          value={aspiration.id}
        />

        <label>
          Organisasi tujuan

          <select
            name="organization_id"
            required
            defaultValue=""
          >
            <option value="" disabled>
              Pilih organisasi tujuan
            </option>

            {organizations?.map((organization) => (
              <option
                key={organization.id}
                value={organization.id}
              >
                {organization.name} ({organization.code})
              </option>
            ))}
          </select>
        </label>

        <button
          type="submit"
          className="button"
        >
          Teruskan Aspirasi
        </button>
      </form>
    </article>
  </section>
)}

{aspiration.assigned_organization && (
  <section className="dashboardSection">
    <div>
      <p className="eyebrow">Penugasan</p>

      <h2>Organisasi Tujuan</h2>
    </div>

    <article className="card">
      <span className="tag">
        ORGANISASI PENANGGUNG JAWAB
      </span>

      <h3>
        {aspiration.assigned_organization.name}
      </h3>

      <p>
        {aspiration.assigned_organization.code}
      </p>
    </article>
  </section>
)}

{aspiration.status === "forwarded" && (
  <form
    action={markAsFollowedUp}
    style={{ marginTop: "16px" }}
  >
    <input
      type="hidden"
      name="id"
      value={aspiration.id}
    />

    <button type="submit" className="button">
      ✓ Tandai sebagai Ditindaklanjuti
    </button>
  </form>
)}

{aspiration.status === "followed_up" && (
  <form
    action={completeAspiration}
    style={{ marginTop: "16px" }}
  >
    <input
      type="hidden"
      name="id"
      value={aspiration.id}
    />

    <button type="submit" className="button">
      ✓ Selesaikan Aspirasi
    </button>
  </form>
)}

      <section className="dashboardSection">
        <div className="grid">
          <article className="card">
            <span className="tag">KATEGORI</span>

            <h3>{formatCategory(aspiration.category)}</h3>
          </article>

          <article className="card">
            <span className="tag">STATUS</span>

            <h3>{formatStatus(aspiration.status)}</h3>
          </article>

          <article className="card">
            <span className="tag">DIKIRIM</span>

            <h3>{formatDate(aspiration.submitted_at)}</h3>
          </article>
        </div>
      </section>

      <section className="dashboardSection">
        <div>
          <p className="eyebrow">Isi Aspirasi</p>

          <h2>Deskripsi</h2>
        </div>

        <article className="card">
          <p style={{ whiteSpace: "pre-wrap" }}>
            {aspiration.description}
          </p>
        </article>
      </section>

<section className="dashboardSection">
  <div>
    <p className="eyebrow">Tindak Lanjut</p>

    <h2>Catatan Penanganan</h2>
  </div>

<FollowUpForm
  aspirationId={aspiration.id}
  defaultNote={aspiration.follow_up_note}
/>
</section>

      <section className="dashboardSection">
        <div>
          <p className="eyebrow">Informasi Pengirim</p>

          <h2>Identitas</h2>
        </div>

        {aspiration.is_anonymous ? (
          <div className="notice">
            Aspirasi ini dikirim secara anonim.
          </div>
        ) : (
          <div className="grid">
            <article className="card">
              <span className="tag">NAMA</span>

              <h3>{aspiration.sender_name || "-"}</h3>
            </article>

            <article className="card">
              <span className="tag">EMAIL</span>

              <h3>{aspiration.sender_email || "-"}</h3>
            </article>

            <article className="card">
              <span className="tag">TELEPON</span>

              <h3>{aspiration.sender_phone || "-"}</h3>
            </article>
          </div>
        )}
      </section>

{/* RIWAYAT AKTIVITAS */}
<section className="dashboardSection">
  <div>
    <p className="eyebrow">Riwayat Aktivitas</p>
    <h2>Aktivitas Penanganan</h2>
  </div>

<div className="activityLog">
  {!activityLogs || activityLogs.length === 0 ? (
    <div className="notice">
      Belum ada riwayat aktivitas untuk aspirasi ini.
    </div>
  ) : (
    activityLogs.map((log) => (
      <article
        key={log.id}
        className="activityLogItem"
      >
        <div className="activityLogIcon">
          {getActivityIcon(log.action)}
        </div>

        <div className="activityLogContent">
          <p>{log.description}</p>

          <div className="activityLogMeta">
            {log.actor_name && (
              <span>
                👤 {log.actor_name}
              </span>
            )}

            {log.previous_status &&
              log.new_status && (
                <span>
                  {formatLogStatus(log.previous_status)}
                  {" → "}
                  {formatLogStatus(log.new_status)}
                </span>
              )}
          </div>

          <span className="activityLogDate">
            {formatDate(log.created_at)}
          </span>
        </div>
      </article>
    ))
  )}
</div></section>


{/* TIMELINE STATUS */}
<section className="dashboardSection">
  <div>
    <p className="eyebrow">Timeline</p>
    <h2>Status Aspirasi</h2>
  </div>

  <div className="aspirationTimeline">
    {timelineSteps.map((step, index) => {
      const state = getTimelineState(index);

      return (
        <div
          key={step.key}
          className={`timelineItem timeline-${state}`}
        >
          <div className="timelineIndicator">
            <div className="timelineDot">
              {state === "completed"
                ? "✓"
                : index + 1}
            </div>

            {index < timelineSteps.length - 1 && (
              <div className="timelineLine" />
            )}
          </div>

          <div className="timelineContent">
            <div className="timelineHeader">
              <h3>{step.title}</h3>

              <span
                className={`timelineStatus timelineStatus-${state}`}
              >
                {state === "completed"
                  ? "Selesai"
                  : state === "current"
                  ? "Sedang Diproses"
                  : state === "inactive"
                  ? "Tidak Aktif"
                  : "Menunggu"}
              </span>
            </div>

            <p>{step.description}</p>

            <span className="timelineDate">
              {formatDate(step.date)}
            </span>
          </div>
        </div>
      );
    })}
  </div>
</section>
    </>
  );
}