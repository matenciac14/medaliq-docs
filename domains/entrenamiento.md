# Domain: Entrenamiento
# Reglas de negocio no evidentes en el codigo. Leer antes de tocar cualquier feature de entrenamiento.
> **Flujos por actor -> `flujos-por-actor.md`** -- que puede hacer cada actor (atleta, coach, admin) en este modulo, con endpoints.
> Spec de implementacion: `../specs/gym.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Completa (/gym, /gym/session, /gym/builder, /gym/exercises) |
| Mobile atleta | Completa (8 endpoints gym + 3 exercises + draft offline) |
| Web coach | Completa (asignar rutinas, templates) |

## Que es el modulo de Entrenamiento

Entrenamiento es un **modulo unificado que contiene disciplinas** (gym, running, natacion, yoga, ciclismo, etc.). Cada disciplina tiene su propia biblioteca de ejercicios y su forma de registrar sesiones.

Dentro del modulo hay dos conceptos distintos:

1. **Biblioteca de ejercicios = enciclopedia.** El atleta la navega para aprender como se ejecuta cada ejercicio (demo GIF, instrucciones, musculo objetivo). Es referencia, no tracking. Fuente: AscendAPI para gym (1,300+ ejercicios). Otras disciplinas pendientes de contenido de especialistas.

2. **Registrar sesion = tracking.** El atleta elige disciplina -> selecciona ejercicios de esa disciplina -> registra datos (sets/reps/peso para gym; distancia/pace/FC para running; etc.). Es un flujo de registro, no de consulta.

**Estado de bibliotecas por disciplina:**
| Disciplina | Biblioteca | Registro de sesion |
|-----------|-----------|-------------------|
| Gym / Fuerza | Rica (AscendAPI, 1,300+ ejercicios con GIF) | Completo (`GymSession` + `SetLog`) |
| Running | Sin biblioteca — usa `SessionType` enum (RODAJE_Z2, FARTLEK, etc.) con campos directos | Completo (`SessionLog`) |
| Yoga, Natacion, Ciclismo | Pendiente — requiere contenido de especialistas | Pendiente |

**[ARCH-12 — Configuración dinámica de disciplinas — COMPLETADO]** Modelo `Discipline` en DB con: slug, name/nameEs, icon, color, isActive, sortOrder, hasExerciseLibrary, trackingFields (JSON), sessionTypes (JSON). 5 disciplinas seed: strength, running, cycling, swimming, other. Endpoints: `GET /api/disciplines` (público, cacheable 1h), admin CRUD completo (`GET/POST /api/admin/disciplines`, `GET/PATCH/DELETE /api/admin/disciplines/[id]`). Resolver cacheable en `domain/discipline/discipline_resolver.ts`. Todos los write paths escriben `disciplineId`. Read paths incluyen `disciplineRef`. `SESSION_INTENSITY_MAP` centralizado en discipline.types.ts. ProfileForm del coach carga disciplinas dinámicamente. 62 tests. CoachProfile.specialties sigue como String[] — NUTRITION no es disciplina deportiva. Cadena: ARCH-12 (DONE) → ARCH-11 (rutina multi-disciplina) → ARCH-07 (múltiples sesiones por día).

El modulo alimenta dos destinos:

```
Entrenamiento (bibliotecas + registro)
  |
  |-- Alimenta al Plan (sesion estructurada con fecha)
  |     PlannedSession tipo FUERZA -> workoutDayId -> ejercicios del dia
  |     (ver plan.md para el contenedor temporal)
  |
  |-- Alimenta al track diario (sesion libre o rutina sin plan)
        AssignedWorkout -> rutina ciclica por dia de la semana
        Sesion libre -> atleta elige disciplina y registra
