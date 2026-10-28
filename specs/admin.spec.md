# ADMIN — Panel de operacion y gestion de la plataforma

<!-- mirror: false -->
<!-- note: Admin es web-only. No hay endpoints mobile para admin. -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-02.
> Archivos fuente: `src/app/api/admin/`, `src/app/admin/`, `src/domain/admin/`, `src/lib/admin/`
> Domain doc: `../domains/plataforma.md`

## TL;DR
- 16 endpoints API (todos web, auth via `auth()` + role ADMIN verificado en DB)
- 12 paginas server-rendered (overview, users, coaches, metrics, finanzas, subscriptions, activaciones, alerts, audit, features, plans, crons, exercises, invite-codes, settings, help, roadmap)
- Modelos: User, UserSubscription, AdminAuditLog, TierFeatureConfig, Exercise, InviteCode, TrainingPlan, Payment, CoachAthlete
- Dependencias: `logAdminAction()`, `computeWAU()`, `computeRetention()`, `computeCoachActivity()`, `buildAthleteAlert()`, `buildCoachAlert()`, `validateExercise()`
- Trampas criticas: auth verifica rol en DB (no en JWT), `DELETE /users/[id]` es hard delete con cascade, audit log antes del delete, `PATCH /users/[id]/plan` cambia rol + features (no solo plan)
- Mirror mobile: ninguno

---

## Contratos de la AI

