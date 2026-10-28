# NUTRITION PROPOSALS & TODAY — Coach Proposals, Unified Mobile Endpoint

<!-- mirror: true -->
<!-- mirror-endpoints: GET/PATCH /api/athlete/nutrition/proposals ↔ GET/POST /api/mobile/nutrition/proposals, /api/mobile/nutrition/today (solo mobile) -->

> Split de nutrition.spec.md. Propuestas del coach + endpoint unificado mobile.
> Specs relacionadas: `nutrition_tracking.spec.md`, `nutrition_plans.spec.md`, `nutrition_templates.spec.md`
> Domain doc: `../domains/nutricion.md`

## TL;DR
- 7 endpoints (4 web incl deprecated adjust, 3 mobile + /today)
- Modelos: CoachNutritionProposal, PendingNutritionAdjustment (DEPRECATED)
- Dependencias: respondCoachProposal use case, getNutritionToday use case (1 query secuencial + 14 queries paralelas = 15 total)
- Trampas criticas: web PATCH vs mobile POST para proposals, /today intensity MODERATE inconsistencia, pendingAdjustment siempre null
- Mirror mobile: proposals (metodo HTTP diferente), adjustment deprecated

---

## Contratos de la AI

- `PendingNutritionAdjustment` esta **DEPRECATED (NUT-15)**. Los endpoints `adjustment/[id]/accept` y `adjustment/[id]/reject` se conservan solo para datos historicos. No generar nuevos.
- El endpoint `/api/mobile/nutrition/today` es el endpoint unificado de mobile. Es el UNICO que el nutrition tab debe llamar al montar. Hace 1 query secuencial (trainingPlan activo) + 14 queries en paralelo = 15 queries totales.
- La prioridad del plan de comidas en mobile es: (1) `AssignedNutritionPlan` del coach, (2) `MealPlan` JSON legacy, (3) sin plan.
- El endpoint `/api/mobile/nutrition/today` siempre devuelve `pendingAdjustment: null` (deprecated hardcodeado).

---

## Endpoints

### Web

| Method | Path | Rate limit | Descripcion |
|--------|------|-----------|-------------|
| GET | `/api/athlete/nutrition/proposals` | ninguna | Propuestas del coach pendientes (role=ATHLETE) |
| PATCH | `/api/athlete/nutrition/proposals/[id]` | ninguna | Responder propuesta (ACCEPTED/REJECTED) |
| POST | `/api/athlete/nutrition/adjustment/[id]/accept` | ninguna | DEPRECATED |
| POST | `/api/athlete/nutrition/adjustment/[id]/reject` | ninguna | DEPRECATED |

### Mobile

| Method | Path | Rate limit | Descripcion |
|--------|------|-----------|-------------|
| GET | `/api/mobile/nutrition/today` | 300/min | Endpoint unificado: todo para la tab nutricion. Feature gate: `nutrition` |
| GET | `/api/mobile/nutrition/proposals` | 300/min | Propuestas pendientes. Feature gate: `nutrition` |
| POST | `/api/mobile/nutrition/proposals/[id]` | 100/min | Responder propuesta (ACCEPTED/REJECTED) |
| POST | `/api/mobile/nutrition/adjustment/[id]/accept` | 100/min | DEPRECATED |
| POST | `/api/mobile/nutrition/adjustment/[id]/reject` | 100/min | DEPRECATED |

---

## Detalle de endpoints

### Coach Proposals

#### GET proposals (web y mobile)
Usa `CoachNutritionProposalRepository.findPendingForAthlete(athleteId)`.

#### PATCH `/api/athlete/nutrition/proposals/[id]` y POST `/api/mobile/nutrition/proposals/[id]`
**Nota**: web usa PATCH, mobile usa POST. Misma logica via `respondCoachProposal()`.

**Body**: `{ action: "ACCEPTED" | "REJECTED" }`

**Logica** (`respondCoachProposal` use case):
- `REJECTED`: solo actualiza status y respondedAt
- `ACCEPTED`: aplica deltas al NutritionPlan en `$transaction`. Floor 0 en todos los valores. Pone `source: 'COACH'`.
- Errores: NOT_FOUND (404), ALREADY_RESPONDED (409), NO_PLAN (422)

