# Spec: Modulo Gym (Ejercicios)

<!-- mirror: true -->
<!-- mirror-endpoints: GET /api/athlete/gym/week ↔ /api/mobile/gym/week, POST /api/athlete/gym/complete ↔ /api/mobile/gym/complete, GET /api/exercises/search ↔ /api/mobile/exercises/search -->

> Extraido del codigo fuente. Fuente canonica de contratos, logica de negocio, trampas y paridad web/mobile.
> Leer antes de tocar cualquier endpoint de `/api/athlete/gym/`, `/api/mobile/gym/`, `/api/exercises/`, `/api/mobile/exercises/`, `/api/admin/exercises/`, `/api/coach/gym/exercises/`.
> Domain doc complementario: `entrenamiento.md`
> **Scope:** Esta spec cubre endpoints de atleta y mobile. Coach gym routes → ver `coach_gym.spec.md`.

## TL;DR
- 20 endpoints (10 web, 10 mobile)
- Modelos: Exercise, GymSession, SetLog, AssignedWorkout, WorkoutTemplate, WorkoutDay, WorkoutExercise
- Dependencias: getGymWeek() use case, GymCompleteSchema, isPR detection, suggestedNextWeightKg
- Trampas criticas: isPR usa max historico (no sesion anterior), gym overlay nunca pisa sesion deportiva, DOW de GymSession se deriva de fecha real
- Mirror mobile: week, complete, set-log, exercises/search (schemas identicos)

---

## Contratos de datos

### GymCompleteSchema (Zod — compartido web + mobile)
`src/domain/gym/gym_session.schemas.ts`

```ts
GymCompleteSchema = z.object({
  assignedWorkoutId:  z.string().min(1).optional(),
  plannedSessionId:   z.string().min(1).optional(),
  dayOfWeek:          z.number().int().min(0).max(6),
  rpe:                z.number().int().min(1).max(10).optional(),
  durationMin:        z.number().int().min(0).max(600).optional(),
  energyState:        z.enum(['EXHAUSTED', 'NORMAL', 'ENERGIZED']).optional(),
  discomfort:         z.enum(['NONE', 'MILD', 'MODERATE']).optional(),
  notes:              z.string().max(2000).optional(),
  sets:               z.array(SetPayloadSchema).max(300).optional(),
  exerciseOverrides:  z.array(ExerciseOverrideSchema).max(50).optional(),
})

SetPayloadSchema = z.object({
  workoutExerciseId:  z.string().min(1).optional(),
  exerciseName:       z.string().max(200).optional(),
  setNumber:          z.number().int().min(1).max(20),
  weightKg:           z.number().min(0).max(1000).nullable(),
  repsCompleted:      z.number().int().min(0).max(200).nullable(),
  completed:          z.boolean(),
  setLogType:         z.enum(['WORK', 'WARMUP', 'DROPSET']).optional(),
  rpe:                z.number().int().min(1).max(10).optional(),
})

ExerciseOverrideSchema = z.object({
  originalWorkoutExerciseId: z.string().min(1),
  replacedWithExerciseId:    z.string().min(1),
  replacedExerciseName:      z.string().max(200),
  reason:                    z.string().max(500).optional(),
})
```

### TemplateBody (sin Zod — validacion manual)
Usado en `POST /api/athlete/gym/routines` y `POST /api/mobile/gym/routines`:
```ts
{
  name:        string         // requerido, trim
  description: string?
  goal:        string?
  level:       string?
  daysPerWeek: number
  days: {
    dayOfWeek:    number
    label:        string
    muscleGroups: string[]
    isRestDay:    boolean
    warmupNotes?: string
    cardioNotes?: string
    exercises: {
      exerciseId:   string
      sets:         number
      repsScheme:   string
      restSeconds?: number | null
      setType?:     string        // SetType enum
      notes?:       string
      order:        number
    }[]
  }[]
}
```

---

## Tabla de endpoints

