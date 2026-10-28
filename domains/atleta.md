# Domain: Atleta
# Reglas de negocio no evidentes en el código. Leer antes de tocar cualquier feature de atleta.
> **Flujos por actor → `flujos-por-actor.md`** — qué puede hacer el atleta en cada módulo, con endpoints y restricciones de tier por actor (Free / Pro / B2B).
> Spec de implementacion: `../specs/onboarding.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Completa (24 páginas) |
| Mobile atleta | Completa (30+ pantallas) |
| Web coach | N/A |

## Visión del producto — dos capas independientes

El atleta es cualquier persona que quiera registrar y hacer seguimiento de su actividad deportiva y nutrición. El coach es una capa profesional encima — no un requisito.

```
Capa 1 — Tracker personal (cualquier usuario)
  → Modulo de entrenamiento con disciplinas (gym, running, etc.) — cada disciplina tiene su propia biblioteca de ejercicios. El atleta elige disciplina → ve ejercicios → registra sesion
  → Nutrición: calorías, macros, comidas (recetas en roadmap) — módulo completo en web y mobile
  → Plan del coach (B2B) — el sistema NO genera planes automáticamente post-onboarding
  → Sesiones libres sin plan: el atleta registra sesiones pasadas y puede crear sesiones futuras propias (self-coach path — EJ-02)
  → Progreso y métricas personales

Capa 2 — Plataforma de coaching (coach + atletas)
  → Coach asigna planes y nutrición personalizados
  → Coach hace seguimiento y cobra sus asesorías
  → El atleta del coach usa exactamente la misma app — sin diferencia de UX
```

Un atleta B2B pausado o sin coach activo sigue usando la app como Capa 1. No pierde acceso al producto.

## Dos modos de operación

| Modo | Cómo entra | Features | Activa |
|------|-----------|----------|--------|
| B2C | Se registra solo | Derivadas del tier (FREE/PRO) | Al completar onboarding |
| B2B | El coach lo crea | Todas false hasta que coach activa | Coach cambia status → ACTIVE vía PATCH /api/coach/athletes/[id]/status → aplica `computeAthleteFeatures('PRO')` automáticamente |

**El producto es para cualquier atleta** — registrar entrenamiento y nutrición de forma autónoma. El coach es una capa encima, no un requisito. Un atleta B2B pausado no queda bloqueado: revierte a B2C y sigue usando la app.

## Reglas de features

- **B2C FREE**: `featureLog + featureNutrition + featureGym = true` — registro de sesiones, nutrición y gym. Sin plan, sin check-in, sin métricas históricas.
- **B2C PRO**: todas true excepto `featureCoach` — el sistema sugiere mejoras siguiendo el rendimiento del atleta y mostrando métricas para que ajuste su plan, entrenamiento y nutrición.
- **B2B sin activar**: todas false → redirecta a `/pending`.
- **B2B activado**: siempre igual a B2C PRO por defecto — `configToAthleteFeatures(getTierFeatureConfig('B2B'))` aplicado automáticamente al activar. `TierFeatureConfig` es configurable por admin (los defaults coinciden con PRO pero son ajustables por tier). El coach paga para que sus atletas tengan acceso completo.
- `featureCoach` nunca es true para un atleta — es exclusivo de COACH.

**Precio por modo:**
- B2C Free: $0 permanente.
- B2C Pro: $9.99/mes — el atleta paga por sugerencias de plan periodizado, check-in con sugerencias de ajuste y métricas de progreso.
- B2B: $0 para el atleta — incluido en el tier del coach. El coach ya pagó por el acceso de sus asesorados. El atleta B2B nunca ve pantalla de pago.

## Reglas de activación por tier (B2C)

```
FREE  → { plan:false, checkin:false, nutrition:true,  progress:false, log:true, gym:true  }
PRO   → { plan:true,  checkin:true,  nutrition:true,  progress:true,  log:true, gym:true  }
```
> **Beta actual**: `getUserPlan()` retorna PRO cuando `BILLING_ENABLED !== 'true'`. Al activar billing real, FREE tendrá `plan:false, checkin:false, progress:false`. Hoy en beta todos los usuarios tienen features PRO activas.

**Diferenciación FREE vs PRO:**
- FREE = capa de registro: el atleta entrena, registra y lleva su nutricion. Historial limitado a ultimos 30 dias (entrenamiento y nutricion). Sin plan, sin check-in, sin metricas de progreso.
- PRO = capa de inteligencia: el sistema reacciona a cada dato — check-in semanal sugiere ajustes al plan, métricas de progreso, notificaciones de sugerencia. El atleta decide qué aplicar. Historial completo desde fecha de suscripcion. Puede planificar semanas futuras con rutinas de entrenamiento y nutricion.

**Estado actual:** `getUserPlan()` retorna `'PRO'` cuando `BILLING_ENABLED !== 'true'`. También soporta tier TRIAL via `trialEndsAt`.
El enum `SubscriptionTier: FREE | PRO` existe en DB (`UserSubscription`). `WompiPaymentGateway` está implementado y cableado en `payment-gateway.factory.ts`. Para activar: configurar `PAYMENT_GATEWAY=wompi` + `WOMPI_PRIVATE_KEY` + `WOMPI_INTEGRITY_SECRET` en Vercel y registrar el webhook `https://medaliq.com/api/webhooks/wompi` en dashboard.wompi.co.