### Endpoint Unificado Mobile (`/api/mobile/nutrition/today`)

1 query secuencial + 14 queries en paralelo = 15 total:

**Secuencial (fase 1):** TrainingPlan activo (`status: ACTIVE`) — necesario para condicionar queries de fase 2

**Paralelas (fase 2, Promise.all):**
1. NutritionPlan · 2. MealPlan (legacy) · 3. PlannedSession hoy (condicional: solo si hay plan activo + currentWeek) · 4. AssignedNutritionPlan (con coach + template completo incluyendo days/meals/items/food) · 5. PlannedMeal[] hoy (con food + overrides) · 6. FoodLog[] hoy (con food) · 7. WaterLog hoy · 8. AssignedWorkout (dias del hoy para gym) · 9. GymSession completada hoy · 10. PlanWeek actual (condicional) · 11. HealthProfile · 12. Food proposals (via PrismaFoodProposalRepository) · 13. FoodLog[] semana · 14. PlannedSession[] semana (condicional)

**Calculo de intensity**:
- PlannedSession.intensity → usa esa
- Solo AssignedWorkout con dia activo → MODERATE
- Ninguno → null → `intensityToDayType(null)` → `'easy'`

**Response completo:**
```json
{
  "hasNutritionPlan": boolean,
  "dayType": "hard|easy|rest",
  "macros": { "kcal", "proteinG", "carbsG", "fatG", "tdee" } | null,
  "targets": DailyNutritionTarget | null,
  "dayTargets": { "hard": DailyNutritionTarget, "easy": DailyNutritionTarget, "rest": DailyNutritionTarget } | null,
  "intensity": "hard|easy|rest",
  "plannedMeals": PlannedMeal[] (con override flatten),
  "templateMeals": NutritionTemplateMeal[] | null,
  "foodLogs": FoodLogResponse,
  "adherence": { "kcalLogged": number, "kcalTarget": number, "pct": number },
  "waterMl": number,
  "waterTarget": number,
  "mealPlan": MealPlanData | null,
  "gymKcalBurned": number | null,
  "planPhaseContext": string | null,
  "pendingAdjustment": null,
  "isB2B": boolean,
  "coachName": string | null,
  "planName": string | null,
  "mealChecklist": [{ "mealType", "label", "foods", "kcal", "proteinG", "isLogged" }],
  "nextMeal": { "label", "time", "foods", "kcal", "proteinG" } | null,
  "tip": { "title": string, "body": string } | null,
  "proposals": [{ "id", "status", "food": { "id", "name", "kcalPer100g", ... }, "reviewNote", "country", "notes", "createdAt" }],
  "weeklySummary": { "weekStart", "weekEnd", "daysWithLog", "daysWithoutLog", "avgKcal", "targetKcal", "adherencePct" }
}
```

---

## Modelos DB

### CoachNutritionProposal
```
id, coachId, athleteId
status ('PENDING' | 'ACCEPTED' | 'REJECTED')
deltaKcal, deltaProtein, deltaCarbs, deltaFat
respondedAt?
```

### PendingNutritionAdjustment (DEPRECATED)
```
id, userId, status ('PENDING' | 'ACCEPTED' | 'REJECTED')
acceptedAt?, rejectedAt?
```

---

## Reglas de negocio

1. `PendingNutritionAdjustment` esta deprecated. No generar nuevos.
2. El endpoint `/api/mobile/nutrition/today` siempre devuelve `pendingAdjustment: null`.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Coach proposal: metodo HTTP | Deberian ser iguales | Web: PATCH. Mobile: POST. Misma logica interna. |
| Mobile `/nutrition/today` intensity MODERATE | Gym sin plan produce MODERATE | En `/nutrition/route.ts` (legacy) usa HIGH para gym, en `/nutrition/today` usa MODERATE. Inconsistencia. |
| `log-today` calcula macros distinto | Web inline, mobile calcMacros() | Resultado numerico identico. |

---

## Paridad web vs mobile

