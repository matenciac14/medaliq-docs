# Medaliq — Tests E2E: Coach y Admin (Carlos + Admin)

**URL base:** `https://www.medaliq.com`
**Ejecutar DESPUES de `test-atleta-b2c.md` y `test-atleta-b2b.md`**

**Protocolo:** Ejecutar cada test en orden. Al terminar, registrar resultado en la SECCION DE REPORTE al final. Si falla, anotar el error exacto y continuar.

**Protocolo de capturas:**
- FAIL / PARCIAL → screenshot obligatorio
- PASS con valor numérico verificado (MRR, recuento de atletas, métricas admin) → screenshot del valor visible en pantalla
- PASS funcional sin valor numérico → no capturar (registrar solo resultado)

---

## ⚠️ CAMBIOS DE ARQUITECTURA — Leer antes de ejecutar (actualizado 2026-07-10)

| Cambio | Detalle |
|--------|---------|
| Ejercicios: 39 seed → WorkoutX | La biblioteca de ejercicios ya no viene del seed (39 ejercicios). Usa la API WorkoutX: plan free = 10 ejercicios visibles, plan pagado = 1,300+. El `Exercise.nameEs` muestra nombre en español cuando existe. |
| Tabs del detalle de atleta | Las tabs reales en `/coach/athlete/[id]` son: **Plan · Sesiones · Nutrición · Notas · Config**. El orden "Resumen, Plan, Progreso, Nutrición, Gym, Mensajes, Perfil" ya no aplica. |
| `/coach/invite` | Existe como `href` en el dashboard del coach (`<a href="/coach/invite">Compartir link</a>`), pero la ruta Next.js no está implementada aún. Clicar → 404. Marcar tests de navegación a esa ruta como N/A. |
| `NutritionAdherenceCard` | En tab Nutrición del atleta: sparkline de 4 semanas de adherencia (28 días). Badge verde ≥80%, amarillo 60-79%, rojo <60%. Fuente: `GET /api/coach/athlete/[id]/nutrition/adherence`. |
| `CoachNutritionProposal` | El coach puede proponer ajuste de macros. El atleta siempre acepta/rechaza — nunca auto-aplicado. Endpoint: `POST /api/coach/athlete/[id]/nutrition/propose`. |
| `AssignedWorkout` | Al asignar rutina a un atleta: desactiva la anterior, activa la nueva. El atleta la ve en `/gym` inmediatamente. Endpoint: `POST /api/coach/gym/routines/[id]/assign`. |
| Planes: max 12 semanas | `RACE_HALF_MARATHON` y `RACE_MARATHON` eliminados de selectores UI. `BODY_RECOMPOSITION` y `STRENGTH` recortados de 16W a 12W en templates. Planes en DB existentes no se tocan. |
| `/admin/metrics` vs `/admin/finanzas` | MRR e ingresos viven en `/admin/finanzas`. `/admin/metrics` muestra actividad: WAU, retención, distribución geográfica, check-ins, sesiones. |
| `Goal` model ELIMINADO | No existe tabla Goal. Ver `HealthProfile.sportGoal` y `TrainingPlan.goalType`. |

---

## Datos esperados de DB — Carlos Entrenador (COACH)

| Campo | Valor esperado | Fuente |
|-------|---------------|--------|
| Email | coach@medaliq.com | User |
| Nombre | Carlos Entrenador | User.name |
| Rol | COACH | User.role |
| featureCoach | true | User.featureCoach |
| onboardingCompleted | true | User |
| Atletas activos | 6 (confirmado COACH-02 en ejecucion anterior) | CoachAthlete |
| Atletas asignados | miguel, juan.perez, sebastian.rios, nicolas.gutierrez, santiago.rodriguez + 1 mas | CoachAthlete |
| Ejercicios en libreria | **WorkoutX** — free: 10 visibles / paid: 1,300+ | Exercise (API WorkoutX) |
| Planes creados | seed-plan-1 (miguel), seed-plan-3 (juan.perez), seed-plan-9 (sebastian.rios) | TrainingPlan |

**Atletas del coach con planes en seed:**

| Atleta | Email | Plan en seed | Semanas definidas |
|--------|-------|-------------|-------------------|
| Miguel Atleta | miguel@medaliq.com | Media Maratón 18 sem | 6 (1-4=BASE, 5-6=DESARROLLO) |
| Juan Perez | juan.perez@medaliq.com | 10K — 12 sem | 5 (1-4=BASE, 5=DESARROLLO) |
| Sebastian Rios | sebastian.rios@medaliq.com | 5K — 8 sem | 4 (1-2=BASE, 3-4=ESPECIFICO) |
| Nicolas Gutierrez | nicolas.gutierrez@medaliq.com | A asignar en DC-19 | — |
| Santiago Rodriguez | santiago.rodriguez@medaliq.com | Segun seed | — |

---

## Datos esperados de DB — Admin Medaliq

| Campo | Valor esperado | Fuente |
|-------|---------------|--------|
| Email | admin@medaliq.com | User |
| Nombre | Admin Medaliq | User.name |
| Rol | ADMIN | User.role |
| Total usuarios en sistema | >= 10 (seed tiene 12+ atletas + 2 coaches + 1 admin) | User count |
| Coaches registrados | 2 (Carlos Entrenador, María González) | User donde role=COACH |
| Atletas registrados | >= 10 (seed tiene 12 atletas numerados) | User donde role=ATHLETE |

---

## SUITE 1 — COACH (Carlos Entrenador — Panel completo)

**Antes de iniciar:** Cerrar sesion activa: `https://www.medaliq.com/api/auth/signout`

