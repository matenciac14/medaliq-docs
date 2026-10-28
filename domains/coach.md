# Domain: Coach
# Reglas de negocio no evidentes en el código. Leer antes de tocar cualquier feature de coach.
> **Flujos por actor → `flujos-por-actor.md`** — qué puede hacer el coach en cada módulo, con endpoints completos y restricciones de tier.
> Spec de implementacion: `../specs/coach_athletes.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | N/A |
| Mobile atleta | Parcial (coach-inbox + coach-chat) |
| Web coach | Completa (panel /coach/*) |

## Especialidades del coach

El coach declara sus especialidades al registrarse. Definen qué herramientas ve en su panel y qué disciplinas puede asignar a sus atletas.

**Fuente canónica:** `CoachProfile.specialties String[]` — array de strings, NO enum.

| Especialidad | Panel muestra |
|-------------|---------------|
| `RUNNING` | Constructor de sesiones con zonas FC, pace, distancia |
| `GYM` | Constructor de rutinas con ejercicios, series, cargas |
| `NUTRITION` | Plantillas nutricionales (sin herramientas de entrenamiento) |
| `CYCLING` | (futuro) Constructor de sesiones ciclismo |
| `SWIMMING` | (futuro) Constructor de sesiones natación |
| `YOGA` | (futuro) Constructor de sesiones yoga |
| `FUNCTIONAL` | (futuro) Constructor de entrenamiento funcional |

**Regla `[]` vacío = acceso completo** (backward compat). Coaches existentes sin especialidades configuradas ven todas las herramientas.

**Lógica canónica** (inline en sidebar + athlete detail, testeada en `coach_specialty.test.ts`):
```ts
// Patrón usado inline — [] vacío = acceso completo
sp.includes('GYM') || sp.length === 0       // ¿puede gym?
sp.includes('NUTRITION') || sp.length === 0  // ¿puede nutrición?
sp.length === 0 || sp.includes(discipline)   // ¿puede disciplina X?
```

**`primarySpecialty` (enum) está @deprecated** — se mantiene por backward compat pero `specialties[]` es la fuente canónica. No usar `primarySpecialty` en código nuevo.

**Estado:** Implementado. `specialties String[]` como fuente canónica. `CoachSidebarClient` filtra herramientas del panel. `PlanTab` filtra discipline cards según `coachSpecialties`. Tests: 22 tests en `coach-specialty.test.ts`. COACH-UX-02 completado.

---

## Qué puede y NO puede hacer el coach

| Puede | NO puede |
|-------|----------|
| Crear y asignar planes al atleta | Registrar sesiones por el atleta |
| Ver logs, check-ins y food logs del atleta | Modificar FoodLog o SessionLog del atleta |
| Ajustar el plan base nutricional | Aceptar/rechazar ajustes diarios (eso es del atleta) |
| Crear y asignar plantillas de nutrición | Acceder a datos de atletas de otro coach |
| Activar atleta → acceso PRO completo automático | Configurar features individuales por atleta |
| Pausar atleta → revierte a B2C FREE automáticamente | Crear benchmarks sin ser el coach asignado |
| Ver PRs y benchmarks del atleta | Eliminar historial de sesiones del atleta |
| Guardar meta pactada y notas privadas por atleta | Cambiar el coach de un atleta (solo admin) |

## Flujo B2B obligatorio

```
Coach crea atleta (POST /api/coach/clients/create)
  → Atleta completa onboarding → /pending
  → Coach activa el atleta (PATCH /api/coach/athletes/[id]/status { status: 'ACTIVE' })
      → configToAthleteFeatures(getTierFeatureConfig('B2B')) aplicado automáticamente
      → Push notification al atleta: "Tu entrenador te activó"
  → Atleta accede al producto con acceso PRO completo