| Funcionalidad | Web | Mobile | Diferencia |
|--------------|-----|--------|-----------|
| Propuestas coach GET | `GET /athlete/nutrition/proposals` | `GET /mobile/nutrition/proposals` | Identico — misma query via repo |
| Responder propuesta | `PATCH /athlete/nutrition/proposals/[id]` | `POST /mobile/nutrition/proposals/[id]` | Metodo HTTP diferente (PATCH vs POST). Misma logica via `respondCoachProposal()` |
| Adjustment accept (DEPRECATED) | `POST /athlete/nutrition/adjustment/[id]/accept` | `POST /mobile/nutrition/adjustment/[id]/accept` | DEPRECATED en ambos. No generar nuevos |
| Adjustment reject (DEPRECATED) | `POST /athlete/nutrition/adjustment/[id]/reject` | `POST /mobile/nutrition/adjustment/[id]/reject` | DEPRECATED en ambos. No generar nuevos |
| Endpoint unificado hoy | No existe | `GET /mobile/nutrition/today` (NUT-14) | Solo mobile — 1 secuencial + 14 paralelas = 15 queries. Incluye foodLogs, waterLog, mealPlan, adherencia, weeklySummary, plannedMeals, templateMeals, dayTargets, nextMeal, tip, proposals, gymKcalBurned, planPhaseContext. `pendingAdjustment` siempre `null` (NUT-15). Feature gate: `nutrition`. |

**NUT-14 (`/mobile/nutrition/today`) es mobile-only.** La web usa RSC + llamadas separadas por seccion. No tiene equivalente web unico. Es el UNICO endpoint que el nutrition tab mobile debe llamar al montar. Tiene feature gate `nutrition` (retorna 402 si no tiene acceso).

**NUT-15 (`PendingNutritionAdjustment`) DEPRECATED.** Los endpoints `adjustment/[id]/accept` y `adjustment/[id]/reject` existen en web y mobile solo para compatibilidad con datos historicos. `pendingAdjustment` esta hardcodeado a `null` en `/today`. No crear nuevos `PendingNutritionAdjustment`.

---

## Tests requeridos

### Proposals
- [ ] PATCH/POST proposals: action ACCEPTED aplica deltas al NutritionPlan
- [ ] PATCH/POST proposals: propuesta ya respondida retorna 409
- [ ] PATCH/POST proposals: propuesta de otro atleta retorna 404
- [ ] PATCH/POST proposals: ACCEPTED sin NutritionPlan retorna 422

---

## UI — Mapa de CTAs

> Auditado contra Figma (fileKey `fV1SK1rxdJHAmA8n1zK3Cm`) y codigo el 2026-09-30.

### Pagina principal

| CTA | Componente | Archivo | Accion | Condicion |
|-----|-----------|---------|--------|----------|
| Crear mi menu → | EmptyMealPlanCard | EmptyMealPlanCard.tsx | → `/nutrition/builder` | sin-plan |
| Pedir plan a mi coach | EmptyMealPlanCard | EmptyMealPlanCard.tsx | → `/coaches` | sin-plan, !isB2B |
| + Registrar comida | TrackingSection | TrackingSection.tsx | abre LogFoodModal | siempre |
| 📋 Ver lo que consumi | DeficitHeroCard | DeficitHeroCard.tsx | abre ConsumedModal | con-plan, b2b |
| +250ml / +500ml / +1L | HydrationWidget | HydrationWidget.tsx | POST water | siempre |

### Modal: Registrar comida

| CTA | Componente | Accion |
|-----|-----------|--------|
| Pills Desayuno/Almuerzo/etc | LogFoodModal | selecciona mealType |
| + (alimento) | LogFoodModal | → step detail |
| + (template/menu) | LogFoodModal | POST batch log items |
| Agregar Xg de Y al Z | LogFoodModal | POST nutrition/log + cierra |

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-02 | Split desde nutrition.spec.md — proposals y /today (Groups 12-13) |
| 2026-10-02 | Paridad web↔mobile completada: NUT-14 /today solo mobile, NUT-15 DEPRECATED, metodo PATCH vs POST |
| 2026-09-30 | UI CTAs agregada |
| 2026-09-29 | Spec original creada |
| 2026-10-05 | Fix: query count 13->14+1=15, response completo documentado (dayTargets, intensity, plannedMeals, templateMeals, waterTarget, gymKcalBurned, planPhaseContext, coachName, planName, nextMeal, tip, proposals), feature gate nutrition en GET proposals y /today | Auditoria vs codigo real |