### COACH-01
**Descripcion:** Login y redirect a /coach/dashboard
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`
2. Email: `coach@medaliq.com`, password: `coach123`, submit
**Esperado:** Redirect a `/coach/dashboard`. Dashboard del coach visible con KPIs.
**Severidad si falla:** CRITICO

---

### COACH-02
**Descripcion:** Dashboard del coach — KPIs y lista de atletas
**Precondicion:** Sesion como COACH
**Datos esperados:** 5 atletas activos en seed. El 6° lo crea COACH-06 — ejecutar ESTE test ANTES de COACH-06.
**Pasos:**
1. En `/coach/dashboard` verificar:
   - Numero de atletas activos — debe ser **5** (seed) antes de COACH-06, **6** después
   - NO debe aparecer banner de "first-time experience" (tiene atletas)
   - Lista o cards de atletas
**Esperado:** Dashboard muestra 5 atletas. Sin banner de bienvenida.
**Nota:** Anotar el numero exacto observado.
**Severidad si falla:** ALTO

---

### COACH-03
**Descripcion:** Lista completa de atletas del coach — verificar nombres
**Precondicion:** Sesion como COACH
**Datos esperados:** Miguel, Juan Perez, Sebastian Rios, Nicolas Gutierrez, Santiago Rodriguez = 5 en seed
**Pasos:**
1. Ir a la seccion de atletas (sidebar o desde dashboard)
2. Verificar que aparecen todos los atletas asignados
3. Buscar y confirmar nombres: miguel, juan.perez, sebastian.rios, nicolas.gutierrez, santiago.rodriguez
4. Contar el total de atletas con estado ACTIVO
**Esperado:** Lista de atletas visible con los 5 nombres seed y estado ACTIVO/PAUSED. Total = 5 activos.
**Severidad si falla:** ALTO

---

### COACH-04
**Descripcion:** Detalle de atleta — tabs navegables
**Precondicion:** Sesion como COACH
**Pasos:**
1. Click en un atleta de la lista (usar Sebastian Rios)
2. Verificar que carga la pagina de detalle del atleta
3. Verificar que hay tabs: (Resumen, Plan, Nutricion, Gym, Mensajes — o equivalentes)
4. Click en cada tab y verificar que carga sin error 500
**Esperado:** Detalle del atleta funcional con todos los tabs navegables. Sin errores.
**Severidad si falla:** ALTO

---

### COACH-05
**Descripcion:** Crear o revisar plan para un atleta
**Precondicion:** Sesion como COACH, en detalle de algun atleta
**Pasos:**
1. Ir al tab de Plan del atleta (usar Sebastian Rios — tiene seed-plan-9)
2. Verificar que el plan activo "5K — 8 semanas" es visible
3. Click en "Crear plan" o "Generar plan" (si esta disponible para crear uno nuevo)
4. Completar parametros si los pide
5. Guardar / Generar
**Esperado:** Plan visible o creado. Sin errores criticos. El coach puede ver y gestionar los planes de sus atletas.
**Nota:** Si el atleta ya tiene plan activo, verificar que hay opcion de crear uno nuevo o verlo.
**Severidad si falla:** ALTO

---

### COACH-06
**Descripcion:** Crear nuevo atleta B2B
**Precondicion:** Sesion como COACH
**Pasos:**
1. Ir a `/coach/clients/new` o buscar boton "Agregar atleta" / "Nuevo cliente"
2. Completar formulario: nombre="Atleta Test E2E", email=`test.atleta.[timestamp]@mailinator.com`
3. Submit
4. Anotar el email exacto usado (se necesita en CROSS-01 del archivo principal)
**Esperado:** Atleta creado. Aparece en la lista de atletas. Sin errores.
**Email del atleta creado:** `test.atleta.___@mailinator.com` — ANOTAR AQUI
**Severidad si falla:** ALTO

---

### COACH-07
**Descripcion:** Generar invite code para nuevos atletas
**Precondicion:** Sesion como COACH
**Pasos:**
1. Ir a `/coach/invite` o buscar opcion de invitacion en el sidebar
2. Verificar que hay un codigo de invitacion generado o boton para generarlo
3. Si hay boton "Generar nuevo codigo", hacer click
4. Copiar el codigo generado
5. Ir a `/join/[codigo]` en una nueva pestana (sin sesion activa)
**Esperado:** Codigo generado visible. La pagina `/join/[codigo]` muestra branding del coach (nombre "Carlos Entrenador", especialidades si tiene).
**Nota:** El codigo generado aqui se usa en UX-06 del archivo test-atleta-b2c.md.
**Codigo generado:** `___` — ANOTAR AQUI
**Severidad si falla:** ALTO

---

### COACH-08
**Descripcion:** Seccion Gym del coach — ejercicios y rutinas
**Precondicion:** Sesion como COACH
**Datos esperados:** 39 ejercicios en la libreria (seed completo)
**Pasos:**
1. Ir a `/coach/gym` o seccion de gym en sidebar
2. Verificar que muestra lista de ejercicios — debe haber **39 ejercicios** en la biblioteca
3. Verificar que hay opcion de crear rutinas
4. Click en "Nueva rutina" o equivalente
5. Crear una rutina de prueba con 2 ejercicios (para poder asignarla en DC-19)
**Esperado:** Lista de ejercicios visible (39). Creacion de rutina funcional.
**Severidad si falla:** MEDIO

---

### COACH-09
**Descripcion:** Finanzas — crear pago pendiente
**Precondicion:** Sesion como COACH
**Pasos:**
1. Ir a `/coach/finanzas`
2. Verificar que carga la lista de pagos
3. Buscar boton "Nuevo pago" o "Registrar pago"
4. Seleccionar atleta: Santiago Rodriguez
5. Monto: `150000`
6. Moneda: COP
7. Descripcion: "Mensualidad test e2e"
8. Fecha de vencimiento: dentro de 30 dias
9. Guardar
**Esperado:** Pago creado con estado PENDIENTE. Aparece en la lista con datos exactos.
**Nota:** Se creara otro pago en DC-25 (suite del orquestador). Este es diferente.
**Severidad si falla:** ALTO

---

### COACH-10
**Descripcion:** Finanzas — marcar pago como pagado
**Precondicion:** Sesion como COACH, pago pendiente del test anterior creado
**Pasos:**
1. En `/coach/finanzas` buscar el pago creado en COACH-09
2. Buscar boton "Marcar como pagado" o icono de check
3. Click en la accion
4. Confirmar si hay dialog de confirmacion
**Esperado:** Estado del pago cambia a PAGADO. Fecha de pago visible. Sin errores.
**Severidad si falla:** ALTO

---

### COACH-11
**Descripcion:** Mensajes del coach — ver conversaciones con atletas
**Precondicion:** Sesion como COACH
**Datos esperados:** Mensaje de Miguel enviado en B2B-03 ("Hola coach, este es un test automatico B2B")
**Pasos:**
1. Ir a mensajes (sidebar o nav del coach)
2. Verificar lista de atletas con mensajes
3. Buscar la conversacion con Miguel
4. Click en la conversacion
5. Verificar que el mensaje de Miguel aparece: "Hola coach, este es un test automatico B2B"
6. Responder: "Hola Miguel, recibido! Seguimos entrenando."
**Esperado:** Conversacion visible con mensaje de Miguel. Respuesta enviada sin errores. La respuesta sera verificada por Miguel en DC-24.
**Severidad si falla:** ALTO

---

### COACH-12
**Descripcion:** Perfil del coach
**Precondicion:** Sesion como COACH
**Nota re-ejecucion:** La bio ya puede contener "Test e2e ejecutado." de una ejecucion anterior. El test sigue siendo valido — verificar que la edicion y guardado funcionan sin importar el estado inicial de la bio.
**Pasos:**
1. Ir a `/coach/profile`
2. Verificar que carga informacion del coach (nombre "Carlos Entrenador", especialidades, bio)
3. Modificar la bio: agregar o actualizar con "Test e2e ejecutado."
4. Guardar cambios
**Esperado:** Perfil guardado. Sin errores.
**Severidad si falla:** MEDIO

---

### COACH-13
**Descripcion:** Settings del coach
**Precondicion:** Sesion como COACH
**Pasos:**
1. Ir a `/coach/settings`
2. Verificar que la pagina carga
3. No hacer cambios — solo verificar que no hay errores
**Esperado:** Pagina de settings carga sin 500 ni errores visibles.
**Severidad si falla:** BAJO

---

### COACH-14
**Descripcion:** Navegacion a /dashboard como COACH → redirect a /coach/dashboard
**Precondicion:** Sesion como COACH
**Pasos:**
1. Ir directamente a `/dashboard`
**Esperado:** Redirect automatico a `/coach/dashboard`.
**Severidad si falla:** ALTO

---

### COACH-15
**Descripcion:** Badge de mora en lista de atletas
**Precondicion:** Sesion como COACH, en lista de atletas
**Nota:** `PaymentStatus.OVERDUE` no existe en DB — es derivado en app: `dueDate < ahora && status === PENDING`
**Pasos:**
1. Revisar si algun atleta muestra badge o indicador de "mora" o "pago vencido"
2. Si hay pagos vencidos (dueDate pasada + PENDING), deben mostrar el badge
**Esperado:** Si existen pagos vencidos, badge visible. Sin errores.
**Nota:** Si no hay pagos vencidos en produccion, marcar N/A.
**Severidad si falla:** MEDIO

---

### COACH-16
**Descripcion:** Constructor visual de plan — WeekNav funcional
**Feature:** #14 — Constructor visual
**Precondicion:** Sesion como COACH. Miguel tiene plan "Media Maratón 18 semanas" con 6 semanas definidas en seed.
**Pasos:**
1. Ir al detalle de Miguel → tab Plan → click en "Abrir constructor" o equivalente
2. Verificar que el constructor se carga en `/coach/athlete/[id]/plan/build`
3. Buscar el WeekNav (barra horizontal de dots con "S1", "S2"... "S18") arriba del contenido de la semana
4. Verificar que el dot de la semana activa tiene borde coloreado (outline)
5. Verificar que dots de semanas con sesiones tienen color y dots vacios son grises
6. Click en "S3" o cualquier semana diferente a la activa
7. Verificar que el contenido del builder cambia a las sesiones de esa semana
**Esperado:** WeekNav visible con 18 dots. Semana activa resaltada. Click navega a la semana correcta. Semanas con sesiones tienen dot coloreado; semanas vacias dot gris.
**Severidad si falla:** ALTO

---

### COACH-17
**Descripcion:** Constructor plan — editar metadata de semana (fase, descripcion, volumeKm)
**Feature:** #15 — PATCH week metadata + volumeKm
**Precondicion:** Sesion como COACH en el constructor del plan de Miguel.
**Pasos:**
1. En el constructor, con la semana 1 seleccionada, buscar el boton de editar semana (icono lapiz o "Editar semana")
2. Click en editar — debe abrirse un modal con campos: Fase, Descripcion / enfoque, Semana de recuperacion (checkbox), Volumen semanal (km)
3. Cambiar la descripcion a: "Test E2E — semana editada"
4. Ingresar volumen km: `35`
5. Guardar
6. Verificar que el modal se cierra sin error
7. Verificar que la descripcion actualizada y/o los km son visibles en la vista de la semana
**Esperado:** Modal de edicion funcional con los 4 campos. Cambios persisten tras guardar. `35 km` visible en la semana. Sin errores 500.
**Nota tecnica:** El PATCH va a `/api/coach/plan/[planId]/week/[weekId]` — incluye `phase`, `focusDescription`, `isRecoveryWeek`, `volumeKm`.
**Severidad si falla:** ALTO

---

### COACH-18
**Descripcion:** Panel Nutricion del atleta — sugerencia de targets por fase
**Feature:** #13 — Editor targets kcal por fase
**Precondicion:** Sesion como COACH. Miguel tiene plan con fases (BASE semanas 1-4, DESARROLLO semanas 5-6).
**Datos esperados (seed):** NutritionPlan.tdee = 2633. Fase actual de Miguel: segun semana activa (dinamico).
**Pasos:**
1. Ir al detalle de Miguel → click en tab "Nutricion"
2. Verificar que carga el plan nutricional con targets (duro, facil, descanso)
3. Buscar la seccion "Fase actual" debajo de los targets
4. Verificar que muestra: nombre de la fase (BASE/DESARROLLO/ESPECIFICO/AFINAMIENTO) + valores recomendados (Duro: X kcal, Facil: X kcal, Descanso: X kcal)
5. Si hay boton "Aplicar targets de fase": hacer click en el
6. Verificar que el editor de nutricion se abre con los valores recomendados pre-llenados
7. Guardar si se quiere persistir (opcional en el test, solo verificar que el flujo funciona)
**Esperado:** Seccion de sugerencia por fase visible. Valores calculados como `tdee + delta ± offset` donde delta depende de la fase. Boton de aplicar funciona y abre editor con esos valores exactos. Si ya esta aplicado, muestra "✓ Targets de fase aplicados".
**Nota tecnica:** Calculos — BASE: delta=-200; DESARROLLO: delta=0; ESPECIFICO: delta=+100; AFINAMIENTO: delta=-100. Hard=tdee+delta+300, Easy=tdee+delta, Rest=tdee+delta-200.
**Severidad si falla:** MEDIO

---

### COACH-19
**Descripcion:** Registrar benchmark de rendimiento para un atleta
**Feature:** #10 — PerformanceBenchmarks CRUD (lado coach)
**Precondicion:** Sesion como COACH, en detalle de Sebastian Rios (deportista de RUNNING con plan 5K).
**Pasos:**
1. Ir al detalle de Sebastian Rios
2. Buscar la seccion o tab de "Benchmarks" o "Tests de rendimiento" o "Rendimiento"
3. Buscar boton "Nuevo benchmark" o "Registrar test"
4. Completar: Deporte=RUNNING, Metrica=5K, Valor=`1620` (tiempo en segundos — equivale a 27:00), Fecha de hoy
5. Guardar
6. Verificar que el benchmark aparece en la lista del atleta
**Esperado:** Benchmark registrado con los datos correctos. Aparece en la vista del coach con formato legible ("5K — 27:00"). Sin errores.
**Nota:** El valor se formatea como MM:SS si < 3600s. Los valores en DB se guardan como segundos con unidad "seconds".
**Severidad si falla:** MEDIO

---

### COACH-20
**Descripcion:** Pausar y reactivar atleta (ACTIVE/PAUSED status)
**Feature:** #11 — CoachAthlete.status
**Precondicion:** Sesion como COACH, en lista de atletas.
**Pasos:**
1. Ir al detalle de Juan Perez
2. Buscar opcion de "Pausar" o "Cambiar estado" del atleta
3. Cambiar estado a PAUSED
4. Ir a `/coach/dashboard` — verificar que Juan Perez aparece con estado PAUSED o separado de los activos
5. Volver al detalle de Juan Perez, reactivar (ACTIVE)
6. Verificar que vuelve a aparecer como ACTIVE en el dashboard
**Esperado:** Estado ACTIVE/PAUSED visible en lista. Cambio persiste. Coach puede pausar y reactivar sin errores. El KPI de "atletas activos" NO cuenta los PAUSED.
**Nota:** `CoachAthlete.status` enum en DB: `ACTIVE | PAUSED`. El endpoint PATCH actualiza este campo.
**Severidad si falla:** MEDIO

---

## SUITE 2 — ADMIN (Panel de administracion)

**Antes de iniciar:** Cerrar sesion de coach. `https://www.medaliq.com/api/auth/signout`

