# COACH_PLAN — Gestion de planes de entrenamiento (coach)

<!-- mirror: false -->
<!-- note: todos los endpoints son web-only (auth() COACH). No existe mirror mobile para creacion/edicion de planes. -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-02.
> Fuente canonica: esta spec refleja el comportamiento ACTUAL del codigo, no el deseado.
> Specs relacionadas: `coach_athletes.spec.md`, `coach_gym.spec.md`, `plan.spec.md`, `gym.spec.md`

---

## TL;DR

- 17 endpoints (17 web, 0 mobile)
- Modelos: TrainingPlan, PlanWeek, PlannedSession, SessionTemplate
- Dependencias: `generatePlanUseCase()`, `getSessionIntensity()`, `forceMonday()`
- Trampas criticas: `dayOfWeek - 1` en from-template (base-0 vs base-1), PATCH/DELETE comparten ruta, copy-prev es destructivo, sin Zod en mayoria de endpoints
- Mirror mobile: ninguno — plan es web-only

---

## Contratos de la AI

<!-- Lo que la AI DEBE saber antes de tocar este modulo. Si no lees esto, alucinaras. -->

- [ ] `from-template` convierte `dayOfWeek + 1` (base-0 a base-1) al crear sesiones. El resto de endpoints usan base-1 directamente (1=lunes, 7=domingo).
- [ ] Crear un plan SIEMPRE desactiva todos los planes activos del atleta (`updateMany COMPLETED`) en la misma transaccion.
- [ ] PATCH y DELETE de sesiones comparten la misma ruta: `/api/coach/sessions/[sessionId]/edit` — el metodo HTTP diferencia la operacion.
- [ ] `copy-prev` es destructivo: borra TODAS las sesiones de la semana destino antes de copiar.
- [ ] `workoutDayId` solo es valido para sesiones tipo `FUERZA`. Si el tipo cambia, se fuerza `null`.
- [ ] `copy-to` omite `workoutDayId` intencionalmente. `copy-from` (plan completo) lo preserva.
- [ ] La notificacion `PLAN_ACTUALIZADO` se envia async solo en PATCH de sesion (no en create/delete/copy/note).
- [ ] Ownership devuelve 404 (no 403) para la mayoria de recursos. Excepcion: acceso a plan de atleta de otro coach devuelve 403.
- [ ] Timeouts de transaccion custom: 15s en plan custom, 30s en from-template y copy-from.
- [ ] `getSessionIntensity(type)` calcula la intensidad automaticamente — nunca viene del cliente.

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| POST | `/api/coach/athletes/[id]/plan` | `auth()` COACH | ninguno | Generar plan desde template predefinido |
| POST | `/api/coach/athletes/[id]/plan/custom` | `auth()` COACH | ninguno | Crear plan vacio custom |
| POST | `/api/coach/athletes/[id]/plan/from-template` | `auth()` COACH | ninguno | Crear plan desde WorkoutTemplate con sesiones |
| POST | `/api/coach/athletes/[id]/plan/copy-from` | `auth()` COACH | ninguno | Copiar plan completo de otro atleta |
| POST | `/api/coach/athletes/[id]/sessions` | `auth()` COACH | ninguno | Crear sesion en plan activo (busca semana por fecha) |
| POST | `/api/coach/plan/[planId]/sessions` | `auth()` COACH | ninguno | Crear sesion por planId + weekId explicito |
| PATCH | `/api/coach/sessions/[sessionId]/edit` | `auth()` COACH | ninguno | Editar sesion + notificacion async |
| DELETE | `/api/coach/sessions/[sessionId]/edit` | `auth()` COACH | ninguno | Borrar sesion |
| PATCH | `/api/coach/sessions/[sessionId]/note` | `auth()` COACH | ninguno | Editar coachNote de sesion |
| POST | `/api/coach/sessions/[sessionId]/copy-to` | `auth()` COACH | ninguno | Copiar sesion a otra semana |
| POST | `/api/coach/plan/[planId]/week/[weekId]/copy-prev` | `auth()` COACH | ninguno | Copiar sesiones de semana anterior (destructivo) |
| PATCH | `/api/coach/plan/[planId]/week/[weekId]` | `auth()` COACH | ninguno | Editar metadatos de semana |
| GET | `/api/coach/plans` | `auth()` COACH | ninguno | Listar planes de todos los atletas del coach |
| PATCH | `/api/coach/athletes/[id]/plan/nutrition-template` | `auth()` COACH | ninguno | (ver `coach_nutrition.spec.md`) |
| GET | `/api/coach/session-templates` | `auth()` COACH | ninguno | Listar SessionTemplates del coach |
| POST | `/api/coach/session-templates` | `auth()` COACH | ninguno | Crear SessionTemplate |
| DELETE | `/api/coach/session-templates` | `auth()` COACH | ninguno | Borrar SessionTemplate |

