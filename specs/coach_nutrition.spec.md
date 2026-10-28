# COACH-NUT — Coach Nutrition

<!-- mirror: false -->
<!-- note: coach es web-only. Todos los endpoints usan auth() COACH. Sin paridad mobile. -->

> Spec extraida de los requisitos de diseno. Ultima actualizacion: 2026-10-02.
> Fuente canonica: esta spec refleja el comportamiento ESPERADO del codigo (spec de implementacion).
> Specs relacionadas: `nutrition.spec.md`, `plan.spec.md`, `coach_athletes.spec.md`

## TL;DR

- 20 endpoints (20 web, 0 mobile)
- Modelos: NutritionPlan, NutritionTemplate, NutritionTemplateDay, NutritionTemplateMeal, NutritionTemplateFoodItem, AssignedNutritionPlan, PlannedMeal, CoachNutritionProposal, MealPlan (DEPRECATED)
- Dependencias: `auth()`, `floorZero()`, Zod 4
- Trampas criticas: PATCH /nutrition vs PATCH /targets son rutas distintas con semantica distinta; apply-template es destructivo; MealPlan esta deprecated; template DELETE bloqueado con asignaciones activas (409)
- Mirror mobile: ninguno — web-only

---

## Contratos de la AI

<!-- Lo que la AI DEBE saber antes de tocar este modulo. Si no lees esto, alucinaras. -->

