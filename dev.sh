#!/bin/bash
# dev.sh — Startup checklist de sesión Medaliq
# Correr antes de abrir claude en cualquier repo del proyecto

echo "=== Medaliq Dev Session ==="

# 1. Docker
if docker ps | grep -q medaliq-db; then
  echo "✓ DB: medaliq-db corriendo"
else
  echo "→ Iniciando medaliq-db..."
  docker start medaliq-db && echo "✓ DB: medaliq-db iniciado" || echo "✗ Error al iniciar medaliq-db — verifica Docker Desktop"
fi

# 2. Branch status — web
echo ""
echo "--- MEDALIQ-PROJECT ---"
cd "$(dirname "$0")/MEDALIQ-PROJECT"
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"
if [ "$BRANCH" != "develop" ] && [[ "$BRANCH" != feature/* ]] && [[ "$BRANCH" != bugfix/* ]]; then
  echo "⚠ No estás en develop ni en feature/* — verifica antes de trabajar"
else
  echo "✓ Git flow correcto"
fi
git status --short | grep -q . && echo "⚠ Hay cambios sin commitear" || echo "✓ Working tree limpio"

# 3. Branch status — mobile
echo ""
echo "--- MEDALIQ-MOBILE ---"
cd "$(dirname "$0")/MEDALIQ-MOBILE"
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"
if [ "$BRANCH" != "develop" ] && [[ "$BRANCH" != feature/* ]] && [[ "$BRANCH" != bugfix/* ]]; then
  echo "⚠ No estás en develop ni en feature/* — verifica antes de trabajar"
else
  echo "✓ Git flow correcto"
fi
git status --short | grep -q . && echo "⚠ Hay cambios sin commitear" || echo "✓ Working tree limpio"

echo ""
echo "=== Listo. Abre claude en el repo que corresponda ==="
