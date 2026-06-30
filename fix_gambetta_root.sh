#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/opt/gambetta_park"

echo "Réparation du projet dans : ${PROJECT_DIR}"

cd "${PROJECT_DIR}"

echo "Vérification du dossier courant :"
pwd

echo "Création des dossiers nécessaires..."
mkdir -p \
  scripts \
  src/app/admin/login \
  src/app/admin/dashboard \
  src/app/api/auth/login \
  src/app/api/auth/logout \
  src/lib \
  prisma

echo "Réécriture du docker-compose.yml..."
cat > docker-compose.yml <<'COMPOSE_EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: parking_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-parking_rental}
      POSTGRES_USER: ${POSTGRES_USER:-parking_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-change-moi}
    volumes:
      - parking_postgres_data:/var/lib/postgresql/data
    networks:
      - parking_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-parking_user} -d ${POSTGRES_DB:-parking_rental}"]
      interval: 10s
      timeout: 5s
      retries: 10

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: parking_app
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "3020:3000"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - parking_net

volumes:
  parking_postgres_data:

networks:
  parking_net:
    driver: bridge
COMPOSE_EOF

echo "Réécriture du .dockerignore..."
cat > .dockerignore <<'DOCKERIGNORE_EOF'
node_modules
.next
.git
.env
.env.local
.env.production
logs
*.log
coverage
.vscode
.idea
.DS_Store
DOCKERIGNORE_EOF

echo "Réécriture du Dockerfile..."
cat > Dockerfile <<'DOCKERFILE_EOF'
FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm install

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup -S nodejs && adduser -S nextjs -G nodejs

COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

RUN chmod +x /app/scripts/docker-entrypoint.sh

USER nextjs

EXPOSE 3000

CMD ["/app/scripts/docker-entrypoint.sh"]
DOCKERFILE_EOF

echo "Réécriture de scripts/docker-entrypoint.sh..."
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

echo "Vérification / création de next.config.ts..."
cat > next.config.ts <<'NEXTCONFIG_EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone"
};

export default nextConfig;
NEXTCONFIG_EOF

echo "Vérification / création de src/app/layout.tsx..."
cat > src/app/layout.tsx <<'LAYOUT_EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Gambetta Park",
  description: "Location mensuelle de places de parking sécurisées pour voitures et deux-roues."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
LAYOUT_EOF

echo "Vérification / création de src/app/globals.css..."
cat > src/app/globals.css <<'CSS_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: light;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: #f8fafc;
  color: #0f172a;
}

input,
textarea,
select,
button {
  font: inherit;
}
CSS_EOF

echo "Réécriture de la page d'accueil src/app/page.tsx..."
cat > src/app/page.tsx <<'HOME_EOF'
export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
          <a href="/" className="text-xl font-bold text-slate-950">
            Gambetta Park
          </a>

          <nav className="hidden gap-6 text-sm font-medium text-slate-700 md:flex">
            <a href="#services">Services</a>
            <a href="#tarifs">Tarifs</a>
            <a href="#contact">Contact</a>
            <a href="/admin/login">Admin</a>
          </nav>
        </div>
      </header>

      <section className="mx-auto flex min-h-[85vh] max-w-6xl flex-col justify-center px-6 py-16">
        <p className="mb-4 w-fit rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white">
          Parking fermé et sécurisé
        </p>

        <h1 className="max-w-4xl text-4xl font-bold tracking-tight text-slate-950 md:text-6xl">
          Location mensuelle de places de parking pour voitures et deux-roues.
        </h1>

        <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
          Louez une place dans un parking fermé, sécurisé et organisé sur 3 étages,
          avec des emplacements numérotés et une gestion administrative complète.
        </p>

        <div className="mt-8 flex flex-wrap gap-4">
          <a
            href="#contact"
            className="rounded-xl bg-slate-950 px-6 py-3 font-semibold text-white"
          >
            Demander une place
          </a>

          <a
            href="/admin/login"
            className="rounded-xl border border-slate-300 px-6 py-3 font-semibold text-slate-900"
          >
            Administration
          </a>
        </div>
      </section>

      <section id="services" className="bg-white py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-slate-950">Services</h2>

          <div className="mt-8 grid gap-6 md:grid-cols-3">
            <article className="rounded-2xl border border-slate-200 p-6">
              <h3 className="text-xl font-bold">Parking fermé</h3>
              <p className="mt-3 text-slate-600">
                Stationnement dans un espace fermé et sécurisé.
              </p>
            </article>

            <article className="rounded-2xl border border-slate-200 p-6">
              <h3 className="text-xl font-bold">Voitures et deux-roues</h3>
              <p className="mt-3 text-slate-600">
                Emplacements adaptés aux voitures, motos et scooters.
              </p>
            </article>

            <article className="rounded-2xl border border-slate-200 p-6">
              <h3 className="text-xl font-bold">Location mensuelle</h3>
              <p className="mt-3 text-slate-600">
                Gestion claire du client, du montant, de la durée et du véhicule.
              </p>
            </article>
          </div>
        </div>
      </section>

      <section id="tarifs" className="py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-slate-950">Tarifs</h2>

          <div className="mt-8 grid gap-6 md:grid-cols-2">
            <article className="rounded-2xl bg-white p-6 shadow-sm">
              <h3 className="text-2xl font-bold">Place voiture</h3>
              <p className="mt-3 text-slate-600">Location mensuelle pour véhicule particulier.</p>
              <p className="mt-6 text-3xl font-bold">120 € <span className="text-base font-medium text-slate-500">/ mois</span></p>
            </article>

            <article className="rounded-2xl bg-white p-6 shadow-sm">
              <h3 className="text-2xl font-bold">Place deux-roues</h3>
              <p className="mt-3 text-slate-600">Location mensuelle pour moto ou scooter.</p>
              <p className="mt-6 text-3xl font-bold">60 € <span className="text-base font-medium text-slate-500">/ mois</span></p>
            </article>
          </div>
        </div>
      </section>

      <section id="contact" className="bg-white py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-slate-950">Contact</h2>
          <p className="mt-4 max-w-2xl text-slate-600">
            Formulaire de contact à connecter à la base de données dans l'étape suivante.
          </p>
        </div>
      </section>
    </main>
  );
}
HOME_EOF

