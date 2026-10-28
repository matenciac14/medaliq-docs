# COACH-01 — Coach: Gestion de Atletas, Invite/Join, Planes, Pagos, Perfil

<!-- mirror: false -->
<!-- note: coach panel es web-only. No hay endpoints mobile para coach -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Cubre: status transitions · feature toggling · invite/join flow · plan assignment · payments · coach profile.
> Domain doc: `../domains/coach.md`
> Panel del coach es web-only — no hay par mobile para estos endpoints.
> **Fuera de scope:** Coach gym routes (`/api/coach/gym/*`), coach nutrition templates (`/api/coach/nutrition/*`), plan editing (`/api/coach/plan/*`), posts (`/api/coach/posts`), programs (`/api/coach/programs`), running-logs, benchmarks, celebrate-pr, sessions, dailylogs — existen en el codebase pero no estan documentados en esta spec.

## TL;DR
- 18 endpoints (todos web-only)
- Modelos: CoachAthlete, InviteCode, CoachProfile, CoachProgram, Payment
- Dependencias: user_config.ts (feature toggling), session_mappers.ts
- Trampas criticas: status transitions (PENDING→ACTIVE→SUSPENDED→REMOVED), feature toggling bidireccional, inviteCode.usedBy tracking
- Mirror mobile: NO — coach panel es web-only

---

## Contratos de la AI

<!-- Lo que la AI DEBE saber antes de tocar este modulo. Si no lees esto, alucinaras. -->

- [ ] Auth: todos los endpoints de este modulo usan Auth.js v5 `auth()` + `session.user.role === 'COACH'`. Ningun endpoint es mobile.
- [ ] Ownership: antes de cualquier accion sobre un atleta SIEMPRE verificar `CoachAthlete` con `{ coachId: session.user.id, athleteId }`. Nunca confiar en el body.
- [ ] Status transitions: solo ACTIVE y PAUSED existen en el enum `AthleteStatus`. REMOVED no existe en DB — eliminar la relacion no esta implementado en estos endpoints.
- [ ] Feature toggling: el endpoint `/status` NO permite toggles granulares. Activa → B2B features completas. Pausa → B2C_FREE features. La config la define `TierFeatureConfig` (admin), no el coach.
- [ ] PAUSED != bloqueado: un atleta pausado sigue siendo usuario B2C activo. No va a `/pending`. Solo pierde la capa de coach.
- [ ] Un atleta solo puede tener un coach con `status: 'ACTIVE'` a la vez. `/clients/link` lo valida explicitamente.
- [ ] Coach tier limit: se evalua en `/clients/create` y `/status ACTIVE` antes de escribir. 402 si `activeCount >= maxAthletes`. Response incluye `nextTier`, `nextPrice`, `nextLimit` para modal informativo. Los atletas PAUSED NO cuentan para el limite.
- [ ] Perfil incompleto bloquea creacion: sin `identification` ni `phoneWa` en User → 403 en `/clients/create`. El coach puede operar el panel pero no invitar atletas.
- [ ] Plan assignment requiere atleta ACTIVE: los 4 endpoints de plan (`/plan`, `/plan/from-template`, `/plan/custom`, `/plan/copy-from`) usan `findFirst({ where: { coachId, athleteId, status: 'ACTIVE' } })`. Un atleta PAUSED no puede recibir planes.
- [ ] Al asignar cualquier plan: el plan ACTIVE anterior se setea a COMPLETED en la misma transaccion. No puede haber dos planes ACTIVE para el mismo atleta.
- [ ] `startDate` de planes siempre se fuerza al lunes de la semana indicada via `forceMonday()`.
- [ ] `specialties[]` es la fuente canonica de disciplinas del coach. `primarySpecialty` esta @deprecated. Array vacio `[]` = acceso completo (backward compat).
- [ ] `coachGoal` es la meta visible para el atleta. `privateNotes` es privado — el atleta nunca las ve. Ambos viven en `CoachAthlete`, no en `User`.
- [ ] `/config` maneja solo metadatos del coach sobre el atleta (coachGoal, privateNotes). Para activar/pausar usar `/status`.
- [ ] InviteCode expira en 7 dias desde creacion. El flujo `/coach/join` es para atletas que se unen desde el perfil publico del coach (usa `profileId + programId`), no desde un invite code.
- [ ] Dashboard de atletas usa cursor-based pagination (TAKE=20). Retorna `{ athletes, hasMore, nextCursor }`.
- [ ] Pagos son registros manuales del coach — no hay integracion de pasarela para cobros al atleta. Son solo tracking interno.
- [ ] `PaymentAuditLog` se crea en la misma `$transaction` que cada accion de pago. No crear pagos sin su audit log.
- [ ] `plan/copy-from` verifica que el coach sea dueno tanto del atleta destino (ACTIVE) como del atleta fuente del plan origen. No se puede copiar desde un plan de atleta de otro coach.

