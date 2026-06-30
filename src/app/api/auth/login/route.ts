import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import {
  createSessionToken,
  sessionCookieName,
  shouldUseSecureCookie
} from "@/lib/session";

export async function POST(request: NextRequest) {
  const formData = await request.formData();

  const email = String(formData.get("email") || "").trim().toLowerCase();
  const password = String(formData.get("password") || "");

  const admin = await prisma.admin.findUnique({
    where: { email }
  });

  if (!admin || !admin.isActive) {
    return NextResponse.redirect(new URL("/admin/login?error=1", request.url), 303);
  }

  const validPassword = await bcrypt.compare(password, admin.passwordHash);

  if (!validPassword) {
    return NextResponse.redirect(new URL("/admin/login?error=1", request.url), 303);
  }

  await prisma.admin.update({
    where: { id: admin.id },
    data: { lastLoginAt: new Date() }
  });

  const token = await createSessionToken({
    adminId: admin.id,
    email: admin.email,
    name: admin.name
  });

  const response = NextResponse.redirect(new URL("/admin/dashboard", request.url), 303);

  response.cookies.set(sessionCookieName, token, {
    httpOnly: true,
    secure: shouldUseSecureCookie(),
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 8
  });

  return response;
}