- [ ] PATCH `/api/coach/athletes/[id]/nutrition` y PATCH `/api/coach/athletes/[id]/nutrition/targets` son endpoints DISTINTOS. El primero acepta `tdee/targetKcalHard/Easy/Rest/proteinG/carbsHardG/carbsEasyG/fatG` sin Zod, hace upsert con `source: COACH`. El segundo acepta `targetKcalHard/Easy/Rest/proteinG/kcalAdjustment` con Zod, hace update con recalculo TDEE+macros.
- [ ] `AssignedNutritionPlan` (athleteId UNIQUE) y `TrainingPlan.nutritionTemplateId` son dos referencias independientes. No confundirlas.
- [ ] POST `/api/coach/nutrition/templates` precrea automaticamente 3 dias (HARD, EASY, REST) en la misma transaccion. No hay endpoint separado para crear dias individuales.
- [ ] POST `/api/coach/athletes/[id]/nutrition/apply-template` es DESTRUCTIVO: hace `deleteMany` de PlannedMeals existentes de la semana antes del `createMany`. Operacion irreversible sin backup.
- [ ] `CoachNutritionProposal` es un delta (`deltaKcal`, `deltaProtein`, `deltaCarbs`, `deltaFat`), no un set absoluto. Al aceptar, se aplica `floorZero()` para evitar macros negativas.
- [ ] PATCH `/api/coach/athletes/[id]/nutrition/meals` esta DEPRECATED (NUT-12). No usarlo para logica nueva.
- [ ] DELETE `/api/coach/nutrition/templates/[templateId]` retorna 409 (no 200 ni 400) si el template tiene atletas asignados. Verificar `_count.assignments` antes de eliminar.
- [ ] Un atleta tiene maximo UNA asignacion nutricional activa. POST `/assign` usa `upsert` por `athleteId`, no `insert`.
- [ ] Todos los endpoints tienen rate limiting propio via `rateLimitAsync`. GETs: 300/min, writes: 60/min, operaciones sensibles (propose, assign, apply-template): 30/min.
- [ ] Todos los endpoints de atleta verifican que el atleta [id] pertenece al coach autenticado (ownership check) antes de operar.

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/coach/athletes/[id]/nutrition` | `auth()` COACH | 300/min | Dashboard nutricional del atleta |
| PATCH | `/api/coach/athletes/[id]/nutrition` | `auth()` COACH | 60/min | Upsert NutritionPlan targets directos (sin Zod, source COACH) |
| PATCH | `/api/coach/athletes/[id]/nutrition/targets` | `auth()` COACH | 60/min | Update targets con Zod + recalculo TDEE/macros |
| GET | `/api/coach/athletes/[id]/nutrition/plan` | `auth()` COACH | 300/min | Meals de una semana (?week=YYYY-MM-DD) |
| POST | `/api/coach/athletes/[id]/nutrition/plan` | `auth()` COACH | 60/min | Crear PlannedMeal para atleta |
| DELETE | `/api/coach/athletes/[id]/nutrition/plan/[mealId]` | `auth()` COACH | 60/min | Borrar PlannedMeal |
| PATCH | `/api/coach/athletes/[id]/nutrition/meals` | `auth()` COACH | 60/min | DEPRECATED NUT-12. JSON blob en MealPlan |
| POST | `/api/coach/athletes/[id]/nutrition/propose` | `auth()` COACH | 30/min | Crear CoachNutritionProposal (delta, status PENDING) |
| GET | `/api/coach/athletes/[id]/nutrition/adherence` | `auth()` COACH | 300/min | Adherencia nutricional 28 dias |
| POST | `/api/coach/athletes/[id]/nutrition/apply-template` | `auth()` COACH | 30/min | Aplica template asignado a semana (DESTRUCTIVO) |
| PATCH | `/api/coach/athletes/[id]/plan/nutrition-template` | `auth()` COACH | ninguno | Vincula/desvincula NutritionTemplate al TrainingPlan activo |
| GET | `/api/coach/nutrition/templates` | `auth()` COACH | 300/min | Lista templates con `_count.assignments` |
| POST | `/api/coach/nutrition/templates` | `auth()` COACH | 60/min | Crear template (precrea 3 dias: HARD/EASY/REST) |
| GET | `/api/coach/nutrition/templates/[templateId]` | `auth()` COACH | 300/min | Detalle completo del template |
| PATCH | `/api/coach/nutrition/templates/[templateId]` | `auth()` COACH | 60/min | Update metadata del template |
| DELETE | `/api/coach/nutrition/templates/[templateId]` | `auth()` COACH | 60/min | Borrar template (guard: 409 si tiene asignados) |
| POST | `/api/coach/nutrition/templates/[templateId]/meals` | `auth()` COACH | 60/min | Agregar food item con snapshot macros |
| DELETE | `/api/coach/nutrition/templates/[templateId]/meals` | `auth()` COACH | 60/min | Borrar food item. Body: `{ itemId }` |
| POST | `/api/coach/nutrition/templates/[templateId]/assign` | `auth()` COACH | 30/min | Asignar template a atleta (upsert por athleteId) |
| DELETE | `/api/coach/nutrition/templates/[templateId]/assign` | `auth()` COACH | 30/min | Desasignar template de atleta. Body: `{ athleteId }` |

---

## Detalle de endpoints

### `GET /api/coach/athletes/[id]/nutrition`

**Request:**
```ts
// Path params
{ id: string } // athleteId
```

**Response:**
```ts
{
  foodLogs: FoodLog[]
  mealPlan: MealPlan | null    // DEPRECATED — presente por retrocompatibilidad
  foodProfile: FoodProfile | null
  assignedNutritionPlan: (AssignedNutritionPlan & {
    template: NutritionTemplate & {
      templateTotals: { kcal: number; protein: number; carbs: number; fat: number }
    }
  }) | null
}
```

**Logica:**
1. Verificar sesion COACH con `auth()`
2. Verificar que atleta [id] pertenece al coach (ownership check)
3. `Promise.all` de 4 queries independientes:
   - `foodLogs` — 7 dias hacia atras desde hoy
   - `mealPlan` — registro actual (puede ser null si ya migrado)
   - `foodProfile` — perfil nutricional del atleta
   - `assignedNutritionPlan` — con include del template y calculo de `templateTotals`
4. Retornar objeto compuesto con los 4 resultados

---

### `PATCH /api/coach/athletes/[id]/nutrition`

**Request:**
```ts
// Body — sin validacion Zod, se parsean campos validos de una lista fija
{
  tdee?: number
  targetKcalHard?: number
  targetKcalEasy?: number
  targetKcalRest?: number
  proteinG?: number
  carbsHardG?: number
  carbsEasyG?: number
  fatG?: number
}
```

**Response:**
```ts
{ ok: true, plan: NutritionPlan }
```

**Logica:**
1. Verificar sesion COACH + ownership del atleta (status ACTIVE)
2. Filtrar body a campos validos (`tdee, targetKcalHard, targetKcalEasy, targetKcalRest, proteinG, carbsHardG, carbsEasyG, fatG`), redondear a entero, descartar NaN y <= 0
3. Si ningun campo valido -> 400
4. `upsert` en `NutritionPlan` por `userId` con `source: 'COACH'` (create usa defaults: tdee 2000, targetKcalHard 2200, targetKcalEasy 1800, targetKcalRest 1600, proteinG 120, carbsHardG 250, carbsEasyG 200, fatG 80)
5. Retornar `{ ok: true, plan }` con el plan upsertado

---

### `PATCH /api/coach/athletes/[id]/nutrition/targets`

**Request:**
```ts
// Body — validado con Zod
{
  targetKcalHard?: number    // int, rango: 500..10000
  targetKcalEasy?: number    // int, rango: 500..10000
  targetKcalRest?: number    // int, rango: 500..10000
  proteinG?: number          // int, rango: 30..500
  kcalAdjustment?: number    // int, rango: KCAL_ADJUSTMENT_MIN..KCAL_ADJUSTMENT_MAX
}
```

**Response:**
```ts
{ targetKcalHard: number, targetKcalEasy: number, targetKcalRest: number, proteinG: number, kcalAdjustment: number | null, source: string }
```

**Logica:**
1. Verificar sesion COACH + ownership del atleta (status ACTIVE)
2. Validar body con Zod (targetKcalHard/Easy/Rest 500-10000, proteinG 30-500, kcalAdjustment rango configurable)
3. Si body vacio -> 400
4. **Rama A** — si `kcalAdjustment` presente:
   - Leer `HealthProfile` del atleta (weightKg, heightCm, age, gender)
   - Si perfil incompleto -> 422
   - Calcular TDEE con `calculateTDEE()` + macros con `calculateMacros()`
   - `update` en `NutritionPlan` con todos los macros recalculados (hard/easy/rest) + `source: COACH`
5. **Rama B** — si campos manuales:
   - Leer plan actual (targetKcalHard, proteinG, carbsHardG) — si no existe -> 404
   - Calcular `fatG` residual: `max(round((finalKcal - finalProtein*4 - finalCarbs*4) / 9), 0)`
   - `update` en `NutritionPlan` con los campos + fatG + `source: COACH`
6. Retornar select parcial: `{ targetKcalHard, targetKcalEasy, targetKcalRest, proteinG, kcalAdjustment, source }`

---

### `GET /api/coach/athletes/[id]/nutrition/plan`

**Request:**
```ts
// Query params
{ week?: string } // YYYY-MM-DD (lunes de la semana). Default: semana actual
```

**Response:**
```ts
PlannedMeal[] // con include de food y overrides
```

**Logica:**
1. Verificar sesion COACH + ownership
2. Parsear `week` query param, calcular rango [startOfWeek, endOfWeek]
3. Query `PlannedMeal` con `include: { food: true, overrides: true }` filtrado por `athleteId` + rango de fechas
4. Retornar array

---

### `POST /api/coach/athletes/[id]/nutrition/plan`

**Request:**
```ts
{
  date: string      // ISO date (YYYY-MM-DD)
  mealType: string  // MealType enum
  foodId: string
  grams: number     // > 0
}
```

**Response:**
```ts
{ meal: PlannedMeal & { food: FoodSelect } }  // status 201
```

**Logica:**
1. Verificar sesion COACH + ownership (status ACTIVE)
2. Validar campos requeridos: `date`, `mealType`, `foodId`, `grams` — 400 si falta alguno
3. Validar `mealType` contra enum `MealType` — 400 si invalido
4. Validar `grams` > 0 — 400 si invalido
5. Verificar que el food existe y esta activo (`isActive: true`) — 404 si no
6. Crear `PlannedMeal` con include de food
7. Retornar `{ meal }` con status 201

---

### `DELETE /api/coach/athletes/[id]/nutrition/plan/[mealId]`

**Request:**
```ts
// Path params
{ id: string; mealId: string }
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar sesion COACH + ownership del atleta (status ACTIVE)
2. Verificar que `PlannedMeal.userId === athleteId` — 404 si no existe
3. `delete` en `PlannedMeal`
4. Retornar `{ ok: true }`