## Regla crítica de ownership

- Nunca confiar en userId del body del request — siempre leer de la sesión
- Todo query de atleta filtra por `userId` (web) o `getMobileUser(req).id` (mobile)
- El atleta nunca ve datos de otro atleta — validar ownership en cada endpoint

## Ciclo de vida del plan — completar y continuar

Cuando el plan expira (`rawWeek > totalWeeks && now > endDate`):
```
Plan → COMPLETED
  → Pantalla de celebración con logro: "Completaste [nombre] — X/Y sesiones en Z semanas"
  → Dos opciones:
      1. "Quiero un nuevo plan" → atleta B2B contacta a su coach para que le asigne uno
                                → atleta B2C busca coach en marketplace o crea su propio plan
      2. "Seguir entrenando libre" → dashboard modo FREE (tracker sin plan)
  → En cualquier caso la app sigue disponible — no hay limbo
```

**Importante (actualizado 2026-10-07):** el sistema NO auto-genera planes en onboarding. Los planes vienen de:
- **B2B**: el coach los asigna desde su panel
- **B2C Pro**: generador de plan propio pendiente (B2C-02 en roadmap — no implementado aún). `generate_plan.use_case.ts` existe pero solo lo usa el coach plan builder, no hay ruta accesible para el atleta.

Un atleta B2C sin coach que termina su plan pasa a modo FREE hasta que un coach le asigne uno o se implemente B2C-02.

**Estado actual en código:** `lastCompletedPlanInfo` captura nombre, semanas y sesiones completadas pero no se muestra al atleta. Solo hay un banner pequeño "¿Lista tu próxima meta?". No existe pantalla de celebración.

**Modo FREE post-plan:** el atleta registra entrenamientos libremente — gym, running, sesiones sueltas — sin estructura de plan. El dashboard muestra lo que hizo en la semana. El sistema periódicamente le recuerda que puede conseguir un plan con un entrenador.

## Dashboard modo FREE — primer acceso sin plan

Cuando el atleta completa el onboarding pero no tiene plan activo, el dashboard entra en `dashboardMode = 'FREE'`. **Estado actual (2026-10-07):** el dashboard FREE es funcional — muestra upsell banner con CTAs a `/find-coach` y `/upgrade`, `WeeklySummaryCard`, `MobileCardsSection`, `DesktopRecentActivity` y widgets de nutrición/agua. Ya no referencia `/new-goal` (eliminado en ARCH-01).