- [ ] TODOS los endpoints admin verifican `role === 'ADMIN'` contra la DB, NO contra `session.user.role` del JWT (excepto `/api/admin/features` que usa `session.user.role`)
- [ ] `logAdminAction()` es fire-and-forget — no bloquea la respuesta, falla silenciosamente
- [ ] `DELETE /api/admin/users/[id]` es un **hard delete** (`prisma.user.delete`) — NO es soft delete. Cascade elimina todo. El audit log se escribe ANTES del delete porque `onDelete: SetNull` vacía `targetUserId`
- [ ] Admin NO puede eliminarse a si mismo — guard explicito `id === session.user.id`
- [ ] `PATCH /api/admin/users/[id]/role` sincroniza feature flags automaticamente via `featuresByRole` map — cambiar rol sin actualizar features es un bug
- [ ] `PATCH /api/admin/users/[id]/plan` cambia TANTO el `role` COMO las features — `plan: 'COACH'` cambia role a COACH y activa `featureCoach`
- [ ] `TierFeatureConfig` afecta solo activaciones FUTURAS — usuarios ya activados conservan sus features
- [ ] `POST /api/admin/crons/trigger` solo acepta 3 crons: `checkin-reminder`, `session-reminder`, `payment-overdue`. Llama al endpoint real via HTTP con `CRON_SECRET`
- [ ] Ejercicios globales tienen `coachId: null`. Solo se pueden editar/eliminar ejercicios globales — coach exercises estan fuera de scope del admin
- [ ] `DELETE /api/admin/exercises/[id]` verifica que no haya `WorkoutExercise` usando el ejercicio — si esta en uso retorna 409
- [ ] Invite codes generados por admin tienen formato `MEDAL-XXXXXX` (6 chars alfanumericos), expiran en 7 dias
- [ ] Las paginas admin son **server components** — queries directas a Prisma, sin endpoints intermedios
- [ ] `/admin` layout verifica `session.user.role !== 'ADMIN'` → redirect `/dashboard`

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/admin/search?q=` | `auth()` + DB role | Ninguno | Buscar usuarios por nombre/email |
| GET | `/api/admin/features` | `auth()` + session role | Ninguno | Listar TierFeatureConfig (B2C_FREE, B2C_PRO, B2B) |
| PATCH | `/api/admin/features` | `auth()` + session role | Ninguno | Actualizar feature flag de un userType |
| PATCH | `/api/admin/users/[id]/role` | `auth()` + DB role | Ninguno | Cambiar rol de usuario + sincronizar features |
| PATCH | `/api/admin/users/[id]/plan` | `auth()` + DB role | Ninguno | Cambiar plan (FREE/PRO/COACH) + sincronizar rol y features |
| DELETE | `/api/admin/users/[id]` | `auth()` + DB role | Ninguno | Eliminar usuario (hard delete con cascade) |
| PATCH | `/api/admin/coach/[id]/tier` | `auth()` + DB role | Ninguno | Cambiar coachTier de un coach (STARTER/GROWTH/PRO/SCALE) |
| GET | `/api/admin/exercises` | `auth()` + DB role | Ninguno | Listar ejercicios globales (coachId null) |
| POST | `/api/admin/exercises` | `auth()` + DB role | Ninguno | Crear ejercicio global manual |
| PATCH | `/api/admin/exercises/[id]` | `auth()` + DB role | Ninguno | Editar ejercicio global |
| DELETE | `/api/admin/exercises/[id]` | `auth()` + DB role | Ninguno | Eliminar ejercicio global (si no esta en uso) |
| POST | `/api/admin/exercises/sync` | `auth()` + session role | Ninguno | Re-seed ejercicios desde fuente externa (AscendAPI/WorkoutX) |
| POST | `/api/admin/crons/trigger` | `auth()` + DB role | Ninguno | Disparar cron manualmente |
| GET | `/api/admin/invite-codes` | `auth()` + DB role | Ninguno | Listar todos los invite codes de todos los coaches |
| POST | `/api/admin/invite-codes` | `auth()` + DB role | Ninguno | Generar invite code para un coach |
| DELETE | `/api/admin/invite-codes/[id]` | `auth()` + DB role | Ninguno | Revocar invite code |
| GET | `/api/admin/nutrition/proposals` | `auth()` + session role | Ninguno | Listar propuestas de alimentos pendientes |
| PATCH | `/api/admin/nutrition/proposals/[id]` | `auth()` + session role | Ninguno | Aprobar/rechazar propuesta de alimento |
| POST | `/api/admin/integrations/strava/subscribe` | `auth()` + DB role | Ninguno | Suscribir webhook de Strava |
| GET | `/api/admin/integrations/strava/subscribe` | `auth()` + DB role | Ninguno | Consultar suscripcion activa de Strava |

---

### GET /api/admin/search

**Request:**
```ts
// Query params
{ q: string } // min 2 chars, retorna [] si < 2
```

**Response:**
```ts
{ users: { id: string; name: string | null; email: string; role: string }[] }
// max 10 resultados, ordenados por name asc
```

**Logica:**
1. Verificar admin en DB (query `prisma.user.findUnique`)
2. Si `q.length < 2` → `{ users: [] }`
3. Buscar por `name` OR `email` con `contains` + `mode: 'insensitive'`

---

### GET /api/admin/features

**Response:**
```ts
{ configs: Record<AthleteUserType, FeatureConfig> }
// AthleteUserType: 'B2C_FREE' | 'B2C_PRO' | 'B2B'
```

### PATCH /api/admin/features

**Request:**
```ts
{ userType: 'B2C_FREE' | 'B2C_PRO' | 'B2B'; feature: string; value: boolean }
// feature: 'featurePlan' | 'featureCheckin' | 'featureNutrition' | 'featureProgress' | 'featureLog' | 'featureGym'
```

**Response:**
```ts
{ ok: true; config: TierFeatureConfig }
```

**Logica:**
1. Valida `userType` contra `VALID_USER_TYPES`
2. Valida `feature` contra `VALID_FEATURES`
3. Valida `value` es boolean
4. `updateTierFeatureConfig(userType, { [feature]: value }, adminId)`

---

### PATCH /api/admin/users/[id]/role

**Request:**
```ts
{ role: 'ATHLETE' | 'COACH' | 'ADMIN' }
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar admin en DB
2. Validar `role` contra `['ATHLETE', 'COACH', 'ADMIN']`
3. Leer rol anterior del target (para audit log)
4. Aplicar `featuresByRole[role]` map:
   - ATHLETE: `featurePlan:true, featureCheckin:true, featureNutrition:true, featureProgress:true, featureLog:true, featureCoach:false, featureGym:true`
   - COACH: `featurePlan:false, ..., featureCoach:true, onboardingCompleted:true`
   - ADMIN: todas las features `false`
5. `logAdminAction(CHANGE_ROLE, id, { from, to })` fire-and-forget

---

### PATCH /api/admin/users/[id]/plan

**Request:**
```ts
{ plan: 'FREE' | 'PRO' | 'COACH' }
```

**Response:**
```ts
{ ok: true; user: { id, role, featurePlan, featureCoach, onboardingCompleted } }
```

