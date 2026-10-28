# PLAN CHECK-IN — Check-In Semanal, Sugerencias, processCheckIn

<!-- mirror: true -->
<!-- mirror-endpoints: GET/POST /api/athlete/checkin ↔ GET/POST /api/mobile/checkin, POST /api/athlete/checkin/suggestions/[id]/{accept,reject} ↔ POST /api/mobile/checkin/suggestions/[id]/{accept,reject} -->

> Split de plan.spec.md. Check-in semanal y sugerencias.
> Specs relacionadas: `plan_sessions.spec.md`, `plan_dashboard.spec.md`
> Domain doc: `../domains/plan.md`

## TL;DR
- 9 endpoints (4 web, 5 mobile incl checkin-status)
- Modelos: WeeklyCheckIn, CheckInSuggestion
- Dependencias: processCheckIn use case, evaluateCheckInRules(), buildSessionAdjustments(), syncWeight()
- Trampas criticas: T05 naming asimetrico RPE (hardestRpe/muscleSoreness/rpe/hardestSessionRpe), nutritionAdherencePct 0-100 -> /10
- Mirror mobile: schemas diferentes (T05), respuesta mobile sin planChanges/nutritionChanges, checkin-status solo mobile

---

## Contratos de la AI

- `hardestRpe` (web) y `muscleSoreness` (mobile) son el MISMO dato. Se mapean a `rpe` en dominio y `hardestSessionRpe` en DB. Nunca enviar `hardestRpe` desde mobile ni `muscleSoreness` desde web.
- Mobile `energyLevel` y `muscleSoreness` son OBLIGATORIOS. Web tiene ambos opcionales pero requiere al menos uno.
- `nutritionAdherencePct` entra como 0-100, el mapper divide `/10` para escala de dominio 1-10.
- `plan.source === 'COACH'` genera `CheckInSuggestion` (el coach decide). `plan.source === 'SYSTEM'` auto-aplica ajustes. **Nota**: El enum `PlanSource` en DB solo tiene `COACH`. El valor `SYSTEM` no existe — este path nunca se ejecuta. Regla reservada para futura implementacion.
- Sugerencias expiran en 7 dias desde creacion.
- El primer check-in (`count(userId) === 1`) habilita feature `'progress'`.

---

## Endpoints

### Web

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/athlete/checkin` | 300/min | ninguna | Ultimo check-in + sugerencias pendientes |
| POST | `/api/athlete/checkin` | 30/min | featureCheckin (session) | Registrar check-in semanal |
| POST | `/api/athlete/checkin/suggestions/[id]/accept` | 60/min | ninguna | Aceptar sugerencia y aplicar ajustes |
| POST | `/api/athlete/checkin/suggestions/[id]/reject` | 60/min | ninguna | Rechazar sugerencia |

### Mobile

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/mobile/checkin` | 300/min | ninguna | Estado check-in semana actual + datos previos |
| POST | `/api/mobile/checkin` | 100/min | `checkin` | Registrar check-in semanal |
| GET | `/api/mobile/checkin-status` | 300/min | `checkin` (locked=true si no tiene) | Verificar si check-in pendiente |
| POST | `/api/mobile/checkin/suggestions/[id]/accept` | 60/min | ninguna | Aceptar sugerencia |
| POST | `/api/mobile/checkin/suggestions/[id]/reject` | 60/min | ninguna | Rechazar sugerencia |

---

## Detalle de endpoints

### GET `/api/athlete/checkin`

**Queries Prisma**:
- `weeklyCheckIn.findFirst({ where: { userId }, orderBy: { recordedAt: 'desc' } })`
- `checkInSuggestion.findMany({ where: { userId, status: 'PENDING', expiresAt: { gt: now } }, orderBy: { createdAt: 'desc' } })`

**Response 200**:
```json
{
  "weightKg": "number | null",
  "hrResting": "number | null",
  "sleepHours": "number | null",
  "energyLevel": "number | null",
  "hardestSessionRpe": "number | null",
  "sleepScore": "number | null",
  "stressLevel": "number | null",
  "motivationLevel": "number | null",
  "nutritionAdherencePct": "number | null",
  "pendingSuggestions": [{ "id": "string", "type": "string", "title": "string", "description": "string", "expiresAt": "string" }]
}
```

