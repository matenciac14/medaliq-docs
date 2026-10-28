# MOBILE MIRROR — Indice de pares web <-> mobile

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-02.
> REGLA: al corregir un bug en web, buscar el mirror mobile y aplicar el mismo fix (y viceversa).

---

## Contratos de la AI

- [ ] SIEMPRE buscar el par antes de terminar un fix: `Glob src/app/api/mobile/**/route.ts` o `src/app/api/athlete/**/route.ts`
- [ ] Auth difiere en TODOS los pares: web usa `auth()` (Auth.js cookie), mobile usa `getMobileUser()` (jose JWT)
- [ ] Mobile aplica `rateLimitAsync` universalmente; web lo aplica inconsistentemente
- [ ] Mobile aplica `requireFeature()` guards; web verifica `session.user.features?.X` inline o no verifica
- [ ] Algunos modulos NO tienen par web REST — web usa RSC (server components con Prisma directo)

---

## Divergencias sistematicas (aplican a TODOS los pares)

| Aspecto | Web | Mobile |
|---------|-----|--------|
| Auth | `auth()` — Auth.js v5 cookie | `getMobileUser(req)` — jose JWT Bearer |
| Rate limit | Inconsistente (algunos si, otros no) | Universal (`rateLimitAsync`) |
| Feature gates | `session.user.features?.X` inline | `requireFeature(mobile.features, 'X')` |
| Response en error auth | Redirect a `/login` o 401 | 401 JSON |

---

## Pares confirmados

### Auth

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `POST /api/auth/login` (Auth.js credentials) | `POST /api/mobile/auth/login` | Mobile: JWT jose 30d. Web: Auth.js cookie session |
| Auth.js Google provider | `POST /api/mobile/auth/google` | Mobile-only REST. Intercambia Google ID token por JWT interno |
| Auth.js auto-refresh | `POST /api/mobile/auth/refresh` | Mobile-only. Refresca JWT con features frescas |
| Auth.js post-OAuth callback | `POST /api/mobile/auth/set-role` | Mobile-only. Asigna ATHLETE/COACH post-Google |
| `GET /api/auth/session` (Auth.js) | `GET /api/mobile/auth/me` | Mobile-only REST. Devuelve user + features desde JWT |
| — | `PATCH /api/mobile/auth/me` | Mobile-only. Actualiza timezone/locale del usuario |

### Check-in

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/checkin` | `GET /api/mobile/checkin` | Misma logica |
| `POST /api/athlete/checkin` | `POST /api/mobile/checkin` | **Body schema diferente:** web usa `hardestRpe`, mobile usa `muscleSoreness`. Mappers distintos: `mapWebCheckinBody` vs `mapMobileCheckinBody`. Mismo use case destino |
| `POST /api/athlete/checkin/suggestions/[id]/accept` | `POST /api/mobile/checkin/suggestions/[id]/accept` | Identicos |
| `POST /api/athlete/checkin/suggestions/[id]/reject` | `POST /api/mobile/checkin/suggestions/[id]/reject` | Identicos |
| — | `GET /api/mobile/checkin-status` | Mobile-only (status ligero) |

### Sesiones / Running Log

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `POST /api/athlete/log/session` | `POST /api/mobile/log/session` | Mobile agrega `sessionType`, `dataSource`; web usa `plannedSessionId` naming |
| `PATCH /api/athlete/log/session/[logId]` | `PATCH /api/mobile/log/session/[logId]` | Misma logica |
| `GET /api/athlete/log/last-session` | `GET /api/mobile/log/last-session` | Mobile agrega `?type=` filter |
| `POST /api/athlete/log/run` | — | Web-only (free run separado) |
| — | `GET /api/mobile/log/history` | Mobile-only REST |

### Nutricion — Food Log

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/log` | `GET /api/mobile/nutrition/log` | Mobile: `requireFeature('nutrition')` + `todayInTz` default. Web: UTC directo |
| `POST /api/athlete/nutrition/log` | `POST /api/mobile/nutrition/log` | Misma logica |
| `DELETE /api/athlete/nutrition/log/[id]` | `DELETE /api/mobile/nutrition/log/[id]` | Misma logica |
| — | `GET /api/mobile/nutrition/log/summary` | Mobile-only |

### Nutricion — Foods

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/foods` | `GET /api/mobile/nutrition/foods` | Casi identicos. Mobile agrega rate limit + `countryFromTimezone` sorting |
| `POST /api/athlete/nutrition/foods/propose` | `POST /api/mobile/nutrition/foods/propose` | Misma logica |
| `GET /api/athlete/nutrition/foods/my-proposals` | `GET /api/mobile/nutrition/foods/my-proposals` | Misma logica |
| — | `GET /api/mobile/nutrition/foods/barcode` | Mobile-only (scanner) |

### Nutricion — Planned Meals

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/planned-meals` | `GET /api/mobile/nutrition/planned-meals` | Misma logica |
| `POST /api/athlete/nutrition/planned-meals` | `POST /api/mobile/nutrition/planned-meals` | Misma logica |
| `DELETE /api/athlete/nutrition/planned-meals/[id]` | `DELETE /api/mobile/nutrition/planned-meals/[id]` | Misma logica |
| `POST /api/athlete/nutrition/planned-meals/log-today` | `POST /api/mobile/nutrition/planned-meals/log-today` | Misma logica |

