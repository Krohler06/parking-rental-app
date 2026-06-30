#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="parking-rental-app"
PROJECT_DIR="./${PROJECT_NAME}"

echo "Création du projet : ${PROJECT_NAME}"

if [ -d "${PROJECT_DIR}" ]; then
  echo "Erreur : le dossier ${PROJECT_DIR} existe déjà."
  echo "Supprime-le ou change PROJECT_NAME dans le script."
  exit 1
fi

mkdir -p "${PROJECT_DIR}"
cd "${PROJECT_DIR}"

mkdir -p \
  prisma \
  public/images \
  scripts \
  src/app/api/auth/login \
  src/app/api/auth/logout \
  src/app/api/contact \
  src/app/admin/login \
  'src/app/admin/(protected)/dashboard' \
  'src/app/admin/(protected)/spots' \
  'src/app/admin/(protected)/customers' \
  'src/app/admin/(protected)/vehicles' \
  'src/app/admin/(protected)/rentals' \
  'src/app/admin/(protected)/services' \
  'src/app/admin/(protected)/pricing' \
  'src/app/admin/(protected)/messages' \
  src/components/admin \
  src/components/public \
  src/components/ui \
  src/actions \
  src/lib \
  src/types

cat > .gitignore <<'GITIGNORE_EOF'
node_modules
.next
.env
.env.local
.env.production
dist
coverage
.DS_Store
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
GITIGNORE_EOF

cat > .env.example <<'ENV_EOF'
NODE_ENV=production
APP_URL=http://localhost:3000
APP_NAME="Parking Rental App"

SESSION_SECRET=change-moi-avec-une-valeur-longue-et-aleatoire-minimum-32-caracteres

POSTGRES_DB=parking_rental
POSTGRES_USER=parking_user
POSTGRES_PASSWORD=change-moi

DATABASE_URL=postgresql://parking_user:change-moi@postgres:5432/parking_rental?schema=public

ADMIN_EMAIL=admin@example.local
ADMIN_PASSWORD=ChangeMoi123!
ADMIN_NAME=Administrateur
ENV_EOF

cat > package.json <<'PACKAGE_EOF'
{
  "name": "parking-rental-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "prisma generate && next build",
    "start": "node .next/standalone/server.js",
    "prisma:generate": "prisma generate",
    "prisma:push": "prisma db push",
    "prisma:seed": "tsx prisma/seed.ts"
  },
  "dependencies": {
    "@prisma/client": "^6.9.0",
    "bcryptjs": "^3.0.2",
    "jose": "^6.0.11",
    "next": "^15.3.4",
    "prisma": "^6.9.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "zod": "^3.25.67"
  },
  "devDependencies": {
    "@types/node": "^22.15.32",
    "@types/react": "^19.0.12",
    "@types/react-dom": "^19.0.4",
    "autoprefixer": "^10.4.21",
    "postcss": "^8.5.6",
    "tailwindcss": "^3.4.17",
    "tsx": "^4.20.3",
    "typescript": "^5.8.3"
  },
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
PACKAGE_EOF

cat > tsconfig.json <<'TSCONFIG_EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "es2022"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSCONFIG_EOF

cat > next-env.d.ts <<'NEXTENV_EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
NEXTENV_EOF

cat > next.config.ts <<'NEXTCONFIG_EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone"
};

export default nextConfig;
NEXTCONFIG_EOF

cat > postcss.config.js <<'POSTCSS_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
POSTCSS_EOF

cat > tailwind.config.ts <<'TAILWIND_EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {}
  },
  plugins: []
};

export default config;
TAILWIND_EOF

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
      - "3000:3000"
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

cat > Dockerfile <<'DOCKERFILE_EOF'
FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json ./
RUN npm install

FROM base AS builder
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

cat > scripts/docker-entrypoint.sh <<'ENTRYPOINT_EOF'
#!/usr/bin/env sh
set -e

echo "Application parking : initialisation Prisma..."
npx prisma db push

echo "Application parking : seed base de données..."
npx prisma db seed || true

echo "Application parking : démarrage Next.js..."
node server.js
ENTRYPOINT_EOF

chmod +x scripts/docker-entrypoint.sh

cat > prisma/schema.prisma <<'PRISMA_SCHEMA_EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum AdminRole {
  SUPER_ADMIN
  ADMIN
}

enum SpotType {
  CAR
  MOTORCYCLE
  BOTH
}

enum SpotStatus {
  AVAILABLE
  OCCUPIED
  RESERVED
  MAINTENANCE
  INACTIVE
}

enum VehicleType {
  CAR
  MOTORCYCLE
  OTHER
}

enum RentalStatus {
  PENDING
  ACTIVE
  ENDED
  CANCELLED
}

enum PaymentStatus {
  PAID
  UNPAID
  PARTIAL
  LATE
}

enum MessageStatus {
  NEW
  READ
  ARCHIVED
}

model Admin {
  id           String    @id @default(cuid())
  email        String    @unique
  passwordHash String
  name         String
  role         AdminRole @default(ADMIN)
  isActive     Boolean   @default(true)
  lastLoginAt  DateTime?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  auditLogs AdminAuditLog[]
}

model SiteSetting {
  id           String   @id @default(cuid())
  companyName  String
  headline     String
  description  String
  address      String
  phone        String
  email        String
  openingHours String?
  facebookUrl  String?
  instagramUrl String?
  linkedinUrl  String?
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}

