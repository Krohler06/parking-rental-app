#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/opt/gambetta_park"

echo "Patch thème + auth + contact pour : ${PROJECT_DIR}"

cd "${PROJECT_DIR}"

if [ ! -f ".env" ]; then
  echo "Fichier .env absent, création depuis .env.example..."
  cp .env.example .env
fi

echo "Vérification SESSION_SECRET..."
CURRENT_SECRET="$(grep -E '^SESSION_SECRET=' .env | cut -d '=' -f2- || true)"

if [ -z "${CURRENT_SECRET}" ] || [ "${#CURRENT_SECRET}" -lt 32 ] || echo "${CURRENT_SECRET}" | grep -qi "change-moi"; then
  if command -v openssl >/dev/null 2>&1; then
    NEW_SECRET="$(openssl rand -hex 32)"
  else
    NEW_SECRET="$(date +%s%N | sha256sum | awk '{print $1}')"
  fi

  if grep -qE '^SESSION_SECRET=' .env; then
    sed -i "s|^SESSION_SECRET=.*|SESSION_SECRET=${NEW_SECRET}|" .env
  else
    echo "SESSION_SECRET=${NEW_SECRET}" >> .env
  fi

  echo "SESSION_SECRET régénéré."
else
  echo "SESSION_SECRET déjà OK."
fi

echo "Création des dossiers..."
mkdir -p \
  src/app/api/auth/login \
  src/app/api/auth/logout \
  src/app/api/contact \
  src/app/admin/login \
  src/app/admin/dashboard \
  src/components/admin \
  src/lib \
  scripts

echo "Patch src/lib/prisma.ts..."
cat > src/lib/prisma.ts <<'PRISMA_EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ["error", "warn"]
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
PRISMA_EOF

echo "Patch src/lib/session.ts..."
cat > src/lib/session.ts <<'SESSION_EOF'
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
SESSION_EOF
echo "Patch middleware.ts..."
cat > middleware.ts <<'MIDDLEWARE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";

const SESSION_COOKIE_NAME = "parking_admin_session";

function getSecretKey() {
  const secret =
    process.env.SESSION_SECRET ||
    "dev-secret-change-me-dev-secret-change-me-32chars";

  return new TextEncoder().encode(secret);
}