```
Sin activación del coach, el atleta queda en `/pending` indefinidamente.

**El coach puede ver el panel del atleta aunque esté en `/pending`** — historial de entrenamiento disponible desde el primer momento. Pero el sistema debe mostrar una alerta al atleta indicando que debe completar su perfil/onboarding para que el coach pueda ajustar su asesoría. Sin ese perfil (peso, altura, objetivo, FC), el coach no tiene los datos necesarios para personalizar el plan.

## Límites por tier

> Tabla de tiers y definición de atleta activo: ver `pagos.md` — fuente canónica de billing.

Enforcement en `POST /api/coach/clients/create` → 402 si `activeCount >= maxAthletes` del tier.
**Estado: implementado** — `computeAthleteFeatures(tier)` + `getCoachLimits(CoachTier)` en `domain/subscription/tier-features.ts`. Guard activo en `/api/coach/clients/create`. `CoachSubscriptionTier` en `UserSubscription.coachTier`. `WompiPaymentGateway` implementado y cableado — activa con `PAYMENT_GATEWAY=wompi` en Vercel. UI de upgrade en `/coach/settings/plan`. SCALE+ (>100 atletas con cargo por atleta adicional) pendiente de implementar.

**Atleta B2B — precio para el atleta: $0.** El atleta B2B nunca paga a Medaliq. Su acceso está incluido en el tier del coach. El atleta B2B nunca ve pantalla de pago ni suscripción en la app.

## Regla de ownership coach-atleta

- Antes de cualquier acción sobre un atleta: verificar `CoachAthlete` con `status: 'ACTIVE'`
- Un atleta solo puede tener un coach activo a la vez
- **No existe flujo de cambio de coach** — ni el atleta ni el coach pueden reasignar. Solo admin puede hacerlo vía `/api/admin/users/[id]`.

## Qué pasa cuando el coach pausa a un atleta

PAUSED no significa bloqueado. El atleta **revierte a B2C** — sigue usando la app de forma autónoma con las features de su tier.

```
CoachAthlete.status = 'PAUSED'
  → El atleta pierde la capa del coach (plan asignado, seguimiento, cobro)
  → El atleta NO va a /pending — sigue activo como usuario B2C
  → El coach puede reactivarlo cuando quiera (status → ACTIVE)
  → El atleta PAUSED no cuenta para el límite de tier del coach
```

**Contexto de negocio:** Medaliq es una herramienta para cualquiera que quiera registrar entrenamiento y nutrición. El coach agrega la capa de asesoría encima. Si la relación termina, el atleta no pierde la app — solo pierde al coach.

## Panel del coach — constructores de plan y nutrición

El panel del coach es web-first. Debe ser robusto: el coach gestiona múltiples atletas y necesita herramientas eficientes para construir y asignar planes sin repetir trabajo.

### Constructor de sesiones de running

Para coaches con especialidad `RUNNING` o `ALL`:

```
Tab Plan del atleta → Vista calendario → Click en día → Añadir sesión

Campos por sesión:
  Tipo: RODAJE_Z2 | FARTLEK | TEMPO | INTERVALOS | TIRADA_LARGA | DESCANSO | OTRO
  Zona FC objetivo: Z1 (< 60%) | Z2 (60-70%) | Z3 (70-80%) | Z4 (80-90%) | Z5 (>90%)
  Distancia km | Duración min | Descripción técnica | Nota personal al atleta

Capacidades:
  → Publicar sesión por sesión O bloque semanal completo de una vez
  → Duplicar una sesión a otro día del mismo atleta
  → Copiar una sesión de un atleta a otro (reutilización)
  → Ver el calendario del atleta con historial vs plan (cumplido / no cumplido)
```

### Constructor de rutinas de gym/fuerza

Para coaches con especialidad `GYM` o `ALL`:

```
/coach/gym/routines → crear WorkoutTemplate
  → Define días (ej. Lunes: Upper, Martes: Lower)
  → Por día: bloques de ejercicios desde la biblioteca global
      Ejercicio | Series | Reps objetivo | Carga sugerida | Descanso (seg)
  → Guardar como plantilla reutilizable
  → Asignar a uno o varios atletas

El coach:
  → Tiene su biblioteca de templates (propios + públicos de otros coaches)
  → Puede duplicar un template como base para otro atleta
  → Ve el historial de sesiones gym del atleta: ejercicios, cargas, volumen, PRs
  → Puede sugerir aumento de carga por ejercicio (nota en el template)
```

### Constructor de nutrición

Para coaches con especialidad `NUTRITION` o `ALL`:

```
/coach/nutrition → crear NutritionTemplate
  Macros por tipo de comida y tipo de día:
    Desayuno | Almuerzo | Merienda | Cena | Snack
    × Día de entrenamiento duro | Día moderado | Día suave | Día de descanso

Asignar plantilla al atleta → reemplaza su NutritionPlan base
El atleta puede tener ajustes diarios encima sin tocar la plantilla