### POST `/api/athlete/checkin`

**Zod schema** (`checkInBodySchema`):
```ts
hardestRpe?:            number  min(1) max(10)     // -> rpe en dominio -> hardestSessionRpe en DB
sleepHours?:            number  min(0) max(24)
sleepScore?:            number  min(0) max(10)
energyLevel?:           number  min(1) max(10)
stressLevel?:           number  min(0) max(10)
weightKg?:              number  min(10) max(500)
hrResting?:             number  min(0) max(250)
painLevel?:             number  min(0) max(10)
nutritionAdherencePct?: number  min(0) max(100)    // 0-100, se convierte /10 en mapper
motivationLevel?:       number  min(0) max(10)
notes?:                 string  max(5000)
painDescription?:       string  max(500)
waistCm?:               number  min(40) max(200)
armsCm?:                number  min(10) max(100)
hipsCm?:                number  min(40) max(200)
thighsCm?:              number  min(20) max(120)
```

**Validacion de negocio**: requiere al menos `energyLevel` o `hardestRpe` — 400 si ambos son `null`.

**Flujo**: `mapWebCheckinBody(body)` -> `processCheckIn(...)` -> side effects fire-and-forget.

**Side effects (fire-and-forget)**:
- `sendPlanUpdatedEmail` si `result.adjustments.length > 0`
- `createNotification('PLAN_ACTUALIZADO')` si `result.sessionsAdjusted > 0`
- `sendCoachCheckInEmail` si atleta tiene `CoachAthlete.status = 'ACTIVE'`

**Response 200**:
```json
{
  "ok": true,
  "adjustment": {
    "severity": "ok | warning | critical",
    "recommendation": "string",
    "adjustments": ["string"],
    "triggers": ["string"],
    "planChanges": { "volumeDeltaPct": "number", "zonesAdjusted": "boolean" },
    "nutritionChanges": { "newKcalHard": "number", "newKcalEasy": "number" }
  },
  "pendingSuggestions": "number",
  "suggestions": [{ "id": "string", "type": "string", "title": "string", "description": "string", "expiresAt": "string" }]
}
```

### GET `/api/mobile/checkin`

**Logica de semana**: si hay plan activo -> `getPlanWeekNumber(plan.startDate, plan.totalWeeks)`, si no -> `getCurrentISOWeek()`.

**Queries Prisma** (en paralelo):
- `trainingPlan.findFirst({ where: { userId, status: 'ACTIVE' } })` con sesiones de todas las semanas
- `weeklyCheckIn.findFirst({ where: { userId, weekNumber } })`
- `checkInSuggestion.findMany(...)` pendientes
- `healthProfile.findUnique({ where: { userId }, select: { weightKg, hrResting } })`

**`weekSessions`**: sesiones de la semana actual del plan filtradas `type !== 'DESCANSO'` -> `[{ dayOfWeek, completed: !!log }]`.

**Response 200**:
```json
{
  "submitted": "boolean",
  "weekNumber": "number",
  "totalWeeks": "number | null",
  "weekSessions": [{ "dayOfWeek": "number", "completed": "boolean" }],
  "hasAutoData": "boolean",
  "data": "WeeklyCheckIn | null",
  "pendingSuggestions": "Suggestion[]"
}
```

### POST `/api/mobile/checkin`

**Feature gate**: `checkin`

**Zod schema** (`mobileCheckInSchema`):
```ts
energyLevel:     number  min(1) max(10)   // OBLIGATORIO
muscleSoreness:  number  min(1) max(10)   // OBLIGATORIO (mapea a rpe en dominio)
stressLevel?:    number  min(1) max(10)
motivationLevel?:number  min(0) max(10)
sleepScore?:     number  min(0) max(10)
painLevel?:      number  min(0) max(10)
weightKg?:       number  min(10) max(500)
hrResting?:      number  min(0) max(250)
sleepHours?:     number  min(0) max(24)
nutritionAdherencePct?:number min(0) max(100)
notes?:          string  max(5000)
waistCm?:        number  min(40) max(200)
armsCm?:         number  min(10) max(100)
hipsCm?:         number  min(40) max(200)
thighsCm?:       number  min(20) max(120)
```