---

### `PATCH /api/coach/athletes/[id]/nutrition/meals` (DEPRECATED NUT-12)

**Request:**
```ts
{
  hard: unknown    // requerido
  easy: unknown    // requerido
  rest: unknown    // requerido
  low?: unknown    // opcional
}
```

**Response:**
```ts
{ ok: true, mealPlanId: string }
```

**Logica:**
1. Verificar sesion COACH + ownership (status ACTIVE)
2. Validar que `hard`, `easy`, `rest` esten presentes — 400 si falta alguno
3. `upsert` en `MealPlan` con el body completo en campo `data` (JSON)
4. Retornar `{ ok: true, mealPlanId }`
5. **NO usar para logica nueva.** Existe por retrocompatibilidad.

---

### `POST /api/coach/athletes/[id]/nutrition/propose`

**Request:**
```ts
// Validado con Zod
{
  message: string        // 10..300 chars
  deltaKcal: number      // integer
  deltaProtein?: number  // default 0
  deltaCarbs?: number    // default 0
  deltaFat?: number      // default 0
}
```

**Response:**
```ts
CoachNutritionProposal
```

**Logica:**
1. Verificar sesion COACH + ownership
2. Validar body con Zod
3. Crear `CoachNutritionProposal` con `status: 'PENDING'`, `coachId`, `athleteId`, y los deltas
4. Retornar la propuesta creada
5. El atleta acepta/rechaza desde su propia interfaz — este endpoint solo crea la propuesta

