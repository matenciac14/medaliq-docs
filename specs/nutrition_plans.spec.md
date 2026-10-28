# NUTRITION PLANS — Planned Meals, Targets, B2B, Food Profile, Init/Generate

<!-- mirror: true -->
<!-- mirror-endpoints: GET/POST/DELETE /api/athlete/nutrition/planned-meals ↔ /api/mobile/nutrition/planned-meals, GET/PUT /api/athlete/nutrition/food-profile ↔ /api/mobile/nutrition/food-profile -->

> Split de nutrition.spec.md. Planificacion y targets nutricionales.
> Specs relacionadas: `nutrition_tracking.spec.md`, `nutrition_templates.spec.md`, `nutrition_proposals.spec.md`
> Domain doc: `../domains/nutricion.md`

## TL;DR
- 16 endpoints (10 web, 6 mobile + assigned-plan exclusivo)
- Modelos: PlannedMeal, AthleteNutritionOverride, NutritionPlan, FoodProfile, AssignedNutritionPlan
- Dependencias: getDailyNutritionTarget(), calculateTDEE(), calculateMacros(), intensityToDayType() [roadmap R5] PENDIENTE DE ELIMINAR
- Trampas criticas: intensityToDayType(null)='easy' [roadmap R5] PENDIENTE DE ELIMINAR, planned-summary TZ hardcodeado Bogota, B2B no puede editar targets
- Mirror mobile: planned-meals, food-profile (targets solo web, assigned-plan solo mobile)

---

## Contratos de la AI

- `intensityToDayType()` mapea: `HIGH` → `'hard'`, `LOW` → `'low'`, `REST` → `'rest'`, cualquier otra cosa (incluyendo `MODERATE` y `null`) → `'easy'`. CUIDADO: `null` y `MODERATE` producen el mismo `'easy'`. [roadmap R5] PENDIENTE DE ELIMINAR — el target diario no debe variar automaticamente por intensidad de sesion.
- Los targets de dia LOW usan multiplicadores fijos: kcal = `targetKcalEasy * 0.88`, carbos = `carbsEasyG * 0.75`. REST usa: carbos = `carbsEasyG * 0.70`.
- `fatG` siempre se deriva como `(kcal - protein*4 - carbs*4) / 9`, redondeado al entero mas cercano (`Math.round`), nunca negativo.
- Un atleta con `CoachAthlete.status = 'ACTIVE'` NO puede editar sus `NutritionPlan.targets`. Recibe 403.
- La prioridad del plan de comidas en mobile es: (1) `AssignedNutritionPlan` del coach, (2) `MealPlan` JSON legacy, (3) sin plan (modo tracking libre).
- En `planned-summary`, el timezone esta hardcodeado a `'America/Bogota'`. No es dinamico segun el usuario.

---

## Endpoints

### Web

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/athlete/nutrition/planned-meals` | ninguna | ninguna | PlannedMeals por fecha o semana |
| POST | `/api/athlete/nutrition/planned-meals` | ninguna | ninguna | Crear PlannedMeal individual |
| PATCH | `/api/athlete/nutrition/planned-meals/[id]` | ninguna | ninguna | Actualizar grams de un PlannedMeal |
| DELETE | `/api/athlete/nutrition/planned-meals/[id]` | ninguna | ninguna | Borrar PlannedMeal |
| POST | `/api/athlete/nutrition/planned-meals/log-today` | ninguna | ninguna | Convertir PlannedMeals de hoy a FoodLog (idempotente) |
| GET | `/api/athlete/nutrition/planned-summary` | ninguna | ninguna | Resumen dia: PlannedMeals + FoodLogs + totales + adherencia |
| GET | `/api/athlete/nutrition/adherence` | ninguna | ninguna | Adherencia calorica diaria (from/to params, default 7 dias) |
| GET | `/api/athlete/nutrition/targets` | ninguna | ninguna | Leer NutritionPlan del atleta |
| PATCH | `/api/athlete/nutrition/targets` | ninguna | ninguna | Editar targets (solo B2C sin coach activo) |
| GET | `/api/athlete/nutrition/food-profile` | ninguna | ninguna | Leer FoodProfile del atleta |
| PUT | `/api/athlete/nutrition/food-profile` | ninguna | ninguna | Upsert FoodProfile |
| POST | `/api/athlete/nutrition/init` | ninguna | ninguna | Inicializar NutritionPlan desde HealthProfile (idempotente) |
| POST | `/api/athlete/nutrition/generate` | 3/hora | ninguna | Regenerar NutritionPlan desde HealthProfile |

### Mobile

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/mobile/nutrition/planned-meals` | 300/min | nutrition | PlannedMeals de la semana agrupados por fecha |
| POST | `/api/mobile/nutrition/planned-meals` | 100/min | nutrition | Crear PlannedMeal individual |
| DELETE | `/api/mobile/nutrition/planned-meals/[id]` | 60/min | nutrition | Borrar PlannedMeal |
| POST | `/api/mobile/nutrition/planned-meals/log-today` | 100/min | nutrition | Convertir PlannedMeals de hoy a FoodLog |
| GET | `/api/mobile/nutrition/plan` | 300/min | nutrition | PlannedMeals de una fecha con overrides aplanados |
| POST | `/api/mobile/nutrition/plan/[id]/log` | 100/min | nutrition | Registrar un PlannedMeal especifico como FoodLog (1 tap) |
| GET | `/api/mobile/nutrition/assigned-plan` | 300/min | nutrition | Plan nutricional asignado por el coach |
| GET | `/api/mobile/nutrition/food-profile` | 300/min | ninguna | Leer FoodProfile |
| PUT | `/api/mobile/nutrition/food-profile` | 100/min | ninguna | Upsert FoodProfile |