Coach ve en Tab Nutrición del atleta:
  → FoodLog de los últimos 7 días
  → Adherencia diaria vs target (% por día)
  → Puede proponer ajuste puntual → atleta acepta/rechaza

[Roadmap DB-12] Coach asigna alimentos concretos por fecha (PlannedMeal):
  → Vista semanal del atleta → click en día → agregar alimentos específicos
  → Atleta lo ve como "Plan de tu coach" en la app
  → Coach ve adherencia: % de días donde el atleta siguió el plan nutricional
  → PlannedMeal ≠ NutritionTemplate: la plantilla define macros genéricos por tipo de día,
    PlannedMeal define alimentos concretos para una fecha específica
```

### Reglas de protección de recursos del coach

- **Ejercicios:** el coach solo puede editar o eliminar ejercicios propios (`source = 'custom'`). Al intentar modificar o eliminar un ejercicio global (de la biblioteca compartida), el sistema retorna 403 Forbidden — no 404.
- **Rutinas:** eliminar una rutina requiere que el coach sea el dueño Y que la rutina no tenga asignaciones activas a atletas. Si tiene asignaciones, el coach debe desasignarla primero.
- **Constructor de nutrición (NutritionBuilder):** los errores al agregar o quitar alimentos de un template se muestran al coach con mensajes descriptivos — el sistema no falla silenciosamente.

### Principios del panel del coach

- **El coach ve un atleta a la vez** en el panel de detalle — no dashboards agregados de todos sus atletas simultáneamente (demasiado ruido)
- **El dashboard del coach** muestra: alertas de adherencia baja, atletas en /pending, pagos vencidos, mensajes sin leer — señales de acción, no de información
- **Reutilización siempre:** templates de rutinas y nutrición se copian entre atletas — el coach no rehace el trabajo desde cero
- **El coach nunca registra datos por el atleta** — solo diseña, asigna, sugiere y observa

## Plantillas de nutrición (NutritionTemplate)

El coach puede crear plantillas de nutrición reutilizables y asignarlas a sus atletas:
```
POST /api/coach/nutrition/templates        → crear plantilla
GET  /api/coach/nutrition/templates        → listar las del coach
PATCH /api/coach/nutrition/templates/[id]  → editar
DELETE /api/coach/nutrition/templates/[id] → eliminar
POST /api/coach/nutrition/templates/[id]/assign → asignar a atleta
```
UI: `/coach/nutrition`
La plantilla define el plan base nutricional — el atleta puede tener ajustes diarios encima sin que la plantilla se toque.

## Regla de edición de sesiones

> Regla completa: ver `plan.md §Regla de ajuste automático de sesiones` — fuente canónica.

El coach puede editar `coachNote`, `detailText`, `zoneTarget` de cualquier sesión publicada.
`coachNote` sin prefijo `[AUTO]` → edición manual del coach → el sistema **nunca** la sobrescribe.
`coachNote` con prefijo `[AUTO]` → ajuste automático del check-in → puede sobrescribirse automáticamente.

---

## Endpoints del coach — referencia rápida

> Ver flujos completos con restricciones de tier en `flujos-por-actor.md`.

### Gestión de atletas
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/clients` | GET | Listar atletas del coach |
| `/api/coach/clients/create` | POST | Crear atleta nuevo (402 si límite de tier alcanzado) |
| `/api/coach/clients/link` | POST | Vincular atleta B2C existente |
| `/api/coach/athletes/[id]` | GET | Perfil completo del atleta — **No existe como endpoint standalone.** La data del atleta se obtiene via sub-rutas (`/nutrition`, `/plan`, `/training-adherence`, etc.) |
| `/api/coach/athletes/[id]/status` | PATCH | Activar/pausar atleta — aplica `configToAthleteFeatures()` automáticamente |
| `/api/coach/athletes/[id]/config` | PATCH | Guardar meta pactada (`coachGoal`) y notas privadas (`privateNotes`) — solo metadatos |