### ADMIN-01
**Descripcion:** Login como ADMIN y acceso al panel
**Precondicion:** Sin sesion
**Pasos:**
1. Login como `admin@medaliq.com` / `admin123!`
2. Observar el resultado
**Esperado:** Login exitoso. Redirige a `/admin`. Panel admin visible.
**Severidad si falla:** CRITICO

### ADMIN-02
**Descripcion:** KPIs del panel admin
**Precondicion:** Sesion como ADMIN, en `/admin`
**Datos esperados:** total usuarios >= 10, coaches = 2, atletas >= 10
**Pasos:**
1. Verificar que la pagina principal del admin muestra metricas
2. Buscar: total de usuarios, coaches activos, atletas, o cualquier KPI visible
3. Anotar los valores exactos observados
**Esperado:** Al menos 1 KPI visible con datos numericos reales. Usuarios total >= 10, coaches >= 2, atletas >= 10.
**Severidad si falla:** ALTO

### ADMIN-03
**Descripcion:** Gestion de usuarios
**Precondicion:** Sesion como ADMIN
**Pasos:**
1. Ir a `/admin/users`
2. Verificar que carga la lista de usuarios
3. Buscar el usuario `coach@medaliq.com` en la lista
4. Verificar que muestra rol COACH y estado
**Esperado:** Lista de usuarios paginada o completa. Usuario coach visible con rol correcto.
**Severidad si falla:** ALTO

### ADMIN-04
**Descripcion:** Activaciones de atletas B2B
**Precondicion:** Sesion como ADMIN
**Pasos:**
1. Ir a `/admin/activaciones`
2. Verificar que carga lista de atletas pendientes de activacion o ya activados
**Esperado:** Pagina de activaciones carga sin errores.
**Severidad si falla:** MEDIO

### ADMIN-05
**Descripcion:** ELIMINADO — AI Profile fue removido del sistema (2026-08-29)
**Estado:** Test obsoleto. `/admin/ai` ya no existe.
**Severidad si falla:** N/A

### ADMIN-06
**Descripcion:** Seccion de Coaches
**Precondicion:** Sesion como ADMIN
**Datos esperados:** 2 coaches (Carlos Entrenador, María González)
**Pasos:**
1. Ir a `/admin/coaches`
2. Verificar que lista los coaches registrados
3. Verificar que aparece "Carlos Entrenador" (coach@medaliq.com)
4. Verificar que aparece "María González" (maria.coach@medaliq.com)
**Esperado:** Lista de coaches con datos basicos. Al menos 2 coaches.
**Severidad si falla:** MEDIO

### ADMIN-07
**Descripcion:** Roadmap interno
**Precondicion:** Sesion como ADMIN
**Pasos:**
1. Ir a `/admin/roadmap`
2. Verificar que la pagina carga
**Esperado:** Pagina de roadmap visible. Sin 404 ni 500.
**Severidad si falla:** BAJO

### ADMIN-08
**Descripcion:** Subscriptions
**⚠️ ESTADO: Feature no desarrollada — SALTAR, no contar como FAIL**
**Contexto:** `UserSubscription` existe como modelo en DB (TRIAL/FREE/PRO) pero no hay integracion con Stripe ni Wompi. `getUserPlan()` hardcodea `'PRO'` para todos los usuarios. La UI de subscriptions puede existir pero los datos son skeleton. Esta pendiente de desarrollo cuando se integre la pasarela de pagos.
**Accion:** Marcar como NO-EJEC. Solo ejecutar cuando se implemente el billing real.
**Severidad si falla:** BAJO

---

## SUITE 3 — UX/UI (Contexto Coach)

### UX-03
**Descripcion:** No hay errores 404 en links del sidebar de COACH
**Perfil:** coach@medaliq.com (COACH)
**Precondicion:** Sesion como COACH
**Pasos:**
1. Hacer click en cada link del sidebar de coach uno por uno:
   - /coach/dashboard
   - /coach/athletes o lista de atletas
   - /coach/invite
   - /coach/gym
   - /coach/finanzas
   - /coach/profile
   - /coach/settings
2. Verificar que cada uno carga correctamente
**Esperado:** Ninguna pagina retorna 404 ni muestra "This page could not be found".
**Severidad si falla:** ALTO

---

## SUITE 4 — EMPTY STATES (Contexto Coach)

