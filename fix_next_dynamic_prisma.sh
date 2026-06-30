#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/opt/gambetta_park"

cd "${PROJECT_DIR}"

echo "Patch Next.js : forcer le rendu dynamique sur les pages utilisant Prisma"

add_dynamic_flag() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return
  fi

  if grep -q 'export const dynamic = "force-dynamic"' "$file"; then
    echo "Déjà patché : $file"
    return
  fi

  tmp_file="$(mktemp)"

  {
    echo 'export const dynamic = "force-dynamic";'
    echo 'export const revalidate = 0;'
    echo ''
    cat "$file"
  } > "$tmp_file"

  mv "$tmp_file" "$file"

  echo "Patché : $file"
}

# Patch toutes les pages Next.js qui importent Prisma
find src/app -type f -name "page.tsx" | while read -r file; do
  if grep -q '@/lib/prisma' "$file"; then
    add_dynamic_flag "$file"
  fi
done

# Patch explicite des pages importantes, même si Prisma n'est pas détecté
add_dynamic_flag "src/app/page.tsx"
add_dynamic_flag "src/app/admin/dashboard/page.tsx"

echo ""
echo "Vérification des flags dynamiques :"
grep -R 'export const dynamic = "force-dynamic"' src/app || true

echo ""
echo "Nettoyage et rebuild Docker..."
docker compose down --remove-orphans || true
docker compose build --no-cache app
docker compose up -d

echo ""
echo "État des containers :"
docker compose ps

echo ""
echo "Logs app :"
docker compose logs --tail=80 app

echo ""
echo "Tests HTTP :"
sleep 5
curl -I http://127.0.0.1:3020/ || true
curl -I http://127.0.0.1:3020/admin/login || true
curl -I http://127.0.0.1:3020/admin/dashboard || true

echo ""
echo "Patch terminé."
