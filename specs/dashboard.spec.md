# DASHBOARD — Dashboard del Atleta (Web + Mobile)

<!-- mirror: true -->
<!-- mirror-endpoints: web SSR (get_dashboard_data.ts) ↔ GET /api/mobile/dashboard, GET /api/mobile/dashboard/week-sessions -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Fuente canonica: esta spec refleja el comportamiento ACTUAL del codigo, no el deseado.
> Archivos principales:
> - `src/domain/dashboard/get_dashboard_summary.use_case.ts` — logica pura, sin DB
> - `src/infrastructure/db/dashboard_queries.ts` — queries compartidas web + mobile
> - `src/infrastructure/db/shared_athlete_data.ts` — handlePlanLifecycle + helpers
> - `src/app/(athlete)/dashboard/_lib/get_dashboard_data.ts` — orquestador web (RSC)
> - `src/app/api/mobile/dashboard/route.ts` — endpoint mobile
> - `src/app/api/mobile/dashboard/week-sessions/route.ts` — calendario semanal mobile

## TL;DR
- 2 endpoints mobile + 1 orquestador web (RSC)
- Modelos: TrainingPlan, PlanWeek, PlannedSession, SessionLog, GymSession, NutritionPlan
- Dependencias: getDashboardSummary() (use case puro), fetchCoreDashboardData(), handlePlanLifecycle(), overlayGymSessions()
- Trampas criticas: planIsExpired requiere 2 condiciones, auto-complete plan al abrir dashboard, gym overlay no pisa sesion deportiva, todayDow siempre con timezone
- Mirror mobile: dashboard (web=SSR, mobile=API), week-sessions (solo mobile)

---

## Contratos de la AI