---

## Detalle de endpoints

### Grupo 4 — Planned Meals

#### GET `/api/athlete/nutrition/planned-meals`
- `?date=YYYY-MM-DD`: retorna solo ese dia
- Sin date o con `?weekStart=YYYY-MM-DD`: retorna la semana (lunes a domingo)
- Response: `{ meals: { "YYYY-MM-DD": PlannedMeal[] } }` agrupado por fecha

#### GET `/api/mobile/nutrition/planned-meals`
- Solo acepta `?weekStart=YYYY-MM-DD` y `?tz=`
- Sin weekStart: usa `getWeekMonday(0, tz)` para calcular el lunes actual

#### POST planned-meals (web y mobile)
**Body**: `{ date: "YYYY-MM-DD", mealType: string, foodId: string, grams: number }`
- Verifica que `Food.isActive === true` antes de crear.

#### PATCH `/api/athlete/nutrition/planned-meals/[id]` (solo web)
- Solo acepta `{ grams: number }`. Verifica ownership. No existe equivalente mobile.

#### POST log-today (web y mobile)
- Obtiene timezone, busca PlannedMeals de hoy, calcula macros
- `createMany({ skipDuplicates: true })` — idempotente
- Response: `{ created: number, total: number }`

#### GET `/api/mobile/nutrition/plan`
PlannedMeals de una sola fecha con overrides aplanados. Response: `{ date, meals: PlannedMeal[] }`.

### Grupo 5 — Plan Nutricional Asignado (B2B)

#### GET `/api/mobile/nutrition/assigned-plan`
Retorna `AssignedNutritionPlan` con template completo. Determina `dayType` segun sesion de hoy. Calcula totales por dia.

### Grupo 7 — Targets Nutricionales

#### GET `/api/athlete/nutrition/targets`
Retorna `NutritionPlan` completo.

#### PATCH `/api/athlete/nutrition/targets`
- B2B check: `CoachAthlete.status = 'ACTIVE'` → 403
- Si `kcalAdjustment`: recalcula TODOS los macros con Mifflin-St Jeor/Karvonen
- `fatG` se recalcula como residual. Siempre `source: 'ATHLETE'`.

### Grupo 8 — Food Profile

#### GET + PUT food-profile (web y mobile)
**Zod PUT**: `{ availableFoodIds: string[], restrictions: string[], mealsPerDay: int 2-6, weighsFood: boolean, notes?: string }`
Filtra IDs contra `Food.isActive === true` antes de guardar.

### Grupo 14 — Init y Generate

#### POST `/api/athlete/nutrition/init`
Idempotente: `upsert` con `update: {}`. Calcula TDEE + macros. `kcalAdjustment` default: -500 si hay weightGoalKg.

#### POST `/api/athlete/nutrition/generate`
Regenera siempre. Rate limit: 3/hora. Activa `featureNutrition` y `featureProgress`. Preserva `kcalAdjustment` existente.

---

## Modelos DB

### PlannedMeal
```
id, userId, date, mealType, foodId, grams
overrides → AthleteNutritionOverride[]
```