---

### `GET /api/coach/athletes/[id]/nutrition/adherence`

**Request:**
```ts
// Sin params adicionales. Ventana fija: 28 dias atras desde hoy
```

**Response:**
```ts
{
  days: {
    date: string
    kcalLogged: number
    targetKcal: number | null   // null si no hay plan/template
    adherencePct: number | null // null si no hay target, max 999
  }[]
  targetKcal: number | null    // targetKcalEasy del plan efectivo
}
```

**Logica:**
1. Verificar sesion COACH + ownership (status ACTIVE)
2. Calcular rango de 28 dias hacia atras
3. 4 queries en paralelo: `foodLogs`, `nutritionPlan`, `assignedNutritionPlan` (con template items), `intensityMap`
4. Determinar targets efectivos: primero `NutritionPlan` directo, si no existe sintetiza desde template asignado (`synthesizeTargetsFromTemplate`)
5. Agrupar kcal por dia, calcular adherencePct por dia usando `getDailyNutritionTarget(intensity)` para cada fecha
6. Retornar `{ days, targetKcal }` donde `targetKcal` es el `targetKcalEasy` del plan efectivo

---

### `POST /api/coach/athletes/[id]/nutrition/apply-template`

**Request:**
```ts
// Validado con Zod
{
  weekStartDate: string  // YYYY-MM-DD (formato validado con regex)
}
```

**Response:**
```ts
{ ok: true, created: number, weekStart: string }
```

**Logica:**
1. Verificar sesion COACH + ownership (status ACTIVE)
2. Validar body con Zod (`weekStartDate` regex `^\d{4}-\d{2}-\d{2}$`) — 400 si invalido
3. 2 reads en paralelo: `AssignedNutritionPlan` con template completo (days + meals + items), `intensityMap` para el rango de la semana
4. Si no hay template asignado -> **404** (no 400)
5. Para cada dia de la semana: determinar dayType via intensityMap -> intensityToDayType, mapear meals del template day correspondiente
6. **DENTRO de `$transaction`**:
   a. `deleteMany` PlannedMeal del atleta para esa semana **(DESTRUCTIVO)**
   b. `createMany` PlannedMeal con los datos del template (userId, date, mealType, foodId, grams)
7. Retornar `{ ok: true, created: count, weekStart }`

---

### `PATCH /api/coach/athletes/[id]/plan/nutrition-template`

**Request:**
```ts
// Validado con Zod
{
  nutritionTemplateId: string | null  // null para desvincular
}
```

**Response:**
```ts
TrainingPlan
```

**Logica:**
1. Verificar sesion COACH + ownership
2. Buscar `TrainingPlan` activo del atleta (status ACTIVE)
3. Si no hay plan activo -> 404
4. `update` en `TrainingPlan` con `nutritionTemplateId` (puede ser `null`)
5. Retornar el plan actualizado

---

### `GET /api/coach/nutrition/templates`

**Request:**
```ts
// Sin params — lista templates del coach autenticado
```

**Response:**
```ts
{ templates: (NutritionTemplate & { days: NutritionTemplateDayFull[], _count: { assignments: number } })[] }
```

**Logica:**
1. Verificar sesion COACH
2. Query `NutritionTemplate` donde `coachId === session.user.id`
3. Include `_count: { select: { assignments: true } }`
4. Retornar array

