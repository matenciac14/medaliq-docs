# Flujos por Actor
# Qué puede hacer cada actor, en qué módulo, con qué endpoint y bajo qué restricción.
# [roadmap] = no implementado · [parcial] = implementado con gaps conocidos · sin marca = implementado
# Para reglas de negocio profundas → leer el domain doc del módulo correspondiente.

**Domain docs:** `atleta.md` · `coach.md` · `nutricion.md` · `entrenamiento.md` · `plan.md` · `pagos.md` · `plataforma.md` · `flujos-cruzados.md`

> **Nota para agentes:** los endpoints listados en este archivo están documentados desde el contexto de los CLAUDE.md y domain docs — no verificados línea a línea contra el código. Antes de usar un endpoint, confirmar que existe con `Glob` en `src/app/api/` o `MEDALIQ-MOBILE/src/api/`. Los marcadores `[roadmap]` y `[parcial]` indican que el endpoint puede no existir aún.

---

## Atleta B2C Free

Usa el sistema como **tracking** de entrenamiento y nutricion.

**Entrenamiento:** el sistema soporta multiples disciplinas (gym, running, natacion, etc.) que se van habilitando progresivamente. Cada disciplina tiene su propia logica de registro y seguimiento. En gym, el sistema provee una biblioteca de ejercicios que el atleta selecciona por grupo muscular y preferencia — detalles especificos en `entrenamiento.md`.

**Nutricion:** despues del onboarding, el sistema propone una distribucion de macros diaria segun el objetivo del atleta. El atleta registra su alimentacion diaria (buscar alimentos, registrar comidas consumidas) y el sistema le muestra metricas de lo registrado en ese dia vs su target — detalles en `nutricion.md`.

Features activas: `featureLog` · `featureNutrition` · `featureGym`
Features inactivas: `featurePlan` · `featureCheckin` · `featureProgress`
**Nota beta:** `getUserPlan()` hardcodea PRO — todos tienen acceso completo hasta activar Wompi.

### Entrenamiento
Modulo unificado con multiples disciplinas (gym, running, natacion, etc.). Cada disciplina tiene su logica de registro — ver `entrenamiento.md`.

| Acción | Disciplina | Endpoint | Restricción |
|--------|-----------|----------|-------------|
| Registrar sesión libre | Todas | `POST /api/athlete/log/session` · `/api/mobile/log/session` | — |
| Ver historial unificado | Todas | `GET /api/athlete/log/sessions` · `/api/mobile/log/sessions` · `/log/history` | Free: ultimos 30 dias. Pro/B2B: completo desde suscripcion |
| Ver sesiones de gym del día | Gym | `GET /api/athlete/gym/session/today` | Sin rutina asignada → muestra plantillas públicas. [ARCH-07] Hoy retorna 1 sesión — post-ARCH-07 retornará array |
| Completar sesión gym (PR detection) | Gym | `POST /api/athlete/gym/session/complete` · `/api/mobile/gym/session/complete` | Cada sesión se completa independientemente |
| Ver rutina semanal con adherencia | Gym | `/gym` (server page) | Requiere `AssignedWorkout.isActive=true`. Sin rutina → plantillas públicas |
| Explorar biblioteca de ejercicios | Gym | `/gym/exercises` | Solo librería global (`coachId=null`). 48/página. WorkoutX free=10, pagado=1,300+ |
| Crear rutina propia (self-coach) | Gym | `POST /api/athlete/routines` | `WorkoutTemplate` personal — coach la reemplaza si asigna una |
| Ver sesiones del plan en calendario | Todas | ❌ requiere `featurePlan` | — |
| Ver curva de fuerza y progresión | Gym | ❌ requiere `featureProgress` | — |

