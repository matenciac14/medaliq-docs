# Trampas transversales — LEE ESTO ANTES DE TOCAR CUALQUIER MODULO

> Estas son decisiones de implementacion que NO son obvias y que la AI rompe sistematicamente.
> Cada trampa fue verificada contra el codigo real. Ultima actualizacion: 2026-09-29.

---

## T01 — Fechas: todayInTz() vs new Date()

**Que parece:** `new Date()` y `setHours(0,0,0,0)` dan la fecha de hoy.
**Que es realmente:** En Vercel (UTC), `new Date().setHours(0,0,0,0)` da medianoche UTC, no medianoche Colombia (UTC-5). Un atleta que entrena a las 10pm COT aparece como "dia siguiente" en UTC.

**Regla:** SIEMPRE usar `todayInTz(timezone)` de `@/lib/core/date_utils` para queries de DB por fecha.

**Archivo:** `src/lib/core/date_utils.ts`

**Trampa extra en getWeekMonday():** Si `timezone` es `undefined`, retorna medianoche en hora LOCAL del server (UTC en Vercel). Si `timezone` es string, retorna medianoche en esa zona. Los dos valores se comportan DIFERENTE en Prisma range queries.

---

## T02 — [AUTO] en coachNote

> **[roadmap R4] PENDIENTE DE ELIMINAR.** La decisión de producto es que check-in = recopilación de datos solamente. `applySessionAdjustments` será eliminado. Mientras exista, este es el comportamiento activo:

**Que parece:** `PlannedSession.coachNote` es un campo de texto libre.
**Que es realmente:** Si `coachNote` NO empieza con `[AUTO]` o esta vacio, el sistema de check-in NUNCA modifica esa sesion automaticamente. Es la senal de que el coach escribio una nota manual.

**Regla:** Cualquier codigo que escriba `coachNote` automaticamente DEBE preponer `[AUTO]`. Sin el prefijo, la sesion queda "bloqueada" contra ajustes del check-in.

**Archivo:** `src/domain/checkin/process_check_in.use_case.ts` — busca `applySessionAdjustments`.

---

## T03 — FoodLog.snapshot: inmutabilidad de historicos

**Que parece:** Los macros de un FoodLog se calculan desde `food.kcalPer100g * quantity`.
**Que es realmente:** Si `FoodLog.snapshot` no es null, los macros se leen del snapshot (valores al momento del log). Si es null, se calculan desde el `food` actual. Esto protege historicos si el alimento se edita despues.

**Regla:** NUNCA recalcular macros de un FoodLog desde `food.*` cuando `snapshot != null`. Usar `buildFoodLogResponse()` de `domain/nutrition/calculate_food_log.ts`.

---

## T04 — Prioridad B2B: assignedMealPlan ?? mealPlanParsed

**Que parece:** El atleta tiene un meal plan y se muestra.
**Que es realmente:** Si el atleta es B2B con template del coach (`AssignedNutritionPlan`), ese plan tiene PRIORIDAD sobre el plan propio del atleta (`MealPlan`). El operador `??` garantiza esto.

**Regla:** Invertir el orden del `??` = el atleta B2B ve su plan propio en vez del del coach. NUNCA cambiar el orden sin validar el flujo B2B.

**Archivo:** `src/domain/nutrition/get_nutrition_today.use_case.ts` ~linea 205.

---

## T05 — Tres nombres para el mismo campo: muscleSoreness/rpe/hardestSessionRpe

**Que parece:** El check-in tiene un campo de esfuerzo percibido.
**Que es realmente:** El campo tiene 3 nombres segun la capa:
- `muscleSoreness` — body del request mobile
- `rpe` — domain `CheckInInput` (despues del mapper)
- `hardestSessionRpe` — columna en DB `WeeklyCheckIn`

**Regla:** Usar el nombre correcto en la capa correcta. El mapper esta en `src/lib/api/checkin_mapper.ts`.