---

### `POST /api/coach/nutrition/templates`

**Request:**
```ts
{
  name: string
  description?: string
  goal?: string
}
```

**Response:**
```ts
{ template: NutritionTemplate & { days: (NutritionTemplateDay & { meals: (NutritionTemplateMeal & { items: NutritionTemplateFoodItem[] })[] })[] } }
// status 201
```

**Logica:**
1. Verificar sesion COACH
2. Crear `NutritionTemplate` con `coachId` y nested create de 3 `NutritionTemplateDay` (`HARD`, `EASY`, `REST`) en una sola operacion (no $transaction explicito — Prisma nested create)
3. Constraint UNIQUE `(templateId, dayType)` garantiza no duplicados
4. Retornar `{ template }` con status 201

---

### `GET /api/coach/nutrition/templates/[templateId]`

**Request:**
```ts
// Path params
{ templateId: string }
```

**Response:**
```ts
{
  template: NutritionTemplate & {
    days: (NutritionTemplateDay & {
      meals: (NutritionTemplateMeal & {
        items: (NutritionTemplateFoodItem & {
          food: { id, name, category, kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g }
        })[]
      })[]
    })[]
    _count: { assignments: number }
  }
}
```

**Logica:**
1. Verificar sesion COACH
2. Query `NutritionTemplate` por `templateId` donde `coachId === session.user.id`
3. Include completo: days (orderBy dayType asc) -> meals (orderBy order asc) -> items (orderBy order asc, include food select)
4. Si no existe o no pertenece al coach -> 404
5. Retornar `{ template }` con detalle completo

---

### `PATCH /api/coach/nutrition/templates/[templateId]`

**Request:**
```ts
{
  name?: string       // se aplica trim(), solo si no vacio tras trim
  description?: string  // se aplica trim(), null si vacio
  goal?: string         // se aplica trim(), null si vacio
}
```

**Response:**
```ts
{ template: NutritionTemplate }
```

**Logica:**
1. Verificar sesion COACH + ownership del template (404 si no existe/no pertenece)
2. `update` en `NutritionTemplate`: `name` solo se actualiza si truthy tras trim, `description`/`goal` se ponen null si vacios
3. Retornar `{ template }` con el template actualizado

---

### `DELETE /api/coach/nutrition/templates/[templateId]`

**Request:**
```ts
// Path params
{ templateId: string }
```

**Response:**
```ts
{ ok: true }
// o 409 si tiene asignaciones activas
```

**Logica:**
1. Verificar sesion COACH + ownership del template (404 si no existe/no pertenece)
2. Contar `AssignedNutritionPlan` donde `templateId === templateId`
3. Si `count > 0` -> retornar **409** `{ error: 'No se puede eliminar: el template tiene atletas asignados.' }`
4. `delete` en `NutritionTemplate` (cascade a days, meals, items)
5. Retornar `{ ok: true }`

---

### `POST /api/coach/nutrition/templates/[templateId]/meals`

**Request:**
```ts
{
  dayType: string    // NutritionDayType: HARD | EASY | REST (case-insensitive, se normaliza a uppercase)
  mealType: string   // MealType: BREAKFAST | LUNCH | DINNER | SNACK | PRE_WORKOUT | POST_WORKOUT (case-insensitive)
  foodId: string
  grams: number      // > 0
}
```

**Response:**
```ts
{ item: NutritionTemplateFoodItem & { food: { id, name, category } } }  // status 201
```

**Logica:**
1. Verificar sesion COACH + ownership del template (404 si no existe/no pertenece)
2. Validar `dayType` contra VALID_DAY_TYPES — 400 si invalido
3. Validar `mealType` contra VALID_MEAL_TYPES — 400 si invalido
4. Validar `foodId` y `grams > 0` — 400 si faltan o invalidos
5. Buscar `Food` por `foodId` — 404 si no existe
6. Buscar dia del template por `dayType` — 404 si no existe
7. Calcular snapshot de macros: `factor = grams / 100`, macros = `food.{kcal,protein,carbs,fat}Per100g * factor` redondeado a 1 decimal
8. **DENTRO de `$transaction`**:
   a. `upsert` `NutritionTemplateMeal` por `(dayId, mealType)` (UNIQUE)
   b. Contar items existentes para determinar `order`
   c. Crear `NutritionTemplateFoodItem` con snapshot: `grams, kcal, proteinG, carbsG, fatG, order`
