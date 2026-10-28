# Domain: Plan de Entrenamiento + Check-in
# Reglas de negocio no evidentes en el codigo. Leer antes de tocar planes, check-in o calendario.
> **Flujos por actor -> `flujos-por-actor.md`** -- que puede hacer cada actor (atleta Free/Pro/B2B, coach) en planes y check-in, con endpoints.
> Spec de implementacion: `../specs/plan.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Completa (/plan, /checkin) |
| Mobile atleta | Completa (plan + checkin + calendar + suggestions) |
| Web coach | Completa (diseñar/asignar planes) |

## Que es el Plan

El modulo de entrenamiento contiene disciplinas (gym, running, etc.) — cada una con su biblioteca de ejercicios y forma de registro (ver `entrenamiento.md`). El plan organiza sesiones de esas disciplinas en el tiempo (calendario).

El plan es un **contenedor temporal** donde el coach (o el atleta) organiza sesiones de entrenamiento en un calendario. Es **agnostico de disciplina** -- un plan puede tener sesiones de running, fuerza, ciclismo o cualquier combinacion.

```
TrainingPlan (contenedor)
  -> PlanWeek[] (semanas con fase y volumeKm opcional)
    -> PlannedSession[] (sesiones asignadas a fechas)
        -> tipo RODAJE_Z2, FARTLEK, TEMPO...  (running)
        -> tipo FUERZA + workoutDayId          (gym -- enlaza a entrenamiento.md)
        -> tipo CICLA, NATACION, OTRO...       (otras disciplinas)
```

El plan NO es exclusivo de running. `SessionType` soporta: `RODAJE_Z2 | FARTLEK | TEMPO | INTERVALOS | TIRADA_LARGA | FUERZA | CICLA | NATACION | DESCANSO | TEST | SIMULACRO | OTRO`.

## Filosofia -- el plan es del coach, no del sistema

Los planes de entrenamiento son disenados por coaches especializados. **El sistema NO genera planes automaticamente desde templates.**

Esta decision es intencional:
- RUNNING y GYM son disciplinas con metodologias especificas -- un template generico no puede reemplazar al especialista
- Un plan auto-generado actua como un PDF estatico, no como un plan vivo
- El valor real del producto esta en la capa coach + el registro del atleta

Sin coach activo, el atleta registra sesiones libres y lleva su nutricion -- la capa del plan estructurado la activa el coach.

**Estado del codigo:** `/new-goal` fue eliminado (ARCH-01). `generate_plan.use_case.ts` existe pero es usado exclusivamente por el coach plan builder (no por el atleta). `PlanSource: COACH` es el unico valor valido en el enum -- los planes existentes en DB se conservan intactos.

## Especialidades del coach

El coach declara su especialidad al registrarse. Esto define que herramientas ve en su panel y que tipo de sesiones puede crear:

| Especialidad | Herramientas de plan | Tipo de sesiones que crea |
|-------------|---------------------|--------------------------|
| `RUNNING` | Constructor de sesiones de running | RODAJE_Z2, FARTLEK, TEMPO, INTERVALOS, TIRADA_LARGA -- con zonas FC, pace, distancia |
| `GYM` | Constructor de rutinas de fuerza | FUERZA -- bloques con ejercicios, series, cargas, progresion |
| `NUTRITION` | Plantillas nutricionales | NutritionTemplate con macros por comida y tipo de dia |
| `ALL` | Acceso completo | Todas las especialidades anteriores |

**Estado:** `CoachProfile.specialties String[]` es la fuente canonica (valores: `RUNNING`, `GYM`, `NUTRITION`, `CYCLING`, `SWIMMING`, `YOGA`, `FUNCTIONAL`). `primarySpecialty CoachSpecialty @default(ALL)` sigue en schema pero esta `@deprecated` — pendiente de eliminacion. El panel del coach (`CoachSidebarClient`) filtra herramientas segun `specialties[]`. Con ARCH-12, las disciplinas deportivas son dinamicas via modelo `Discipline`, pero `specialties` sigue como `String[]` porque incluye `NUTRITION` (que no es disciplina deportiva).

## El atleta ve su plan en un calendario (TrainingPeaks-style)

Vista principal del plan para el atleta: **calendario navegable por fecha**.

```
Atleta abre /plan
  -> Ve el mes o semana en formato calendario
  -> Dias con sesion asignada por el coach -> badge/dot de color
  -> Click en un dia -> detalle completo de la sesion
      Running: tipo (RODAJE_Z2 / FARTLEK / TEMPO...), zona FC objetivo, distancia, duracion, notas del coach
      Gym: rutina con ejercicios, series, cargas, descansos (ver entrenamiento.md)
  -> Dias pasados completados -> badge de check
  -> Dias pasados no completados -> badge vacio (historial)
  -> Navegar hacia adelante (semanas futuras del plan)
  -> Navegar hacia atras (historial del atleta)