- [ ] El use case `getDashboardSummary` es puro (sin DB). Nunca agregar accesos a Prisma dentro de el.
- [ ] `handlePlanLifecycle` tiene side effects fire-and-forget (updateMany/update en Prisma). Los errores se silencian con `.catch()`. Esto es intencional — no "arreglar" eso.
- [ ] Web usa `handlePlanLifecycle` para detectar expiracion. Mobile tiene su propia logica de expiracion en la route directamente (no llama handlePlanLifecycle). Son independientes, NO unificar sin analizar ambos.
- [ ] El campo DB se llama `zoneTarget` y `detailText` y `coachNote`. El dominio los expone como `zone`, `description`, `coachNotes`. El mapeo se hace en la route/orquestador ANTES de pasar al use case. Cambiar estos nombres rompe la mobile app (hay contract tests que lo verifican).
- [ ] `overlayGymSessions` (T15) solo agrega slots FUERZA a dias que NO tienen ya una sesion de deporte (type != null && type != 'DESCANSO'). Un dia DESCANSO del plan SI puede ser sobreescrito por gym.
- [ ] `planIdToComplete` en el resultado del use case es una senal: la route DEBE marcar ese plan COMPLETED en DB. El use case no puede hacerlo (es puro). Si la route no actua, el plan queda activo para siempre.
- [ ] La web pre-fetches `initialCalendarWeek`, `initialWater`, `initialMealSlotLogs` en el RSC para evitar flash de zeros en el cliente. Mobile no pre-fetcha estos — el cliente los pide aparte.
- [ ] `weekSessionCount` en modo FREE/GYM cuenta dias unicos con actividad (no numero de logs). Un dia con 2 SessionLogs cuenta como 1.
- [ ] `checkinPending` compara `lastCheckIn.weekNumber` con el weekNumber actual del plan. Sin plan activo usa `getCurrentISOWeek()`.
- [ ] El streak usa fechas UTC (`.toISOString().split('T')[0]`). Si el atleta entrena a las 10pm Colombia (UTC-5), su log cae en el dia UTC siguiente. Esto puede causar que el streak muestre 0 cuando visualmente "entreno hoy". Es una limitacion conocida.
- [ ] `formStatus='rest'` se fuerza en modo RECOVERY independientemente del check-in. Siempre.
- [ ] `formStatus` ignora check-ins con mas de 7 dias (`CHECKIN_EXPIRY_DAYS = 7`) y devuelve `good` con mensaje "Haz tu check-in semanal".
- [ ] Mobile Dashboard hace su propia deteccion de `justCompletedPlan` + un "gap fix" que busca planes completados en los ultimos 7 dias. Esto es para el modal de season completion. La web no tiene este modal.

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/mobile/dashboard` | `getMobileUser()` | 300/min | Dashboard completo del atleta (mobile) |
| GET | `/api/mobile/dashboard/week-sessions` | `getMobileUser()` | 300/min | Slots semanales con gym overlay (mobile) |

La web usa RSC — no tiene endpoint HTTP propio. `getDashboardData()` se llama directamente desde `page.tsx`.

---

### `GET /api/mobile/dashboard`

**Query params:**
```ts
{ tz?: string }  // IANA timezone, ej: "America/Bogota"
```

**Response:**
```ts
{
  // Del use case getDashboardSummary
  firstName: string
  todaySession: {
    id: string
    logId: string | null
    type: string
    intensity: string | null
    durationMin: number | null
    zoneTarget: string       // nombre en JSON — origen: PlannedSession.zoneTarget
    detailText: string       // nombre en JSON — origen: PlannedSession.detailText
    completed: boolean
  } | null
  planData: {
    name: string
    currentWeek: number
    totalWeeks: number
    phase: string
  } | null
  metrics: {
    weightKg: number | null
    weightGoalKg: number | null
    hrResting: number | null
    sleepHours: number | null
  }
  weekSessions: WeekSessionSlot[]   // 7 slots, dayIndex 0=Lun..6=Dom
  nutritionTarget: {
    kcal: number
    proteinG: number
    carbsG: number
    fatG: number
    label: string
  } | null
  completedCount: number
  totalTraining: number
  checkinPending: boolean
  streakDays: number
  weekStreak: number
  raceDays: number | null
  isRecomp: boolean
  formStatus: 'good' | 'moderate' | 'rest'
  formMessage: string
  lastCheckIn: { energyLevel: number | null; hardestSessionRpe: number | null; sleepHours: number | null } | null
  lastCheckinDaysAgo: number | null
  weeklyWeightChange: number | null
  weightProgressPct: number | null
  currentVolume: number | null
  volumeDeltaPct: number | null
  mode: 'TRAINING' | 'RECOVERY' | 'FREE' | 'GYM'
  recoveryDaysLeft: number | null
  completedPlanName: string | null
  recentActivity: { type: string; completedAt: string; durationMin: number | null; rpe: number | null }[]
  hasEverLogged: boolean

  // Adicionales de la route (no del use case)
  weeklyRoutine: { daysPerWeek: number; days: unknown } | null
  todayLog: { weightKg: number | null; energyLevel: number | null } | null
  hasEverLogged: boolean
  coach: { name: string; headline: string | null; initial: string } | null
  isB2B: boolean
  workoutName: string | null
  justCompletedPlan: {
    name: string
    totalWeeks: number
    totalSessions: number
    totalKm: number | null
    seasonNumber: number
    adherencePct: number | null
  } | null
  pendingSuggestionsCount: number
  todayFoodTotals: { kcal: number; proteinG: number; carbsG: number; fatG: number }
  waterData: { mlLogged: number; waterMlTarget: number }
  mealSlotLogs: { mealType: string; kcal: number }[]
  checkInData: {
    energyLevel: number | null
    sleepHours: number | null
    stressLevel: number | null
    motivationLevel: number | null
    recordedAt: string
  } | null
  hrZones: {
    z1: { min: number; max: number }
    z2: { min: number; max: number }
    z3: { min: number; max: number }
    z4: { min: number; max: number }
    z5: { min: number; max: number }
  } | null
}
```

**Logica (mobile route):**
1. Auth `getMobileUser(req)` — 401 si falla.
2. Rate limit `mobile-{id}:dashboard` 300/min — 429 si excede.
3. `fetchCoreDashboardData(userId, tz)` — 11 queries en paralelo (ver seccion DB).
4. `prisma.trainingPlan.findFirst` con `status: ACTIVE` para metadata del plan (sin sesiones — PERF-01 Phase 1).
5. Calcular `currentWeekNum` con `getPlanWeekNumber`. Si `rawWeek > totalWeeks && now > endDate` → el plan esta vencido (`planIsExpired = true`).
6. Si plan no vencido: cargar solo `PlanWeek` de la semana actual con sesiones completas (PERF-01 Phase 2).
7. Mapear nombres DB→dominio: `zoneTarget→zone`, `detailText→description`, `coachNote→coachNotes`.
8. `buildDashboardSummaryInput` + `getDashboardSummary` — obtener summary y `planIdToComplete`.
9. Si `planIdToComplete` no null: calcular stats del plan completado y marcar `COMPLETED` en DB (fire-and-forget con .catch).
10. "Gap fix": si no hay `justCompletedPlan` de este request, buscar planes completados en los ultimos 7 dias para el modal.
11. Serializar respuesta con `computeFoodTotals`, `buildWaterData`, `computeMealSlotLogs`.
12. HR Zones calculadas con `calculateHRZones(hrMax, hrResting)` — null si no hay `hrMax` en perfil.

---

### `GET /api/mobile/dashboard/week-sessions`

**Query params:**
```ts
{
  weekOffset?: string  // entero, default "0" (semana actual)
  tz?: string          // IANA timezone
}
```

**Response:**
```ts
{
  weekSessions: {
    dayIndex: number       // 0=Lun..6=Dom
    type: string | null    // tipo de sesion o 'FUERZA' si es gym
    done: boolean
    isToday: boolean
    id: string | null      // PlannedSession.id o null si es gym/libre
    durationMin: number | null
    zoneTarget: string | null
    gymLabel: string | null
  }[]
  completedCount: number
  totalTraining: number
  weekLabel: string | null  // ej: "14-20 oct" o "28 oct - 3 nov"
  weekOffset: number
  isCurrentWeek: boolean
}
```

**Logica:**
1. Auth + rate limit (300/min, key `week-sessions`).
2. Buscar plan activo para el usuario (`status: 'ACTIVE'`).
3. **Sin plan activo:**
   a. Crear 7 slots vacios.
   b. Intentar `overlayGymSessions` (T15).
   c. Si se agrego gym (addedTraining > 0): devolver con los slots de gym.
   d. Si no hay gym: buscar `SessionLog` libres de la semana (B2C Free). `completedCount = totalTraining = freeTotal`.
4. **Con plan activo:**
   a. Calcular `selectedWeekNum = currentWeek + weekOffset`.
   b. Cargar `PlanWeek` con sesiones (excluye `DESCANSO` en where).
   c. Si no existe `PlanWeek` para esa semana: fallback a `SessionLog` libres sin `plannedSessionId`.
   d. Siempre aplicar `overlayGymSessions` al final para agregar FUERZA en slots vacios.

---

## Modelos DB involucrados

```prisma
// Queries en fetchCoreDashboardData (11 paralelas)
User              { profile, checkIns (last 12, desc) }
SessionLog        { last 60, desc — id, completedAt, freeSessionType, durationMin, rpe, plannedSession.type }
NutritionPlan     { targetKcalHard, targetKcalEasy, targetKcalRest, proteinG, carbsHardG, carbsEasyG, fatG, waterMlTarget }
AssignedWorkout   { isActive: true — template.days (include exercises) }
WeeklyRoutine     { daysPerWeek, days }
GymSession        { completed: true, last 60, desc — id, date, durationMin, energyState, assignedWorkout.template.name }
CoachAthlete      { athleteId, status: ACTIVE — coach.name, coachProfile.{slug,specialties,headline} }
CheckInSuggestion { status: PENDING, expiresAt > now — COUNT }
DailyLog          { userId_date composite — weightKg, energyLevel }
FoodLog           { userId, date=today — grams, mealType, kcalLogged, proteinLogged, carbsLogged, fatLogged, food macros }
WaterLog          { userId_date composite — mlLogged }

