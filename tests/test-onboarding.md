# Medaliq — Tests E2E Onboarding (B2C Atleta)

**URL base:** `https://www.medaliq.com` / local: `http://localhost:3000`
**Ejecutado:** 2026-07-03 (QA manual + code review) · Re-ejecutado: 2026-07-05 (E2E Chrome MCP, local)
**Usuario de prueba:** `carlos.test.onboarding@medaliq.com` (2026-07-03) · `carlos.qa.e2e@medaliq.com` (2026-07-05)

**Protocolo de capturas:**
- FAIL / PARCIAL → screenshot obligatorio
- PASS en paso de redirección (URL resultante) → screenshot de la URL en barra del navegador
- PASS funcional sin valor numérico → no capturar (registrar solo resultado)

---

## ⚠️ CAMBIOS DE ARQUITECTURA — Leer antes de ejecutar (actualizado 2026-07-10)

| Cambio | Detalle |
|--------|---------|
| `/new-goal` NO EXISTE | La ruta `/new-goal` fue deprecada y no existe como página Next.js. ONB-05 a ONB-09 describen el flujo antiguo. Si el onboarding de Running redirige a `/new-goal` → 404. El comportamiento esperado actual es redirect a `/dashboard`. |
| ONB-05 esperado actualizado | Redirect correcto post-onboarding = `/dashboard` directo (para gym Y running). Si running aún va a `/new-goal` es el bug ARCH-01 aún abierto. |
| ONB-06 a ONB-09 | Tests de `/new-goal` son legacy. Al ejecutar, ir a `/new-goal` manualmente — si es 404, marcar todos como N/A y anotar que ARCH-01 fue cerrado. |
| ONB-JOIN-01 | Referencias a "coach genera código en `/coach/invite`" — la ruta `/coach/invite` no existe como página. El coach no tiene una UI para generar código actualmente. Marcar ONB-JOIN-01 como parcialmente N/A. |
| `WeeklyRoutine` | Eliminado del schema. El onboarding ya no crea `WeeklyRoutine`. Cualquier verificación de ese modelo → N/A. |

---

## SUITE ONB — Registro y Onboarding B2C

### ONB-01 — Registro nuevo atleta: formulario y validación

**Descripción:** Usuario nuevo se registra como atleta en `/register`
**Precondición:** Usuario no existe en DB
**Pasos:**
1. Ir a `/register`
2. Seleccionar "Soy atleta"
3. Llenar nombre, email, contraseña, confirmar contraseña
4. Click "Crear cuenta"

**Esperado:** Cuenta creada. Redirige a `/onboarding`. Sin errores.
**Resultado:** ✅ PASS — Redirigió a `/onboarding` correctamente.
**Notas:** El selector "Soy atleta / Soy coach" funciona con feedback visual (borde naranja al seleccionar).

---

### ONB-02 — Onboarding paso 1: contador de pasos reactivo (BUG-069)

**Descripción:** El contador "Paso X de Y" debe mostrar el total correcto desde el inicio
**Precondición:** Usuario recién registrado en `/onboarding`
**Pasos:**
1. Abrir `/onboarding` sin seleccionar nada
2. Observar el contador de pasos en el header
3. Seleccionar "Running"
4. Observar el contador nuevamente
5. Avanzar al paso 2 y observar el contador

**Esperado:** Contador muestra "Paso 1 de 2" desde el inicio (sin selección).
**Resultado:** ❌ FAIL — El contador cambia 3 veces en el mismo flujo:
- Sin selección: "Paso 1 de 1"
- Al seleccionar Running (paso 1): "Paso 1 de 2"
- Al avanzar al paso 2: "Paso 2 de 2" ✓ (correcto aquí)
El problema es que el total es inestable antes de cualquier selección.
**Bug:** BUG-069 — `src/app/onboarding/page.tsx:423` — `totalSteps` depende de `getSteps(data)` reactivo. El array `steps` crece al seleccionar actividad, el contador lo refleja en tiempo real.
**Re-ejecutado:** 2026-07-05 — confirmado mismo comportamiento, con variación: el contador muestra 3 estados distintos durante el flujo completo.