**TRAMPA T05**: mobile NO tiene `hardestRpe`; usa `muscleSoreness` (mismo rango 1-10, mismo mapeo a `rpe` en dominio).

**Flujo**: `mapMobileCheckinBody(body)` -> `processCheckIn(...)` -> side effects fire-and-forget.

**Diferencia vs web**: la respuesta mobile NO incluye `planChanges` ni `nutritionChanges` en `adjustment`.

### GET `/api/mobile/checkin-status`

**Feature gate**: `checkin` — si no tiene el feature: `{ pending: false, locked: true }` (200, no error).

**Logica**: si no hay check-in en los ultimos 7 dias -> `pending: true`.

**Response 200**: `{ "pending": boolean, "lastCheckin": { "createdAt": string, "energyLevel": number | null, "weightKg": number | null } | null }`

### Sugerencias accept/reject (web y mobile)

**Errores**: 404 (no encontrada), 403 (no es del usuario), 409 (ya respondida o expirada).

**Accept — flujo en `$transaction`**:
1. `checkInSuggestion.update({ status: 'ACCEPTED', respondedAt: now })`
2. Si tipo `PLAN_ADJUSTMENT` o `RECOVERY_WEEK` y payload tiene `planId: string` y `nextWeek: number` -> llama `applySessionAdjustments(planId, nextWeek, triggers, txPlan)`

**Reject**: `checkInSuggestion.update({ status: 'REJECTED', respondedAt: now })`

---

## Dominio: processCheckIn (use case compartido)

**Archivo**: `src/domain/checkin/process_check_in.use_case.ts`

### Tres fases

**Fase 1 — Lecturas en paralelo** (fuera de transaction):
- `checkInRepo.findLatest(userId)` — check-in anterior
- `planRepo.findActive(userId)` — plan activo
- `assignedWorkout.findFirst(...)` — plan de gym
- `weeklyCheckIn.findMany(take: 4, orderBy: weekNumber desc)` — ultimas 4 semanas para `consecutiveLowEnergyWeeks`
- `checkInRepo.getWeekActivitySummary(userId)` — datos objetivos de la semana

**Fase 2 — Evaluacion pura** (sin I/O):
- `evaluateCheckInRules(data, planContext)` -> `{ triggers, adjustments, severity }`
- `buildSessionAdjustments(triggers)` -> `{ hasPain, hasVolumeTrigger, hasRpe, volumeReduction }`

**Fase 3 — $transaction (timeout 30s)**:
1. `checkInRepo.save(userId, { ...data, trainingAdherence, triggers, weekNumber, planId })`
2a. Si `plan.source === 'COACH'` y hay triggers: `generateSuggestions(...)` -> `suggRepo.createMany(...)` (NO auto-aplica)
2b. Si `assignedWorkout` y triggers `dolor_activo` o `rpe_excesivo`: actualiza `WorkoutDay.warmupNotes` con prefijo `[AUTO]`.

> **[roadmap R4] PENDIENTE DE ELIMINAR.** Check-in = recopilación de datos solamente. La auto-modificación de `warmupNotes` será eliminada.
3. Si `data.weight`: `syncWeight(...)` — ver detalle abajo.

> **[roadmap R3] PENDIENTE DE ELIMINAR recálculo.** La decisión de producto es que syncWeight solo guarda peso en HealthProfile.weightKg. El código actual TODAVÍA recalcula TDEE/macros — esto es código zombie que será eliminado en R3.