async function hasValidSession(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE_NAME)?.value;

  if (!token) {
    return false;
  }

  try {
    await jwtVerify(token, getSecretKey());
    return true;
  } catch {
    return false;
  }
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (!pathname.startsWith("/admin")) {
    return NextResponse.next();
  }

  const valid = await hasValidSession(request);

  if (pathname === "/admin/login") {
    if (valid) {
      return NextResponse.redirect(new URL("/admin/dashboard", request.url));
    }

    return NextResponse.next();
  }

  if (!valid) {
    const loginUrl = new URL("/admin/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (pathname === "/admin") {
    return NextResponse.redirect(new URL("/admin/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*"]
};
MIDDLEWARE_EOF

echo "Patch src/app/api/auth/login/route.ts..."
cat > src/app/api/auth/login/route.ts <<'LOGIN_ROUTE_EOF'
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
LOGIN_ROUTE_EOF

echo "Patch src/app/api/auth/logout/route.ts..."
cat > src/app/api/auth/logout/route.ts <<'LOGOUT_ROUTE_EOF'
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
LOGOUT_ROUTE_EOF

echo "Patch src/app/api/contact/route.ts..."
cat > src/app/api/contact/route.ts <<'CONTACT_ROUTE_EOF'
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
CONTACT_ROUTE_EOF

echo "Patch src/components/admin/AdminShell.tsx..."
cat > src/components/admin/AdminShell.tsx <<'ADMINSHELL_EOF'
import Link from "next/link";

const links = [
  { href: "/admin/dashboard", label: "Tableau de bord" },
  { href: "/admin/spots", label: "Places" },
  { href: "/admin/customers", label: "Clients" },
  { href: "/admin/vehicles", label: "Véhicules" },
  { href: "/admin/rentals", label: "Locations" },
  { href: "/admin/services", label: "Services" },
  { href: "/admin/pricing", label: "Tarifs" },
  { href: "/admin/messages", label: "Messages" }
];

export function AdminShell({
  title,
  subtitle,
  children
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-slate-100">
      <div className="grid min-h-screen md:grid-cols-[280px_1fr]">
        <aside className="bg-slate-950 p-6 text-white">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-yellow-300">
              Gambetta Park
            </p>
            <h1 className="mt-3 text-2xl font-black">Administration</h1>
            <p className="mt-2 text-sm text-slate-400">
              Gestion des places, clients, véhicules et locations.
            </p>
          </div>

          <nav className="mt-10 space-y-2">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="block rounded-2xl px-4 py-3 text-sm font-semibold text-slate-300 transition hover:bg-white/10 hover:text-white"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <form action="/api/auth/logout" method="post" className="mt-10">
            <button className="w-full rounded-2xl bg-yellow-300 px-4 py-3 text-sm font-black text-slate-950 transition hover:bg-yellow-200">
              Déconnexion
            </button>
          </form>

          <a
            href="/"
            className="mt-4 block text-center text-xs font-semibold text-slate-500 hover:text-slate-300"
          >
            Retour au site public
          </a>
        </aside>

        <section className="p-6 md:p-10">
          <div className="mb-8">
            <p className="text-sm font-bold uppercase tracking-[0.2em] text-yellow-600">
              Back-office
            </p>
            <h2 className="mt-2 text-4xl font-black tracking-tight text-slate-950">
              {title}
            </h2>
            {subtitle && (
              <p className="mt-3 max-w-3xl text-slate-600">{subtitle}</p>
            )}
          </div>

          {children}
        </section>
      </div>
    </main>
  );
}
ADMINSHELL_EOF

echo "Patch src/app/admin/login/page.tsx..."
cat > src/app/admin/login/page.tsx <<'LOGIN_PAGE_EOF'
export default async function AdminLoginPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : {};

  return (
    <main className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top,#1e293b,#020617_55%)] px-6">
      <section className="w-full max-w-md overflow-hidden rounded-[2rem] border border-white/10 bg-white shadow-2xl">
        <div className="bg-slate-950 px-8 py-8 text-white">
          <p className="text-xs font-bold uppercase tracking-[0.35em] text-yellow-300">
            Gambetta Park
          </p>
          <h1 className="mt-4 text-3xl font-black">Connexion admin</h1>
          <p className="mt-3 text-sm leading-6 text-slate-300">
            Accès réservé à la gestion des places, clients, véhicules et locations.
          </p>
        </div>

        <div className="p-8">
          {params.error && (
            <p className="mb-5 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
              Identifiants incorrects. Vérifie ADMIN_EMAIL et ADMIN_PASSWORD dans ton fichier .env.
            </p>
          )}

          <form action="/api/auth/login" method="post" className="space-y-5">
            <div>
              <label className="text-sm font-bold text-slate-800">Email</label>
              <input
                name="email"
                type="email"
                required
                className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3 outline-none transition focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                placeholder="admin@example.local"
              />
            </div>

            <div>
              <label className="text-sm font-bold text-slate-800">Mot de passe</label>
              <input
                name="password"
                type="password"
                required
                className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3 outline-none transition focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                placeholder="Mot de passe"
              />
            </div>

            <button className="w-full rounded-2xl bg-slate-950 px-4 py-3 font-black text-white transition hover:bg-slate-800">
              Se connecter
            </button>
          </form>

          <a
            href="/"
            className="mt-6 block text-center text-sm font-semibold text-slate-500 hover:text-slate-900"
          >
            Retour au site public
          </a>
        </div>
      </section>
    </main>
  );
}
LOGIN_PAGE_EOF
echo "Patch src/app/admin/dashboard/page.tsx..."
cat > src/app/admin/dashboard/page.tsx <<'DASHBOARD_EOF'
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";

function euro(value: number) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(value);
}