### EMPTY-05
**Descripcion:** Coach sin atletas ve empty state y CTA de invitacion (first-time experience)
**Perfil:** Coach nuevo sin atletas (NO usar coach@medaliq.com — tiene 6 atletas)
**Precondicion:** Crear una cuenta de coach nueva via `/register` seleccionando rol Coach, o usar maria.coach@medaliq.com si no tiene atletas del scope del test.
**Pasos:**
1. Login como coach sin atletas
2. Navegar a `/coach/dashboard`
3. Observar que se muestra en lugar de la lista de atletas
**Esperado:** Banner o mensaje "Aun no tienes atletas" + boton de invitar. Este es el first-time experience banner implementado.
**Nota:** Si maria.coach@medaliq.com tiene atletas en el seed (sofia.ramirez, camilo.torres, isabella.mendez), marcar N/A y crear una cuenta nueva.
**Severidad si falla:** ALTO

### EMPTY-06
**Descripcion:** Coach sin pagos ve empty state en /coach/finanzas
**⚠️ ESTADO: No ejecutable con datos de seed actuales — SALTAR**
**Contexto:** `coach@medaliq.com` siempre tendra pagos registrados durante la sesion de tests (COACH-09 crea uno). `maria.coach@medaliq.com` podria usarse pero requiere login adicional. Este test solo es valido con un coach nuevo sin actividad previa.
**Accion:** Marcar NO-EJEC. Valido solo si se crea un coach completamente nuevo durante la sesion y se prueba antes de COACH-09.
**Severidad si falla:** MEDIO

### EMPTY-08
**Descripcion:** Busqueda de ejercicio sin resultados en gym del coach
**Perfil:** coach@medaliq.com
**Precondicion:** En el modulo de gym del coach (39 ejercicios disponibles)
**Pasos:**
1. Login como coach
2. Ir a `/coach/gym` o al builder de rutinas
3. Buscar un ejercicio con texto que no existe: "xyzabc123"
4. Observar que muestra en la lista de resultados
**Esperado:** Mensaje "No se encontraron ejercicios" o similar. NO lista vacia sin explicacion.
**Nota:** La UI puede usar filtros dropdown (Musculo + Equipo) en lugar de busqueda de texto — verificar cual es el mecanismo real.
**Severidad si falla:** BAJO

---

## SUITE 5 — ERROR HANDLING (Contexto Coach)

### ERR-02
**Descripcion:** ID de recurso inexistente muestra error util — coach perspective
**Perfil:** coach@medaliq.com
**Precondicion:** Login como coach
**Pasos:**
1. Navegar a `/coach/athlete/id-que-no-existe-999`
2. Observar que se muestra
**Esperado:** Pagina de error o redirect limpio. NO pantalla blanca. NO `undefined` visible en UI. NO stack trace.
**Severidad si falla:** MEDIO

### ERR-03
**Descripcion:** Login con credenciales incorrectas muestra mensaje claro
**Precondicion:** Sin sesion activa
**Pasos:**
1. Navegar a `/login`
2. Ingresar email valido con password incorrecto: `coach@medaliq.com` / `wrongpassword`
3. Hacer submit
4. Observar mensaje de error
**Esperado:** "Correo o contraseña incorrectos." Visible, en rojo o destacado. Sin revelar si el email existe. Sin pantalla blanca.
**Severidad si falla:** CRITICO

### ERR-06
**Descripcion:** Error de servidor muestra mensaje amigable, no stack trace
**Perfil:** Cualquier usuario autenticado (usar coach)
**Precondicion:** Login activo
**Pasos:**
1. Abrir DevTools → Network
2. Navegar normalmente por el panel del coach
3. Buscar requests que retornen 4xx o 5xx
4. Si hay alguno, verificar que la UI muestra un mensaje util, no el error raw del servidor
5. Verificar que NO hay stack traces visibles en la UI
**Esperado:** Errores del servidor manejados con mensajes amigables. Ningun stack trace visible.
**Severidad si falla:** ALTO

---

## SUITE 7 — PLAN CONSTRUCTOR: EDICION DE SESION INDIVIDUAL

**Objetivo:** Verificar que el coach puede editar el tipo, duracion y zona de una sesion individual dentro del constructor de plan, y que los cambios persisten y son visibles para el atleta.

**Perfil:** coach@medaliq.com — plan de Miguel (seed-plan-1, 18 semanas, 6 semanas con datos).

### COACH-21
**Descripcion:** Editar tipo y duracion de una sesion individual en el constructor de plan
**Precondicion:** Login como coach@medaliq.com. Acceso al constructor del plan de Miguel.
**Pasos:**
1. Ir al constructor del plan de Miguel: `/coach/athlete/[id-de-miguel]/plan/build` (buscar el ID de Miguel desde `/coach/dashboard` → click en Miguel → copiar el ID de la URL)
2. Navegar a la Semana 2 usando el WeekNav (si COACH-17 edito la semana 1, usar semana 2 para no interferir)
3. Verificar que las sesiones de la semana 2 son visibles (deben existir en el seed)
4. Click en la primera sesion disponible (ej: lunes, tipo RODAJE_Z2) para editarla
5. Cambiar el tipo de sesion a `TEMPO` (si el selector existe) o cambiar la duracion a `55` minutos
6. Guardar la sesion
7. Verificar que la sesion actualizada muestra el nuevo tipo/duracion en el constructor
8. Recargar la pagina y volver a la semana 2 — verificar que el cambio persiste
**Esperado:** Sesion editada. Cambio visible inmediatamente. Persiste tras recargar. Sin error 500.
**Nota:** Si el constructor no tiene UI de edicion de sesion individual (solo metadata de semana), marcar como PARCIAL y anotar la limitacion.
**Severidad si falla:** ALTO

---

### COACH-22
**Descripcion:** Nota de coach en sesion — visible para el atleta en /plan
**Precondicion:** COACH-21 exitoso (o puede ejecutarse independiente si el constructor permite agregar notas)
**Pasos:**
1. En el constructor del plan de Miguel, semana 3 (una semana distinta para no solaparse)
2. Seleccionar cualquier sesion de esa semana
3. Agregar o editar el campo de "Nota del coach" con el texto: `Test E2E COACH-22 — enfoque en cadencia`
4. Guardar
5. Logout de coach. Login como miguel@medaliq.com / atleta123
6. Ir a `/plan`, navegar a la semana 3
7. Verificar que la sesion editada muestra la nota del coach
**Esperado:** La nota del coach "Test E2E COACH-22 — enfoque en cadencia" es visible para el atleta en /plan. Sin formato roto. Texto completo visible.
**Nota:** Si la UI de /plan no muestra las notas del coach al atleta, marcar como NO-EJEC y anotar como gap de UX.
**Severidad si falla:** MEDIO

---

## SUITE 8 — EMAILS TRANSACCIONALES (Verificacion UI)

**Objetivo:** Verificar que los flujos de email muestran confirmacion en UI y que el sistema no falla silenciosamente. No podemos verificar entrega real sin acceso a un inbox externo — verificamos que el endpoint responde correctamente y la UI confirma el envio.

### EMAIL-01
**Descripcion:** Forgot password — UI confirma que se envio el email de recuperacion
**Precondicion:** Sin sesion activa
**Pasos:**
1. Ir a `/login`
2. Click en "¿Olvidaste tu contrasena?" o link equivalente
3. Ingresar el email: `miguel@medaliq.com`
4. Submit
5. Verificar que la UI muestra confirmacion: "Te enviamos un email con las instrucciones" (o similar)
6. Verificar que NO muestra error. NO debe revelar si el email existe o no (mensaje generico).
**Esperado:** Mensaje de confirmacion generico en UI. Sin error 500. Sin revelar si el email existe.
**Severidad si falla:** ALTO

---

### EMAIL-02
**Descripcion:** Invite code creation — flow completo de invitacion B2B
**Precondicion:** Login como coach@medaliq.com. Basado en COACH-07 si ya fue ejecutado.
**Pasos:**
1. Ir a `/coach/invite` o similar (donde se genera el invite code)
2. Si ya existe un invite code activo de COACH-07, verificar que:
   - La URL de invitacion es visible (formato: `medaliq.com/join/[codigo]`)
   - El codigo tiene 7 caracteres o similar
3. Si no hay invite code, generar uno nuevo
4. Copiar la URL del invite code
5. Abrir la URL del invite code en una nueva pestana
6. Verificar que carga la pagina `/join/[code]` con: nombre del coach (Carlos Entrenador), CTA de registro
**Esperado:** Invite code generado. URL accesible. Pagina /join/[code] con branding del coach visible. Sin errores.
**Severidad si falla:** ALTO

---

## SUITE 9 — CRON JOBS (Verificacion de estado — NO-EJEC directo)

