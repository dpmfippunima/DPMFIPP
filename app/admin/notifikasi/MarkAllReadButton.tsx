"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { markAllNotificationsAsRead } from "./actions";

export default function MarkAllReadButton() {
  const router = useRouter();

  const [isLoading, setIsLoading] = useState(false);

  async function handleMarkAllRead() {
    if (isLoading) return;

    setIsLoading(true);

    try {
      const result = await markAllNotificationsAsRead();

      console.log(
        "Mark all notifications result:",
        result
      );

      if (!result.success) {
        console.error(
          "Failed to mark all notifications as read:",
          result.message
        );

        return;
      }

      router.refresh();
    } catch (error) {
      console.error(
        "Error marking all notifications as read:",
        error
      );
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <button
      type="button"
      className="markAllReadButton"
      onClick={handleMarkAllRead}
      disabled={isLoading}
    >
      {isLoading
        ? "Memproses..."
        : "Tandai Semua Dibaca"}
    </button>
  );
}