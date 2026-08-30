import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@supabase/supabase-js";

export async function GET(request: NextRequest) {
  const secret = request.headers.get("authorization")?.replace("Bearer ", "");
  if (!process.env.CRON_SECRET || secret !== process.env.CRON_SECRET) {
    return NextResponse.json({ code: "UNAUTHORIZED" }, { status: 401 });
  }
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) return NextResponse.json({ code: "SERVICE_UNAVAILABLE" }, { status: 503 });
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const [workflow, expiry] = await Promise.all([
    admin.rpc("process_workflow_sla"),
    admin.rpc("expire_access_requests"),
  ]);
  if (workflow.error || expiry.error) return NextResponse.json({ code: "INTERNAL_ERROR" }, { status: 500 });
  return NextResponse.json({ workflow: workflow.data, expiredAccessRequests: expiry.data });
}
