# PLAN SESSIONS — Calendar, Sessions, Log, History

<!-- mirror: true -->
<!-- mirror-endpoints: PATCH /api/athlete/sessions/[sessionId] ↔ PATCH /api/mobile/sessions/[sessionId], GET /api/athlete/calendar ↔ GET /api/mobile/calendar, POST /api/athlete/log/session ↔ POST /api/mobile/log/session -->

> Split de plan.spec.md. Sesiones, calendario, logs de entrenamiento.
> Specs relacionadas: `plan_checkin.spec.md`, `plan_dashboard.spec.md`
> Domain doc: `../domains/plan.md`

## TL;DR
- 19 endpoints (10 web incl log/run/routine/week-print, 9 mobile incl history y delete)
- Modelos: PlannedSession, SessionLog, TrainingPlan, PlanWeek
- Dependencias: buildCalendarWeek(), getPlanWeekNumber(), todayDowInTz()
- Trampas criticas: T06 actualDurationMin vs durationMin, T07 sessionId vs plannedSessionId, T03 weekNumber del plan vs fechas, T08 energyState solo web
- Mirror mobile: log unifica run+session, mobile tiene wearable fields, delete solo mobile

---

## Contratos de la AI

- `buildCalendarWeek` usa `weekNumber` del plan (NO rangos de fecha) para cargar `PlannedSession`. Si `targetWeekNumber < 1` no carga sesiones.
- Mobile `POST log/session` usa `sessionId` para `plannedSessionId` y `actualDurationMin` para `durationMin`. Web usa los nombres directos.
- La idempotencia de `SessionLog` usa dos mecanismos: `findUnique({ where: { plannedSessionId } })` + catch P2002 (PERSIST-06).
- Wearable deduplication: si `externalId` presente y ya existe -> `{ ok: true, alreadyLogged: true }`.
- `DELETE /mobile/log/session/[logId]` solo permite borrar logs libres (`plannedSessionId = null`). Logs de plan no se borran.
- `POST /athlete/log/run` es web-only. Mobile unifica logs libres en `POST /mobile/log/session` con `sessionType`.
- `PATCH /mobile/log/session/[logId]` NO tiene campo `energyState` (web si lo tiene).

---

## Endpoints