### Nutrición
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Ver target diario (kcal + macros) | `GET /api/athlete/nutrition` · `/api/mobile/nutrition` | Onboarding crea `NutritionPlan` automáticamente. No hay feature gate — todos acceden |
| Registrar alimento (FoodLog) | `POST /api/athlete/nutrition/log` · `/api/mobile/nutrition/log` | — |
| Buscar alimentos en biblioteca global | `GET /api/athlete/nutrition/foods` · `/api/mobile/nutrition/foods` | Filtra `isActive: true` — nunca filtrar por `createdBy` |
| Proponer alimento nuevo | `POST /api/athlete/nutrition/foods/propose` · `/api/mobile/nutrition/foods/propose` | Crea `Food isVerified:false` + `FoodProposal PENDING`. Implementado web + mobile. |
| Ver estado de mis propuestas | `GET /api/athlete/nutrition/foods/my-proposals` · `/api/mobile/nutrition/foods/my-proposals` | Implementado web + mobile. |

---

## Atleta B2C Pro — añade sobre Free

Todo lo del Free **mas** la capacidad de **autogestionar su entrenamiento y nutricion** como si fuera su propio coach. Puede planificar ejercicios, organizar rutinas, ver historial completo y programar entrenamientos hasta su fecha de corte de suscripcion.

Features: todas activas. $9.99/mes · $79.99/año.
Historial completo desde la fecha de suscripcion. Si baja a Free, pierde acceso al historial anterior a 30 dias.

| Módulo | Acción | Endpoint | Restricción |
|--------|--------|----------|-------------|
| Plan | Ver plan con sesiones | `GET /api/athlete/plan` · `/api/mobile/plan` | Pro se autogestiona — planifica hasta su fecha de corte |
| Plan | Ver sesión del día | `GET /api/athlete/plan/session/today` · `/api/mobile/plan/session/today` | — |
| Plan | Registrar ejecución de sesión del plan | `POST /api/athlete/log/session` con `plannedSessionId` | Vincula `SessionLog` a `PlannedSession` |
| Check-in | Enviar check-in semanal | `POST /api/athlete/checkin` · `/api/mobile/checkin` | Recopilación de datos solamente (R3/R4). Guarda peso y FC reposo en HealthProfile. Genera sugerencias para COACH plans — atleta/coach decide aceptar |
| Check-in | [parcial] Pantalla de resultado post check-in | — | Check-in funciona — pantalla que muestra al atleta qué cambió no existe aún |
| Check-in | Ver historial | `GET /api/athlete/checkin/history` · `/api/mobile/checkin/latest` | — |
| Progreso | Ver métricas (volumen, adherencia, peso, tendencias) | `GET /api/athlete/progress` · `/api/mobile/progress` | Activo tras primer check-in |
| Progreso | Registrar / ver benchmarks | `POST/GET /api/athlete/progress/benchmarks` · `/api/mobile/progress/benchmarks` | Implementado web + mobile. Coach ve en `/api/coach/athletes/[id]/benchmarks` |

---

## Atleta B2B — diferencias sobre Pro

Features: las que el coach activó vía `PATCH /api/coach/athletes/[id]/config`. $0 — incluido en tier del coach.
Sin activar → `/pending`. Ver `flujos-cruzados.md §Flujo 4`.

**Si la relacion de coaching termina** (coach pausa o desvincula al atleta), el atleta **revierte a B2C** con las features de su tier personal (Free o Pro). No pierde su cuenta ni su historial — solo pierde la capa del coach.
Historial completo sin restriccion de 30 dias.