**Logica:**
1. Verificar admin en DB
2. Segun `plan`:
   - `'FREE'` → role ATHLETE, solo `featureLog:true`, demas `false`
   - `'PRO'` → role ATHLETE, todas features de atleta `true`
   - `'COACH'` → role COACH, `featureCoach:true`, `onboardingCompleted:true`
3. `logAdminAction(CHANGE_PLAN, id, { plan })` fire-and-forget

---

### DELETE /api/admin/users/[id]

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar admin en DB
2. Guard: `id === session.user.id` → 400
3. Leer target user (name, email, role) para audit log
4. `logAdminAction(DELETE_USER, id, { email, name, role })` — **await** (no fire-and-forget, porque el delete posterior borra el FK)
5. `prisma.user.delete({ where: { id } })` — cascade elimina todo

---

### PATCH /api/admin/coach/[id]/tier

**Request:**
```ts
{ coachTier: 'STARTER' | 'GROWTH' | 'PRO' | 'SCALE' }
```

**Response:**
```ts
{ ok: true; coachTier: string }
```

**Logica:**
1. Verificar admin en DB
2. Validar `coachTier` contra `VALID_TIERS`
3. Verificar target existe y `role === 'COACH'` → 400 si no
4. `prisma.userSubscription.upsert` (crea si no existe)
5. `logAdminAction(CHANGE_PLAN, id, { plan: 'coachTier:OLD->NEW' })`

---

### GET /api/admin/exercises

**Response:**
```ts
{ exercises: { id, name, bodyPart, target, equipment, mechanic, description, gifUrl, source }[] }
// Solo ejercicios con coachId: null, ordenados por bodyPart + name
```

### POST /api/admin/exercises

**Request:**
```ts
{ name: string; bodyPart: string; target: string; equipment: string; mechanic?: string; description?: string; gifUrl?: string }
```

**Response 201:**
```ts
{ exercise: { id, name, bodyPart, target, equipment } }
```

**Logica:** `validateExercise(body)` → si errors → 400. Crea con `source: 'manual'`, `coachId: null`.

### PATCH /api/admin/exercises/[id]

Mismos campos que POST. Verifica que el ejercicio existe y `coachId === null` (solo globales).

### DELETE /api/admin/exercises/[id]

1. Verificar ejercicio existe y `coachId === null`
2. Contar `workoutExercise` que lo usan → si `> 0` → 409 "en uso en rutinas"
3. `prisma.exercise.delete`

---

### POST /api/admin/exercises/sync

**Response:**
```ts
{ synced: number; source: 'ascendapi' | 'workoutx' }
```

**Logica:**
1. Resuelve client segun `EXERCISE_SOURCE` env var (default `ascendapi`)
2. `ExerciseSyncUseCase.execute()` → upsert ejercicios globales

---

### POST /api/admin/crons/trigger

**Request:**
```ts
{ cron: 'checkin-reminder' | 'session-reminder' | 'payment-overdue' }
```

**Response:**
```ts
{ ok: boolean; status: number; result: object }
// 502 si el cron falla
```

**Logica:**
1. Validar `cron` contra `VALID_CRONS`
2. Requiere `CRON_SECRET` en env
3. HTTP GET a `/api/cron/${cron}` con header `Authorization: Bearer ${CRON_SECRET}`

---

### GET /api/admin/invite-codes

**Response:**
```ts
{ codes: { id, code, usedBy, usedAt, expiresAt, createdAt, coach: { id, name, email } }[] }
// Todos los codigos, ordenados por createdAt desc
```

### POST /api/admin/invite-codes

**Request:**
```ts
{ coachId: string }
```

**Response:**
```ts
{ invite: { id, code, expiresAt } }
// code formato: MEDAL-XXXXXX, expira en 7 dias
```

**Logica:** Verifica que `coachId` es un usuario con `role === 'COACH'`.

### DELETE /api/admin/invite-codes/[id]

Verifica que el codigo existe → `prisma.inviteCode.delete`.

---

### GET /api/admin/nutrition/proposals

**Response:**
```ts
{ proposals: FoodProposal[]; pendingCount: number }
// Lista hasta 100 propuestas pendientes
```

### PATCH /api/admin/nutrition/proposals/[id]

**Request:**
```ts
{ action: 'APPROVE' | 'REJECT'; reviewNote?: string } // Zod validated, reviewNote max 500 chars
```

