"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function revalidateAspirationPaths(id: string) {
  revalidatePath(`/admin/aspirasi/${id}`);
  revalidatePath("/admin/aspirasi");
  revalidatePath("/admin/dashboard");
}

async function createActivityLog({
  aspirationId,
  action,
  description,
  previousStatus,
  newStatus,
  metadata = {},
}: {
  aspirationId: string;
  action: string;
  description: string;
  previousStatus?: string | null;
  newStatus?: string | null;
  metadata?: Record<string, unknown>;
}) {
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const actorName =
    user?.user_metadata?.full_name ||
    user?.user_metadata?.name ||
    user?.email ||
    "Admin DPM FIPP";

  const { error } = await supabase
    .from("aspiration_activity_logs")
    .insert({
      aspiration_id: aspirationId,
      action,
      description,
      actor_id: user?.id ?? null,
      actor_name: actorName,
      previous_status: previousStatus ?? null,
      new_status: newStatus ?? null,
      metadata,
    });

  if (error) {
    console.error("Error creating activity log:", error);
  }
}

export async function startReview(formData: FormData) {
  const id = formData.get("id")?.toString();

  if (!id) {
    throw new Error("ID aspirasi tidak valid.");
  }

  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("aspirations")
    .update({
      status: "in_review",
      reviewed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "submitted")
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    console.error("Error starting aspiration review:", error);

    throw new Error(
      "Status aspirasi tidak dapat diperbarui. Aspirasi harus berada pada status Masuk."
    );
  }

await createActivityLog({
  aspirationId: id,
  action: "review_started",
  description: "Proses peninjauan aspirasi telah dimulai.",
  previousStatus: "submitted",
  newStatus: "in_review",
});

  revalidateAspirationPaths(id);
}

export async function forwardAspiration(formData: FormData) {
  const id = formData.get("id")?.toString();

  const organizationId = formData
    .get("organization_id")
    ?.toString();

  if (!id) {
    throw new Error("ID aspirasi tidak ditemukan.");
  }

  if (!organizationId) {
    throw new Error("Organisasi tujuan harus dipilih.");
  }

  const supabase = await createSupabaseServerClient();

  const { data: organization } = await supabase
    .from("organizations")
    .select("name, code")
    .eq("id", organizationId)
    .maybeSingle();

  const { data, error } = await supabase
    .from("aspirations")
    .update({
      status: "forwarded",
      forwarded_at: new Date().toISOString(),
      assigned_organization_id: organizationId,
    })
    .eq("id", id)
    .eq("status", "in_review")
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    console.error("Error forwarding aspiration:", error);

    throw new Error(
      "Aspirasi tidak dapat diteruskan. Pastikan aspirasi sedang dalam proses review."
    );
  }

 await createActivityLog({
  aspirationId: id,
  action: "forwarded",
  description: `Aspirasi telah diteruskan kepada ${
    organization
      ? `${organization.name} (${organization.code})`
      : "organisasi terkait"
  }.`,
  previousStatus: "in_review",
  newStatus: "forwarded",
  metadata: {
    organization_id: organizationId,
    organization_name: organization?.name ?? null,
    organization_code: organization?.code ?? null,
  },
});

  revalidateAspirationPaths(id);
}

export async function markAsFollowedUp(formData: FormData) {
  const id = formData.get("id")?.toString();

  if (!id) {
    throw new Error("ID aspirasi tidak ditemukan.");
  }

  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("aspirations")
    .update({
      status: "followed_up",
      followed_up_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "forwarded")
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    console.error(
      "Error marking aspiration as followed up:",
      error
    );

    throw new Error(
      "Aspirasi tidak dapat ditandai sebagai ditindaklanjuti."
    );
  }

 await createActivityLog({
  aspirationId: id,
  action: "followed_up",
  description:
    "Aspirasi telah ditandai sebagai ditindaklanjuti oleh pihak terkait.",
  previousStatus: "forwarded",
  newStatus: "followed_up",
});

  revalidateAspirationPaths(id);
}

export async function completeAspiration(formData: FormData) {
  const id = formData.get("id")?.toString();

  if (!id) {
    throw new Error("ID aspirasi tidak ditemukan.");
  }

  const supabase = await createSupabaseServerClient();

  const { data: aspiration, error: checkError } = await supabase
    .from("aspirations")
    .select("id, status")
    .eq("id", id)
    .is("deleted_at", null)
    .maybeSingle();

  if (checkError || !aspiration) {
    console.error("Error checking aspiration:", checkError);

    throw new Error("Aspirasi tidak ditemukan.");
  }

  if (aspiration.status !== "followed_up") {
    throw new Error(
      `Aspirasi belum dapat diselesaikan. Status saat ini: ${aspiration.status}`
    );
  }

  const { data, error: updateError } = await supabase
    .from("aspirations")
    .update({
      status: "completed",
      completed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "followed_up")
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (updateError || !data) {
    console.error("Error completing aspiration:", updateError);

    throw new Error("Gagal menyelesaikan aspirasi.");
  }

 await createActivityLog({
  aspirationId: id,
  action: "completed",
  description:
    "Proses penanganan aspirasi telah dinyatakan selesai.",
  previousStatus: "followed_up",
  newStatus: "completed",
});

  revalidateAspirationPaths(id);
}

export async function saveFollowUpNote(
  previousState: {
    success: boolean;
    message: string;
  },
  formData: FormData
) {
  const id = formData.get("id")?.toString();

  const followUpNote = formData
    .get("follow_up_note")
    ?.toString()
    .trim();

  if (!id) {
    return {
      success: false,
      message: "ID aspirasi tidak ditemukan.",
    };
  }

  const supabase = await createSupabaseServerClient();

  const { error } = await supabase
    .from("aspirations")
    .update({
      follow_up_note: followUpNote || null,
    })
    .eq("id", id)
    .is("deleted_at", null);

  if (error) {
    console.error("Gagal menyimpan catatan:", error);

    return {
      success: false,
      message: "Catatan gagal disimpan.",
    };
  }

 await createActivityLog({
  aspirationId: id,
  action: "follow_up_note_updated",
  description: followUpNote
    ? "Catatan tindak lanjut aspirasi telah diperbarui."
    : "Catatan tindak lanjut aspirasi telah dihapus.",
  metadata: {
    has_note: Boolean(followUpNote),
  },
});

  revalidateAspirationPaths(id);

  return {
    success: true,
    message: "✓ Catatan berhasil disimpan.",
  };
}