| Módulo | Diferencia B2B | Endpoint | Restricción |
|--------|---------------|----------|-------------|
| Nutrición | Ve "Plan de tu coach" si hay `AssignedNutritionPlan` (toma precedencia sobre MealPlan del sistema) | `/nutrition` (server page) · `/api/mobile/nutrition/today` | El plan del coach siempre gana. Badge "Plan de tu coach: [nombre]" visible. Mobile: `CoachBanner` + `MealChecklistInline` + `CoachCTA` (2026-09-10) |
| Nutrición | Propuesta de cambio de macros del coach (`CoachNutritionProposalCard`) | `GET /api/athlete/nutrition` · `POST /api/coach/athletes/[id]/nutrition/propose` | Atleta SIEMPRE acepta/rechaza — el coach no puede forzarlo |
| Plan | Ve sesiones publicadas por el coach en su calendario | `GET /api/athlete/plan` · `/api/mobile/plan` | Implementado |
| Gym | Ve rutina asignada por el coach (`AssignedWorkout`) | `/gym` (server page) | Coach la asigna con `POST /api/coach/gym/routines/[id]/assign`. Reemplaza rutina anterior |
| Finanzas | [roadmap] Ve fecha de vencimiento de su asesoría | `GET /api/athlete/payments/upcoming` | Endpoint no existe. Solo la fecha — NO el monto |
| Dashboard | `CoachCard` visible con nombre del coach | `/dashboard` (server page) | Visible siempre que `CoachAthlete.status = 'ACTIVE'` |

---

## Coach

Acceso web-first. Sin `identification` + `phoneWa` completados (campos en modelo `User`) → bloqueado en `POST /api/coach/clients/create`.
Tiers, pricing y definición de atleta activo: ver `pagos.md`.

### Gestión de atletas
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Crear atleta nuevo | `POST /api/coach/clients/create` | 402 si `activeCount >= maxAthletes` del tier |
| Vincular atleta B2C existente | `POST /api/coach/clients/link` | — |
| Listar / ver perfil de atleta | `GET /api/coach/clients` · `/api/coach/athletes/[id]` | Solo los propios — verificar `CoachAthlete.status = 'ACTIVE'` |
| Activar atleta (todas las features PRO) | `PATCH /api/coach/athletes/[id]/status` `{ status: 'ACTIVE' }` | Activa todas las features automáticamente — no hay toggles individuales. B2B activo = PRO |
| Configurar notas / objetivo del atleta | `PATCH /api/coach/athletes/[id]/config` | Solo `coachGoal` y `privateNotes` — NO toca features |
| Pausar atleta | `PATCH /api/coach/athletes/[id]/status` `{ status: 'PAUSED' }` | Revierte features a B2C Free automáticamente. Ocurre también cuando se vence el plan (fecha de corte) |
| [roadmap] Desvincular atleta | — | Coach elimina la relación definitivamente cuando el asesorado no volverá — sin registro residual |
| Cambiar coach del atleta | ❌ | Solo admin puede hacerlo |

### Entrenamiento (todas las disciplinas)
El coach diseña planes y rutinas según su especialidad. Un plan puede combinar disciplinas (ej: triatleta con 2 sesiones/día de disciplinas diferentes).

| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Asignar plan al atleta (por semanas) | `POST /api/coach/athletes/[id]/plan` | `PlanSource: 'COACH'`. Requiere `HealthProfile` del atleta (400 si falta). Usa benchmark 5K últimos 90 días para calibrar ritmos |
| Crear plan desde template | `POST /api/coach/athletes/[id]/plan/from-template` | — |
| Publicar sesión individual en calendario | `POST /api/coach/athletes/[id]/sessions` | Implementado. [pendiente] No envía notificación push al atleta |
| Ver calendario del atleta (historial vs plan) | `GET /api/coach/athletes/[id]/sessions` | — |
| Copiar sesión a semana de otro atleta | `POST /api/coach/sessions/[sessionId]/copy-to` | `{ targetWeekId, dayOfWeek }` — reutilización de sesiones |
| Editar sesión publicada | `PATCH /api/coach/athletes/[id]/sessions/[sessionId]` | — |
| Crear / listar WorkoutTemplate (rutinas gym) | `POST/GET /api/coach/gym/routines` | — |
| Asignar rutina al atleta | `POST /api/coach/gym/routines/[id]/assign` | Desactiva rutina anterior del atleta automáticamente |
| Ver historial gym del atleta | `GET /api/coach/athletes/[id]/gym` | Solo lectura — NUNCA registra sets |

