"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function markNotificationAsRead(
  notificationId: string
) {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("admin_notifications")
    .update({
      is_read: true,
    })
    .eq("id", notificationId)
    .select("id, is_read");

  console.log("Single notification update:", {
    data,
    error,
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/admin", "layout");
  revalidatePath("/admin/notifikasi");

  return {
    success: true,
    updated: data?.length ?? 0,
  };
}

export async function markAllNotificationsAsRead() {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("admin_notifications")
    .update({
      is_read: true,
    })
    .eq("is_read", false)
    .select("id, is_read");

  console.log("Mark all notifications result:", {
    data,
    error,
  });

  if (error) {
    return {
      success: false,
      error: error.message,
    };
  }

  revalidatePath("/admin", "layout");
  revalidatePath("/admin/notifikasi");

  return {
    success: true,
    updatedCount: data?.length ?? 0,
  };
}