// Solo en mobile route (no en fetchCore)
TrainingPlan      { userId, status: ACTIVE — id, name, startDate, endDate, totalWeeks }
PlanWeek          { planId, weekNumber — startDate, endDate, sessions (excl DESCANSO) }

// Solo en web get_dashboard_data (no en fetchCore)
TrainingPlan      { userId, status: ACTIVE — include weeks.sessions (id, type, dayOfWeek, log.id) }
PlannedSession    { week.planId + weekNumber — full include con log }
```

---

## Reglas de negocio (invariantes)

1. **DashboardMode**: la prioridad es `TRAINING > GYM > RECOVERY > FREE`.
   - `TRAINING`: hay plan activo no vencido.
   - `GYM`: no hay plan, pero hay `AssignedWorkout` activo.
   - `RECOVERY`: no hay plan ni gym, pero el ultimo plan termino hace 14 dias o menos.
   - `FREE`: ninguno de los anteriores.

2. **Plan expiration**: un plan ACTIVE se considera vencido cuando `rawWeek > totalWeeks && now > endDate`. "rawWeek" se calcula como `floor((now - startDate) / 7 dias) + 1`. El plan NO se marca ACTIVE→COMPLETED al crearse, sino la proxima vez que el atleta abre el dashboard.

3. **overlayGymSessions (T15)**: solo llena slots vacios o slots con `type === 'DESCANSO'`. Un slot con cualquier otro tipo de deporte NO se sobreescribe con gym. Regla: running y gym pueden coexistir en la semana, pero no en el mismo dia.

4. **Streak calculo**: recorre hacia atras desde hoy (UTC), dia a dia, hasta encontrar un dia sin actividad. Maximo 60 dias hacia atras. Incluye tanto `SessionLog.completedAt` como `GymSession.date` de sesiones completadas.

5. **weekSessionCount (FREE/GYM mode)**: cuenta dias unicos con actividad, no cantidad de sesiones. Se construye con `Set<string>` de `toLocaleDateString('en-CA', { timeZone })` (timezone-aware, no `toDateString()` que usa UTC). Solo aplica para el modo FREE/GYM/RECOVERY — en TRAINING se usan `completedCount` y `totalTraining` del plan.

6. **nutritionTarget**: ajustado por intensidad de la sesion de hoy. `HIGH → targetKcalHard`, `MODERATE → targetKcalEasy`, `LOW/null → targetKcalRest`. La intensidad viene del campo `PlannedSession.intensity` o se infiere con `getSessionIntensity(type)`.

7. **checkinPending**: `true` si no hay check-in cuyo `weekNumber` sea igual al `currentWeekNum` del plan activo. Sin plan, usa `getCurrentISOWeek()` (semana ISO del calendario).

8. **weightProgressPct**: mide cuanto de la brecha inicial→meta se ha cerrado. `pct = (totalDistance - remaining) / totalDistance`. Funciona tanto para bajar (70→60kg) como para subir (78→83kg). Clamped a [0, 100].

9. **weeklyWeightChange**: normalizado a 7 dias. `(lastCheckIn.weightKg - prevCheckIn.weightKg) / daysDiff * 7`. Requiere al menos 2 check-ins con peso.

10. **recentActivity**: merge de `SessionLog` + `GymSession` completadas, ordenadas por fecha desc, limitadas a 5. GymSession siempre aparece como `type: 'FUERZA'`.

11. **handlePlanLifecycle (T09)**: si hay multiples planes ACTIVE para un usuario (no deberia ocurrir pero puede), `selectActivePlan` elige el ganador (el mas reciente) y marca los demas COMPLETED con `updateMany` fire-and-forget. Adicionalmente detecta si el ganador esta vencido y lo marca COMPLETED. Devuelve `{ activePlan, expiredSnapshot }`.

12. **todayFoodTotals en mobile**: `proteinG`, `carbsG`, `fatG` se redondean a 1 decimal. `kcal` se redondea a entero.

13. **hrZones**: calculadas con `calculateHRZones(hrMax, hrResting)` (formula Karvonen). Se omiten del response si el perfil no tiene `hrMax`.

14. **B2C Free en week-sessions**: cuando no hay plan ni gym, los `SessionLog` libres de la semana se muestran con `completedCount = totalTraining = freeTotal`. Todos los slots marcados como `done: true`.

15. **weekLabel formato**: mismo mes → `"14-20 oct"` (con en-dash U+2013). Meses distintos → `"28 oct - 3 nov"`. Calculado en `formatWeekLabel` usando `MONTHS` array en español.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `zone` vs `zoneTarget` | El dominio usa `zone`, la DB usa `zoneTarget` | El mapeo se hace en la route/orquestador antes de llamar al use case. `todaySession.zoneTarget` en el JSON es el nombre que ve la mobile app — viene del campo `zone` del dominio que a su vez viene de `PlannedSession.zoneTarget` en DB |
| `description` vs `detailText` | El dominio usa `description`, la DB usa `detailText` | Mismo patron: `s.description` en el use case → serializado como `detailText` en JSON mobile. Hay contract tests que verifican estos nombres exactos |
| `handlePlanLifecycle` en web vs mobile | Parece que ambos usan el mismo mecanismo | Web llama `handlePlanLifecycle` de `shared_athlete_data.ts`. Mobile tiene su propia logica inline de `planIsExpired` en la route. No son identicos — mobile no hace dedup de planes duplicados |
| `planIdToComplete` del use case | Parece que el use case completa el plan | El use case es puro — solo senala `planIdToComplete`. La mobile route es quien llama `prisma.trainingPlan.updateMany` si es non-null. La web NO hace esto — usa `handlePlanLifecycle` que lo maneja en su propia ruta |
| `weekSessionCount` vs `completedCount` | Ambos cuentan sesiones de la semana | `completedCount` cuenta sesiones del plan completadas (TRAINING mode). `weekSessionCount` cuenta dias unicos con actividad libre o gym (FREE/GYM/RECOVERY mode). Se usan en contextos diferentes |
| `overlayGymSessions` en week-sessions vs use case | Parecen identicas | La funcion en `week-sessions/route.ts` deriva el DOW de la fecha real de la `GymSession` (usando `getUTCDay()`). El use case en `get_dashboard_summary` usa un `Set` de indices calculado de forma diferente. Pueden divergir si las fechas no son exactamente de la semana actual |
| `todayFoodTotals` null vs `{kcal:0,...}` | Mobile siempre devuelve totales | `computeFoodTotals` devuelve `null` si `foodLogs.length === 0`. La route hace `?? { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 }` para evitar null. Web no hace este fallback — pasa `null` directamente a los componentes |
| `activeDays` con `toDateString()` | Parece que da la fecha local | `toDateString()` usa timezone del server (UTC en Vercel). Usar `toLocaleDateString('en-CA', { timeZone })` para la fecha real del atleta. Ver T17 en `_traps.spec.md` |
| `DesktopRecentActivity` sin timezone | Las fechas se muestran en UTC | Componente recibe prop `timezone` para mostrar fechas en la zona del atleta |
| `MobileCardsSection` sin isB2B | No distingue B2B de B2C | Componente recibe prop `isB2B` para mostrar/ocultar cards segun tipo de atleta |
| `weekOffset` en TRAINING mode (web) | El offset es relativo a hoy | En `get_dashboard_data.ts`, `weekOffset` se clampea a `[-52, 0]` en dashboard, `[-52, 52]` en gym. No puedes ir mas atras de 52 semanas ni mas adelante en gym. |
| `isToday` en week-sessions | Se calcula correctamente siempre | Solo es `true` cuando `weekOffset === 0 && i + 1 === todayDow`. Si el usuario navega a una semana pasada/futura, ningun slot es `isToday` |
| `justCompletedPlan.seasonNumber` | Cuenta cuantos planes ha completado el atleta | Si `isNewCompletion=true` (el plan se acaba de completar en este request), suma 1 al conteo actual porque el UPDATE es fire-and-forget y el COUNT puede no verlo todavia |

---

## Paridad web <-> mobile

| Aspecto | Web (RSC) | Mobile (REST) | Divergencia |
|---------|-----------|---------------|-------------|
| Auth | `auth()` Auth.js | `getMobileUser()` JWT jose | Diferente mecanismo, mismo `userId` |
| Plan lifecycle | `handlePlanLifecycle()` — dedup + expiracion | Logica inline `planIsExpired` — solo expiracion, sin dedup | Mobile NO elimina planes duplicados |
| Datos del plan | Carga TODOS los PlanWeeks con sesiones (PERF: puede ser grande) | PERF-01: carga solo metadata del plan, luego solo la semana actual con sesiones | Mobile es mas eficiente en carga |
| justCompletedPlan | No existe (sin modal de season completion en web) | Si — stats del plan + season number para modal | Solo mobile tiene este flujo |
| initialCalendarWeek | Pre-fetched en RSC via `buildCalendarWeek` | No — mobile hace fetch separado a `/week-sessions` | Web evita flash de carga |
| initialWater / initialMealSlotLogs | Pre-fetched en RSC | No — mobile los recibe inline en la misma respuesta | Mobile los incluye directamente en el JSON |
| weekOffset | Clampea a `max(1-currentWeek, rawOffset)` | No clampea — acepta cualquier offset | Mobile puede ir a semanas antes del inicio del plan |
| hrZones | No esta en la response web (calculado client-side si aplica) | Si — incluido en la response como `hrZones` | Solo mobile recibe hrZones precalculadas |
| workoutName | `d.assignedWorkout?.template.name` disponible en data | `workoutName: assignedWorkoutRaw?.template.name` en response | Misma info, distinta forma de exponer |

---

## Flujo de datos (arquitectura)

```
Web RSC (getDashboardData):
  fetchCoreDashboardData (11 queries paralelas)
  + prisma.trainingPlan (ACTIVE, all weeks)
  + buildCalendarWeek
      ↓
  handlePlanLifecycle (dedup + expiracion, side effects fire-and-forget)
      ↓
  buildDashboardSummaryInput (mapeo DB → dominio)
      ↓
  getDashboardSummary (pure — logica de negocio)
      → DashboardSummary + planIdToComplete (ignorado en web)
      ↓
  Serializar DashboardData → props de los componentes React

