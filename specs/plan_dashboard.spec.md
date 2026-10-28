# PLAN DASHBOARD — Mobile Dashboard, Week Sessions

<!-- mirror: false -->
<!-- note: dashboard web es SSR en page.tsx, no tiene API equivalente. week-sessions solo mobile. -->

> Split de plan.spec.md. Endpoints de dashboard mobile.
> Specs relacionadas: `plan_checkin.spec.md`, `plan_sessions.spec.md`, `dashboard.spec.md`
> Domain doc: `../domains/plan.md`

## TL;DR
- 2 endpoints (solo mobile)
- Modelos: TrainingPlan, PlanWeek, PlannedSession, SessionLog, GymSession
- Dependencias: getDashboardSummary(), getPlanWeekNumber(), overlayGymSessions(), todayDowInTz()
- Trampas criticas: T04 planIsExpired requiere ambas condiciones, T09 auto-complete ocurre al abrir dashboard, gym DOW de fecha real
- Mirror mobile: no hay mirror — dashboard web es SSR

---

## Contratos de la AI

- El auto-complete del plan ocurre en `GET /api/mobile/dashboard` (NO en un endpoint dedicado). Si `getDashboardSummary` devuelve `planIdToComplete`, el dashboard lo completa en el acto con `updateMany`.
- `planIsExpired = currentWeekNum > plan.totalWeeks && Date.now() > plan.endDate`. AMBAS condiciones deben cumplirse.
- `overlayGymSessions` solo rellena slots donde `type === null` o `type === 'DESCANSO'`. Nunca pisa sesion deportiva.
- DOW de `GymSession` se calcula de `new Date(gs.date).getUTCDay()`, NO del campo `gs.dayOfWeek`.
- `todayDow` siempre usa `todayDowInTz(tz)`, NUNCA `new Date().getDay()`.
- `week-sessions` tiene 4 casos: sin plan, sin plan + gym, con plan + planWeek existe, con plan + planWeek no existe.

---

## Endpoints

### Mobile

| Method | Path | Rate limit | Descripcion |
|--------|------|-----------|-------------|
| GET | `/api/mobile/dashboard` | 300/min | Dashboard completo del atleta |
| GET | `/api/mobile/dashboard/week-sessions` | 300/min | Sesiones de la semana para CalendarStrip |

---

## Detalle de endpoints

### GET `/api/mobile/dashboard`

**Query params**: `tz` (IANA timezone, opcional)

**Flujo de carga (PERF-01)**:
1. Fase 1 (paralelo): `fetchCoreDashboardData(userId, tz)` + `trainingPlan.findFirst` (solo metadata, sin sesiones)
2. `currentWeekNum = getPlanWeekNumber(plan.startDate, plan.totalWeeks)`
3. `planIsExpired = currentWeekNum > plan.totalWeeks && Date.now() > plan.endDate`
4. Fase 2: `planWeek.findFirst({ where: { planId, weekNumber: currentWeekNum }, include: sessions+logs })` solo si plan no expirado
5. Auto-completar plan si `planIdToComplete` (del use case)
6. Gap-fix: buscar plan completado en los ultimos 7 dias para mostrar `justCompletedPlan`

**Mapeo pre-use-case**: las sesiones del plan activo se mapean `zoneTarget->zone`, `detailText->description`, `coachNote->coachNotes` antes de pasar a `getDashboardSummary`.

**Auto-completar plan**: si `planIdToComplete` -> `trainingPlan.updateMany({ status: 'COMPLETED' })`.

**`justCompletedPlan`** contiene: `name`, `totalWeeks`, `totalSessions`, `totalKm`, `seasonNumber`, `adherencePct`.

**Response 200**: spread de `summary` + campos adicionales:
```json
{
  "weeklyRoutine": { "daysPerWeek": "number", "days": "any[]" },
  "todayLog": "SessionLog | null",
  "hasEverLogged": "boolean",
  "coach": { "name": "string", "headline": "string | null", "initial": "string" },
  "isB2B": "boolean",
  "workoutName": "string | null",
  "justCompletedPlan": { "name": "string", "totalWeeks": "number", "totalSessions": "number", "totalKm": "number | null", "seasonNumber": "number", "adherencePct": "number | null" },
  "pendingSuggestionsCount": "number",
  "todayFoodTotals": { "kcal": "number", "proteinG": "number", "carbsG": "number", "fatG": "number" },
  "waterData": "any",
  "mealSlotLogs": "any",
  "checkInData": { "energyLevel": "number | null", "sleepHours": "number | null", "stressLevel": "number | null", "motivationLevel": "number | null", "recordedAt": "string" },
  "hrZones": "HRZones | null"
}
```