---

## Endpoints — documentacion detallada

### POST /api/coach/athletes/[id]/plan

Genera un plan completo para el atleta desde un template predefinido del sistema (`PLAN_TEMPLATES`).

**Auth:** `auth()` — verifica `role === 'COACH'` y ownership via `coachAthlete.findFirst({ where: { coachId, athleteId: id, status: 'ACTIVE' } })` → 404 si no.

**Request body:**
```ts
{
  goalType: string         // clave de PLAN_TEMPLATES — requerido
  daysPerWeek?: number     // 3-6, default 4
  hoursPerSession?: number // 0.5-3, default 1
}
```

**Logica:**
1. Verifica ownership del atleta con el coach.
2. Carga `HealthProfile` del atleta → 400 si no existe.
3. Busca `PerformanceBenchmark` 5K mas reciente del atleta (puede ser null — no bloquea).
4. Llama `generatePlanUseCase({ athleteId, goalType, daysPerWeek, hoursPerSession, healthProfile, benchmark, generatedBy: 'COACH' })`.
5. Dentro del use case, en `$transaction`:
   - `updateMany` planes activos del atleta → `status: 'COMPLETED'`
   - `create` TrainingPlan con semanas y sesiones
   - `upsert` NutritionProfile del atleta

**Respuesta:** `{ planId: string }`

---

### POST /api/coach/athletes/[id]/plan/custom

Crea un plan vacio (sin sesiones) con semanas pre-generadas segun la duracion indicada.

**Auth:** verifica ownership del atleta como en el endpoint anterior.

**Request body (Zod):**
```ts
{
  name: string         // requerido
  totalWeeks: number   // 1-52
  startDate: string    // ISO date — se fuerza a lunes con forceMonday()
}
```

**Logica de fases por ciclo de 2 semanas:**
```
Semana 1-2:   BASE
Semana 3-4:   BASE
Semana 5-6:   DESARROLLO
Semana 7-8:   DESARROLLO
Semana 9-10:  ESPECIFICO
Semana 11-12: ESPECIFICO
Semana 13-14: AFINAMIENTO
(ciclo se repite si totalWeeks > 14)
```

**Transaccion (timeout: 15s):**
1. `updateMany` planes activos del atleta → `status: 'COMPLETED'`
2. `create` TrainingPlan con todas las PlanWeeks (sin sesiones)

**Respuesta:** `{ planId: string }`

---

### POST /api/coach/athletes/[id]/plan/from-template

Crea un plan con sesiones pre-cargadas desde un WorkoutTemplate (rutina gym del coach).

**Auth:** verifica ownership del atleta.

**Request body:**
```ts
{
  templateId: string  // id del WorkoutTemplate
  name: string
  startDate: string   // se fuerza a lunes
}
```

**TRAMPA CRITICA — dayOfWeek base-0 a base-1:**
```ts
// WorkoutDay.dayOfWeek viene en base-0 (0=lunes) del modelo de rutina gym
// PlannedSession.dayOfWeek usa base-1 (1=lunes, 7=domingo)
// Conversion: dayOfWeek: workoutDay.dayOfWeek + 1
```
Esta es la UNICA ruta que hace esta conversion. El resto de endpoints asume que el valor recibido ya esta en base-1.