model Service {
  id          String   @id @default(cuid())
  title       String   @unique
  description String
  icon        String?
  isActive    Boolean  @default(true)
  sortOrder   Int      @default(0)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

model Pricing {
  id           String      @id @default(cuid())
  title        String      @unique
  description  String?
  vehicleType  VehicleType
  priceMonthly Decimal     @db.Decimal(10, 2)
  currency     String      @default("EUR")
  isActive     Boolean     @default(true)
  sortOrder    Int         @default(0)
  createdAt    DateTime    @default(now())
  updatedAt    DateTime    @updatedAt
}

model ContactMessage {
  id        String        @id @default(cuid())
  name      String
  email     String
  phone     String?
  subject   String?
  message   String
  status    MessageStatus @default(NEW)
  createdAt DateTime      @default(now())
  updatedAt DateTime      @updatedAt
}

model ParkingFloor {
  id          String   @id @default(cuid())
  name        String
  levelNumber Int      @unique
  description String?
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  spots ParkingSpot[]
}

model ParkingSpot {
  id         String     @id @default(cuid())
  floorId    String
  spotNumber Int
  label      String
  spotType   SpotType   @default(BOTH)
  status     SpotStatus @default(AVAILABLE)
  isActive   Boolean    @default(true)
  createdAt  DateTime   @default(now())
  updatedAt  DateTime   @updatedAt

  floor   ParkingFloor @relation(fields: [floorId], references: [id], onDelete: Cascade)
  rentals Rental[]

  @@unique([floorId, spotNumber])
}

model Customer {
  id        String   @id @default(cuid())
  firstName String
  lastName  String
  email     String?
  phone     String?
  address   String?
  notes     String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  vehicles Vehicle[]
  rentals  Rental[]
}

model VehicleBrand {
  id        String   @id @default(cuid())
  name      String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  models   VehicleModel[]
  vehicles Vehicle[]
}

model VehicleModel {
  id          String      @id @default(cuid())
  brandId     String
  name        String
  vehicleType VehicleType
  createdAt   DateTime    @default(now())
  updatedAt   DateTime    @updatedAt

  brand    VehicleBrand @relation(fields: [brandId], references: [id], onDelete: Cascade)
  vehicles Vehicle[]

  @@unique([brandId, name])
}

model Vehicle {
  id           String      @id @default(cuid())
  customerId   String
  brandId      String?
  modelId      String?
  customBrand  String?
  customModel  String?
  vehicleType  VehicleType
  licensePlate String      @unique
  color        String?
  createdAt    DateTime    @default(now())
  updatedAt    DateTime    @updatedAt

  customer Customer      @relation(fields: [customerId], references: [id], onDelete: Cascade)
  brand    VehicleBrand? @relation(fields: [brandId], references: [id], onDelete: SetNull)
  model    VehicleModel? @relation(fields: [modelId], references: [id], onDelete: SetNull)
  rentals  Rental[]
}

model Rental {
  id             String        @id @default(cuid())
  parkingSpotId  String
  customerId     String
  vehicleId      String
  amountMonthly  Decimal       @db.Decimal(10, 2)
  durationMonths Int
  entryDate      DateTime
  exitDate       DateTime?
  status         RentalStatus  @default(ACTIVE)
  paymentStatus  PaymentStatus @default(UNPAID)
  notes          String?
  createdAt      DateTime      @default(now())
  updatedAt      DateTime      @updatedAt

  parkingSpot ParkingSpot @relation(fields: [parkingSpotId], references: [id], onDelete: Restrict)
  customer    Customer    @relation(fields: [customerId], references: [id], onDelete: Restrict)
  vehicle     Vehicle     @relation(fields: [vehicleId], references: [id], onDelete: Restrict)
}

model AdminAuditLog {
  id         String   @id @default(cuid())
  adminId    String?
  action     String
  entityType String?
  entityId   String?
  metadata   Json?
  createdAt  DateTime @default(now())

  admin Admin? @relation(fields: [adminId], references: [id], onDelete: SetNull)
}
PRISMA_SCHEMA_EOF

cat > prisma/seed.ts <<'SEED_EOF'
import { PrismaClient, SpotStatus, SpotType, VehicleType } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.env.ADMIN_EMAIL || "admin@example.local";
  const adminPassword = process.env.ADMIN_PASSWORD || "ChangeMoi123!";
  const adminName = process.env.ADMIN_NAME || "Administrateur";

  const passwordHash = await bcrypt.hash(adminPassword, 12);

  await prisma.admin.upsert({
    where: { email: adminEmail },
    update: {
      passwordHash,
      name: adminName,
      isActive: true
    },
    create: {
      email: adminEmail,
      passwordHash,
      name: adminName,
      role: "SUPER_ADMIN"
    }
  });

  await prisma.siteSetting.upsert({
    where: { id: "default" },
    update: {},
    create: {
      id: "default",
      companyName: "Parking Sécurisé",
      headline: "Location mensuelle de places de parking",
      description:
        "Parking fermé et sécurisé pour voitures et deux-roues, disponible à la location mensuelle.",
      address: "Adresse à compléter",
      phone: "Téléphone à compléter",
      email: "contact@example.local",
      openingHours: "Lundi au samedi, sur rendez-vous"
    }
  });

  const floors = [
    { name: "Étage 1", levelNumber: 1 },
    { name: "Étage 2", levelNumber: 2 },
    { name: "Étage 3", levelNumber: 3 }
  ];

  for (const floor of floors) {
    const createdFloor = await prisma.parkingFloor.upsert({
      where: { levelNumber: floor.levelNumber },
      update: { name: floor.name, isActive: true },
      create: {
        name: floor.name,
        levelNumber: floor.levelNumber,
        isActive: true
      }
    });

    for (let spotNumber = 1; spotNumber <= 40; spotNumber++) {
      await prisma.parkingSpot.upsert({
        where: {
          floorId_spotNumber: {
            floorId: createdFloor.id,
            spotNumber
          }
        },
        update: {},
        create: {
          floorId: createdFloor.id,
          spotNumber,
          label: `${floor.name} - Place ${spotNumber}`,
          spotType: SpotType.BOTH,
          status: SpotStatus.AVAILABLE,
          isActive: true
        }
      });
    }
  }

  await prisma.service.createMany({
    data: [
      {
        title: "Parking fermé",
        description: "Un espace fermé pour stationner votre véhicule en toute tranquillité.",
        icon: "shield",
        sortOrder: 1
      },
      {
        title: "Voitures et deux-roues",
        description: "Des places adaptées aux véhicules particuliers, motos et scooters.",
        icon: "car",
        sortOrder: 2
      },
      {
        title: "Location mensuelle",
        description: "Une gestion simple avec montant, durée, date d’entrée et véhicule.",
        icon: "calendar",
        sortOrder: 3
      }
    ],
    skipDuplicates: true
  });

  await prisma.pricing.createMany({
    data: [
      {
        title: "Place voiture",
        description: "Location mensuelle pour véhicule particulier.",
        vehicleType: VehicleType.CAR,
        priceMonthly: 120,
        currency: "EUR",
        sortOrder: 1
      },
      {
        title: "Place deux-roues",
        description: "Location mensuelle pour moto ou scooter.",
        vehicleType: VehicleType.MOTORCYCLE,
        priceMonthly: 60,
        currency: "EUR",
        sortOrder: 2
      }
    ],
    skipDuplicates: true
  });

  const brands = [
    {
      name: "Renault",
      models: [
        { name: "Clio", vehicleType: VehicleType.CAR },
        { name: "Captur", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Peugeot",
      models: [
        { name: "208", vehicleType: VehicleType.CAR },
        { name: "308", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Citroën",
      models: [
        { name: "C3", vehicleType: VehicleType.CAR },
        { name: "C4", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "BMW",
      models: [
        { name: "Série 1", vehicleType: VehicleType.CAR },
        { name: "Série 3", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Mercedes",
      models: [
        { name: "Classe A", vehicleType: VehicleType.CAR },
        { name: "Classe C", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Yamaha",
      models: [
        { name: "MT-07", vehicleType: VehicleType.MOTORCYCLE },
        { name: "XMAX", vehicleType: VehicleType.MOTORCYCLE }
      ]
    },
    {
      name: "Honda",
      models: [
        { name: "Forza", vehicleType: VehicleType.MOTORCYCLE },
        { name: "CB500F", vehicleType: VehicleType.MOTORCYCLE }
      ]
    }
  ];

  for (const brand of brands) {
    const createdBrand = await prisma.vehicleBrand.upsert({
      where: { name: brand.name },
      update: {},
      create: { name: brand.name }
    });

    for (const model of brand.models) {
      await prisma.vehicleModel.upsert({
        where: {
          brandId_name: {
            brandId: createdBrand.id,
            name: model.name
          }
        },
        update: {},
        create: {
          brandId: createdBrand.id,
          name: model.name,
          vehicleType: model.vehicleType
        }
      });
    }
  }

  console.log("Seed terminé.");
  console.log(`Admin local : ${adminEmail}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
SEED_EOF

cat > src/app/globals.css <<'GLOBALS_CSS_EOF'
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
GLOBALS_CSS_EOF

cat > src/app/layout.tsx <<'LAYOUT_EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Parking sécurisé",
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


cat > src/lib/prisma.ts <<'PRISMA_CLIENT_EOF'
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
PRISMA_CLIENT_EOF

cat > src/lib/session.ts <<'SESSION_EOF'
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
SESSION_EOF

cat > src/lib/utils.ts <<'UTILS_EOF'
import { PaymentStatus, RentalStatus, SpotStatus, VehicleType } from "@prisma/client";

export function formatCurrency(value: number | string) {
  const amount = typeof value === "string" ? Number(value) : value;

  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(amount);
}

export function formatDate(value: Date | string | null | undefined) {
  if (!value) {
    return "-";
  }

  return new Intl.DateTimeFormat("fr-FR").format(new Date(value));
}

export function spotStatusLabel(status: SpotStatus) {
  const labels: Record<SpotStatus, string> = {
    AVAILABLE: "Disponible",
    OCCUPIED: "Occupée",
    RESERVED: "Réservée",
    MAINTENANCE: "Maintenance",
    INACTIVE: "Inactive"
  };

  return labels[status];
}

export function spotStatusClass(status: SpotStatus) {
  const classes: Record<SpotStatus, string> = {
    AVAILABLE: "bg-emerald-100 text-emerald-800 border-emerald-200",
    OCCUPIED: "bg-red-100 text-red-800 border-red-200",
    RESERVED: "bg-amber-100 text-amber-800 border-amber-200",
    MAINTENANCE: "bg-slate-200 text-slate-800 border-slate-300",
    INACTIVE: "bg-zinc-100 text-zinc-500 border-zinc-200"
  };

  return classes[status];
}

export function vehicleTypeLabel(type: VehicleType) {
  const labels: Record<VehicleType, string> = {
    CAR: "Voiture",
    MOTORCYCLE: "Deux-roues",
    OTHER: "Autre"
  };

  return labels[type];
}

export function rentalStatusLabel(status: RentalStatus) {
  const labels: Record<RentalStatus, string> = {
    PENDING: "En attente",
    ACTIVE: "Active",
    ENDED: "Terminée",
    CANCELLED: "Annulée"
  };

  return labels[status];
}

export function paymentStatusLabel(status: PaymentStatus) {
  const labels: Record<PaymentStatus, string> = {
    PAID: "Payée",
    UNPAID: "Non payée",
    PARTIAL: "Partielle",
    LATE: "En retard"
  };

  return labels[status];
}
UTILS_EOF




[200~cat > middleware.ts <<'MIDDLEWARE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";

const SESSION_COOKIE_NAME = "parking_admin_session";

function getSecretKey() {
  const secret = process.env.SESSION_SECRET || "dev-secret-change-me-dev-secret-change-me";
  return new TextEncoder().encode(secret);
}

async function isValidSession(request: NextRequest) {
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

  const valid = await isValidSession(request);

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

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*"]
};
MIDDLEWARE_EOF

cat > src/components/admin/AdminShell.tsx <<'ADMIN_SHELL_EOF'
import Link from "next/link";

const links = [
  { href: "/admin/dashboard", label: "Dashboard" },
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
  children
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-slate-100">
      <div className="grid min-h-screen md:grid-cols-[260px_1fr]">
        <aside className="border-r border-slate-200 bg-white p-6">
          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">
              Administration
            </p>
            <h1 className="mt-1 text-xl font-bold text-slate-950">Parking</h1>
          </div>

          <nav className="mt-8 space-y-2">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="block rounded-xl px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <form action="/api/auth/logout" method="post" className="mt-8">
            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white">
              Déconnexion
            </button>
          </form>
        </aside>

        <section className="p-6 md:p-10">
          <div className="mb-8">
            <h2 className="text-3xl font-bold text-slate-950">{title}</h2>
          </div>

          {children}
        </section>
      </div>
    </main>
  );
}
ADMIN_SHELL_EOF

cat > src/app/page.tsx <<'HOME_PAGE_EOF'
import { prisma } from "@/lib/prisma";
import { formatCurrency, vehicleTypeLabel } from "@/lib/utils";

export default async function HomePage({
  searchParams
}: {
  searchParams?: Promise<{ contact?: string }>;
}) {
  const params = searchParams ? await searchParams : {};
  const [settings, services, pricing] = await Promise.all([
    prisma.siteSetting.findFirst(),
    prisma.service.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    }),
    prisma.pricing.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    })
  ]);

  return (
    <main className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
          <a href="/" className="text-xl font-bold text-slate-950">
            {settings?.companyName || "Parking sécurisé"}
          </a>

          <nav className="hidden gap-6 text-sm font-medium text-slate-700 md:flex">
            <a href="#services">Services</a>
            <a href="#tarifs">Tarifs</a>
            <a href="#contact">Contact</a>
            <a href="/admin/login">Admin</a>
          </nav>
        </div>
      </header>

      <section className="mx-auto flex max-w-6xl flex-col items-start justify-center px-6 py-20 md:py-28">
        <p className="mb-4 rounded-full bg-slate-900 px-4 py-2 text-sm font-medium text-white">
          Parking fermé et sécurisé
        </p>

        <h1 className="max-w-4xl text-4xl font-bold tracking-tight text-slate-950 md:text-6xl">
          {settings?.headline || "Location mensuelle de places de parking"}
        </h1>

        <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
          {settings?.description ||
            "Louez une place dans un parking fermé, sécurisé et organisé sur plusieurs étages."}
        </p>

        <div className="mt-8 flex flex-wrap gap-4">
          <a
            href="#contact"
            className="rounded-xl bg-slate-950 px-6 py-3 font-semibold text-white"
          >
            Demander une place
          </a>

          <a
            href="#tarifs"
            className="rounded-xl border border-slate-300 px-6 py-3 font-semibold text-slate-900"
          >
            Voir les tarifs
          </a>
        </div>
      </section>

      <section id="services" className="bg-white py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-slate-950">Nos services</h2>
          <div className="mt-8 grid gap-6 md:grid-cols-3">
            {services.map((service) => (
              <article key={service.id} className="rounded-2xl border border-slate-200 p-6">
                <h3 className="text-xl font-bold text-slate-950">{service.title}</h3>
                <p className="mt-3 text-slate-600">{service.description}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="tarifs" className="py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-slate-950">Tarifs mensuels</h2>
          <div className="mt-8 grid gap-6 md:grid-cols-2">
            {pricing.map((price) => (
              <article key={price.id} className="rounded-2xl bg-white p-6 shadow-sm">
                <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">
                  {vehicleTypeLabel(price.vehicleType)}
                </p>
                <h3 className="mt-2 text-2xl font-bold text-slate-950">{price.title}</h3>
                <p className="mt-3 text-slate-600">{price.description}</p>
                <p className="mt-6 text-3xl font-bold text-slate-950">
                  {formatCurrency(price.priceMonthly.toString())}
                  <span className="text-base font-medium text-slate-500"> / mois</span>
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="contact" className="bg-white py-20">
        <div className="mx-auto grid max-w-6xl gap-10 px-6 md:grid-cols-2">
          <div>
            <h2 className="text-3xl font-bold text-slate-950">Contact</h2>
            <p className="mt-4 text-slate-600">
              Demandez une disponibilité ou posez une question concernant une location mensuelle.
            </p>

            <div className="mt-8 space-y-3 text-slate-700">
              <p><strong>Adresse :</strong> {settings?.address}</p>
              <p><strong>Téléphone :</strong> {settings?.phone}</p>
              <p><strong>Email :</strong> {settings?.email}</p>
              <p><strong>Horaires :</strong> {settings?.openingHours}</p>
            </div>
          </div>

          <form action="/api/contact" method="post" className="rounded-2xl border border-slate-200 p-6">
            {params.contact === "success" && (
              <p className="mb-4 rounded-xl bg-emerald-100 px-4 py-3 text-sm font-medium text-emerald-800">
                Message envoyé avec succès.
              </p>
            )}

            <div className="space-y-4">
              <input name="name" required placeholder="Nom" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
              <input name="email" required type="email" placeholder="Email" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
              <input name="phone" placeholder="Téléphone" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
              <input name="subject" placeholder="Sujet" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
              <textarea name="message" required placeholder="Message" rows={5} className="w-full rounded-xl border border-slate-300 px-4 py-3" />
              <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
                Envoyer
              </button>
            </div>
          </form>
        </div>
      </section>
    </main>
  );
}
HOME_PAGE_EOF

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
      subject: subject || null,
      message
    }
  });

  return NextResponse.redirect(new URL("/?contact=success#contact", request.url), 303);
}
CONTACT_ROUTE_EOF~


cat > src/app/admin/login/page.tsx <<'LOGIN_PAGE_EOF'
export default async function AdminLoginPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : {};

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-100 px-6">
      <section className="w-full max-w-md rounded-2xl bg-white p-8 shadow-sm">
        <h1 className="text-2xl font-bold text-slate-950">Connexion admin</h1>
        <p className="mt-2 text-sm text-slate-600">
          Accès réservé à l’administration du parking.
        </p>

        {params.error && (
          <p className="mt-4 rounded-xl bg-red-100 px-4 py-3 text-sm font-medium text-red-800">
            Identifiants incorrects.
          </p>
        )}

        <form action="/api/auth/login" method="post" className="mt-6 space-y-4">
          <div>
            <label className="text-sm font-medium text-slate-700">Email</label>
            <input
              name="email"
              type="email"
              required
              className="mt-1 w-full rounded-xl border border-slate-300 px-4 py-3"
              placeholder="admin@example.local"
            />
          </div>

          <div>
            <label className="text-sm font-medium text-slate-700">Mot de passe</label>
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
LOGIN_PAGE_EOF

cat > src/app/api/auth/login/route.ts <<'LOGIN_ROUTE_EOF'
import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import { createSessionToken, sessionCookieName } from "@/lib/session";

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
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 8
  });

  return response;
}
LOGIN_ROUTE_EOF

cat > src/app/api/auth/logout/route.ts <<'LOGOUT_ROUTE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { sessionCookieName } from "@/lib/session";

export async function POST(request: NextRequest) {
  const response = NextResponse.redirect(new URL("/admin/login", request.url), 303);

  response.cookies.set(sessionCookieName, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0
  });

  return response;
}
LOGOUT_ROUTE_EOF

cat > src/actions/spots.actions.ts <<'SPOTS_ACTIONS_EOF'
"use server";

import { SpotStatus } from "@prisma/client";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function updateSpotStatus(formData: FormData) {
  const id = String(formData.get("id") || "");
  const status = String(formData.get("status") || "") as SpotStatus;

  if (!id || !Object.values(SpotStatus).includes(status)) {
    return;
  }

  await prisma.parkingSpot.update({
    where: { id },
    data: { status }
  });

  revalidatePath("/admin/spots");
}
SPOTS_ACTIONS_EOF

cat > src/actions/customers.actions.ts <<'CUSTOMERS_ACTIONS_EOF'
"use server";

import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createCustomer(formData: FormData) {
  const firstName = String(formData.get("firstName") || "").trim();
  const lastName = String(formData.get("lastName") || "").trim();
  const email = String(formData.get("email") || "").trim();
  const phone = String(formData.get("phone") || "").trim();
  const address = String(formData.get("address") || "").trim();
  const notes = String(formData.get("notes") || "").trim();

  if (!firstName || !lastName) {
    return;
  }

  await prisma.customer.create({
    data: {
      firstName,
      lastName,
      email: email || null,
      phone: phone || null,
      address: address || null,
      notes: notes || null
    }
  });

  revalidatePath("/admin/customers");
}
CUSTOMERS_ACTIONS_EOF

cat > src/actions/vehicles.actions.ts <<'VEHICLES_ACTIONS_EOF'
"use server";

import { VehicleType } from "@prisma/client";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createVehicle(formData: FormData) {
  const customerId = String(formData.get("customerId") || "");
  const brandId = String(formData.get("brandId") || "");
  const modelId = String(formData.get("modelId") || "");
  const customBrand = String(formData.get("customBrand") || "").trim();
  const customModel = String(formData.get("customModel") || "").trim();
  const vehicleType = String(formData.get("vehicleType") || "") as VehicleType;
  const licensePlate = String(formData.get("licensePlate") || "").trim().toUpperCase();
  const color = String(formData.get("color") || "").trim();

  if (!customerId || !licensePlate || !Object.values(VehicleType).includes(vehicleType)) {
    return;
  }

  await prisma.vehicle.create({
    data: {
      customerId,
      brandId: brandId || null,
      modelId: modelId || null,
      customBrand: customBrand || null,
      customModel: customModel || null,
      vehicleType,
      licensePlate,
      color: color || null
    }
  });

  revalidatePath("/admin/vehicles");
}
VEHICLES_ACTIONS_EOF

cat > src/actions/rentals.actions.ts <<'RENTALS_ACTIONS_EOF'
"use server";

import { PaymentStatus, RentalStatus, SpotStatus } from "@prisma/client";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createRental(formData: FormData) {
  const parkingSpotId = String(formData.get("parkingSpotId") || "");
  const customerId = String(formData.get("customerId") || "");
  const vehicleId = String(formData.get("vehicleId") || "");
  const amountMonthly = Number(formData.get("amountMonthly") || 0);
  const durationMonths = Number(formData.get("durationMonths") || 1);
  const entryDateRaw = String(formData.get("entryDate") || "");
  const paymentStatus = String(formData.get("paymentStatus") || "UNPAID") as PaymentStatus;
  const notes = String(formData.get("notes") || "").trim();

  if (!parkingSpotId || !customerId || !vehicleId || !amountMonthly || !entryDateRaw) {
    return;
  }

  const entryDate = new Date(entryDateRaw);
  const exitDate = new Date(entryDate);
  exitDate.setMonth(exitDate.getMonth() + durationMonths);

  await prisma.$transaction([
    prisma.rental.create({
      data: {
        parkingSpotId,
        customerId,
        vehicleId,
        amountMonthly,
        durationMonths,
        entryDate,
        exitDate,
        status: RentalStatus.ACTIVE,
        paymentStatus,
        notes: notes || null
      }
    }),
    prisma.parkingSpot.update({
      where: { id: parkingSpotId },
      data: { status: SpotStatus.OCCUPIED }
    })
  ]);

  revalidatePath("/admin/rentals");
  revalidatePath("/admin/spots");
  revalidatePath("/admin/dashboard");
}
RENTALS_ACTIONS_EOF

cat > src/actions/services.actions.ts <<'SERVICES_ACTIONS_EOF'
"use server";

import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createService(formData: FormData) {
  const title = String(formData.get("title") || "").trim();
  const description = String(formData.get("description") || "").trim();
  const sortOrder = Number(formData.get("sortOrder") || 0);

  if (!title || !description) {
    return;
  }

  await prisma.service.create({
    data: {
      title,
      description,
      sortOrder
    }
  });

  revalidatePath("/admin/services");
  revalidatePath("/");
}

export async function toggleService(formData: FormData) {
  const id = String(formData.get("id") || "");
  const isActive = String(formData.get("isActive") || "") === "true";

  if (!id) {
    return;
  }

  await prisma.service.update({
    where: { id },
    data: { isActive: !isActive }
  });

  revalidatePath("/admin/services");
  revalidatePath("/");
}
SERVICES_ACTIONS_EOF

cat > src/actions/pricing.actions.ts <<'PRICING_ACTIONS_EOF'
"use server";

import { VehicleType } from "@prisma/client";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createPricing(formData: FormData) {
  const title = String(formData.get("title") || "").trim();
  const description = String(formData.get("description") || "").trim();
  const vehicleType = String(formData.get("vehicleType") || "") as VehicleType;
  const priceMonthly = Number(formData.get("priceMonthly") || 0);
  const sortOrder = Number(formData.get("sortOrder") || 0);

  if (!title || !Object.values(VehicleType).includes(vehicleType) || !priceMonthly) {
    return;
  }

  await prisma.pricing.create({
    data: {
      title,
      description: description || null,
      vehicleType,
      priceMonthly,
      sortOrder
    }
  });

  revalidatePath("/admin/pricing");
  revalidatePath("/");
}

export async function togglePricing(formData: FormData) {
  const id = String(formData.get("id") || "");
  const isActive = String(formData.get("isActive") || "") === "true";

  if (!id) {
    return;
  }

  await prisma.pricing.update({
    where: { id },
    data: { isActive: !isActive }
  });

  revalidatePath("/admin/pricing");
  revalidatePath("/");
}
PRICING_ACTIONS_EOF

cat > src/actions/messages.actions.ts <<'MESSAGES_ACTIONS_EOF'
"use server";

import { MessageStatus } from "@prisma/client";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function updateMessageStatus(formData: FormData) {
  const id = String(formData.get("id") || "");
  const status = String(formData.get("status") || "") as MessageStatus;

  if (!id || !Object.values(MessageStatus).includes(status)) {
    return;
  }

  await prisma.contactMessage.update({
    where: { id },
    data: { status }
  });

  revalidatePath("/admin/messages");
  revalidatePath("/admin/dashboard");
}
MESSAGES_ACTIONS_EOF

cat > 'src/app/admin/(protected)/dashboard/page.tsx' <<'DASHBOARD_PAGE_EOF'
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import { formatCurrency } from "@/lib/utils";

export default async function AdminDashboardPage() {
  const [
    totalSpots,
    availableSpots,
    occupiedSpots,
    activeRentals,
    unreadMessages,
    rentals
  ] = await Promise.all([
    prisma.parkingSpot.count(),
    prisma.parkingSpot.count({ where: { status: "AVAILABLE" } }),
    prisma.parkingSpot.count({ where: { status: "OCCUPIED" } }),
    prisma.rental.count({ where: { status: "ACTIVE" } }),
    prisma.contactMessage.count({ where: { status: "NEW" } }),
    prisma.rental.findMany({ where: { status: "ACTIVE" } })
  ]);

  const monthlyRevenue = rentals.reduce(
    (sum, rental) => sum + Number(rental.amountMonthly),
    0
  );

  const cards = [
    { label: "Places totales", value: totalSpots },
    { label: "Disponibles", value: availableSpots },
    { label: "Occupées", value: occupiedSpots },
    { label: "Locations actives", value: activeRentals },
    { label: "Messages non lus", value: unreadMessages },
    { label: "CA mensuel théorique", value: formatCurrency(monthlyRevenue) }
  ];

  return (
    <AdminShell title="Tableau de bord">
      <div className="grid gap-4 md:grid-cols-3">
        {cards.map((card) => (
          <article key={card.label} className="rounded-2xl bg-white p-6 shadow-sm">
            <p className="text-sm font-semibold text-slate-500">{card.label}</p>
            <p className="mt-3 text-3xl font-bold text-slate-950">{card.value}</p>
          </article>
        ))}
      </div>
    </AdminShell>
  );
}
DASHBOARD_PAGE_EOF

cat > 'src/app/admin/(protected)/spots/page.tsx' <<'SPOTS_PAGE_EOF'
import { SpotStatus } from "@prisma/client";
import { updateSpotStatus } from "@/actions/spots.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import { spotStatusClass, spotStatusLabel } from "@/lib/utils";

export default async function AdminSpotsPage() {
  const floors = await prisma.parkingFloor.findMany({
    orderBy: { levelNumber: "asc" },
    include: {
      spots: {
        orderBy: { spotNumber: "asc" }
      }
    }
  });

  return (
    <AdminShell title="Gestion des places">
      <div className="space-y-8">
        {floors.map((floor) => (
          <section key={floor.id} className="rounded-2xl bg-white p-6 shadow-sm">
            <h3 className="text-xl font-bold text-slate-950">{floor.name}</h3>

            <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-8">
              {floor.spots.map((spot) => (
                <form
                  key={spot.id}
                  action={updateSpotStatus}
                  className={`rounded-xl border p-3 ${spotStatusClass(spot.status)}`}
                >
                  <input type="hidden" name="id" value={spot.id} />
                  <p className="font-bold">Place {spot.spotNumber}</p>
                  <p className="text-xs">{spotStatusLabel(spot.status)}</p>

                  <select
                    name="status"
                    defaultValue={spot.status}
                    className="mt-3 w-full rounded-lg border border-white/60 bg-white px-2 py-1 text-xs text-slate-900"
                  >
                    {Object.values(SpotStatus).map((status) => (
                      <option key={status} value={status}>
                        {spotStatusLabel(status)}
                      </option>
                    ))}
                  </select>

                  <button className="mt-2 w-full rounded-lg bg-white px-2 py-1 text-xs font-semibold text-slate-900">
                    Modifier
                  </button>
                </form>
              ))}
            </div>
          </section>
        ))}
      </div>
    </AdminShell>
  );
}
SPOTS_PAGE_EOF

cat > 'src/app/admin/(protected)/customers/page.tsx' <<'CUSTOMERS_PAGE_EOF'
import { createCustomer } from "@/actions/customers.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";

export default async function AdminCustomersPage() {
  const customers = await prisma.customer.findMany({
    orderBy: { createdAt: "desc" }
  });

  return (
    <AdminShell title="Clients">
      <div className="grid gap-6 lg:grid-cols-[420px_1fr]">
        <form action={createCustomer} className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Ajouter un client</h3>

          <div className="mt-6 space-y-4">
            <input name="firstName" required placeholder="Prénom" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="lastName" required placeholder="Nom" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="email" type="email" placeholder="Email" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="phone" placeholder="Téléphone" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="address" placeholder="Adresse" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <textarea name="notes" placeholder="Notes" rows={4} className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
              Ajouter
            </button>
          </div>
        </form>

        <section className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Liste des clients</h3>

          <div className="mt-6 overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="py-3">Client</th>
                  <th>Email</th>
                  <th>Téléphone</th>
                </tr>
              </thead>
              <tbody>
                {customers.map((customer) => (
                  <tr key={customer.id} className="border-b border-slate-100">
                    <td className="py-3 font-medium">
                      {customer.firstName} {customer.lastName}
                    </td>
                    <td>{customer.email || "-"}</td>
                    <td>{customer.phone || "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
CUSTOMERS_PAGE_EOF

cat > 'src/app/admin/(protected)/vehicles/page.tsx' <<'VEHICLES_PAGE_EOF'
import { VehicleType } from "@prisma/client";
import { createVehicle } from "@/actions/vehicles.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import { vehicleTypeLabel } from "@/lib/utils";

export default async function AdminVehiclesPage() {
  const [vehicles, customers, brands, models] = await Promise.all([
    prisma.vehicle.findMany({
      orderBy: { createdAt: "desc" },
      include: {
        customer: true,
        brand: true,
        model: true
      }
    }),
    prisma.customer.findMany({ orderBy: [{ lastName: "asc" }, { firstName: "asc" }] }),
    prisma.vehicleBrand.findMany({ orderBy: { name: "asc" } }),
    prisma.vehicleModel.findMany({
      orderBy: { name: "asc" },
      include: { brand: true }
    })
  ]);

  return (
    <AdminShell title="Véhicules">
      <div className="grid gap-6 lg:grid-cols-[420px_1fr]">
        <form action={createVehicle} className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Ajouter un véhicule</h3>

          <div className="mt-6 space-y-4">
            <select name="customerId" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Client</option>
              {customers.map((customer) => (
                <option key={customer.id} value={customer.id}>
                  {customer.firstName} {customer.lastName}
                </option>
              ))}
            </select>

            <select name="vehicleType" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Type de véhicule</option>
              {Object.values(VehicleType).map((type) => (
                <option key={type} value={type}>
                  {vehicleTypeLabel(type)}
                </option>
              ))}
            </select>

            <select name="brandId" className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Marque référentiel</option>
              {brands.map((brand) => (
                <option key={brand.id} value={brand.id}>{brand.name}</option>
              ))}
            </select>

            <select name="modelId" className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Modèle référentiel</option>
              {models.map((model) => (
                <option key={model.id} value={model.id}>
                  {model.brand.name} {model.name}
                </option>
              ))}
            </select>

            <input name="customBrand" placeholder="Marque libre si absente" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="customModel" placeholder="Modèle libre si absent" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="licensePlate" required placeholder="Plaque immatriculation" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="color" placeholder="Couleur" className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
              Ajouter
            </button>
          </div>
        </form>

        <section className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Liste des véhicules</h3>

          <div className="mt-6 overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="py-3">Plaque</th>
                  <th>Client</th>
                  <th>Type</th>
                  <th>Marque / modèle</th>
                </tr>
              </thead>
              <tbody>
                {vehicles.map((vehicle) => (
                  <tr key={vehicle.id} className="border-b border-slate-100">
                    <td className="py-3 font-bold">{vehicle.licensePlate}</td>
                    <td>{vehicle.customer.firstName} {vehicle.customer.lastName}</td>
                    <td>{vehicleTypeLabel(vehicle.vehicleType)}</td>
                    <td>
                      {vehicle.brand?.name || vehicle.customBrand || "-"}{" "}
                      {vehicle.model?.name || vehicle.customModel || ""}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
VEHICLES_PAGE_EOF

cat > 'src/app/admin/(protected)/rentals/page.tsx' <<'RENTALS_PAGE_EOF'
import { PaymentStatus } from "@prisma/client";
import { createRental } from "@/actions/rentals.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import {
  formatCurrency,
  formatDate,
  paymentStatusLabel,
  rentalStatusLabel
} from "@/lib/utils";

export default async function AdminRentalsPage() {
  const [rentals, spots, customers, vehicles] = await Promise.all([
    prisma.rental.findMany({
      orderBy: { createdAt: "desc" },
      include: {
        parkingSpot: { include: { floor: true } },
        customer: true,
        vehicle: true
      }
    }),
    prisma.parkingSpot.findMany({
      where: { status: { in: ["AVAILABLE", "RESERVED"] } },
      orderBy: [{ floor: { levelNumber: "asc" } }, { spotNumber: "asc" }],
      include: { floor: true }
    }),
    prisma.customer.findMany({ orderBy: [{ lastName: "asc" }, { firstName: "asc" }] }),
    prisma.vehicle.findMany({
      orderBy: { licensePlate: "asc" },
      include: { customer: true }
    })
  ]);

  return (
    <AdminShell title="Locations">
      <div className="grid gap-6 xl:grid-cols-[430px_1fr]">
        <form action={createRental} className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Créer une location</h3>

          <div className="mt-6 space-y-4">
            <select name="parkingSpotId" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Place</option>
              {spots.map((spot) => (
                <option key={spot.id} value={spot.id}>
                  {spot.floor.name} - Place {spot.spotNumber}
                </option>
              ))}
            </select>

            <select name="customerId" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Client</option>
              {customers.map((customer) => (
                <option key={customer.id} value={customer.id}>
                  {customer.firstName} {customer.lastName}
                </option>
              ))}
            </select>

            <select name="vehicleId" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Véhicule</option>
              {vehicles.map((vehicle) => (
                <option key={vehicle.id} value={vehicle.id}>
                  {vehicle.licensePlate} - {vehicle.customer.firstName} {vehicle.customer.lastName}
                </option>
              ))}
            </select>

            <input name="amountMonthly" required type="number" step="0.01" min="0" placeholder="Montant mensuel" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="durationMonths" required type="number" min="1" defaultValue="1" placeholder="Durée en mois" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="entryDate" required type="date" className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <select name="paymentStatus" defaultValue="UNPAID" className="w-full rounded-xl border border-slate-300 px-4 py-3">
              {Object.values(PaymentStatus).map((status) => (
                <option key={status} value={status}>
                  {paymentStatusLabel(status)}
                </option>
              ))}
            </select>

            <textarea name="notes" placeholder="Notes" rows={4} className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
              Créer la location
            </button>
          </div>
        </form>

        <section className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Locations enregistrées</h3>

          <div className="mt-6 overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="py-3">Place</th>
                  <th>Client</th>
                  <th>Véhicule</th>
                  <th>Montant</th>
                  <th>Entrée</th>
                  <th>Sortie</th>
                  <th>Statut</th>
                  <th>Paiement</th>
                </tr>
              </thead>
              <tbody>
                {rentals.map((rental) => (
                  <tr key={rental.id} className="border-b border-slate-100">
                    <td className="py-3">{rental.parkingSpot.floor.name} - {rental.parkingSpot.spotNumber}</td>
                    <td>{rental.customer.firstName} {rental.customer.lastName}</td>
                    <td>{rental.vehicle.licensePlate}</td>
                    <td>{formatCurrency(rental.amountMonthly.toString())}</td>
                    <td>{formatDate(rental.entryDate)}</td>
                    <td>{formatDate(rental.exitDate)}</td>
                    <td>{rentalStatusLabel(rental.status)}</td>
                    <td>{paymentStatusLabel(rental.paymentStatus)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
RENTALS_PAGE_EOF

cat > 'src/app/admin/(protected)/services/page.tsx' <<'SERVICES_PAGE_EOF'
import { createService, toggleService } from "@/actions/services.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";

export default async function AdminServicesPage() {
  const services = await prisma.service.findMany({
    orderBy: { sortOrder: "asc" }
  });

  return (
    <AdminShell title="Services">
      <div className="grid gap-6 lg:grid-cols-[420px_1fr]">
        <form action={createService} className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Ajouter un service</h3>

          <div className="mt-6 space-y-4">
            <input name="title" required placeholder="Titre" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <textarea name="description" required placeholder="Description" rows={4} className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="sortOrder" type="number" defaultValue="0" placeholder="Ordre" className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
              Ajouter
            </button>
          </div>
        </form>

        <section className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Services existants</h3>

          <div className="mt-6 space-y-3">
            {services.map((service) => (
              <div key={service.id} className="rounded-xl border border-slate-200 p-4">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <h4 className="font-bold text-slate-950">{service.title}</h4>
                    <p className="mt-1 text-sm text-slate-600">{service.description}</p>
                  </div>

                  <form action={toggleService}>
                    <input type="hidden" name="id" value={service.id} />
                    <input type="hidden" name="isActive" value={String(service.isActive)} />
                    <button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">
                      {service.isActive ? "Désactiver" : "Activer"}
                    </button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
SERVICES_PAGE_EOF









cat > 'src/app/admin/(protected)/pricing/page.tsx' <<'PRICING_PAGE_EOF'
import { VehicleType } from "@prisma/client";
import { createPricing, togglePricing } from "@/actions/pricing.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import { formatCurrency, vehicleTypeLabel } from "@/lib/utils";

export default async function AdminPricingPage() {
  const pricing = await prisma.pricing.findMany({
    orderBy: { sortOrder: "asc" }
  });

  return (
    <AdminShell title="Tarifs">
      <div className="grid gap-6 lg:grid-cols-[420px_1fr]">
        <form action={createPricing} className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Ajouter un tarif</h3>

          <div className="mt-6 space-y-4">
            <input name="title" required placeholder="Titre" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <textarea name="description" placeholder="Description" rows={3} className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <select name="vehicleType" required className="w-full rounded-xl border border-slate-300 px-4 py-3">
              <option value="">Type véhicule</option>
              {Object.values(VehicleType).map((type) => (
                <option key={type} value={type}>{vehicleTypeLabel(type)}</option>
              ))}
            </select>

            <input name="priceMonthly" required type="number" step="0.01" min="0" placeholder="Prix mensuel" className="w-full rounded-xl border border-slate-300 px-4 py-3" />
            <input name="sortOrder" type="number" defaultValue="0" placeholder="Ordre" className="w-full rounded-xl border border-slate-300 px-4 py-3" />

            <button className="w-full rounded-xl bg-slate-950 px-4 py-3 font-semibold text-white">
              Ajouter
            </button>
          </div>
        </form>

        <section className="rounded-2xl bg-white p-6 shadow-sm">
          <h3 className="text-xl font-bold text-slate-950">Tarifs existants</h3>

          <div className="mt-6 space-y-3">
            {pricing.map((price) => (
              <div key={price.id} className="rounded-xl border border-slate-200 p-4">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <h4 className="font-bold text-slate-950">{price.title}</h4>
                    <p className="mt-1 text-sm text-slate-600">{vehicleTypeLabel(price.vehicleType)}</p>
                    <p className="mt-2 text-xl font-bold">{formatCurrency(price.priceMonthly.toString())} / mois</p>
                  </div>

                  <form action={togglePricing}>
                    <input type="hidden" name="id" value={price.id} />
                    <input type="hidden" name="isActive" value={String(price.isActive)} />
                    <button className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-semibold">
                      {price.isActive ? "Désactiver" : "Activer"}
                    </button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </AdminShell>
  );
}
PRICING_PAGE_EOF

cat > 'src/app/admin/(protected)/messages/page.tsx' <<'MESSAGES_PAGE_EOF'
import { MessageStatus } from "@prisma/client";
import { updateMessageStatus } from "@/actions/messages.actions";
import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";
import { formatDate } from "@/lib/utils";

export default async function AdminMessagesPage() {
  const messages = await prisma.contactMessage.findMany({
    orderBy: { createdAt: "desc" }
  });

  return (
    <AdminShell title="Messages de contact">
      <section className="rounded-2xl bg-white p-6 shadow-sm">
        <div className="space-y-4">
          {messages.map((message) => (
            <article key={message.id} className="rounded-xl border border-slate-200 p-5">
              <div className="flex flex-col justify-between gap-4 md:flex-row">
                <div>
                  <h3 className="font-bold text-slate-950">{message.name}</h3>
                  <p className="text-sm text-slate-600">{message.email} {message.phone ? `- ${message.phone}` : ""}</p>
                  <p className="mt-2 text-sm font-semibold">{message.subject || "Sans sujet"}</p>
                  <p className="mt-3 text-slate-700">{message.message}</p>
                  <p className="mt-3 text-xs text-slate-500">Reçu le {formatDate(message.createdAt)}</p>
                </div>

                <form action={updateMessageStatus} className="min-w-44">
                  <input type="hidden" name="id" value={message.id} />
                  <select name="status" defaultValue={message.status} className="w-full rounded-xl border border-slate-300 px-3 py-2">
                    {Object.values(MessageStatus).map((status) => (
                      <option key={status} value={status}>{status}</option>
                    ))}
                  </select>
                  <button className="mt-2 w-full rounded-xl bg-slate-950 px-3 py-2 text-sm font-semibold text-white">
                    Modifier
                  </button>
                </form>
              </div>
            </article>
          ))}

          {messages.length === 0 && (
            <p className="text-slate-600">Aucun message pour le moment.</p>
          )}
        </div>
      </section>
    </AdminShell>
  );
}
MESSAGES_PAGE_EOF

cat > src/types/index.ts <<'TYPES_EOF'
export type SelectOption = {
  label: string;
  value: string;
};
TYPES_EOF

cat > README.md <<'README_EOF'
# Parking Rental App

Application web de location mensuelle de places de parking.

## Fonctionnalités

- Site vitrine public
- Tarifs dynamiques
- Formulaire de contact
- Interface d'administration sécurisée
- Authentification admin avec mot de passe hashé
- Gestion des places par étage
- 3 étages de 40 places, soit 120 places
- Gestion clients
- Gestion véhicules
- Référentiel marques et modèles
- Gestion locations
- Gestion services
- Gestion tarifs
- Gestion messages de contact

## Stack

- Next.js
- TypeScript
- PostgreSQL
- Prisma
- Docker Compose
- Tailwind CSS

## Installation

1. Copier le fichier d'environnement :

    cp .env.example .env

2. Modifier les secrets :

    nano .env

À modifier impérativement :

    SESSION_SECRET
    POSTGRES_PASSWORD
    DATABASE_URL
    ADMIN_EMAIL
    ADMIN_PASSWORD

Attention : le mot de passe dans DATABASE_URL doit être le même que POSTGRES_PASSWORD.

3. Lancer le projet :

    docker compose up -d --build

4. Voir les logs :

    docker compose logs -f app

## Accès

Site public :

    http://localhost:3000

Administration :

    http://localhost:3000/admin/login

## Git

Initialiser le dépôt :

    git init
    git add .
    git commit -m "chore: initial parking rental app"

Ajouter le remote GitHub :

    git remote add origin git@github.com:TON_USER/parking-rental-app.git
    git branch -M main
    git push -u origin main

## Commandes utiles

Arrêter :

    docker compose down

Redémarrer :

    docker compose up -d --build

Shell PostgreSQL :

    docker compose exec postgres psql -U parking_user -d parking_rental

Réinitialiser complètement la base :

    docker compose down -v
    docker compose up -d --build

## Notes sécurité

- Ne jamais versionner .env
- Changer ADMIN_PASSWORD
- Changer SESSION_SECRET
- Ne pas exposer PostgreSQL publiquement
- Mettre un reverse proxy HTTPS devant l'application en production
README_EOF

if command -v git >/dev/null 2>&1; then
  git init
  git add .
  git commit -m "chore: initial parking rental app" || true
else
  echo "Git n'est pas installé, dépôt non initialisé."
fi

echo ""
echo "Projet créé avec succès : ${PROJECT_NAME}"
echo ""
echo "Commandes suivantes :"
echo "cd ${PROJECT_NAME}"
echo "cp .env.example .env"
echo "nano .env"
echo "docker compose up -d --build"
echo ""
echo "Puis accès :"
echo "http://localhost:3000"
echo "http://localhost:3000/admin/login"