### Plan de entrenamiento
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/athletes/[id]/plan` | POST | Asignar plan al atleta (`PlanSource: 'COACH'`) |
| `/api/coach/athletes/[id]/sessions` | GET | Ver calendario del atleta |
| `/api/coach/athletes/[id]/sessions` | POST | Publicar sesión en el calendario — Implementado. |
| `/api/coach/athletes/[id]/sessions/[sessionId]` | PATCH | Editar sesión publicada |

### Gym / Rutinas
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/gym/routines` | GET | Listar plantillas de rutinas propias |
| `/api/coach/gym/routines` | POST | Crear WorkoutTemplate |
| `/api/coach/gym/routines/[id]/assign` | POST | Asignar rutina a atleta (desactiva la anterior) |
| `/api/coach/athletes/[id]/gym` | GET | Ver historial gym del atleta (cargas, PRs, adherencia) |

### Nutrición
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/nutrition/templates` | GET | Listar plantillas nutricionales |
| `/api/coach/nutrition/templates` | POST | Crear NutritionTemplate |
| `/api/coach/nutrition/templates/[id]` | PATCH | Editar plantilla |
| `/api/coach/nutrition/templates/[id]` | DELETE | Eliminar plantilla |
| `/api/coach/nutrition/templates/[id]/assign` | POST | Asignar plantilla al atleta (reemplaza NutritionPlan base) |
| `/api/coach/athletes/[id]/nutrition` | GET | Ver FoodLog del atleta (últimos 7 días) — solo lectura |
| `/api/coach/athletes/[id]/nutrition/propose` | POST | Proponer ajuste nutricional (atleta acepta/rechaza) |

### Seguimiento y check-ins
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/athletes/[id]/checkins` | GET | Historial de check-ins del atleta — **No implementado. Endpoint no existe en el codebase.** |
| `/api/coach/athletes/[id]/training-adherence` | GET | % sesiones completadas vs planeadas (path correcto: `/training-adherence`, no `/adherence`) |
| `/api/coach/athletes/[id]/benchmarks` | GET | Benchmarks de rendimiento del atleta |
| `/api/coach/sessions/[sessionId]/copy-to` | POST | Copiar sesión a semana de otro atleta (`{ targetWeekId, dayOfWeek }`) |

### Finanzas
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/payments` | GET | Listar cobros del atleta |
| `/api/coach/payments` | POST | Crear cobro (monto, descripción, fecha vencimiento) |
| `/api/coach/payments/[paymentId]` | PATCH | Marcar como pagado |
| `/api/coach/payments/[paymentId]` | DELETE | Eliminar cobro |

### Perfil y suscripción
| Endpoint | Método | Qué hace |
|----------|--------|---------|
| `/api/coach/profile` | PATCH | Editar perfil público (bio, especialidad, `showPhoneWa`) |
| `/api/coach/billing` | GET | Tier actual + atletas activos vs límite del tier — **No implementado. Pendiente activación de billing real.** |

---

## Builder de rutinas gym — detalles de implementación

`/coach/gym/routines/[id]` es un client component completo con estado local.

**Estructura de un día:**
```
DayConfig {
  dayOfWeek: 1-7
  label: string (ej. "Lunes — Upper Body")
  muscleGroups: string[]     (QUADRICEPS | HAMSTRINGS | GLUTES | CHEST | BACK | SHOULDERS | BICEPS | TRICEPS | ABS | CALVES | FULL_BODY)
  isRestDay: boolean
  warmupNotes: string
  cardioNotes: string
  exercises: DayExercise[]
}