**Transaccion (timeout: 30s):**
1. Verifica que el template pertenezca al coach: `workoutTemplate.findFirst({ where: { id: templateId, coachId } })` → 404 si no.
2. `updateMany` planes activos del atleta → `status: 'COMPLETED'`
3. `create` TrainingPlan con semanas y sesiones derivadas de los dias del template.
4. Cada `WorkoutDay` del template se convierte en una `PlannedSession` con `type: 'FUERZA'` y `workoutDayId` enlazado.

**Respuesta:** `{ planId: string }`

---

### POST /api/coach/athletes/[id]/plan/copy-from

Copia un plan completo (semanas + sesiones) de otro atleta al atleta destino.

**Auth:** verifica ownership del atleta DESTINO.

**Request body (Zod):**
```ts
{
  sourcePlanId: string
  startDate: string   // se fuerza a lunes
}
```

**Doble ownership:**
- Atleta destino: `coachAthlete.findFirst({ where: { coachId, athleteId: targetAthleteId, status: 'ACTIVE' } })` → 404
- Plan fuente: `trainingPlan.findFirst({ where: { id: sourcePlanId, user.coachAthletes.some({ coachId }) } })` → **sin filtro de status** — puede copiar planes COMPLETED o PAUSED

**Logica:**
1. Carga plan fuente con todas sus semanas y sesiones.
2. Recalcula fechas: `startDate + offset_semana + offset_dia`.
3. Nombre del plan nuevo: `"${sourcePlan.name} (copia)"`.
4. Preserva `workoutDayId` de cada sesion (a diferencia de `copy-to`).

**Transaccion (timeout: 30s):**
1. `updateMany` planes activos del atleta destino → `status: 'COMPLETED'`
2. `create` nuevo TrainingPlan con semanas y sesiones clonadas

**Respuesta:** `{ planId: string }`

---

### POST /api/coach/athletes/[id]/sessions

Crea una sesion en el plan activo del atleta buscando la semana que contiene la fecha indicada.

**Auth:** verifica ownership del atleta.

**Request body (Zod):**
```ts
{
  date: string          // ISO date
  type: SessionType     // enum del dominio
  durationMin: number   // 5-600
  zoneTarget?: number   // max 50
  detailText?: string   // max 1000
  coachNote?: string    // max 500
}
```

**Logica:**
1. Busca plan activo del atleta: `trainingPlan.findFirst({ where: { userId: athleteId, status: 'ACTIVE' } })` → 422 si no hay plan activo.
2. Busca `PlanWeek` cuyo rango [weekStart, weekEnd] contiene la fecha → 422 si la fecha cae fuera de todas las semanas.
3. Calcula `dayOfWeek` desde la fecha (1=lunes, 7=domingo).
4. Crea `PlannedSession` con `intensity: getSessionIntensity(type)`.

**Respuesta:** `{ sessionId: string }`

---

### POST /api/coach/plan/[planId]/sessions

Crea una sesion especificando planId y weekId explicitamente. No busca por fecha.

**Auth:** verifica que el plan pertenezca a un atleta del coach: `trainingPlan.findFirst({ where: { id: planId, user.coachAthletes.some({ coachId }) } })` → 404 si no.

**Request body (sin Zod — validacion manual):**
```ts
{
  weekId: string
  dayOfWeek: number     // 1-7
  type: string          // SessionType
  durationMin: number
  distanceKm?: number
  zoneTarget?: number
  detailText?: string
  sportLabel?: string
  workoutDayId?: string
}
```

**Validacion manual adicional:** verifica que `weekId` pertenezca al `planId`: `planWeek.findFirst({ where: { id: weekId, planId } })` → 400 si no.

**Logica:** crea `PlannedSession` con `intensity: getSessionIntensity(type)`.

**Respuesta:** objeto `PlannedSession` completo.

---

### PATCH /api/coach/sessions/[sessionId]/edit

Edita campos de una sesion existente y envia notificacion al atleta de forma async.

**Auth:** verifica ownership via plan: `plannedSession.findFirst({ where: { id: sessionId, week.plan.user.coachAthletes.some({ coachId }) } })` → 404 si no.