---

## Endpoints

| Metodo | Path | Auth | Descripcion |
|--------|------|------|-------------|
| GET | `/api/coach/dashboard/athletes` | `auth()` COACH | Lista atletas con cursor pagination + adherencia + checkins |
| GET | `/api/coach/clients/check` | `auth()` COACH | Buscar usuario existente por email |
| POST | `/api/coach/clients/create` | `auth()` COACH | Crear atleta nuevo y vincularlo |
| POST | `/api/coach/clients/link` | `auth()` COACH | Vincular atleta B2C existente |
| PATCH | `/api/coach/athletes/[id]/status` | `auth()` COACH | Activar o pausar atleta |
| PATCH | `/api/coach/athletes/[id]/config` | `auth()` COACH | Actualizar coachGoal y/o privateNotes |
| GET | `/api/coach/athletes/[id]/invite-link` | `auth()` COACH | Generar link set-password para atleta ACTIVE |
| POST | `/api/coach/athletes/[id]/reset-password` | `auth()` COACH | Resetear password del atleta (genera link) |
| POST | `/api/coach/athletes/[id]/plan` | `auth()` COACH | Asignar plan via `generatePlanUseCase` (COACH-generated) |
| POST | `/api/coach/athletes/[id]/plan/from-template` | `auth()` COACH | Asignar plan desde template de sistema |
| POST | `/api/coach/athletes/[id]/plan/custom` | `auth()` COACH | Crear plan custom (semanas vacias) |
| POST | `/api/coach/athletes/[id]/plan/copy-from` | `auth()` COACH | Copiar plan de otro atleta del mismo coach |
| POST | `/api/coach/invite` | `auth()` COACH | Crear InviteCode (MEDAL-XXXXXX, 7d TTL) |
| GET | `/api/coach/invite` | `auth()` COACH | Listar InviteCodes del coach |
| POST | `/api/coach/join` | `auth()` ATHLETE | Atleta se une a programa publico del coach |
| GET | `/api/coach/profile` | `auth()` COACH | Leer CoachProfile + identification + phoneWa |
| PATCH | `/api/coach/profile` | `auth()` COACH | Actualizar CoachProfile (upsert) |
| GET | `/api/coach/payments` | `auth()` COACH | Listar pagos del coach |
| POST | `/api/coach/payments` | `auth()` COACH | Crear registro de pago |
| PATCH | `/api/coach/payments/[paymentId]` | `auth()` COACH | Marcar como PAID o PENDING |
| DELETE | `/api/coach/payments/[paymentId]` | `auth()` COACH | Eliminar pago |

---

### `PATCH /api/coach/athletes/[id]/status`

**Request body:**
```ts
{ status: 'ACTIVE' | 'PAUSED' }
```

**Response 200:**
```ts
{ ok: true, status: 'ACTIVE' | 'PAUSED' }
```

**Response 402 (limite alcanzado al activar):**
```ts
{
  error: string,
  limit: number,       // max atletas del tier actual
  current: number,     // atletas activos actuales
  tier: CoachTier,     // tier actual del coach
  nextTier: CoachTier | null,   // siguiente tier disponible (null si ya es SCALE)
  nextPrice: number | null,     // precio USD del siguiente tier
  nextLimit: number | null      // limite de atletas del siguiente tier
}
```

**Rate limit:** 30/min por coach (`coach-{id}:athlete-status-patch`).

**Logica:**
1. Verificar `CoachAthlete { coachId, athleteId }` — 404 si no existe.
2. Validar que `status` sea `'ACTIVE'` o `'PAUSED'` — 400 si otro valor.
3. Si ACTIVE: verificar limite de tier — 402 con info del siguiente tier si `activeCount >= maxAthletes`.
4. Derivar `userType`: `'B2B'` si ACTIVE, `'B2C_FREE'` si PAUSED.
5. Leer `TierFeatureConfig` para ese `userType` via `getTierFeatureConfig(userType)`.
6. Convertir a `AthleteFeatures` via `configToAthleteFeatures(config)`.
7. `$transaction`: `userRepo.mergeFeatures(athleteId, features)` + `CoachAthlete.update({ status })`.
8. Fire-and-forget: push notification al atleta via Expo si tiene `pushToken`.

