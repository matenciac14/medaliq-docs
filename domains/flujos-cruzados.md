# Domain: Flujos Cruzados
# Flujos que tocan múltiples módulos simultáneamente.
# Verificado contra el código fuente — no inferido de documentación.
> **Flujos por actor → `flujos-por-actor.md`** — qué puede hacer cada actor por módulo. Este archivo cubre los flujos que cruzan varios módulos.

## Flujo 1 — Check-in → ajuste de plan + nutrición

```
POST /api/athlete/checkin → processCheckIn(input, deps)

Fase 1 (fuera tx — reads paralelos):
  findLatest + findActivePlan + getAdherence + assignedWorkout + recentCheckIns (últimos 4) + weekActivity

Fase 2 (fuera tx — lógica pura):
  evaluateCheckInRules → triggers + adjustments
  Triggers generan recomendación de texto — determinista, desde adjustments.join('. ')

Fase 3 ($transaction):
  1. upsert WeeklyCheckIn por (userId, weekNumber)
  2. Si plan source=COACH y hay triggers → genera PlanSuggestion rows (el atleta/coach decide si acepta)
  3. syncWeight: si |peso reportado - HealthProfile.weightKg| >= 0.5 → updateWeight en perfil solamente.
     [R3 COMPLETADO] syncWeight solo guarda peso — sin recalculo de TDEE/macros.
  3b. syncHrResting: siempre actualiza HealthProfile.hrResting si heartRate > 0 (solo guarda dato)
  4. Primer check-in (count === 1, contado post-save) → enableFeature(userId, 'progress')
```

## Flujo 2 — Onboarding → perfil + features

```
POST /api/athlete/onboarding/generate → completeOnboardingUseCase

Detecta B2B: CoachAthlete.findFirst({ where: { athleteId } })

$transaction (ambas rutas):
  upsertNutrition + upsertProfile + completeOnboarding
  completeOnboarding seta onboardingCompleted=true + sportGoal en HealthProfile

B2C:
  Onboarding pregunta: "Aparte del gym, ¿qué otro deporte practicas?" → input libre o "ningún otro"
  Gym es la base garantizada para todos. Disciplinas adicionales se guardan en HealthProfile.
  completeOnboarding activa TODAS las features { plan:true, nutrition:true, progress:true, log:true, checkin:true, gym:true }
  Nota beta: en la práctica todos son PRO hasta activar Wompi. Post-billing: condicionar features según tier real del atleta (FREE vs PRO).
  WeeklyRoutine creada dentro del $transaction (para todos — B2B y B2C)
  planId: null — el plan lo asigna el coach (B2B) o el atleta Pro (self-coach). El sistema NO genera planes automáticamente.
  Sin plan activo → dashboard en modo FREE → atleta registra sesiones libres (EJ-02 implementado)

B2B (detectado por CoachAthlete.findFirst({ athleteId, status: 'ACTIVE' })):
  completeOnboarding seta onboardingCompleted=true pero SIN features (todas false)
  WeeklyRoutine creada dentro del $transaction (igual que B2C)
  Notificación al entrenador post-tx
  Atleta va a /pending — entrenador activa con PATCH /coach/athletes/[id]/status { status: 'ACTIVE' } → todas las features PRO automáticamente
```

## Flujo 3 — Log de sesión (eliminado: ajuste nutricional automatico)

> **ELIMINADO [R6 COMPLETADO].** `PendingNutritionAdjustment` removido del schema. Los ajustes nutricionales solo provienen del coach via `CoachNutritionProposal` (B2B).

## Flujo 4 — Coach activa atleta → features PRO automáticas → JWT mobile refresh

```
PATCH /api/coach/athletes/[id]/status
  body: { status: 'ACTIVE' }

$transaction:
  getTierFeatureConfig('B2B') → todas las features PRO (plan, checkin, nutrition, progress, log, gym)
  mergeFeatures(athleteId, allFeatures) → bloque atómico, no toggles individuales
  coachAthlete.update({ status: 'ACTIVE' })

Al pausar (status: 'PAUSED'):
  getTierFeatureConfig('B2C_FREE') → revierte a features Free (nutrition, log, gym activas — plan, checkin, progress inactivas)

Post-tx (fire-and-forget, sin await):
  Notificación push al atleta — "Tu entrenador te activó"

JWT mobile queda inmediatamente STALE:
  Las features están activas en DB pero el JWT del atleta tiene las features viejas.

Auto-refresh implementado:
  El servidor envía push notification con data.type = 'features_updated'
  _layout.tsx tiene listener → llama refreshUser()
  refreshUser() → POST /api/mobile/auth/refresh → nuevo JWT con features frescas
  El store se actualiza sin interrumpir al atleta (silencioso si falla)

Comportamiento mobile en 401:
  client.ts: clearToken() + useAuthStore.setUser(null) → pantalla de login
  El 401 ocurre cuando el JWT expira — el refresh proactivo lo previene en el caso B2B
```