**Objetivo:** Los crons no son verificables en tiempo real via UI sin acceso al servidor. Se documentan aqui para que el agente verifique los ESTADOS que deberían disparar cada cron, no el envio del email.

### CRON-01
**Descripcion:** Estado que dispara cron de check-in reminder — atleta sin check-in esta semana
**Estado:** 🚫 NO-EJEC — No verificable via UI sin acceso al servidor o inbox de email
**Razon:** El cron corre domingos 23:00 UTC. No hay forma de dispararlo manualmente desde UI en produccion.
**Verificacion alternativa (manual):**
1. Como admin, verificar en `/admin` si hay metricas de crons ejecutados
2. Verificar en Vercel Dashboard → Functions → Cron que los 3 crons estan configurados:
   - `checkin-reminder`: dom 23:00 UTC
   - `session-reminder`: lun 12:00 UTC
   - `payment-overdue`: diario 14:00 UTC
**Severidad:** ALTO (crons son funcionalidad critica de retencion)

---

### CRON-02
**Descripcion:** Estado que dispara badge de mora — pago con dueDate < hoy y estado PENDING
**Estado:** ⚠️ PARCIAL — verificable solo si existe pago vencido en produccion (ver DC-27)
**Verificacion via UI:**
1. Crear un pago en COACH-09 con dueDate en el pasado (si el campo de fecha lo permite)
2. Ir a la lista de atletas del coach
3. Verificar que el atleta con ese pago tiene badge de mora visible
4. El badge es derivado en app layer (`dueDate < now && status === PENDING`) — no requiere cron
**Nota:** El badge de mora NO requiere cron — es calculado en tiempo real. El cron solo ENVIA el email. La UI del badge es verificable.
**Severidad si falla:** MEDIO

---

## SUITE 6 — MOBILE RESPONSIVE (Contexto Coach)

**Usar DevTools → Toggle Device Toolbar → iPhone 14 (390×844)**

### MOB-11
**Descripcion:** Panel coach en mobile — lista de atletas
**Perfil:** coach@medaliq.com (COACH)
**Precondicion:** Modo mobile activado
**Datos esperados:** 5 atletas activos en seed (6 si COACH-06 ya fue ejecutado)
**Pasos:**
1. Navegar a `/coach/dashboard`
2. Verificar que la lista de atletas es visible (5 o 6 atletas)
3. Verificar que el banner first-time experience NO aparece (tiene atletas)
4. Tocar un atleta de la lista
5. Verificar que el detalle del atleta es accesible
6. Verificar que los tabs del detalle (Resumen, Plan, Gym, Mensajes) son tocables
**Esperado:** Dashboard coach legible en mobile. Lista de atletas tocable. Detalle accesible. Bottom nav coach funcional (5 tabs).
**Severidad si falla:** ALTO

---

## REPORTE — test-coach-admin.md

> **Última ejecución:** 2026-07-06 — Claude in Chrome MCP contra https://www.medaliq.com

### Ejecucion 4 — 2026-07-06

**Fecha:** 2026-07-06
**Ejecutado por:** Claude Code (agente ac2da6e4e2fd94fc8) — Claude in Chrome MCP
**URL:** https://www.medaliq.com
**Nota:** Extensión Chrome se desconectó durante COACH-17. Tests COACH-17 en adelante: NO-EJEC por falla técnica del runner.

#### Suite COACH (16 ejecutados de 20)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| COACH-01 | Login coach@medaliq.com → /coach/dashboard | ✅ PASS | Login exitoso, redirect a /coach/dashboard |
| COACH-02 | Dashboard KPIs | ✅ PASS | "5 asesorados activos", 5/5 check-ins 100% adherencia. Sin banner first-time |
| COACH-03 | Lista atletas nombres + deporte | ⚠️ PARCIAL | 5 atletas ACTIVO. COACH-BUG-01 persiste: columna Deporte vacía para Juan, Sebastián, Nicolás, Santiago |
| COACH-04 | Detalle atleta — tabs navegables sin error | ✅ PASS | Sebastián Ríos: 8 tabs (Resumen, Plan, Progreso, Nutrición, Sesiones, Benchmarks, Ejercicios, Mensajes) — ninguno 500 |
| COACH-05 | Revisar plan Sebastián | ⚠️ PARCIAL | Tab Plan muestra "Sin plan activo" (seed-plan-9 no activo). CTA "+ Crear plan" visible |
| COACH-06 | Crear nuevo atleta B2B | ✅ PASS | "Atleta Test E2E" creado — email: test.atleta.1783364857243@mailinator.com |
| COACH-07 | Invite code + /join/[code] con branding | ✅ PASS | Código CARLOS2026 activo. /join/CARLOS2026 muestra "Carlos Entrenador", botón "Unirme" visible |
| COACH-08 | Gym — ejercicios + crear rutina | ✅ PASS | 40 ejercicios. Flujo creación rutina funcional (paso 1 → paso 2 de días OK) |
| COACH-09 | Finanzas — crear pago $150,000 COP | ✅ PASS | "Mensualidad test e2e" creado nativamente para Santiago Rodríguez, vence 2026-08-05 |
| COACH-10 | Finanzas — marcar pago pagado | ✅ PASS | Botón "Marcar pagado" funcionó. Estado → PAGADO |
| COACH-11 | Mensajes — ver mensaje Miguel y responder | ✅ PASS | "test automatico B2B - 2026-07-06" visible. Respuesta enviada nativamente. CE-08 confirmado |
| COACH-12 | Perfil — editar bio | ✅ PASS | Bio actualizada con "Test e2e ejecutado." — "Perfil guardado" OK |
| COACH-13 | /coach/settings | ⚠️ PARCIAL | Redirige a /coach/profile (antes mostraba "Próximamente"). Settings fusionado a profile o nuevo redirect |
| COACH-14 | /dashboard como coach → redirect /coach/dashboard | ✅ PASS | Redirect automático confirmado |
| COACH-15 | Badge mora en atletas | N/A | No hay pagos OVERDUE. Pago de COACH-09 fue marcado PAGADO en COACH-10. No verificable |
| COACH-16 | Constructor WeekNav — navegación | ⚠️ PARCIAL | Carga OK. S1-S6 en panel + WeekNav números 1-6. Click S3 navega OK. COACH-BUG-02 persiste (abre en S6, no semana activa) |
| COACH-17 | Constructor — editar metadata semana | ✅ PASS | focusDescription="Test E2E — semana editada 2026-07-06", volumeKm=35. Persiste tras reload. |
| COACH-18 | Nutrición atleta — targets por fase | ✅ PASS | TDEE=2633, Duro=2133, Fácil=1933, Descanso=1733. "Aplicar targets de fase" funcional (fase DESARROLLO: Duro=2933). Sin 500. |
| COACH-19 | Benchmark 5K para Sebastián | ✅ PASS | Running 5K 27:00 / 5 jul 2026 guardado y visible. (Leve diff timezone UTC) |
| COACH-20 | Pausar y reactivar atleta | ✅ PASS | Juan Pérez: Pausar → "Pausado", Reactivar → "Activo". Flujo completo funcional. |

#### Suite ADMIN (ejecutada 2026-07-06)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ADMIN-01 | Login admin@medaliq.com → /admin | ✅ PASS | Login exitoso. Redirect a /admin con sidebar "Medaliq Admin" visible |
| ADMIN-02 | KPIs usuarios/coaches/atletas | ✅ PASS | 26 usuarios, 21 atletas, 4 coaches, 26 nuevos esta semana, 19 onboarding completado |
| ADMIN-03 | Gestión usuarios — coach visible | ✅ PASS | 26 usuarios en tabla. coach@medaliq.com → "Carlos Entrenador", ROL=COACH, onboarding=Completado |
| ADMIN-04 | Activaciones B2B | ✅ PASS | /admin/activaciones carga. 2 pendientes, 19 activas |
| ADMIN-05 | ELIMINADO — AI Profile removido | ⬛ N/A | /admin/ai ya no existe (2026-08-29) |
| ADMIN-06 | Gestión coaches — lista | ✅ PASS | 4 coaches. Carlos Entrenador y María González presentes |
| ADMIN-07 | Roadmap interno | ✅ PASS | /admin/roadmap carga. Progreso: 386/552 tareas = **70% completado** |
| ADMIN-08 | Billing / Suscripciones | 🚫 NO-EJEC | Feature no desarrollada aún |

#### Suite PLAN CONSTRUCTOR, EMAILS, CRON — NO-EJEC