### Nutrición (NUTRITION / ALL)
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Crear / editar / eliminar plantilla | `POST/PATCH/DELETE /api/coach/nutrition/templates[/id]` | Plantilla tiene `coachId` (privada). Preview de kcal/macros por día tipo (HARD/EASY/REST) visible en `/coach/nutrition` |
| Asignar plantilla al atleta | `POST /api/coach/nutrition/templates/[id]/assign` | Crea `AssignedNutritionPlan`. El atleta la ve como "Plan de tu coach" en `/nutrition` — toma precedencia sobre MealPlan del sistema |
| Ver FoodLog del atleta (últimos 7 días) | `GET /api/coach/athletes/[id]/nutrition` | Solo lectura — NUNCA modifica FoodLog |
| Ver adherencia nutricional (28 días) | `GET /api/coach/athletes/[id]/nutrition/adherence` | Devuelve `{ days: DayAdherence[], targetKcal }`. UI: `NutritionAdherenceCard` con sparkline 4 semanas |
| Proponer ajuste de macros al atleta | `POST /api/coach/athletes/[id]/nutrition/propose` | Crea `CoachNutritionProposal`. Atleta ve `CoachNutritionProposalCard` — acepta/rechaza. NUNCA se aplica sin confirmación |

### Seguimiento
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| [roadmap] Ver check-ins del atleta | `GET /api/coach/athletes/[id]/checkins` | Endpoint no existe — coach ve datos indirectos via dailylogs y training-adherence |
| Ver adherencia al plan | `GET /api/coach/athletes/[id]/adherence` | % sesiones completadas vs planeadas |
| Ver benchmarks del atleta | `GET /api/coach/athletes/[id]/benchmarks` | Implementado — coach ve benchmarks del atleta |
| Registrar sesión / check-in por el atleta | ❌ | NUNCA — el atleta registra sus propios datos |

### Finanzas (cobros a atletas — Medaliq no toca el dinero)
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Crear cobro | `POST /api/coach/payments` | Audit: `CREATED`. Rate limit 60/min |
| Listar cobros | `GET /api/coach/payments` | Auto-marca `OVERDUE` al leer. `take: 500` |
| Marcar como pagado / revertir | `PATCH /api/coach/payments/[paymentId]` | Audit: `MARKED_PAID` / `REVERTED`. `$transaction` |
| Eliminar cobro | `DELETE /api/coach/payments/[paymentId]` | Audit: `DELETED`. `$transaction` |
| [roadmap] Enviar recordatorio | `POST /api/coach/payments/[id]/remind` | Endpoint no existe |
| [roadmap] Cron pagos vencidos | `CRON-08 payment-overdue` | Desactivado — reactivar con billing live |

**Futuro**: cuando Medaliq se posicione como plataforma de confianza, se habilitará cobro directo al asesorado con pago al entrenador. Feature post-lanzamiento — generará fricción inicial.

### Autogestión del coach (entrenamiento + nutrición propios)
El coach también entrena y come. Necesita paneles constructores de rutinas y nutrición similares a los del atleta Pro para gestionar su propio entrenamiento y alimentación.

| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| [roadmap] Gestionar su propia rutina de gym | — | Constructor similar al del atleta Pro |
| [roadmap] Gestionar su propia nutrición | — | Tracking de macros y registro de alimentos propio |

### Perfil y suscripción
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Editar perfil público | `PATCH /api/coach/profile` | Unicidad de `identification` + `phoneWa` solo para COACH |
| Aparecer en directorio `/coaches` | Automático con `status = ACTIVE` | Página existe pero sin feature guard. [ARCH-10] Agregar env var para ocultar hasta tener tracción |
| Ver métricas de suscripción | `GET /api/coach/billing` | Tier actual + atletas activos vs límite |

---

## Admin

Acceso exclusivo `role = 'ADMIN'`. Ver reglas en `plataforma.md`.

### Gestión de usuarios
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Ver / cambiar rol / cambiar tier | `GET/PATCH /api/admin/users[/id]` | Cambio de tier manual hasta conectar Wompi |
| [roadmap PLT-01] Bloquear usuario | `PATCH /api/admin/users/[id]` `{ status: 'BLOCKED' }` | Bloquea acceso a la app — conserva todos los datos. No elimina cuenta |
| Cambiar coach asignado a atleta | `PATCH /api/admin/users/[id]` | Único actor que puede hacerlo |