Sin sesiones asignadas por coach:
  -> Calendario vacio + CTA: "Tu entrenador aun no ha publicado tu plan"
  -> Atleta puede seguir registrando sesiones libres desde cualquier dia
```

**Sin plan del coach -> sin estructura en el calendario.** El atleta B2C sin coach ve su historial de sesiones libres en el calendario pero sin estructura periodizada.

## Como el coach asigna sesiones al atleta

El coach opera desde su panel web -- crea sesiones y las asigna a fechas especificas en el calendario del atleta.

```
Coach abre panel de atleta -> Tab Plan -> Vista calendario
  -> Click en un dia -> "Anadir sesion"
  -> Define: tipo de sesion, zona FC, distancia/duracion, descripcion, nota personal al atleta
  -> Para FUERZA: enlaza a WorkoutDay de la biblioteca de ejercicios (ver entrenamiento.md)
  -> Publica -> atleta recibe notificacion in-app

El coach puede publicar:
  - Sesion por sesion (dia a dia)
  - Bloque semanal completo de una vez
  - Editar una sesion ya publicada antes de que el atleta la ejecute
```

**Regla de edicion post-publicacion:**
- `coachNote` sin prefijo `[AUTO]` = edicion manual del coach -> el sistema NUNCA sobrescribe este campo
- `coachNote` con prefijo `[AUTO]` = ajuste automatico del check-in -> puede sobrescribirse automaticamente
- El coach puede editar: `coachNote`, `detailText`, `zoneTarget`, tipo de sesion

## Relacion Plan <-> Ejercicios

El plan y el modulo de ejercicios son complementarios:

```
Plan (cuando entrenar)              Ejercicios (que hacer)
  PlannedSession tipo FUERZA  --->    WorkoutDay (via workoutDayId)
                                        -> ejercicios, series, cargas
  PlannedSession tipo RUNNING  --->   Campos directos: zona FC, pace, distancia
                                      (no pasa por la biblioteca de ejercicios)
```

- `PlannedSession.workoutDayId` es **nullable** -- solo se usa para sesiones FUERZA
- Una sesion FUERZA del plan carga los ejercicios del `WorkoutDay` enlazado
- Al completar una sesion FUERZA del plan, `autoCompleteStrengthSession()` crea un `SessionLog` automaticamente para que la adherencia del plan la cuente

## El plan nunca es estatico -- check-in lo ajusta

Flujo del check-in (3 fases en `process-check-in.use-case.ts`):

```
Fase 1 -- reads paralelos fuera del tx
  findLatest check-in + findActivePlan + getAdherence + getWeekActivitySummary (paralelo)

Fase 2 -- evaluateRules() pura (sin I/O) -> triggers + adjustments
  Triggers subjetivos (reportados por el atleta):
    fc_alta | sueno_bajo | rpe_excesivo | dolor_activo | estres_alto
    motivacion_baja | nutricion_baja | perdida_peso_rapida | energia_baja
    gym_sobrecarga | nutricion_deficit_critico
  Triggers objetivos (datos reales de SessionLog + GymSession via WeekActivitySummary):
    sin_descanso (>=5 dias consecutivos entrenando)
    rpe_discrepancia (avgRpe real >=8 pero atleta reporta <=5)
    pico_volumen (minutos semanales >=150% del promedio de 4 semanas)
    sesion_muy_intensa (alguna sesion con RPE >=9, excluyente con rpe_excesivo)
  Compuesta: fatiga_acumulada (>=3 triggers individuales -> severity critical)

Fase 3 -- $transaction:
  1. upsert WeeklyCheckIn (incluye waistCm, armsCm, hipsCm, thighsCm si el atleta los envia)
  2. [R4 COMPLETADO] applySessionAdjustments ELIMINADO del check-in
  3. [R3 COMPLETADO] syncWeight si |Dkg| >= 0.5 -> solo guarda peso en HealthProfile.weightKg (sin recalculo TDEE/macros). [BUG-055] Compara vs peso del perfil (`HealthProfile.weightKg`), no vs check-in anterior.
  3b. syncHrResting -> actualiza HealthProfile.hrResting siempre que heartRate > 0
  4. Primer check-in (count === 1) -> enableFeature(userId, 'progress')