**Lo que debe ser (B2C-04 en roadmap — dashboard adaptativo):**
```
4 modos contextuales del dashboard:
  1. B2C Free     → tracking básico + CTA upgrade destacado (IMPLEMENTADO)
  2. B2C Pro sin plan → CTA "Genera tu plan" prominente (→ generador B2C-02, pendiente)
  3. B2C Pro con plan → plan semana + check-in + métricas + nutrición contextual
  4. B2B activado → plan del coach + check-in + canal comunicación
```

**Regla:** mientras no haya plan activo, no mostrar cards vacías. Mostrar un estado de bienvenida que guíe al atleta a su primera acción (registrar sesión libre o buscar coach). Una vez que el coach asigne un plan, el dashboard se activa con estructura completa.

**Estado actual en código:** `getDashboardSummary()` en `src/domain/dashboard/get_dashboard_summary.use_case.ts` maneja todos los modos incluyendo FREE.

## Onboarding — filosofía y reglas

El onboarding tiene exactamente **2 pasos reales** y no debe crecer:
1. **Paso `goal`** — ¿Qué haces? (RUNNING / GYM / BOTH) + objetivo de gym si aplica
2. **Paso `physical`** — Edad, altura, peso, género (obligatorios) + días/semana, nivel (opcionales)

**Por qué los datos físicos son obligatorios:** sin peso + altura no se puede calcular TDEE ni nutrición. El core del producto no funciona sin esos datos — no es fricción evitable.

**Diferencia B2C vs B2B:**
- B2C: el atleta llena ambos pasos solo. El onboarding debe sentirse rápido y cada campo debe explicar para qué sirve.
- B2B: el coach puede pre-llenar los datos físicos al crear al atleta. El atleta solo confirma — no llena nada.

**Lo que NO se debe hacer:** agregar pasos, hacer los datos físicos opcionales para "entrar antes", o duplicar información que el coach ya llenó. La mejora correcta es en la experiencia (UX mobile nativo, progress indicator, contexto por campo) — no en reducir datos.

## Sistema de recompensas — filosofía y capas

**Principio:** la gamificación debe crear conversación social, no colecciones que nadie mira. En LATAM el atleta quiere compartir su logro, no acumular puntos.

**Lo que NO se construye ahora:** puntos, rankings, leaderboards, niveles — complejidad alta, retención baja en esta etapa.

### Capa 1 — Logros de momento (celebración puntual)
Feedback inmediato en el momento del logro — no una colección, solo el instante.
- PR en gym → banner de celebración inmediato (parcialmente implementado via `SetLog.isPR`)
- Completar plan → pantalla de celebración con resumen del logro
- Primera sesión registrada → micro-feedback positivo

### Capa 2 — Racha (el único indicador que crea hábito)
Días consecutivos con actividad registrada. Es el mecanismo más efectivo para retención diaria.
- Visible siempre en el dashboard
- Se rompe si no hay actividad en 48h
- Al romper la racha → notificación de "¿Volvemos?" al día siguiente

### Capa 3 — Hitos de consistencia (largo plazo, compartibles)
Milestones que el atleta puede compartir en WhatsApp/Instagram como imagen.
- 10 check-ins completados
- 50 sesiones registradas
- 3 meses activo en la app
- Plan completado (imagen con nombre del plan + estadísticas)

**Estado:**
- PR detection + celebration banner ✅ (gym)
- `ShareMilestoneButton` ✅ — `src/app/(athlete)/_components/ShareMilestoneButton.tsx`
- `StreakShareButton` ✅ — `src/app/(athlete)/_components/StreakShareButton.tsx` (wired en dashboard, racha ≥7d)
- Logros y achievements: DB lista, lógica de desbloqueo pendiente

**DB implementada (migración 20260708180057):**
- `ActivityStreak` ✅ — `userId @unique`, `currentStreak`, `longestStreak`, `lastActivityAt`. Lógica de actualización parcial.
- `UserAchievement` ✅ — `userId`, `type String`, `unlockedAt`. `@@unique([userId, type])`. Pendiente: lógica de desbloqueo automático.
- `ProgressPhoto` ✅ — `userId`, `url String` (Vercel Blob), `takenAt`, `description?`. Pendiente: endpoint POST /api/athlete/progress/photos y comparador side-by-side en /progress.

