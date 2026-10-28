# COACH-GYM — Coach Gym Module

<!-- mirror: false -->
<!-- mirror-endpoints: N/A -->
<!-- note: coach es web-only. Atleta consume rutinas asignadas via /api/mobile/gym/* (ver gym.spec.md) -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-02.
> Fuente canonica: esta spec refleja el comportamiento ACTUAL del codigo, no el deseado.
> Specs relacionadas: `gym.spec.md` (atleta), `coach_athletes.spec.md` (ownership), `_traps.spec.md`

## TL;DR

- 17 endpoints (17 web, 0 mobile) — auth() COACH, todos con rate limiting (GETs: 300/min, writes: 60/min, sensibles: 30/min)
- Modelos: WorkoutTemplate, WorkoutDay, WorkoutExercise, AssignedWorkout, Exercise
- Dependencias: `createRoutine()`, `validateExercise()`, formula Brzycki (PRs)
- Trampas criticas: `supersetWith` en DB es ID de WorkoutExercise no exerciseId; PATCH replace invalida SetLog; POST /assign desactiva TODAS las rutinas activas; DELETE /assign solo desactiva las del template especifico
- Mirror mobile: no aplica — modulo exclusivo coach web

---

## Contratos de la AI

<!-- Lo que la AI DEBE saber antes de tocar este modulo. Si no lees esto, alucinaras. -->

- [ ] `supersetWith` en DB es el **ID de WorkoutExercise** (cuid), NO el `exerciseId` del catalogo de ejercicios
- [ ] `supersetWithOrder` en el body del request es el **order numerico del ejercicio par** — se usa para resolver el ID en tx, no se persiste directamente
- [ ] `dayOfWeek` es **0-6 (convencion JS)** — diferente al dominio 1-7 que usan otros modulos
- [ ] **POST /assign desactiva TODAS las asignaciones activas del atleta**, sin importar a que template pertenecen; DELETE /assign solo desactiva las del template especifico en el path
- [ ] **PATCH es replace total**: borra todos los `WorkoutDay` (cascade a `WorkoutExercise`) y los recrea. Todos los `WorkoutExercise.id` cambian. `SetLog.workoutExerciseId` queda null (onDelete: SetNull)
- [ ] Ejercicios accesibles = globales (`coachId IS NULL`) + propios del coach (`coachId = session.coachId`)
- [ ] Superset resolution difiere segun operacion: POST/PATCH mapea `supersetWithOrder -> ID en tx`; COPY mapea `ID source -> order -> nuevo ID`
- [ ] `GET /exercises/[id]` tiene ownership check: solo globales (coachId null) o propios del coach (coachId match) — 404 para custom de otros coaches
- [ ] Ownership en `/athlete/[id]/*` acepta relaciones `coachAthlete` en cualquier status (incluyendo inactivas), EXCEPTO POST /assign que exige status ACTIVE
- [ ] Volume analytics excluye sets `WARMUP`; incluye `DROPSET`. PR analytics usa solo `SetLog` con `isPR = true`

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/coach/gym/routines` | `auth()` COACH | 300/min | Lista templates del coach (take: 100, sin paginacion) |
| POST | `/api/coach/gym/routines` | `auth()` COACH | 60/min | Crear template con dias y ejercicios |
| GET | `/api/coach/gym/routines/[id]` | `auth()` COACH | 300/min | Detalle template (ownership por coachId) |
| PATCH | `/api/coach/gym/routines/[id]` | `auth()` COACH | 60/min | Update template — replace total de dias |
| POST | `/api/coach/gym/routines/[id]/copy` | `auth()` COACH | 60/min | Deep copy del template |
| POST | `/api/coach/gym/routines/[id]/assign` | `auth()` COACH | 30/min | Asignar rutina a atleta (desactiva todas las previas) |
| DELETE | `/api/coach/gym/routines/[id]/assign` | `auth()` COACH | 30/min | Desactivar asignacion del template especifico |
| GET | `/api/coach/gym/exercises` | `auth()` COACH | 300/min | Buscar ejercicios (globales + custom propios) |
| POST | `/api/coach/gym/exercises` | `auth()` COACH | 60/min | Crear ejercicio custom |
| GET | `/api/coach/gym/exercises/[id]` | `auth()` COACH | 300/min | Detalle ejercicio (ownership: global o propio) |
| PATCH | `/api/coach/gym/exercises/[id]` | `auth()` COACH | 60/min | Editar ejercicio custom propio |
| DELETE | `/api/coach/gym/exercises/[id]` | `auth()` COACH | 30/min | Eliminar ejercicio custom (409 si en uso) |
| GET | `/api/coach/gym/athlete/[id]/prs` | `auth()` COACH | 300/min | PRs del atleta via formula Brzycki |
| GET | `/api/coach/gym/athlete/[id]/logs` | `auth()` COACH | 300/min | Historial volumen por ejercicio (limit 1-200, default 60) |
| GET | `/api/coach/gym/athlete/[id]/volume` | `auth()` COACH | 300/min | Volumen semanal vs semana anterior |
| GET | `/api/coach/gym/athlete/[id]/adherence` | `auth()` COACH | 300/min | Adherencia ultimas 4 semanas |
| GET | `/api/coach/gym/athlete/[id]/assigned` | `auth()` COACH | 300/min | Rutina activa + 5 sesiones recientes + runningSessions del plan |

---

### `GET /api/coach/gym/routines`

**Request:**
```ts
// Sin query params
```

**Response:**
```ts
WorkoutTemplate[] // con WorkoutDay[] y WorkoutExercise[] incluidos
```

**Logica:**
1. `auth()` — verificar COACH
2. `prisma.workoutTemplate.findMany({ where: { coachId }, take: 100 })`
3. Incluir join completo de dias y ejercicios
4. Sin paginacion — limite fijo 100

---

### `POST /api/coach/gym/routines`

**Request:**
```ts
// Body (Zod — CreateRoutineSchema)
{
  name: string            // min 1, max 200
  description?: string    // max 1000
  goal?: string           // max 200
  level?: string          // max 100
  daysPerWeek: number     // int, 1-7
  days: {                 // min 1
    dayOfWeek: number     // int, 0-6
    label: string         // max 100
    muscleGroups: string[] // array de strings, max 50 chars cada uno
    isRestDay: boolean
    warmupNotes?: string  // max 1000
    cardioNotes?: string  // max 1000
    exercises: {
      exerciseId: string            // uuid
      sets?: number                 // int, 1-20, optional
      repsScheme?: string           // max 50, optional (e.g. "8-10", "12,10,8")
      restSeconds?: number | null   // int, 0-600, nullable, optional
      setType?: string              // max 30, optional
      notes?: string                // max 500, optional
      order: number                 // int, min 0
      supersetWithOrder?: number | null  // int, nullable, optional
    }[]
  }[]
}
```

**Response:**
```ts
WorkoutTemplate  // completo con dias y ejercicios, status 201
```

**Logica:**
1. `auth()` — verificar COACH
2. Validar schema Zod
3. Verificar que todos los `exerciseId` sean accesibles: `coachId IS NULL OR coachId = session.coachId`
4. Llamar use case `createRoutine()`
5. Dentro del `$transaction`:
   - Crear `WorkoutTemplate`
   - Crear `WorkoutDay` por cada dia
   - Crear `WorkoutExercise` por cada ejercicio, mapear `order -> id` en memoria
   - Resolver `supersetWith`: para cada ejercicio con `supersetWithOrder != null`, buscar en el mapa el `WorkoutExercise.id` con ese `order` en el mismo dia, asignar ese ID a `supersetWith`
6. Retornar `{ id }`

---

### `GET /api/coach/gym/routines/[id]`

**Request:**
```ts
// Path param: id (WorkoutTemplate.id)
```

**Response:**
```ts
WorkoutTemplate // con WorkoutDay[] — SIN join de Exercise en WorkoutExercise
```

**Logica:**
1. `auth()` — verificar COACH
2. `findFirst({ where: { id, coachId } })` — ownership check
3. 404 si no existe o no pertenece al coach
4. **TRAMPA**: NO incluye el join de la tabla `Exercise` en `WorkoutExercise`. El GET lista si lo incluye.

---

### `PATCH /api/coach/gym/routines/[id]`

**Request:**
```ts
// Body: mismo schema que POST (CreateRoutineSchema — name, description, goal, level, daysPerWeek, days con label/muscleGroups/isRestDay/warmupNotes/cardioNotes/exercises con repsScheme/notes/etc)
// Delegado a updateRoutineUseCase()
```

**Response:**
```ts
{ id: string }
```

**Logica:**
1. `auth()` — verificar COACH
2. Validar schema Zod
3. Verificar ownership: `findFirst({ where: { id, coachId } })`
4. Verificar accesibilidad de ejercicios (igual que POST)
5. Dentro del `$transaction`:
   - `deleteMany({ where: { templateId: id } })` — borra TODOS los WorkoutDay (cascade borra WorkoutExercise)
   - Recrear dias y ejercicios desde cero con nuevos IDs
   - Resolver `supersetWith` igual que POST
6. **CONSECUENCIA CRITICA**: todos los `WorkoutExercise.id` son nuevos. `SetLog.workoutExerciseId` queda `null` (onDelete: SetNull) — el historial no se pierde pero pierde la referencia al ejercicio especifico

---

### `POST /api/coach/gym/routines/[id]/copy`

**Request:**
```ts
// Sin body
```

**Response:**
```ts
{ id: string } // ID del nuevo template copiado
```

**Logica:**
1. `auth()` — verificar COACH
2. Verificar ownership del template source
3. Deep copy en `$transaction`:
   - Crear nuevo `WorkoutTemplate` con nombre `"${name} (copia)"`
   - Copiar cada `WorkoutDay` con nuevos IDs
   - Copiar cada `WorkoutExercise` con nuevos IDs
   - Resolver `supersetWith`: para cada ejercicio con `supersetWith != null` en source, buscar ese `WorkoutExercise` source por ID -> obtener su `order` -> encontrar el nuevo `WorkoutExercise` con ese mismo `order` en el dia correspondiente -> asignar nuevo ID
   - **TRAMPA**: resolucion diferente a POST/PATCH — busca por ID source primero, no por `supersetWithOrder`

---

### `POST /api/coach/gym/routines/[id]/assign`

**Request:**
```ts
// Body
{
  athleteId: string
  startDate: string       // ISO date
  weeksDuration?: number
  notes?: string
}
```

**Response:**
```ts
{ id: string } // ID de AssignedWorkout creada
```

**Logica:**
1. `auth()` — verificar COACH
2. Doble ownership: template pertenece al coach AND `coachAthlete` entre coach y athleteId existe con status ACTIVE
3. Dentro del `$transaction`:
   - `updateMany({ where: { athleteId, isActive: true }, data: { isActive: false } })` — desactiva TODAS las asignaciones activas del atleta, de cualquier template
   - Crear nueva `AssignedWorkout` con `isActive: true`
4. Enviar notificacion al atleta (fire-and-forget, fuera del tx)

---

### `DELETE /api/coach/gym/routines/[id]/assign`

**Request:**
```ts
// Body
{
  athleteId: string
}
```

**Response:**
```ts
{ ok: true }
```

**Logica:**
1. `auth()` — verificar COACH
2. Verificar ownership del template `[id]`
3. `updateMany({ where: { templateId: id, athleteId, isActive: true }, data: { isActive: false } })` — solo desactiva asignaciones del template especifico
4. **TRAMPA CRITICA**: diferencia con POST /assign que desactiva TODAS — este solo desactiva las del template en el path

---

### `GET /api/coach/gym/exercises`

**Request:**
```ts
// Query params
{
  q?: string         // busqueda por nombre
  bodyPart?: string
  target?: string
  equipment?: string
  page?: number      // default 1
  limit?: number
}
```

**Response:**
```ts
{
  exercises: Exercise[]
  total: number
}
```

**Logica:**
1. `auth()` — verificar COACH
2. Filtrar: `(coachId IS NULL OR coachId = session.coachId)` + filtros opcionales de query
3. Aplicar paginacion

---

### `POST /api/coach/gym/exercises`

**Request:**
```ts
// Body validado con validateExercise()
{
  name: string
  bodyPart: string
  target: string
  equipment: string
  // ...campos adicionales de Exercise
}
```

**Response:**
```ts
Exercise
```

**Logica:**
1. `auth()` — verificar COACH
2. `validateExercise(body)` — validacion de negocio
3. Crear con `source: 'custom'` y `coachId = session.coachId`

---

### `GET /api/coach/gym/exercises/[id]`

**Request:**
```ts
// Path param: id (Exercise.id)
```

**Response:**
```ts
Exercise
```

**Logica:**
1. `auth()` — verificar COACH
2. `findFirst({ where: { id } })` — ownership check: solo globales (`coachId: null`) o propios del coach (`coachId` match)
3. 404 si no existe o pertenece a otro coach

---

### `PATCH /api/coach/gym/exercises/[id]`

**Logica:**
1. `auth()` — verificar COACH
2. Ownership check: `coachId === session.user.id` — **403 para ejercicios globales** (`coachId: null`). Solo puede editar custom propios.

---

### `DELETE /api/coach/gym/exercises/[id]`

**Logica:**
1. `auth()` — verificar COACH
2. Ownership check: `coachId === session.user.id` — **403 para ejercicios globales** (`coachId: null`). Solo puede eliminar custom propios.
3. 409 si `workoutExercise.count({ where: { exerciseId: id } }) > 0` — no se puede borrar si hay rutinas que lo usan.

---

### `DELETE /api/coach/gym/routines/[id]`

**Logica:**
1. `auth()` — verificar COACH
2. Ownership check: `findFirst({ where: { id, coachId } })` — 404 si no existe
3. Active assignment check: `assignedWorkout.count({ where: { templateId: id, isActive: true } })` — 409 si hay asignaciones activas
4. `delete` en `WorkoutTemplate` (cascade a dias y ejercicios)

---

### `GET /api/coach/gym/athlete/[id]/prs`

**Request:**
```ts
// Path param: id (athleteId)
```

**Response:**
```ts
{
  exerciseId: string
  exerciseName: string
  maxWeight: number
  maxReps: number
  estimated1RM: number  // formula Brzycki
}[]
```

**Logica:**
1. `auth()` — verificar COACH
2. Ownership: `coachAthlete` existe (sin filtro de status — acepta inactivas)
3. Buscar `SetLog` con `isPR = true` del atleta
4. Calcular `estimated1RM` con formula Brzycki: `weight / (1.0278 - 0.0278 * reps)`

---

### `GET /api/coach/gym/athlete/[id]/logs`

**Request:**
```ts
// Query params
{
  limit?: number  // 1-200, default 60
}
```

**Response:**
```ts
{
  exerciseId: string
  exerciseName: string
  sessions: {
    date: string
    totalVolume: number  // sum(weight * reps) por sesion
    sets: SetLog[]
  }[]
}[]
```

**Logica:**
1. `auth()` — verificar COACH
2. Ownership: `coachAthlete` existe (sin filtro de status)
3. Traer `SessionLog` del atleta limitado a `limit`
4. Agrupar por ejercicio y fecha

---

### `GET /api/coach/gym/athlete/[id]/volume`

**Request:**
```ts
// Sin query params
```

**Response:**
```ts
{
  currentWeek: number
  previousWeek: number
  deltaPct: number
  alert: boolean  // true si abs(deltaPct) > 20
}
```

**Logica:**
1. `auth()` — verificar COACH
2. Ownership: `coachAthlete` existe (sin filtro de status)
3. Calcular volumen semana actual y semana anterior
4. Excluir sets con `setType = WARMUP`; incluir `DROPSET`
5. `alert = abs(deltaPct) > 20`

---

### `GET /api/coach/gym/athlete/[id]/adherence`

**Request:**
```ts
// Sin query params
```

**Response:**
```ts
{
  weeks: {
    weekStart: string
    planned: number
    completed: number
    pct: number
  }[]
  avg4WeekPct: number
}
```

**Logica:**
1. `auth()` — verificar COACH
2. Ownership: `coachAthlete` existe (sin filtro de status)
3. `plannedPerWeek` tomado de `AssignedWorkout.daysPerWeek` OR de `PlannedSession` con tipo FUERZA
4. Calcular adherencia para las 4 semanas anteriores

---

### `GET /api/coach/gym/athlete/[id]/assigned`

**Request:**
```ts
// Sin query params
```

**Response:**
```ts
{
  assignedWorkout: AssignedWorkout | null  // rutina activa con template completo
  recentSessions: SessionLog[]             // ultimas 5 sesiones gym
  runningSessions: PlannedSession[]        // sesiones running del plan activo del atleta
}
```

**Logica:**
1. `auth()` — verificar COACH
2. Ownership: `coachAthlete` existe (sin filtro de status)
3. `AssignedWorkout` con `isActive = true` del atleta, include template completo con dias y ejercicios
4. `SessionLog` ultimas 5 (tipo gym)
5. `PlannedSession` del plan activo del atleta con disciplina running

---

## Modelos DB involucrados

```prisma
model WorkoutTemplate {
  id          String            @id @default(cuid())
  coachId     String
  name        String            // max 200
  description String?           // max 1000
  goal        String?           // max 200
  level       String?           // max 100
  daysPerWeek Int               // 1-7
  days        WorkoutDay[]
  assignments AssignedWorkout[]
  // timestamps
}

model WorkoutDay {
  id           String            @id @default(cuid())
  templateId   String
  dayOfWeek    Int               // 0-6 (convencion JS — no 1-7)
  label        String            // max 100 — nombre del dia (e.g. "Push", "Pierna")
  muscleGroups String[]          // array de strings, max 50 chars cada uno
  isRestDay    Boolean           @default(false)
  warmupNotes  String?           // max 1000
  cardioNotes  String?           // max 1000
  order        Int               @default(0)
  exercises    WorkoutExercise[]
  template     WorkoutTemplate   @relation(fields: [templateId], references: [id], onDelete: Cascade)
}

model WorkoutExercise {
  id               String    @id @default(cuid())
  dayId            String
  exerciseId       String
  sets             Int?      // optional (1-20)
  repsScheme       String?   // max 50 — e.g. "8-10", "12,10,8" (NOT a number)
  restSeconds      Int?      // 0-600
  order            Int
  setType          String?   // max 30 — NORMAL | SUPERSET | BISERIE | DROPSET | CIRCUIT (stored as string)
  notes            String?   // max 500
  supersetWith     String?   // ID de WorkoutExercise en el mismo dia (NO exerciseId)
  day              WorkoutDay @relation(fields: [dayId], references: [id], onDelete: Cascade)
  setLogs          SetLog[]   // onDelete: SetNull -> workoutExerciseId queda null al borrar
}

model AssignedWorkout {
  id            String          @id @default(cuid())
  athleteId     String
  templateId    String
  coachId       String
  isActive      Boolean         @default(true)
  startDate     DateTime
  weeksDuration Int?
  notes         String?
  template      WorkoutTemplate @relation(fields: [templateId], references: [id])
}

model Exercise {
  id        String  @id @default(cuid())
  coachId   String? // null = global del catalogo, non-null = custom del coach
  name      String
  bodyPart  String
  target    String
  equipment String
  source    String  // 'workoutx' | 'ascendapi' | 'custom' | 'manual'
}

enum SetType {
  NORMAL
  SUPERSET
  BISERIE
  DROPSET
  CIRCUIT
  WARMUP
}
```

---

## Reglas de negocio (invariantes)

1. **R01 — Un atleta, una rutina activa**: POST /assign desactiva TODAS las `AssignedWorkout` con `isActive: true` del atleta antes de crear la nueva, sin importar de que template son.
2. **R02 — Ejercicios accesibles**: un coach solo puede usar en sus templates ejercicios globales (`coachId IS NULL`) o sus propios custom (`coachId = coachId`). No puede usar custom de otro coach.
3. **R03 — Superset resolution por contexto**: en POST/PATCH se resuelve `supersetWith` mapeando `supersetWithOrder` (order del ejercicio par en el mismo dia) al ID creado en el tx. En COPY se resuelve mapeando el ID del source a su order y luego al nuevo ID.
4. **R04 — PATCH es replace total**: el update borra y recrea todos los dias y ejercicios del template. Los IDs de `WorkoutExercise` cambian. `SetLog.workoutExerciseId` queda `null` via onDelete SetNull — el historial de sets no se pierde pero pierde la referencia al ejercicio especifico del template.
5. **R05 — Volume excluye WARMUP**: el calculo de volumen semanal excluye todos los sets con `setType = WARMUP`. Los sets `DROPSET` se incluyen en el calculo.
6. **R06 — PR usa sets con flag**: los PRs se calculan unicamente sobre `SetLog` con `isPR = true` (WORK sets). Formula Brzycki: `weight / (1.0278 - 0.0278 * reps)`.
7. **R07 — Ownership analytics acepta inactivas**: los endpoints `/athlete/[id]/*` verifican existencia de `coachAthlete` sin filtrar por status — acepta relaciones inactivas o terminadas. Excepcion: POST /assign exige `coachAthlete.status = ACTIVE`.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `supersetWith` en DB | FK a `Exercise.id` (exerciseId del catalogo) | ID de `WorkoutExercise` — el ejercicio dentro del dia del template (cuid) |
| `supersetWithOrder` en body | campo que mapea directo a DB | order numerico del ejercicio par en el mismo dia — se usa para resolver el ID en tx, no se persiste |
| `dayOfWeek` valores | 1-7 como otros modulos del dominio | 0-6 (convencion JS) — 0 = domingo, 6 = sabado |
| POST /assign vs DELETE /assign | ambos operan igual, solo cambia el template scope | POST desactiva TODAS las rutinas activas del atleta; DELETE solo desactiva las del template en el path `[id]` |
| GET /exercises/[id] ownership | verifica `coachId` como todos los demas endpoints | ownership check: solo globales o propios del coach — 404 para custom de otros |
| PATCH/DELETE exercises globales | Parece que el coach puede editar cualquier ejercicio | Retorna **403** para ejercicios globales (`coachId: null`) — solo puede modificar/eliminar custom propios |
| PATCH effect en historial de sets | update seguro que preserva referencias | invalida `SetLog.workoutExerciseId` (queda null) porque los IDs de `WorkoutExercise` cambian todos |
| COPY superset resolution | igual que POST/PATCH (por supersetWithOrder) | diferente: busca por ID source, obtiene el order, busca el nuevo ID por ese order — puede fallar si el orden cambio en PATCH previo |
| Ownership en analytics | solo acepta status ACTIVE como POST /assign | acepta cualquier status de `coachAthlete` incluyendo inactivas o terminadas |

---

## Tests requeridos

- [ ] POST /routines crea template con `supersetWith` apuntando al ID de `WorkoutExercise` correcto, no al `exerciseId`
- [ ] POST /routines rechaza `exerciseId` de otro coach (custom ajeno)
- [ ] POST /routines acepta `exerciseId` global (`coachId = null`)
- [ ] PATCH /routines/[id] invalida `SetLog.workoutExerciseId` (campo queda null tras replace)
- [ ] PATCH /routines/[id] genera nuevos IDs en todos los `WorkoutExercise`
- [ ] POST /routines/[id]/assign desactiva rutinas de CUALQUIER template del atleta, no solo del template asignado
- [ ] DELETE /routines/[id]/assign solo desactiva asignaciones del template `[id]`, no de otros templates
- [ ] POST /routines/[id]/copy genera deep copy con nombre `"${name} (copia)"` y supersets correctamente resueltos
- [ ] GET /exercises no retorna custom de otros coaches en la lista
- [ ] GET /exercises/[id] retorna 404 para ejercicio custom de otro coach (ownership check)
- [ ] PATCH /exercises/[id] solo permite editar custom propios (coachId match), valida con validateExercise()
- [ ] DELETE /exercises/[id] retorna 409 si el ejercicio está en uso en alguna WorkoutExercise
- [ ] GET /athlete/[id]/volume excluye sets `WARMUP` e incluye sets `DROPSET`
- [ ] GET /athlete/[id]/volume retorna `alert: true` cuando `abs(deltaPct) > 20`
- [ ] GET /athlete/[id]/prs aplica formula Brzycki: `weight / (1.0278 - 0.0278 * reps)`
- [ ] GET /athlete/[id]/prs acepta `coachAthlete` con status inactivo
- [ ] POST /routines/[id]/assign rechaza si `coachAthlete.status != ACTIVE`
- [ ] `dayOfWeek = 0` (domingo) se persiste y retorna como 0, no como 7
- [ ] PATCH /exercises/[id] retorna 403 para ejercicios globales (coachId null)
- [ ] DELETE /exercises/[id] retorna 403 para ejercicios globales (coachId null)
- [ ] DELETE /routines/[id] verifica ownership + active assignment check
- [ ] PlanBuilder firstEmpty: guard cuando semana llena (usedDays.size >= 7)
- [ ] update_routine: order dedup guard previene ejercicios con order duplicado

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-01 | Spec creada (auditoria P0.3) | Extraida del codigo |
| 2026-10-02 | Spec reescrita completa | Detalle de los 15 endpoints, trampas criticas, reglas R01-R07, tests |
| 2026-10-05 | Fix body schema: reps->repsScheme (string), sets optional, notes agregado, label/muscleGroups/isRestDay/warmupNotes/cardioNotes en DaySchema, description/goal/level en template. Rate limits documentados en todos los endpoints (GETs 300/min, writes 60/min, assign 30/min). Modelos DB actualizados (WorkoutTemplate, WorkoutDay, WorkoutExercise). | Auditoria vs Zod schemas reales |
| 2026-10-09 | Auditoria pre-prod: PATCH/DELETE exercises 403 para globales, DELETE routines handler con ownership+active assignment check, PlanBuilder firstEmpty guard semana llena, copyPrevWeek guard, update_routine order dedup guard | 8 rondas de auditoria |
