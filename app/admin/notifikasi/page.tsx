import Link from "next/link";
import MarkAllReadButton from "./MarkAllReadButton";
import NotificationLink from "./NotificationLink";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function formatDate(date: string) {
  return new Intl.DateTimeFormat("id-ID", {
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(date));
}

function getNotificationIcon(type: string) {
  const icons: Record<string, string> = {
    new_aspiration: "📨",
    aspiration_update: "📋",
    content_approval: "📝",
    access_request: "🔐",
    system: "🔔",
  };

  return icons[type] ?? "🔔";
}

export default async function NotificationsPage() {
  const supabase = await createSupabaseServerClient();

  const { data: notifications, error } = await supabase
    .from("admin_notifications")
    .select(`
      id,
      type,
      title,
      message,
      href,
      is_read,
      created_at
    `)
    .order("created_at", {
      ascending: false,
    });

  if (error) {
    console.error(
      "Error loading admin notifications:",
      error
    );
  }

  return (
    <>
      <div className="sectionHead">

  <div className="sectionHeadContent">

    <p className="eyebrow">
      Admin Panel
    </p>

    <h1>
      Notifikasi
    </h1>

    <p className="sectionDescription">
      Pantau aktivitas terbaru dan pembaruan
      yang membutuhkan perhatian.
    </p>

  </div>


  <div className="sectionHeadActions">
    <MarkAllReadButton action={async () => {
      "use server";
      const supabase = await createSupabaseServerClient();
      const { count, error } = await supabase
        .from("admin_notifications")
        .update({ is_read: true })
        .eq("is_read", false);

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, updatedCount: count || 0 };
    }} />
  </div>

</div>

      {!notifications || notifications.length === 0 ? (
        <div className="emptyNotifications">
          <div className="emptyNotificationsIcon">
            🔔
          </div>

          <h2>Belum Ada Notifikasi</h2>

          <p>
            Saat ini belum ada aktivitas baru yang
            membutuhkan perhatian Anda.
          </p>
        </div>
      ) : (
        <div className="notificationsList">
          
          {notifications.map((notification) => (
  <NotificationLink
    key={notification.id}
    id={notification.id}
    href={notification.href}
    className={`notificationItem ${
      notification.is_read
        ? "notificationRead"
        : "notificationUnread"
    }`}
  >
    <div className="notificationContent">
      <h3>{notification.title}</h3>

      <p>{notification.message}</p>

      <span className="notificationDate">
        {formatDate(notification.created_at)}
      </span>
    </div>
  </NotificationLink>
))}
        </div>
      )}
    </>
  );
}