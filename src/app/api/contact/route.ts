import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(request: NextRequest) {
  const formData = await request.formData();

  const name = String(formData.get("name") || "").trim();
  const email = String(formData.get("email") || "").trim();
  const phone = String(formData.get("phone") || "").trim();
  const subject = String(formData.get("subject") || "").trim();
  const message = String(formData.get("message") || "").trim();

  if (!name || !email || !message) {
    return NextResponse.redirect(new URL("/?contact=error#contact", request.url), 303);
  }

  await prisma.contactMessage.create({
    data: {
      name,
      email,
      phone: phone || null,
      subject: subject || "Demande de place",
      message
    }
  });

  return NextResponse.redirect(new URL("/?contact=success#contact", request.url), 303);
}
