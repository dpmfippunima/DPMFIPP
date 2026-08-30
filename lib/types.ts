export type AppRole =
  | "super_admin"
  | "chairperson"
  | "secretary"
  | "commission"
  | "viewer";
export type Visibility = "public" | "restricted" | "internal";
export type WorkflowStatus =
  | "draft"
  | "pending_secretary"
  | "pending_super_admin"
  | "approved"
  | "revision"
  | "rejected"
  | "published"
  | "archived";

export type PublicContent = {
  id: string;
  slug: string;
  title: string;
  type: string;
  excerpt: string | null;
  featured_image_path: string | null;
  published_at: string | null;
};

export type Profile = {
  id: string;
  full_name: string;
  role: AppRole;
  status: "invited" | "active" | "inactive" | "suspended";
  period_id: string | null;
  organization_id: string | null;
};