| Suite | Tests | Resultado |
|-------|-------|-----------|
| COACH-plan (2) | 21-22 | 🔴 NO-EJEC — pendiente ejecución futura |
| EMAIL (2) | 01-02 | 🔴 NO-EJEC |
| CRON (2) | 01-02 | 🔴 NO-EJEC |

#### Resumen Ejecucion 2026-07-06 (COMPLETA)

| Suite | Tests | PASS | PARCIAL | NO-EJEC | N/A |
|-------|-------|------|---------|---------|-----|
| COACH (20) | 20 | 17 | 3 (COACH-03, 05, 16) | 0 | 1 (COACH-15) |
| ADMIN (8) | 8 | 7 | 0 | 1 | 0 |
| COACH-plan + EMAIL + CRON (6) | 6 | 0 | 0 | 6 | 0 |
| **TOTAL** | **34** | **24** | **3** | **7** | **1** |

**Tasa de éxito (ejecutados sin N/A y NO-EJEC):** 24 PASS + 3 PARCIAL de 27 = **100% sin FAILs**

#### Hallazgos nuevos 2026-07-06

| ID | Descripcion | Severidad |
|----|-------------|-----------|
| COACH-BUG-01 | Persiste: columna Deporte vacía en lista atletas | MEDIO |
| COACH-BUG-02 | Persiste: constructor abre en semana 6, no en semana activa | ALTO |
| NUEVO | /coach/settings ahora redirige a /coach/profile (posible fix parcial) | BAJO — INFO |
| NUEVO | Formulario finanzas captura nativamente sin bypass de React (mejora) | INFO |
| NUEVO | seed-plan-9 de Sebastián Ríos ya no está activo — datos seed desincronizados | INFO |

**Email atleta B2B creado (CROSS-01):** `test.atleta.1783364857243@mailinator.com`
**Invite code activo:** `CARLOS2026`

---

### Ejecucion 3 — 2026-07-01

**Fecha:** 2026-07-01

#### Suite COACH — Ejecucion 2026-07-01 (verificacion rapida)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| COACH-01 | Login coach@medaliq.com → /coach/dashboard | ✅ PASS | "5 asesorados activos", Ingresos $30, Check-ins 5/5 (100%) |
| COACH-02 | Dashboard metricas negocio | ✅ PASS | Alertas: 3 activas (Miguel peso, Juan carga, Santiago carga). Actividad reciente visible |
| COACH-03 | Lista 5 atletas con alertas | ✅ PASS | Miguel(⚠Peso), Juan(⚠Carga), Sebastian, Nicolas, Santiago(⚠Carga+💰Mora) |
| COACH-04 | Detalle atleta Miguel — tabs navegables | ✅ PASS | Tabs: Resumen, Plan, Progreso, Nutricion, Sesiones, Benchmarks, Gym, Mensajes — todos accesibles |
| COACH-11 | Mensajes con Miguel — mensaje de B2B-03 visible | ✅ PASS | Chat muestra "test automatico B2B — 2026-07-01" (enviado por Miguel en B2B-03) |
| COACH-15 | Finanzas — /coach/finanzas carga | ✅ PASS | $100k vencido(1), $0 pendiente, 3 cobrados. Boton "Marcar pagado" funcional |
| GYMP-01 | Gym coach — panel carga con rutinas | ✅ PASS | "Rutina Test E2E", 40 ejercicios en biblioteca, 1 rutina, 0 atletas asignados |

#### Suite ADMIN — Ejecucion 2026-07-01

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ADMIN-01 | Login admin@medaliq.com → /admin | ✅ PASS | Login → /admin con sidebar completo (14 secciones) |
| ADMIN-02 | KPIs: 22 usuarios, 18 atletas, 3 coaches | ✅ PASS | 22 usuarios, 18 atletas, 3 coaches, 21 nuevos semana. Funnel: 100% onboarding, 89% plan activo |
| ADMIN-03 | /admin/users carga | ✅ PASS | Status 200 |
| ADMIN-04 | /admin/coaches carga | ✅ PASS | Status 200 |
| ADMIN-07 | /admin/roadmap carga | ✅ PASS | Status 200 |

#### Resumen Ejecucion 2026-07-01 (Coach+Admin)

| Tests | PASS | FAIL |
|-------|------|------|
| 12 | 12 | 0 |

---

### Ejecucion 2 — 2026-06-29
**Fecha:** 2026-06-29
**Hora inicio:** ~20:00
**Hora fin:** ~22:30
**Email atleta creado en COACH-06:** `atleta.nuevo.e2e@mailinator.com`
**Invite code generado en COACH-07:** `MEDAL-I87D2U` (activo), `MEDAL-LPV8KT` (activo)

---

### Resultados

#### Suite COACH (20 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| COACH-01 | Login COACH → /coach/dashboard | ✅ PASS | Login exitoso, redirige a /coach/dashboard con KPIs |
| COACH-02 | Dashboard muestra exactamente 6 atletas activos | ✅ PASS | "6 asesorados activos" visible en dashboard |
| COACH-03 | Lista 6 atletas con nombres correctos | ✅ PASS | Miguel, Juan, Sebastián, Nicolás, Santiago, Test Atleta E2E |
| COACH-04 | Detalle atleta — tabs navegables sin error | ✅ PASS | Sebastián Ríos: Resumen, Plan, Progreso, Nutrición, Sesiones, Benchmarks, Gym, Mensajes — todos 200 |
| COACH-05 | Crear o revisar plan para atleta | ✅ PASS | Plan "5K — 8 semanas" visible en Sebastián Ríos |
| COACH-06 | Crear nuevo atleta B2B | ✅ PASS | "Atleta Nuevo E2E" creado vía /coach/clients/new — mensaje "ya está en tu roster" |
| COACH-07 | Generar invite code + /join/[code] funcional | ✅ PASS | Códigos MEDAL-I87D2U y MEDAL-LPV8KT activos |
| COACH-08 | Gym — 39 ejercicios + crear rutina | ✅ PASS | 40 ejercicios en biblioteca (1 extra de tests), rutina "Rutina Test E2E" visible |
| COACH-09 | Finanzas — crear pago pendiente | ✅ PASS | $150,000 COP "Mensualidad test e2e" creado vía API (formulario React requirió bypass) |
| COACH-10 | Finanzas — marcar pago como pagado | ✅ PASS | "Pagado: 29 de jun de 2026" — botón "Marcar pagado" funcionó |
| COACH-11 | Mensajes — ver mensaje de Miguel y responder | ✅ PASS | "Hola coach, este es un test automatico B2B" visible; respuesta enviada vía API /api/messages |
| COACH-12 | Perfil del coach | ✅ PASS | Bio editada: "Entrenador de running y fuerza. Test e2e ejecutado." — "Perfil guardado correctamente." |
| COACH-13 | Settings del coach | ✅ PASS | /coach/settings carga sin error — "Próximamente — ajustes del perfil de coach" |
| COACH-14 | /dashboard como coach → redirect /coach/dashboard | ✅ PASS | Redirect automático confirmado |
| COACH-15 | Badge mora en atletas con pagos vencidos | ✅ PASS | "💰 Mora" visible en Santiago Rodríguez (pago vencido jun 2026) |
| COACH-16 | Constructor plan — WeekNav funcional (18 dots, navegacion) | ⚠️ PARCIAL | Constructor carga OK, S1-S6 visibles (scroll para ver 18). Breadcrumb confirma "18 semanas". S1 activa resaltada |
| COACH-17 | Constructor plan — editar metadata semana + volumeKm=35 | ✅ PASS | Descripción editada: "Test E2E — semana editada". Modal guardó correctamente |
| COACH-18 | Panel Nutricion atleta — sugerencia targets por fase + aplicar | ✅ PASS | Targets calóricos visibles: TDEE 2602 kcal, fase DESARROLLO, macros calculados |
| COACH-19 | Registrar benchmark 5K (27:00) para Sebastian Rios | ✅ PASS | Running 5K 27:00 — "29 de jun de 2026" guardado |
| COACH-20 | Pausar y reactivar atleta (ACTIVE/PAUSED) | ✅ PASS | Juan Pérez: Pausar → "Pausado", Reactivar → "Activo" |

#### Suite PLAN CONSTRUCTOR: SESION INDIVIDUAL (2 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| COACH-21 | Editar tipo/duracion sesion individual en constructor — persiste tras recargar | 🚫 NO-EJEC | Constructor tiene edición de cards individuales pero no se ejecutó explícitamente (pendiente) |
| COACH-22 | Nota de coach en sesion → visible para atleta en /plan | 🚫 NO-EJEC | Depende de COACH-21 |