**Endpoint:** `POST /api/mobile/auth/refresh` — reemite JWT con features frescas desde DB.
Rate limit: 10 req/min. Devuelve `{ token, features }`.
Si el push no llega (app en background, push deshabilitado), el atleta sigue viendo features viejas hasta que el JWT expire o reinicie sesión.

**Nota:** `/api/coach/athletes/[id]/config` NO toca features — solo maneja `coachGoal` y `privateNotes`.

## Flujo 5 — Marketplace → coach-atleta → activación B2B

```
Atleta descubre coach en /coaches (directorio público)
  → Ve perfil /p/[slug]
  → Click "Contactar" → WhatsApp del coach con mensaje pre-redactado
  → Acuerdan términos y precio fuera de la plataforma (Nequi, Daviplata, transferencia)
  → Coach crea al atleta en su panel: POST /api/coach/clients/create
      Si el atleta ya existe en Medaliq (B2C) → link: POST /api/coach/clients/link
      Si es nuevo → create: crea User + envía email con link de onboarding
  → Atleta completa onboarding → /pending (Flujo 2 B2B)
  → Coach activa features → JWT mobile queda stale (Flujo 4)
  → Atleta reinicia sesión → dashboard activo con plan del coach

Módulos cruzados: plataforma (marketplace) + coach + atleta + auth
Nota: Medaliq NO procesa el pago — 0% fee en la fase actual. Futuro: cobro directo al asesorado con pago al entrenador (post-confianza de mercado)
```

## Flujo 6 — Coach publica sesión → calendario del atleta → notificación

```
Coach abre perfil del atleta → Tab Plan → Vista calendario
  → Click en día → "Añadir sesión"
  → Define: disciplina, tipo de sesión, parámetros según disciplina (zona FC/pace para running, ejercicios/series para gym, etc.), nota al atleta
  → POST /api/coach/athletes/[id]/sessions (ARCH-03 implementado)
      Crea PlannedSession con fecha específica en el calendario del atleta

[pendiente] Post-tx notificación:
  → El endpoint NO envía notificación push al atleta actualmente
  → Debe agregar: Notification { type: 'PLAN_ACTUALIZADO' } + push si tiene token
  → Patrón existe en celebrate-pr y status — copiar approach

Atleta mobile:
  → Abre el calendario → ve la sesión del día con todos los detalles

Módulos cruzados: coach (panel) + plan (PlannedSession) + atleta (calendario) + plataforma (notificaciones)
```

## Flujo 7 — Plan completado → modo FREE → opciones del atleta

```
rawWeek > totalWeeks && now > endDate
  → Sistema marca TrainingPlan.status = 'COMPLETED'
  → Dashboard detecta lastCompletedPlanInfo → pantalla de celebración (roadmap)
      Muestra: nombre del plan, semanas completadas, sesiones X/Y

Atleta elige:
  Opción A — "Quiero otro plan":
    B2B: contacta a su coach → coach publica nuevas sesiones en el calendario
    B2C Pro: se autogestiona — crea su próximo plan como self-coach
    B2C Free: modo libre hasta encontrar coach o pasar a Pro

  Opción B — "Quiero un entrenador":
    Atleta busca coach en la plataforma → acuerda asesoría → pasa a B2B ($0 extra)
    No necesita ser Pro — el tier del coach cubre sus features

  Opción C — "Seguir entrenando libre":
    dashboardMode = 'FREE'
    Atleta registra sesiones libres sin estructura

En ambos casos: app disponible, nutrición activa, historial conservado — no hay limbo

Módulos cruzados: plan (estado del plan) + atleta (dashboard) + coach (si B2B)
Estado: pantalla de celebración no implementada — lastCompletedPlanInfo existe en código pero no se muestra
```

## Flujo 8 — Sesión libre del atleta → panel del coach

```
Atleta registra sesión libre (con o sin plan activo):
  POST /api/athlete/log/session (web) o POST /api/mobile/log/session (mobile)
    body: {
      discipline: 'GYM' | 'RUNNING' | 'NATACION' | 'CICLISMO' | 'OTRO',
      durationMin, rpe, notes,
      // opcionales según disciplina:
      distanceKm,          // running, ciclismo, natacion
      avgPaceSecPerKm,     // running
      exercises: [...]     // gym — opcional, puede ser solo "hice gym 45 min"
    }
    Crea SessionLog con discipline (no linkedTo PlannedSession)
    gym/session/complete queda exclusivo para sesiones planificadas o de rutina (con PR detection, vinculación a AssignedWorkout)
    [paridad pendiente] Web guarda `discipline` pero no `freeSessionType`. Mobile guarda `freeSessionType` pero no `discipline`.
    Fix: unificar en `discipline` como campo canónico. Deprecar `freeSessionType`.

Coach entra al perfil del atleta → Tab Plan o Tab Historial:
  → Ve SessionLog del atleta incluyendo sesiones libres (via /api/coach/athletes/[id]/running-logs)
  → Sesiones libres identificadas por discipline + sin plannedSessionId
  → Cuentan en la adherencia del atleta de la semana (denominador ajustado: solo semanas con plan activo)
  → El coach puede ver el volumen libre y decidir ajustar el plan de la siguiente semana

Nota de adherencia:
  Si el atleta tiene plan activo y registra sesiones libres ADICIONALES → adherencia puede superar 100%
  Si el atleta NO tiene plan activo → todas sus sesiones son libres → adherencia no aplica (no hay denominador)

Módulos cruzados: ejercicios/plan (SessionLog) + coach (panel de adherencia) + atleta (historial)
```

