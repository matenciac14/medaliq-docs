#!/usr/bin/env bash
# wt.sh — Gestion de worktrees para Medaliq
# Uso:
#   ./wt.sh new <nombre>        Crea worktree desde develop
#   ./wt.sh list                Lista worktrees activos
#   ./wt.sh done <nombre>       Elimina worktree (contexto se preserva en contexts/)
#   ./wt.sh ctx <nombre>        Muestra el contexto de una feature
#   ./wt.sh help                Muestra este mensaje

set -e

BASE_DIR="/Users/miguelatencia/Desktop/FACTORY_AI_SOFTWARE/MEDALIQ"
PROJECT_DIR="$BASE_DIR/MEDALIQ-PROJECT"
MOBILE_DIR="$BASE_DIR/MEDALIQ-MOBILE"
CONTEXTS_DIR="$BASE_DIR/contexts"
SOURCE_BRANCH="develop"

new() {
  local name="$1"
  local type="${2:-feature}"   # segundo arg opcional: feature | bugfix | chore | hotfix
  if [ -z "$name" ]; then
    echo "Uso: ./wt.sh new <nombre> [tipo]"
    echo "Tipos: feature (default) | bugfix | chore | hotfix"
    echo "Ejemplo: ./wt.sh new coach-payments"
    echo "Ejemplo: ./wt.sh new 45-fix-payment bugfix"
    exit 1
  fi

  local branch="$type/$name"
  local dir="$BASE_DIR/medaliq-$name"
  local ctx_file="$CONTEXTS_DIR/$name.md"

  echo "Creando worktree: $dir"
  echo "Branch: $branch (desde $SOURCE_BRANCH)"
  echo ""

  # Verificar que la rama base existe; si no, crearla desde main
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$SOURCE_BRANCH"; then
    echo "La rama '$SOURCE_BRANCH' no existe localmente. Creándola desde 'main'..."
    git -C "$PROJECT_DIR" checkout -b "$SOURCE_BRANCH" main
    git -C "$PROJECT_DIR" push -u origin "$SOURCE_BRANCH"
    git -C "$PROJECT_DIR" checkout -
    echo "'$SOURCE_BRANCH' creada y pusheada a origin."
    echo ""
  fi

  # Si el branch ya existe (retomando feature), no usar -b
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$PROJECT_DIR" worktree add "$dir" "$branch"
  else
    git -C "$PROJECT_DIR" worktree add -b "$branch" "$dir" "$SOURCE_BRANCH"
  fi

  # Copiar .env.local al nuevo worktree
  if [ -f "$PROJECT_DIR/.env.local" ]; then
    cp "$PROJECT_DIR/.env.local" "$dir/.env.local"
    echo ".env.local copiado"
  fi

  # Crear contexto si no existe, o cargar el existente
  if [ ! -f "$ctx_file" ]; then
    cp "$CONTEXTS_DIR/_template.md" "$ctx_file"
    sed -i '' "s/\[nombre-feature\]/$name/" "$ctx_file"
    echo "Contexto nuevo creado: contexts/$name.md"
  else
    echo "Contexto existente encontrado: contexts/$name.md"
  fi

  # Siempre poner el contexto en el worktree como CLAUDE.worktree.md
  cp "$ctx_file" "$dir/CLAUDE.worktree.md"

  # Instalar dependencias en el worktree
  echo "Instalando dependencias..."
  (cd "$dir" && pnpm install --frozen-lockfile --silent)
  echo "Dependencias instaladas"

  echo ""
  echo "Listo. Para empezar:"
  echo ""
  echo "  cd $dir"
  echo "  claude"
  echo ""
  if grep -q "^\- \[ \] Sin empezar" "$ctx_file"; then
    echo "  IMPORTANTE: Edita contexts/$name.md con el scope antes de arrancar"
  else
    echo "  Contexto previo cargado — revisa contexts/$name.md para retomar donde quedaste"
  fi
  echo ""
  echo "  NOTA: Si esta feature toca MEDALIQ-MOBILE, editar directamente en:"
  echo "  $MOBILE_DIR  (no hay aislamiento de worktree para mobile)"
  echo ""
}