---

### ONB-03 — Onboarding paso 1: opciones de actividad

**Descripción:** El usuario ve las opciones de actividad y elige Running
**Pasos:**
1. Observar las opciones disponibles
2. Seleccionar "Running"
3. Click "Siguiente"

**Esperado:** 2 opciones claras (Ejercicios / Running). Selección con feedback visual. Avanza al paso 2.
**Resultado:** ✅ FIXED (UX-01) — Re-ejecutado 2026-07-05: el onboarding ahora muestra exactamente 2 opciones: "Running" y "Ejercicios". Feedback visual con borde naranja al seleccionar. Avanza correctamente al paso 2.
**Notas:** UX-01 aplicado. "Solo trackear" y "Ejercicios+Running" eliminados de los selectores.

---

### ONB-04 — Onboarding paso 2: datos personales (label Talla vs Altura)

**Descripción:** El usuario llena sus datos físicos
**Pasos:**
1. Llenar Edad: 28
2. Observar label del campo de altura
3. Llenar Altura (cm): 172
4. Llenar Peso actual (kg): 70
5. Seleccionar género: Hombre
6. Verificar días disponibles pre-seleccionados: 4 días

**Esperado:** Label dice "Altura (cm)". Valores se guardan correctamente.
**Resultado:** ✅ FIXED (UX-02) — Re-ejecutado 2026-07-05: el label ahora dice "Altura (cm)". Todos los campos se llenan y guardan correctamente.
**Notas:** UX-02 aplicado. Datos usados en E2E: Edad 28 · Altura 172 cm · Peso 70 kg · Género Hombre · Nivel Intermedio.

---

### ONB-05 — Onboarding: submit y redirección post-onboarding

**Descripción:** Al completar el onboarding de Running, se guarda el perfil y redirige
**Pasos:**
1. Con todos los datos llenos (paso 2), seleccionar nivel "Intermedio"
2. Click "Guardar y entrar"
3. Esperar respuesta y observar redirección

**Esperado actual (2026-07-10):** Redirige directamente a `/dashboard`. `/new-goal` no existe como página — si el redirect va ahí → 404 = bug activo ARCH-01 aún abierto.
**Esperado según ARCH-01:** POST `/api/onboarding/generate` devuelve 200. Redirige directamente a `/dashboard`.
**Resultado:** ✅ PASS (flujo funciona) / ⚠️ ARCH-01 aún abierto — Re-ejecutado 2026-07-05: el onboarding de Running sigue redirigiendo a `/new-goal`. HealthProfile guardado correctamente en DB. El roadmap marcaba ARCH-01 como done pero el comportamiento en develop no lo refleja.
**Inconsistencia activa:** Gym → `/dashboard` directo. Running → `/new-goal` → `/dashboard`. Paso extra sin valor real.

---

### ONB-06 — /new-goal: pre-selección de meta no coincide con deporte elegido (BUG-070)

**Descripción:** La meta pre-seleccionada debe corresponder al deporte del onboarding
**Precondición:** Usuario completó onboarding con activityType=RUNNING
**Pasos:**
1. Observar `/new-goal` al llegar
2. Verificar cuál opción está pre-seleccionada
3. Verificar si el banner "Pre-seleccionado según tu onboarding" aparece
4. Seleccionar manualmente "10K"
5. Verificar si el banner aparece ahora

**Esperado:** Pre-selección = 5K o 10K (coherente con Running). Banner solo si la selección coincide con lo del onboarding.
**Resultado:** ❌ FAIL — Re-ejecutado 2026-07-05:
- Al llegar: ninguna opción visualmente pre-seleccionada (estado inicial = null)
- El `defaultGoal` que llega del server no coincide con ninguna opción GOALS de running → `selected` inicia null
- Al seleccionar manualmente "10K": el banner "Pre-seleccionado según tu onboarding" aparece → **banner engañoso** (el usuario hizo la selección, no el sistema)
**Causa raíz:** En `NewGoalClient.tsx`, el banner se muestra cuando `defaultGoal && selected` — condición verdadera siempre que el usuario haya seleccionado algo Y exista un defaultGoal (aunque no coincidan). Fix: `selected?.value === defaultGoal`.
**Bug adicional descubierto:** Las opciones incluyen "Fitness general" y "Ganar músculo" (metas de gym) para un atleta que se registró como runner — **BUG-NEW-02** (ver sección nueva).
**Bug:** BUG-070 — `NewGoalClient.tsx` — lógica del banner incorrecta + `defaultGoal` no mapea RUNNING→RACE_5K/RACE_10K.

