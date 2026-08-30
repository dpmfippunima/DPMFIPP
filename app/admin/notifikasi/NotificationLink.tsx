"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { markNotificationAsRead } from "./actions";

interface NotificationLinkProps {
  id: string;
  href: string;
  children: React.ReactNode;
  className?: string;
}

export default function NotificationLink({
  id,
  href,
  children,
  className,
}: NotificationLinkProps) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);

  async function handleClick(
    event: React.MouseEvent<HTMLAnchorElement>
  ) {
    event.preventDefault();

    if (isLoading) return;

    setIsLoading(true);

    try {
      const result = await markNotificationAsRead(id);

      console.log(
        "Mark notification result:",
        result
      );

      if (!result.success) {
        console.error(
          "Notification update failed:",
        );
      }

      router.push(href);
    } catch (error) {
      console.error(
        "Error opening notification:",
        error
      );

      router.push(href);
    }
  }

  return (
    <a
      href={href}
      className={className}
      onClick={handleClick}
      aria-busy={isLoading}
    >
      {children}
    </a>
  );
}