**Request body (sin Zod — validacion manual):**
```ts
{
  type?: string         // SessionType — si cambia, recalcula intensity
  durationMin?: number
  distanceKm?: number
  detailText?: string
  zoneTarget?: number
  structure?: string
  sportLabel?: string
  workoutDayId?: string // solo si type === 'FUERZA'; si no, se fuerza null
}
```

**Regla workoutDayId:**
```ts
// Si type cambia a algo distinto de FUERZA, workoutDayId se elimina:
workoutDayId: resolvedType === 'FUERZA' ? (body.workoutDayId ?? existing.workoutDayId) : null
```

**Side effect (fire-and-forget):** envia notificacion `PLAN_ACTUALIZADO` al atleta via `createNotification()`. Es la unica ruta de sesiones que notifica.

**Respuesta:** `{ ok: true }`

---

### DELETE /api/coach/sessions/[sessionId]/edit

Borra una sesion. Comparte archivo de ruta con PATCH — el metodo HTTP diferencia la operacion.

**Auth:** mismo ownership check que PATCH.

**Logica:** `plannedSession.delete({ where: { id: sessionId } })`.

**Respuesta:** `{ ok: true }`

---

### PATCH /api/coach/sessions/[sessionId]/note

Edita solo el campo `coachNote` de una sesion.

**Auth:** mismo ownership check que PATCH/DELETE.

**Request body:**
```ts
{ note: string }
```

**Regla:** NO agrega prefijo `[AUTO]`. Es una nota manual del coach. Ver trampa T02 en `_traps.spec.md` — notas sin `[AUTO]` bloquean ajustes automaticos del check-in sobre esa sesion.

**Respuesta:** `{ ok: true }`

---

### POST /api/coach/sessions/[sessionId]/copy-to

Copia una sesion a otra semana (del mismo plan u otro plan del mismo atleta).

**Auth:** doble ownership:
- Sesion fuente: `plannedSession.findFirst({ where: { id: sessionId, week.plan.user.coachAthletes.some({ coachId }) } })` → 404
- Semana destino: `planWeek.findFirst({ where: { id: targetWeekId, plan.user.coachAthletes.some({ coachId }) } })` → 404

**Request body:**
```ts
{
  targetWeekId: string
  dayOfWeek: number   // 1-7
}
```

**TRAMPA — workoutDayId se omite intencionalmente:**

`copy-to` NO copia `workoutDayId` aunque la sesion fuente sea FUERZA y lo tenga. La sesion copiada queda sin vincular a ninguna rutina gym. Contrasta con `copy-from` (plan completo) que SI preserva `workoutDayId`.

**Logica:** calcula la nueva `date` desde el `weekStart` de la semana destino + `dayOfWeek`. Crea nueva `PlannedSession` sin `workoutDayId`.

**Respuesta:** objeto `PlannedSession` creado.

---

### POST /api/coach/plan/[planId]/week/[weekId]/copy-prev

Copia todas las sesiones de la semana anterior a la semana indicada. **Operacion destructiva — borra las sesiones existentes en el destino.**

**Auth:** verifica ownership del plan: `trainingPlan.findFirst({ where: { id: planId, user.coachAthletes.some({ coachId }) } })` → 404.

**Logica:**
1. Verifica que `weekId` pertenezca al `planId`.
2. Calcula el numero de semana de la semana destino y busca la semana con `weekNumber - 1` → 400 si no existe semana anterior.

**Transaccion (destructiva):**
```ts
await tx.plannedSession.deleteMany({ where: { weekId: targetWeekId } })
await tx.plannedSession.createMany({
  data: prevSessions.map(s => ({
    ...s,
    id: undefined,      // genera nuevo cuid
    weekId: targetWeekId,
    date: recalculada,  // fecha ajustada a la semana destino
  }))
})
```

Si la transaccion falla despues del `deleteMany`, la semana destino queda vacia. No hay rollback visible al usuario.

**Respuesta:** `{ ok: true, count: number }` — numero de sesiones copiadas.

---

### PATCH /api/coach/plan/[planId]/week/[weekId]

Edita los metadatos de una semana del plan.

**Auth:** verifica ownership del plan.

**Validacion:** verifica que `weekId` pertenezca al `planId` → 400 si no.