---

### ONB-07 — /new-goal: semanas mostradas como opción fija (UX-03)

**Descripción:** Las semanas deben calcularse automáticamente, no mostrarse como dato fijo
**Pasos:**
1. Observar las opciones de meta: "5K — Carrera de 5 km — 8 semanas", "10K — Carrera de 10 km — 12 semanas"
2. Verificar si hay campo de fecha de evento
3. Intentar entender el flujo como usuario nuevo

**Esperado:** El usuario elige distancia + (opcional) fecha evento → sistema calcula semanas automáticamente.
**Resultado:** ❌ FAIL — Re-ejecutado 2026-07-05: las semanas siguen aparecidas como parte fija del label de cada opción. Hay un campo de fecha de evento pero no actualiza el número de semanas mostrado — es cosmético.
**Mejora pendiente:** UX-03 (roadmap) — fecha evento → semanas auto-calculadas con mínimo 4 semanas. El campo de fecha existe en UI pero su valor no afecta el label de semanas.

---

### ONB-08 — /new-goal: guardar meta y redirigir a dashboard ~~(BUG-071)~~

**Descripción:** El atleta selecciona 10K y hace click en el CTA de /new-goal
**Pasos:**
1. Seleccionar "10K"
2. (Opcional) ingresar fecha del evento
3. Click "Guardar meta — 10K →"
4. Esperar respuesta

**Esperado:** goalType guardado en HealthProfile. Redirige a `/dashboard`. Sin generación de plan.
**Resultado:** ✅ FIXED (BUG-071 + UX-04 — branch bugfix/mvp-ux-flows)
**Fix aplicado:** `NewGoalClient.tsx` llama `PATCH /api/athlete/sport` (no `POST /api/plan/new`). El endpoint hace `healthProfile.upsert({ sportGoal: goalType })` y retorna `{ ok: true }`. El cliente redirige a `/dashboard`.
**Nota ARCH-01:** La ruta `/new-goal` sigue existiendo pero está pendiente de deprecación formal. No hay navegación visible que lleve al usuario a ella desde el dashboard FREE. El onboarding RUNNING aún puede redirigir aquí — ver inconsistencia abajo.

---

### ONB-09 — /new-goal: metas de gym visibles para atleta runner (BUG-NEW-02)

**Descripción:** El catálogo de metas en `/new-goal` debe filtrar opciones según el deporte elegido en el onboarding
**Precondición:** Usuario completó onboarding con activityType=RUNNING
**Pasos:**
1. Llegar a `/new-goal` desde onboarding Running
2. Observar todas las opciones de meta disponibles
3. Verificar si aparecen "Fitness general", "Ganar músculo", "Recomposición corporal"

**Esperado:** Solo metas de running: 5K, 10K. Sin metas de gym.
**Resultado:** ❌ FAIL — Las opciones incluyen metas de gym/fuerza ("Fitness general", "Ganar músculo", "Recomposición corporal") para un usuario que se registró como runner. Incoherencia de contexto: el usuario que eligió running no tiene por qué planificar ganar músculo como próxima meta.
**Causa raíz:** El componente `NewGoalClient.tsx` renderiza la lista `GOALS` completa sin filtrar por `activityType` del perfil.
**Fix sugerido:** Pasar `activityType` como prop y filtrar: `activityType === 'RUNNING' ? GOALS.filter(g => g.category === 'running') : GOALS`.
**Bug:** BUG-NEW-02 — `src/app/(athlete)/new-goal/_components/NewGoalClient.tsx` — GOALS no filtrados por deporte.

---

