"use client";

import Link from "next/link";

type AdminErrorProps = {
  error: Error & {
    digest?: string;
  };
  reset: () => void;
};

export default function AdminError({
  error,
  reset,
}: AdminErrorProps) {
  return (
    <div className="adminState adminErrorState">
      <div className="adminStateIcon">⚠️</div>

      <h2>Terjadi Kesalahan</h2>

      <p>
        Maaf, terjadi kesalahan saat memuat halaman ini.
        Silakan coba kembali.
      </p>

      {error.message && (
        <details className="adminErrorDetails">
          <summary>Detail Error</summary>

          <pre>{error.message}</pre>
        </details>
      )}

      <div className="adminStateActions">
        <button
          type="button"
          onClick={() => reset()}
          className="adminStateAction"
        >
          Coba Lagi
        </button>

        <Link
          href="/admin/dashboard"
          className="adminStateAction adminStateSecondaryAction"
        >
          Kembali ke Dashboard
        </Link>
      </div>
    </div>
  );
}