**Notas:**
- El coach no elige que features activar — el sistema aplica la config del admin (TierFeatureConfig).
- Push es fire-and-forget — el `.catch(() => {})` absorbe errores. No bloquear la respuesta por fallos de push.
- La response 402 incluye datos del siguiente tier para que el frontend muestre un modal informativo: "Tu plan STARTER permite 2. Sube a GROWTH ($59/mes, 10 asesorados)". Botones: "Subir de plan" → checkout coach / "Cancelar".

---

### `PATCH /api/coach/athletes/[id]/config`

**Request body:**
```ts
{
  coachGoal?: string | null
  privateNotes?: string | null
}
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar `CoachAthlete { coachId, athleteId }` — 404 si no existe (no requiere `status: 'ACTIVE'`).
2. Validar que al menos uno de los campos este presente en el body — 400 si ninguno.
3. Actualizar solo los campos presentes (partial update con `'coachGoal' in body`).
4. `null` es un valor valido — permite borrar la meta o las notas.

---

### `POST /api/coach/clients/create`

**Request body:**
```ts
{
  name: string           // nameSchema
  email: string          // emailSchema
  sport?: string | null
  goal?: string | null
  heightCm?: number      // 50-280
  weightKg?: number      // 20-400
  dateOfBirth?: string   // YYYY-MM-DD
  gender?: 'male' | 'female'
  experienceLevel?: 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED'
}
```

**Response 201:**
```ts
{
  ok: true
  email: string
  resetLink: string   // /set-password?token=<jwt-7d>
  athleteId: string
  athleteName: string
}
```

**Logica:**
1. Verificar `identification` y `phoneWa` en `User` del coach — 403 `PROFILE_INCOMPLETE` si falta alguno.
2. Contar atletas ACTIVE del coach + leer `UserSubscription.coachTier` (default: `'STARTER'`).
3. Aplicar `getCoachLimits(coachTier).maxAthletes` — 402 `COACH_LIMIT_REACHED` si excede.
4. Verificar que el email no exista en `User` — 409 si ya existe.
5. Generar `tempPassword` (8 chars, alphanum sin confundibles).
6. `$transaction`:
   - Crear `User` con `role: 'ATHLETE'` y todas las feature flags en `false`.
   - Crear `CoachAthlete { coachId, athleteId }` (status default: ACTIVE).
   - Si `heightCm && weightKg` → crear `HealthProfile` pre-poblado.
7. Generar `resetLink` via JWT HS256 con `{ sub: athleteId, purpose: 'set-password' }`, TTL 7d.
8. Fire-and-forget: `sendAthleteWelcomeEmail` con el resetLink.

**Nota:** El atleta recien creado tiene todas las features en `false`. Debe completar onboarding y el coach debe activarlo con `PATCH /status { status: 'ACTIVE' }` para que tenga acceso.

---

### `POST /api/coach/clients/link`

**Request body:**
```ts
{ athleteId: string }
```

**Response 201:**
```ts
{
  ok: true
  athlete: { id: string, name: string, email: string }
}
```

**Logica:**
1. Verificar que `User` con ese `athleteId` existe y tiene `role: 'ATHLETE'` — 404 si no.
2. Verificar que no existe `CoachAthlete { coachId, athleteId }` — 409 si ya existe.
3. Verificar que el atleta no tiene otro coach con `status: 'ACTIVE'` — 409 con nombre del otro coach si lo tiene.
4. `CoachAthlete.create({ coachId, athleteId })` — catch P2002 para concurrencia.
5. Fire-and-forget: `sendAthleteCoachAssignedEmail`.

---

### `POST /api/coach/athletes/[id]/plan`

Asigna un plan via `generatePlanUseCase` (el mismo que usa el atleta B2C Pro, con `generatedBy: 'COACH'`).

**Request body:**
```ts
{
  goalType: string        // clave de PLAN_TEMPLATES (RUNNING_5K, BODY_RECOMPOSITION, etc.)
  daysPerWeek?: 3 | 4 | 5 | 6   // default: 4
  hoursPerSession?: number       // 0.5-3, default: 1
}
```

**Response 200:**
```ts
{ success: true, planId: string }
```

**Logica:**
1. Verificar `CoachAthlete { coachId, athleteId, status: 'ACTIVE' }` — 404 si no o si pausado.
2. Cargar `HealthProfile` del atleta — 400 si no existe.
3. Buscar `PerformanceBenchmark` de 5K en los ultimos 90 dias (opcional, para calibrar paces).
4. Llamar `generatePlanUseCase` con datos del perfil + `generatedBy: 'COACH'`.
5. El use case internamente desactiva el plan activo anterior y crea el nuevo.

---

### `POST /api/coach/athletes/[id]/plan/from-template`

**Request body:**
```ts
{
  templateId: string   // ID de template del sistema (PLAN_TEMPLATES)
  name: string
  startDate: string    // ISO date — se fuerza a lunes con forceMonday()
}
```

**Response 201:**
```ts
{
  planId: string
  plan: { id, name, totalWeeks, startDate, weeks: [{ id, weekNumber, phase, focusDescription, isRecoveryWeek, volumeKm, startDate, endDate, sessions: [...] }] }
}
```

**Logica:**
1. Verificar ownership ACTIVE.
2. Validar `templateId` contra `PLAN_TEMPLATES` — 400 si no existe.
3. `$transaction (timeout: 30s)`:
   - `TrainingPlan.updateMany({ userId: athleteId, status: 'ACTIVE' }, { status: 'COMPLETED' })`.
   - Crear `TrainingPlan` con `generatedBy: 'COACH'`.
   - `PlanWeek.createMany` con fechas calculadas desde `startDate`.
   - `PlannedSession.createMany` — `dayOfWeek` del template usa 1=Lun,7=Dom → DB usa 0=Lun,6=Dom (restar 1).

---

### `POST /api/coach/athletes/[id]/plan/custom`

Crea un plan con semanas vacias (sin sesiones). El coach las rellena despues desde el builder.

**Request body:**
```ts
{
  name: string
  totalWeeks: number    // 1-52
  startDate: string     // ISO date — se fuerza a lunes
}
```

**Response 201:**
```ts
{ planId: string, plan: { id, name, totalWeeks, startDate, weeks: [...] } }
```

**Logica:**
1. Verificar ownership ACTIVE.
2. `$transaction (timeout: 15s)`: desactivar plan anterior → crear plan → `PlanWeek.createMany` via `buildCustomPlanWeeks()`.
3. Retorna el plan con semanas pero `sessions: []` en cada semana.

---

### `POST /api/coach/athletes/[id]/plan/copy-from`

**Request body:**
```ts
{
  sourcePlanId: string   // ID del plan a copiar
  startDate: string      // YYYY-MM-DD — se fuerza a lunes
}
```

**Response 201:**
```ts
{ ok: true, planId: string }
```

**Logica:**
1. Verificar ownership ACTIVE del atleta **destino**.
2. Cargar `sourcePlan` con weeks + sessions.
3. Verificar que el coach tambien sea dueno del atleta **fuente** del plan (`CoachAthlete` sin filtro de status) — 403 si no.
4. `$transaction (timeout: 30s)`: desactivar activo → crear plan copia → crear semanas → `PlannedSession.createMany`.
5. Nombre del plan: `"${sourcePlan.name} (copia)"`.
6. Las fechas de sesiones se recalculan desde el nuevo `startDate` (`addDays(weekStart, s.dayOfWeek - 1)`).

---

### `POST /api/coach/invite` y `GET /api/coach/invite`

**POST — crear InviteCode:**

Request: sin body.

Response:
```ts
{ invite: { id, code, usedBy, usedAt, expiresAt, createdAt } }
```

- Codigo formato: `MEDAL-XXXXXX` (6 chars alphanumeric uppercase).
- TTL: 7 dias desde creacion.
- No hay limite de codigos por coach.

**GET — listar InviteCodes:**

Response:
```ts
{ codes: Array<{ id, code, usedBy, usedAt, expiresAt, createdAt }> }
```

Ordenados por `createdAt desc`.

---

### `POST /api/coach/join`

Caller: ATHLETE (no COACH). El atleta se une desde el perfil publico del coach.

**Request body:**
```ts
{
  profileId: string    // CoachProfile.id
  programId: string    // CoachProgram.id
}
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar que `CoachProfile` existe y `isPublic: true` — 404 si no.
2. Verificar que `CoachProgram` existe, pertenece al `profileId` y `isActive: true` — 404 si no.
3. `CoachAthlete.upsert` — si ya existe la relacion no lanza error (update: `{}`).