```

## Convención dayOfWeek — base-1

En todo el sistema, `dayOfWeek` usa convención base-1: **1 = Lunes, 7 = Domingo**. Esta convención aplica en rutinas, sesiones planificadas y respuestas de API. La validación rechaza valores menores a 1. Internamente, `GymSession.dayOfWeek` almacena formato JavaScript nativo (0-6), pero se convierte a base-1 en las respuestas de la API para mantener consistencia.

---

## Nomenclatura -- regla critica

- En UI y producto: **"Entrenamiento"** -- nombre definitivo del modulo. Cubre todas las disciplinas (gym, running, ciclismo, etc.)
- Sub-sección de biblioteca: **"Ejercicios"** -- la enciclopedia de referencia dentro del modulo
- En codigo, DB y feature flags: `gym`, `GymSession`, `featureGym`, `AssignedWorkout`
- **NO renombrar en codigo** -- evita migracion costosa. El renombramiento es solo UI/producto.

## Biblioteca de ejercicios (Exercise) — enciclopedia

La biblioteca es una **enciclopedia de referencia**: el atleta la navega para aprender como se ejecuta cada ejercicio (demo GIF, instrucciones, musculo objetivo, equipamiento). No es un flujo de tracking — es consulta.

- Fuente operacional default: **AscendAPI ExerciseDB V1** (`EXERCISE_SOURCE ?? 'ascendapi'`, ~1,300+ ejercicios, tier free sin auth). GIFs cacheados en `gifStoredUrl` (CDN propio) — no dependemos de AscendAPI en runtime.
- Fuente alternativa: WorkoutX activable via `EXERCISE_SOURCE=workoutx`
- Nota schema: `Exercise.source @default("workoutx")` se mantiene por legado pero el runtime usa AscendAPI
- `Exercise.source` valores: `'workoutx' | 'ascendapi' | 'custom' | 'manual'`
- **AscendAPI tiene 3 productos independientes**: ExerciseDB V1 (free, lo que usamos), ExerciseDB V2 (paid, 11K ejercicios + videos HD), Muscle Visualizer (paid, diagramas anatómicos dinámicos). No se reemplazan entre sí. MVP-08 en roadmap evalúa integrar Muscle Visualizer post-launch.
- Ejercicios custom del coach: `coachId` set, `source = 'custom'`. El coach crea ejercicios propios desde su panel — solo visibles para el y sus atletas. Pueden asignarse en rutinas igual que los de AscendAPI.
- Campos principales: name, nameEs, bodyPart, target, secondaryMuscles[], equipment, difficulty, mechanic, force, caloriesPerMinute, gifUrl, videoUrl, description
- Campos de metadata: `disciplineId` (FK a modelo Discipline — canónico post-ARCH-12; `discipline String?` legacy se mantiene por compatibilidad), `isUnilateral` (ejercicio unilateral), `met` (MET para calorias), `popularityRank` (ordena busqueda)
- Hoy la biblioteca solo tiene contenido rico para **gym** (AscendAPI). Running no usa la biblioteca — usa `SessionType` enum (RODAJE_Z2, FARTLEK, etc.) con campos directos (distancia, pace, FC). Otras disciplinas (yoga, natacion, ciclismo) estan pendientes de sus bibliotecas de ejercicios con contenido de especialistas

## Tres caminos para entrenar -- routing de sesion

```
1. Plan de entrenamiento (PlannedSession tipo FUERZA)
   -> Carga ejercicios del WorkoutDay ligado a la fase del plan

2. Rutina asignada por coach (AssignedWorkout activo)
   -> Carga ejercicios del WorkoutTemplate del coach
   -> Ciclica por dia de la semana (sin fechas fijas)

3. Sesion libre (sin plan ni rutina)
   -> Atleta elige disciplina y registra libremente