**Comportamiento activo (código zombie):** `syncWeight()` detecta |Δkg| >= 0.3 → actualiza `HealthProfile.weightKg` Y recalcula `NutritionPlan` (TDEE, macros, targets por dayType).
**Comportamiento objetivo (post-R3):** `syncWeight()` solo actualiza `HealthProfile.weightKg`. Sin recálculo de NutritionPlan.
3b. Si `data.heartRate > 0`: `healthProfileRepo.updateHrResting(userId, heartRate)`
4. Si es primer check-in (count=1): `userRepo.enableFeature(userId, 'progress')`

### Reglas de evaluacion (CHECK_IN_THRESHOLDS)

| Constante | Valor | Trigger generado |
|-----------|-------|-----------------|
| `HIGH_RPE` | 8 | `rpe_excesivo` (running, fase BASE) o `gym_sobrecarga` (gym) |
| `LOW_SLEEP` | 6.5 h | `sueno_bajo` |
| `HIGH_STRESS` | 8 | `estres_alto` |
| `HIGH_PAIN` | 5 | `dolor_activo` (critical) |
| `WEIGHT_LOSS_WEEKLY` | 1 kg | `perdida_peso_rapida` |
| `LOW_ENERGY` | 3 | `energia_baja` |
| `LOW_MOTIVATION` | 3 | `motivacion_baja` |
| `LOW_NUTRITION_ADH` | 4/10 | `nutricion_baja` o `nutricion_deficit_critico` (+ energia baja) |
| `WEIGHT_DELTA_MIN` | 0.5 kg | umbral minimo para actualizar HealthProfile |

**Reglas objetivas** (desde `WeekActivitySummary`):

| Condicion | Trigger |
|-----------|---------|
| `consecutiveActiveDays >= 5` | `sin_descanso` |
| `avgRpe >= 8` && `checkIn.rpe <= 5` | `rpe_discrepancia` |
| `totalMinutes >= 1.5 x prevWeeksAvgMinutes` | `pico_volumen` |
| `maxRpe >= 9` | `sesion_muy_intensa` |
| `triggers.length >= 3` | `fatiga_acumulada` (critical) |

**Reduccion de volumen** (`buildSessionAdjustments`):
- Triggers que activan volumen: `['energia_baja','sueno_bajo','fc_alta','estres_alto','pico_volumen','sin_descanso']`
- `volumeReduction`: 0.85 si `estres_alto`, 0.80 para el resto
- `hasRpe` (zona baja): solo `rpe_excesivo` (NO `gym_sobrecarga`)

### applySessionAdjustments (exportado)

> **[roadmap R4] PENDIENTE DE ELIMINAR.** Check-in = recopilación de datos solamente. `applySessionAdjustments` será eliminado.

Usada tambien por los endpoints de accept sugerencia.

**Reglas de skip**: sesiones con `coachNotes` (DB: `coachNote` singular — el repositorio mapea `coachNote` → `coachNotes`) que NO contienen `[AUTO]` -> se saltan (editadas manualmente por el coach).

**Notas `[AUTO]`**: se anaden con prefijo `[AUTO]` para permitir limpieza posterior. El proceso de check-in LIMPIA las notas `[AUTO]` previas de `WorkoutDay.warmupNotes` antes de escribir las nuevas (regex `\s*\[AUTO\][\s\S]*$`).

---

## T05 — Mapeo de nombres (TRAMPA CRITICA)

| Capa | Nombre |
|------|--------|
| Web body | `hardestRpe` |
| Mobile body | `muscleSoreness` |
| Dominio (CheckInInput) | `rpe` |
| DB (WeeklyCheckIn) | `hardestSessionRpe` |

`mapWebCheckinBody`: `hardestRpe -> rpe`
`mapMobileCheckinBody`: `muscleSoreness -> rpe`
`checkin.repository.ts`: `rpe -> hardestSessionRpe`

---

## Modelos DB