**Trampa:** este endpoint no valida si el atleta ya tiene otro coach activo. A diferencia de `/clients/link`, el upsert pasa silenciosamente. Esto es intencional para el flujo de marketplace — pero significa que un atleta puede tener dos relaciones si una esta PAUSED.

---

### `GET /api/coach/profile` y `PATCH /api/coach/profile`

**GET — Response:**
```ts
{
  profile: CoachProfile | null    // incluye programs[] y posts[]
  identification: string | null
  phoneWa: string | null
  showPhoneWa: boolean
}
```

**PATCH — Request body (todos opcionales):**
```ts
{
  slug?: string                   // /^[a-z0-9-]+$/ — unico
  bio?: string
  headline?: string
  city?: string
  country?: string                // default "CO"
  whatsapp?: string
  instagram?: string
  yearsExp?: number | string      // parseInt aplicado
  specialties?: string[]
  certifications?: string[]
  isPublic?: boolean
  avatarUrl?: string
  identification?: string         // 5-30 chars — unico entre coaches
  phoneWa?: string                // E.164: /^\+[1-9]\d{7,14}$/ — unico entre coaches
}
```

**Logica:**
1. Validar slug (formato), identification (5-30 chars), phoneWa (E.164).
2. Verificar unicidad en paralelo: slug, identification, phoneWa — todos contra otros coaches (NOT self).
3. Si `identification` o `phoneWa` provistos → `User.update` primero.
4. `CoachProfile.upsert` — crea si no existe, actualiza solo los campos presentes.
5. Catch P2002 → 409 "slug ya en uso".