### ONB-10 — Registro: typo de marca en pantalla de bienvenida (BUG-NEW-01)

**Descripción:** El nombre de la app debe aparecer como "Medaliq" (sin doble L)
**Precondición:** Ninguna
**Pasos:**
1. Ir a `/register`
2. Leer el header/título de la pantalla

**Esperado:** "Medaliq" — una L.
**Resultado:** ❌ FAIL — El texto muestra "Medalliq" (doble L). Error tipográfico de marca.
**Bug:** BUG-NEW-01 — typo en componente de registro. Buscar "Medalliq" en `src/app/register/` y corregir a "Medaliq".

---

## RESUMEN DE SUITE ONB

| Test | Resultado 2026-07-03 | Resultado 2026-07-05 (E2E Chrome MCP) | Bug/Mejora |
|------|---------------------|---------------------------------------|------------|
| ONB-01 — Registro nuevo atleta | ✅ PASS | ✅ PASS | — |
| ONB-02 — Contador pasos reactivo | ❌ FAIL | ❌ FAIL (3 estados en flujo) | BUG-069 (P3) |
| ONB-03 — Opciones de actividad | ⚠️ PARCIAL (4 opts) | ✅ FIXED | UX-01 aplicado |
| ONB-04 — Label Talla vs Altura | ⚠️ PARCIAL | ✅ FIXED | UX-02 aplicado |
| ONB-05 — Submit y redirección | ✅ PASS | ⚠️ ARCH-01 abierto | Running → /new-goal (aún) |
| ONB-06 — Pre-selección meta incorrecta | ❌ FAIL | ❌ FAIL (banner engañoso) | BUG-070 (P2) |
| ONB-07 — Semanas fijas en opciones | ❌ FAIL | ❌ FAIL | UX-03 (P1) |
| ONB-08 — Guardar meta y redirigir | ❌ FAIL | ✅ FIXED | BUG-071 + UX-04 |
| ONB-09 — Metas gym visibles a runner | N/A | ❌ FAIL | BUG-NEW-02 (P2) |
| ONB-10 — Typo "Medalliq" en registro | N/A | ❌ FAIL | BUG-NEW-01 (P3) |

**Total 2026-07-05:** 10 tests · 3 PASS · 4 FAIL · 1 PARCIAL · 2 FIXED

---

## INCONSISTENCIAS DETECTADAS EN EL FLUJO

### Coherencia actividad seleccionada → meta pre-seleccionada
- Onboarding paso 1: usuario elige "Running"
- `/new-goal`: no pre-selecciona nada (estado inicial null) — incoherente ❌
- `/new-goal`: muestra metas de gym (Fitness general, Ganar músculo) a un runner — incoherente ❌ **BUG-NEW-02**
- Al seleccionar manualmente una meta, aparece banner "Pre-seleccionado según tu onboarding" — engañoso ❌ **BUG-070**

### Semanas: presentadas como característica de la meta vs calculadas desde fecha
- Las semanas (8, 12) deberían desaparecer del label de la opción y calcularse automáticamente desde la fecha del evento que el usuario ingresa
- El campo de fecha de evento existe pero no afecta el número de semanas mostrado

### ~~Flujo Running bloqueado en producción~~ — RESUELTO (BUG-071 + UX-04)
- ~~El 100% de atletas nuevos con activityType=RUNNING quedan bloqueados en `/new-goal`~~
- `/new-goal` ahora guarda la meta vía `PATCH /api/athlete/sport` y redirige al dashboard. Sin generación de plan, sin FK constraint. ✅ RESUELTO

### Onboarding gym vs onboarding running — flujo asimétrico (pendiente ARCH-01)
- Gym: completa datos → `/dashboard` directamente ✅
- Running: completa datos → `/new-goal` (guarda goalType) → `/dashboard` ⚠️ paso extra sin valor real
- El paso `/new-goal` es redundante: guarda un campo que podría guardarse en el onboarding mismo o desde el dashboard. La ruta existe pero está huérfana (ningún CTA del dashboard FREE apunta a ella). Deprecación formal pendiente en ARCH-01.
- **Confirmado en E2E 2026-07-05** (develop branch): ARCH-01 aún no aplicado — onboarding Running sigue redirigiendo a /new-goal.

