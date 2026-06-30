import { NextRequest, NextResponse } from "next/server";
import { sessionCookieName, shouldUseSecureCookie } from "@/lib/session";

export async function POST(request: NextRequest) {
  const response = NextResponse.redirect(new URL("/admin/login", request.url), 303);

  response.cookies.set(sessionCookieName, "", {
    httpOnly: true,
    secure: shouldUseSecureCookie(),
    sameSite: "lax",
    path: "/",
    maxAge: 0
  });

  return response;
}