export default async function AdminDashboardPage() {
  const [
    totalSpots,
    availableSpots,
    occupiedSpots,
    reservedSpots,
    activeRentals,
    newMessages,
    customers,
    vehicles,
    rentals
  ] = await Promise.all([
    prisma.parkingSpot.count(),
    prisma.parkingSpot.count({ where: { status: "AVAILABLE" } }),
    prisma.parkingSpot.count({ where: { status: "OCCUPIED" } }),
    prisma.parkingSpot.count({ where: { status: "RESERVED" } }),
    prisma.rental.count({ where: { status: "ACTIVE" } }),
    prisma.contactMessage.count({ where: { status: "NEW" } }),
    prisma.customer.count(),
    prisma.vehicle.count(),
    prisma.rental.findMany({ where: { status: "ACTIVE" } })
  ]);

  const monthlyRevenue = rentals.reduce(
    (total, rental) => total + Number(rental.amountMonthly),
    0
  );

  const occupancyRate =
    totalSpots > 0 ? Math.round((occupiedSpots / totalSpots) * 100) : 0;

  const cards = [
    { label: "Places totales", value: totalSpots, detail: "3 étages de 40 places" },
    { label: "Disponibles", value: availableSpots, detail: "Prêtes à louer" },
    { label: "Occupées", value: occupiedSpots, detail: `${occupancyRate}% d’occupation` },
    { label: "Réservées", value: reservedSpots, detail: "En attente de confirmation" },
    { label: "Locations actives", value: activeRentals, detail: "Contrats en cours" },
    { label: "Messages non lus", value: newMessages, detail: "Demandes à traiter" },
    { label: "Clients", value: customers, detail: "Contacts enregistrés" },
    { label: "Véhicules", value: vehicles, detail: "Plaques suivies" },
    { label: "Revenu mensuel", value: euro(monthlyRevenue), detail: "Estimation active" }
  ];

  return (
    <AdminShell
      title="Tableau de bord"
      subtitle="Vue rapide de l’activité du parking : disponibilité, occupation, demandes entrantes et revenu mensuel estimé."
    >
      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {cards.map((card) => (
          <article
            key={card.label}
            className="rounded-[1.5rem] border border-slate-200 bg-white p-6 shadow-sm"
          >
            <p className="text-sm font-bold uppercase tracking-wide text-slate-500">
              {card.label}
            </p>
            <p className="mt-3 text-4xl font-black text-slate-950">
              {card.value}
            </p>
            <p className="mt-2 text-sm text-slate-500">
              {card.detail}
            </p>
          </article>
        ))}
      </div>

      <section className="mt-8 rounded-[1.5rem] bg-slate-950 p-8 text-white">
        <p className="text-sm font-bold uppercase tracking-[0.25em] text-yellow-300">
          Priorités
        </p>
        <h3 className="mt-3 text-2xl font-black">Ce qu’il faut surveiller</h3>

        <div className="mt-6 grid gap-4 md:grid-cols-3">
          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Messages entrants</p>
            <p className="mt-2 text-sm text-slate-300">
              Traiter rapidement les demandes augmente les chances de convertir une place libre.
            </p>
          </div>

          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Places disponibles</p>
            <p className="mt-2 text-sm text-slate-300">
              Les places libres doivent être visibles dans les tarifs et le discours commercial.
            </p>
          </div>

          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Locations actives</p>
            <p className="mt-2 text-sm text-slate-300">
              Garder les plaques et dates d’entrée à jour évite les erreurs terrain.
            </p>
          </div>
        </div>
      </section>
    </AdminShell>
  );
}
DASHBOARD_EOF

echo "Patch page publique src/app/page.tsx..."
cat > src/app/page.tsx <<'HOME_EOF'
import { prisma } from "@/lib/prisma";

function euro(value: number | string) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(Number(value));
}

function vehicleLabel(type: string) {
  const labels: Record<string, string> = {
    CAR: "Voiture",
    MOTORCYCLE: "Deux-roues",
    OTHER: "Autre"
  };

  return labels[type] || type;
}