---

### `GET /api/coach/dashboard/athletes`

**Query params:**
```ts
{ cursor?: string }   // CoachAthlete.id del ultimo item (cursor-based pagination)
```

**Response:**
```ts
{
  athletes: AthleteCard[]   // resultado de mapCoachAthleteRelation()
  hasMore: boolean
  nextCursor: string | null
}
```

- TAKE = 20 por pagina.
- Ordenado por `CoachAthlete.createdAt asc`.
- Incluye por atleta: `HealthProfile`, plan ACTIVE con semanas y sesiones hasta hoy con sus logs, ultimos 2 check-ins, asignacion gym activa, conteo de sesiones gym completadas.
- La logica de mapeo vive en `mapCoachAthleteRelation()` en `infrastructure/db/coach_athlete.mapper`.

---

### `GET /api/coach/payments` y `POST /api/coach/payments`

**GET — Response:**
```ts
{
  payments: Array<Payment & { athlete: { id, name, email } }>
}
```
Ordenado por `[status asc, dueDate desc]` (PENDING antes que PAID, mas recientes primero).

**POST — Request body:**
```ts
{
  athleteId: string
  amount: number        // > 0
  currency?: string     // default "COP"
  description?: string
  dueDate: string       // ISO date
  notes?: string
}
```

**Response 201:**
```ts
{ payment: Payment & { athlete: { id, name, email } } }
```

**Logica:**
1. Verificar `CoachAthlete.findUnique({ coachId_athleteId: { coachId, athleteId } })` (sin filtro de status) — 404 si no.
2. Validar que `dueDate` sea fecha valida.
3. `$transaction`: `Payment.create` + `PaymentAuditLog.create({ action: 'CREATED' })`.

---

### `PATCH /api/coach/payments/[paymentId]`

**Request body:**
```ts
{ status: 'PENDING' | 'PAID', paidAt?: string }
```

**Logica:**
1. Verificar `Payment { id: paymentId, coachId }` — 404 si no.
2. `$transaction`: `Payment.update({ status, paidAt })` + `PaymentAuditLog.create({ action: status === 'PAID' ? 'MARKED_PAID' : 'REMINDED' })`.
3. Si `status === 'PAID'` y `paidAt` no viene → usar `new Date()`.
4. Si `status === 'PENDING'` → `paidAt` se setea a `null`.

---

### `DELETE /api/coach/payments/[paymentId]`

**Logica:**
1. `$transaction`: buscar payment con `findFirst({ coachId })` — throw `{ code: 'NOT_FOUND' }` si no existe.
2. Crear `PaymentAuditLog({ action: 'DELETED' })` antes de borrar.
3. `Payment.delete`.
4. Catch `NOT_FOUND` → 404.

---

## Modelos DB involucrados