### WeeklyCheckIn
```
id, userId, weekNumber, planId
hardestSessionRpe (int, nullable) <- dominio: rpe
energyLevel, sleepHours, sleepScore, stressLevel, motivationLevel
nutritionAdherencePct, weightKg, hrResting, painLevel, painDescription
notes, waistCm, armsCm, hipsCm, thighsCm
trainingAdherence (float, nullable)  // Nota: se calcula en el use case pero NO se persiste en DB — no existe como columna en el schema
triggers (string[], nullable)  (DB: `adjustmentsTriggered`)
recordedAt (DateTime)
```

### CheckInSuggestion
```
id, userId, checkInId
type: 'PLAN_ADJUSTMENT' | 'RECOVERY_WEEK' | 'NUTRITION_CHANGE' | 'GYM_DELOAD'
status: 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'EXPIRED'
title, description (string)
payload (Json) <- { planId, nextWeek, triggers[] } para PLAN_ADJUSTMENT/RECOVERY_WEEK
expiresAt (DateTime) <- +7 dias desde creacion
respondedAt (DateTime, nullable)
```

---

## Reglas de negocio

1. **R01 — semana del plan vs semana ISO**: Con plan activo usa `getPlanWeekNumber()`. Sin plan usa `getCurrentISOWeek()`. Nunca mezclar.
2. **R02 — COACH vs SYSTEM plan**: `source === 'SYSTEM'` auto-aplica ajustes. `source === 'COACH'` genera sugerencias. **Nota**: El enum `PlanSource` en DB solo tiene `COACH`. El valor `SYSTEM` no existe — este path nunca se ejecuta. Regla reservada para futura implementacion.
3. **R10 — nutritionAdherencePct**: escala 0-100 en body -> dominio 1-10 (/10 en mapper).
4. **R11 — syncWeight**: compara vs `profile.weightKg` (peso base), no vs check-in anterior. Umbral: 0.5 kg.
5. **R12 — Primer check-in habilita 'progress'**: `count(userId) === 1` -> `enableFeature(userId, 'progress')`.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| T05 — Naming RPE | Un solo campo | 4 nombres distintos segun la capa. Nunca enviar `hardestRpe` desde mobile. |
| T10 — suggestions.payload tipado Json | Puede acceder directamente | Cast manual. Verificar `typeof payload.planId === 'string'` antes de usar. |
| T02 — [AUTO] prefix | Texto libre | Marca notas auto-generadas. El sistema limpia `[AUTO]` previas. Nunca escribir texto manual con ese prefijo. |

---

## Paridad web vs mobile

| Funcionalidad | Web | Mobile | Diferencias |
|--------------|-----|--------|-------------|
| Check-in GET | `/athlete/checkin` | `/mobile/checkin` | Mobile incluye: `submitted`, `weekSessions`, `hasAutoData`, `totalWeeks` |
| Check-in POST | `/athlete/checkin` | `/mobile/checkin` | Schemas diferentes (T05). Respuesta mobile sin `planChanges`/`nutritionChanges` |
| Check-in status | NO EXISTE | `/mobile/checkin-status` | Solo mobile |
| Sugerencias | `/athlete/checkin/suggestions/[id]/{accept,reject}` | `/mobile/checkin/suggestions/[id]/{accept,reject}` | Logica identica. Mobile con rate limit |

---

## Tests requeridos

### Check-in
- [ ] POST web: requiere energyLevel o hardestRpe — 400 si ambos null
- [ ] POST mobile: energyLevel y muscleSoreness obligatorios
- [ ] POST: processCheckIn genera sugerencias para plan COACH, auto-aplica para SYSTEM
- [ ] POST: syncWeight actualiza HealthProfile si delta >= 0.5 kg
- [ ] POST: primer check-in habilita feature 'progress'

### Sugerencias
- [ ] POST accept: propuesta ya respondida retorna 409
- [ ] POST accept: propuesta de otro usuario retorna 403
- [ ] POST accept: PLAN_ADJUSTMENT aplica applySessionAdjustments
- [ ] GET checkin-status: locked=true si no tiene feature checkin

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-08 | Web endpoints table: add Feature gate column, rate limits (300/30/60/60) |
| 2026-10-02 | Split desde plan.spec.md — check-in y sugerencias |
| 2026-09-29 | Spec original creada |