## Estado `/pending` — atleta B2B esperando activación

El atleta no debe percibir `/pending` como un callejón sin salida. La pantalla debe:

```
Mostrar progreso claro:
  Paso 1 ✅ Registro completado
  Paso 2 ✅ Perfil completado
  Paso 3 ⏳ Tu entrenador está preparando tu plan

Permitir acción inmediata:
  → Puede registrar sesiones libres desde ya
  → Su historial estará listo cuando el coach active sus features

Mensaje de contexto:
  "Tu entrenador está configurando tu experiencia personalizada.
   Mientras tanto, puedes empezar a registrar tu actividad."
```

**Notificación automática al coach:** si el atleta lleva +48h en `/pending` sin activación → push + email al coach: *"[Nombre] completó su perfil y está esperando. Actívalo para que pueda empezar."*

**Diseño de la pantalla (roadmap):**
```
Hola [Nombre] — Tu entrenador está preparando tu plan personalizado

● ✅ Registro completado
● ✅ Perfil completado
● ⏳ Esperando activación del coach

Mientras tanto puedes registrar tus entrenamientos
[ Registrar sesión de hoy → ]
```

**Estado actual:** `/pending` es solo una pantalla de espera estática sin CTA ni progreso visual.

## Check-in semanal — propósito y loop cerrado

El check-in es el mecanismo de feedback del atleta hacia el sistema y el coach. Su valor no es el formulario — es lo que cambia después.

**Problema actual:** el atleta llena el check-in, el sistema ajusta el plan, pero el atleta nunca ve qué cambió. El esfuerzo no tiene retorno visible → abandono.

**Solución: pantalla de resultado post check-in**
```
Atleta envía check-in
  ↓
Resultado inmediato (pantalla nueva):

  ✅ Check-in semana 6 guardado

  Lo que detectamos:
  · RPE alto (8/10) + energía baja (3/10)

  Lo que ajustamos:
  · Volumen próxima semana −15%
  · Sesiones de alta intensidad → Zona 2

  Recomendación:
  "Prioriza recuperación y mantén la hidratación alta"

  → Si no hubo ajustes: "Todo en orden — sigue con el plan como está"
```

**La data ya existe:** `processCheckIn` devuelve `triggers` y `adjustments`. Solo falta la pantalla de resultado que los muestre al atleta.

**¿Es obligatorio?** No. El atleta puede ignorarlo. Pero sin check-in: sin ajustes automáticos, sin datos para el coach, sin activación de `featureProgress` (primer check-in la activa — implementado en Fase 3 del tx de `processCheckIn`: `enableFeature(userId, 'progress')` cuando `count === 1`). El valor lo decide el atleta con sus acciones.

## Sistema de notificaciones

**Principio:** in-app primero. Canales externos solo cuando el atleta no abre la app.

```
Canal 1 — In-app (centro de notificaciones dentro de la app)
  → Sesión del día programada
  → Check-in semanal disponible
  → Mensaje del coach
  → Plan ajustado por check-in ("Bajamos tu volumen esta semana")
  → Logro desbloqueado (PR, racha, hito)
  → Plan asignado por coach

Canal 2 — Push notification (cuando la app no está abierta)
  → Recordatorio de sesión del día
  → Check-in pendiente (domingo)
  → Racha en riesgo ("Llevas 2 días sin actividad")
  → Mensaje del coach sin leer

Canal 3 — Email (atleta sin abrir la app en +3 días)
  → Re-engagement: "Te extrañamos — tu plan te espera"
  → Eventos críticos: plan asignado, coach te escribió

Canal 4 — WhatsApp (roadmap — post Meta Live Mode)
  → Recordatorios de alta prioridad
  → Mensajes del coach
```

**Estado actual:** cron jobs para check-in reminder y session reminder via email. Push notifications parcialmente implementadas. Centro de notificaciones in-app: no existe.