```

`GET /api/athlete/gym/session/today` y `getTodaySession()` determinan cual aplica. Actualmente retorna 1 sesion con prioridad excluyente — **[ARCH-07] post-cambio retornara un array con TODAS las sesiones del dia** (planificadas + rutina + libres). El atleta ve todas y elige cual completar o agrega mas.

**Plan Builder como hub unico (BUILDER-03):** para atletas CON plan activo, el coach gestiona las sesiones de fuerza desde el Plan Builder. Los cards de AssignedWorkout aparecen como sugerencias clickables en cada dia — un click crea una PlannedSession tipo FUERZA con el workoutDayId ya seteado. No hay drag-and-drop, es one-click.

## Flujo de sesion — desde "comenzar" hasta "completar"

El flujo de ejecucion de una sesion de gym es el core del modulo. Aplica a los 3 caminos (plan FUERZA, rutina, sesion libre).

```
1. Atleta ve sesion del dia
   GET /api/athlete/gym/session/today (web) o GET /api/mobile/gym/today (mobile)
   → Retorna ejercicios con sets esperados, sugerencia de carga, restSeconds
   → Si es plan FUERZA: ejercicios del WorkoutDay enlazado
   → Si es rutina: ejercicios del WorkoutTemplate activo para ese dia de la semana
   → Si es libre: lista vacia — el atleta elige ejercicios de la biblioteca

2. Atleta toca "Comenzar sesion"
   → Carga la pantalla de tracking (gym/session web, gym-session mobile)
   → Ve la lista de ejercicios con sets/reps/peso esperados
   → Si es libre: busca y agrega ejercicios de la biblioteca (enciclopedia)

3. Por cada ejercicio, el atleta registra sets:
   → Ingresa peso (kg) y reps por cada set
   → Tipo de set: WORK (default) | WARMUP | DROPSET
   → Ve sugerencia de carga del sistema (suggestedNextWeightKg) como referencia
   → Al marcar set como completado:
      → Timer de descanso se activa automaticamente
      → restSeconds del coach es el default (configurable por ejercicio)
      → Atleta puede ajustar timer en sesion (+15s/-15s) sin persistir
      → Mobile: haptic feedback al iniciar y completar descanso
   → Al completar todos los sets del ejercicio:
      → RPE picker inline (1-10) — RPE individual por ejercicio, no solo de sesion
      → El RPE se guarda en cada SetLog del ejercicio

4. Atleta toca "Completar sesion"
   POST /api/athlete/gym/session/complete (web) o POST /api/mobile/gym/complete (mobile)

   Dentro del endpoint:
   a. Crea GymSession + SetLog[] en $transaction
      → GymSession incluye: energyState (EXHAUSTED/NORMAL/ENERGIZED), discomfort (NONE/MILD/MODERATE)
      → caloriesBurned auto-calculado (CPM x duracion por ejercicio)
      → exerciseOverrides (JSON) si el atleta sustituyo ejercicios mid-sesion
   b. PR detection: compara cada set contra max historico
      → Plan/rutina: compara por `exerciseId` (via `weExIdMap`)
      → Sesion libre: compara por `exerciseName` (no hay workoutExerciseId)
      → SetLog.isPR = true si supera el record (inmutable, no se recalcula)
      → PRs detectados en sesiones de rutina, plan Y libres
   c. Sugerencia de carga actualizada (suggestedNextWeightKg):
      → completedRatio > 0.9 → +2.5kg (subir)
      → completedRatio < 0.6 → -2.5kg (bajar)
      → Entre 0.6 y 0.9 → sin cambio
   d. Si es plan FUERZA: autoCompleteStrengthSession() crea SessionLog
      para que la adherencia del plan la cuente
   e. Notificaciones in-app (fire-and-forget, no bloquean la respuesta):
      → Al atleta si hay PRs: createNotification "Lograste N PR(s) en tu sesión de hoy. ¡Sigue así!"
      → Al coach (si B2B): notifyCoach() "X completó una sesión" con deep link al perfil del atleta
   f. Retorna { sessionId, newPRs[] }

5. Pantalla de resumen post-sesion
   → Si hay PRs: modal de celebracion con animacion (spring scale-in) + boton compartir
   → El volumen de la sesion (sets x reps x peso) se acumula en la vista semanal de /progress
   → Coach ve volumen semanal en su panel (GET /api/coach/gym/athlete/[id]/volume)
   → Historial del ejercicio: el atleta puede ver su progresion en /progress