### Biblioteca de alimentos
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Ver propuestas pendientes | `GET /api/admin/nutrition/proposals` | — |
| Aprobar / rechazar propuesta | `POST /api/admin/nutrition/proposals/[id]` `{ action: 'APPROVE'|'REJECT' }` | `Food.isVerified → true` o `isActive → false` |

### Métricas y configuración
| Acción | Endpoint | Restricción |
|--------|----------|-------------|
| Ver KPIs del negocio | `/admin/metrics` | Implementado: check-ins totales/semana, session logs, planes activos, WAU (8 semanas), retención por semana, distribución geográfica por timezone, segmentación B2C vs B2B |
| Ver métricas financieras | `/admin/finanzas` | [roadmap] Módulo completo post-activación de pagos: MRR real, churn, ingresos por tier, pagos coach→atleta, trazabilidad financiera del negocio |
| Sincronizar biblioteca de ejercicios | `/admin/exercises` (SyncButton) | Llama WorkoutX API — actualiza `Exercise` table |
| Gestionar roadmap | `/admin/roadmap` | Fuente canónica: `src/app/admin/roadmap/roadmap_data.ts` |

### Automatizaciones (cron jobs)
| Cron | Schedule | Qué hace |
|------|----------|---------|
| `session-reminder` | diario | Recuerda a atletas con sesión pendiente hoy |
| `checkin-reminder` | semanal | Recuerda a atletas que no hicieron check-in esta semana |
| `payment-overdue` | diario | Notifica pagos vencidos coach→atleta |
| `pending-athlete-reminder` | diario | Recuerda a coaches atletas que no completaron onboarding |
| `expire-suggestions` | diario | Expira `CheckInSuggestion` viejas |
| `billing-check` | diario | Verifica estado de suscripciones (grace period=3 días, downgrade si vence) |
| `billing-renewal-reminder` | diario 1pm UTC | Envía email con nuevo link de pago Wompi a suscripciones que vencen en 7 días |
| `inactive-athlete-reminder` | diario | Alerta coaches con atletas inactivos (sin actividad 7+ días) |
| `streak-risk` | diario | Avisa a atletas en riesgo de perder su racha |
| `nutrition-alert` | diario 09:00 | Alerta coaches: atleta con 3 días seguidos de adherencia <60% |

Todos los crons están en `src/app/api/cron/*/route.ts`. Autenticados con header secret — no son invocables públicamente.

**Nota**: los crons son el motor de retención del sistema. Refinar horarios, frecuencias y contenido de cada notificación cuando la funcionalidad core esté confirmada — post-lanzamiento.

---

## Reglas transversales críticas

Las más peligrosas si se omiten — aplican a todos los actores:

| Regla | Domain doc |
|-------|------------|
| Nunca confiar en `userId` del body — siempre de la sesión/JWT | `seguridad.md` |
| Coach verifica `CoachAthlete.status = 'ACTIVE'` antes de actuar sobre un atleta | `coach.md` |
| El atleta SIEMPRE acepta/rechaza ajustes — ni el coach ni el sistema modifican sin su confirmación | `nutricion.md` |
| `FoodLog.snapshot` no nulo → usar snapshot (inmutable). Nulo → calcular desde `food.*` | `nutricion.md` |
| El sistema NUNCA auto-modifica planes ni nutrición (R3/R4/R5). Check-in = datos solamente | `plan.md` · `nutricion.md` |
| Entrenamiento es un módulo unificado con disciplinas — no módulos separados por deporte | `entrenamiento.md` |
| El coach NUNCA registra sesiones, check-ins ni logs por el atleta — el atleta registra sus propios datos | `coach.md` |
| Un día puede tener N sesiones de cualquier disciplina — no hay límite de 1 sesión por día [ARCH-07] | `flujos-cruzados.md` · `entrenamiento.md` |