## Mobile es el canal principal del atleta

- Toda feature de atleta requiere versión mobile antes de considerarse completa
- Si existe en web pero no en mobile → feature incompleta
- El panel del entrenador es web-first (excepción al principio anterior)

## Plan nutricional del coach en /nutrition

Cuando el coach asigna una `NutritionTemplate` al atleta, se crea un registro `AssignedNutritionPlan` (FK a `NutritionTemplate`). La página `/nutrition` del atleta tiene la siguiente prioridad:

```
1. AssignedNutritionPlan (del coach) → badge "Plan de tu coach: [nombre]" encima del contenido
2. MealPlan (generado por sistema) → fallback si no hay plan del coach
3. NutritionPlan base (macros TDEE) → siempre existe tras onboarding
```

Los tres modelos pueden coexistir. El atleta siempre ve el plan del coach si existe. El sistema construye las comidas del día (`DayMeals`) desde la plantilla del coach transformando sus días (HARD/EASY/REST) al formato canónico.

**Propuestas de macros del coach (`CoachNutritionProposal`):**

```
Coach detecta déficit o desviación en los FoodLogs del atleta
→ POST /api/coach/athletes/[id]/nutrition/propose
→ Crea CoachNutritionProposal con delta de macros (ej: +30g proteína)

Atleta ve CoachNutritionProposalCard en /nutrition
  → Puede aceptar (ajusta targets del día) o rechazar
  → NUNCA se aplica automáticamente — el atleta decide siempre
```

**Estado actual (2026-09-10):** `AssignedNutritionPlan` funciona en web y mobile. La pantalla de nutrición diferencia 3 estados: `sin-plan`, `con-plan`, `b2b` — cada uno con orden de componentes distinto alineado a Figma. En mobile (RN), el atleta B2B ve `CoachBanner` (nombre coach + plan), `MealChecklistInline` (comidas del plan), y `CoachCTA` (mensaje al coach). La detección B2B es `!!assignedNutritionPlan` en el endpoint `/api/mobile/nutrition/today`.

## Historial de actividad unificado (/log/history)

`/log/history` muestra un feed cronológico de las últimas 60 actividades del atleta combinando dos fuentes:

```
GymSession (completadas)     → sesiones de gym con sets, pesos, reps, PRs
SessionLog (libres)          → corridas libres (freeSessionType != null, plannedSessionId = null)
```

Ambas listas se mezclan, ordenan por fecha desc y se truncan a 60 entradas. Las sesiones del plan (corridas programadas registradas con `plannedSessionId`) NO aparecen en este feed — están en la vista del plan.

**Resumen del período:** total actividades / total gym / total corridas libres.

**Sesiones de gym:** expandibles (`<details>`), muestran ejercicios, series, peso × reps, PRs marcados.

**Corridas libres:** tarjeta plana con icono de tipo (Z2 🟢, Fartlek 🟡, Tempo 🟠, Intervalos 🔴, Tirada Larga 🔵, Otro ⚪), duración, distancia, RPE. Editables con `EditRunButton`.

**`/log`** → redirect permanente a `/log/history` (legacy bookmarks).

## Biblioteca de ejercicios (/gym/exercises)

Accesible desde `/gym` para todos los atletas. Muestra solo ejercicios de la biblioteca global (`coachId = null`).

```
48 ejercicios por página, ordenados por popularityRank
Filtros: por parte del cuerpo (bodyPart) + búsqueda por nombre (ES y EN)
Paginación: anterior / siguiente con preservación de filtros en URL

AscendAPI: fuente activa — 1,300+ ejercicios sincronizados (EXERCISE_SOURCE=ascendapi por defecto)
gifStoredUrl = versión almacenada en CDN público (Cloudflare) — carga sin restricciones ni headers
gifUrl = URL original de AscendAPI — requiere proxy server-side (/api/athlete/gym/gif/[id]) si gifStoredUrl es null
WorkoutX: fuente secundaria (legacy) — requiere X-WorkoutX-Key header, plan free = 10 ejercicios
```