**Trampa extra:** `nutritionAdherencePct` (0-100 en body) se convierte a `nutritionAdherence` (1-10 en domain) — division por 10 en el mapper.

---

## T06 — getUserPlan() hardcodea PRO

**Que parece:** `getUserPlan(userId)` retorna el tier real del atleta.
**Que es realmente:** Hoy retorna `'PRO'` para TODOS los usuarios. El billing (Wompi) no esta activado en produccion.

**Regla:** NO implementar logica de tier que dependa de `getUserPlan()` pensando que funciona. Los feature gates del JWT mobile (`mobile.features`) tambien reflejan PRO para todos.

**Archivo:** `src/lib/config/user_config.ts` — busca `getUserPlan`.

---

## T07 — requireFeature() retorna el ERROR, no true

**Que parece:** `requireFeature(features, 'nutrition')` retorna `true` si tiene el feature.
**Que es realmente:** Retorna `NextResponse` (error 402) si NO tiene el feature, o `null` si tiene acceso.

**Regla:** El patron correcto es:
```ts
const guard = requireFeature(mobile.features, 'nutrition')
if (guard) return guard  // <-- retorna el error
```
Escribir `if (!guard) return guard` INVIERTE el gate — bloquea a todos.

**Archivo:** `src/lib/guards/feature_gate.ts`

---

## T08 — Floor math en gym/week vs getPlanWeekNumber()

**Que parece:** El numero de semana del plan se calcula con `getPlanWeekNumber()`.
**Que es realmente:** La ruta `/api/mobile/gym/week` usa floor math inline en vez de `getPlanWeekNumber()`. Es el UNICO lugar que lo hace.

**Regla:** NO "estandarizar" la ruta gym/week a `getPlanWeekNumber()` — cambiaria la semantica del offset de semana de gym. Es intencional.

**Archivo:** `src/app/api/mobile/gym/week/route.ts` ~linea 59.

---

## T09 — handlePlanLifecycle() tiene side effects

**Que parece:** `handlePlanLifecycle()` calcula el estado del plan y retorna datos.
**Que es realmente:** Ademas de retornar datos, hace writes fire-and-forget a la DB (actualiza `plan.status`). NO es una funcion pura.

**Regla:** NO tratarla como funcion pura. NO moverla a un `Promise.all` donde el resultado se descarta. Los side effects son criticos para el ciclo de vida del plan.

**Archivo:** `src/infrastructure/db/shared_athlete_data.ts`

---

## T10 — Fix en web sin fix en mobile (mirror routes)

**Que parece:** Corregi el bug en `/api/athlete/nutrition/foods`.
**Que es realmente:** Existe `/api/mobile/nutrition/foods` con la misma logica pero auth diferente. Si solo corriges web, el bug persiste en mobile.

**Regla:** SIEMPRE buscar el mirror antes de terminar un fix:
```
Glob: src/app/api/mobile/**/route.ts  (buscar equivalente mobile)
Glob: src/app/api/athlete/**/route.ts (buscar equivalente web)
```

**Indice completo de pares:** Ver `specs/_mobile_mirror.spec.md`.

---

## T11 — dbDayType vs intensityToDayType()

**Que parece:** Hay una funcion `intensityToDayType()` que mapea intensidad a tipo de dia.
**Que es realmente:** En `/api/mobile/nutrition/today`, el mapeo es DIFERENTE:
- DB enum: `HIGH -> 'HARD'`, `MODERATE/LOW/null -> 'EASY'`, `REST -> 'REST'`
- Domain function: usa strings del dominio, no del enum DB

**Regla:** En el endpoint nutrition/today, usar el mapeo inline del DB enum, NO llamar a `intensityToDayType()`.

**Archivo:** `src/domain/nutrition/get_nutrition_today.use_case.ts` ~linea 158.

---

## T12 — Tipos locales en pages vs tipos de la API

