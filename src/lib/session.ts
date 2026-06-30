import { SignJWT, jwtVerify } from "jose";

export const sessionCookieName = "parking_admin_session";

export type AdminSessionPayload = {
  adminId: string;
  email: string;
  name: string;
};

function getSecretKey() {
  const secret = process.env.SESSION_SECRET;

  if (!secret || secret.length < 32) {
    throw new Error("SESSION_SECRET doit contenir au moins 32 caractères.");
  }

  return new TextEncoder().encode(secret);
}

export async function createSessionToken(payload: AdminSessionPayload) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("8h")
    .sign(getSecretKey());
}

export async function verifySessionToken(token: string) {
  const verified = await jwtVerify(token, getSecretKey());
  return verified.payload as unknown as AdminSessionPayload;
}

export function shouldUseSecureCookie() {
  return process.env.APP_URL?.startsWith("https://") === true;
}