**Nota**: `nameEs` y `instructionsEs` en español disponibles. El UI muestra `nameEs ?? name`.

## Endpoints del atleta — referencia rápida

> Ver flujos completos con restricciones de tier en `flujos-por-actor.md`.

### Auth y perfil
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/athlete/user/profile` | GET | Perfil del atleta (peso, altura, edad, objetivo) |
| `/api/athlete/user/profile` | PATCH | Actualizar perfil |
| `/api/mobile/auth/refresh` | POST | Reemitir JWT con features frescas desde DB (rate limit: 10/min) |

### Plan y sesiones
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| RSC directo (web) | — | Plan activo con semanas y sesiones (web usa Server Component, no REST) |
| `/api/mobile/plan` | GET | Plan activo mobile |
| `/api/athlete/gym/session/today` | GET | Sesión de gym planificada del día |
| `/api/mobile/gym/session/today` | GET | Idem mobile |
| `/api/athlete/log/session` | POST | Registrar sesión (libre o vinculada a PlannedSession) |
| `/api/mobile/log/session` | POST | Idem mobile |
| `/api/athlete/log/sessions` | GET | Historial de sesiones |
| `/api/mobile/log/sessions` | GET | Idem mobile |
| `/api/athlete/plan/week-print` | GET | Vista imprimible de la semana del plan |

### Gym / Ejercicios
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/athlete/gym/session/today` | GET | Determina qué sesión de gym aplica hoy (plan / rutina / libre) |
| `/api/athlete/gym/session/complete` | POST | Completar sesión de gym con sets y cargas |
| `/api/mobile/gym/session/complete` | POST | Idem mobile |
| `/api/mobile/routine` | POST | Crear rutina propia (self-coach) — solo mobile |

### Nutrición
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/athlete/nutrition` | GET | Target diario + FoodLog del día + plan nutricional |
| `/api/mobile/nutrition` | GET | Idem mobile |
| `/api/athlete/nutrition/log` | POST | Registrar alimento (FoodLog) |
| `/api/mobile/nutrition/log` | POST | Idem mobile |
| `/api/athlete/nutrition/foods` | GET | Buscar alimentos (`isActive: true` únicamente) |
| `/api/mobile/nutrition/foods` | GET | Idem mobile |
| `/api/athlete/nutrition/foods/propose` | POST | Proponer alimento nuevo (NUT-05 — roadmap P1) |
| `/api/athlete/nutrition/foods/my-proposals` | GET | Ver estado de mis propuestas (NUT-06 — roadmap P1) |

### Check-in y progreso
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/athlete/checkin` | GET | Último check-in + sugerencias pendientes |
| `/api/athlete/checkin` | POST | Enviar check-in semanal — dispara 3 fases (PRO) |
| `/api/mobile/checkin` | GET | Estado check-in semana actual + datos previos |
| `/api/mobile/checkin` | POST | Idem mobile |
| `/api/mobile/checkin-status` | GET | Verificar si check-in pendiente (solo mobile) |
| `/api/athlete/progress` | GET | Métricas de progreso (PRO — activo tras primer check-in) |
| `/api/mobile/progress` | GET | Idem mobile |
| `/api/athlete/progress/benchmarks` | GET / POST | Ver y registrar benchmarks de rendimiento (PRO) |