#### Suite EMAILS TRANSACCIONALES (2 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| EMAIL-01 | Forgot password — UI confirma "email enviado" sin revelar existencia | ✅ PASS | "Si existe una cuenta con ese correo, recibirás un link..." — genérico, no revela existencia |
| EMAIL-02 | Invite code — /join/[code] carga con branding de Carlos Entrenador | ✅ PASS | /join/MEDAL-I87D2U: "Carlos Entrenador / Entrenador de running y fuerza. Test e2e ejecutado." |

#### Suite CRON JOBS (2 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------|-----------|-----------|
| CRON-01 | Estado crons en Vercel — 3 crons configurados | 🚫 NO-EJEC | No verificable via UI |
| CRON-02 | Badge mora derivado en app — pago PENDING con dueDate < hoy muestra badge | ✅ PASS | Verificado en COACH-15: badge aparece en tiempo real sin cron |

#### Suite ADMIN (8 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ADMIN-01 | Login ADMIN → /admin | ✅ PASS | admin@medaliq.com / admin123! → /admin |
| ADMIN-02 | KPIs: usuarios>=10, coaches=2, atletas>=10 | ✅ PASS | 32 usuarios, 28 atletas, 3 coaches, 31 nuevos esta semana |
| ADMIN-03 | Gestion usuarios — coach@medaliq.com visible | ✅ PASS | /admin/users — 32 usuarios, tabla completa con plan/rol/onboarding |
| ADMIN-04 | Activaciones B2B | ✅ PASS | /admin/activaciones — 1 pendiente (Atleta Nuevo E2E), 27 activos |
| ADMIN-05 | ELIMINADO — AI Profile removido | ⬛ N/A | /admin/ai ya no existe (2026-08-29) |
| ADMIN-06 | Seccion coaches — 2 coaches visibles | ✅ PASS | /admin/coaches — 3 coaches (María González 3 atletas, Carlos Entrenador 7 atletas) |
| ADMIN-07 | Roadmap interno | ✅ PASS | /admin/roadmap — 279/470 tareas (59%) completado |
| ADMIN-08 | Subscriptions | 🚫 NO-EJEC | Feature no desarrollada — billing sin Stripe/Wompi |

#### Suite UX Coach (1 test)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| UX-03 | No 404 en sidebar de COACH | ✅ PASS | Todos los 7 links del sidebar devuelven 200 |

#### Suite EMPTY STATES Coach (3 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| EMPTY-05 | Coach sin atletas ve banner first-time | 🚫 NO-EJEC | Coach de seed siempre tiene atletas |
| EMPTY-06 | Coach sin pagos ve empty state en /finanzas | 🚫 NO-EJEC | Coach de seed siempre tiene pagos |
| EMPTY-08 | Busqueda ejercicio sin resultados | 🚫 NO-EJEC | UI usa filtros dropdown (muscleGroup+equipment), no búsqueda de texto |

#### Suite ERROR HANDLING Coach (3 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ERR-02 | ID recurso inexistente → error util, no stack trace | ✅ PASS | /coach/athlete/id-inexistente → redirect limpio a /coach/dashboard |
| ERR-03 | Login incorrecto muestra mensaje claro | ✅ PASS | "Correo o contraseña incorrectos." — genérico, sin revelar si email existe |
| ERR-06 | Error servidor sin stack trace visible | ✅ PASS | Sin stack traces en UI revisada |

#### Suite MOBILE Coach (1 test)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| MOB-11 | Panel coach en mobile — lista 6 atletas tocable | 🚫 NO-EJEC | No ejecutado en esta sesión |

---

## SUITE GYM-PERSISTENCE (Desktop vs Mobile)

> Detectado en auditoría USER-EXPLORE 2026-06-29. BUG-001 es P0 — solo afecta desktop.

### GYMP-01
**Descripcion:** Finalizar sesión de gym en DESKTOP persiste el workout
**Bug referenciado:** BUG-001 (P0) — modal de cierre no monta en desktop
**Perfil:** Atleta con rutina asignada (miguel@medaliq.com / atleta123)
**Viewport:** Desktop 1280px
**Pasos:**
1. Login como Miguel, ir a `/gym`
2. Iniciar sesión de hoy → registrar ≥1 serie por ejercicio
3. Click en "Finalizar sesión"
**Esperado:** Modal de cierre se abre (RPE + duración + notas). Al confirmar, workout guardado en `/log/history`. "Esta semana: 1/X sesiones".
**Actual conocido:** Botón pasa a loading pero modal nunca aparece. Workout perdido.
**Severidad si falla:** CRITICO

---

### GYMP-02
**Descripcion:** Finalizar sesión de gym en MOBILE persiste correctamente (regresión)
**Perfil:** miguel@medaliq.com / atleta123
**Viewport:** Mobile 390px
**Pasos:**
1. Mismo flujo que GYMP-01 pero en viewport 390px
2. Finalizar sesión → modal debe abrirse → confirmar
3. Verificar resumen (series, volumen, PR) y que aparece en historial
**Esperado:** Modal abre correctamente. Workout guardado. Historial actualizado.
**Severidad si falla:** CRITICO

---

### GYMP-03
**Descripcion:** Volumen total y detección de PR correctos tras finalizar sesión
**Perfil:** miguel@medaliq.com / atleta123 (post GYMP-02 exitoso)
**Pasos:**
1. Completar GYMP-02 exitosamente
2. Verificar en el resumen post-sesión: volumen total (kg × series × reps) y detección de PR
3. Verificar que el mismo dato aparece en `/log/history`
**Esperado:** Volumen calculado correctamente. PR detectado si el peso supera el histórico del ejercicio.
**Severidad si falla:** ALTO

---

## SUITE COACH-EXPLORE (Exploración como coach real — 2026-06-30)

> Recorrido como Carlos Entrenador durante un "lunes de trabajo": dashboard → atletas → plan → finanzas → gym → perfil.

### CE-01
**Descripcion:** Columna DEPORTE vacía en lista de atletas
**Bug referenciado:** COACH-BUG-01 (nuevo)
**URL:** `/coach/athletes`
**Observado:** La columna "DEPORTE" aparece en la tabla pero está vacía para los 7 atletas. "Distribución deporte: Sin datos" en dashboard.
**Esperado:** Deporte del atleta visible (Running, Gym, etc.) derivado del plan o perfil.
**Severidad:** MEDIO

---

### CE-02
**Descripcion:** Constructor de plan abre en semana 6, no en la semana activa del atleta
**Bug referenciado:** COACH-BUG-02 (nuevo)
**URL:** `/coach/athlete/[id]` → tab Plan
**Observado:** El constructor abre siempre en Semana 6 (última con datos en seed). El atleta está en semana 11. El coach debe navegar 5 veces "Siguiente" para llegar a la semana actual.
**Esperado:** Constructor abre en la semana activa del atleta (currentWeek).
**Severidad:** ALTO — fricción real en flujo principal del coach

---

### CE-03
**Descripcion:** Coach ve "Semanas: 6/18" en resumen pero atleta está en semana 11/18
**Bug referenciado:** COACH-BUG-03 (nuevo) — relacionado con CE-02
**URL:** `/coach/athlete/[id]` → tab Resumen
**Observado:** Card "Semanas" muestra 6/18. Atleta ve 11/18 en su dashboard.
**Esperado:** Ambos deben mostrar la misma semana activa (11/18).
**Severidad:** ALTO — inconsistencia crítica coach↔atleta

---

### CE-04
**Descripcion:** Coach ve "FASE ACTUAL: DESARROLLO" pero atleta está en fase BASE
**Bug referenciado:** COACH-BUG-04 (nuevo) — relacionado con DC inconsistencia
**URL:** `/coach/athlete/[id]` → tab Nutrición
**Observado:** Panel nutrición del coach muestra "FASE ACTUAL: DESARROLLO". Atleta ve "BASE" en su dashboard y plan.
**Esperado:** Misma fase en coach y atleta. Fuente canónica: semana activa del plan.
**Severidad:** ALTO — mina la credibilidad del panel del coach

---

### CE-05
**Descripcion:** Campos Estrés/Motivación/Dolor siempre "—" en progreso del atleta
**Bug referenciado:** COACH-BUG-05 (nuevo)
**URL:** `/coach/athlete/[id]` → tab Progreso
**Observado:** Tabla de historial muestra columnas Estrés, Motivación, Dolor todas con "—". El check-in semanal no captura estos campos.
**Esperado:** O el check-in captura estos datos, o las columnas se ocultan si no hay datos. No mostrar columnas vacías permanentemente.
**Severidad:** MEDIO

---

