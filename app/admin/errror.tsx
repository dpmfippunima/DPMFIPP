"use client";

export default function AdminError({
  reset,
}: {
  error: Error & {
    digest?: string;
  };

  reset: () => void;
}) {
  return (
    <div className="adminError">
      <div className="adminErrorIcon">
        ⚠️
      </div>

      <h2>Terjadi Kesalahan</h2>

      <p>
        Sistem mengalami masalah saat memuat halaman.
        Silakan coba kembali beberapa saat lagi.
      </p>

      <button
        type="button"
        className="adminErrorAction"
        onClick={() => reset()}
      >
        Coba Lagi
      </button>
    </div>
  );
}

<div className="adminState">
  <div className="adminStateIcon">
    🔍
  </div>

  <h2>Data Tidak Ditemukan</h2>

  <p>
    Tidak ada data yang sesuai dengan
    filter yang sedang digunakan.
  </p>

  <Link
    href="/admin/aspirasi"
    className="adminStateAction"
  >
    Reset Filter
  </Link>
</div>