```

**El atleta no ve que cambio despues de enviar el check-in -- este es un gap conocido.** `processCheckIn` devuelve `triggers[]` y `adjustments[]` pero no existe pantalla de resultado. Registrado en roadmap (P1).

**WeekActivitySummary agrega AMBAS disciplinas** -- SessionLog (running) + GymSession (gym). El check-in ve entrenamiento unificado, no separado por disciplina.

## Regla de ajuste automatico de sesiones

**[R4 COMPLETADO]** — `applySessionAdjustments` ELIMINADO del flujo de check-in. El check-in es recopilacion de datos solamente. No auto-modifica sesiones ni planes.

La funcion `applySessionAdjustments` sigue exportada para los endpoints de **accept suggestion** (`/checkin/suggestions/[id]/accept`), donde el atleta/coach **decide explicitamente** aceptar un ajuste sugerido. Nunca se aplica automaticamente.

## Adherencia de entrenamiento -- unificada

La adherencia se calcula con `calculateTrainingAdherence()` en `src/domain/training/get_training_adherence.ts`. Combina:

1. **Plan sessions** (running + FUERZA): completadas / esperadas
2. **Rutina gym** (AssignedWorkout): gym sessions completadas / dias esperados por semana

El resultado incluye desglose por disciplina (`running` vs `gym`) y total unificado.

**Endpoint coach:** `GET /api/coach/athletes/[id]/training-adherence` -- devuelve adherencia total + por disciplina + breakdown semanal.

**Nota:** `GET /api/coach/athletes/[id]/running-adherence` sigue existiendo (legacy) pero solo cuenta plan sessions. Usar `training-adherence` para datos completos.

## Formulas cientificas -- fuentes canonicas

- FC maxima: Fox `211 - 0.64 * edad` -- fuente canonica unica en todo el sistema
- Zonas HR: Karvonen si `hrResting > 0`, % simple si `hrResting = 0`
- TDEE: Mifflin-St Jeor en `src/lib/plan/formulas.ts` -- NO recalcular inline en ningun otro lugar
- **Calibracion de ritmos**: si el atleta tiene un 5K_TIME en `PerformanceBenchmark` de los ultimos 90 dias, `computePaceHints(fiveKTimeSecs)` calcula:
  - Easy: `ritmo5K * 1.35` -> sesiones RODAJE_Z2 / TIRADA_LARGA
  - Tempo: `ritmo5K * 1.10` -> sesiones TEMPO
  - Interval: `ritmo5K * 1.00` -> sesiones INTERVALOS / TEST / SIMULACRO
  - Se anade como hint textual al `detailText` de la sesion (no cambia la zona HR).

## Onboarding NO genera plan

El onboarding configura perfil + TDEE + nutricion.
El plan lo asigna el coach (B2B). El atleta B2C sin coach registra sesiones libres hasta tener coach activo.

## Templates actuales en codebase -- estado de deprecacion

| Template | GoalType | Semanas | Estado |
|----------|----------|---------|--------|
| `FIVE_K_8W` | `RACE_5K` | 8 | Deprecar -- no usar para nuevos planes |
| `TEN_K_12W` | `RACE_10K` | 12 | Deprecar -- no usar para nuevos planes |
| `HALF_MARATHON_18W` | `RACE_HALF_MARATHON / RACE_MARATHON` | 18 | Deprecar -- excede 12 semanas |
| `BODY_RECOMPOSITION_16W` | `BODY_RECOMPOSITION / STRENGTH_TRAINING` | 16 | Deprecar -- excede 12 semanas |
| `STRENGTH_TRAINING_16W` | `STRENGTH_TRAINING` | 16 | Deprecar -- excede 12 semanas |

**Los planes existentes en DB no se tocan.** Solo se bloquea la creacion de nuevos planes desde templates.

`PlanSource: COACH` -- unico valor valido. `'TEMPLATE'` NO existe como valor valido.

## Calendar — vista unificada del atleta

El calendar es un **modulo de lectura** que fusiona tres fuentes de datos en una vista semanal unica para el atleta:

1. **PlannedSession** (cualquier disciplina) — sesiones asignadas por el coach o el atleta Pro dentro de un TrainingPlan activo
2. **AssignedWorkout + GymSession** (gym) — rutinas de fuerza asignadas y su registro de completado
3. **SessionLog libre** — sesiones registradas sin plan (atleta autonomo, cualquier disciplina)

No tiene logica de escritura propia. Solo lee y proyecta datos de otros modulos.

**[ARCH-07 — pendiente]** Un dia puede tener N sesiones de cualquier combinacion de fuentes. El modelo actual (`CalendarDay` con 3 slots fijos) asume 1 sesion por disciplina por dia — la segunda sesion del mismo dia es invisible. ARCH-07 cambia `CalendarDay` a un array de `SessionSlot[]`. Ver `flujos-cruzados.md §Flujo 11`.

### Tipos clave

Definidos en `src/domain/calendar/calendar.types.ts`:

- **CalendarDay** — un dia (Mon-Sun). Actualmente 3 slots fijos: `sport`, `gym`, `freeRun`. Post-ARCH-07: `sessions: SessionSlot[]`
- **CalendarWeek** — 7 CalendarDay + metadata (weekStart, weekEnd, label, weekOffset)

Convencion de dia: `dow` 1=Lun ... 7=Dom (consistente con schema DB). `weekIdx` 0-6 para UI.

### Flujo de datos

```
GET /api/athlete/calendar?weekOffset=0&tz=America/Bogota
GET /api/mobile/calendar?weekOffset=0&tz=America/Bogota

  -> buildCalendarWeek(userId, weekOffset, timezone)
       1. Busca TrainingPlan activo del atleta
       2. Calcula weekNumber del plan a partir de weekOffset
       3. Queries paralelos:
          - PlannedSession (por weekNumber, no por fecha)
          - AssignedWorkout activo + WorkoutDay
          - GymSession completadas esta semana (por fecha)
          - SessionLog libres (sin plannedSessionId, por fecha)
       4. Construye lookups por dow (dia de la semana)
       5. Itera 7 dias (Mon-Sun) y arma CalendarDay[]