**Response:**
```ts
{ ok: true }
```

---

### POST /api/admin/integrations/strava/subscribe

Suscribe webhook de Strava. Ejecutar una sola vez al deploy.

**Response:**
```ts
{ ok: true; subscriptionId: number }
// 502 si Strava falla
```

### GET /api/admin/integrations/strava/subscribe

Consulta suscripcion activa de Strava. Retorna la respuesta cruda de la API de Strava.

---

## Paginas admin (server components)

| Ruta | Que muestra | Queries principales |
|------|-------------|---------------------|
| `/admin` | Overview: KPIs (total users, athletes, coaches, nuevos semana/mes, onboarding completado) + funnel de activacion + ultimos 10 registros | 9 queries paralelas |
| `/admin/metrics` | WAU (8 semanas), retencion 14 dias, planes por estado, B2C vs B2B, distribucion geografica por timezone | 15 queries paralelas |
| `/admin/users` | Tabla paginada (50/page) con busqueda por nombre/email | 2 queries (findMany + count) |
| `/admin/users/[id]` | Perfil completo: datos, health profile, plan activo, ultimo check-in, features activas, coach asignado, acciones (reset password, delete) | 1 query con includes |
| `/admin/coaches` | Coaches con atletas, actividad semanal (mensajes + pagos), dropdown de tier | 3 queries paralelas + `computeCoachActivity()` |
| `/admin/finanzas` | MRR estimado (atletas Pro + fees coaches), pagos en plataforma (paid/pending/overdue), fee por coach | 5 queries paralelas |
| `/admin/subscriptions` | Distribucion por plan (Pro/Free/Inactivo/Coach/Admin), tabla con features por usuario | 1 query (300 users max) |
| `/admin/activaciones` | Atletas pendientes (sin featurePlan NI featureLog) vs activos (featurePlan:true), boton activar/desactivar | 1 query |
| `/admin/alerts` | Alertas operativas: atletas >48h en pending, coaches >7 dias sin atletas | 2 queries + `buildAthleteAlert()` + `buildCoachAlert()` |
| `/admin/audit` | Feed de ultimas 200 acciones admin (cambio rol, plan, delete) | 1 query con includes |
| `/admin/features` | Matrix de feature flags por userType (B2C_FREE/B2C_PRO/B2B) con toggles | Via endpoint GET `/api/admin/features` |
| `/admin/plans` | Tabla de planes activos con atleta, semanas, inicio, fin, fuente | 1 query (200 max) |
| `/admin/crons` | Panel para disparar crons manualmente | Via endpoint POST `/api/admin/crons/trigger` |
| `/admin/exercises` | CRUD de ejercicios globales + sync desde fuente externa | Via endpoints `/api/admin/exercises` |
| `/admin/invite-codes` | Lista + crear + revocar invite codes | Via endpoints `/api/admin/invite-codes` |
| `/admin/settings` | Info estatica: plataforma, stack tecnico, integraciones | Sin queries |
| `/admin/help` | FAQ interactivo por seccion | Sin queries |
| `/admin/roadmap` | Roadmap del producto (data en `roadmap_data.ts`) | Sin queries |

---

## Modelos DB involucrados

```prisma
model User {
  id                    String    @id @default(cuid())
  role                  Role      // ATHLETE | COACH | ADMIN
  status                UserStatus // ACTIVE | SUSPENDED | BLOCKED | DELETED
  featurePlan           Boolean   @default(false)
  featureCheckin        Boolean   @default(false)
  featureNutrition      Boolean   @default(false)
  featureProgress       Boolean   @default(false)
  featureLog            Boolean   @default(false)
  featureCoach          Boolean   @default(false)
  featureGym            Boolean   @default(false)
  onboardingCompleted   Boolean   @default(false)
  // ... otros campos
}

model AdminAuditLog {
  id            String   @id @default(cuid())
  adminId       String
  admin         User     @relation("adminAudit", fields: [adminId])
  action        String   // CHANGE_ROLE | CHANGE_PLAN | DELETE_USER
  targetUserId  String?  // onDelete: SetNull — se vacía al eliminar user
  targetUser    User?    @relation("targetAudit", fields: [targetUserId])
  meta          Json?    // { from, to } | { plan } | { email, name, role }
  createdAt     DateTime @default(now())
}

model TierFeatureConfig {
  id               String          @id @default(cuid())
  userType         AthleteUserType @unique // B2C_FREE | B2C_PRO | B2B
  featurePlan      Boolean
  featureCheckin   Boolean
  featureNutrition Boolean
  featureProgress  Boolean
  featureLog       Boolean
  featureGym       Boolean
  updatedAt        DateTime        @updatedAt
  updatedById      String?
}

model UserSubscription {
  userId    String                @id
  tier      SubscriptionTier      // FREE | PRO
  coachTier CoachSubscriptionTier? // STARTER | GROWTH | PRO | SCALE
  // ... billing fields
}

model Exercise {
  id          String  @id @default(cuid())
  name        String
  bodyPart    String
  target      String
  equipment   String
  mechanic    String?
  description String?
  gifUrl      String?
  coachId     String? // null = global (admin), no-null = coach-specific
  source      String? // 'manual' | 'ascendapi' | 'workoutx'
}

model InviteCode {
  id        String    @id @default(cuid())
  code      String    @unique // MEDAL-XXXXXX
  coachId   String
  usedBy    String?
  usedAt    DateTime?
  expiresAt DateTime
  createdAt DateTime  @default(now())
}
```