**Que parece:** La page define sus tipos inline para tipar los datos de la API.
**Que es realmente:** Archivos como `gym/session/page.tsx` definen `ExerciseData`, `SessionData`, `SetsMap` localmente. Estos tipos NO estan compartidos con la API que produce los datos.

**Regla:** Si cambias el response shape de una API, buscar la page que lo consume y actualizar sus tipos locales. No hay validacion en compile-time para esto.

**Archivos afectados:**
- `src/app/(athlete)/gym/session/page.tsx` (lineas 22-79)
- `src/app/api/mobile/gym/week/route.ts` (`CompletedExercise` definido 2 veces)
- `src/app/api/mobile/dashboard/week-sessions/route.ts` (`WeekSessionSlot` inline)

---

## T13 — Shims de re-export en lib/nutrition/

**Que parece:** `@/lib/nutrition/day_type` y `@/domain/nutrition/day_type` son modulos distintos.
**Que es realmente:** Los archivos en `src/lib/nutrition/` son re-exports de `src/domain/nutrition/`. Importar de cualquier path da el mismo resultado.

**Regla:** Para codigo nuevo, importar SIEMPRE de `@/domain/nutrition/`. Los shims en `@/lib/nutrition/` existen solo por backward compat.

---

## T14 — PlannedMeal usa lunes-domingo, NO "ultimos 7 dias"

**Que parece:** "Datos de la semana" = ultimos 7 dias.
**Que es realmente:** `PlannedMeal` usa `mondayThisWeek` a `sundayThisWeek` (lunes a domingo). Pero otras queries en la misma pagina usan `weekStart` = `today - 6 days` (ultimos 7 dias). Son ventanas DIFERENTES.

**Regla:** NO unificar las dos ventanas — son intencionalmente distintas.

**Archivo:** `src/app/(athlete)/nutrition/page.tsx`

---

## T15 — overlayGymSessions: condicion de slot vacio

**Que parece:** Las gym sessions se muestran en cualquier slot del calendario.
**Que es realmente:** Solo se superponen en slots donde `type` es `null` o `'DESCANSO'`. Si agregas un nuevo tipo de sesion que tambien deberia ser sobreescribible, debes actualizar esta condicion.

**Regla:** Al agregar un nuevo `SessionType`, revisar `overlayGymSessions()` en `mobile/dashboard/week-sessions/route.ts`.

**Archivo:** `src/app/api/mobile/dashboard/week-sessions/route.ts` ~linea 67.

---

## T16 — syncWeight recalcula TDEE/macros (roadmap R3)

> **[roadmap R3] PENDIENTE DE ELIMINAR.** La decisión de producto es que syncWeight solo guarda peso en HealthProfile.weightKg. El recálculo de TDEE/macros será eliminado.

**Comportamiento actual (código activo):**
`process_check_in.use_case.ts` → `syncWeight()` detecta |Δkg| >= 0.3 → actualiza `HealthProfile.weightKg` Y recalcula `NutritionPlan` (TDEE, macros, targets por dayType).

**Comportamiento objetivo (post-R3):**
`syncWeight()` solo actualiza `HealthProfile.weightKg`. Sin recálculo de NutritionPlan.

**Riesgo:** si alguien toca el check-in y ve la lógica de peso, puede asumir que el recálculo es intencional. NO lo es — es código zombie pendiente de eliminar.

---

## T17 — toDateString() usa timezone del server (UTC en Vercel)

**Que parece:** `new Date().toDateString()` da la fecha de hoy para el atleta.
**Que es realmente:** En Vercel (UTC), `toDateString()` retorna la fecha en UTC, no en el timezone del usuario. Un atleta en Colombia (UTC-5) que entrena a las 10pm aparece en la fecha del dia siguiente.

**Regla:** SIEMPRE usar `toLocaleDateString('en-CA', { timeZone })` para obtener la fecha local del usuario en formato `YYYY-MM-DD`. Nunca `toDateString()` en server-side.

---

## T18 — req.json() puede lanzar en routes

