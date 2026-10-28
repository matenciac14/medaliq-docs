# Guía de onboarding — Medaliq (web + mobile + AI)

## 1. El ecosistema

Medaliq son **3 piezas** que trabajan juntas:

```
/MEDALIQ/
  CLAUDE.md                    ← producto, actores, pricing, scope
  MEDALIQ-PROJECT/             ← Backend + Web (Next.js 16)
    CLAUDE.md                  ← stack web, auth, arquitectura, reglas
    prisma/schema.prisma       ← schema DB (fuente de verdad)
    src/app/admin/roadmap/     ← roadmap compartido web+mobile
  MEDALIQ-MOBILE/              ← App iOS/Android (React Native + Expo)
    CLAUDE.md                  ← stack mobile, pantallas, endpoints
  domains/                     ← 12 domain docs (QUÉ hace el sistema)
  specs/                       ← 19 specs (CÓMO está implementado)
```

**Regla fundamental**: una feature de atleta no está completa hasta que existe en mobile.

---

## 2. Entender el producto (5 min)

Leer en este orden:

| # | Archivo | Qué te da |
|---|---------|-----------|
| 1 | `/MEDALIQ/CLAUDE.md` | Qué es Medaliq, actores, pricing, scope |
| 2 | `/MEDALIQ/MEDALIQ-PROJECT/CLAUDE.md` | Stack web, auth, arquitectura, convenciones |
| 3 | `/MEDALIQ/MEDALIQ-MOBILE/CLAUDE.md` | Stack mobile, pantallas, patrones RN |
| 4 | `/MEDALIQ/domains/flujos-por-actor.md` | Qué puede hacer cada actor (Free/Pro/B2B/Coach/Admin) |

Con esos 4 archivos tienes el 80% del contexto.

---

## 3. Stack por proyecto

### Web — MEDALIQ-PROJECT
| Capa | Tecnología |
|------|-----------|
| Framework | Next.js 16 · React 19 · TypeScript 5 |
| DB | PostgreSQL + Prisma 7 (PrismaPg adapter) |
| Estilos | Tailwind CSS v4 |
| Auth | Auth.js v5 (JWT + Google OAuth) |
| Email | Resend |
| Rate limit | Upstash Redis (fallback in-memory en dev) |
| Tests | Vitest + Playwright |
| Package manager | pnpm |

### Mobile — MEDALIQ-MOBILE
| Capa | Tecnología |
|------|-----------|
| Framework | React Native + Expo ~54 (managed workflow) |
| Routing | Expo Router v6 (file-based) |
| Estilos | NativeWind v4 (Tailwind en RN) |
| Server state | @tanstack/react-query v5 |
| Global state | Zustand v4 |
| Auth | JWT jose (expo-secure-store) |
| Push | expo-notifications |

---

## 4. Arquitectura

### Backend (hexagonal)
```
src/
  domain/              ← lógica pura, SIN Prisma/Next.js
    <modulo>/           ← use_case.ts, types.ts
    ports/              ← interfaces (repository.ts)
  infrastructure/
    db/                 ← repositorios Prisma
    email/              ← Resend
    billing/            ← Wompi
  app/api/              ← rutas delgadas (~25 líneas)
  lib/                  ← utilidades compartidas
```

**Regla**: `domain/` nunca importa Prisma. `app/api/` nunca tiene lógica de negocio.

### Dos sistemas de auth
| | Web | Mobile |
|--|-----|--------|
| Librería | Auth.js v5 | JWT jose |
| Cómo se usa | `auth()` → session | `getMobileUser(req)` |
| Rutas | `/api/*` | `/api/mobile/*` |
| Storage | Cookie | expo-secure-store |
| Token | Session JWT | Bearer 30 días |

### Mobile — flujo de datos
```
Screen → useQuery(queryFn) → apiFetch() → /api/mobile/* → backend
         useMutation()       ↑ Bearer token
                             ↑ X-Client: medaliq-mobile
                             ↑ X-Timezone (en GETs)
```

---

## 5. Relación web ↔ mobile

60+ endpoints tienen **par web/mobile** que deben estar sincronizados:

```
/api/athlete/checkin     ↔  /api/mobile/checkin
/api/athlete/gym/...     ↔  /api/mobile/gym/...
/api/messages            ↔  /api/mobile/messages
```

**Spec clave**: `specs/_mobile_mirror.spec.md` — lista todos los pares y sus diferencias (schemas, response shapes).

**Diferencias comunes**:
- Auth: web usa `auth()`, mobile usa `getMobileUser(req)`
- Rate limits: mobile tiene rate limits explícitos, web algunos no
- Feature gates: mobile usa `requireFeature()` que retorna 402 si el tier no tiene acceso
- Response shapes: a veces difieren (ej. `/messages/read` → web: `{marked}`, mobile: `{ok}`)

---

## 6. Sistema de documentación (SDD)

3 capas que se complementan:

```
Domain docs (QUÉ)     →  /MEDALIQ/domains/*.md        (12 archivos)
Specs (CÓMO)           →  /MEDALIQ/specs/*.spec.md     (19 archivos)
Roadmap (QUÉ FALTA)   →  src/app/admin/roadmap/roadmap_data.ts
```

### Cuándo leer qué

| Si vas a tocar... | Lee el domain doc | Lee la spec |
|-------------------|------------------|-------------|
| Nutrición | `nutricion.md` | `nutrition_tracking.spec.md` / `nutrition_plans.spec.md` |
| Gym | `entrenamiento.md` | `gym.spec.md` |
| Plan/Check-in | `plan.md` | `plan_checkin.spec.md` / `plan_sessions.spec.md` |
| Auth/Seguridad | `seguridad.md` | `auth.spec.md` |
| Coach panel | `coach.md` | `coach_athletes.spec.md` / `coach_gym.spec.md` |
| Billing | `pagos.md` | `billing.spec.md` |
| Mensajes | — | `messages.spec.md` |

