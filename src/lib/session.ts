import { SignJWT, jwtVerify } from "jose";

const SESSION_COOKIE_NAME = "parking_admin_session";

function getSecretKey() {
  const secret = process.env.SESSION_SECRET;

  if (!secret || secret.length < 32) {
    throw new Error("SESSION_SECRET doit contenir au moins 32 caractères.");
  }

  return new TextEncoder().encode(secret);
}

export type AdminSessionPayload = {
  adminId: string;
  email: string;
  name: string;
};

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

export const sessionCookieName = SESSION_COOKIE_NAME;