### Web

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/athlete/calendar` | 300/min | ninguna | Semana de calendario unificado |
| PATCH | `/api/athlete/sessions/[sessionId]` | 100/min | featurePlan (session) | Editar sesion planificada |
| GET | `/api/athlete/plan/week-print` | 60/min | featurePlan (session) | Vista imprimible de la semana |
| POST | `/api/athlete/log/session` | 100/min | featureLog (session) | Registrar log de sesion (plan o libre) |
| PATCH | `/api/athlete/log/session/[logId]` | 100/min | ninguna | Editar log de sesion |
| DELETE | `/api/athlete/log/session/[logId]` | 100/min | ninguna | Eliminar log de sesion |
| GET | `/api/athlete/log/last-session` | 300/min | ninguna | Ultimo log libre por tipo |
| POST | `/api/athlete/log/run` | 100/min | ninguna | Registrar carrera libre (web only) |
| GET | `/api/athlete/routine` | 300/min | ninguna | Obtener rutina activa del atleta |
| PUT | `/api/athlete/routine` | 60/min | ninguna | Actualizar rutina del atleta |

### Mobile

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| PATCH | `/api/mobile/sessions/[sessionId]` | 100/min | `plan` | Editar sesion planificada |
| GET | `/api/mobile/calendar` | 300/min | ninguna | Semana de calendario unificado |
| GET | `/api/mobile/plan` | 60/min | ninguna | Plan activo completo o ultimo completado |
| POST | `/api/mobile/log/session` | 100/min | `log` | Registrar log (plan, libre, wearable) |
| PATCH | `/api/mobile/log/session/[logId]` | 100/min | ninguna | Editar log de sesion |
| DELETE | `/api/mobile/log/session/[logId]` | 100/min | ninguna | Eliminar log libre |
| GET | `/api/mobile/log/last-session` | 300/min | ninguna | Ultimo log libre por tipo |
| GET | `/api/mobile/log/history` | 300/min | ninguna | Feed ultimos 40 logs (run + gym) |

---

## Detalle de endpoints

### PATCH sessions (web y mobile)

**Ownership check**: `plannedSession.findFirst({ where: { id: sessionId, week: { plan: { userId } } } })`

**Campos editables** (sin Zod, validacion manual):
- `type`: uno de `VALID_TYPES` = `['RODAJE_Z2','FARTLEK','TEMPO','INTERVALOS','TIRADA_LARGA','FUERZA','CICLA','NATACION','DESCANSO','TEST','SIMULACRO','OTRO']`
- `durationMin`: number > 0
- `zoneTarget`: string (vacio -> null)
- `detailText`: string (vacio -> null)

**400** si ningun campo valido en el body. Mobile tiene feature gate `plan`.

### GET calendar (web y mobile)

**Query params**: `weekOffset` (int, -52..52, default 0), `tz` (IANA timezone, opcional)

**Funcion compartida**: `buildCalendarWeek(userId, weekOffset, timezone?)` en `/infrastructure/db/calendar.ts`.

**buildCalendarWeek** — merges tres fuentes:
1. `PlannedSession` de la semana por `weekNumber` del plan activo
2. `AssignedWorkout` -> `WorkoutDay` (dias de gym del template activo)
3. `GymSession` de la semana (por rango de fechas `monday..sunday`)
4. `SessionLog` libre (sin `plannedSessionId`, con `freeSessionType != null`)

**Calculo de semana**:
- `getWeekMonday(weekOffset, timezone)` -> lunes UTC-midnight
- `currentPlanWeek = getPlanWeekNumber(plan.startDate, plan.totalWeeks)`
- `targetWeekNumber = currentPlanWeek + weekOffset`
- Solo carga `plannedSessions` si `targetWeekNumber >= 1`

**Response 200** (`CalendarWeek`):
```json
{
  "weekStart": "YYYY-MM-DD",
  "weekEnd": "YYYY-MM-DD",
  "label": "16-22 jun",
  "weekOffset": "number",
  "days": [{
    "date": "YYYY-MM-DD",
    "dow": "number (1=Mon..7=Sun)",
    "sport": { "sessionId", "type", "intensity", "durationMin", "done", "logId" },
    "gym": { "workoutDayId", "label", "templateName", "done", "durationMin" },
    "freeRun": { "sessionLogId", "type", "durationMin", "distanceKm" }
  }]
}
```

### GET `/api/mobile/plan`

**Flujo**:
1. `trainingPlan.findFirst({ where: { userId, status: 'ACTIVE' } })` con weeks+sessions+logs
2. Si no hay plan activo -> busca `status: 'COMPLETED'` mas reciente -> `{ lastCompletedPlan }`
3. Si no hay ningun plan -> `null`

**Response 200 (plan activo)**: plan completo con weeks, sessions, logs.
**Response 200 (ultimo completado)**: `{ lastCompletedPlan: { name, totalWeeks, endDate, sessionsLogged, sessionsTotal } }`
**Response 200 (sin plan)**: `null`

### POST `/api/athlete/log/session`

**Zod schema** (`LogSessionSchema`):
```ts
plannedSessionId?: string  min(1)
completed?:        boolean
rpe?:              int  min(1) max(10)
distanceKm?:       number  min(0) max(1000)
durationMin?:      int  min(0) max(600)
hrAvg?:            int  min(30) max(250)
hrMax?:            int  min(30) max(250)
notes?:            string  max(2000)
actualIntensity?:  enum('HIGH','MODERATE','LOW','REST')
discipline?:       enum('RUNNING','STRENGTH','CYCLING','SWIMMING','OTHER')
sessionDate?:      string  regex(/^\d{4}-\d{2}-\d{2}$/)
```

**Flujo**:
- Si `completed === false` -> `{ ok: true, skipped: true }`
- Si `plannedSessionId` + ya existe log -> `{ ok: true, id, alreadyLogged: true }`
- `sessionLog.create(...)` con catch P2002 -> `{ ok: true, alreadyLogged: true }` (PERSIST-06)
- Fire-and-forget: push al coach, notificacion nutricional si `actualIntensity != plannedIntensity`

### POST `/api/athlete/log/run` (web only)

**Zod**: `{ type: enum, durationMin?, distanceKm?, rpe?, notes? }`
Crea `SessionLog` con `plannedSessionId: null` y `freeSessionType: type`.

### POST `/api/mobile/log/session`

**Zod schema** (`LogSessionSchema`):
```ts
sessionId?:         string  min(1)              // plannedSessionId equivalente
sessionType?:       string  max(50)             // freeSessionType
completed?:         boolean
actualDurationMin?: int  min(0) max(600)        // DIFERENTE DE WEB
rpe?:               int  min(1) max(10)
hrAvg?:             int  min(30) max(250)
hrMax?:             int  min(30) max(250)
distanceKm?:        number  min(0) max(1000)
notes?:             string  max(2000)
actualIntensity?:   enum('HIGH','MODERATE','LOW','REST')
discipline?:        enum('RUNNING','STRENGTH','CYCLING','SWIMMING','OTHER')
sessionDate?:       string  regex
// Wearable fields:
dataSource?:        enum('MANUAL','STRAVA','GARMIN','HEALTHKIT')
externalId?:        string  max(200)
caloriesBurned?:    int  min(0) max(10000)
avgPaceSecPerKm?:   int  min(0) max(3600)
```

**Refinement**: `sessionId || sessionType` — 400 si ambos ausentes.

**Deduplicacion wearable**: si `externalId` y ya existe -> `{ ok: true, id, alreadyLogged: true }`.

### PATCH log (web y mobile)

**Ownership**: `sessionLog.findFirst({ where: { id: logId, userId } })`

**Campos**: `durationMin`, `rpe`, `hrAvg`, `notes`, `distanceKm`. Web tambien acepta `energyState` (T08).

### DELETE `/api/mobile/log/session/[logId]` (mobile only)

Solo permite borrar logs con `plannedSessionId = null`. Si tiene `plannedSessionId` -> 404.

### GET `/api/mobile/log/history` (mobile only)

Combina `sessionLog` (take: 30) + `gymSession` completadas (take: 30), ordena por fecha desc, toma primeros 40. Response: `{ sessions: [{ kind: "run"|"gym", ... }] }`.

### GET last-session (web y mobile)

**Query params**: `type` (requerido). Retorna `{ log: SessionLog | null }`.

---

## Modelos DB

### SessionLog
```
id, userId
plannedSessionId (string, nullable, unique)
freeSessionType (SessionType enum, nullable)
completedAt, sessionDate (DateTime, nullable)
rpe, hrAvg, hrMax (int, nullable)
distanceKm (Decimal, nullable)
durationMin (int, nullable)
notes, actualIntensity, discipline (string, nullable)
energyState (string, nullable) <- solo editable en web PATCH
dataSource, externalId (string, nullable) <- wearable dedup
caloriesBurned, avgPaceSecPerKm (int, nullable)
```

### PlannedSession
```
id, weekId (-> PlanWeek)
type (SessionType enum)
dayOfWeek (int, 1=Mon..7=Sun)
durationMin (int)
intensity, zoneTarget, detailText, coachNote (string, nullable)
structure (Json, nullable)
sportLabel (string, nullable)
log (SessionLog, 1:1 via plannedSessionId)
```

### TrainingPlan
```
id, userId, status ('ACTIVE'|'COMPLETED'|'CANCELLED')
name, source ('SYSTEM'|'COACH')
startDate, endDate, totalWeeks
weeks -> PlanWeek[]
```

---

## Reglas de negocio

1. **R03 — Idempotencia SessionLog**: `findUnique({ where: { plannedSessionId } })` + catch P2002 -> alreadyLogged.
2. **R04 — Solo borrar logs libres**: DELETE mobile solo permite `plannedSessionId = null`.
3. **R05 — weekOffset usa weekNumber del plan, NO fechas**: `targetWeekNumber = currentPlanWeek + weekOffset`.
4. **R06 — todayDow siempre con timezone**: `todayDowInTz(tz)` en lugar de `new Date().getDay()`.
5. **R07 — gym overlay nunca pisa sesion deportiva**: solo rellena slots donde `type === null` o `type === 'DESCANSO'`.
6. **R08 — DOW de GymSession se deriva de fecha real**: `new Date(gs.date).getUTCDay()`, NO del campo `gs.dayOfWeek`.
7. **R09 — [AUTO] en coachNote**: sesiones con `coachNotes` sin `[AUTO]` se saltan en ajustes automaticos.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| T03 — buildCalendarWeek usa weekNumber | Parece que filtra por rango de fechas | Usa weekNumber del plan. weekOffset=0 puede no coincidir con semana ISO. |
| T06 — actualDurationMin vs durationMin | Deberian ser el mismo campo | Mobile: `actualDurationMin`. Web: `durationMin`. Ambos mapean a `SessionLog.durationMin`. |
| T07 — sessionId vs plannedSessionId | Mismo nombre | Mobile: `sessionId`. Web: `plannedSessionId`. Ambos son el ID de PlannedSession. |
| T08 — energyState solo web | Deberia estar en ambos | PATCH mobile NO acepta `energyState`. Solo web PATCH lo tiene. |
| T11 — intensity vs zone | Mismo campo | DB: `zoneTarget`. Dominio: `zone`. Dashboard mapea explicitamente `zoneTarget -> zone`. |

---

## Paridad web vs mobile

| Funcionalidad | Web | Mobile | Diferencias |
|--------------|-----|--------|-------------|
| Editar sesion | `/athlete/sessions/[sessionId]` | `/mobile/sessions/[sessionId]` | Identico. Mobile con feature gate `plan` |
| Calendario | `/athlete/calendar` | `/mobile/calendar` | `buildCalendarWeek` compartida. Mobile con rate limit |
| Plan completo | NO EXISTE (SSR) | `/mobile/plan` | Solo mobile |
| Log sesion | `/athlete/log/session` | `/mobile/log/session` | T06, T07. Mobile anade wearable fields |
| Log run libre | `/athlete/log/run` | Incluido en `/mobile/log/session` | Web tiene endpoint separado |
| Editar log | `/athlete/log/session/[logId]` | `/mobile/log/session/[logId]` | Web tiene `energyState` (T08) |
| Borrar log | NO EXISTE | `/mobile/log/session/[logId]` DELETE | Solo mobile. Solo logs libres |
| Ultimo log | `/athlete/log/last-session` | `/mobile/log/last-session` | Identico |
| Historial | NO EXISTE | `/mobile/log/history` | Solo mobile. Feed mixto run+gym |

---

## Tests requeridos

### Calendar
- [ ] GET calendar: weekOffset fuera de rango retorna 400
- [ ] buildCalendarWeek: gym overlay no pisa sesion deportiva
- [ ] buildCalendarWeek: targetWeekNumber < 1 no carga PlannedSessions

### Logs
- [ ] POST log/session: completed=false retorna skipped
- [ ] POST log/session: plannedSessionId duplicado retorna alreadyLogged (idempotencia)
- [ ] POST log/session: P2002 concurrente retorna alreadyLogged (PERSIST-06)
- [ ] POST mobile log: externalId duplicado retorna alreadyLogged
- [ ] POST mobile log: sin sessionId ni sessionType retorna 400
- [ ] DELETE mobile log: log con plannedSessionId retorna 404
- [ ] PATCH mobile log: no acepta energyState

### Sessions
- [ ] PATCH sessions: ownership check — sesion de otro usuario retorna 404
- [ ] PATCH sessions: body sin campos validos retorna 400

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-08 | Web endpoints table: add Feature gate column, rate limits, week-print and routine endpoints |
| 2026-10-02 | Split desde plan.spec.md — sesiones, calendario, logs |
| 2026-09-29 | Spec original creada |