## Flujo 9 — Rutina del atleta vs rutina del coach — precedencia

```
Atleta B2C crea su propia rutina (EJ-02 — roadmap):
  POST /api/athlete/routines → WorkoutTemplate del atleta (isPublic=false, createdBy=athleteId)
  Se activa como AssignedWorkout del atleta

Coach le asigna una rutina al atleta (ya sea B2B o B2C con coach):
  POST /api/coach/gym/routines/[id]/assign
    → Crea nuevo AssignedWorkout para el atleta
    → AssignedWorkout anterior (del atleta o del coach) se desactiva automáticamente
    → Un atleta solo puede tener un AssignedWorkout activo a la vez

Precedencia para rutinas: coach > atleta — la rutina del coach siempre reemplaza la del atleta.
El atleta puede volver a activar su rutina propia si el coach la desvincula.

Módulos cruzados: ejercicios (AssignedWorkout) + coach (asignación) + atleta (rutina propia)
```

## Flujo 11 — Múltiples sesiones por día (ARCH-07 — roadmap)

```
[DECISIÓN DE PRODUCTO — pendiente de implementar]

Un día es un contenedor con N sesiones — como Garmin, Strava y TrainingPeaks.
El atleta puede tener 2+ sesiones el mismo día (ej: running AM + gym PM + sesión libre).

Fuentes de sesiones para un día:
  1. PlannedSession del plan (coach o Pro) — 0, 1 o más por día
  2. WorkoutDay de la rutina activa (AssignedWorkout) — 0 o 1 por día
  3. Sesiones libres del atleta — sin límite

Todas conviven. No hay prioridad excluyente — el atleta ve TODAS sus sesiones
del día en una lista y elige cuál completar o agrega más.

Estado actual (pre-ARCH-07):
  - La DB ya soporta N sesiones por día (sin constraints unique por fecha)
  - Toda la capa de display asume 1 sesión por disciplina por día:
    CalendarDay tiene 3 slots fijos (sport, gym, freeRun)
    getTodaySession retorna 1 objeto
    week-sessions tiene 1 slot por día
    Si hay 2 sesiones el mismo día, la segunda es INVISIBLE
  - No hay error ni warning al coach que cree 2 sesiones el mismo día

Cambios necesarios (ARCH-07):
  1. CalendarDay.sessions: SessionSlot[] — array en vez de 3 slots fijos
  2. getTodaySession → getTodaySessions — retorna array
  3. buildCalendarWeek — Maps acumulan arrays, no sobreescriben
  4. week-sessions API — cada día tiene sessions[] en vez de 1 slot
  5. Dashboard — todaySessions[] en vez de todaySession singular

Lo que NO cambia:
  - Plan y Rutina siguen como builders separados del coach
  - La DB no necesita migración
  - Adherencia ya funciona por sesión individual
  - PR detection y GymSession complete funcionan por sesión

Adherencia con N sesiones/día:
  - Planificadas completadas / planificadas totales = adherencia del plan
  - Sesiones libres extras no afectan el denominador
  - Coach ve: "cumplió 90% del plan + hizo 3 sesiones extra esta semana"

Módulos cruzados: calendario + dashboard + gym + plan + ejercicios
```

## Flujo 10 — Integración wearable → SessionLog + check-in auto-relleno (roadmap)

```
[FUTURO — no implementado. Documenta el flujo intendido cuando llegue la integración]

Atleta vincula Strava / Apple Health / Garmin (una vez, OAuth):
  → Token guardado en WearableConnection { userId, provider, accessToken, refreshToken }

Atleta completa actividad en su dispositivo:
  → Webhook o polling detecta la nueva actividad
  → Sistema mapea a SessionLog:
      distanceKm, durationMin, hrAvg, hrMax, avgPaceSecPerKm, caloriesBurned
      dataSource: 'STRAVA' | 'GARMIN' | 'HEALTHKIT'
      externalId: ID de la actividad en la plataforma externa (deduplicación)
  → Si ya existe un SessionLog pendiente para esa fecha → merge o link
  → Si es nuevo → crea SessionLog automáticamente

Check-in semanal:
  → hrResting: promedio de FC en reposo de la semana (desde wearable) → pre-rellena WeeklyCheckIn.heartRate
  → sleepHours: promedio de sueño de la semana → pre-rellena WeeklyCheckIn.sleepHours
  → El atleta puede editar los valores pre-rellenados antes de enviar

Módulos cruzados: integraciones (wearable) + plan/ejercicios (SessionLog) + check-in (WeeklyCheckIn) + atleta (historial)
Prerequisito: INT-05 (campos nuevos en SessionLog y HealthProfile) + tabla WearableConnection nueva
```