**Request body (campos opcionales):**
```ts
{
  phase?: 'BASE' | 'DESARROLLO' | 'ESPECIFICO' | 'AFINAMIENTO'
  focusDescription?: string
  isRecoveryWeek?: boolean
  volumeKm?: number
}
```

**Respuesta:** objeto `PlanWeek` actualizado.

---

### GET /api/coach/plans

Lista los planes de todos los atletas del coach. Usado principalmente en el modal "copiar plan de otro atleta".

**Auth:** `auth()` COACH.

**Logica:**
```ts
coachAthlete.findMany({
  where: { coachId, status: 'ACTIVE' },
  take: 200,
  include: {
    athlete: {
      include: {
        trainingPlans: { take: 3, orderBy: { createdAt: 'desc' } }
      }
    }
  }
})
```

Limite fijo de 200 relaciones y 3 planes por atleta. Coaches con mas de 200 atletas activos no veran todos.

**Respuesta:**
```ts
{
  plans: [{
    planId: string
    planName: string
    athleteName: string
    athleteId: string
    status: TrainingPlanStatus
    totalWeeks: number
    createdAt: string
  }]
}
```

---

### GET /api/coach/session-templates

Lista los `SessionTemplate` del coach autenticado.

**Auth:** `auth()` COACH.

**Logica:** `sessionTemplate.findMany({ where: { coachId }, orderBy: { createdAt: 'desc' } })`.

**Respuesta:**
```ts
{
  templates: [{
    id: string
    name: string
    type: string
    durationMin: number
    distanceKm: number | null
    zoneTarget: number | null
    detailText: string | null
    sportLabel: string | null
  }]
}
```

---

### POST /api/coach/session-templates

Crea un `SessionTemplate` para el coach.

**Auth:** `auth()` COACH.

**Request body:**
```ts
{
  name: string
  type: string          // SessionType
  durationMin: number
  distanceKm?: number
  zoneTarget?: number
  detailText?: string
  sportLabel?: string
}
```

**Logica:** `sessionTemplate.create({ data: { ...body, coachId } })`.

**Respuesta:** objeto `SessionTemplate` creado.

---

### DELETE /api/coach/session-templates

Borra un `SessionTemplate` del coach.

**Auth:** `auth()` COACH.

**Request body:**
```ts
{ id: string }
```

**Ownership check:** `sessionTemplate.findFirst({ where: { id, coachId } })` → 404 si no pertenece al coach.

**Logica:** `sessionTemplate.delete({ where: { id } })`.

**Respuesta:** `{ ok: true }`

---

## Modelos DB involucrados

```prisma
model TrainingPlan {
  id          String             @id @default(cuid())
  userId      String             // athleteId — tenant key
  name        String
  status      TrainingPlanStatus // ACTIVE | COMPLETED | PAUSED | ABANDONED
  generatedBy String             // 'COACH' | 'SYSTEM' | 'ATHLETE'
  totalWeeks  Int
  startDate   DateTime
  weeks       PlanWeek[]
  createdAt   DateTime
}

enum TrainingPlanStatus {
  ACTIVE
  COMPLETED
  PAUSED
  ABANDONED
}

model PlanWeek {
  id               String    @id @default(cuid())
  planId           String
  weekNumber       Int
  phase            PlanPhase
  focusDescription String?
  isRecoveryWeek   Boolean   @default(false)
  volumeKm         Float?
  weekStart        DateTime
  weekEnd          DateTime
  sessions         PlannedSession[]
}

enum PlanPhase {
  BASE
  DESARROLLO
  ESPECIFICO
  AFINAMIENTO
}

model PlannedSession {
  id           String           @id @default(cuid())
  weekId       String
  dayOfWeek    Int
  // base-1: 1=lunes, 7=domingo
  // EXCEPCION: from-template convierte desde base-0 (WorkoutDay.dayOfWeek) sumando +1
  date         DateTime
  type         SessionType
  intensity    SessionIntensity // auto-calculada con getSessionIntensity(type), nunca viene del cliente
  durationMin  Int
  distanceKm   Float?
  zoneTarget   Int?
  detailText   String?
  coachNote    String?
  // prefijo [AUTO] = escrita por sistema (check-in)
  // sin prefijo = nota manual del coach (bloquea ajustes automaticos del check-in)
  structure    String?
  sportLabel   String?
  workoutDayId String?
  // solo para type=FUERZA
  // se fuerza null si type cambia a otro valor en PATCH
  // copy-to lo omite; copy-from lo preserva
}

model SessionTemplate {
  id          String   @id @default(cuid())
  coachId     String   // ownership
  name        String
  type        String   // SessionType
  durationMin Int
  distanceKm  Float?
  zoneTarget  Int?
  detailText  String?
  sportLabel  String?
  createdAt   DateTime @default(now())
}
```

