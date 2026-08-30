import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

const allowedCategories = [
  "academic",
  "facility",
  "organization",
  "policy",
  "advocacy",
  "bullying",
  "other",
];

function generateTicketNumber() {
  const date = new Date();

  const year = date.getFullYear();
  const random = crypto.randomUUID()
    .replace(/-/g, "")
    .slice(0, 8)
    .toUpperCase();

  return `DPM-${year}-${random}`;
}

export async function POST(request: Request) {
  try {
    const body = await request.json();

    const {
      title,
      category,
      description,
      sender_name,
      sender_email,
    } = body;

    // ==========================================
    // VALIDASI
    // ==========================================

    if (
      typeof title !== "string" ||
      title.trim().length < 5
    ) {
      return NextResponse.json(
        {
          error: "Judul aspirasi minimal 5 karakter.",
        },
        { status: 400 }
      );
    }

    if (!allowedCategories.includes(category)) {
      return NextResponse.json(
        {
          error: "Kategori aspirasi tidak valid.",
        },
        { status: 400 }
      );
    }

    if (
      typeof description !== "string" ||
      description.trim().length < 20
    ) {
      return NextResponse.json(
        {
          error: "Aspirasi minimal 20 karakter.",
        },
        { status: 400 }
      );
    }

    if (
      typeof sender_name !== "string" ||
      sender_name.trim().length < 2
    ) {
      return NextResponse.json(
        {
          error: "Nama harus diisi.",
        },
        { status: 400 }
      );
    }

    if (
      typeof sender_email !== "string" ||
      !sender_email.includes("@")
    ) {
      return NextResponse.json(
        {
          error: "Email tidak valid.",
        },
        { status: 400 }
      );
    }

    // ==========================================
    // SUPABASE SERVER CLIENT
    // ==========================================

    const supabaseUrl =
      process.env.NEXT_PUBLIC_SUPABASE_URL;

    const serviceRoleKey =
      process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !serviceRoleKey) {
      console.error(
        "Supabase server environment variables belum lengkap."
      );

      return NextResponse.json(
        {
          error: "Konfigurasi server belum lengkap.",
        },
        { status: 500 }
      );
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // ==========================================
    // CARI PERIODE AKTIF
    // ==========================================

    const { data: activePeriod, error: periodError } =
      await supabase
        .from("periods")
        .select("id")
        .eq("is_active", true)
        .single();

    if (periodError || !activePeriod) {
      console.error("Active period error:", periodError);

      return NextResponse.json(
        {
          error:
            "Belum ada periode kepengurusan aktif.",
        },
        { status: 400 }
      );
    }

    // ==========================================
    // BUAT TICKET NUMBER
    // ==========================================

    const ticketNumber = generateTicketNumber();

    // ==========================================
    // SIMPAN ASPIRASI
    // ==========================================

    const { data: aspiration, error: insertError } =
      await supabase
        .from("aspirations")
        .insert({
          period_id: activePeriod.id,

          ticket_number: ticketNumber,

          title: title.trim(),

          description: description.trim(),

          category,

          is_anonymous: false,

          sender_name: sender_name.trim(),

          sender_email: sender_email.trim(),

          otp_verified: false,

          status: "submitted",
        })
        .select("id, ticket_number")
        .single();

    if (insertError) {
      console.error(
        "Error inserting aspiration:",
        insertError
      );

      return NextResponse.json(
        {
          error:
            "Gagal menyimpan aspirasi. Silakan coba lagi.",
        },
        { status: 500 }
      );
    }

// 🔔 BUAT NOTIFIKASI ADMIN
const { error: notificationError } = await supabase
  .from("admin_notifications")
  .insert({
    type: "new_aspiration",
    title: "Aspirasi Baru Masuk",
    message: `Aspirasi "${aspiration.title}" membutuhkan peninjauan.`,
    href: `/admin/aspirasi/${aspiration.id}`,
  });

if (notificationError) {
  console.error(
    "Error creating admin notification:",
    notificationError
  );
}

    return NextResponse.json(
      {
        success: true,
        id: aspiration.id,
        ticket_number: aspiration.ticket_number,
      },
      { status: 201 }
    );
  } catch (error) {
    console.error("Aspiration API error:", error);

    return NextResponse.json(
      {
        error:
          "Terjadi kesalahan pada server.",
      },
      { status: 500 }
    );
  }
}