```prisma
model CoachAthlete {
  id           String        @id @default(cuid())
  coachId      String
  athleteId    String
  status       AthleteStatus @default(ACTIVE)
  coachGoal    String?       // meta visible para el atleta
  privateNotes String?       // notas privadas — el atleta NUNCA las ve
  createdAt    DateTime      @default(now())
  updatedAt    DateTime      @updatedAt

  @@unique([coachId, athleteId])
  @@index([athleteId])
  @@index([coachId, status])
}

enum AthleteStatus {
  ACTIVE
  PAUSED
  // REMOVED no existe — no implementar
}

model InviteCode {
  id        String    @id @default(cuid())
  code      String    @unique   // "MEDAL-XXXXXX"
  coachId   String
  usedBy    String?             // athleteId — FK SetNull
  usedAt    DateTime?
  expiresAt DateTime            // createdAt + 7 dias
  createdAt DateTime  @default(now())
}

model CoachProfile {
  id               String    @id @default(cuid())
  coachId          String    @unique
  slug             String    @unique
  primarySpecialty CoachSpecialty @default(ALL)  // @deprecated — usar specialties[]
  bio              String?
  avatarUrl        String?
  headline         String?
  specialties      String[]  // fuente canonica: ["RUNNING", "GYM", "NUTRITION", ...]
  city             String?
  country          String    @default("CO")
  whatsapp         String?
  instagram        String?
  yearsExp         Int?
  certifications   String[]
  isPublic         Boolean   @default(false)
  programs         CoachProgram[]
  posts            CoachPost[]
}

model Payment {
  id          String        @id @default(cuid())
  coachId     String
  athleteId   String?       // FK SetNull al eliminar atleta
  amount      Decimal       @db.Decimal(12, 2)
  currency    String        @default("COP")
  description String?
  dueDate     DateTime
  paidAt      DateTime?
  status      PaymentStatus @default(PENDING)
  notes       String?
  auditLogs   PaymentAuditLog[]

  @@index([coachId, status])
  @@index([coachId, athleteId])
}

enum PaymentStatus {
  PENDING
  PAID
}

model PaymentAuditLog {
  id        String   @id @default(cuid())
  paymentId String
  action    String   // CREATED | MARKED_PAID | REMINDED | DELETED
  actorId   String
  note      String?
  createdAt DateTime @default(now())
}

model TierFeatureConfig {
  id               String          @id @default(cuid())
  userType         AthleteUserType @unique   // B2C_FREE | B2C_PRO | B2B
  featurePlan      Boolean         @default(false)
  featureCheckin   Boolean         @default(false)
  featureNutrition Boolean         @default(true)
  featureProgress  Boolean         @default(false)
  featureLog       Boolean         @default(true)
  featureGym       Boolean         @default(true)
  updatedAt        DateTime        @updatedAt
  updatedBy        String?
}
```

---

## Reglas de negocio (invariantes)

1. **Un atleta, un coach activo**: `CoachAthlete` puede tener multiples filas para el mismo `athleteId` (con coaches distintos), pero solo puede haber una con `status: 'ACTIVE'`. `/clients/link` lo valida con `findFirst({ athleteId, coachId: { not: coachId }, status: 'ACTIVE' })`.

2. **PAUSED no bloquea al atleta**: un atleta PAUSED revierte a B2C con sus feature flags de `B2C_FREE`. No va a `/pending`, no pierde historial, puede seguir usando la app de forma autonoma.

3. **Features las define TierFeatureConfig, no el coach**: el coach ejecuta `ACTIVE` o `PAUSED` — el sistema consulta `TierFeatureConfig` para saber que features aplicar. Si un admin cambia `TierFeatureConfig.B2B`, el proximo toggle del coach ya aplica la nueva config.

4. **Plan anterior siempre se cierra**: cualquier asignacion de plan (4 endpoints) usa `TrainingPlan.updateMany({ status: 'ACTIVE' }, { status: 'COMPLETED' })` dentro de la transaccion antes de crear el nuevo. No puede quedar un atleta con dos planes ACTIVE.

5. **Limite de tier se evalua en create, no en link**: `getCoachLimits` solo se aplica en `/clients/create`. `/clients/link` (vincular B2C existente) no verifica el limite — decision de producto intencional.

6. **Perfil del coach bloquea creacion de atletas**: `identification` y `phoneWa` son requeridos antes de poder crear atletas. Son los 3 identificadores anti-fraude del coach (junto con email). Sin ellos → 403 `PROFILE_INCOMPLETE`.

7. **InviteCode no vincula automaticamente**: crear un InviteCode y que un atleta lo use son flujos separados. El codigo `POST /api/coach/invite` solo crea el registro. El join real ocurre via `/api/coach/join` (usando `profileId + programId`, no el codigo directamente desde el panel).

