import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { PublicContent } from "@/lib/types";

export async function getPublishedContent(type?: string): Promise<PublicContent[]> {
  const supabase = await createSupabaseServerClient();
  let query = supabase
    .from("contents")
    .select("id,slug,title,type,excerpt,featured_image_path,published_at")
    .eq("status", "published")
    .is("deleted_at", null)
    .order("published_at", { ascending: false })
    .limit(24);
  if (type) query = query.eq("type", type);
  const { data, error } = await query;
  if (error) return [];
  return data ?? [];
}

export async function getActiveOrganizations() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("organizations")
    .select("id,name,code,description,logo_path,period_id")
    .eq("status", "active")
    .is("deleted_at", null)
    .order("name")
    .limit(100);
  if (error) return [];
  return data ?? [];
}
