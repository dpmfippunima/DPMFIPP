import type { AppRole, Visibility } from "@/lib/types";

export type Action = "read" | "create" | "update" | "submit" | "approve" | "publish" | "archive" | "manage";

export function can(role: AppRole, action: Action, visibility: Visibility = "internal") {
  if (role === "super_admin") return true;
  if (role === "viewer") return action === "read" && visibility !== "internal";
  if (role === "secretary") return ["read", "create", "update", "approve", "publish", "archive"].includes(action);
  return ["read", "create", "update", "submit"].includes(action);
}

/** UI hint only. Database RLS and service-layer checks remain authoritative. */
export function adminNavigation(role: AppRole) {
  const base = ["dashboard", "aspirasi", "kajian", "monitoring", "laporan", "program-kerja", "berita", "survei", "media"];
  if (role === "viewer") return ["dashboard", "access/requests"];
  if (role === "super_admin") return [...base, "workflow/approval", "access/requests", "organization/periods", "users", "audit-log"];
  return [...base, "workflow/approval"];
}
