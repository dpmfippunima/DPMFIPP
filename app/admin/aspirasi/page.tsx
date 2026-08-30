import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function formatDate(date: string) {
  return new Intl.DateTimeFormat("id-ID", {
    day: "numeric",
    month: "short",
    year: "numeric",
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
    in_review: "Ditinjau",
    forwarded: "Diteruskan",
    followed_up: "Ditindaklanjuti",
    completed: "Selesai",
    rejected: "Ditolak",
    archived: "Diarsipkan",
  };

  return labels[status] ?? status;
}

const statuses = [
  { value: "", label: "Semua Status" },
  { value: "submitted", label: "Masuk" },
  { value: "in_review", label: "Ditinjau" },
  { value: "forwarded", label: "Diteruskan" },
  { value: "followed_up", label: "Ditindaklanjuti" },
  { value: "completed", label: "Selesai" },
  { value: "rejected", label: "Ditolak" },
  { value: "archived", label: "Diarsipkan" },
];

const categories = [
  { value: "", label: "Semua Kategori" },
  { value: "academic", label: "Akademik" },
  { value: "facility", label: "Fasilitas" },
  { value: "organization", label: "Organisasi" },
  { value: "policy", label: "Kebijakan" },
  { value: "advocacy", label: "Advokasi" },
  { value: "sexual_harassment", label: "Pelecehan Seksual" },
  { value: "corruption", label: "Korupsi" },
  { value: "bullying", label: "Perundungan" },
  { value: "abuse_of_authority", label: "Penyalahgunaan Wewenang" },
  {
    value: "serious_ethics_violation",
    label: "Pelanggaran Etik Serius",
  },
  { value: "violence", label: "Kekerasan" },
  { value: "other", label: "Lainnya" },
];

export default async function AspirasiPage({
  searchParams,
}: {
  searchParams: Promise<{
    status?: string;
    category?: string;
  }>;
}) {
  const { status, category } = await searchParams;

  const supabase = await createSupabaseServerClient();

  let query = supabase
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
      completed_at,
      follow_up_note,
      assigned_organization_id,
      assigned_organization:organizations (
        id,
        name,
        code
      )
    `)
    .is("deleted_at", null)
    .order("submitted_at", {
      ascending: false,
    });

  if (status) {
    query = query.eq("status", status);
  }

  if (category) {
    query = query.eq("category", category);
  }

  const { data: aspirations, error } = await query;

  if (error) {
    console.error(
      "Error loading aspirations:",
      error
    );
  }

  return (
    <>
      <p className="eyebrow">
        Admin Panel / D-DAS
      </p>

      <h1>Aspirasi Mahasiswa</h1>

      <div className="notice">
        Kelola aspirasi yang masuk, lakukan peninjauan,
        dan pantau perkembangan tindak lanjutnya.
      </div>

      <div className="sectionHead">
  <div>
    <p className="eyebrow">
      Daftar Aspirasi
    </p>

    <h2>
      {aspirations?.length ?? 0} Aspirasi
    </h2>

    {(status || category) && (
      <p className="activeFilterText">
        Menampilkan hasil berdasarkan filter yang dipilih
      </p>
    )}
  </div>

  <form
    className="filterGroup"
    method="GET"
  >
          
            <div className="filterItem">
              <label htmlFor="status-filter">
                Status
              </label>

              <select
                id="status-filter"
                name="status"
                className="filterSelect"
                defaultValue={status ?? ""}
              >
                {statuses.map((item) => (
                  <option
                    key={item.value}
                    value={item.value}
                  >
                    {item.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="filterItem">
              <label htmlFor="category-filter">
                Kategori
              </label>

              <select
                id="category-filter"
                name="category"
                className="filterSelect"
                defaultValue={category ?? ""}
              >
                {categories.map((item) => (
                  <option
                    key={item.value}
                    value={item.value}
                  >
                    {item.label}
                  </option>
                ))}
              </select>
            </div>

            <button
  type="submit"
  className="filterButton"
>
  <span>Terapkan Filter</span>
  <span className="filterButtonIcon">→</span>
</button>

            {(status || category) && (
              <Link
                href="/admin/aspirasi"
                className="filterReset"
              >
                Reset
              </Link>
            )}
          </form>
        </div>

        {!aspirations || aspirations.length === 0 ? (
          <div className="notice">
            Tidak ada aspirasi yang sesuai dengan filter.
          </div>
        ) : (
          <div className="adminTableWrapper">
            <table className="adminTable">
              <thead>
                <tr>
                  <th>Tiket</th>
                  <th>Judul</th>
                  <th>Kategori</th>
                  <th>Status</th>
                  <th>Pengirim</th>
                  <th>Tanggal</th>
                  <th></th>
                </tr>
              </thead>

              <tbody>
                {aspirations.map((aspiration) => (
                  <tr key={aspiration.id}>
                    <td>
                      <strong>
                        {aspiration.ticket_number}
                      </strong>
                    </td>

                    <td>
                      {aspiration.title}
                    </td>

                    <td>
  <span
    className={`categoryBadge category-${aspiration.category}`}
  >
    {formatCategory(aspiration.category)}
  </span>
</td>

                    <td>
                      <span
                        className={`statusBadge status-${aspiration.status}`}
                      >
                        {formatStatus(
                          aspiration.status
                        )}
                      </span>
                    </td>

                   <td>
  <span
    className={`senderBadge ${
      aspiration.is_anonymous
        ? "sender-anonymous"
        : "sender-identified"
    }`}
  >
    {aspiration.is_anonymous
      ? "Anonim"
      : "Teridentifikasi"}
  </span>
</td>

                    <td>
                      {formatDate(
                        aspiration.submitted_at
                      )}
                    </td>

                    <td>
                      <Link
                        href={`/admin/aspirasi/${aspiration.id}`}
                      >
                        Detail →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </>
  );
}