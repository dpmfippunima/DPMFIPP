"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

interface AdminSidebarNavProps {
  items: string[];
  labels: Record<string, string>;
  hrefs: Record<string, string>;
}

export default function AdminSidebarNav({
  items,
  labels,
  hrefs,
}: AdminSidebarNavProps) {
  const pathname = usePathname();

  return (
    <nav className="adminSidebarNav">
      {items.map((item) => {
        const href = hrefs[item] || `/admin/${item}`;

        const isActive =
          pathname === href ||
          pathname.startsWith(`${href}/`);

        return (
          <Link
            key={item}
            href={href}
            className={`adminNavItem ${
              isActive ? "adminNavItemActive" : ""
            }`}
          >
            {labels[item] || item}
          </Link>
        );
      })}
    </nav>
  );
}