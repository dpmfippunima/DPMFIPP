"use client";

import { useState } from "react";

type MarkAllReadButtonProps = {
  action: () => Promise<
    | {
        success: false;
        error: string;
      }
    | {
        success: true;
        updatedCount: number;
      }
  >;
};

export default function MarkAllReadButton({
  action,
}: MarkAllReadButtonProps) {
  const [isLoading, setIsLoading] = useState(false);

  async function handleMarkAllRead() {
    if (isLoading) return;

    setIsLoading(true);

    try {
      const result = await action();

      if (!result.success) {
        console.error(
          "Failed to mark all notifications as read:",
          result.error
        );

        return;
      }

      console.log(
        `${result.updatedCount} notification(s) marked as read.`
      );

      window.location.reload();
    } catch (error) {
      console.error(
        "Unexpected error while marking notifications as read:",
        error
      );
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <button
      type="button"
      onClick={handleMarkAllRead}
      disabled={isLoading}
      className="adminButton adminButtonSecondary"
    >
      {isLoading
        ? "Memproses..."
        : "Tandai Semua Dibaca"}
    </button>
  );
}