8. **Pagos son tracking manual**: no hay integracion de pasarela para cobros coach→atleta. El coach registra lo que cobra offline y marca manualmente como pagado. Todo cambio de estado genera `PaymentAuditLog`.

9. **`coachGoal` vs `privateNotes`**: `coachGoal` es visible para el atleta en su app. `privateNotes` es solo para el coach — no se expone en ningun endpoint de atleta.

10. **`specialties[]` vacio = acceso total**: un coach sin especialidades configuradas ve todas las herramientas del panel (backward compat). Codigo nuevo debe usar `coachCanDo(sp, discipline)` — no comparar directamente contra el array.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Status REMOVED | Parece que existe para "eliminar" la relacion | No existe en el enum `AthleteStatus`. Solo ACTIVE y PAUSED. No hay endpoint de eliminacion de relacion en este modulo. |
| `PATCH /status` activa features especificas | Parece que el coach controla que features activar | El coach solo dice ACTIVE/PAUSED — el sistema aplica `TierFeatureConfig` del admin. No hay toggles granulares por atleta. |
| `PATCH /config` activa/pausa al atleta | El nombre "config" suena a configuracion completa | Solo actualiza `coachGoal` y `privateNotes` en `CoachAthlete`. Para status → `/status`. |
| `plan/copy-from` solo verifica atleta destino | Parece que basta con ser coach del atleta destino | Tambien verifica que el coach sea dueno del atleta **fuente** del plan origen. Si la fuente es de otro coach → 403. |
| `/coach/join` valida coach unico | Parece que deberia validar el limite de un coach activo | `CoachAthlete.upsert` no valida si el atleta ya tiene otro coach ACTIVE. A diferencia de `/clients/link`, este endpoint es para marketplace y pasa silenciosamente. |
| `startDate` del plan se usa tal cual | Parece que cualquier fecha lunes/miercoles/viernes funciona | `forceMonday()` siempre reescribe la fecha al lunes de esa semana. El plan siempre empieza en lunes. |
| `dayOfWeek` en templates usa 1=Lun | Parece que DB tambien usa 1=Lun | Templates usan 1-7 (1=Lun,7=Dom). DB/builder usa 0-6 (0=Lun,6=Dom). `from-template` hace `s.dayOfWeek - 1` al persistir. |
| `atletaId` en Payment es FK obligatoria | Parece que el pago siempre tiene atleta | `Payment.athleteId` es `String?` — FK SetNull. Si el atleta se elimina, el pago queda con `athleteId: null`. |
| Limite de tier aplica en link | Parece que agregar cualquier atleta consume el cupo | El limite solo aplica en `/clients/create`. Vincular un atleta B2C existente no verifica limite de tier. |
| `identification` y `phoneWa` estan en CoachProfile | Parece que son campos del perfil publico | Estan en el modelo `User` (campos `identification` y `phoneWa`). `CoachProfile` tiene `whatsapp` (diferente — para contacto publico). |
| AthleteDetail applyPhaseTargets | Aplica targets directos | Usa `nutritionDraft` (estado local del builder) — no el plan de DB directamente. El draft puede tener cambios no guardados. |
| AthleteDetail toggle/reset errors | El estado de error se maneja automaticamente | Los estados de error de toggle y reset DEBEN tener elementos de renderizado en JSX — sin ellos el error es silencioso. |
| benchmarks/nutrition plan/status req.json() | El body siempre es JSON valido | Deben usar `req.json().catch(() => null)` — body vacio o malformado causa 500 sin el catch. Ver T18 en `_traps.spec.md`. |

---

## Paridad web <-> mobile

El panel de gestion del coach es exclusivamente web. La unica excepcion es un endpoint de lectura para coaches en mobile:

| Web | Mobile | Diferencia |
|-----|--------|-----------|
| `GET /api/coach/dashboard/athletes` | `GET /api/mobile/coach/athletes` | Mobile-only para coach. Devuelve lista simplificada de atletas activos del coach para uso en app mobile del coach |
| `POST /api/coach/athletes/[id]/status` | No existe | Solo web |
| `POST /api/coach/clients/create` | No existe | Solo web |
| `POST /api/coach/clients/link` | No existe | Solo web |
| `POST /api/coach/athletes/[id]/plan/*` | No existe | Solo web |
| `POST /api/coach/invite` / `GET` | No existe | Solo web |
| `GET/PATCH /api/coach/profile` | No existe | Solo web |
| `GET/POST/PATCH/DELETE /api/coach/payments/*` | No existe | Solo web |