---

## Domain logic (logica pura sin Prisma)

| Archivo | Que hace |
|---------|----------|
| `domain/admin/audit_log.ts` | `ADMIN_ACTIONS` enum, `labelForAction()`, `describeAuditEntry()`, `colorForAction()` |
| `domain/admin/wau.ts` | `computeWAU(events, weeks)` — Weekly Active Users por semana ISO |
| `domain/admin/retention.ts` | `activeUserIdsInWindow()`, `computeRetention()`, `retentionColor()` |
| `domain/admin/coach_activity.ts` | `computeCoachActivity(messageFromIds, paymentCoachIds, allCoachIds)` |
| `domain/admin/alerts.ts` | `buildAthleteAlert()` (>48h pending), `buildCoachAlert()` (>7d sin atletas) |
| `domain/admin/finanzas.ts` | `coachTierFee()`, `coachTierFeeLabel()`, `mrrAthletes()`, `mrrCoaches()` |
| `domain/admin/exercise.ts` | `validateExercise(body)` — validacion de campos de ejercicio |
| `domain/admin/search.ts` | Logica de busqueda (usada en search palette) |
| `domain/admin/invite_conversion.ts` | Calculo de conversion de invite codes |
| `lib/admin/log_action.ts` | `logAdminAction(adminId, action, targetUserId?, meta?)` — persiste en AdminAuditLog |

---

## Reglas de negocio (invariantes)

1. **Auth doble capa**: la mayoria de endpoints verifican rol en DB (no JWT) — patron: `prisma.user.findUnique({ select: { role } })` → `role !== 'ADMIN'` → 403. Excepcion: `/api/admin/features` y `/api/admin/exercises/sync` verifican `session.user.role`
2. **featuresByRole map**: al cambiar rol, SIEMPRE sincronizar features. COACH → `featureCoach:true` + `onboardingCompleted:true` + demas `false`. ATHLETE → todas features de atleta `true`. ADMIN → todas `false`
3. **Audit antes de delete**: el audit log se escribe ANTES de `prisma.user.delete` porque `onDelete: SetNull` vacía `targetUserId` — sin el pre-write se pierde la trazabilidad
4. **Self-delete guard**: admin no puede eliminarse a si mismo
5. **Ejercicios globales vs coach**: admin solo gestiona ejercicios con `coachId: null`. Ejercicios de coach estan fuera de scope
6. **Exercise usage check**: no se puede eliminar un ejercicio global si esta referenciado en `WorkoutExercise`
7. **Invite code formato**: `MEDAL-` + 6 chars alfanumericos uppercase, TTL 7 dias
8. **Cron trigger proxy**: el endpoint admin no ejecuta la logica del cron directamente — hace HTTP al endpoint `/api/cron/*` con `CRON_SECRET`
9. **TierFeatureConfig scope**: solo afecta activaciones futuras (cuando un coach activa un atleta). No retroactivo
10. **Finanzas estimadas**: MRR es calculado, no real — no hay pasarela de pago conectada. Precios hardcodeados en `domain/admin/finanzas.ts`

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `DELETE /users/[id]` es soft delete | El domain doc dice "Soft delete con doble confirmacion" | El codigo hace `prisma.user.delete` — es **hard delete** con cascade. El "soft delete" es solo el concepto en el domain doc, no la implementacion actual |
| `PATCH /users/[id]/plan` solo cambia plan | El endpoint se llama "plan" | Cambia TANTO `role` como features. `plan: 'COACH'` → el usuario deja de ser ATHLETE y pasa a COACH |
| Admin auth es por JWT | `session.user.role` parece suficiente | La mayoria de endpoints hacen una query extra a DB para verificar — el JWT puede estar stale. Excepto `/features` y `/exercises/sync` que confian en `session.user.role` |
| `logAdminAction` siempre es fire-and-forget | `void logAdminAction()` en varios endpoints | En `DELETE /users/[id]` es `await logAdminAction()` (sincrono) — necesario porque el delete posterior borra el FK |
| Las paginas admin usan endpoints API | Patron tipico Next.js | Las paginas son **server components** que consultan Prisma directamente — solo los client components usan los endpoints API |
| `computeCoachActivity` usa login data | Parece que mide logins | Mide mensajes enviados + pagos registrados en los ultimos 7 dias |
| Admin puede crear invite codes para cualquier coach | Parece igual que el flujo del coach | El admin puede generar codigos para CUALQUIER coach, no solo para si mismo |
| Nutrition proposals son propuestas de alimentos | Parece propuestas de plan nutricional | Son propuestas de NUEVOS ALIMENTOS para la libreria (FoodProposal), no planes de nutricion |