### Nutricion — Templates & Proposals

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET/POST /api/athlete/nutrition/meal-templates` | `GET/POST /api/mobile/nutrition/meal-templates` | Misma logica |
| `DELETE /api/athlete/nutrition/meal-templates/[id]` | `DELETE /api/mobile/nutrition/meal-templates/[id]` | Misma logica |
| `POST /api/athlete/nutrition/adjustment/[id]/accept` | `POST /api/mobile/nutrition/adjustment/[id]/accept` | **DEPRECATED (NUT-15)** — solo procesa ajustes historicos. Ya no se generan nuevos |
| `POST /api/athlete/nutrition/adjustment/[id]/reject` | `POST /api/mobile/nutrition/adjustment/[id]/reject` | **DEPRECATED (NUT-15)** — solo procesa ajustes historicos |
| `GET/PATCH /api/athlete/nutrition/proposals/[id]` | `GET/PATCH /api/mobile/nutrition/proposals/[id]` | Misma logica |

### Nutricion — Agua

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/water` | `GET /api/mobile/nutrition/water` | Misma logica |
| `POST /api/athlete/nutrition/water` | `POST /api/mobile/nutrition/water` | Misma logica |

### Nutricion — Today (NUT-14)

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| RSC en `nutrition/page.tsx` | `GET /api/mobile/nutrition/today` | Mobile-only REST. Use case `getNutritionToday`. Feature gate: nutrition |
| RSC en `nutrition/page.tsx` | `GET /api/mobile/nutrition/assigned-plan` | Mobile-only REST. Plan del coach con comidas del dia |

### Nutricion — Plan Swap

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `POST /api/athlete/nutrition/plan/[id]/swap` | `POST /api/mobile/nutrition/plan/[id]/swap` | Misma logica. Feature gate: nutrition |
| `DELETE /api/athlete/nutrition/plan/[id]/swap` | `DELETE /api/mobile/nutrition/plan/[id]/swap` | Misma logica. Feature gate: nutrition |

### Nutricion — Templates B2C

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/templates` | `GET /api/mobile/nutrition/templates` | Misma logica |
| `POST /api/athlete/nutrition/templates` | `POST /api/mobile/nutrition/templates` | Solo sin coach activo |
| `POST /api/athlete/nutrition/templates/[id]/meals` | `POST /api/mobile/nutrition/templates/[id]/meals` | Misma logica |
| `DELETE /api/athlete/nutrition/templates/[id]/meals` | `DELETE /api/mobile/nutrition/templates/[id]/meals` | Misma logica (body: itemId) |
| `POST /api/athlete/nutrition/templates/[id]/apply` | `POST /api/mobile/nutrition/templates/[id]/apply` | Misma logica. Body: weekStart + intensityMap |

### Nutricion — Food Profile

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/food-profile` | `GET /api/mobile/nutrition/food-profile` | Misma logica |
| `PUT /api/athlete/nutrition/food-profile` | `PUT /api/mobile/nutrition/food-profile` | Misma logica |

### Nutricion — Coach Proposals

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/proposals` | `GET /api/mobile/nutrition/proposals` | Misma logica |
| `POST /api/athlete/nutrition/proposals/[id]` | `POST /api/mobile/nutrition/proposals/[id]` | Misma logica. Body: { action: ACCEPTED\|REJECTED } |

### Gym

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/gym/session/today` | `GET /api/mobile/gym/today` | **URL diferente.** Mismo use case `getTodaySession`. Mobile: `requireFeature('gym')` |
| `POST /api/athlete/gym/session/complete` | `POST /api/mobile/gym/complete` | **URL diferente.** Misma logica |
| `POST /api/athlete/gym/assign` | `POST /api/mobile/gym/assign` | Mobile agrega rate limit |
| `GET /api/athlete/gym/routines` | `GET /api/mobile/gym/routines` | Misma logica |
| `POST /api/athlete/gym/routines` | `POST /api/mobile/gym/routines` | Bloquea si tiene coach activo |
| — | `GET /api/mobile/gym/templates` | Mobile-only REST (web usa RSC). Lista templates publicos |
| — | `GET /api/mobile/gym/week` | Mobile-only |
| — | `GET /api/mobile/gym/history` | Mobile-only |
| — | `GET /api/mobile/gym/prs` | Mobile-only |