**`GET /api/mobile/coach/athletes` (mobile-only):**
- Auth: `getMobileUser()` con `role === 'COACH'`
- Devuelve atletas activos del coach para navigation/contexto en app mobile
- Sin cursor pagination — lista plana optimizada para mobile
- Scope: solo `CoachAthlete` con `status: 'ACTIVE'` del coach autenticado

Los efectos de las acciones del coach en web si son visibles en mobile para el atleta:
- `PATCH /status ACTIVE` → push notification al atleta + features habilitadas en app.
- `PATCH /status PAUSED` → push notification + features revertidas.
- Plan asignado → visible en `/api/mobile/plan`.

---

## Tests requeridos

- [ ] `PATCH /status ACTIVE`: verifica que `TierFeatureConfig.B2B` se aplica via `mergeFeatures`. Verifica que `CoachAthlete.status` queda en ACTIVE.
- [ ] `PATCH /status PAUSED`: verifica que `TierFeatureConfig.B2C_FREE` se aplica. Verifica que el atleta sigue activo como usuario (no bloqueado).
- [ ] `PATCH /status` con valor invalido: retorna 400.
- [ ] `PATCH /status` sin relacion coach-atleta: retorna 404.
- [ ] `PATCH /config` con body vacio (sin coachGoal ni privateNotes): retorna 400.
- [ ] `PATCH /config` con `coachGoal: null`: actualiza a null correctamente.
- [ ] `POST /clients/create` con limite alcanzado: retorna 402 con `code: 'COACH_LIMIT_REACHED'`.
- [ ] `POST /clients/create` sin identification/phoneWa del coach: retorna 403 `PROFILE_INCOMPLETE`.
- [ ] `POST /clients/create` con email ya registrado: retorna 409.
- [ ] `POST /clients/create` exitoso: crea User con todas las features en `false`, crea CoachAthlete, crea HealthProfile si se pasan datos fisicos.
- [ ] `POST /clients/link` con atleta que tiene otro coach ACTIVE: retorna 409 con nombre del otro coach.
- [ ] `POST /clients/link` concurrente (P2002): retorna 409 limpio.
- [ ] `POST /athletes/[id]/plan` con atleta PAUSED: retorna 404.
- [ ] `POST /athletes/[id]/plan` sin HealthProfile del atleta: retorna 400.
- [ ] `POST /athletes/[id]/plan/from-template` desactiva plan anterior en la misma transaccion.
- [ ] `POST /athletes/[id]/plan/custom` con `totalWeeks: 0` o `totalWeeks: 53`: retorna 400.
- [ ] `POST /athletes/[id]/plan/copy-from` con plan de atleta de otro coach: retorna 403.
- [ ] `POST /athletes/[id]/plan/copy-from` nombra el plan como `"${nombre} (copia)"`.
- [ ] `PATCH /profile` con slug en uso por otro coach: retorna 409.
- [ ] `PATCH /profile` con identification duplicada entre coaches: retorna 409.
- [ ] `PATCH /profile` con phoneWa en formato invalido: retorna 400.
- [ ] `POST /payments` sin relacion coach-atleta: retorna 404.
- [ ] `POST /payments` exitoso: crea Payment + PaymentAuditLog en la misma transaccion.
- [ ] `PATCH /payments/[id]` PAID: setea `paidAt` a `new Date()` si no viene en el body.
- [ ] `PATCH /payments/[id]` PENDING: setea `paidAt` a `null`.
- [ ] `DELETE /payments/[id]` de otro coach: retorna 404.
- [ ] `GET /dashboard/athletes`: verifica cursor pagination (hasMore, nextCursor).
- [ ] `GET /clients/check` con email de no-atleta (COACH/ADMIN): retorna `{ exists: false }`.

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo real — routes + domain + schema |
| 2026-10-02 | Paridad web↔mobile completada: GET /mobile/coach/athletes documentado | Revision de paridad |
| 2026-10-03 | PATCH /status: 403→402 con response enriquecida (nextTier/nextPrice/nextLimit). Rate limit 30/min documentado | Auditoria SDD |
| 2026-10-09 | Auditoria pre-prod: AthleteDetail applyPhaseTargets usa nutritionDraft, toggle/reset error states renderizados, benchmarks/nutrition plan/status req.json().catch | 8 rondas de auditoria |