### AthleteNutritionOverride
```
id, athleteId, plannedMealId, overrideFoodId, overrideGrams
@@unique([athleteId, plannedMealId])
```

### NutritionPlan (1:1 con User)
```
userId (unique)
tdee, kcalAdjustment
targetKcalHard, targetKcalEasy, targetKcalRest
proteinG, carbsHardG, carbsEasyG, fatG
waterMlTarget (default 2000)
source ('ATHLETE' | 'COACH')
```

### FoodProfile (1:1 con User)
```
userId (unique)
availableFoodIds String[], availableFoods String[]
restrictions String[], mealsPerDay (default 3)
weighsFood (default false), notes?
```

### AssignedNutritionPlan (B2B — 1:1 con atleta)
```
athleteId (unique), templateId, coachId, assignedAt
template → NutritionTemplate
```

---

## Reglas de negocio

1. Un atleta B2B (con `CoachAthlete.status = 'ACTIVE'`) NO puede editar `NutritionPlan.targets`. Recibe 403.
2. El coach gestiona el plan nutricional B2B via `AssignedNutritionPlan`. El atleta B2B solo consume el plan, no lo edita.
3. `log-today` es idempotente via `skipDuplicates: true`.
4. `generate` activa `featureNutrition` y `featureProgress`. `init` NO los activa.
5. `planned-summary` tiene timezone hardcodeado a `'America/Bogota'`.
6. La adherencia en `planned-summary` se capea al 150%: `Math.min(150, adherencePct)`.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `intensityToDayType(null)` | Podria ser 'rest' o null | Retorna `'easy'`. null y MODERATE producen el mismo resultado. [roadmap R5] PENDIENTE DE ELIMINAR |
| `planned-summary` timezone | Parece que usa timezone del usuario | Hardcodeado a `'America/Bogota'`. |

---

## Paridad web vs mobile

| Funcionalidad | Web | Mobile | Diferencia |
|--------------|-----|--------|-----------|
| Planned meals GET | `/athlete/nutrition/planned-meals` | `/mobile/nutrition/planned-meals` | Web: acepta `?date=` o `?weekStart=`. Mobile: solo `?weekStart=` + `?tz=` |
| Planned meals PATCH | `/athlete/nutrition/planned-meals/[id]` | NO EXISTE | Solo web |
| Log today | `/athlete/nutrition/planned-meals/log-today` | `/mobile/nutrition/planned-meals/log-today` | Identico |
| Plan fecha | NO EXISTE | `/mobile/nutrition/plan` | Solo mobile |
| Plan/[id]/log | NO EXISTE | `/mobile/nutrition/plan/[id]/log` | Solo mobile |
| Assigned plan | NO EXISTE | `/mobile/nutrition/assigned-plan` | Solo mobile |
| Targets | `/athlete/nutrition/targets` | NO EXISTE | Solo web |
| Food profile | `/athlete/nutrition/food-profile` | `/mobile/nutrition/food-profile` | Identico |
| Planned summary | `/athlete/nutrition/planned-summary` | NO EXISTE | Solo web |
| Adherencia | `/athlete/nutrition/adherence` | NO EXISTE | Solo web |

---

## Tests requeridos

### Planned Meals
- [ ] POST planned-meals: food inactivo retorna 404
- [ ] DELETE planned-meals: solo borra meals del propio usuario
- [ ] POST log-today: idempotente — segunda ejecucion no crea duplicados
- [ ] POST log-today: retorna `{ created: 0 }` si no hay PlannedMeals hoy

### Targets
- [ ] PATCH targets: atleta B2B recibe 403
- [ ] PATCH targets con kcalAdjustment: recalcula todos los macros
- [ ] PATCH targets: fatG nunca puede ser negativo

### getDailyNutritionTarget
- [ ] HIGH usa targetKcalHard y carbsHardG
- [ ] MODERATE usa targetKcalEasy y carbsEasyG
- [ ] LOW = targetKcalEasy * 0.88, carbsEasyG * 0.75
- [ ] REST = targetKcalRest, carbsEasyG * 0.70
- [ ] fatG siempre >= 0 aunque kcal sea muy bajo

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-05 | Fix: feature gate `nutrition` en assigned-plan mobile, refuerzo senalizacion R5 intensityToDayType |
| 2026-10-02 | Split desde nutrition.spec.md — planes y targets (Groups 4-5, 7-8, 14) |
| 2026-09-29 | Spec original creada |