### Progress / Metrics

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| RSC en `progress/page.tsx` | `GET /api/mobile/progress/muscles` | Mobile-only REST. Mapa muscular + fatiga |
| `GET /api/athlete/metrics/log` | `GET /api/mobile/metrics/log` | Misma logica. DailyLog upsert |
| `POST /api/athlete/metrics/log` | `POST /api/mobile/metrics/log` | Misma logica. DailyLog upsert |

### Billing

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| RSC en `upgrade/page.tsx` | `GET /api/mobile/billing/prices` | Mobile-only. SIN AUTH. Precios Pro USD/COP+TRM |

### Exercises

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/exercises` | `GET /api/mobile/exercises` | **Response shape diferente.** Web: array flat. Mobile: `{ exercises, total, page, pages }` |
| `GET /api/exercises/[id]` | `GET /api/mobile/exercises/[id]` | Misma logica |
| `GET /api/exercises/[id]/similar` | `GET /api/mobile/exercises/[id]/alternatives` | **URL diferente** (`similar` vs `alternatives`). Misma logica |

### Calendar

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/calendar` | `GET /api/mobile/calendar` | **Identicos** — mismo `buildCalendarWeek()` |

### Sesiones Plan

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `PATCH /api/athlete/sessions/[sessionId]` | `PATCH /api/mobile/sessions/[sessionId]` | Misma logica. Mobile agrega `requireFeature('plan')` |

### Messages

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/messages` | `GET /api/mobile/messages` | Web: cursor pagination. Mobile: take:100 flat |
| `POST /api/messages` | `POST /api/mobile/messages` | Web: status ACTIVE. Mobile: cualquier status |
| `PATCH /api/messages/read` | `PATCH /api/mobile/messages/read` | Web: `{ marked }`. Mobile: `{ ok: true }` |
| `GET /api/messages/unread-count` | `GET /api/mobile/messages/unread-count` | Identicos |
| `GET /api/messages/me` | `GET /api/mobile/messages/me` | Web: ACTIVE. Mobile: cualquier status |

### Onboarding

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `POST /api/athlete/onboarding/generate` | `POST /api/mobile/onboarding/generate` | Mismo use case. Mobile tiene adapter de campo names (`mainGoal` → `activityType`) |
| `GET /api/athlete/onboarding/prefilled` | — | Web-only |

### Notifications

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/notifications` | `GET /api/mobile/notifications` | Misma logica |
| `PATCH /api/athlete/notifications/read-all` | `PATCH /api/mobile/notifications/read-all` | Misma logica |

### Profile

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET/PATCH /api/athlete/user/profile` | `GET/PATCH /api/mobile/profile` | **URL diferente.** Mismo HealthProfile shape |

### Benchmarks

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET/POST/DELETE /api/athlete/progress/benchmarks` | `GET/POST/DELETE /api/mobile/progress/benchmarks` | Web: guard `features?.progress`. Mobile: rate limit |

### Grocery List

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/nutrition/grocery-list` | `GET /api/mobile/nutrition/grocery-list` | Misma logica |

### Routine

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/athlete/routine` | `GET /api/mobile/routine` | Misma logica |

---

## Mobile-only (sin par web REST)

Estos endpoints mobile no tienen equivalente REST en web — web usa RSC (server components):

| Mobile endpoint | Web equivalente |
|----------------|-----------------|
| `GET /api/mobile/dashboard` | RSC `get-dashboard-data.ts` |
| `GET /api/mobile/dashboard/week-sessions` | RSC en `plan/page.tsx` |
| `GET /api/mobile/plan` | RSC en `plan/page.tsx` |
| `GET /api/mobile/progress` | RSC en `progress/page.tsx` |
| `GET /api/mobile/gym/week` | RSC en `gym/page.tsx` |
| `GET /api/mobile/gym/history` | RSC en `gym/history/page.tsx` |
| `GET /api/mobile/gym/prs` | RSC en `progress/page.tsx` |
| `GET /api/mobile/gym/templates` | RSC en gym pages (web usa RSC) |
| `GET /api/mobile/log/history` | RSC en pages |
| `GET /api/mobile/coach/athletes` | RSC en `coach/` pages |
| `POST /api/mobile/push-token` | N/A (solo mobile) |

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo por agentes SDD |
| 2026-10-02 | Auth: sección completa (refresh, set-role, PATCH me). Nutrition: Today (NUT-14), Plan Swap, Templates B2C, Food Profile, Coach Proposals. Gym: POST routines + GET templates. Progress: muscles + metrics/log. Billing: prices. Adjustment endpoints marcados DEPRECATED (NUT-15). Grocery-list y routine movidas a Pares confirmados. Mobile-only limpiada de entradas que ya tienen par. | Actualizacion manual |