echo "Réécriture de la page admin login..."
cat > src/app/admin/login/page.tsx <<'LOGIN_EOF'
export default function AdminLoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-100 px-6">
      <section className="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm">
        <h1 className="text-2xl font-bold text-slate-950">Connexion admin</h1>
        <p className="mt-2 text-sm text-slate-600">
          Accès réservé à l'administration du parking.
        </p>

        <form action="/api/auth/login" method="post" className="mt-6 space-y-4">
          <div>
            <label className="text-sm font-medium text-slate-700">
              Email
            </label>
            <input
              name="email"
              type="email"
              required
              className="mt-1 w-full rounded-xl border border-slate-300 px-4 py-3"
              placeholder="admin@example.local"
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">
              Mot de passe
            </label>
            <input
              name="password"
              type="password"
              required
              className="mt-1 w-full rounded-xl border border-slate-300 px-4 py-3"
              placeholder="Mot de passe"
            />
          </div>

          <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
            Connexion
          </button>
        </form>
      </section>
    </main>
  );
}
LOGIN_EOF

echo "Création d'un dashboard minimal..."
cat > src/app/admin/dashboard/page.tsx <<'DASHBOARD_EOF'
export default function AdminDashboardPage() {
  return (
    <main className="min-h-screen bg-slate-100 p-8">
      <section className="mx-auto max-w-6xl rounded-2xl bg-white p-8 shadow-sm">
        <h1 className="text-3xl font-bold text-slate-950">
          Tableau de bord Gambetta Park
        </h1>

        <p className="mt-4 text-slate-600">
          L'interface d'administration est prête à recevoir les modules :
          places, clients, véhicules, locations, tarifs et messages.
        </p>

        <div className="mt-8 grid gap-4 md:grid-cols-3">
          <article className="rounded-xl border border-slate-200 p-5">
            <p className="text-sm font-semibold text-slate-500">Étages</p>
            <p className="mt-2 text-3xl font-bold">3</p>
          </article>

          <article className="rounded-xl border border-slate-200 p-5">
            <p className="text-sm font-semibold text-slate-500">Places par étage</p>
            <p className="mt-2 text-3xl font-bold">40</p>
          </article>

          <article className="rounded-xl border border-slate-200 p-5">
            <p className="text-sm font-semibold text-slate-500">Total places</p>
            <p className="mt-2 text-3xl font-bold">120</p>
          </article>
        </div>

        <a
          href="/"
          className="mt-8 inline-block rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white"
        >
          Retour au site
        </a>
      </section>
    </main>
  );
}
DASHBOARD_EOF

echo "Création route login temporaire..."
cat > src/app/api/auth/login/route.ts <<'LOGIN_ROUTE_EOF'
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  return NextResponse.redirect(new URL("/admin/dashboard", request.url), 303);
}
LOGIN_ROUTE_EOF

echo "Création route logout temporaire..."
cat > src/app/api/auth/logout/route.ts <<'LOGOUT_ROUTE_EOF'
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  return NextResponse.redirect(new URL("/admin/login", request.url), 303);
}
LOGOUT_ROUTE_EOF

echo "Liste des fichiers src/app après correction :"
find src/app -maxdepth 5 -type f | sort

echo "Arrêt des anciens containers..."
docker compose down --remove-orphans || true

echo "Suppression forcée de l'ancien container parking_app si présent..."
docker rm -f parking_app 2>/dev/null || true

echo "Rebuild complet sans cache..."
docker compose build --no-cache app

echo "Démarrage..."
docker compose up -d

echo "État Docker :"
docker compose ps

echo "Tests HTTP locaux..."
sleep 5

echo ""
echo "Test /"
curl -I http://127.0.0.1:3020/ || true

echo ""
echo "Test /admin/login"
curl -I http://127.0.0.1:3020/admin/login || true

echo ""
echo "Terminé."
echo "Accès : http://IP_DU_SERVEUR:3020/"
echo "Admin : http://IP_DU_SERVEUR:3020/admin/login"