---

## Tests requeridos

### Endpoints existentes con tests
- `src/app/api/admin/search/route.test.ts`
- `src/app/api/admin/exercises/route.test.ts`
- `src/app/api/admin/exercises/[id]/route.test.ts`
- `src/app/api/admin/users/[id]/route.test.ts`
- `src/app/api/admin/users/[id]/role/route.test.ts`
- `src/app/api/admin/users/[id]/plan/route.test.ts`
- `src/app/api/admin/crons/trigger/route.test.ts`
- `src/app/api/admin/invite-codes/route.test.ts`
- `src/app/api/admin/invite-codes/[id]/route.test.ts`

### Domain logic existentes con tests
- `src/domain/admin/audit_log.test.ts`
- `src/domain/admin/wau.test.ts`
- `src/domain/admin/retention.test.ts`
- `src/domain/admin/coach_activity.test.ts`
- `src/domain/admin/alerts.test.ts`
- `src/domain/admin/finanzas.test.ts`
- `src/domain/admin/exercise.test.ts`
- `src/domain/admin/search.test.ts`
- `src/domain/admin/invite_conversion.test.ts`

### Casos criticos que deben pasar al modificar este modulo
- [ ] Non-admin user → 401 o 403 en todos los endpoints
- [ ] `PATCH /users/[id]/role` con rol COACH → `featureCoach:true`, `onboardingCompleted:true`, demas features `false`
- [ ] `PATCH /users/[id]/role` con rol ATHLETE → todas features de atleta `true`, `featureCoach:false`
- [ ] `PATCH /users/[id]/plan` con `plan: 'FREE'` → `role: 'ATHLETE'`, solo `featureLog:true`
- [ ] `DELETE /users/[id]` con `id === session.user.id` → 400 "No puedes eliminarte a ti mismo"
- [ ] `DELETE /users/[id]` registra audit log ANTES del delete con email/name/role del target
- [ ] `DELETE /exercises/[id]` con ejercicio en uso → 409
- [ ] `DELETE /exercises/[id]` con ejercicio de coach (coachId !== null) → 404
- [ ] `PATCH /coach/[id]/tier` con target no-COACH → 400
- [ ] `POST /crons/trigger` con cron invalido → 400
- [ ] `POST /invite-codes` con coachId de non-COACH → 400
- [ ] `PATCH /features` con userType invalido → 400
- [ ] `PATCH /nutrition/proposals/[id]` con action invalida → 400
- [ ] `GET /search?q=a` (1 char) → `{ users: [] }`
- [ ] `computeWAU` retorna buckets correctos por semana ISO
- [ ] `computeRetention` retorna rate 0 cuando base es 0
- [ ] `buildAthleteAlert` retorna null si atleta lleva < 48h
- [ ] `buildCoachAlert` retorna null si coach lleva < 7 dias

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-02 | Spec creada | Extraida del codigo existente |
