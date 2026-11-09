---
tags: [medaliq, spec, dashboard, nutricion, entrenamiento]
---

# ENERGY_BALANCE — Dashboard "Mi Dia" Unificado

<!-- mirror: true -->
<!-- mirror-endpoints: GET /api/athlete/energy-balance ↔ GET /api/mobile/energy-balance -->

> Spec nueva. Unifica datos de nutricion (consumo) + entrenamiento (gasto) + agua + peso en una sola vista.
> Specs relacionadas: `dashboard.spec.md`, `nutrition_tracking.spec.md`, `plan_sessions.spec.md`
> Domain doc: [[atleta]] · [[nutricion]] · [[entrenamiento]]

## TL;DR
- 2 endpoints (1 web, 1 mobile) + 1 endpoint semanal
- Modelos: NutritionPlan, FoodLog, SessionLog, GymSession, DailyLog, WaterLog, WeeklyCheckIn
- Dependencias: getDashboardSummary(), computeFoodTotals(), calculateTDEE()
- Trampas: calorias quemadas en ejercicio son ESTIMADAS (no exactas), TDEE ya existe en HealthProfile
- Mirror mobile: endpoint espejo con misma logica, diferente auth

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
El atleta abre la app y ve en UN vistazo: calorias consumidas vs presupuesto diario (TDEE + ejercicio), macros vs objetivo, estado de sesion del dia, agua, y peso con tendencia.

**2. Que resultado obtiene?**
Un anillo de calorias (consumo/presupuesto), barras de macros (protein/carbs/fat), indicador de sesion (completada/pendiente), agua (ml/target), peso (ultimo + tendencia semanal). Todo en una sola pantalla.

**3. Que debe respetar?**
- TDEE base ya esta calculado en HealthProfile (Mifflin-St Jeor). NO recalcular
- Calorias de ejercicio son estimadas — mostrar como "~320 kcal" (con tilde)
- nutritionTarget ya se ajusta por intensidad del dia (HIGH/MODERATE/LOW) — reutilizar logica de dashboard.spec.md
- No inventar datos: si no hay FoodLog del dia, consumo = 0 (no estimar)

**4. Como se demuestra?**
- Test: atleta sin sesion hoy → presupuesto = TDEE base (sin exercise bonus)
- Test: atleta con sesion gym 320kcal → presupuesto = TDEE + 320
- Test: atleta sin FoodLog → consumo = 0, macros = 0/0/0
- Test: resumen semanal muestra promedio correcto de 7 dias

## Contratos de la AI