---

## Reglas de negocio (invariantes)

1. **R01 — Plan activo desactivado en toda creacion:** `updateMany({ where: { userId: athleteId, status: 'ACTIVE' }, data: { status: 'COMPLETED' } })` siempre precede al `create` del nuevo plan, en la misma transaccion. Aplica a los 4 endpoints de creacion de plan.

2. **R02 — dayOfWeek base-1 como estandar:** todos los endpoints almacenan y consumen `PlannedSession.dayOfWeek` en base-1 (1=lunes, 7=domingo). La unica excepcion es `from-template` que recibe `WorkoutDay.dayOfWeek` en base-0 y convierte con `+1`.

3. **R03 — from-template convierte base-0 a base-1:** `WorkoutDay.dayOfWeek` en el modelo de rutina gym usa base-0 (0=lunes). `from-template` es el unico endpoint que hace esta conversion.

4. **R04 — workoutDayId exclusivo de FUERZA:** si el tipo de sesion cambia en PATCH a cualquier cosa distinta de `FUERZA`, `workoutDayId` se fuerza a `null` automaticamente.

5. **R05 — copy-to vs copy-from en workoutDayId:** `copy-to` (sesion individual) omite `workoutDayId`. `copy-from` (plan completo) lo preserva. Diferencia intencional.

6. **R06 — intensity auto-calculada:** `PlannedSession.intensity` siempre se calcula con `getSessionIntensity(type)`. Nunca se acepta del cliente.

7. **R07 — Ownership retorna 404:** los ownership checks devuelven 404 para no revelar si existe un recurso de otro coach. Excepcion documentada: acceso a plan de atleta de otro coach puede retornar 403.

8. **R08 — Notificacion solo en PATCH sesion:** `PLAN_ACTUALIZADO` se envia unicamente en `PATCH /edit`. Create, delete, copy-to, copy-prev y note no notifican.

9. **R09 — coachNote sin [AUTO] bloquea ajustes automaticos:** una sesion con `coachNote` que no empiece con `[AUTO]` no sera modificada por `applySessionAdjustments` en el check-in. Ver `_traps.spec.md` T02.

> **[roadmap R4] PENDIENTE DE ELIMINAR.** La decisión de producto es que check-in = recopilación de datos solamente. El sistema NUNCA auto-modifica planes. `applySessionAdjustments` será eliminado — ver T02 en `_traps.spec.md`.