9. Retornar `{ item }` con include food, status 201

---

### `DELETE /api/coach/nutrition/templates/[templateId]/meals`

**Request:**
```ts
// Body
{ itemId: string }
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar sesion COACH
2. **Paso 1 — ownership check (2 queries en cadena)**:
   a. Buscar `NutritionTemplateFoodItem` por `itemId` con include `meal.day.template`
   b. Si no existe -> **404**
   c. Si `template.coachId !== session.user.id` -> **403**
3. `delete` en `NutritionTemplateFoodItem`
4. Retornar `{ success: true }`

---

### `POST /api/coach/nutrition/templates/[templateId]/assign`

**Request:**
```ts
{
  athleteId: string
}
```

**Response:**
```ts
{ assignment: AssignedNutritionPlan & { athlete: { id, name, email } } }  // status 201
```

**Logica:**
1. Verificar sesion COACH + ownership del template (404 si no existe/no pertenece)
2. Verificar `athleteId` en body — 400 si falta
3. Verificar relacion `coachAthlete` activa — 404 si no existe
4. `upsert` en `AssignedNutritionPlan` por `athleteId` (UNIQUE):
   - `create`: `{ templateId, athleteId, coachId }`
   - `update`: `{ templateId, coachId, assignedAt: new Date() }` (reemplaza asignacion anterior)
5. Include `athlete: { select: { id, name, email } }`
6. Retornar `{ assignment }` con status 201

---

### `DELETE /api/coach/nutrition/templates/[templateId]/assign`

**Request:**
```ts
// Body
{ athleteId: string }
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. Verificar sesion COACH
2. Verificar `athleteId` en body — 400 si falta
3. Buscar `AssignedNutritionPlan` donde `{ athleteId, templateId, coachId }` — 404 si no existe
4. `delete` en `AssignedNutritionPlan` donde `{ athleteId }`
5. Retornar `{ ok: true }`

---

## Modelos DB involucrados