```

### Archivos del calendar

| Path | Que hace |
|------|----------|
| `domain/calendar/calendar.types.ts` | Tipos CalendarDay, CalendarWeek |
| `infrastructure/db/calendar.ts` | `buildCalendarWeek()` — query + merge |
| `app/api/athlete/calendar/route.ts` | Endpoint web (Auth.js) |
| `app/api/mobile/calendar/route.ts` | Endpoint mobile (jose JWT + rate limit) |
| `app/(athlete)/plan/_components/PlanCalendarView.tsx` | UI web — renderiza CalendarWeek |
| `app/(athlete)/plan/_components/PlanCalendarStrip.tsx` | UI web — strip horizontal de dias |

### Trampas del calendar

- **weekNumber vs fecha**: PlannedSession se busca por `weekNumber` del plan, no por rango de fechas. Esto evita desalineacion si el plan empezo un miercoles.
- **Timezone**: `getWeekMonday()` recibe timezone del cliente. Las fechas resultantes son UTC-midnight. Usar `getUTCDate()` nunca `getDate()` para evitar shifts en servidores no-UTC.
- **GymSession por fecha**: a diferencia de sport (por weekNumber), gym sessions se filtran por rango de fecha real (monday-sunday). Esto es correcto porque gym no tiene concepto de weekNumber.
- **weekOffset rango**: limitado a -52..+52 en ambos endpoints.
- **Dashboard duplica logica**: `get_dashboard_summary.use_case.ts` replica parte de la logica de calendar para la vista de hoy (no reutiliza buildCalendarWeek directamente).
- **[ARCH-07] Multiples sesiones por dia**: `buildCalendarWeek` usa Maps que sobreescriben por dow — si hay 2 sesiones el mismo dia, la segunda desaparece. Post-ARCH-07 los Maps acumulan arrays.

## Modelos DB clave

- `TrainingPlan` -- contenedor temporal: goalType, totalWeeks, startDate, endDate, status
- `PlanWeek` -- semana: weekNumber, phase (BASE|DESARROLLO|ESPECIFICO|AFINAMIENTO), volumeKm (nullable)
- `PlannedSession` -- sesion: type (SessionType), intensity, durationMin, zoneTarget, workoutDayId (nullable FK a ejercicios)
- `SessionLog` -- registro de ejecucion: plannedSessionId (unique), distancia, pace, FC, discipline
- `WeeklyCheckIn` -- check-in semanal: weightKg, hrResting, rpe, energyLevel, stressLevel, adjustmentsTriggered