10. **R10 — copy-from sin filtro de status en plan fuente:** el plan origen puede estar en cualquier status (ACTIVE, COMPLETED, PAUSED, ABANDONED). El filtro solo aplica al atleta destino (debe tener relacion ACTIVE con el coach).

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| **dayOfWeek en from-template** | El template usa el mismo esquema que el plan | `WorkoutDay.dayOfWeek` es base-0 (0=lunes). Se suma 1 al crear la PlannedSession. Es la unica ruta que hace esto. |
| **PATCH/DELETE misma ruta** | Son endpoints separados | `/api/coach/sessions/[sessionId]/edit` maneja ambos metodos HTTP en el mismo archivo de ruta Next.js. |
| **copy-prev destructivo** | "Copiar" implica que el destino se preserva | El endpoint hace `deleteMany` en la semana destino ANTES del `createMany`. Si el create falla, la semana queda completamente vacia. |
| **copy-to sin workoutDayId** | Copiar una sesion FUERZA deberia copiar el vinculo a la rutina | `copy-to` omite `workoutDayId` intencionalmente. La sesion copiada queda desvinculada de cualquier rutina gym. |
| **copy-from con workoutDayId** | copy-to y copy-from deberian comportarse igual | `copy-from` (plan completo) SI preserva `workoutDayId`. Diferencia intencional: al copiar un plan completo se mantiene la estructura gym. |
| **Sin Zod en mayoria de endpoints** | El resto del codebase usa Zod | Solo plan/custom y copy-from usan Zod. Los demas validan manualmente con checks inline. Campos invalidos pueden pasar silenciosamente si no se cubren. |
| **Tx timeout 15s/30s** | Los timeouts son el default del ORM | plan/custom usa 15s; from-template y copy-from usan 30s. Sin especificarlo, Prisma usa el default del PG adapter (puede ser menor). |
| **Notificacion fire-and-forget en PATCH edit** | La respuesta `{ ok: true }` confirma que el atleta fue notificado | La notificacion se envia async sin await. Si falla, la edicion ya fue exitosa y el atleta no recibe notificacion. No hay reintentos. |
| **GET /api/coach/plans: limite de 200** | Lista todos los atletas del coach | Hard limit `take: 200` en coachAthletes y `take: 3` en planes por atleta. Coaches grandes no veran todos sus atletas. |
| **copy-from copia plan de cualquier status** | Solo deberia copiar planes activos | El query del plan fuente no filtra por status. Un coach puede copiar un plan COMPLETED o ABANDONED de otro atleta suyo. |

---

## Paridad web vs mobile

Este modulo no tiene mirror mobile. Todos los endpoints son web-only (auth() COACH).

El atleta consume el plan via:
- Web: `/api/athlete/plan/*`
- Mobile: `/api/mobile/plan/*`

Ver `plan.spec.md` para los endpoints de lectura del atleta.

---

## Tests requeridos

- [ ] POST plan: 404 si atleta no pertenece al coach (relacion no ACTIVE)
- [ ] POST plan: 400 si atleta no tiene HealthProfile
- [ ] POST plan: desactiva plan activo previo en la misma transaccion
- [ ] POST plan/custom: startDate se fuerza a lunes (forceMonday)
- [ ] POST plan/custom: fases asignadas correctamente por numero de semana
- [ ] POST plan/from-template: dayOfWeek se convierte correctamente (base-0 + 1 = base-1)
- [ ] POST plan/from-template: sesiones FUERZA tienen workoutDayId
- [ ] POST plan/copy-from: nombre del plan es "${name} (copia)"
- [ ] POST plan/copy-from: puede copiar plan con status COMPLETED (sin filtro de status)
- [ ] POST plan/copy-from: preserva workoutDayId en sesiones copiadas
- [ ] POST athletes/[id]/sessions: 422 si atleta no tiene plan activo
- [ ] POST athletes/[id]/sessions: 422 si fecha cae fuera de todas las semanas del plan
- [ ] PATCH sessions/[id]/edit: workoutDayId se fuerza null si type cambia de FUERZA a otro
- [ ] PATCH sessions/[id]/edit: intensity se recalcula si type cambia
- [ ] PATCH sessions/[id]/edit: notificacion se envia de forma async (fire-and-forget)
- [ ] DELETE sessions/[id]/edit: 404 si sesion no pertenece a un atleta del coach
- [ ] POST sessions/[id]/copy-to: nueva sesion no tiene workoutDayId
- [ ] POST sessions/[id]/copy-to: 404 si semana destino no pertenece a un atleta del coach
- [ ] POST plan/[planId]/week/[weekId]/copy-prev: 400 si no hay semana anterior
- [ ] POST plan/[planId]/week/[weekId]/copy-prev: borra sesiones existentes antes de copiar
- [ ] POST plan/[planId]/week/[weekId]/copy-prev: recalcula fechas correctamente para la semana destino
- [ ] DELETE session-templates: 404 si template no pertenece al coach
- [ ] GET /api/coach/plans: solo retorna atletas del coach autenticado

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-01 | Spec stub creada (auditoria P0.3) | Extraida del codigo |
| 2026-10-02 | Spec completa con 17 endpoints, contratos, trampas, tests | Expansion completa desde descripcion de endpoints |
