import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  const loginUrl = request.nextUrl.clone();
  loginUrl.pathname = "/login";
  loginUrl.searchParams.set("next", request.nextUrl.pathname);

  // Jika Supabase belum dikonfigurasi, JANGAN izinkan akses admin
  if (!url || !key) {
    return NextResponse.redirect(loginUrl);
  }

  const response = NextResponse.next({
    request,
  });

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },

      setAll(cookies) {
        cookies.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Belum login → masuk ke halaman login
  if (!user) {
    return NextResponse.redirect(loginUrl);
  }

  // Sudah login → boleh akses admin
  return response;
}

export const config = {
  matcher: ["/admin/:path*"],
};