### GET `/api/mobile/dashboard/week-sessions`

**Query params**: `weekOffset` (int, default 0), `tz` (IANA, opcional)

**Caso A — sin plan activo + sin gym**:
- Carga `SessionLog` libres de la semana -> marca slots completados
- `weekSessions[idx].type = log.freeSessionType ?? log.plannedSession?.type ?? 'OTRO'`

**Caso B — sin plan activo + tiene gym**:
- `overlayGymSessions` rellena slots con gym

**Caso C — con plan activo, PlanWeek existe**:
- Carga sesiones de `planWeek` (sin DESCANSO) -> rellena slots
- `overlayGymSessions` rellena slots vacios con gym

**Caso D — con plan activo, PlanWeek no existe para esa semana**:
- Carga `SessionLog` libres sin `plannedSessionId` -> rellena slots
- `overlayGymSessions` despues

**`overlayGymSessions`**:
- Solo rellena slots que no tienen sesion (`type = null` o `type = 'DESCANSO'`)
- DOW de GymSession se deriva de `UTCDay` de la fecha real (NO del campo `dayOfWeek` del modelo)

**`todayDow`**: `todayDowInTz(tz)` — NUNCA `new Date().getDay()`.

**Response 200**:
```json
{
  "weekSessions": [{
    "dayIndex": "number (0=Mon..6=Sun)",
    "type": "string | null",
    "done": "boolean",
    "isToday": "boolean",
    "id": "string | null",
    "durationMin": "number | null",
    "zoneTarget": "string | null",
    "gymLabel": "string | null"
  }],
  "completedCount": "number",
  "totalTraining": "number",
  "weekLabel": "string | null",
  "weekOffset": "number",
  "isCurrentWeek": "boolean"
}
```

---

## Modelos DB

Referencia: ver `plan_sessions.spec.md` para modelos completos de TrainingPlan, PlannedSession, SessionLog.

---

## Reglas de negocio

1. **R07 — gym overlay nunca pisa sesion deportiva**: `overlayGymSessions` solo rellena slots donde `type === null` o `type === 'DESCANSO'`.
2. **R08 — DOW de GymSession de fecha real**: `new Date(gs.date).getUTCDay()`, NO del campo `gs.dayOfWeek`.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| T04 — planIsExpired | Basta con que pase la ultima semana | Requiere AMBAS: `currentWeekNum > totalWeeks` Y `Date.now() > endDate`. Un plan puede estar en semana 13/12 pero endDate no paso. |
| T09 — auto-complete en dashboard | El plan se completa explicitamente | Se completa al abrir el dashboard si `planIdToComplete` esta presente. Sin accion explicita del atleta. |
| T01 — todayInTz vs todayDowInTz | Son intercambiables | `todayInTz(tz)` -> Date UTC-midnight. `todayDowInTz(tz)` -> numero 1-7. Usar `new Date().getDay()` en Vercel (UTC) es INCORRECTO para LatAm. |

---

## Tests requeridos

### Dashboard
- [ ] GET dashboard: auto-complete plan si planIdToComplete presente
- [ ] GET dashboard: justCompletedPlan se muestra si plan completado en ultimos 7 dias
- [ ] GET dashboard: planIsExpired requiere ambas condiciones

### Week Sessions
- [ ] Caso A: sin plan + sin gym -> slots de SessionLog libres
- [ ] Caso B: sin plan + con gym -> overlayGymSessions rellena
- [ ] Caso C: con plan + planWeek existe -> sesiones del plan + gym overlay
- [ ] Caso D: con plan + planWeek no existe -> SessionLog libres + gym overlay
- [ ] overlayGymSessions: nunca pisa slot con sesion deportiva

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-02 | Split desde plan.spec.md — dashboard mobile y week-sessions |
| 2026-09-29 | Spec original creada |