list() {
  echo "=== Worktrees activos ==="
  git -C "$PROJECT_DIR" worktree list
  echo ""
  echo "=== Contextos disponibles ==="
  ls "$CONTEXTS_DIR" | grep -v "^_" || echo "(sin contextos guardados)"
}

done_wt() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Uso: ./wt.sh done <nombre>"
    exit 1
  fi

  local dir="$BASE_DIR/medaliq-$name"
  # Detectar el branch real del worktree (puede ser feature/, bugfix/, etc.)
  local branch
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local ctx_file="$CONTEXTS_DIR/$name.md"

  # Verificar cambios sin commitear
  local dirty
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | grep -v "CLAUDE.worktree.md" | wc -l | tr -d ' ')
  if [ "$dirty" -gt 0 ]; then
    echo "ADVERTENCIA: hay $dirty archivo(s) con cambios sin commitear en el worktree."
    echo "¿Continuar y perder esos cambios? [s/N]"
    read -r confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
      echo "Cancelado. Haz commit primero."
      exit 1
    fi
  fi

  # Verificar commits sin pushear
  local unpushed=0
  if git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    unpushed=$(git -C "$dir" log "origin/$branch..$branch" --oneline | wc -l | tr -d ' ')
  else
    # Branch nunca pusheado — contar solo commits sobre develop (no el historial completo)
    unpushed=$(git -C "$dir" rev-list --count "$SOURCE_BRANCH..HEAD" 2>/dev/null || echo "0")
  fi
  if [ "$unpushed" -gt 0 ]; then
    echo "ADVERTENCIA: hay $unpushed commit(s) sin pushear en $branch."
    echo "¿Continuar y eliminar el worktree de todas formas? [s/N]"
    read -r confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
      echo "Cancelado. Haz push primero: git push -u origin $branch"
      exit 1
    fi
  fi

  # Sincronizar CLAUDE.worktree.md de vuelta a contexts/ antes de borrar
  if [ -f "$dir/CLAUDE.worktree.md" ]; then
    cp "$dir/CLAUDE.worktree.md" "$ctx_file"
    echo "Contexto guardado en contexts/$name.md"
  fi

  echo "Eliminando worktree: $dir"
  git -C "$PROJECT_DIR" worktree remove "$dir" --force 2>/dev/null || true
  git -C "$PROJECT_DIR" branch -d "$branch" 2>/dev/null || echo "Branch $branch no eliminado (puede tener cambios sin mergear)"
  git -C "$PROJECT_DIR" worktree prune
  echo "Listo. Contexto preservado en contexts/$name.md"
}

ctx() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Contextos disponibles:"
    ls "$CONTEXTS_DIR" | grep -v "^_" || echo "(sin contextos guardados)"
    exit 0
  fi
  local ctx_file="$CONTEXTS_DIR/$name.md"
  if [ -f "$ctx_file" ]; then
    cat "$ctx_file"
  else
    echo "No existe contexto para '$name'"
    echo "Contextos disponibles:"
    ls "$CONTEXTS_DIR" | grep -v "^_" || echo "(sin contextos guardados)"
  fi
}

help() {
  echo ""
  echo "wt.sh — Worktrees para Medaliq"
  echo ""
  echo "  ./wt.sh new <nombre> [tipo]   Crea worktree <tipo>/<nombre> desde develop"
  echo "                                tipos: feature (default) | bugfix | chore | hotfix"
  echo "  ./wt.sh list             Lista worktrees activos y contextos disponibles"
  echo "  ./wt.sh done <nombre>    Elimina worktree — contexto se preserva en contexts/"
  echo "  ./wt.sh ctx <nombre>     Muestra el contexto de una feature"
  echo "  ./wt.sh ctx              Lista todos los contextos disponibles"
  echo ""
  echo "Ejemplos:"
  echo "  ./wt.sh new coach-payments"
  echo "  ./wt.sh ctx coach-payments"
  echo "  ./wt.sh done coach-payments"
  echo ""
}

case "$1" in
  new)   new "$2" "$3" ;;
  list)  list ;;
  done)  done_wt "$2" ;;
  ctx)   ctx "$2" ;;
  help)  help ;;
  *)     help ;;
esac