```prisma
model NutritionPlan {
  id              String          @id @default(cuid())
  userId          String          @unique  // 1 plan por usuario
  source          NutritionSource // SYSTEM | COACH | ATHLETE
  tdee            Float           @default(2000)
  targetKcalHard  Float           @default(2200)
  targetKcalEasy  Float           @default(1800)
  targetKcalRest  Float           @default(1600)
  proteinG        Float           @default(120)
  carbsHardG      Float           @default(250)
  carbsEasyG      Float           @default(200)
  fatG            Float           @default(80)
  kcalAdjustment  Float?          // delta sobre TDEE
  waterMlTarget   Int?
  createdAt       DateTime        @default(now())
  updatedAt       DateTime        @updatedAt
}

enum NutritionSource {
  SYSTEM
  COACH
  ATHLETE
}

model NutritionTemplate {
  id          String                  @id @default(cuid())
  coachId     String
  name        String
  description String?
  goal        String?
  days        NutritionTemplateDay[]
  assignments AssignedNutritionPlan[]
  createdAt   DateTime                @default(now())
  updatedAt   DateTime                @updatedAt
}

model NutritionTemplateDay {
  id         String                  @id @default(cuid())
  templateId String
  dayType    DayType                 // HARD | EASY | REST
  meals      NutritionTemplateMeal[]
  template   NutritionTemplate       @relation(fields: [templateId], references: [id])

  @@unique([templateId, dayType])
}

model NutritionTemplateMeal {
  id       String                    @id @default(cuid())
  dayId    String
  mealType MealType
  order    Int                       @default(0)
  items    NutritionTemplateFoodItem[]
  day      NutritionTemplateDay      @relation(fields: [dayId], references: [id])

  @@unique([dayId, mealType])
}

model NutritionTemplateFoodItem {
  id       String                @id @default(cuid())
  mealId   String
  foodId   String
  grams    Float
  order    Int                   @default(0)
  // snapshot de macros al momento de agregar:
  kcal     Float
  proteinG Float
  carbsG   Float
  fatG     Float
  meal     NutritionTemplateMeal @relation(fields: [mealId], references: [id])
  food     Food                  @relation(fields: [foodId], references: [id])
}

model AssignedNutritionPlan {
  id         String            @id @default(cuid())
  athleteId  String            @unique  // max 1 asignacion activa por atleta
  templateId String
  coachId    String
  assignedAt DateTime          @default(now())
  template   NutritionTemplate @relation(fields: [templateId], references: [id])
  athlete    User              @relation(fields: [athleteId], references: [id])
  coach      User              @relation(fields: [coachId], references: [id])
}

model PlannedMeal {
  id        String    @id @default(cuid())
  userId    String
  foodId    String
  mealType  MealType
  date      DateTime
  grams     Float
  food      Food      @relation(fields: [foodId], references: [id])
  overrides PlannedMealOverride[]
  createdAt DateTime  @default(now())
}

model CoachNutritionProposal {
  id           String         @id @default(cuid())
  athleteId    String
  coachId      String
  message      String         // 10..300 chars
  deltaKcal    Int
  deltaProtein Int            @default(0)
  deltaCarbs   Int            @default(0)
  deltaFat     Int            @default(0)
  status       ProposalStatus // PENDING | ACCEPTED | REJECTED
  createdAt    DateTime       @default(now())
  updatedAt    DateTime       @updatedAt
}

enum ProposalStatus {
  PENDING
  ACCEPTED
  REJECTED
}

// DEPRECATED NUT-12
model MealPlan {
  id        String   @id @default(cuid())
  userId    String   @unique
  data      Json     // blob arbitrario (hard/easy/rest)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

---

## Reglas de negocio (invariantes)

1. **R01 — Dos rutas para targets**: `/nutrition` es `upsert` sin Zod con `source: COACH` y campos `tdee/targetKcalHard/Easy/Rest/proteinG/carbsHardG/carbsEasyG/fatG`. `/targets` es `update` con Zod estricto (`targetKcalHard/Easy/Rest/proteinG/kcalAdjustment`) y logica de recalculo. No son intercambiables.
2. **R02 — AssignedNutritionPlan vs TrainingPlan.nutritionTemplateId**: Son referencias independientes. `AssignedNutritionPlan` controla que template recibe el atleta en su app. `TrainingPlan.nutritionTemplateId` es la vinculacion a nivel de plan de entrenamiento.
3. **R03 — apply-template es destructivo**: `deleteMany` de meals existentes de la semana antes de `createMany`. No hay rollback logico — si el coach lo ejecuta, las meals manuales se pierden.
4. **R04 — Propuesta es delta, no absoluto**: `CoachNutritionProposal` almacena deltas. Al aceptar, se suma al plan actual y se aplica `floorZero()` — ninguna macro puede quedar < 0.
5. **R05 — MealPlan deprecated NUT-12**: El modelo `MealPlan` y su endpoint PATCH existen solo por retrocompatibilidad. No agregar logica nueva sobre este modelo.
6. **R06 — Template delete bloqueado**: Si `AssignedNutritionPlan` tiene registros con ese `templateId`, el DELETE retorna **409**. El coach debe desasignar a todos los atletas antes de borrar.
7. **R07 — Un atleta = max una asignacion activa**: `AssignedNutritionPlan.athleteId` tiene constraint UNIQUE. POST `/assign` usa `upsert` — si el atleta ya tiene una asignacion, se reemplaza.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| PATCH `/nutrition` vs PATCH `/targets` | Dos endpoints que actualizan el mismo modelo | Semantica completamente diferente: `upsert` sin validacion vs `update` con Zod + recalculo TDEE |
| `apply-template` "aplica" el template | Operacion aditiva/merge | DESTRUCTIVO: borra todas las meals de esa semana antes de crear las nuevas |
| DELETE `/templates/[id]/meals` borra una `NutritionTemplateMeal` | El endpoint se llama `meals` | Borra un `NutritionTemplateFoodItem`. La meal container no se toca. |
| Ownership check en DELETE `/meals` | Un solo query basta | Requiere 2 queries en cadena: primero buscar el item con includes, luego validar coachId del template. 404 si no existe, 403 si pertenece a otro coach. |
| POST `/templates` puede agregar dias despues | Los dias son editables post-creacion | Los 3 dias (HARD/EASY/REST) se crean automaticamente en la misma tx. No hay endpoint para crear dias individuales. |
| `AssignedNutritionPlan` == `TrainingPlan.nutritionTemplateId` | Son la misma referencia | Son dos campos independientes con propositos distintos |
| Rate limiting uniforme | Todos tienen el mismo rate limit | GETs: 300/min, writes: 60/min, sensibles (propose, assign, apply-template): 30/min |
| Propuesta ACCEPTED actualiza el plan inmediatamente desde el coach | El coach acepta en su panel | El coach CREA la propuesta. El ATLETA acepta/rechaza. El calculo `floorZero()` ocurre al aceptar en el lado atleta. |
| NutritionBuilder builderError | `setBuilderError('msg')` muestra error | Si `builderError` no tiene elemento JSX de renderizado, el error se setea pero el usuario no lo ve. Ver T25 en `_traps.spec.md`. |
| NutritionBuilder activeDay | Siempre hay un activeDay seleccionado | Requiere fallback safety: si `activeDay` es undefined (ej. dias no cargados aun), el builder no debe crashear. |
| templates PATCH/POST req.json() | El body siempre es JSON valido | Debe usar `req.json().catch(() => null)` — body vacio o malformado causa 500 sin el catch. Ver T18 en `_traps.spec.md`. |
| Template DELETE con asignaciones -> 400 o 404 | El template existe pero no se puede borrar | Retorna **409** — el template existe pero esta bloqueado por tener atletas asignados. |

---

## Paridad web <-> mobile

Este modulo es web-only. No tiene endpoints espejo en `/api/mobile/*`.

El atleta interactua con los resultados (ver propuestas, aceptar/rechazar, ver plan nutricional asignado) desde endpoints propios del atleta, no desde este modulo de coach.

---

## Tests requeridos

- [ ] GET `/nutrition` retorna los 4 campos del `Promise.all` correctamente
- [ ] PATCH `/nutrition` hace `upsert` con `source: COACH` (no falla si no existe el plan)
- [ ] PATCH `/targets` rama A: `kcalAdjustment` recalcula TDEE + macros
- [ ] PATCH `/targets` rama B: campos manuales + fat residual correcto
- [ ] PATCH `/targets` rechaza `kcal` fuera de rango (< 500 o > 10000)
- [ ] PATCH `/targets` rechaza `kcalAdjustment` fuera de rango (< -750 o > 500)
- [ ] POST `/templates` precrea exactamente 3 dias (HARD, EASY, REST)
- [ ] DELETE `/templates/[id]` retorna **409** si hay asignaciones activas
- [ ] DELETE `/templates/[id]` retorna 200 si no hay asignaciones
- [ ] POST `/assign` hace `upsert` (no crea duplicado si athleteId ya tiene asignacion)
- [ ] POST `/apply-template` elimina meals existentes de la semana antes de crear nuevas
- [ ] POST `/apply-template` retorna 400 si el atleta no tiene template asignado
- [ ] DELETE `/templates/[id]/meals` retorna 404 si `itemId` no existe
- [ ] DELETE `/templates/[id]/meals` retorna 403 si el item pertenece a otro coach
- [ ] POST `/propose` rechaza `message` < 10 chars
- [ ] POST `/propose` rechaza `message` > 300 chars
- [ ] GET `/adherence` retorna 28 dias con `adherencePercent` por dia
- [ ] Todos los endpoints retornan 401 si no hay sesion
- [ ] Todos los endpoints de atleta retornan 403 si el atleta no pertenece al coach
- [ ] Todos los endpoints de template retornan 404 si el template no pertenece al coach

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-01 | Spec creada (auditoria P0.3) | Extraida del codigo |
| 2026-10-02 | Reescritura completa con 20 endpoints, modelos completos, reglas R01-R07, trampas detalladas, tests exhaustivos | Requisitos de diseno |
| 2026-10-05 | Fix body schemas: PATCH /nutrition usa tdee/targetKcalHard/Easy/Rest/proteinG/carbsHardG/carbsEasyG/fatG; PATCH /targets usa targetKcalHard/Easy/Rest/proteinG/kcalAdjustment; POST /meals usa dayType+grams; apply-template usa weekStartDate; POST /plan usa date+grams. Rate limits documentados en todos los endpoints. Modelos DB corregidos (NutritionPlan, NutritionTemplateFoodItem, PlannedMeal, AssignedNutritionPlan, MealPlan). Response wrappers corregidos. | Auditoria vs codigo real |
| 2026-10-09 | Auditoria pre-prod: NutritionBuilder builderError renderizado obligatorio, activeDay fallback safety, templates PATCH/POST req.json().catch | 8 rondas de auditoria |