```

**La biblioteca alimenta los 3 caminos:** los ejercicios de la enciclopedia (AscendAPI) son los mismos que el coach asigna en rutinas, los que aparecen en el plan FUERZA, y los que el atleta elige en sesion libre. No hay ejercicios "diferentes" por camino — la fuente es unica.

**Seguimiento y progresion:** cada sesion completada acumula datos que alimentan:
- **PRs** por ejercicio (max historico de peso x reps) → visible en /progress y panel coach
- **Curva de fuerza** (1RM estimado) → tendencia por ejercicio en el tiempo
- **Sugerencia de carga** → el sistema le dice al atleta si subir o mantener peso
- **Calorias estimadas** → auto-calculadas por sesion. Fuente: `Exercise.caloriesPerMinute` (si existe) o calculado desde `Exercise.met` (MET × peso atleta / 60). Visible en historial.
- **Estado fisico** → energyState y discomfort post-sesion. El coach ve la tendencia — si el atleta reporta EXHAUSTED o MODERATE discomfort seguido, es senal de sobreentrenamiento.
- **Adherencia** → sesiones completadas vs planificadas (unificado gym + running)
- **Volumen semanal** → total kg levantados, detectable en check-in (trigger `pico_volumen`)
- **Sustituciones** → exerciseOverrides registra que ejercicios cambio el atleta mid-sesion. El coach ve si el atleta evita ciertos ejercicios (posible molestia o falta de equipo).

## Plan vs Rutina -- dos herramientas, una vista del atleta

Plan y Rutina son herramientas separadas que sirven para cosas diferentes. El atleta NO ve la distincion — solo ve su calendario con las sesiones del dia.

| Concepto | Plan (`TrainingPlan`) | Rutina (`WeeklyRoutine` + `AssignedWorkout`) |
|----------|----------------------|----------------------------------------------|
| Naturaleza | **Progresivo** — semana 1 ≠ semana 8. Periodización por fases (BASE → DESARROLLO → ESPECÍFICO → AFINAMIENTO) | **Repetitivo** — misma estructura cada semana |
| Temporalidad | Fechas fijas, inicio/fin, semanas contadas | Cíclica sin fin — se repite hasta que se cambie |
| Objetivo | Llegar a una meta (carrera 10K en 12 semanas, recomposición) | Mantener consistencia, hábito, base |
| Disciplinas | Todas (running + fuerza + ciclismo + otras) | **[Estado actual]** Solo gym/fuerza. **[ARCH-11 pendiente]** Todas las disciplinas construidas en el sistema |
| Quien asigna | Coach o atleta Pro (self-coach) | Coach o atleta (cualquiera) |
| Modelo de sesion | `PlannedSession` -> `SessionLog` / `GymSession` | Gym: `AssignedWorkout` -> `GymSession`. Otras disciplinas: `WeeklyRoutine.days` -> sesión libre |
| Adherencia | Contada en adherencia del plan | Contada en adherencia de rutina |
| Routing actual | `getTodaySession` retorna 1 sesión con prioridad: AssignedWorkout > plan FUERZA > libre. **[ARCH-07 pendiente]** Post-cambio: sin prioridad, todas las sesiones del día conviven en un array. |

**[ARCH-11 — Rutina multi-disciplina]** La rutina debe poder incluir cualquier disciplina construida en el sistema. Cada disciplina tiene su propia lógica (running: intervalos, zonas, pace; ciclismo: potencia, cadencia; natación: largos, estilos). Que el sistema hoy solo modele gym con profundidad no significa que las demás no tengan estructura — se construirán con sus bibliotecas de ejercicios y formas de registro. La rutina las integra automáticamente como opciones. Gym sigue usando `AssignedWorkout/WorkoutTemplate` (necesita ejercicios/series/reps/peso). Las otras disciplinas se modelan en `WeeklyRoutine.days` con campos propios por disciplina.

**Exclusion mutua:** `GymSession` es de rutina O de plan, nunca ambos. No hay CHECK SQL — la exclusion mutua `assignedWorkoutId`/`plannedSessionId` se enforcea por logica de aplicacion.

## Sesion libre -- el atleta elige su disciplina (flujo de tracking)

El atleta puede registrar sesiones libres **en cualquier momento**, con o sin plan/rutina activos. La sesion libre es actividad que no estaba planificada ni es parte de la rutina — es iniciativa propia del atleta.

| Disciplina | Campos disponibles | Modelo DB |
|-----------|-------------------|-----------|
| Gym / Fuerza (`STRENGTH`) | Ejercicios con series, reps, carga (kg). PR detection activa. | `GymSession` + `SetLog` |
| Running (`RUNNING`) | Distancia (km), duracion (min), FC media/maxima, RPE | `SessionLog` (pace se calcula en UI desde distancia/duración, no es columna) |
| Ciclismo (`CYCLING`) | Distancia (km), duracion (min), FC | `SessionLog` |
| Natacion (`SWIMMING`) | Distancia (km), duracion (min) | `SessionLog` |
| Otro (`OTHER`) | Duracion (min), RPE, notas | `SessionLog` |

> **"Funcional"** no es una disciplina separada — es un objetivo de rutina (`WorkoutTemplate.goal = 'FUNCTIONAL'`). Se registra como `STRENGTH` con ejercicios de la misma biblioteca gym.

**Descanso**: No es una disciplina de sesion libre. Hay dos formas de descanso en el sistema:
1. **Planificado por coach**: `PlannedSession` tipo `DESCANSO` — aparece en el calendario del atleta como dia de recuperacion intencional.
2. **Dia sin actividad**: El atleta simplemente no registra nada. No bloquea ninguna funcionalidad — puede registrar una sesion libre en cualquier momento si cambia de opinion.

**Dos modelos de sesion separados -- por diseno:**
- `SessionLog` para running/cardio: distancia, pace, FC, zonas HR
- `GymSession` + `SetLog` para fuerza/gym: ejercicios, series, reps, carga, PRs

Son tablas diferentes porque los datos son fundamentalmente distintos. La unificacion ocurre en la capa de dominio (`TrainingActivity` en `src/domain/training/`) para metricas y adherencia.

## Un atleta, una rutina activa

- Un atleta solo puede tener un `AssignedWorkout` activo a la vez
- Al asignar una nueva rutina -> la anterior se desactiva automaticamente
- El coach define la rutina, el atleta la ejecuta -- el coach nunca registra sets

## El atleta puede crear su propia rutina (self-coach)

Un atleta B2C sin coach puede crear su propia rutina estructurada desde la app:
- Define dias de entrenamiento (ej. Lun: Upper, Mie: Lower, Vie: Fullbody)
- Agrega ejercicios por dia desde la biblioteca
- La rutina queda guardada y se carga automaticamente en sus sesiones
- Si luego el coach le asigna una rutina -> la del coach reemplaza la del atleta

**WeeklyRoutine (estructura basica):** el atleta sin coach ni rutina tiene una `WeeklyRoutine` creada en onboarding. Define que actividad hace cada dia de la semana (`{dow, activity: "GYM"|"RUN"|"REST", split: "PUSH"|"PULL"|...}`). `getTodaySession()` la usa como fallback para sugerir el tipo de sesion del dia cuando no hay plan ni rutina asignada.

**Regla de precedencia:** coach > atleta. La rutina del coach siempre tiene prioridad.

## Progresion de cargas -- el atleta controla, el coach sugiere

- El atleta registra sus propias cargas en cada set -- no hay obligacion de seguir ninguna sugerencia
- `WorkoutExercise.suggestedNextWeightKg` es una **referencia**, no un requisito para completar la sesion
- El coach puede ver las cargas historicas del atleta y sugerir incrementos o ajustes desde su panel
- El sistema calcula sugerencia de carga según `completedRatio` (sets completados / sets requeridos):
  - `completedRatio > 0.9` (>90%) → `suggestedNextWeightKg = max(weightKg) + 2.5` — subir carga
  - `completedRatio < 0.6` (<60%) → `suggestedNextWeightKg = max(max(weightKg) - 2.5, 0)` — bajar carga
  - Entre 0.6 y 0.9 → sin cambio de sugerencia
- La curva de fuerza (1RM estimado) es visible en `/progress`. Hay dos formulas segun contexto (intencional, no es bug):
  - **Epley** `kg * (1 + reps/30)` — atleta mobile (`/mobile/gym/prs` y `get_progress_data.use_case.ts`). Mas conservador — evita que el atleta sobreestime su capacidad.
  - **Brzycki** `peso * (36 / (37 - reps))` — panel coach (`SessionsTab.tsx`). Mas preciso para rangos bajos de reps — el coach necesita datos exactos para programar.

**No completar los sets requeridos o usar cargas menores NO bloquea la sesion.** El registro es lo que vale.

## PR detection -- reglas

- PR se detecta en `POST /api/athlete/gym/session/complete`
- Dos funciones segun camino:
  - `collectPRsByWeId` → rutina y plan: usa `workoutExerciseId` → mapa a `exerciseId` para comparar. Si el coach edita la rutina, fallback `weNameToWeIdMap` recupera PRs huerfanos por nombre.
  - `collectPRsByName` → sesion libre: usa `exerciseName` directamente (no hay `workoutExerciseId`).
- `SetLog.workoutExerciseId` es nullable -- preserva historial si coach edita la rutina
- `SetLog.isPR = true` se persiste en DB -- no se recalcula despues
- PR detection activa en sesiones de rutina, plan Y libres
- **Dedup de sesion**: el orchestrator detecta sesiones ya completadas (`alreadyCompleted: true`) y retorna el ID existente sin crear duplicados. Protege contra double-tap en mobile/web.

## Benchmarks de rendimiento (`PerformanceBenchmark`)

Tests formales de capacidad del atleta: `1RM_SQUAT`, `1RM_BENCH`, `5K_TIME`, etc.

- **El atleta los registra** -- son datos que el mismo ingresa despues de un test
- El coach puede pedirle al atleta que haga un test formal via nota en la sesion
- El atleta los ve en su perfil de progreso -- referencia de base y evolucion
- El coach los ve en el Tab Rendimiento del perfil del atleta
- **Estado actual:** implementado. Endpoints: `api/athlete/progress/benchmarks/route.ts` (web) + `api/mobile/progress/benchmarks` (mobile).

## Que puede hacer el coach en ejercicios

El coach tiene dos capacidades en este modulo: **gestionar la biblioteca** y **hacer seguimiento del atleta**.

**Gestionar biblioteca y rutinas:**
- Crear ejercicios custom (`source = 'custom'`) visibles solo para el y sus atletas
- Crear rutinas (`WorkoutTemplate`) con dias, ejercicios, series, cargas sugeridas, descansos
- Copiar rutinas (deep clone con ejercicios y supersets preservados)
- Asignar rutina a atleta → desactiva la anterior automaticamente → notificación in-app al atleta
- Desasignar rutina (DELETE) → el atleta queda en modo libre

**Seguimiento del atleta — adherencia, no realtime:**

El coach NO recibe alertas en tiempo real. Entra al perfil del atleta cuando quiere hacer seguimiento:

```
Coach abre perfil del atleta → Tab Ejercicios
  → Adherencia semanal: % sesiones completadas vs asignadas (ultimas 4 semanas)
  → Volumen semanal: kg levantados esta semana vs la anterior (delta %)
  → PRs por ejercicio: 1RM estimado (Brzycki) agrupado por musculo
  → Historial: ultimas N sesiones con sets, cargas, RPE, isPR por set
  → Sustituciones: ejercicios cambiados por el atleta mid-sesion
  → Estado fisico: tendencia de energyState y discomfort post-sesion
  → Rutina activa: asignacion actual + sesiones recientes