export default async function HomePage({
  searchParams
}: {
  searchParams?: Promise<{ contact?: string }>;
}) {
  const params = searchParams ? await searchParams : {};

  const [services, pricing, totalSpots, availableSpots] = await Promise.all([
    prisma.service.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    }),
    prisma.pricing.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    }),
    prisma.parkingSpot.count(),
    prisma.parkingSpot.count({ where: { status: "AVAILABLE" } })
  ]);

  return (
    <main className="min-h-screen bg-slate-950 text-white">
      <header className="sticky top-0 z-50 border-b border-white/10 bg-slate-950/90 backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5">
          <a href="/" className="flex items-center gap-3">
            <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-yellow-300 font-black text-slate-950">
              P
            </span>
            <span>
              <span className="block text-lg font-black leading-none">Gambetta Park</span>
              <span className="block text-xs font-semibold text-slate-400">
                Parking mensuel sécurisé
              </span>
            </span>
          </a>

          <nav className="hidden items-center gap-7 text-sm font-bold text-slate-300 md:flex">
            <a href="#avantages" className="hover:text-yellow-300">Avantages</a>
            <a href="#tarifs" className="hover:text-yellow-300">Tarifs</a>
            <a href="#contact" className="hover:text-yellow-300">Contact</a>
          </nav>

          <a
            href="#contact"
            className="rounded-full bg-yellow-300 px-5 py-3 text-sm font-black text-slate-950 transition hover:bg-yellow-200"
          >
            Vérifier une disponibilité
          </a>
        </div>
      </header>

      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(250,204,21,0.24),transparent_30%),radial-gradient(circle_at_80%_10%,rgba(37,99,235,0.18),transparent_28%)]" />
        <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-slate-950 to-transparent" />

        <div className="relative mx-auto grid min-h-[82vh] max-w-7xl items-center gap-12 px-6 py-20 lg:grid-cols-[1.1fr_0.9fr]">
          <div>
            <p className="mb-5 inline-flex rounded-full border border-yellow-300/30 bg-yellow-300/10 px-4 py-2 text-sm font-bold text-yellow-200">
              Location mensuelle · Voiture · Moto · Scooter
            </p>

            <h1 className="max-w-5xl text-5xl font-black tracking-tight md:text-7xl">
              Une place claire, sécurisée, et réservée pour votre véhicule.
            </h1>

            <p className="mt-7 max-w-2xl text-lg leading-8 text-slate-300">
              Gambetta Park propose des emplacements mensuels dans un parking fermé,
              organisé sur 3 étages, avec des places numérotées et une gestion simple
              pour voitures et deux-roues.
            </p>

            <div className="mt-9 flex flex-wrap gap-4">
              <a
                href="#contact"
                className="rounded-2xl bg-yellow-300 px-7 py-4 font-black text-slate-950 transition hover:bg-yellow-200"
              >
                Demander une place
              </a>

              <a
                href="#tarifs"
                className="rounded-2xl border border-white/15 px-7 py-4 font-black text-white transition hover:bg-white/10"
              >
                Voir les tarifs
              </a>
            </div>

            <div className="mt-10 grid max-w-xl grid-cols-3 gap-4">
              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">3</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">étages</p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">{totalSpots}</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">places</p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">{availableSpots}</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">disponibles</p>
              </div>
            </div>
          </div>

          <div className="relative">
            <div className="rounded-[2rem] border border-white/10 bg-white/10 p-5 shadow-2xl backdrop-blur">
              <div className="rounded-[1.5rem] bg-slate-900 p-6">
                <div className="flex items-center justify-between">
                  <p className="text-sm font-bold uppercase tracking-[0.25em] text-yellow-300">
                    Plan parking
                  </p>
                  <span className="rounded-full bg-emerald-400/15 px-3 py-1 text-xs font-bold text-emerald-300">
                    Accès fermé
                  </span>
                </div>

                <div className="mt-8 space-y-5">
                  {[1, 2, 3].map((floor) => (
                    <div key={floor} className="rounded-2xl bg-white p-4 text-slate-950">
                      <div className="flex items-center justify-between">
                        <p className="font-black">Étage {floor}</p>
                        <p className="text-sm font-bold text-slate-500">40 places</p>
                      </div>

                      <div className="mt-4 grid grid-cols-10 gap-1">
                        {Array.from({ length: 40 }).map((_, index) => (
                          <span
                            key={index}
                            className={`h-4 rounded ${
                              index % 7 === 0
                                ? "bg-red-400"
                                : index % 5 === 0
                                  ? "bg-amber-300"
                                  : "bg-emerald-400"
                            }`}
                          />
                        ))}
                      </div>
                    </div>
                  ))}
                </div>

                <div className="mt-6 flex flex-wrap gap-3 text-xs font-bold text-slate-300">
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-emerald-400" /> Disponible
                  </span>
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-amber-300" /> Réservée
                  </span>
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-red-400" /> Occupée
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="avantages" className="bg-white py-24 text-slate-950">
        <div className="mx-auto max-w-7xl px-6">
          <div className="max-w-3xl">
            <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
              Pourquoi Gambetta Park ?
            </p>
            <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
              Un stationnement mensuel simple, lisible et sécurisé.
            </h2>
            <p className="mt-5 text-lg leading-8 text-slate-600">
              Fini les recherches de place, les stationnements improvisés ou les
              contraintes du quotidien. Vous disposez d’un emplacement identifié,
              dans un parking organisé et suivi.
            </p>
          </div>

          <div className="mt-12 grid gap-6 md:grid-cols-3">
            {(services.length > 0
              ? services
              : [
                  {
                    id: "1",
                    title: "Parking fermé",
                    description: "Un espace fermé pour stationner votre véhicule avec plus de sérénité."
                  },
                  {
                    id: "2",
                    title: "Places numérotées",
                    description: "Chaque emplacement est identifié par étage et numéro de place."
                  },
                  {
                    id: "3",
                    title: "Voiture ou deux-roues",
                    description: "Des solutions adaptées aux véhicules particuliers, motos et scooters."
                  }
                ]
            ).map((service) => (
              <article
                key={service.id}
                className="rounded-[1.5rem] border border-slate-200 bg-slate-50 p-7"
              >
                <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-2xl bg-yellow-300 font-black">
                  ✓
                </div>
                <h3 className="text-2xl font-black">{service.title}</h3>
                <p className="mt-4 leading-7 text-slate-600">{service.description}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="tarifs" className="bg-slate-100 py-24 text-slate-950">
        <div className="mx-auto max-w-7xl px-6">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end">
            <div>
              <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
                Tarifs
              </p>
              <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
                Des formules mensuelles sans complication.
              </h2>
            </div>
            <p className="max-w-xl text-slate-600">
              Les tarifs peuvent évoluer selon la disponibilité, le type de véhicule
              et la durée souhaitée. Contactez-nous pour confirmer une place.
            </p>
          </div>

          <div className="mt-12 grid gap-6 md:grid-cols-2">
            {(pricing.length > 0
              ? pricing
              : [
                  {
                    id: "fallback-car",
                    title: "Place voiture",
                    description: "Location mensuelle pour véhicule particulier.",
                    vehicleType: "CAR",
                    priceMonthly: "120"
                  },
                  {
                    id: "fallback-moto",
                    title: "Place deux-roues",
                    description: "Location mensuelle pour moto ou scooter.",
                    vehicleType: "MOTORCYCLE",
                    priceMonthly: "60"
                  }
                ]
            ).map((price) => (
              <article
                key={price.id}
                className="rounded-[2rem] bg-white p-8 shadow-sm ring-1 ring-slate-200"
              >
                <p className="text-sm font-black uppercase tracking-[0.2em] text-yellow-600">
                  {vehicleLabel(String(price.vehicleType))}
                </p>
                <h3 className="mt-4 text-3xl font-black">{price.title}</h3>
                <p className="mt-4 min-h-14 leading-7 text-slate-600">
                  {price.description}
                </p>
                <p className="mt-8 text-5xl font-black">
                  {euro(price.priceMonthly.toString())}
                  <span className="text-base font-bold text-slate-500"> / mois</span>
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="contact" className="bg-white py-24 text-slate-950">
        <div className="mx-auto grid max-w-7xl gap-12 px-6 lg:grid-cols-[0.9fr_1.1fr]">
          <div>
            <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
              Contact
            </p>
            <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
              Une place vous intéresse ?
            </h2>
            <p className="mt-6 text-lg leading-8 text-slate-600">
              Envoyez votre demande avec le type de véhicule, la durée souhaitée
              et vos coordonnées. Nous vous recontacterons pour confirmer la
              disponibilité et les modalités.
            </p>

            <div className="mt-10 space-y-4">
              <div className="rounded-2xl bg-slate-100 p-5">
                <p className="font-black">Idéal pour</p>
                <p className="mt-1 text-slate-600">
                  Résidents, actifs du quartier, deux-roues, véhicules secondaires.
                </p>
              </div>

              <div className="rounded-2xl bg-slate-100 p-5">
                <p className="font-black">Informations utiles</p>
                <p className="mt-1 text-slate-600">
                  Précisez le véhicule, la plaque si disponible, et la date d’entrée souhaitée.
                </p>
              </div>
            </div>
          </div>

          <form
            action="/api/contact"
            method="post"
            className="rounded-[2rem] border border-slate-200 bg-slate-50 p-6 shadow-sm md:p-8"
          >
            {params.contact === "success" && (
              <p className="mb-6 rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-700">
                Votre message a bien été envoyé. Nous reviendrons vers vous rapidement.
              </p>
            )}

            {params.contact === "error" && (
              <p className="mb-6 rounded-2xl bg-red-50 px-4 py-3 text-sm font-bold text-red-700">
                Merci de renseigner au minimum votre nom, email et message.
              </p>
            )}

            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <label className="text-sm font-bold">Nom</label>
                <input
                  name="name"
                  required
                  placeholder="Votre nom"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Email</label>
                <input
                  name="email"
                  required
                  type="email"
                  placeholder="vous@email.fr"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Téléphone</label>
                <input
                  name="phone"
                  placeholder="06..."
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Objet</label>
                <input
                  name="subject"
                  placeholder="Demande de place"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>
            </div>

            <div className="mt-4">
              <label className="text-sm font-bold">Message</label>
              <textarea
                name="message"
                required
                rows={6}
                placeholder="Bonjour, je recherche une place mensuelle pour une voiture à partir du..."
                className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
              />
            </div>

            <button className="mt-6 w-full rounded-2xl bg-slate-950 px-6 py-4 font-black text-white transition hover:bg-slate-800">
              Envoyer ma demande
            </button>

            <p className="mt-4 text-center text-xs text-slate-500">
              Vos informations servent uniquement à traiter votre demande de stationnement.
            </p>
          </form>
        </div>
      </section>

      <footer className="border-t border-white/10 bg-slate-950 px-6 py-10 text-slate-400">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="font-black text-white">Gambetta Park</p>
            <p className="mt-1 text-sm">
              Location mensuelle de places de parking sécurisées.
            </p>
          </div>

          <div className="flex flex-wrap gap-5 text-sm">
            <a href="#avantages" className="hover:text-yellow-300">Avantages</a>
            <a href="#tarifs" className="hover:text-yellow-300">Tarifs</a>
            <a href="#contact" className="hover:text-yellow-300">Contact</a>
            <a href="/admin/login" className="text-slate-600 hover:text-slate-300">
              Espace gestion
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
HOME_EOF

echo "Patch scripts/docker-entrypoint.sh..."
cat > scripts/docker-entrypoint.sh <<'ENTRYPOINT_EOF'
#!/usr/bin/env sh
set -e

echo "Application parking : initialisation Prisma..."
npx prisma db push --skip-generate

echo "Application parking : seed base de données..."
npx prisma db seed || true

echo "Application parking : démarrage Next.js..."
node server.js
ENTRYPOINT_EOF






chmod +x scripts/docker-entrypoint.sh

echo "Arrêt des containers..."
docker compose down --remove-orphans || true

echo "Rebuild sans cache..."
docker compose build --no-cache app

echo "Démarrage..."
docker compose up -d

echo ""
echo "État :"
docker compose ps

echo ""
echo "Tests HTTP :"
sleep 5
curl -I http://127.0.0.1:3020/ || true
curl -I http://127.0.0.1:3020/admin/login || true

echo ""
echo "Credentials admin actuels dans .env :"
grep -E '^(ADMIN_EMAIL|ADMIN_PASSWORD|ADMIN_NAME)=' .env || true

echo ""
echo "Patch terminé."
echo "Site : http://IP_DU_SERVEUR:3020/"
echo "Admin : http://IP_DU_SERVEUR:3020/admin/login"