DayExercise {
  exerciseId: string
  sets: number
  repsScheme: string         (ej. "8-12" o "3×8" o "AMRAP")
  restSeconds: number
  setType: NORMAL | SUPERSET | BISERIE | DROPSET | CIRCUIT
  notes: string
  order: number
}
```

**SwapModal — intercambio rápido de ejercicios:**
- El coach puede reemplazar un ejercicio dentro de un día sin perder la config de series/reps
- Busca en la misma biblioteca global + ejercicios propios del coach (`coachId = coachId`)
- Al hacer swap: mantiene `sets`, `repsScheme`, `restSeconds`, `setType`, `notes` — solo cambia `exerciseId`
- Razón del swap registrada en `notes` del ejercicio

**Goals disponibles:** HYPERTROPHY · STRENGTH · TONING · FUNCTIONAL · ENDURANCE
**Niveles:** BEGINNER · INTERMEDIATE · ADVANCED

## Seguimiento de atletas — NutritionAdherenceCard

En el Tab Nutrición de `/coach/athlete/[id]`, el coach ve:

1. **`NutritionAdherenceCard`** (primer elemento) — sparkline de 4 semanas:
   - Badge semana actual: verde ≥80%, amarillo 60-79%, rojo <60%
   - "X de 7 días registrados" en la semana actual
   - 4 barras verticales (naranja ≥80%, gris menor)
   - Fuente: `GET /api/coach/athletes/[id]/nutrition/adherence` (28 días, agrupado por día)

2. **`FoodLogsSection`** — logs de comida del atleta últimos 7 días (solo lectura)

3. **Constructor de targets nutricionales** — editar `targetKcalHard/Easy/Rest`, `proteinG`, `carbsHardG`, `carbsEasyG`, `fatG`

4. **Propuesta de ajuste de macros** — `POST /api/coach/athletes/[id]/nutrition/propose` (atleta acepta/rechaza)

**Cron de alerta nutricional:** `GET /api/cron/nutrition-alert` (daily 09:00)
- Si atleta tiene 3 días seguidos con adherencia <60% → push al coach

## Identidad y verificación del coach

### Los 3 identificadores únicos del coach

Todo coach debe tener los tres. Ninguno puede repetirse en la plataforma.

| Identificador | Campo DB | Único | Cuándo se recopila |
|--------------|----------|-------|-------------------|
| Email | `User.email` | ✅ Ya único en DB | Registro |
| Identificación (cédula / pasaporte) | `User.identification` | ✅ Único en coaches | Onboarding coach |
| Número WhatsApp (con código de país) | `User.phoneWa` | ✅ Único en coaches | Onboarding coach |

**Regla:** la unicidad de `identification` y `phoneWa` se valida SOLO entre usuarios con `role = 'COACH'`. Un atleta puede tener el mismo número que un coach registrado en otra plataforma — no son el mismo sistema de identidad.

---

### Reglas de negocio

#### Identificación (cédula / pasaporte)
- Formato libre (string) — soporta cédula colombiana, NIT, pasaporte, cédula extranjera
- Longitud mínima: 5 caracteres · máxima: 30 caracteres
- Sin validación de formato en v1 — validación manual por admin si se sospecha fraude
- No se expone públicamente en ningún endpoint
- Se usa internamente para detección de cuentas duplicadas

#### Número WhatsApp
- Debe incluir código de país: `+57XXXXXXXXXX` (Colombia), `+52XXXXXXXXXX` (México), etc.
- Formato: E.164 (`+` + código de país + número, sin espacios ni guiones)
- Validación: regex `/^\+[1-9]\d{7,14}$/`
- Se expone en el perfil público del coach (`/p/[slug]`) solo si el coach lo autoriza
- Sirve como canal de contacto coach-atleta fuera de la plataforma (Flujo 5 — Marketplace)
- Es la fuente canónica del número de WhatsApp para el link `wa.me/` en el perfil público

#### Email
- Ya existe y es único en toda la tabla `User`
- No cambia su comportamiento actual

---

### Cuándo recopilar cada identificador

```
Registro (/register)
  → Email + password (ya implementado)
  → NO pedir cédula ni teléfono aquí — reduce fricción de entrada

Onboarding coach (flujo pendiente — primer login post-registro)
  → Paso adicional: "Completa tu perfil profesional"
      · Número de identificación (obligatorio)
      · Número WhatsApp con código de país (obligatorio)
      · Especialidad (RUNNING / GYM / NUTRITION / ALL)
  → Hasta completar esto, el coach ve un banner: "Completa tu perfil para invitar atletas"
  → No bloquea acceso al panel — bloquea únicamente POST /api/coach/clients/create
```

**Por qué no en el registro:** el registro debe ser lo más rápido posible. La identidad completa se recopila en el primer uso real (invitar atletas), momento en que el coach ya tiene contexto de por qué se pide.

---

### Validación de unicidad — flujo de error

```
Coach intenta completar su perfil con identification = "1234567890"
  → Sistema busca: User.findFirst({ where: { identification: "1234567890", role: "COACH" } })
  → Si existe → 409: "Ya existe un coach registrado con esa identificación."
  → Si no existe → guarda

Coach intenta registrar phoneWa = "+573001234567"
  → Sistema busca: User.findFirst({ where: { phoneWa: "+573001234567", role: "COACH" } })
  → Si existe → 409: "Ya existe un coach registrado con ese número de WhatsApp."
  → Si no existe → guarda