---

## SUITE ONB-JOIN — Registro por código de invitación (B2B) — E2E 2026-07-06

> Flujo NO cubierto por las suites ONB previas (que son B2C self-register). Ejecutado en local (localhost:3000, Claude Preview) creando un coach nuevo, generando código de invitación y registrando un atleta por `/join/[code]`. Cuentas de prueba: `qa.coach.07061151@medaliq.test`, `qa.atleta.07061151@medaliq.test`.

### ONB-JOIN-01 — Landing de invitación `/join/[code]`
**⚠️ Nota:** `/coach/invite` no existe como página — el coach no tiene UI dedicada para generar invitaciones actualmente. El link `<a href="/coach/invite">` en el dashboard lleva a 404. Para probar este flujo usar un código de invitación generado directamente en DB o vía API.
**Pasos:** ~~coach genera código en `/coach/invite`~~ → visitante abre `/join/MEDAL-XXXXXX`.
**Esperado:** muestra avatar + nombre del coach, "Te invita a entrenar en Medaliq", código, CTAs "Crear mi cuenta" / "Ya tengo cuenta".
**Resultado:** ✅ PASS — landing con branding del coach, limpia.

### ONB-JOIN-02 — Registro por código no aprovecha contexto de invitación (BUG-NEW-10)
**Pasos:** clic "Crear mi cuenta" → redirige a `/register?code=MEDAL-XXXXXX`.
**Esperado:** el form debería pre-seleccionar rol "Soy atleta" y mostrar a qué coach se une.
**Resultado:** ❌ FAIL — muestra el selector de rol genérico (Soy atleta / Soy coach) sin pre-selección y sin mencionar el coach. Se pierde el contexto de la invitación.
**Bug:** **BUG-NEW-10** (P3) — `src/app/register/page.tsx` — leer `searchParams.code`, pre-seleccionar ATHLETE y mostrar el coach objetivo.

### ONB-JOIN-03 — Confirmación de vínculo y onboarding
**Pasos:** completar registro (rol atleta) → "Unirme al coach" → onboarding (actividad + datos físicos) → guardar.
**Esperado:** atleta queda vinculado al coach y con datos físicos para el cálculo Mifflin.
**Resultado:** ✅ PASS — "Unirme al coach" confirma el vínculo; onboarding captura edad/altura/peso/género/días/nivel. Contador de pasos inconsistente ("1 de 1" → "2 de 2" → "2 de 3") ya trackeado en **BUG-069**.

### ONB-JOIN-04 — Atleta vinculado sigue viendo "Busca un entrenador" (BUG-NEW-09)
**Pasos:** tras unirse por código, ir al home del atleta (`/dashboard`).
**Esperado:** el home NO debe ofrecer "Busca un entrenador" — el atleta YA tiene coach (aparece ACTIVO en `Mis Atletas` del coach y su mensajería es 1:1 con el coach).
**Resultado:** ❌ FAIL — el home del atleta muestra la card "Busca un entrenador / Un coach diseña tu plan personalizado…" pese a estar vinculado.
**Bug:** **BUG-NEW-09** (P2) — home del atleta (`/dashboard`) — la condición que renderiza la card de "buscar coach" no considera el coach ya vinculado. Verificar el flag de coach asignado (relacionado con `featureCoach`/relación coach-atleta) en el componente del dashboard atleta.

### Resumen SUITE ONB-JOIN (2026-07-06)
| Test | Resultado | Bug |
|------|-----------|-----|
| ONB-JOIN-01 — Landing invitación | ✅ PASS | — |
| ONB-JOIN-02 — Contexto invitación en /register?code | ❌ FAIL | BUG-NEW-10 (P3) |
| ONB-JOIN-03 — Vínculo + onboarding | ✅ PASS | (contador pasos = BUG-069) |
| ONB-JOIN-04 — Atleta vinculado ve "Busca entrenador" | ❌ FAIL | BUG-NEW-09 (P2) |