- [ ] TDEE base viene de `HealthProfile.tdee` (ya calculado en onboarding). NO recalcular con formula
- [ ] Calorias de ejercicio: `SessionLog.caloriesBurned` o `GymSession.caloriesBurned` (puede ser null si no viene de wearable)
- [ ] Si calorias de ejercicio son null: estimar con `durationMin * MET_PER_TYPE` (tabla MET en domain/)
- [ ] nutritionTarget (kcal/protein/carbs/fat): reutilizar `getDailyNutritionTarget(intensity, nutritionPlan)` de `domain/nutrition/daily_target.ts`. Esta funcion SI ajusta por intensidad de la sesion del dia (HIGH→targetKcalHard, MODERATE→targetKcalEasy, null/REST→targetKcalRest). El doc nutricion.md dice que R5 desactivo esto, pero el codigo real en `get_dashboard_summary.use_case.ts` lineas 260-263 SI lo usa. No crear logica nueva — reutilizar
- [ ] `computeFoodTotals()` ya existe en `infrastructure/db/dashboard_queries.ts` — reutilizar
- [ ] WaterLog + waterMlTarget ya existen en dashboard — reutilizar
- [ ] El peso viene del ultimo WeeklyCheckIn con weightKg not null, tendencia = diferencia con el anterior
- [ ] Este endpoint NO reemplaza el dashboard existente — es un endpoint adicional que agrega la capa de balance energetico
- [ ] GymSession SI tiene `caloriesBurned Int?` (estimado desde durationMin x avgCaloriesPerMinute). SessionLog tambien lo tiene (fuente wearable). Usar el dato si existe, estimar con MET solo si es null en ambos

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/athlete/energy-balance` | auth() | 300/min | Balance energetico del dia actual |
| GET | `/api/mobile/energy-balance` | getMobileUser() | 300/min | Balance energetico del dia actual (mobile) |
| GET | `/api/mobile/energy-balance/weekly` | getMobileUser() | 60/min | Resumen semanal de balance |

### GET /api/athlete/energy-balance (y mobile mirror)

**Query params:**
```ts
{
  date?: string  // YYYY-MM-DD, default: hoy en timezone del usuario
  tz?: string    // IANA timezone
}
```

**Response 200:**
```ts
{
  date: string                    // YYYY-MM-DD

  // Balance
  tdeeBase: number               // TDEE de HealthProfile
  exerciseCalories: number        // estimadas del dia
  totalBudget: number             // tdeeBase + exerciseCalories
  consumed: number                // sum FoodLog del dia
  balance: number                 // totalBudget - consumed (positivo = deficit, negativo = superavit)

  // Macros
  macros: {
    protein: { current: number, target: number }
    carbs: { current: number, target: number }
    fat: { current: number, target: number }
  }

  // Session
  todaySession: {
    completed: boolean
    type: string | null           // FUERZA, RODAJE_Z2, etc.
    durationMin: number | null
    caloriesBurned: number | null // null si no wearable y no estimable
  } | null

  // Water
  water: {
    mlLogged: number
    mlTarget: number
  }

  // Weight
  weight: {
    current: number | null        // ultimo check-in
    previous: number | null       // check-in anterior
    weeklyChange: number | null   // diferencia normalizada a 7 dias
    trend: 'up' | 'down' | 'stable' | null
  }
}
```

**Logica:**
1. Auth check + timezone resolution
2. Paralelo:
   a. `HealthProfile` → tdee
   b. `FoodLog` del dia → computeFoodTotals()
   c. `SessionLog` + `GymSession` del dia → exerciseCalories
   d. `WaterLog` del dia
   e. `NutritionPlan` → macros target
   f. Ultimos 2 `WeeklyCheckIn` con weightKg → trend
3. exerciseCalories = sum(caloriesBurned) de sesiones completadas. Si null → estimar con MET
4. totalBudget = tdeeBase + exerciseCalories
5. balance = totalBudget - consumed
6. Serializar response

### GET /api/mobile/energy-balance/weekly

**Query params:**
```ts
{ tz?: string }
```

**Response 200:**
```ts
{
  weekStart: string              // YYYY-MM-DD (lunes)
  weekEnd: string                // YYYY-MM-DD (domingo)
  days: Array<{
    date: string
    consumed: number
    budget: number
    exerciseCalories: number
    balance: number
  }>
  averages: {
    consumed: number
    budget: number
    balance: number
  }
  weightChange: number | null    // peso domingo - peso lunes (si hay datos)
}
```

## Modelos DB involucrados

No requiere modelos nuevos. Reutiliza:

```prisma
// Ya existentes — solo lectura
HealthProfile     { tdee Float }
NutritionPlan     { targetKcalHard, targetKcalEasy, targetKcalRest, proteinG, carbsHardG, carbsEasyG, fatG }
FoodLog           { userId, date, grams, mealType, kcalLogged, proteinLogged, carbsLogged, fatLogged }
SessionLog        { userId, completedAt, caloriesBurned, durationMin, discipline }
GymSession        { athleteId, date, completed, durationMin }
WaterLog          { userId, date, mlLogged }
WeeklyCheckIn     { userId, weightKg, createdAt }
```

## Estimacion de calorias por ejercicio (MET table)

Cuando `caloriesBurned` es null (sesion manual sin wearable):

```ts
const MET_TABLE: Record<string, number> = {
  FUERZA: 5.0,
  RODAJE_Z2: 8.0,
  TEMPO: 10.0,
  INTERVALOS: 12.0,
  FARTLEK: 10.0,
  TIRADA_LARGA: 8.5,
  NATACION: 8.0,
  CICLA: 7.5,
  OTRO: 5.0,
}