**Que parece:** `const body = await req.json()` es seguro — el body siempre es JSON valido.
**Que es realmente:** Si el request tiene body vacio, content-type incorrecto, o JSON malformado, `req.json()` lanza una excepcion no capturada que resulta en 500.

**Regla:** SIEMPRE usar `await req.json().catch(() => null)` o `.catch(() => ({}))` en routes. Sin excepcion.

---

## T19 — res.json() en client sin verificar res.ok

**Que parece:** `const data = await res.json()` despues de un fetch en un client component.
**Que es realmente:** Si el servidor retorna 4xx/5xx, `res.json()` puede fallar o retornar un error object que no tiene la forma esperada, causando crashes en la UI.

**Regla:** Verificar `res.ok` ANTES de llamar `res.json()` en client components. Patron: `if (!res.ok) throw new Error(...)`.

---

## T20 — endsWith('') matchea cualquier string en Prisma

**Que parece:** `where: { fingerprint: { endsWith: variable } }` filtra por fingerprint.
**Que es realmente:** Si `variable` es string vacio `''`, `endsWith('')` retorna TODOS los registros — no filtra nada. Es una condicion always-true.

**Regla:** NO usar `endsWith('')` como filtro de fingerprint vacio. Validar que el valor no sea vacio antes de usarlo en un where.

---

## T21 — validAudiences vacio skipea validacion en Google OAuth

**Que parece:** `validAudiences` contiene los client IDs validos para verificar el `aud` del idToken.
**Que es realmente:** Si `GOOGLE_CLIENT_ID_IOS` y `GOOGLE_CLIENT_ID_ANDROID` no estan configurados, el array puede quedar con solo elementos falsy. Un `validAudiences.includes(aud)` con array vacio/solo-falsy skipea la validacion.

**Regla:** Fail-safe obligatorio: si `validAudiences` filtrado tiene 0 elementos → rechazar el token con 500. Nunca aceptar tokens sin audiencias configuradas.

---

## T22 — Mobile set-role sin $transaction rompe atomicidad

**Que parece:** `POST /api/mobile/auth/set-role` asigna rol y crea los registros necesarios.
**Que es realmente:** Si la creacion de `CoachProfile` o `UserSubscription` falla despues del `user.update`, el usuario queda en estado inconsistente (rol cambiado pero sin perfil/suscripcion).

**Regla:** Mobile set-role DEBE crear `User.update` + `CoachProfile` + `UserSubscription` dentro de un `$transaction`, igual que web register.

---

## T23 — ::timestamp vs ::date en raw SQL

**Que parece:** `CAST(val AS timestamp)` y `CAST(val AS date)` son intercambiables para columnas de fecha.
**Que es realmente:** Si la columna DB es `@db.Date` (date-only), usar `::timestamp` puede causar comparaciones incorrectas por la componente de hora. Si es `DateTime`, usar `::date` trunca la hora y puede perder precision.

**Regla:** Usar el cast que matchea el tipo de la columna: `::date` para `@db.Date`, `::timestamp` para `DateTime`.

---

## T24 — PlanBuilder firstEmpty sin guard de semana llena

**Que parece:** `firstEmpty` en el PlanBuilder siempre encuentra un dia vacio para agregar una sesion.
**Que es realmente:** Si los 7 dias de la semana estan ocupados, `firstEmpty` puede retornar `undefined` y causar un crash o comportamiento inesperado.

**Regla:** Buscar `firstEmpty` en rango 1-7 con guard `usedDays.size >= 7` — si la semana esta llena, no permitir agregar mas sesiones.

---

## T25 — builderError state sin renderizar en JSX

**Que parece:** `setBuilderError('mensaje')` muestra el error al usuario.
**Que es realmente:** Si el estado `builderError` no tiene un elemento JSX que lo renderice, el error se setea pero el usuario nunca lo ve. Error silencioso.

**Regla:** Todo estado de error (`builderError`, `error`, etc.) DEBE tener su elemento de renderizado correspondiente en el JSX del componente.