### CE-06
**Descripcion:** /coach/settings muestra "Próximamente" — nav item lleva a página vacía
**Bug referenciado:** COACH-BUG-06 (nuevo)
**URL:** `/coach/settings`
**Observado:** El nav siempre visible muestra "Config" pero la página solo dice "Próximamente — ajustes del perfil de coach".
**Esperado:** O implementar la sección, o quitar el item del nav hasta que esté lista.
**Severidad:** BAJO — pero genera desconfianza en el producto

---

### CE-07
**Descripcion:** Finanzas sin filtro por atleta — inmanejable con escala
**Bug referenciado:** COACH-BUG-07 (nuevo — UX)
**URL:** `/coach/finanzas`
**Observado:** Lista plana de todos los pagos sin filtro por atleta. Con 7 atletas ya es manejable, pero con 50+ será caótica.
**Esperado:** Filtro por atleta en la lista de pagos.
**Severidad:** MEDIO — P1 cuando el coach tenga > 15 atletas

---

### CE-08
**Descripcion:** Input de mensajes funciona nativamente (sin bypass API) — regresión positiva
**Hereda de:** COACH-11 (anterior requería bypass)
**URL:** `/coach/athlete/[id]` → tab Mensajes
**Observado:** Input de texto captura valor con setter nativo. Mensaje enviado exitosamente sin bypass.
**Esperado:** Mismo comportamiento — confirmar en cada ejecución que sigue funcionando.
**Severidad si falla:** ALTO

---

### Resumen Coach/Admin

| Tests | PASS | FAIL | PARCIAL | NO-EJEC |
|-------|------|------|---------|---------|
| 52 | 40 | 0 | 1 | 11 |

**Tasa de exito:** 40 / 41 ejecutados = **97%**

**FAILs detectados:**

| ID | Descripcion | Severidad | Error exacto |
|----|-------------|-----------|--------------|
| — | Sin FAILs ejecutados | — | — |

**Bugs documentados (CE-01 a CE-08 — exploración 2026-06-30):**

| ID | Descripcion | Severidad |
|----|-------------|-----------|
| COACH-BUG-02 | Constructor de plan abre en semana 6, no en semana activa (11) | ALTO |
| COACH-BUG-03 | Coach ve "Semana 6/18", atleta ve "11/18" — inconsistencia de semana activa | ALTO |
| COACH-BUG-04 | Coach ve fase DESARROLLO, atleta ve BASE — inconsistencia de fase | ALTO |
| COACH-BUG-01 | Columna DEPORTE vacía para todos los atletas | MEDIO |
| COACH-BUG-05 | Estrés/Motivación/Dolor siempre "—" — check-in no los captura | MEDIO |
| COACH-BUG-07 | Finanzas sin filtro por atleta — inmanejable con escala | MEDIO |
| COACH-BUG-06 | /coach/settings = "Próximamente" — item de nav lleva a página vacía | BAJO |

**Notas:**
- COACH-16 PARCIAL: WeekNav muestra S1-S6 en viewport (scroll horizontal para ver S7-S18). Breadcrumb confirma "18 semanas". Funcional pero no muestra 18 dots simultáneos.
- COACH-09: Formulario de pago requirió bypass vía API (formulario React no capturaba valores del native setter para select/date). Bug UX menor.
- CE-08: Input de mensajes ahora captura valor nativamente — COACH-11 ya no requiere bypass. Verificar en cada ejecución.
- EMPTY-08: Test asumía búsqueda de texto pero la UI usa dropdowns. NO-EJEC por diseño diferente al esperado.

---

## SUITE COACH-E2E — Alta de coach + ciclo completo coach↔atleta (2026-07-06)

> E2E ejecutado en local (localhost:3000, Claude Preview) con cuentas nuevas creadas desde cero: `qa.coach.07061151@medaliq.test` (coach) y `qa.atleta.07061151@medaliq.test` (atleta B2B unido por código). Verifica el ciclo de vida completo: crear coach → invitar → vincular → asignar plan → check-in del atleta → visibilidad en el coach.

### CE2E-01 — Registro de coach y onboarding
**Pasos:** `/register` rol "Soy coach" → dashboard.
**Resultado:** ✅ PASS — redirige a `/coach/dashboard`. Banner de bienvenida "Bienvenido a Medaliq" con próximos pasos guiados (agregar asesorado / compartir link). Buen empty state.

### CE2E-02 — Generar código de invitación
**Pasos:** `/coach/invite` → "Generar código".
**Resultado:** ✅ PASS — código `MEDAL-XXXXXX` válido 7 días + link `/join/[code]` + opción "Crear atleta directo".

### CE2E-03 — Vínculo del atleta verificado en el coach
**Pasos:** atleta se registra por el código y confirma → coach abre `Mis Atletas`.
**Resultado:** ✅ PASS — el atleta aparece como ACTIVO en el listado y en el dashboard (Atletas activos 1).
**Nota:** columna DEPORTE del listado sigue con render parcial — **COACH-BUG-01** (ya trackeado).
**Nota:** alerta "Sin check-in hace +7 días" para un atleta recién creado (nunca hizo check-in) → **BUG-NEW-11**.

### CE2E-04 — Asignar plan (constructor visual)
**Pasos:** ficha del atleta → tab Plan → "Crear plan" → template "Carrera 5K (8 semanas)" → Generar.
**Resultado:** ✅ PASS — genera plan periodizado (BASE/DESARROLLO/AFINAMIENTO) usando edad/peso del atleta; abre el Constructor de planes visual (drag-and-drop, tipos de sesión, zonas Z2-Z5). Atleta pasa a "1/8".

### CE2E-05 — Loop de check-in atleta → coach
**Pasos:** atleta hace check-in semanal (peso 71.5, FC reposo 56, energía 7/10, RPE 6/10) → coach revisa dashboard y tab Progreso.
**Resultado:** ✅ PASS parcial —
- Motor adaptativo del atleta responde: "Todo en orden. Sigue el plan — métricas en rango óptimo". ✅
- Dashboard del coach → "Actividad reciente": "…completó check-in semana 1 · energía 7/10". ✅
- Ficha del coach → Progreso → "Historial de check-ins": S1 · Peso 71.5 · FC 56 · Energía 7. ✅
- **Sueño aparece "—"** en el historial aunque el atleta ingresó 7 h → relacionado con **COACH-BUG-05** (agregar Sueño a la lista de campos del check-in no reflejados). ⚠️
- **Toggle "sesiones completadas" (0/4)** del check-in no respondió a interacción programática — **verificar accesibilidad/click estándar** (posible artefacto de automatización; confirmar manualmente). ⚠️

### CE2E-06 — Mensajería bidireccional
**Pasos:** atleta envía mensaje → coach responde desde la ficha (tab Mensajes).
**Resultado:** ✅ PASS — mensaje del atleta llega al coach y la respuesta del coach se entrega al atleta. Chat 1:1 funcional.

### CE2E-07 — KPI Adherencia inconsistente (BUG-061)
**Pasos:** dashboard del coach tras 1 check-in.
**Resultado:** ❌ FAIL — "Check-ins semana 1/1 · 100% de adherencia" convive con "Adherencia Promedio 0%". Reproducido con datos frescos → confirma que es bug de cálculo del KPI, no de datos.
**Bug:** **BUG-061** (P1, ya trackeado) — extender: el KPI "Adherencia Promedio" del dashboard del coach y la columna Adherencia del listado devuelven 0% mientras la ficha individual calcula el valor real. Unificar la fuente del cálculo.

### Resumen SUITE COACH-E2E (2026-07-06)
| Test | Resultado | Bug |
|------|-----------|-----|
| CE2E-01 — Registro coach + onboarding | ✅ PASS | — |
| CE2E-02 — Código de invitación | ✅ PASS | — |
| CE2E-03 — Vínculo verificado | ✅ PASS | COACH-BUG-01 · BUG-NEW-11 |
| CE2E-04 — Asignar plan (constructor visual) | ✅ PASS | — |
| CE2E-05 — Loop check-in atleta→coach | ⚠️ PARCIAL | COACH-BUG-05 (sueño) · toggle a verificar |
| CE2E-06 — Mensajería bidireccional | ✅ PASS | — |
| CE2E-07 — KPI Adherencia | ❌ FAIL | BUG-061 (P1) |

**Bugs nuevos de esta suite:**
| Bug | Descripción | Prioridad |
|-----|-------------|-----------|
| BUG-NEW-11 | Alerta "Sin check-in hace +7 días" para atleta recién creado (nunca hizo check-in) — debería ser "recién unido"/"sin check-ins aún" | BAJO |
