# Worktrees + Claude — Guía de uso

## Setup inicial (solo una vez)

```bash
cd /Users/miguelatencia/Desktop/MEDALIQ
ls -la wt.sh
./wt.sh list
```

---

## Crear y trabajar en una feature

```bash
# Crear el worktree
cd /Users/miguelatencia/Desktop/MEDALIQ
./wt.sh new <nombre>

# Ir al worktree
cd /Users/miguelatencia/Desktop/MEDALIQ/medaliq-<nombre>
# pnpm install se corre automáticamente en wt.sh new — no es necesario hacerlo manualmente

# Editar el scope antes de arrancar Claude
open CLAUDE.worktree.md

# Arrancar Claude
claude
```

---

## Flujo de branches

```
main (prod)
 └── develop (integración)
       ├── feature/<nombre>   ← ./wt.sh new <nombre>
       ├── bugfix/<nombre>    ← ./wt.sh new <nombre> bugfix
       └── hotfix/<nombre>    ← ./wt.sh new <nombre> hotfix
```

- El worktree crea el branch desde `develop` automáticamente
- Al terminar → PR del branch → `develop`
- Miguel revisa que no rompa otros dominios → mergea a `develop`
- Cuando el ciclo está listo → PR de `develop` → `main` → auto-deploy

## Git dentro del worktree (igual que siempre)

```bash
git branch          # confirmar en qué branch estás (feature/ | bugfix/ | hotfix/)
git status
git add src/...
git commit -m "feat: descripcion"
git push origin <tipo>/<nombre>   # PR va a develop, nunca a main
```

---

## Al terminar la sesión (sin terminar la feature)

```bash
cd /Users/miguelatencia/Desktop/MEDALIQ
./wt.sh done <nombre>
# guarda el contexto en contexts/<nombre>.md y elimina el directorio
```

---

## Retomar la feature otro día

```bash
cd /Users/miguelatencia/Desktop/MEDALIQ
./wt.sh new <nombre>              # si era feature (default)
./wt.sh new <nombre> bugfix       # si era bugfix — MISMO tipo que en la sesión original
./wt.sh new <nombre> hotfix       # si era hotfix
# detecta contexts/<nombre>.md y lo carga automáticamente

cd /Users/miguelatencia/Desktop/MEDALIQ/medaliq-<nombre>
claude
```

> Si pasas el tipo equivocado, el script crea un branch nuevo en vez de retomar el existente.

---

## Ver contextos guardados

```bash
./wt.sh ctx               # lista todos
./wt.sh ctx <nombre>      # muestra uno específico
./wt.sh list              # worktrees activos + contextos disponibles
```

---

## Features que tocan mobile

`MEDALIQ-MOBILE` es un repo separado — **no entra en el worktree**. Los cambios mobile se hacen directamente en:
```
/Users/miguelatencia/Desktop/MEDALIQ/MEDALIQ-MOBILE/
```

Si dos features requieren cambios mobile en paralelo, coordinar manualmente — no hay aislamiento de worktree para mobile. En la práctica, los cambios mobile de features distintas raramente colisionan porque cada screen vive en su propio archivo.

---

## Trabajar en paralelo (dos features al mismo tiempo)

```bash
# Tab 1 de Warp
cd /Users/miguelatencia/Desktop/MEDALIQ && ./wt.sh new <feature-a>
cd medaliq-<feature-a> && claude

# Tab 2 de Warp
cd /Users/miguelatencia/Desktop/MEDALIQ && ./wt.sh new <feature-b>
cd medaliq-<feature-b> && claude
```

---

## Referencia rápida wt.sh

| Comando | Qué hace |
|---------|----------|
| `./wt.sh new <nombre>` | Crea worktree `feature/<nombre>` desde `develop` |
| `./wt.sh new <nombre> bugfix` | Crea worktree `bugfix/<nombre>` desde `develop` |
| `./wt.sh new <nombre> hotfix` | Crea worktree `hotfix/<nombre>` desde `develop` |
| `./wt.sh list` | Lista worktrees activos y contextos guardados |
| `./wt.sh done <nombre>` | Guarda contexto y elimina el worktree |
| `./wt.sh ctx` | Lista todos los contextos de features |
| `./wt.sh ctx <nombre>` | Muestra el contexto de una feature |

---

## Cómo funciona el contexto

```
CLAUDE.md (raíz)                → producto, negocio, arquitectura general
MEDALIQ-PROJECT/CLAUDE.md       → stack web, patrones, auth, middleware
MEDALIQ-PROJECT/CLAUDE-SCHEMA.md → DB, enums, mapeos (cargar si toca migraciones)
MEDALIQ-MOBILE/CLAUDE.md        → stack mobile, screens, endpoints
CLAUDE.worktree.md              → scope de ESTA feature (se carga del contexts/ guardado)
```

Claude carga los CLAUDE.md automáticamente al arrancar en cada directorio.
El CLAUDE.worktree.md define solo el scope y el estado de la feature actual.

> **Nota:** `MEDALIQ-PROJECT/CLAUDE.md` y `MEDALIQ-PROJECT/CLAUDE-SCHEMA.md` son archivos **locales** — están gitignoreados y no se pushean. En una máquina nueva hay que recuperarlos del historial de git: `git show <commit-antes-del-rm>:CLAUDE.md > CLAUDE.md`

---

## Modelo agentico

```
Tú (orquestador — decides qué se construye)
│
├── Tab 1: /MEDALIQ-PROJECT       → Claude principal, develop, hotfixes
├── Tab 2: /medaliq-<feature-a>   → Claude agente A, scope definido en CLAUDE.worktree.md
└── Tab 3: /medaliq-<feature-b>   → Claude agente B, scope independiente
```

Dentro de cada sesión, Claude puede lanzar subagentes en paralelo para web + mobile + DB simultáneo.