**Siempre antes de tocar código**: lee `specs/_traps.spec.md` — 15 trampas transversales.

**Si toca web Y mobile**: lee `specs/_mobile_mirror.spec.md`.

---

## 7. Flujo de trabajo con la AI

### Formato óptimo para pedir tareas

```
## Tarea
[Qué quieres — 1-2 oraciones]

## Spec
[Nombre de la spec, o "sin spec"]

## Archivos (si los conoces)
[Paths relevantes]

## Actual vs esperado
[Actual]: X pasa
[Esperado]: Y debería pasar

## Restricciones
- Solo web / solo mobile / ambos
- No tocar Z
```

### Lo que la AI hace automáticamente

1. Lee los `CLAUDE.md` del proyecto activo
2. Lee la spec y domain doc del módulo
3. Implementa siguiendo la arquitectura hexagonal
4. **Al terminar**: actualiza roadmap + domain docs + agrega tests
5. Si toca web Y mobile → verifica mirror pairs

### Lo que la AI NO hace sin que se lo pidas

- No crea migraciones DB
- No agrega dependencias npm
- No toca auth (`session_mappers.ts`, `middleware.ts`, `mobile_auth.ts`)
- No modifica `schema.prisma`
- No implementa features nuevas complejas sin spec aprobada

### Skills que la AI carga automáticamente

| Contexto | Skill |
|----------|-------|
| React Native / Expo | `react-native-architecture` |
| Prisma / DB | `prisma-development` |
| UI web nueva | `frontend-design` |
| Feature compleja | `feature-dev` |
| Figma | `figma-use` + `figma-generate-design` |

---

## 8. Workflow de desarrollo

### Feature nueva
```
1. Revisar roadmap → buscar si ya está planificada
2. Crear branch: feature/<n>-descripcion-kebab-case
3. Si es compleja → AI genera spec con _template.spec.md → apruebas → implementa
4. Si es simple → AI implementa directo
5. Web: tests con Vitest
6. Mobile: verificar en simulador/dispositivo
7. PR a develop → merge → PR a main → Vercel deploy (web) / EAS build (mobile)
```

### Bug fix
```
1. Reproducir el bug (indicar si es web, mobile o ambos)
2. AI lee código, identifica el problema
3. Fix + test que cubre el caso
4. Si el bug está en un endpoint con mirror → verificar que el otro también está bien
```

### Worktrees (features aisladas — solo web)
```bash
./wt.sh <nombre>   # crea worktree en /MEDALIQ/medaliq-<nombre>/
# Mobile es COMPARTIDO — solo un worktree puede tener cambios mobile a la vez
```

---

## 9. Archivos clave para navegar rápido

### Web
| Si necesitas... | Ve a... |
|-----------------|---------|
| Schema DB | `prisma/schema.prisma` |
| Roadmap | `src/app/admin/roadmap/roadmap_data.ts` |
| Auth web | `src/auth.ts` + `lib/auth/session_mappers.ts` |
| Auth mobile | `lib/auth/mobile_auth.ts` |
| Feature flags | `lib/guards/feature_gate.ts` + `domain/subscription/tier_features.ts` |
| Singleton Prisma | `lib/db/prisma.ts` |
| Fórmulas (Karvonen, TDEE) | `lib/core/athlete_formulas.ts` |
| Labels español | `lib/labels/enum_labels.ts` |

### Mobile
| Si necesitas... | Ve a... |
|-----------------|---------|
| API client + token | `src/api/client.ts` |
| Auth store | `src/store/auth.ts` |
| Gym session state | `src/store/gymSession.ts` + `gymSessionDraft.ts` |
| Todas las API calls | `src/api/*.ts` (auth, gym, nutrition, plan, etc.) |
| Tabs layout | `app/(app)/(tabs)/_layout.tsx` |
| Boot/splash | `app/index.tsx` |
| Push listener | `app/(app)/_layout.tsx` |

---

## 10. Correr los proyectos

### Web
```bash
cd MEDALIQ-PROJECT
pnpm install
cp .env.example .env.local    # llenar variables
pnpm prisma db push           # sincronizar schema
pnpm prisma db seed           # datos de prueba
pnpm dev                      # http://localhost:3000
pnpm test                     # 113 archivos / 1518 tests
```

### Mobile
```bash
cd MEDALIQ-MOBILE
pnpm install
# .env con EXPO_PUBLIC_API_URL apuntando al backend
npx expo start                # Expo Go o simulador
```

### Credenciales de prueba
```
admin@medaliq.com / admin123!    → ADMIN
coach@medaliq.com / coach123     → COACH
miguel@medaliq.com / atleta123   → ATHLETE B2C
ana@medaliq.com / atleta123      → ATHLETE B2B
```

---

## 11. Números del sistema

| Métrica | Valor |
|---------|-------|
| Endpoints web atleta | ~45 |
| Endpoints mobile | **75** |
| Endpoints coach (web-only) | ~70 |
| Endpoints admin | 15 |
| Mirror pairs web↔mobile | 60+ |
| Specs | 19 archivos |
| Domain docs | 12 archivos |
| Test files | **113** |
| Tests totales | **1,518** |

---

## Resumen: tu primer día

1. Lee los 4 archivos de contexto (CLAUDE.md raíz + web + mobile + flujos-por-actor)
2. Lee `schema.prisma` por encima
3. Lee `_traps.spec.md`
4. Abre el roadmap para ver qué está pendiente
5. Elige una tarea y pídela a la AI con el formato del punto 7

Todo lo demás lo lees bajo demanda cuando toques un módulo específico.