```

---

### Uso en detección de fraude — múltiples cuentas

Un coach que intenta crear múltiples cuentas para obtener Starter gratis varias veces será detectado por:

1. **Mismo email** → bloqueado en registro (ya implementado)
2. **Misma identificación** → bloqueado al completar perfil coach — Implementado. Validación de unicidad activa.
3. **Mismo número WhatsApp** → bloqueado al completar perfil coach — Implementado. Validación de unicidad activa.
4. **Mismo método de pago en Wompi** → flaggeado al conectar billing (futuro)

El coach que crea cuentas con emails distintos pero misma cédula o mismo WhatsApp → bloqueado en el paso 2 o 3 antes de poder invitar atletas.

---

### Exposición pública de datos

| Campo | Perfil público `/p/[slug]` | API interna | API pública |
|-------|--------------------------|-------------|-------------|
| Email | ❌ Nunca | ✅ Solo coach dueño | ❌ |
| Identificación | ❌ Nunca | ✅ Solo admin | ❌ |
| PhoneWa | ✅ Si coach autorizó | ✅ Solo coach dueño | ✅ Si autorizó |

---

### Atleta activo para billing

> Definición canónica con los 3 criterios: ver `pagos.md` — fuente canónica de billing.

Relevancia para este dominio: un coach que crea cuentas ficticias con cédulas o WhatsApp distintos para inflar su conteo de atletas activos es detectado por los identificadores únicos antes de poder invitar atletas. La identidad única del coach es la primera línea de defensa contra este fraude.

---

### Estado actual en código

| Campo | Estado |
|-------|--------|
| `User.email` | ✅ Existe y es único |
| `User.identification` | ✅ Implementado — migración 20260708000001. `String? @unique` en `User` |
| `User.phoneWa` | ✅ Implementado — migración 20260708000001. `String? @unique` en `User` |
| `User.showPhoneWa` | ✅ Implementado — `Boolean @default(false)`. Opt-in para exponer en `/p/[slug]` |
| Bloqueo `POST /api/coach/clients/create` sin perfil completo | ✅ Activo — líneas 50-56 del route: 403 si `!identification \|\| !phoneWa` |
| Validación unicidad en actualización de perfil | ✅ Activo — Prisma lanza `P2002` si viola `@unique`, capturado con 409 |
| Admin puede ver identification | ❌ Pendiente — no hay endpoint específico, visible en panel admin general |

---

## Scope deseado — no priorizado (análisis competitivo 2026-08)

Features identificadas tras análisis de Ladder (`joinladder.com`). **No implementar sin decisión explícita de Miguel.**

### Identidad de marca del coach en marketplace (DESIRED-02)

El perfil `/p/[slug]` hoy muestra: bio, especialidad, WhatsApp. Ladder diferencia a sus "coaching teams" con metodología propia, filosofía y perfil de atleta ideal. Para coaches reales en Medaliq esto es un diferenciador fuerte en el marketplace.

**Campos adicionales propuestos en `CoachProfile`:**
```
methodology       String?   // Cómo trabaja el coach — texto libre, max 500 chars
athleteIdealProfile String? // A quién atiende: "principiantes motivados", "runners sub-4h"
typicalResults    String?   // Resultados típicos: "maratón en 6 meses", "+20kg en press banca"
coachingStyle     Enum?     // ONLINE | PRESENCIAL | HIBRIDO
```

**Impacto**: diferencia a coaches serios de perfiles vacíos. Facilita la decisión del atleta en el marketplace. El formulario `/coach/profile` recibe los campos nuevos. El perfil público los renderiza.

**Prerequisito**: el marketplace `/coaches` está oculto hasta 20+ coaches activos. Implementar esto cuando se abra el directorio público.

### Grupos de accountability entre atletas (DESIRED-05)

Los atletas de un mismo coach pueden ver la actividad entre sí — presión social positiva que aumenta adherencia. El coach crea "grupos" (ej. "Grupo Maratón Nov") y los atletas optan por participar.

Feed de actividad: "Ana completó su sesión de hoy", "Carlos batió su PR de sentadilla". No ranking competitivo — foco en consistencia grupal.

**Complejidad**: requiere modelo `AthleteCohort`, privacidad granular (opt-in por atleta), feed de actividad. Feature de comunidad, no de coaching puro. Evaluar PMF antes de construir.