### Gym mobile (sin par web listado arriba)
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/mobile/gym/assign` | POST | Asignar rutina al atleta |
| `/api/mobile/gym/complete` | POST | Completar sesión de gym |
| `/api/mobile/gym/history` | GET | Historial de sesiones gym |
| `/api/mobile/gym/prs` | GET | Records personales |
| `/api/mobile/gym/routines` | GET | Rutinas del atleta |
| `/api/mobile/gym/templates` | GET | Templates de rutinas disponibles |
| `/api/mobile/gym/today` | GET | Sesión de gym para hoy |
| `/api/mobile/gym/week` | GET | Sesiones gym de la semana |

### Nutrition mobile (sin par web listado arriba)
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/mobile/nutrition/assigned-plan` | GET | Plan nutricional asignado por coach |
| `/api/mobile/nutrition/food-profile` | GET/PATCH | Perfil alimentario del atleta |
| `/api/mobile/nutrition/foods/barcode` | GET | Buscar alimento por código de barras |
| `/api/mobile/nutrition/grocery-list` | GET | Lista de compras semanal |
| `/api/mobile/nutrition/log/[id]` | DELETE | Eliminar registro de alimento |
| `/api/mobile/nutrition/log/summary` | GET | Resumen nutricional del día |
| `/api/mobile/nutrition/meal-templates` | GET/POST | Templates de comidas personales |
| `/api/mobile/nutrition/meal-templates/[id]` | PATCH/DELETE | Editar/eliminar template de comida |
| `/api/mobile/nutrition/plan` | GET | Plan nutricional activo |
| `/api/mobile/nutrition/plan/[id]/log` | POST | Registrar comida desde plan |
| `/api/mobile/nutrition/plan/[id]/swap` | POST | Intercambiar comida del plan |
| `/api/mobile/nutrition/planned-meals` | GET | Comidas planificadas |
| `/api/mobile/nutrition/planned-meals/[id]` | GET | Detalle de comida planificada |
| `/api/mobile/nutrition/planned-meals/log-today` | POST | Registrar comidas del plan de hoy |
| `/api/mobile/nutrition/proposals` | GET | Propuestas de macros del coach |
| `/api/mobile/nutrition/proposals/[id]` | PATCH | Aceptar/rechazar propuesta |
| `/api/mobile/nutrition/templates` | GET | Templates de nutrición |
| `/api/mobile/nutrition/templates/[id]/apply` | POST | Aplicar template |
| `/api/mobile/nutrition/templates/[id]/meals` | GET | Comidas de un template |
| `/api/mobile/nutrition/today` | GET | Vista unificada nutrición del día |
| `/api/mobile/nutrition/water` | GET/POST | Registro de agua |

### Progress mobile (sin par web listado arriba)
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/mobile/progress` | GET | Métricas de progreso |
| `/api/mobile/progress/benchmarks` | GET | Benchmarks de rendimiento |
| `/api/mobile/progress/muscles` | GET | Músculos trabajados (heatmap) |

### Dashboard mobile
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/mobile/dashboard` | GET | Dashboard principal mobile |
| `/api/mobile/dashboard/week-sessions` | GET | Sesiones de la semana para calendario |

### Otros mobile
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/mobile/billing/prices` | GET | Precios de planes |
| `/api/mobile/calendar` | GET | Calendario de actividades |
| `/api/mobile/exercises` | GET | Biblioteca de ejercicios |
| `/api/mobile/exercises/[id]` | GET | Detalle de ejercicio |
| `/api/mobile/exercises/[id]/alternatives` | GET | Alternativas a un ejercicio |
| `/api/mobile/log/history` | GET | Historial de actividad |
| `/api/mobile/log/last-session` | GET | Última sesión registrada |
| `/api/mobile/log/session/[logId]` | GET/PATCH/DELETE | CRUD de sesión |
| `/api/mobile/metrics/log` | GET | Métricas de logs |
| `/api/mobile/notifications` | GET | Centro de notificaciones |
| `/api/mobile/notifications/read-all` | PATCH | Marcar todas como leídas |
| `/api/mobile/onboarding/generate` | POST | Generar perfil post-onboarding |
| `/api/mobile/profile` | GET/PATCH | Perfil del atleta |
| `/api/mobile/push-token` | POST | Registrar push token |
| `/api/mobile/routine` | POST | Crear rutina propia |
| `/api/mobile/sessions/[sessionId]` | GET | Detalle de sesión planificada |

### Finanzas
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/athlete/payments/upcoming` | GET | Fecha de vencimiento de asesoría — solo atleta B2B |
