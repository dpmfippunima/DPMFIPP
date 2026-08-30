"use client";

import { useState } from "react";

const categories = [
  { value: "academic", label: "Akademik" },
  { value: "facility", label: "Fasilitas" },
  { value: "organization", label: "Organisasi" },
  { value: "policy", label: "Kebijakan" },
  { value: "advocacy", label: "Advokasi" },
  { value: "bullying", label: "Perundungan" },
  { value: "other", label: "Lainnya" },
];

export default function AspirationForm() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();

    setLoading(true);
    setError(null);
    setResult(null);

    const formData = new FormData(event.currentTarget);

    const payload = {
      title: formData.get("title"),
      category: formData.get("category"),
      description: formData.get("description"),
      sender_name: formData.get("sender_name"),
      sender_email: formData.get("sender_email"),
    };

    try {
      const response = await fetch("/api/aspirations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(
          data.error || "Terjadi kesalahan saat mengirim aspirasi."
        );
      }

      setResult(data.ticket_number);
      event.currentTarget.reset();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan."
      );
    } finally {
      setLoading(false);
    }
  }

  if (result) {
    return (
      <div className="formResult">
        <p className="eyebrow">Aspirasi berhasil dikirim</p>

        <h2>Terima kasih.</h2>

        <p>
          Simpan nomor tiket berikut untuk melacak perkembangan aspirasi kamu.
        </p>

        <strong className="ticketNumber">
          {result}
        </strong>

        <button
          className="button"
          onClick={() => setResult(null)}
        >
          Kirim aspirasi lain
        </button>
      </div>
    );
  }

  return (
    <form className="form aspirationForm" onSubmit={handleSubmit}>
      <label>
        Judul Aspirasi
        <input
          name="title"
          required
          minLength={5}
          placeholder="Tuliskan inti aspirasi"
        />
      </label>

      <label>
        Kategori
        <select name="category" required defaultValue="">
          <option value="" disabled>
            Pilih kategori
          </option>

          {categories.map((category) => (
            <option
              key={category.value}
              value={category.value}
            >
              {category.label}
            </option>
          ))}
        </select>
      </label>

      <label>
        Aspirasi
        <textarea
          name="description"
          required
          minLength={20}
          rows={7}
          placeholder="Jelaskan aspirasi kamu secara jelas dan lengkap"
        />
      </label>

      <label>
        Nama
        <input
          name="sender_name"
          required
          placeholder="Nama lengkap"
        />
      </label>

      <label>
        Email
        <input
          name="sender_email"
          type="email"
          required
          placeholder="nama@email.com"
        />
      </label>

      {error && (
        <div className="error">
          {error}
        </div>
      )}

      <button
        className="button"
        type="submit"
        disabled={loading}
      >
        {loading
          ? "Mengirim..."
          : "Kirim Aspirasi"}
      </button>
    </form>
  );
}