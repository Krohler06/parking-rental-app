#!/usr/bin/env sh
set -e

echo "Application parking : initialisation Prisma..."
npx prisma db push

echo "Application parking : seed base de données..."
npx prisma db seed || true

echo "Application parking : démarrage Next.js..."
node server.js