Mobile Route (GET /api/mobile/dashboard):
  fetchCoreDashboardData (11 queries paralelas)
  + prisma.trainingPlan (solo metadata, PERF-01 Phase 1)
      ↓
  PlanWeek de semana actual (PERF-01 Phase 2, solo si plan no vencido)
      ↓
  Mapear zoneTarget→zone, detailText→description, coachNote→coachNotes
      ↓
  buildDashboardSummaryInput + getDashboardSummary
      → planIdToComplete: si non-null → buildJustCompletedPlan + updateMany (fire-and-forget)
      ↓
  "Gap fix": buscar planes completados en los ultimos 7 dias
      ↓
  Serializar JSON response
```

---

## Tests requeridos

Los tests existentes estan en `src/domain/dashboard/get_dashboard_summary.test.ts`.
Correr: `pnpm test src/domain/dashboard/get_dashboard_summary.test.ts`

**Cubiertos por tests existentes:**
- [x] `mode` — FREE, TRAINING, RECOVERY, GYM, planIdToComplete cuando vence
- [x] `recentActivity` — merge SessionLog + GymSession, limit 5, ordenado desc, fallbacks de tipo
- [x] `hasEverLogged` — false/true con logs y gym sessions
- [x] `firstName` — extraccion + fallback a "Atleta"
- [x] `todaySession` — null sin plan, null con DESCANSO, sesion activa, completed flag, gym fallback
- [x] `weekSessions` — 7 slots, mapeo dayOfWeek→dayIndex, done, isToday
- [x] `completedCount` y `totalTraining` — excluye DESCANSO
- [x] `planData` — null sin plan, campos correctos con plan
- [x] `nutritionTarget` — null sin nutritionPlan, ajuste por intensidad (HIGH/REST)
- [x] `formStatus` — good/moderate/rest segun check-in, spike de volumen, RECOVERY forzado
- [x] `checkinPending` — sin check-ins, semana correcta, semana anterior
- [x] `weeklyWeightChange` — normalizacion a 7 dias
- [x] `weightProgressPct` — bajar/subir de peso, 0%/100%, bidireccional
- [x] `streakDays` — 0, 1, 2, racha rota
- [x] `metrics` — profile vs check-in (check-in gana), nulls
- [x] `isRecomp` y `raceDays` — por sportGoal y sportDetails.raceDate
- [x] CONTRACT — nombres de campos del JSON que consume la mobile app (`zoneTarget`, `detailText`)

**Tests pendientes (no existen aun):**
- [ ] `handlePlanLifecycle` — dedup de planes duplicados, plan expirado, plan vigente
- [ ] `overlayGymSessions` — slot vacio recibe FUERZA, slot con sesion existente NO se sobreescribe, slot DESCANSO SI se sobreescribe
- [ ] `computeFoodTotals` — sum de macros, null cuando no hay logs, fallback a food.macrosPer100g
- [ ] `computeMealSlotLogs` — agrupacion por mealType, SNACK como fallback
- [ ] `buildWaterData` — waterMlTarget default 2000 si no hay nutritionPlan
- [ ] `week-sessions route` — sin plan + sin gym devuelve SessionLogs libres, con plan devuelve PlannedSessions + gym overlay
- [ ] `getDashboardSummary` con `assignedWorkout` — weekSessions contiene slots FUERZA en dias gym, totalTraining incluye gym

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo real |
| 2026-10-09 | Auditoria pre-prod: weekOffset clamped [-52,0]/[-52,52], activeDays timezone-aware (toLocaleDateString no toDateString), DesktopRecentActivity+MobileCardsSection timezone prop, isB2B prop en MobileCardsSection | 8 rondas de auditoria |