```

**Excepcion al "no realtime":** el coach recibe push notification cuando el atleta completa una sesion ("X completo una sesion"). No es alerta de urgencia — es señal de actividad.

**Por que no realtime completo:** el valor de Medaliq para el coach es ampliar su alcance — tener 25 atletas bien gestionados. El panel de adherencia es la senal de gestion, no un dashboard en vivo.

## Metricas de progreso -- periodos

| Periodo | Uso |
|---------|-----|
| Semanal | Dashboard principal del atleta -- semana en curso |
| Mensual | Tendencia de consistencia |
| Trimestral (3 meses) | Ciclo de entrenamiento |
| Semestral (6 meses) | Progresion de fuerza y composicion corporal |
| Anual | Hito de largo plazo |

**Estado actual:** solo existe vista semanal en el dashboard y en `/progress`. Las demas son roadmap.

## Schema -- campos clave

### Exercise
- `nameEs String?` -- nombre en espanol del dataset WorkoutX (DB-13). AscendAPI no provee `nameEs` — ejercicios del catalogo activo tendran `nameEs = null` y mostraran nombre en ingles.
- `instructionsEs String[]` -- instrucciones en espanol (DB-13)
- `videoUrl String?` -- YouTube URL o Vercel Blob URL de referencia tecnica (DB-16)

### WorkoutExercise
- `restSeconds Int?` -- descanso recomendado entre sets en segundos (DB-14)
- `setType SetType @default(NORMAL)` -- tipo de agrupacion: `NORMAL | SUPERSET | BISERIE | DROPSET | CIRCUIT`

### SetLog
- `setLogType SetLogType @default(WORK)` -- tipo de set: `WORK | WARMUP | DROPSET` (DB-15)
  - `WORK` -> cuenta para volumen y PR detection
  - `WARMUP` -> excluido de volumen y PRs
  - `DROPSET` -> excluido de PR detection, incluido en volumen
- `rpe Int?` -- Rating of Perceived Exertion 1-10 (DB-15)
- `isPR Boolean @default(false)` -- inmutable una vez guardado

## Lo que NO hace el modulo

- No prescribe ejercicios especificos al atleta sin coach -- el atleta elige o el coach asigna
- No bloquea la sesion por carga insuficiente o sets incompletos
- No recalcula PRs historicamente -- `isPR` es inmutable una vez guardado
- No genera rutinas automaticamente desde templates

---

## Scope deseado -- no priorizado (analisis competitivo 2026-08)

Features identificadas tras analisis competitivo. **No implementar sin decision explicita de Miguel.** Detalle tecnico en roadmap (`roadmap_data.ts`).

### Audio coaching en sesion (DESIRED-01)

Cues de voz en-ear que guian al atleta durante la sesion sin que tenga que mirar la pantalla. Ladder lo usa como diferenciador principal.

**Opciones de implementacion:**
- `expo-av` + Text-to-Speech nativo (iOS `AVSpeechSynthesizer`, Android TTS)
- Clips de audio grabados por el coach -- personalizados pero requieren infraestructura de media

**Logica de timing**: disparar el cue en funcion del estado de la sesion (inicio de set, fin de set, inicio de descanso, fin de descanso). El timer de descanso ya existe -- ese es el punto de integracion natural.

### Diagramas anatomicos dinamicos (MVP-08)

Reemplazar/complementar los SVGs propios (`MuscleMap.tsx` mobile, `MuscleMapWeb` web) con diagramas anatomicos HD por genero. Casos de uso: vista de ejercicio individual, resumen post-sesion, cobertura semanal del coach, deteccion de gaps musculares. Ya tenemos `targetMuscles`/`secondaryMuscles` en DB para alimentar las visualizaciones. Ver MVP-08 en roadmap para opciones de proveedor (AscendAPI Muscle Visualizer, alternativas open-source).