| Ruta | Método | Auth | Feature gate | Rate limit |
|------|--------|------|-------------|------------|
| `/api/athlete/gym/session/today` | GET | `auth()` | `featureGym` (manual) | ninguno |
| `/api/athlete/gym/session/complete` | POST | `auth()` | `featureGym` (manual) | ninguno |
| `/api/athlete/gym/session/[id]` | GET | `auth()` | ninguno | ninguno |
| `/api/athlete/gym/session/[id]` | PATCH | `auth()` | ninguno | ninguno |
| `/api/athlete/gym/assign` | POST | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/routines` | GET | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/routines` | POST | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/routines/[id]` | GET | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/routines/[id]` | PATCH | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/routines/[id]` | DELETE | `auth()` | `featureGym` (session) | ninguno |
| `/api/athlete/gym/gif/[id]` | GET | **publico** | ninguno | 200 req/min por IP |
| `/api/athlete/gym/exercises/search` | GET | `auth()` | ninguno | ninguno |
| `/api/athlete/gym/exercises/[id]` | GET | `auth()` | ninguno | ninguno |
| `/api/mobile/gym/today` | GET | `getMobileUser()` | `gym` | 300 req/min |
| `/api/mobile/gym/complete` | POST | `getMobileUser()` | `gym` | 60 req/min |
| `/api/mobile/gym/assign` | POST | `getMobileUser()` | ninguno | 30 req/min |
| `/api/mobile/gym/routines` | POST | `getMobileUser()` | ninguno | 30 req/min |
| `/api/mobile/gym/week` | GET | `getMobileUser()` | `gym` | 300 req/min |
| `/api/mobile/gym/history` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/mobile/gym/prs` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/mobile/gym/routines` | GET | `getMobileUser()` | `gym` | 300 req/min |
| `/api/mobile/gym/routines/[id]` | GET | `getMobileUser()` | `gym` | 300 req/min |
| `/api/mobile/gym/routines/[id]` | PATCH | `getMobileUser()` | `gym` | 60 req/min |
| `/api/mobile/gym/routines/[id]` | DELETE | `getMobileUser()` | `gym` | 30 req/min |
| `/api/mobile/gym/templates` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/mobile/dashboard/week-sessions` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/exercises` | GET | `auth()` | ninguno | ninguno |
| `/api/exercises/[id]` | GET | `auth()` | ninguno | ninguno |
| `/api/exercises/[id]/similar` | GET | `auth()` | ninguno | ninguno |
| `/api/mobile/exercises` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/mobile/exercises/[id]` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/mobile/exercises/[id]/alternatives` | GET | `getMobileUser()` | ninguno | 300 req/min |
| `/api/coach/gym/exercises` | GET | `auth()` COACH | ninguno | ninguno |
| `/api/coach/gym/exercises` | POST | `auth()` COACH | ninguno | ninguno |
| `/api/coach/gym/exercises/[id]` | GET | `auth()` COACH | ninguno | ninguno |
| `/api/admin/exercises` | GET | `auth()` ADMIN | ninguno | ninguno |
| `/api/admin/exercises` | POST | `auth()` ADMIN | ninguno | ninguno |
| `/api/admin/exercises/[id]` | PATCH | `auth()` ADMIN | ninguno | ninguno |
| `/api/admin/exercises/[id]` | DELETE | `auth()` ADMIN | ninguno | ninguno |
| `/api/admin/exercises/sync` | POST | `auth()` ADMIN | ninguno | ninguno |

---

## Endpoints — documentacion detallada

### GET /api/athlete/gym/session/today
**Delegado a:** `getTodaySession(athleteId, timezone, prisma)` en `src/domain/gym/get_today_session.use_case.ts`

**Feature gate:** `featureGym` leído en la ruta desde `prisma.user.findUnique({ where: { id: athleteId }, select: { featureGym: true, timezone: true } })`. Sin `featureGym` → 403.

**Logica de routing (prioridad fija):**
1. `AssignedWorkout` activo con dia para hoy → carga ejercicios del `WorkoutDay`
2. `PlannedSession` tipo `FUERZA` con `workoutDayId != null` para la semana activa → carga ejercicios del `WorkoutDay`
3. Fallback libre → `freeSession: true`, `exercises: []`

**Calculo de `todayDow`:**
```ts
const tz = timezone ?? 'America/Bogota'
jsToOurDow(new Date(new Date().toLocaleString('en-US', { timeZone: tz })).getDay())
// 0=Sun en JS → convertido a 7; 1=Mon → 1 (esquema 1=lun…7=dom)
```

**Queries en paralelo (5 queries):**
1. `trainingPlan.findFirst({ where: { userId: athleteId, status: 'ACTIVE' } })`
2. `assignedWorkout.findFirst({ where: { athleteId, isActive: true }, include: { template.days[dayOfWeek: todayDow].exercises } })`
3. `coachAthlete.findFirst({ where: { athleteId, status: 'ACTIVE' } })`
4. `trainingPlan.findFirst` con `weeks.sessions[dayOfWeek: todayDow, type: { notIn: ['FUERZA','DESCANSO'] }]` → `plannedRunToday`
5. `weeklyRoutine.findUnique({ where: { userId: athleteId } })`

**Respuesta (AssignedWorkout path, dia de entrenamiento):**
```ts
{
  assignedWorkoutId: string,
  plannedSessionId: null,
  templateName: string,
  dayOfWeek: number,          // 1–7
  isRestDay: false,
  hasCoach: boolean,
  workoutDay: { id, label, muscleGroups, warmupNotes, cardioNotes },
  exercises: [{
    id,           // workoutExercise.id
    order, sets, repsScheme, restSeconds, notes, setType, supersetWith,
    suggestedNextWeightKg,
    exercise: { id, name, bodyPart, target, equipment, mechanic, description, gif },
    previousLogs: [{ setNumber, weightKg, repsCompleted, completed }]
  }],
  previousLogs: SetLog[],     // logs de la sesion previa del mismo dia/rutina
  plannedSession: null,
  plannedRunToday: { type, durationMin, zoneTarget } | null,
}
```

**Respuesta (plan path, FUERZA):** igual con `assignedWorkoutId: null`, `plannedSessionId: string`.

**Respuesta (libre):**
```ts
{
  assignedWorkoutId: null, plannedSessionId: null,
  templateName: string,   // split name o 'Sesion libre'
  dayOfWeek, isRestDay: boolean, freeSession: true,
  selfCoachDay: { dow, activity, split?, runType? } | null,
  hasCoach, workoutDay: null, exercises: [], previousLogs: [],
  plannedSession: null, plannedRunToday: ...
}
```

**GIF resolution:** `resolveExerciseGifUrl(exerciseId, gifStoredUrl, gifUrl)`:
- Si `gifStoredUrl` → devuelve directo (CDN propio / AscendAPI Cloudflare).
- Si `gifUrl` → devuelve `/api/athlete/gym/gif/${exerciseId}` (proxy WorkoutX).
- Si ninguno → `null`.

**Nombre del ejercicio:** `nameEs ?? name` (español preferido).

---

### POST /api/athlete/gym/session/complete | POST /api/mobile/gym/complete
**Delegado a:** `completeGymSession(athleteId, name, timezone, body, prisma)` en `src/domain/gym/complete_session.orchestrator.ts`

**Tres caminos de sesion:**

**1. Plan-based (`body.plannedSessionId` presente):**
- Verifica: `plannedSession.findFirst({ where: { id, week.plan.userId: athleteId, status:'ACTIVE', type:'FUERZA' } })` → 404 si no.
- Idempotencia: `gymSession.findFirst({ where: { athleteId, plannedSessionId } })` → si existe → `{ alreadyCompleted: true }` (HTTP 200).
- Crea `GymSession` con `assignedWorkoutId: null`.
- Post-write: llama `autoCompleteStrengthSession()` (fire-and-forget).

**2. Libre (`body.assignedWorkoutId` ausente):**
- Crea `GymSession` con `assignedWorkoutId: null, plannedSessionId: null`.
- PR detection via `exerciseName` (`collectPRsByName`).
- No llama `autoCompleteStrengthSession`.

**3. AssignedWorkout (`body.assignedWorkoutId` presente):**
- Verifica: `assignedWorkout.findFirst({ where: { id, athleteId, isActive: true } })` → 404 si no.
- Idempotencia: `gymSession.findFirst({ where: { athleteId, assignedWorkoutId, date: today } })` → `{ alreadyCompleted: true }` (HTTP 200).
- Crea `GymSession` con `plannedSessionId: null`.
- No llama `autoCompleteStrengthSession`.

**P2002 handling:** si la `gymSession.create` falla con Prisma `P2002` (race condition) → lookup del duplicado → `{ alreadyCompleted: true }`.

**PR detection:**
- Pre-fetcha todos los `SetLog` con `weightKg not null` + `completed: true` del atleta por ejercicio → `maxPerExercise` (Map exerciseId → max kg).
- Para sets libres: pre-fetcha por `exerciseName` → `maxPerFreeExerciseName`.
- `isPRSet`: `completed && weightKg !== null && weightKg > maxPerExercise[exerciseId]`.
- `isPRByName`: mismo criterio con `maxPerFreeExerciseName`.
- `SetLog.isPR` se persiste como immutable. No se recalcula despues.

**Progresion de cargas (`computeProgressionUpdates`):**
- `completedRatio > 0.9` (>90%) → `suggestedNextWeightKg = maxWeight + 2.5`
- `completedRatio < 0.6` (<60%) → `suggestedNextWeightKg = max(maxWeight - 2.5, 0)`
- Entre 60% y 90% → sin sugerencia.
- Orphan recovery: si `workoutExerciseId = null` pero `exerciseName` mapea al `weNameToWeIdMap` → recupera `workoutExerciseId` del ejercicio actual (maneja edicion de template por coach).
- Fire-and-forget: `prisma.workoutExercise.update` para cada ejercicio. Errores se swallow con `console.error`.

**Caloria estimation (`estimateCalories`):**
- `Math.round(durationMin * avgCpm)` donde `avgCpm` = promedio de `exercise.caloriesPerMinute` de los ejercicios de la sesion. Fallback: 5.0 kcal/min (MET ~4, persona 70 kg).
- Si `durationMin` es undefined/0 → `null`.

**`sanitizeWeId`:** valida que `workoutExerciseId` exista en los maps pre-fetched. Si no existe → `null`. Previene FK constraint errors cuando el coach borra y recrea ejercicios en el template.

**Side effects (fire-and-forget):**
- `notifyCoach()`: busca `coachAthlete[athleteId, status:ACTIVE]` → push al coach via Expo.
- `createNotification()`: si hay nuevos PRs → notificacion LOGRO al atleta.
- `autoCompleteStrengthSession()`: solo en path plan-based → busca `PlannedSession FUERZA` del dia sin log y crea `SessionLog`.

**Respuesta:**
```ts
{
  sessionId: string,
  newPRs: [{ exerciseName: string | null, weightKg: number | null }],
  alreadyCompleted?: boolean
}
// HTTP 201 si nueva, 200 si alreadyCompleted
```

---

### GET /api/athlete/gym/session/[id]
**Query:** `gymSession.findFirst({ where: { id, athleteId }, include: { setLogs + workoutExercise.exercise, assignedWorkout.template.days } })`

**Respuesta:**
```ts
{
  id, date, dayOfWeek, dayLabel, muscleGroups,
  durationMin, rpe, notes, completed, templateName,
  setLogs: [{
    id, setNumber, weightKg, repsCompleted, completed, notes,
    exercise: { id, name, bodyPart, target, equipment, gifUrl, gifStoredUrl, gif },
    workoutExerciseId
  }]
}
```
`gif` resuelto via `resolveExerciseGifUrl`.

---

### PATCH /api/athlete/gym/session/[id]
Solo permite actualizar `energyState`. Valida que el valor sea uno de `['EXHAUSTED', 'NORMAL', 'ENERGIZED']`. Sin campo valido → 400.

---

### POST /api/athlete/gym/assign | POST /api/mobile/gym/assign
**Regla:** atleta con `coachAthlete[status:ACTIVE]` no puede auto-asignarse → 403.

**Template valido:** `workoutTemplate.findFirst({ where: { id: templateId, OR: [{ isPublic: true, isActive: true }, { athleteId }] } })` → 404 si no.

**Transaccion atomica (PERSIST-05):**
```ts
await tx.assignedWorkout.updateMany({ where: { athleteId, isActive: true }, data: { isActive: false } })
await tx.assignedWorkout.create({ data: { templateId, athleteId, coachId: null, startDate: new Date(), isActive: true } })
```
Evita race condition donde dos requests concurrentes crean dos rutinas activas.

**Respuesta:** `{ ok: true, id: assigned.id }`

---

### GET /api/athlete/gym/routines
Lista `workoutTemplate` donde `{ athleteId }` (rutinas propias). Include: dias con ejercicios ordenados por `order`, y `assignments[isActive: true]`.

### POST /api/athlete/gym/routines | POST /api/mobile/gym/routines
**Reglas:**
- Coach activo → 403.
- `name` requerido.
- Al menos un dia requerido.
- Ejercicios validados: `exercise.findMany({ where: { id: { in: exerciseIds }, coachId: null } })` — solo ejercicios de la libreria global (no custom de coach).

**Transaccion:** crea `WorkoutTemplate` → itera dias → crea `WorkoutDay` → crea `WorkoutExercise[]` via `createMany`. Defaults: `sets: 4`, `repsScheme: '12'`, `setType: 'NORMAL'`.

### GET | PATCH | DELETE /api/athlete/gym/routines/[id]
- Todas verifican ownership: `workoutTemplate.findFirst({ where: { id, athleteId } })`.
- PATCH: reemplaza dias completos (delete all → recreate). No actualiza ejercicios en lugar sino que los borra y recrea.
- DELETE: 409 si hay `assignments[isActive: true]` → debe desactivarse primero.

---

### GET /api/athlete/gym/gif/[id]
**Unico endpoint publico del modulo.** No requiere JWT.

**Logica de proxy:**
1. Rate limit: 200 req/min por IP (`x-forwarded-for`).
2. Verifica que el ejercicio exista en DB → 404 si no.
3. Si `gifStoredUrl` → `302 redirect` directo (sin proxy, sin WorkoutX).
4. Si `gifUrl` → fetch con `X-WorkoutX-Key` desde el servidor.
5. WorkoutX 401/403/404 → 404 al cliente. Otros errores upstream → 502.

**Cache headers:** `Cache-Control: public, max-age=604800, s-maxage=604800, stale-while-revalidate=86400` (7 dias).

**Env requerida:** `WORKOUTX_API_KEY`. Sin ella → 503.

---

### GET /api/athlete/gym/exercises/search
Busca en `nameEs` y `name` con `contains + insensitive`. Query param `q` minimo 2 chars (sin eso → `{ exercises: [] }`). Max 20 resultados, ordenados por `popularityRank asc`.

**Respuesta:** `{ exercises: [{ id, name, bodyPart, gif }] }` — `name` = `nameEs ?? name`, `bodyPart` traducido con `translateBodyPart`.

---

### GET /api/athlete/gym/exercises/[id]
Delega a `PrismaExerciseRepository.findById(id)`. Respuesta: objeto `Exercise` completo con todos los campos.

---

### GET /api/mobile/gym/week
**Params:** `weekOffset` (int, ±52 max), `selectedDow` (1–7), `tz` (string IANA).

**Dos paths:**

**Path AssignedWorkout (si `assigned` existe):**
- `assignedWorkout.findFirst` + `trainingPlan.findFirst` en paralelo.
- `weekNumber = floor((monday - planStart) / 86400000 / 7) + 1`
- Queries en paralelo: `gymSession.findMany` (semana + assignedWorkoutId) + `plannedSession.findMany` (running del plan activo para la semana).
- `buildDaySummaries` mapea 7 dias con: `{ dow, dateNum, isToday, isCompleted, isRest, hasSession, label, muscleGroup, runningSession }`.

**Path Plan (sin AssignedWorkout pero con `activePlan`):**
- `plannedSession.findMany` (FUERZA con workoutDayId, semana X) + `gymSession.findMany` en paralelo.
- Separa FUERZA vs running. Construye `fakeDays` como `TemplateDay[]` para reutilizar logica.
- `completedDows` = dias donde hay `GymSession.completed` linkado al `plannedSessionId`.

**`selectedDetail`:** para el `selectedDow` seleccionado, devuelve uno de:
- `{ type: 'completed', session: { durationMin, rpe, notes, exercises: ExerciseEntry[] } }`
- `{ type: 'planned', planned: { label, exercises: [{ name, sets, repsScheme }] } }`
- `{ type: 'rest' }` o `{ type: 'none' }`

MOB-2: usa datos pre-fetched del query principal — sin query extra para `selectedDetail`.

**Respuesta:**
```ts
{
  templateName, coachName, weekOffset, isCurrentWeek, mondayDate,
  completedCount, trainingDays, days: DaySummary[], selectedDetail
}
```

**Fallback sin plan ni rutina:** busca `sessionLog[freeSessionType:'FUERZA', plannedSessionId: null]` de la semana → `{ sessions, type: 'free', weekOffset, isCurrentWeek }` o 404.

---

### GET /api/mobile/gym/history
Queries en paralelo:
1. `gymSession.findMany({ where: { athleteId }, orderBy: { date: 'desc' }, take: 50, include: setLogs + assignedWorkout.template.days }`
2. `sessionLog.findMany({ where: { userId: athleteId, plannedSessionId: null, freeSessionType: 'FUERZA' }, take: 50 }`

**Calculo de volumen:** `sum(weightKg * repsCompleted)` para sets `completed = true`. `Math.round(volume)`.

**DOW de logs libres:** Conversion `jsToBase1()` aplicada — convierte JS day (0=domingo) a base-1 (1=lunes, 7=domingo).

**Date filter FREE users:** Filtro timezone-aware usando `toLocaleDateString('en-CA', { timeZone })` en lugar de `toDateString()` para evitar desfase UTC.

**Union y ordenacion:** merge de ambas listas → sort por fecha desc → `slice(0, 60)`. Logs libres sin datos (`durationMin === null && rpe === null && notes === null`) son filtrados.

**Respuesta:**
```ts
{
  sessions: GymHistoryEntry[],  // max 60
  stats: { total, completed, totalSets, totalVolumeKg }
}
// GymHistoryEntry.isFree = false (gym) | true (sessionLog libre)
```

---

### GET /api/mobile/gym/prs
Query: `setLog.findMany({ where: { session.athleteId, completed: true, weightKg: { not: null }, repsCompleted: { gte: 1, lte: 15 } } })`.

**Formula Epley:** `Math.round(kg * (1 + reps / 30) * 10) / 10` → estimado 1RM.

**Agrupa por `exerciseName`** (no por `workoutExerciseId`). Devuelve el maximo estimado 1RM por ejercicio.

**Nombre fallback:** Si `exerciseName` es null en SetLog, resuelve via `workoutExercise.exercise.name` como fallback.

**Respuesta:** `{ prs: [{ exerciseName, estimatedOneRM }] }`

---

### GET /api/mobile/gym/templates
Lista plantillas publicas: `workoutTemplate.findMany({ where: { isPublic: true, isActive: true }, include: { days[isRestDay] } })`.

**Respuesta:** `[{ id, name, description, goal, level, daysPerWeek, category, trainingDays }]` donde `trainingDays = days.filter(d => !d.isRestDay).length`.

---

### GET /api/mobile/dashboard/week-sessions (overlayGymSessions)
**Proposito:** calendar strip del dashboard mobile — combina sesiones de running (plan) + gym (AssignedWorkout).

**`overlayGymSessions(weekSessions, userId, weekOffset, timezone)`:**
```ts
// Slot condition (T15 trap):
if (weekSessions[idx].type && weekSessions[idx].type !== 'DESCANSO') continue
// Solo agrega gym si el slot esta vacio O solo tiene DESCANSO.
// Un slot con cualquier otro tipo (RODAJE, FUERZA_previo, etc.) no se sobreescribe.
```

**Queries en paralelo:**
1. `assignedWorkout.findFirst({ where: { athleteId: userId, isActive: true }, select: { template.days[isRestDay: false][dayOfWeek, label] } })`
2. `gymSession.findMany({ where: { athleteId: userId, date: { gte: monday, lte: sunday } }, select: { dayOfWeek, date, completed, durationMin } })`

**DOW de gymCompletions:** `new Date(gs.date).getUTCDay()` → `jsDay === 0 ? 7 : jsDay`.

**Cuando no hay `assignedWorkout`:** retorna `{ addedTraining: 0, addedCompleted: 0 }` inmediatamente.

**Slot fill:**
```ts
weekSessions[idx].type = 'FUERZA'
weekSessions[idx].durationMin = completion?.durationMin ?? 60  // default 60 min
weekSessions[idx].done = completion?.completed ?? false
weekSessions[idx].gymLabel = day.label
```

---

### Ejercicios — biblioteca global

#### GET /api/exercises | GET /api/mobile/exercises
Delega a `PrismaExerciseRepository.findAll(filters)`.

**Filtros:** `bodyPart`, `target`, `equipment`, `q` (busca en `name` + `nameEs`), `page`, `limit` (max 100).

**Where clause:**
```ts
{ AND: [
  coachId ? { OR: [{ coachId }, { coachId: null }] } : { coachId: null },
  // + filtros opcionales con mode: 'insensitive'
]}
```
Para coach: incluye ejercicios globales (coachId null) + los propios del coach.
Para atleta/mobile: solo globales (coachId null).

**Orden:** `[{ popularityRank: asc }, { name: asc }]`.

#### GET /api/exercises/[id] | GET /api/mobile/exercises/[id]
Delega a `repo.findById(id)`. Respuesta: entidad `Exercise` completa con `gif` resuelto.

#### GET /api/exercises/[id]/similar
Delega a `repo.findSimilar(id, limit)`. Mismo `bodyPart` + mismo `target`, excluyendo el ejercicio fuente. Default limit: 6.

#### GET /api/mobile/exercises/[id]/alternatives
**Logica diferente a `findSimilar`:**
1. Primaries: mismo `bodyPart` + (`equipment` igual OR `equipment === 'body weight'`), solo globales (`coachId: null`). Max 5.
2. Si `results.length < 5` → rellena con mismo `bodyPart`, cualquier equipment. No duplica IDs.
Orden: `[{ popularityRank: asc }, { name: asc }]`.

---

### Ejercicios — panel coach

#### GET /api/coach/gym/exercises
Requiere `role === 'COACH'`. Delega a `repo.findAll({ coachId, ...filters })` — devuelve globales + propios del coach.

#### POST /api/coach/gym/exercises
Crea ejercicio custom con `coachId = session.user.id`, `source: 'custom'`. Validado con `validateExercise()` del dominio.

#### GET /api/coach/gym/exercises/[id]
Delega a `repo.findById(id)`.

---

### Ejercicios — admin

#### GET /api/admin/exercises
Lista ejercicios globales: `exercise.findMany({ where: { coachId: null } })`. Solo ADMIN.

#### POST /api/admin/exercises
Crea ejercicio global manual con `coachId: null`, `source: 'manual'`.

#### PATCH /api/admin/exercises/[id]
Solo ejercicios globales (`coachId === null`). 404 si es de coach.

#### DELETE /api/admin/exercises/[id]
409 si `workoutExercise.count({ where: { exerciseId: id } }) > 0` — no se puede borrar si hay rutinas que lo usan.

#### POST /api/admin/exercises/sync
Sincroniza catalogo desde fuente externa controlada por `EXERCISE_SOURCE` env:
- `'workoutx'` → `WorkoutXClient` (requiere `WORKOUTX_API_KEY`)
- `'ascendapi'` (default) → `AscendApiClient`

**AscendApiClient:**
- URL base: `https://oss.exercisedb.dev/api/v1/exercises`
- Paginacion: cursor (`?after=<exerciseId>`), page size 25.
- Retry en 429: hasta 4 intentos, espera incremental (5s, 10s, 15s, 20s).
- Delay entre paginas: 400ms.
- `gifStoredUrl = raw.gifUrl` (CDN publico Cloudflare — sin necesidad de proxy).
- `source = 'ascendapi'`.

**`PrismaExerciseRepository.upsertMany`:**
- Batches de 50 ejercicios en `$transaction` con timeout 30s.
- `tx.exercise.upsert({ where: { id }, create, update })`.

---

## Modelos DB — campos clave

### GymSession
- `athleteId` — tenant key
- `assignedWorkoutId` — FK nullable a AssignedWorkout
- `plannedSessionId` — FK nullable a PlannedSession
- **Constraint DB:** `(assignedWorkoutId IS NULL OR plannedSessionId IS NULL)` — una sesion es de rutina O de plan, nunca ambos.
- `dayOfWeek` — 0–6 (formato JS, no 1–7)
- `date` — Date (local del atleta, calculada con `todayInTz(timezone)`)
- `energyState` — enum `EXHAUSTED | NORMAL | ENERGIZED | null`
- `discomfort` — enum `NONE | MILD | MODERATE | null`
- `caloriesBurned` — calculado por `estimateCalories`, nullable
- `completed` — siempre `true` al crear (el endpoint solo crea sesiones completadas)
- `exerciseOverrides` — JSON, nullable

### SetLog
- `workoutExerciseId` — FK nullable (null en sesiones libres o tras template edit)
- `exerciseName` — String nullable (denormalizado para historial)
- `isPR` — Boolean, immutable post-insert
- `setLogType` — `WORK | WARMUP | DROPSET` (default `WORK`)
- `rpe` — Int nullable, 1–10

### Exercise
- `coachId` — null = global, set = custom del coach
- `nameEs` — nombre en espanol del dataset WorkoutX
- `gifUrl` — URL WorkoutX (requiere proxy con `X-WorkoutX-Key`)
- `gifStoredUrl` — URL propia (S3/Blob/Cloudflare) — bypasea el proxy
- `popularityRank` — ordena el catalogo, null = sin rankear
- `source` — `'workoutx' | 'ascendapi' | 'custom' | 'manual'`
- `caloriesPerMinute` — usado por `estimateCalories`

### AssignedWorkout
- `athleteId` + `isActive` — un atleta solo tiene uno activo (enforced por transaccion en assign)
- `coachId` — null si el atleta se auto-asigno

### WorkoutExercise
- `suggestedNextWeightKg` — actualizado fire-and-forget por `computeProgressionUpdates`
- `setType` — `NORMAL | SUPERSET | BISERIE | DROPSET | CIRCUIT`
- `restSeconds` — descanso entre sets en segundos, nullable

---

## Reglas de negocio

### Routing de sesion (prioridad)
1. AssignedWorkout activo con dia para hoy → siempre gana
2. PlannedSession FUERZA con workoutDayId para la semana activa
3. Sesion libre (fallback)

### Un atleta — una rutina activa
`assignedWorkout.updateMany({ where: { athleteId, isActive: true }, data: { isActive: false } })` en la misma tx que el `create`. Previene race condition con `$transaction`.

### Coach bloquea self-service
- Auto-asignacion de rutina con coach activo → 403.
- Creacion propia de rutina con coach activo → 403.

### PR es inmutable
`SetLog.isPR` se guarda al momento de la sesion y nunca se recalcula. Si el historial cambia despues, los PRs previos permanecen igual.

### Sesion idempotente
`POST /complete` verifica si ya existe una sesion para el mismo `(athleteId, assignedWorkoutId, date)` o `(athleteId, plannedSessionId)`. Si existe → retorna `{ alreadyCompleted: true, sessionId }` con HTTP 200 sin crear duplicado.

### dayOfWeek en GymCompleteSchema
El schema acepta `z.number().int().min(1).max(7)` — formato base-1 (1=lunes, 7=domingo). Zod `min(1)` rechaza JS days sin conversion previa — el cliente DEBE convertir antes de enviar. El uso en la DB y el dominio es consistente con 1–7.

### SetLog.setLogType y volumen
- `WORK` → cuenta para volumen y PR detection
- `WARMUP` → excluido (no hay filtro activo en `/history` — se incluye en `completedSets` si `completed = true`)
- `DROPSET` → excluido de PR, incluido en volumen

---

## Trampas (bugs conocidos y decisiones no obvias)

### T01 — GymCompleteSchema dayOfWeek range
`GymCompleteSchema.dayOfWeek` valida `min(1).max(7)` (base-1). Zod `min(1)` rechaza JS days (0-6) sin conversion previa — el cliente DEBE usar `jsToBase1()` antes de enviar.

### T02 — overlayGymSessions: slot condition
```ts
if (weekSessions[idx].type && weekSessions[idx].type !== 'DESCANSO') continue
```
Slots con `type = 'DESCANSO'` SI se sobreescriben con gym. Slots con cualquier otro tipo no se tocan. Esto es por diseno (gym coexiste con running). Si se cambia esta condicion se rompe la coexistencia running+gym.

### T03 — overlayGymSessions: DOW derivado de date, no de GymSession.dayOfWeek
```ts
const jsDay = new Date(gs.date).getUTCDay()
const dow = jsDay === 0 ? 7 : jsDay
```
Usa `gs.date` (UTC) para derivar el DOW, no `gs.dayOfWeek`. Racional: `gs.date` es la fecha real, `gs.dayOfWeek` es el dia del template. Si el atleta registra una sesion fuera de su dia de template, `gs.dayOfWeek` podria no coincidir con la fecha real.

### T04 — weekNumber con Math.floor
```ts
const weekNumber = Math.floor((monday.getTime() - new Date(activePlan.startDate).getTime()) / 86_400_000 / 7) + 1
```
Sin `Math.floor` explicitamente visible en `build_gym_week.ts` — esta en `mobile/gym/week/route.ts` linea 58. El resultado puede ser 0 o negativo si `weekOffset` es negativo y el plan empezo esta semana. La ruta de plan-based en `gym/week` tiene guard `weekNumber >= 1`.

### T05 — autoCompleteStrengthSession solo en path plan-based
`autoCompleteStrengthSession` se llama SOLO cuando `body.plannedSessionId` esta presente. Para sesiones de `AssignedWorkout` o libres NO se llama. Esto es por diseno — solo las sesiones del plan activo afectan la adherencia del plan.

### T06 — sanitizeWeId: previene FK errors pero descarta datos
Si el `workoutExerciseId` del cliente no existe en los maps pre-fetched (coach borro y recreo el ejercicio) → se convierte en `null` y el set se guarda como huerfano (sin FK). El historial se preserva pero el link al ejercicio se pierde. No hay error visible al usuario.

### T07 — PR detection: doble lookup para exercises con weId
Para PR detection se fetcha:
1. Todos los `WorkoutExercise` del ejercicio (para mapear weId → exerciseId)
2. SetLogs historicos de todos esos weIds + SetLogs orphanos por nombre

Si el atleta tiene muchas sesiones historicas, estos queries pueden ser grandes. No hay paginacion ni limite.

### T08 — durationMin default 60 en overlayGymSessions
```ts
weekSessions[idx].durationMin = completion?.durationMin ?? 60
```
Si el atleta no registro duracion en la sesion, el slot muestra 60 min. Es un valor de display, no persiste en DB.

### T09 — history merge: freeLogs sin sets no se muestran
```ts
.filter(s => s.durationMin !== null || s.rpe !== null || s.notes !== null)
```
Logs libres de FUERZA sin ningun dato (sin duracion, RPE ni notas) se filtran del historial. Esto puede hacer que una sesion registrada no aparezca si el atleta solo la marco sin datos.

### T10 — GIF proxy: endpoint publico sin auth
`GET /api/athlete/gym/gif/[id]` es publico. Cualquier persona con la URL puede acceder. La unica proteccion es la rate limit por IP (200/min) y la validacion de que el ejercicio exista en DB. No hay exposicion de datos sensibles (solo GIFs de ejercicios).

### T11 — workoutExercise.suggestedNextWeightKg: fire-and-forget
Si el `update` de progression falla, el error se loguea en console pero la sesion ya fue creada exitosamente. El atleta no sabe que la sugerencia no se actualizo.

### T12 — AscendApiClient: sin nameEs
AscendAPI no provee nombres en espanol. Los ejercicios sincronizados desde Ascend tendran `nameEs = null`. El fallback `nameEs ?? name` en `getTodaySession` mostrara el nombre en ingles para ejercicios de Ascend.

### T13 — Ejercicios de coach: no validados al crear rutina propia
En `POST /api/athlete/gym/routines`, se valida: `exercise.findMany({ where: { id: { in: exerciseIds }, coachId: null } })`. Solo ejercicios globales (`coachId: null`) pueden usarse en rutinas de atleta. Ejercicios custom de un coach no pueden usarse en rutinas propias del atleta.

### T14 — DELETE WorkoutTemplate: 409 si tiene assignment activo
Si el atleta intenta borrar su rutina activa → 409. Debe desactivarla primero (asignando otra o via `/api/athlete/gym/assign` con otro templateId). No hay endpoint explícito de "desasignar" — la unica forma de desactivar es asignar otra.

### T15 — Paridad de slot condition en overlayGymSessions vs buildCalendarWeek
El comentario en el codigo dice "Mirrors web's buildCalendarWeek logic". Si se cambia la logica de `buildCalendarWeek` en el web, se debe actualizar `overlayGymSessions` en paralelo. No hay test que valide esta paridad.

---

## Paridad web vs mobile

| Feature | Web (`/api/athlete/gym/`) | Mobile (`/api/mobile/gym/`) | Diferencia |
|---------|--------------------------|------------------------------|-----------|
| Today session | `GET /session/today` | `GET /today` | Identico — mismo use case `getTodaySession` |
| Complete session | `POST /session/complete` | `POST /complete` | Identico — mismo orchestrator. Web tiene `revalidatePath('/dashboard')`, mobile no |
| Assign workout | `POST /assign` | `POST /assign` | Identico — misma logica |
| Create routine | `POST /routines` | `POST /routines` | Identico — misma logica. Diferencia menor en mensaje de error ("día" vs "dia") |
| List own routines | `GET /routines` | `GET /routines` | Identico — ambos listan templates del atleta con days+exercises+assignments |
| Routine detail | `GET /routines/[id]` | `GET /routines/[id]` | Identico — ownership check por athleteId |
| Edit routine | `PATCH /routines/[id]` | `PATCH /routines/[id]` | Identico — reemplaza días en $transaction |
| Delete routine | `DELETE /routines/[id]` | `DELETE /routines/[id]` | Identico — 409 si tiene assignment activo |
| Week view | No existe | `GET /week` | Solo mobile |
| History | No existe | `GET /history` | Solo mobile |
| PRs | No existe | `GET /prs` | Solo mobile |
| Templates publicos | No existe | `GET /templates` | Solo mobile |
| Session detail | `GET /session/[id]` | No existe | Solo web |
| Session patch | `PATCH /session/[id]` | No existe | Solo web |
| Exercises search | `GET /exercises/search` | Via `/api/mobile/exercises?q=` | Logica diferente: search usa `nameEs/name contains`, exercises usa `PrismaExerciseRepository` |
| Exercise detail | `GET /exercises/[id]` | `GET /exercises/[id]` | Mismo repo. Web responde `exercise` (wrapped), mobile responde `{ exercise }` (igual) |
| Similar exercises | `GET /exercises/[id]/similar` | `GET /exercises/[id]/alternatives` | Algoritmos distintos: similar = mismo bodyPart+target; alternatives = mismo bodyPart + equipment compatible |
| Feature gate | `session.user.features?.gym` | `requireFeature(mobile.features, 'gym')` | Ambos leen del JWT — web via Auth.js session, mobile via jose |
| Rate limiting | Ninguno | Si — via `rateLimitAsync` | Web no tiene rate limit en gym endpoints |

---

## Tests existentes

### `src/domain/gym/complete_gym_session.use_case.test.ts`
Cubre funciones puras del dominio:
- `isPRSet`: 8 casos (PR, igual al max, menor, no completado, peso null, weId undefined, weId no en mapa, ejercicio nuevo)
- `isPRByName`: 5 casos
- `computeProgressionUpdates`: 9 casos incluyendo orphan recovery con `weNameToWeIdMap`
- `collectPRsByWeId`: 2 casos
- `collectPRsByName`: 2 casos

### `src/app/api/athlete/gym/session/complete/route.test.ts`
Cubre la ruta web:
- 401 sin auth, 403 sin feature gym, 400 schema invalido
- energyState/discomfort: persiste valores validos, persiste null cuando no se envia
- Sesion libre con sets vacia → `newPRs: []`, `sessionId`
- Sesion con `assignedWorkoutId` → persiste en DB con los campos correctos
- Sesion con `plannedSessionId` → persiste en DB con los campos correctos

### Tests pendientes (no existen)
- `overlayGymSessions` — logica de slot condition no testeada
- `getTodaySession` — routing de prioridad no testeado
- `build_gym_week.ts` — `getWeekBounds`, `buildDaySummaries` no testeados
- `/api/mobile/gym/week` — logica de weekNumber y plan-based path no testeados
- Idempotencia de `completeGymSession` — race condition P2002 no testeada
- `autoCompleteStrengthSession` — integracion no testeada

---

## Historial

| Fecha | Cambio |
|-------|--------|
| 2026-09-29 | Creacion inicial del spec extraido del codigo fuente |
| 2026-10-09 | Auditoria pre-prod: dayOfWeek schema min(1) (base-1), history jsToBase1 + timezone-aware date filter FREE, freeLogs dayOfWeek timezone fix, PRs exerciseName fallback via workoutExercise.exercise.name, routines POST exercise validation solo globales, update_routine order dedup guard |
