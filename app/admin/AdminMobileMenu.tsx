"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

type AdminMobileMenuProps = {
  items: string[];
  hrefs: Record<string, string>;
  labels: Record<string, string>;
  userName: string | null;
};

export default function AdminMobileMenu({
  items,
  hrefs,
  labels,
  userName,
}: AdminMobileMenuProps) {
  const pathname = usePathname();

  const [isOpen, setIsOpen] = useState(false);

  const closeMenu = () => {
    setIsOpen(false);
  };

  /* Tutup menu ketika berpindah halaman */

  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  return (
    <div className="adminMobileMenu">

      {/* HAMBURGER BUTTON */}

      <button
        type="button"
        className="mobileMenuButton"
        onClick={() => setIsOpen((previous) => !previous)}
        aria-label="Buka menu navigasi"
        aria-expanded={isOpen}
      >
        <span
          className={`hamburgerIcon ${
            isOpen ? "hamburgerIconOpen" : ""
          }`}
        >
          <span />
          <span />
          <span />
        </span>
      </button>


      {/* BACKDROP */}

      {isOpen && (
        <button
          type="button"
          className="mobileMenuBackdrop"
          onClick={closeMenu}
          aria-label="Tutup menu"
        />
      )}


      {/* MOBILE MENU */}

      <aside
        className={`mobileMenuPanel ${
          isOpen ? "mobileMenuPanelOpen" : ""
        }`}
      >

        {/* HEADER */}

        <div className="mobileMenuHeader">

          <div>

            <strong>
              DPM FIPP
            </strong>

            <span>
              ADMIN
            </span>

          </div>


          <button
            type="button"
            className="mobileMenuClose"
            onClick={closeMenu}
            aria-label="Tutup menu"
          >
            ×
          </button>

        </div>


        {/* USER */}

        {userName && (
          <div className="mobileMenuUser">
            {userName}
          </div>
        )}


        {/* NAVIGATION */}

        <nav className="mobileMenuNavigation">

          {items.map((item) => {
            const href =
              hrefs[item] || `/admin/${item}`;

            const isActive =
              pathname === href ||
              pathname.startsWith(`${href}/`);

            return (
              <Link
                key={item}
                href={href}
                onClick={closeMenu}
                className={
                  isActive
                    ? "mobileMenuLink mobileMenuLinkActive"
                    : "mobileMenuLink"
                }
              >
                {labels[item] || item}
              </Link>
            );
          })}

        </nav>


        {/* PUBLIC PORTAL */}

        <Link
          href="/"
          className="mobilePublicPortal"
          onClick={closeMenu}
        >
          ← Portal Publik
        </Link>

      </aside>

    </div>
  );
}