// Estimacion: MET * weightKg * (durationMin / 60)
function estimateCalories(type: string, weightKg: number, durationMin: number): number {
  const met = MET_TABLE[type] ?? 5.0
  return Math.round(met * weightKg * (durationMin / 60))
}
```

Fuente: Compendium of Physical Activities (Ainsworth 2011).
El valor es una ESTIMACION — siempre mostrar con "~" en UI.

## Reglas de negocio (invariantes)

1. **Balance positivo = deficit calorico** (quemo mas de lo que comio). Balance negativo = superavit.
2. **TDEE base no cambia intradiario** — es el valor de HealthProfile, recalculado solo en check-in o cambio de peso.
3. **exerciseCalories solo cuenta sesiones COMPLETADAS del dia** (completed: true o con log).
4. **Si no hay NutritionPlan**: macros target = null (no inventar objetivos).
5. **Si no hay HealthProfile.tdee**: tdeeBase = 0 y mostrar indicador "Completa tu perfil".
6. **Weight trend**: stable si diferencia < 0.3kg, up si >= +0.3, down si <= -0.3.
7. **Weekly average**: solo incluye dias con al menos 1 FoodLog (no promediar dias sin registro).

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| TDEE recalcular | Parece que hay que recalcular TDEE cada request | TDEE esta en HealthProfile — no recalcular |
| caloriesBurned exacto | Parece dato preciso | Es ESTIMACION cuando no viene de wearable — siempre mostrar con "~" |
| nutritionTarget duplicado | Parece que hay que crear nueva logica | Ya existe en dashboard — reutilizar getNutritionTarget() |
| Balance = calorias | Parece kcal exactas | Son estimaciones — no presentar como dato medico |
| computeFoodTotals null | Parece 0 | computeFoodTotals retorna null si no hay logs — la route hace ?? { kcal: 0, ... } |
| R5 intensity dead code | nutricion.md dice que targets no varian por intensidad | FALSO — getDailyNutritionTarget SI ajusta (HIGH/MODERATE/REST). R5 aplica solo al hardcode de gym=MODERATE, NO a sesiones de plan |
| GymSession vs SessionLog calories | Parece el mismo dato | GymSession.caloriesBurned es estimado (durationMin x avgCalPerMin). SessionLog.caloriesBurned es de wearable. Sumar ambos si hay sesion de plan + gym el mismo dia |

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Balance energetico diario | GET /api/athlete/energy-balance | GET /api/mobile/energy-balance |
| Resumen semanal | NO (web usa SSR directo) | GET /api/mobile/energy-balance/weekly |
| Anillo de calorias (UI) | Componente React en dashboard web | Componente React Native en home |
| Barras de macros (UI) | Ya existe en NutritionProgressCard | Componente React Native |
| Widget peso con tendencia | Componente en /progress | Inline en balance screen |

## Tests requeridos

- [ ] GET energy-balance sin HealthProfile → tdeeBase: 0
- [ ] GET energy-balance sin FoodLog → consumed: 0, macros all 0
- [ ] GET energy-balance con sesion gym 45min → exerciseCalories estimado con MET
- [ ] GET energy-balance con sesion wearable (caloriesBurned: 320) → usa dato real, no estima
- [ ] GET energy-balance balance calculo: budget - consumed correcto
- [ ] GET weekly: promedio excluye dias sin FoodLog
- [ ] GET weekly: weightChange = ultimo peso - primer peso de la semana
- [ ] Auth: sin sesion → 401
- [ ] Weight trend: diferencia < 0.3 → stable

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — balance energetico unificado |
