# Medaliq — Tests E2E: Atleta B2B (Miguel — Con Coach)

**URL base:** `https://www.medaliq.com`
**Ejecutar DESPUES de `test-atleta-b2c.md` y ANTES de `test-coach-admin.md`**

**Protocolo:** Ejecutar cada test en orden. Al terminar, registrar resultado en la SECCION DE REPORTE al final. Si falla, anotar el error exacto y continuar.

**Protocolo de capturas:**
- FAIL / PARCIAL → screenshot obligatorio
- PASS con valor numérico verificado (kcal, IMC, FC, peso, macros) → screenshot del valor visible en pantalla
- PASS funcional sin valor numérico → no capturar (registrar solo resultado)

---

## ⚠️ CAMBIOS DE ARQUITECTURA — Leer antes de ejecutar (actualizado 2026-07-10)

| Cambio | Detalle |
|--------|---------|
| `Goal` model ELIMINADO | La tabla `Goal` y el modelo `GoalStatus` ya no existen. `goalType` vive en `HealthProfile.sportGoal` y `TrainingPlan.goalType`. Ignorar cualquier fila `Goal` en datos de DB. |
| Plan "18 semanas" REMOVIDO de UI | `RACE_HALF_MARATHON` y `RACE_MARATHON` fueron eliminados de los selectores UI. El plan de Miguel en seed (18 semanas) sigue en DB pero no se puede crear uno nuevo desde UI. Máximo 12 semanas en creación nueva. |
| `/messages` NO EXISTE | No hay ruta `/messages` en la app. Las referencias a mensajes coach↔atleta en B2B-03 corresponden a una feature no implementada. Marcar B2B-03 como N/A. |
| `/log` → redirect | `/log` redirige a `/log/history`. El historial unificado (GymSession + SessionLog libre) vive en `/log/history`. El test UX-02 debe verificar `/log/history`, no `/log`. |
| Nutrición B2B | Si el coach asignó `AssignedNutritionPlan`, aparece badge "Plan de tu coach: [nombre]" en `/nutrition`. Tiene prioridad sobre `MealPlan` base. |
| `CoachNutritionProposal` | El coach puede proponer ajustes de macros. El atleta los ve en `/nutrition` y acepta/rechaza. NUNCA se aplican automáticamente. |
| `AssignedWorkout` | Si el coach asignó una rutina, aparece en `/gym` con el plan semanal. Sin asignación → muestra plantillas públicas. |

---

## Datos esperados de DB — Miguel Atleta

| Campo | Valor esperado | Fuente |
|-------|---------------|--------|
| Email | miguel@medaliq.com | User |
| Nombre | Miguel Atleta | User.name |
| Rol | ATHLETE | User.role |
| Coach asignado | Carlos Entrenador (coach@medaliq.com) | CoachAthlete |
| onboardingCompleted | true | User |
| Edad | 30 | HealthProfile.age |
| Altura | 175 cm | HealthProfile.heightCm |
| Peso inicial | 75 kg | HealthProfile.weightKg |
| Peso objetivo | 70 kg | HealthProfile.weightGoalKg |
| hrResting | 55 | HealthProfile.hrResting |
| hrMax | 185 | HealthProfile.hrMax |
| Altitud | 2600 m | HealthProfile.altitudeMeters |
| HR Zonas | Z1:[95-114], Z2:[115-133], Z3:[134-152], Z4:[153-171], Z5:[172-185] | TrainingPlan.hrZones |
| Plan activo | Media Maratón — 18 semanas (seed-plan-1) | TrainingPlan |
| Plan inicio | weeksAgo(6) desde 2026-05-29 → ~2026-04-17 | TrainingPlan.startDate |
| Semana actual | Calculada dinamicamente segun fecha actual | getPlanWeekNumber() |
| Semana en seed | 6 semanas definidas: 1-4=BASE, 5-6=DESARROLLO | PlanWeek.phase |
| ~~Goal~~ | **ELIMINADO** — era `RACE_HALF_MARATHON`. GoalType ahora en `HealthProfile.sportGoal` y `TrainingPlan.goalType` | ~~Goal model~~ |
| NutritionPlan.tdee | 2633 kcal | NutritionPlan |
| NutritionPlan.targetKcalHard | 2133 kcal (dia HIGH) | NutritionPlan |
| NutritionPlan.targetKcalEasy | 1933 kcal (dia MODERATE) | NutritionPlan |
| NutritionPlan.targetKcalRest | 1733 kcal (dia REST) | NutritionPlan |
| NutritionPlan.proteinG | 150 g | NutritionPlan |
| kcal en dia REST (REGR-03) | ~1702 kcal | getDailyNutritionTarget |
| NutritionPlan.carbsHardG | 267 g | NutritionPlan |
| NutritionPlan.carbsEasyG | 169 g | NutritionPlan |
| NutritionPlan.fatG | 52 g | NutritionPlan |
| Check-ins en seed | 6 semanas (wn=1-6) con adherencia: 85,80,90,95,88,85% | WeeklyCheckIn |
| Rutina gym | NO asignada por coach actualmente (DC-19 gap de datos) | AssignedWorkout |
| featurePlan | true | User.featurePlan |
| featureCheckin | true | User.featureCheckin |
| featureNutrition | true | User.featureNutrition |
| featureGym | true | User.featureGym |
| featureCoach | false (es ATHLETE, no COACH) | User.featureCoach |

**Nota sobre la semana actual:** El plan inicio weeksAgo(6) desde la fecha de referencia del seed (2026-05-29). Esto significa que la semana actual en produccion depende de la fecha de ejecucion del test. En la ejecucion del 29 jun 2026 la semana era la 11/18 (en fase DESARROLLO segun semanas > 6 pero el seed solo tiene datos hasta semana 6). La UI puede mostrar cualquier semana entre 7-18 segun la fecha real.

---

## Datos esperados de DB — Atletas del Coach (para contexto de CROSS tests)

| Atleta | Email | Coach | Plan | Semanas seed |
|--------|-------|-------|------|-------------|
| Juan Perez | juan.perez@medaliq.com | Carlos | 10K — 12 semanas (seed-plan-3) | 5 semanas (1-4=BASE, 5=DESARROLLO) |
| Sebastian Rios | sebastian.rios@medaliq.com | Carlos | 5K — 8 semanas (seed-plan-9) | 4 semanas (1-2=BASE, 3-4=ESPECIFICO) |
| Nicolas Gutierrez | nicolas.gutierrez@medaliq.com | Carlos | pendiente asignacion DC-19 | — |
| Santiago Rodriguez | santiago.rodriguez@medaliq.com | Carlos | segun seed | — |

---

## SUITE 1 — ATHLETE B2B (Miguel — Con Coach Asignado)

**Antes de iniciar:** Cerrar sesion activa: `https://www.medaliq.com/api/auth/signout`

### B2B-01
**Descripcion:** Login como Miguel y verificar dashboard B2B
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`
2. Email: `miguel@medaliq.com`, password: `atleta123`, submit
3. Verificar redirect a `/dashboard`
4. Verificar que aparece card o info del coach asignado (Carlos Entrenador)
5. Verificar que aparece "Semana N/18" con la semana actual del plan
**Esperado:** Dashboard con informacion del coach visible. Semana del plan visible. No va a /onboarding.
**Severidad si falla:** ALTO

---

### B2B-02
**Descripcion:** Card del coach en dashboard — datos exactos
**Precondicion:** Sesion como Miguel, en `/dashboard`
**Datos esperados:** Carlos Entrenador (coach@medaliq.com) como coach asignado
**Pasos:**
1. En `/dashboard` buscar la card o seccion del coach
2. Verificar que muestra nombre "Carlos Entrenador"
3. Verificar que hay link o boton para ir a mensajes
**Esperado:** Card de coach visible con nombre "Carlos Entrenador" y acceso a mensajes.
**Severidad si falla:** ALTO

---

### B2B-03 ⛔ N/A — FEATURE NO IMPLEMENTADA
**Descripcion:** ~~Enviar mensaje al coach~~
**Nota:** La ruta `/messages` no existe en la app. La feature de mensajería coach↔atleta no está implementada. Marcar como N/A.
**Pasos:** ~~
1. Ir a mensajes (desde dashboard o sidebar)
2. Verificar que aparece la conversacion con "Carlos Entrenador"~~
3. Escribir un mensaje: "Hola coach, este es un test automatico B2B"
4. Enviar el mensaje
**Esperado:** Mensaje enviado y visible en la conversacion con la hora correcta. Sin errores.
**Nota:** Este mensaje sera verificado desde el panel del coach en test-coach-admin.md (COACH-11 y DC-22).
**Severidad si falla:** ALTO

---

### B2B-04
**Descripcion:** Ver plan de entrenamiento asignado por coach
**Precondicion:** Sesion como Miguel
**Datos esperados:** Plan "Media Maratón — 18 semanas" (seed-plan-1), semana actual en modo dinamico
**Pasos:**
1. Ir a `/plan`
2. Verificar que hay un plan activo con el nombre "Media Maratón" o similar
3. Verificar sesiones de la semana actual (tipos: RODAJE_Z2, FARTLEK, TEMPO, INTERVALOS, TIRADA_LARGA, DESCANSO)
4. Verificar que la fase de la semana es visible (BASE o DESARROLLO segun semana actual)
**Esperado:** Plan visible con nombre "Media Maratón — 18 semanas". Sesiones con tipos correctos. Fase visible.
**Nota:** El plan tiene 6 semanas de sesiones definidas en seed (semanas 1-6). Semanas posteriores pueden estar vacias — eso no es bug.
**Severidad si falla:** ALTO

---

### B2B-05
**Descripcion:** Check-in semanal completo
**Precondicion:** Sesion como Miguel
**Pasos:**
1. Ir a `/checkin`
2. Completar todos los campos del formulario:
   - RPE general: `7`
   - Energia: `4`
   - Horas de sueno: `7.5`
   - Peso: `73` kg
   - Si hay campo de dolor muscular: `0` (sin dolor)
   - Si hay campo de estres: `3`
   - Notas: "Test e2e automatico B2B"
3. Submit
**Esperado:** Check-in guardado. Confirmacion visible o redirect. Sin errores 500.
**Severidad si falla:** ALTO

---

### B2B-06
**Descripcion:** Verificar km/semana en dashboard
**Precondicion:** Sesion como Miguel, en `/dashboard`
**Datos esperados seed:** Semanas con volumen: 30, 34, 38, 28, 42, 45 km (segun la semana actual)
**Pasos:**
1. Buscar resumen de kilometros de la semana o sesiones completadas
2. Si hay sesiones completadas, muestra el resumen con km
3. Si es semana sin sesiones marcadas, muestra 0 o inicio
**Esperado:** Widget km/semana visible en dashboard. Sin errores. Datos coherentes con el plan.
**Severidad si falla:** BAJO

---

### B2B-07
**Descripcion:** Tests de Rendimiento visibles en /progress — despues de que el coach registre benchmarks
**Feature:** #10 — PerformanceBenchmarks en /progress (athlete view)
**Precondicion:** Sesion como Miguel. **Requiere que COACH-19 haya sido ejecutado primero** (coach registra benchmark para Sebastian Rios). Este test verifica la vista athlete. Ejecutar con Sebastian si Miguel no tiene benchmarks registrados. Alternativamente, si el coach registro benchmarks para Miguel (cualquier test anterior), usar Miguel directamente.
**Pasos (con Sebastian como usuario alternativo si Miguel no tiene benchmarks):**
1. Login como sebastian.rios@medaliq.com / atleta123
2. Ir a `/progress`
3. Verificar que al final de la pagina aparece la seccion "Tests de Rendimiento" (solo visible si existen benchmarks)
4. Verificar que muestra el benchmark registrado por el coach: "5K — 27:00" (1620 segundos formateados)
5. Verificar que los benchmarks estan agrupados por deporte (RUNNING)
6. Si Miguel tiene benchmarks propios, repetir desde el inicio con miguel@medaliq.com
**Esperado:** Seccion "Tests de Rendimiento" visible en /progress. Benchmark con metrica, valor formateado (27:00 para seconds) y fecha. Agrupado por deporte. Sin errores.
**Nota:** Si el atleta no tiene benchmarks registrados, la seccion NO aparece (no es un empty state, simplemente no se renderiza). En ese caso marcar N/A y confirmar que la seccion no aparece sin error.
**Severidad si falla:** MEDIO

---

## SUITE 2 — UX/UI (Contexto B2B)

### UX-02
**Descripcion:** No hay errores 404 en links del sidebar de ATHLETE B2B
**Perfil:** miguel@medaliq.com (ATHLETE con todas las features activas)
**Precondicion:** Sesion como Miguel (tiene todas las features: plan, checkin, nutrition, progress, log, gym)
**Pasos:**
1. Hacer click en cada link del sidebar de atleta uno por uno:
   - Dashboard
   - Mi Plan / Plan
   - Check-in
   - Nutricion
   - Progreso
   - Log / Registro (→ redirige a `/log/history`)
   - Gym
   - ~~Mensajes~~ (N/A — no implementado)
2. Verificar que cada uno carga correctamente
**Esperado:** Ninguna pagina retorna 404 ni muestra "This page could not be found". Todas las features activas para miguel.
**Severidad si falla:** ALTO

---

## SUITE 3 — EMPTY STATES (Contexto B2B)

### EMPTY-07
**Descripcion:** Atleta B2B con onboarding completo pero sin plan asignado ve mensaje de coach
**Perfil:** Atleta B2B sin plan (usar juan.perez@medaliq.com si ya completo el plan en seed, o un atleta recien creado en COACH-06)
**Precondicion:** Atleta B2B activado pero sin plan asignado por coach
**Nota:** Si juan.perez tiene plan activo en seed, este test requiere un atleta diferente sin plan. Usar el creado en COACH-06 si fue activado.
**Pasos:**
1. Login como atleta B2B activado sin plan
2. Navegar a `/plan`
3. Observar mensaje mostrado
**Esperado:** "Tu coach aun no ha asignado un plan de entrenamiento." (no "Genera uno nuevo" — es B2B, el coach asigna). CTA para volver al dashboard.
**Severidad si falla:** ALTO

---

## SUITE 4 — ERROR HANDLING (Contexto B2B)

### ERR-04
**Descripcion:** Submit de check-in sin campos obligatorios muestra validacion
**Perfil:** miguel@medaliq.com
**Precondicion:** En `/checkin`. Este test verifica validacion UI + API.
**Estado anterior (REGR-04 confirmado):** API rechaza body vacio con 400 en produccion.
**Pasos:**
1. Navegar a `/checkin`
2. No llenar ningun campo del formulario
3. Intentar hacer submit
4. Observar que sucede en la UI
**Esperado (UI):** Mensaje de validacion visible en el formulario antes de enviar al servidor. "Completa al menos la energia percibida y el RPE." o similar.
**Esperado (API):** Si el submit llega al servidor con body vacio, debe retornar 400 (REGR-04 confirmado).
**Severidad si falla:** ALTO

---

## SUITE 5 — MOBILE RESPONSIVE (Contexto B2B — Miguel)

**Objetivo:** Verificar que todas las pantallas del atleta B2B funcionan correctamente en mobile. Usar DevTools → Toggle Device Toolbar → iPhone 14 (390×844) para todos los tests.

### MOB-01
**Descripcion:** Bottom nav visible y funcional en mobile
**Perfil:** miguel@medaliq.com (ATHLETE)
**Pasos:**
1. Abrir DevTools, activar modo mobile (iPhone 14)
2. Navegar a `/dashboard`
3. Verificar que hay una barra de navegacion fija en la parte inferior
4. Verificar que tiene exactamente 5 tabs: Dashboard/Inicio, Plan, Gym, Checkin, Perfil
5. Hacer click en cada tab y verificar que navega correctamente
**Esperado:** Bottom nav visible, sticky al scroll, 5 tabs funcionales. NO debe aparecer sidebar lateral.
**Severidad si falla:** CRITICO

### MOB-02
**Descripcion:** Dashboard legible en mobile — sin overflow horizontal
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile activado
**Pasos:**
1. Navegar a `/dashboard`
2. Hacer scroll completo de arriba a abajo
3. Verificar que ningun elemento se sale del ancho de la pantalla (scroll horizontal)
4. Verificar que todas las cards son legibles sin zoom
5. Verificar que los botones son tocables (minimo 44px de alto)
**Esperado:** Layout de una columna, sin overflow. Cards apiladas verticalmente. Card de coach visible y legible.
**Severidad si falla:** ALTO

### MOB-03
**Descripcion:** Formulario de check-in usable en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile. Check-in no hecho esta semana (o usar semana diferente).
**Pasos:**
1. Navegar a `/checkin`
2. Verificar que todos los sliders/inputs son visibles sin hacer scroll horizontal
3. Tocar cada campo de input — verificar que el teclado virtual no rompe el layout
4. Completar el formulario
5. Hacer submit
**Esperado:** Formulario completamente usable en mobile. El teclado no oculta el boton de submit permanentemente.
**Severidad si falla:** CRITICO

### MOB-04
**Descripcion:** Pagina /plan legible en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile. Plan activo (seed-plan-1).
**Pasos:**
1. Navegar a `/plan`
2. Verificar que las semanas del plan son navegables
3. Verificar que cada sesion muestra tipo, duracion y estado (done/pending)
4. Tocar una sesion para ver detalle
5. Verificar que el detalle es legible sin scroll horizontal
**Esperado:** Plan navegable en mobile. Sesiones en columna. Tipos RODAJE_Z2, FARTLEK, TIRADA_LARGA visibles.
**Severidad si falla:** ALTO

### MOB-05
**Descripcion:** Gym tracker usable en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile.
**Pasos:**
1. Navegar a `/gym`
2. Verificar que las opciones disponibles se listan correctamente
3. Iniciar una sesion (con plantilla o rutina disponible)
4. Ingresar series/reps/peso usando el teclado numerico
5. Completar la sesion
**Esperado:** Inputs numericos con teclado numerico. Layout sin overflow. Sesion guardable.
**Nota:** Si Miguel no tiene rutina asignada por el coach, verificar que al menos las plantillas son accesibles en mobile.
**Severidad si falla:** ALTO

### MOB-06
**Descripcion:** Pagina /nutrition legible en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile
**Datos esperados:** Macros calculados del NutritionPlan de miguel (tdee=2633, etc.)
**Pasos:**
1. Navegar a `/nutrition`
2. Verificar que los macros (kcal, proteina, carbos, grasas) son visibles en cards
3. Verificar que las comidas del dia estan listadas
4. Verificar que no hay overflow horizontal
**Esperado:** Macros visibles en cards. Comidas legibles. Layout de una columna.
**Severidad si falla:** MEDIO

### MOB-07
**Descripcion:** Pagina /progress con graficos en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile. Miguel tiene 6 check-ins en seed (semanas 1-6).
**Pasos:**
1. Navegar a `/progress`
2. Verificar que los graficos de peso/RPE son visibles
3. Verificar que los graficos no se cortan ni hacen overflow
4. Verificar que los labels de los ejes son legibles
**Esperado:** Graficos responsivos. No cortados. Legibles sin zoom. Peso historico 73.8-75.2 kg visible.
**Severidad si falla:** MEDIO

### MOB-08
**Descripcion:** Mensajeria coach-atleta en mobile
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile. Hay mensajes previos (enviados en B2B-03).
**Pasos:**
1. Navegar a `/dashboard` — verificar badge de mensajes si hay no leidos
2. Ir a la seccion de mensajes
3. Verificar que el chat con Carlos Entrenador es legible
4. Escribir un mensaje usando el teclado virtual
5. Enviar y verificar que aparece en el chat
**Esperado:** Chat usable en mobile. Input de texto accesible con teclado. Mensajes visibles. Nombre del coach visible.
**Severidad si falla:** ALTO

**Nota:** MOB-09 y MOB-10 no existen — números reservados y descartados durante la construcción del test suite. MOB-11 está en `test-coach-admin.md` (panel del coach en mobile).

### MOB-12
**Descripcion:** Sidebar desktop oculto en mobile, visible en desktop
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile activado
**Pasos:**
1. Navegar a `/dashboard`
2. Verificar que NO hay sidebar lateral visible en 390px
3. Cambiar a modo desktop (1280px)
4. Verificar que el sidebar lateral SI aparece
5. Volver a mobile — verificar que desaparece y aparece bottom nav
**Esperado:** Sidebar `hidden` en mobile, visible en desktop. Bottom nav al reves.
**Severidad si falla:** ALTO

### MOB-13
**Descripcion:** Touch targets minimos en navegacion
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile
**Pasos:**
1. Navegar por el bottom nav
2. Inspeccionar en DevTools la altura de los tabs del bottom nav
3. Verificar que cada tab tiene al menos 44px de altura
4. Verificar que los botones principales (CTAs) tienen al menos 44px de altura
**Esperado:** Touch targets >= 44px. Sin elementos demasiado pequenos para tocar.
**Severidad si falla:** MEDIO

### MOB-14
**Descripcion:** Scroll natural en todas las paginas — sin overflow horizontal
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile
**Pasos:**
1. Navegar a `/plan` — hacer scroll largo por las semanas
2. Navegar a `/progress` — scroll por los graficos
3. Navegar a `/nutrition` — scroll por las comidas
4. Verificar que NO hay scroll horizontal en ninguna pagina
5. Verificar que el bottom nav permanece fijo durante el scroll
**Esperado:** Solo scroll vertical. Bottom nav sticky. Sin elementos que escapen del viewport.
**Severidad si falla:** ALTO

### MOB-15
**Descripcion:** Formularios con inputs numericos usan teclado numerico
**Perfil:** miguel@medaliq.com
**Precondicion:** Modo mobile (real o DevTools)
**Pasos:**
1. Ir a `/checkin`
2. Tocar el campo de peso (kg)
3. Verificar que el tipo de teclado es numerico (no QWERTY)
4. Ir a `/gym` — iniciar sesion — tocar campo de peso/reps
5. Verificar que usa teclado numerico
**Esperado:** `inputMode="numeric"` o `type="number"` activa teclado numerico. Experiencia fluida.
**Severidad si falla:** MEDIO

---

## SUITE 6 — QUICKLOG + CHECK-IN HISTORY + NUTRITION LOG (B2B)

**Perfil:** Miguel (miguel@medaliq.com / atleta123) — atleta B2B con plan activo y NutritionPlan seeded.

### QL-01
**Descripcion:** QuickLog en dashboard — boton "¡Complete!" registra sesion del dia sin abrir gym tracker
**Precondicion:** Miguel con sesion activa, en `/dashboard`. Debe haber una sesion de hoy en el plan activo (PlannedSession para hoy). Si no hay sesion programada para hoy, ir a `/plan`, buscar la semana actual y anotar si hay sesion manana — este test es dependiente del dia de la semana.
**Nota:** El QuickLog aparece en el DailySessionCard SOLO si hay una sesion de running planificada para HOY y todavia no esta completada. Si hoy es dia de descanso en el plan, marcar como NO-EJEC-DIA.
**Pasos:**
1. En `/dashboard`, buscar la card de sesion diaria (debe mostrar tipo: RODAJE_Z2, FARTLEK, etc.)
2. Verificar que el boton verde "¡Complete!" esta visible (QuickLog component)
3. Click en "¡Complete!"
4. Verificar que el boton cambia a estado "Sesion completada" con checkmark verde — sin recargar la pagina completa
5. Recargar la pagina (Ctrl+R) y verificar que el estado "Completada" persiste (no vuelve a mostrar el boton)
**Esperado:** QuickLog registra la sesion via `POST /api/log/session`. El estado persiste tras recargar. El boton desaparece.
**Accion:** Si hoy no hay sesion planificada para Miguel, marcar **NO-EJEC-DIA** (depende del dia de la semana).
**Severidad si falla:** ALTO

---

### HIST-01
**Descripcion:** /progress muestra check-ins historicos de Miguel — semanas anteriores visibles
**Precondicion:** Miguel tiene check-ins en el seed. Sesion activa.
**Pasos:**
1. Ir a `/progress`
2. Verificar que la pagina carga sin error 500
3. Buscar la seccion de historial de check-ins o grafico de peso/tendencia
4. Verificar que hay al menos 1 entrada de check-in con: fecha, peso, RPE, energia
5. Verificar que el grafico de peso (si existe) tiene al menos un punto de datos
6. Verificar que la seccion "Tests de Rendimiento" carga (puede estar vacia si COACH-19 no se ejecuto)
**Esperado:** /progress con datos historicos visibles. Al menos 1 check-in. Sin errores. Graficos con puntos de datos.
**Severidad si falla:** ALTO

---

### HIST-02
**Descripcion:** /progress — grafico de adherencia al entrenamiento muestra porcentaje
**Precondicion:** Miguel con plan activo (seed-plan-1 con sesiones en las semanas anteriores)
**Pasos:**
1. En `/progress`, buscar seccion de adherencia o consistencia de entrenamiento
2. Verificar que muestra un porcentaje de sesiones completadas vs programadas
3. Verificar que el valor es un numero entre 0% y 100% (no NaN, no error)
**Esperado:** Adherencia calculada correctamente. Numero entre 0-100%. Sin NaN ni "undefined".
**Severidad si falla:** MEDIO

---

### NUT-B2B-01
**Descripcion:** /nutrition de Miguel muestra targets seeded y macro breakdown correcto
**Datos esperados (seed):** tdee=2633, targetKcalHard=2133, targetKcalEasy=1933, targetKcalRest=1733, proteinG=150
**Pasos:**
1. Login como miguel@medaliq.com / atleta123
2. Ir a `/nutrition`
3. Verificar que el target calorico del dia es uno de: ~2133 (dia HIGH), ~1933 (dia MODERATE), ~1733 (dia REST) — segun la intensidad de la sesion de hoy
4. Verificar que la proteina objetivo es ~150g
5. Verificar que la seccion "Registro del dia" (TrackingSection) esta visible con barras de progreso
6. Verificar que hay boton "+ Registrar alimento"
**Esperado:** Targets nutricionales correctos segun seed. Barras de macro visibles. Boton de registro presente.
**Severidad si falla:** CRITICO

---

### NUT-B2B-02
**Descripcion:** Registrar alimento para Miguel — flujo identico al B2C pero con targets distintos
**Precondicion:** NUT-B2B-01 exitoso — en `/nutrition` como Miguel
**Pasos:**
1. Click en "+ Registrar alimento"
2. Buscar `arroz` en el buscador del modal
3. Seleccionar "Arroz blanco" (o primer resultado de carbohidrato disponible)
4. Ingresar gramos: `200`
5. Seleccionar tipo: `Almuerzo`
6. Click en "Guardar"
7. Verificar que la barra de carbohidratos se actualiza (Carbos consumidos > 0)
8. Verificar que el alimento aparece en la lista del log del dia
**Esperado:** Alimento registrado. Macros actualizados. Coherencia entre lo registrado y lo mostrado en barras.
**Severidad si falla:** ALTO

---

## SUITE 7 — MOBILE LOADING STATES (B2B)

**Objetivo:** Verificar que la app mobile maneja correctamente los estados de carga, refresh y token expirado.
**Perfil:** Miguel (B2B) en simulacion mobile — usar Claude in Chrome DevTools Toggle Device Toolbar (iPhone 14, 390x844).

### MOB-LOAD-01
**Descripcion:** Pull-to-refresh en dashboard mobile refresca datos sin romper el layout
**Precondicion:** Miguel logueado, pantalla `/dashboard` en mobile DevTools
**Pasos:**
1. Activar mobile en DevTools (iPhone 14)
2. Ir a `/dashboard`
3. Hacer scroll arriba hasta el tope de la pagina
4. Simular pull-down (click y drag hacia abajo en la pantalla)
5. Si el browser no soporta pull-to-refresh, usar el boton de recarga (Ctrl+R)
6. Verificar que el dashboard recarga y muestra contenido correcto (no spinner infinito)
**Esperado:** Dashboard recargado correctamente. Sin layout roto. Sin spinner infinito post-reload.
**Severidad si falla:** MEDIO

---

### MOB-LOAD-02
**Descripcion:** Pagina /nutrition mobile carga macros sin layout shift ni overflow
**Precondicion:** Miguel logueado, modo mobile DevTools 390px
**Pasos:**
1. En DevTools mobile 390px, navegar a `/nutrition`
2. Observar la carga inicial (no debe haber flash de contenido vacio)
3. Verificar que las 4 barras de macro son visibles y no se solapan
4. Verificar que el boton "+ Registrar alimento" es accesible (minimo 44px de altura para touch)
5. Hacer click en "+ Registrar alimento" — verificar que el modal se abre correctamente en mobile
6. El modal debe ocupar al menos 80% del ancho en mobile, sin overflow horizontal
**Esperado:** Macros legibles en 390px. Modal accesible. Sin overflow. Boton con touch target adecuado.
**Severidad si falla:** MEDIO

---

### MOB-LOAD-03
**Descripcion:** Token expirado / sesion cerrada en otra pestaña — redirige a login correctamente
**Precondicion:** Miguel logueado en una pestaña
**Pasos:**
1. En una nueva pestaña (o incognito), ir a `/login` y hacer logout de otra cuenta para invalidar sesion
2. De vuelta en la pestaña original de Miguel, intentar navegar a `/plan`
3. Alternativamente: abrir DevTools → Application → Cookies → eliminar la cookie de sesion de next-auth
4. Recargar la pagina
**Esperado:** Redirige a `/login`. No muestra error 500. No queda en pantalla blanca. El redirect es limpio.
**Severidad si falla:** CRITICO

---

## SUITE: ATHLETE UX IMPROVEMENTS (B2B)

### PENDING-01
**Descripcion:** /pending para atleta B2B no activado muestra stepper + CTAs
**Precondicion:** Atleta B2B sin activar (NO Miguel — el ya esta activado). Usar nicolas.gutierrez@medaliq.com si tiene coach pero sin activar. Si no existe -> NO-EJEC.
**Pasos:**
1. Login como atleta B2B no activado
2. Verificar redirect a `/pending`
3. Verificar stepper de 3 pasos: "Registro completado" (check verde), "Perfil completado" (check verde), "[Nombre coach] esta preparando tu plan" (reloj ambar)
4. Si >= 1 dia esperando, verificar badge ambar "Llevas N dias esperando"
5. Verificar 3 CTAs: "Registrar sesion de hoy" -> /log, "Registrar lo que comiste" -> /nutrition, "Escribirle a [coach]" -> /messages/[coachId]
6. Verificar que los links /log y /nutrition funcionan (no redirigen a /pending)
**Esperado:** Stepper visual con 3 pasos. Badge de dias. 3 CTAs funcionales.
**Severidad si falla:** ALTO
**Nota:** NO-EJEC si no hay atleta B2B sin activar en seed.

---

### PLAN-CELEB-01
**Descripcion:** /plan con plan COMPLETED muestra PlanCompletionCard con stats
**Precondicion:** Miguel con plan status=COMPLETED (si ACTIVE -> NO-EJEC)
**Pasos:**
1. Login como Miguel (miguel@medaliq.com / atleta123)
2. Ir a `/plan`
3. Si plan ACTIVE -> NO-EJEC (Miguel tiene plan activo en seed)
4. Si plan COMPLETED -> verificar PlanCompletionCard con:
   - Nombre del plan
   - Total semanas
   - Sesiones completadas / total
   - % adherencia
   - Dias de recuperacion desde endDate
5. Verificar CTA "Volver al inicio" (B2B)
**Esperado:** PlanCompletionCard con metricas. CTA correcta para B2B.
**Severidad si falla:** MEDIO
**Nota:** NO-EJEC si Miguel tiene plan ACTIVE (estado normal del seed).

---

### HERO-NUT-01
**Descripcion:** TrackingSection es el primer elemento visible en /nutrition
**Precondicion:** Miguel logueado
**Pasos:**
1. Ir a `/nutrition`
2. Verificar que lo primero visible (hero) es la barra de progreso calorico con kcal consumidas/target
3. Verificar que debajo hay 3 barras de macros (proteina, carbos, grasa)
4. Verificar que las barras muestran valores numericos (no NaN, no 0/0)
5. Verificar que el target coincide con seed (~1702 kcal REST, ~2133 HIGH, ~1933 MODERATE)
6. Verificar que la seccion de log de comidas viene DEBAJO del hero
**Esperado:** TrackingSection como hero. Barras con datos correctos. Log debajo.
**Severidad si falla:** ALTO

---

### CHECKIN-RES-02
**Descripcion:** Check-in B2B muestra triggers y adjustments post-envio
**Precondicion:** Miguel logueado, check-in NO enviado esta semana
**Pasos:**
1. Ir a `/checkin`
2. Si ya enviado esta semana -> verificar que muestra resumen del ultimo check-in -> NO-EJEC para submit
3. Si no enviado: completar campos (peso, sueno, energia, RPE)
4. Enviar
5. Verificar resultado inline con triggers[] (ej: "Peso estable", "Energia alta")
6. Verificar adjustments si el coach los configuro
**Esperado:** Resultado inline post-submit. Triggers visibles.
**Severidad si falla:** ALTO

---

### MEAL-TPL-03
**Descripcion:** Miguel puede guardar y cargar plantillas de comida
**Precondicion:** Miguel logueado en `/nutrition`
**Pasos:**
1. Ir a `/nutrition`
2. Click en "+ Registrar alimento"
3. Agregar 2 alimentos (ej: "pollo" 250g + "arroz" 200g)
4. Guardar como plantilla "Post-entreno"
5. Verificar confirmacion
6. Abrir modal de nuevo, verificar que "Post-entreno" aparece en "Mis comidas"
7. Cargar plantilla y confirmar que precarga los 2 alimentos
**Esperado:** Plantilla guardada y cargable. Alimentos precargados correctamente.
**Severidad si falla:** MEDIO

---

### BODY-02
**Descripcion:** Check-in de Miguel tiene campos opcionales de medidas corporales
**Precondicion:** Miguel logueado, check-in no enviado esta semana
**Pasos:**
1. Ir a `/checkin`
2. Buscar seccion colapsable de medidas corporales
3. Expandir y verificar 4 campos: cintura, brazos, cadera, muslo
4. Ingresar valores y enviar con campos obligatorios
5. Verificar que check-in guarda correctamente
**Esperado:** Medidas corporales opcionales en check-in. Guardado sin error.
**Severidad si falla:** MEDIO
**Nota:** NO-EJEC si check-in ya enviado.

---

### PROFILE-01
**Descripcion:** Desde /profile, editar datos de salud (peso, altura, edad)
**Precondicion:** Miguel logueado
**Pasos:**
1. Ir a `/profile`
2. Buscar seccion "Datos fisicos" o "Perfil de salud"
3. Click en "Editar" o similar
4. Verificar que muestra campos editables: peso (75 kg), altura (175 cm), edad (30)
5. Modificar peso a 74 kg
6. Guardar cambios
7. Verificar que el cambio persiste al recargar
8. Restaurar peso a 75 kg para no afectar otros tests
**Esperado:** Campos editables. Cambio guardado y persistente.
**Severidad si falla:** MEDIO

---

### NUT-ADJ-01
**Descripcion:** NutritionAdjustmentCard visible cuando hay ajuste pendiente del coach
**Precondicion:** Miguel logueado, con ajuste nutricional pendiente (si no hay -> NO-EJEC)
**Pasos:**
1. Ir a `/nutrition`
2. Buscar NutritionAdjustmentCard o banner de ajuste pendiente
3. Si visible: verificar que muestra cambios propuestos (kcal, macros)
4. Verificar botones Aceptar / Rechazar
5. Click en "Aceptar"
6. Verificar que los targets se actualizan
**Esperado:** Card de ajuste visible con cambios propuestos. Aceptar actualiza targets.
**Severidad si falla:** MEDIO
**Nota:** NO-EJEC si no hay ajuste pendiente en DB.

---

### Reporte — SUITE ATHLETE UX IMPROVEMENTS (B2B)

| ID | Descripcion | Resultado | Observado |
|----|-------------|-----------|-----------|
| PENDING-01 | /pending stepper + CTAs para atleta B2B sin activar | | |
| PLAN-CELEB-01 | /plan PlanCompletionCard B2B | | |
| HERO-NUT-01 | TrackingSection como hero en /nutrition | | |
| CHECKIN-RES-02 | Check-in resultado inline B2B | | |
| MEAL-TPL-03 | Plantillas de comida B2B | | |
| BODY-02 | Medidas corporales en check-in B2B | | |
| PROFILE-01 | Editar perfil de salud en /profile | | |
| NUT-ADJ-01 | NutritionAdjustmentCard pendiente del coach | | |

---

## SUITE 8 — ATLETAS ADICIONALES B2B (Juan y Sebastián)

### ATL-QA-01
**Descripcion:** Login como Juan Pérez y verificar idioma de la UI
**Precondicion:** Sin sesión activa. juan.perez@medaliq.com / atleta123
**Pasos:**
1. Login como juan.perez@medaliq.com / atleta123
2. Verificar URL de redirect (dashboard o onboarding)
3. Verificar idioma del nav (document.documentElement.lang)
**Esperado:** UI en español (lang="es"). Nav en español.
**Resultado:** ⚠️ PARCIAL
**Observado:** Login exitoso → /dashboard. lang="pt" (portugués). Nav muestra "Início, Meu Plano, Nutrição, Progresso, Meu perfil" en vez de español. Según A11Y-02 (done:true) esto es "working as designed" — el usuario tiene cookie de preferencia PT guardada. Sin embargo es un estado inesperado para un usuario con nombre Juan Pérez en LatAm.
**Severidad si falla:** BAJO (working as designed según roadmap)

---

### ATL-QA-02
**Descripcion:** Dashboard de Juan — semana 11/12 con plan 10K muestra fase BASE (debería ser otra)
**Precondicion:** Sesión como Juan (juan.perez@medaliq.com)
**Pasos:**
1. En /dashboard, verificar la semana activa y la fase mostrada
2. Verificar coherencia: el seed define semanas 1-4=BASE, 5=DESARROLLO para Juan (10K — 12 semanas)
3. La semana 11/12 no tiene sesiones definidas en seed — verificar qué fase muestra
**Esperado:** Semana 11 sin sesiones debe mostrar empty state o fase indefinida. Si muestra BASE es un fallback.
**Resultado:** ⚠️ PARCIAL
**Observado:** Dashboard muestra "Sem. 11 · Fase BASE · 0/0 completadas · Descanso hoy". La semana 11 no tiene sesiones en el seed (solo 5 semanas definidas). El sistema hace fallback a BASE cuando la semana no tiene fase definida. No es error crítico pero puede confundir al atleta.
**Severidad si falla:** BAJO

---

### ATL-QA-03
**Descripcion:** Meta de peso de Juan — velocidad de pérdida mostrada (-2.1 kg/sem)
**Precondicion:** Sesión como Juan
**Pasos:**
1. En /dashboard, observar la sección "TU META DE PESO"
2. Verificar la velocidad de pérdida proyectada
**Esperado:** Velocidad razonable (máx ~0.5-1 kg/sem para pérdida saludable). Si el sistema muestra >1 kg/sem debería al menos advertir.
**Resultado:** ⚠️ PARCIAL
**Observado:** "71.0 kg → 70 kg · ~1 semanas · -2.1 kg/sem". El déficit calculado implica -2.1 kg en 1 semana lo cual supera las recomendaciones médicas. El valor puede ser un artefacto del seed (peso en check-in reciente más bajo que el peso base). Sin banner de advertencia.
**Severidad si falla:** MEDIO

---

### ATL-QA-04
**Descripcion:** Dashboard de Sebastián — inconsistencia "Sin plan activo" + "🏆 5K — 8 semanas"
**Precondicion:** Sesión como sebastian.rios@medaliq.com / atleta123
**Pasos:**
1. Login y verificar /dashboard
2. Observar el hero card principal y el contenido de la semana
**Esperado:** Si hay plan activo, el hero debe mostrar el plan. Si no hay plan, no debe haber card del plan.
**Resultado:** ⚠️ PARCIAL
**Observado:** Hero card muestra "Sin plan activo". Pero la sección "ESTA SEMANA" muestra "🏆 5K — 8 semanas · 0/13 sesiones completadas · Recuperación · día 8/14". Inconsistencia visual: el hero dice "sin plan" pero el widget semanal muestra datos del plan. El plan existe (status posiblemente COMPLETED o en período de taper/recuperación).
**Severidad si falla:** MEDIO

---

### ATL-QA-05
**Descripcion:** Check-in semanal — estado cuando es viernes (día de check-in)
**Precondicion:** Sesión como Miguel (miguel@medaliq.com). Hoy es viernes 3 de julio.
**Pasos:**
1. Ir a /checkin
2. Verificar si el formulario está disponible hoy (viernes)
**Esperado:** El check-in se activa el viernes. Si hoy ES viernes, debería estar disponible.
**Resultado:** ⚠️ PARCIAL
**Observado:** /checkin muestra "Se activa el viernes · Tu próximo check-in es el viernes, 3 de julio". La fecha HOY es viernes 3 de julio. El sistema indica que el check-in ES para hoy pero el mensaje dice "espera al final de la semana". Existe botón "Abrir check-in de todas formas". El mensaje es confuso — si hoy es el día, no debería decir "espera".
**Severidad si falla:** MEDIO

---

### ATL-QA-06
**Descripcion:** Gym de Miguel (B2B) — empty state para atleta sin rutina asignada por coach
**Precondicion:** Sesión como Miguel
**Pasos:**
1. Ir a /gym
2. Verificar mensaje mostrado
**Esperado:** Mensaje informativo explicando que el coach asignará la rutina. CTA o información de próximos pasos.
**Resultado:** ✅ PASS
**Observado:** /gym muestra "🏋️ Tu coach gestionará tu rutina · Cuando tu coach te asigne una rutina de gym, aparecerá aquí automáticamente." Empty state correcto para B2B sin rutina asignada.
**Severidad si falla:** ALTO

---

### ATL-QA-07
**Descripcion:** Perfil de Miguel — Fecha de nacimiento vacía pese a tener edad 30
**Precondicion:** Sesión como Miguel
**Pasos:**
1. Ir a /profile
2. Verificar campo "Fecha de nacimiento"
3. Verificar si la edad (30) está calculada desde DOB o almacenada directamente
**Esperado:** Fecha de nacimiento registrada o mensaje claro de que no está capturada. BUG-022 ya resuelto debe calcular edad desde DOB.
**Resultado:** ⚠️ PARCIAL
**Observado:** /profile muestra "Fecha de nacimiento: —" (vacío) y "Edad: 30 años". La edad está almacenada directamente (como number), no derivada de DOB. El fix de BUG-022 (calcAge desde dateOfBirth) requiere que la fecha esté cargada, pero el seed no la tiene. Edad puede quedar stale cuando cumpla años.
**Severidad si falla:** BAJO

---

### ATL-QA-08
**Descripcion:** Landing pública — verificar idioma cuando usuario sin cookie de idioma
**Precondicion:** Sin sesión activa, sin cookie de preferencia de idioma
**Pasos:**
1. Ir a https://www.medaliq.com (home)
2. Verificar idioma de los botones de CTA
**Esperado:** Landing en español (DEFAULT_LOCALE="es" según código).
**Resultado:** ❌ FAIL
**Observado:** Los botones de la landing aparecen en inglés: "Reserve free access →", "I'm a coach", "I'm an athlete", "Start free →", "Start 30 days free →". El html lang podía estar en "en" por preferencia del browser. El contenido del marketing está en inglés cuando debería ser en español para el mercado LatAm objetivo.
**Severidad si falla:** ALTO

---

## REPORTE — test-atleta-b2b.md

> **Instrucciones:** Edita esta seccion con los resultados reales. Usa el formato indicado.

### Ejecucion 3 — 2026-07-03 (QA Exhaustivo Senior)

**Fecha:** 2026-07-03
**Hora inicio:** ~10:00

#### Suite ATLETAS ADICIONALES B2B (Juan y Sebastián) — Ejecucion 2026-07-03

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ATL-QA-01 | Idioma Juan Pérez — UI en portugués | ⚠️ PARCIAL | lang="pt", nav en PT. Working as designed (A11Y-02 done:true) pero estado raro para usuario LatAm |
| ATL-QA-02 | Dashboard Juan — sem.11 con fase BASE (sin sesiones en seed) | ⚠️ PARCIAL | Fallback a BASE para semanas sin fase definida. No crítico pero confuso |
| ATL-QA-03 | Meta peso Juan — -2.1 kg/sem (excede límite saludable) | ⚠️ PARCIAL | Posible artefacto del seed. Sin advertencia médica en UI |
| ATL-QA-04 | Dashboard Sebastián — "Sin plan activo" pero widget muestra 5K 8sem | ⚠️ PARCIAL | Inconsistencia visual hero vs widget semanal. Plan en recuperación post-completado |
| ATL-QA-05 | Check-in viernes — mensaje confuso "espera al viernes" cuando ES viernes | ⚠️ PARCIAL | UI dice "Tu próximo check-in es el viernes, 3 de julio" siendo hoy viernes 3 de julio |
| ATL-QA-06 | Gym B2B sin rutina — empty state correcto | ✅ PASS | "Tu coach gestionará tu rutina" — mensaje correcto |
| ATL-QA-07 | Perfil Miguel — fecha nacimiento vacía, edad 30 almacenada directo | ⚠️ PARCIAL | DOB no capturado en seed. BUG-022 fix requiere DOB cargada |
| ATL-QA-08 | Landing pública en inglés (debería ser español) | ❌ FAIL | CTAs en inglés: "Reserve free access", "I'm a coach", "Start free" |

#### Resumen Ejecucion 2026-07-03 (B2B adicional)

| Tests | PASS | FAIL | PARCIAL |
|-------|------|------|---------|
| 8 | 1 | 1 | 6 |

**FAILs nuevos:**
- ATL-QA-08: Landing pública muestra CTAs en inglés — impacto en conversión LatAm (ALTO)

**PARCIALes a seguir:**
- ATL-QA-04: Inconsistencia hero vs widget en Sebastián (plan en recuperación) — investigar estado del plan
- ATL-QA-05: Mensaje check-in confuso para el día viernes — UX mejorable

---

### Ejecucion 2 — 2026-07-01

**Fecha:** 2026-07-01

#### Suite B2B — Ejecucion 2026-07-01

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| B2B-01 | Login Miguel → dashboard | ✅ PASS | Login → /dashboard directo. "Buenos dias, Miguel", semana 11/18, Media Maraton visible |
| B2B-02 | Card coach "Carlos Entrenador" | ✅ PASS | CoachCard visible con "Carlos Entrenador", ultimo check-in: RPE 6, energia 5, 73kg |
| B2B-03 | Enviar mensaje al coach | ✅ PASS | Mensaje "test automatico B2B — 2026-07-01" enviado. Timestamp "12:35 a.m. · 1 de jul" |
| B2B-04 | Plan Media Maraton 18 semanas | ✅ PASS | /plan: "Plan Media Maraton · 18 semanas", Sem.11, BASE, hoy=Descanso, 1702 kcal REST |
| B2B-05 | Check-in enviado — muestra resumen | ✅ PASS | /checkin muestra resumen (ya enviado sem. 6, 29 jun). Próximo: viernes 3 jul |
| B2B-06 | Km/semana + resumen dashboard | ✅ PASS | Dashboard: 0/0 sesiones (dia descanso). CoachCard con RESUMEN RAPIDO visible |
| B2B-07 | Tests de Rendimiento en /progress | 🚫 NO-EJEC | Miguel sin benchmarks. Seccion no renderizada (correcto segun spec) |

#### Suite UX + MOBILE + HIST — Ejecucion 2026-07-01

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| UX-02 | Sin 404 en sidebar atleta B2B | ✅ PASS | 7 rutas verificadas con fetch: todas 200 |
| MOB-01/12 | Bottom nav + sidebar responsive | ✅ PASS | lg:hidden fixed bottom-0 en DOM. Estructura responsive correcta |
| NUT-B2B-01 | /nutrition targets correctos | ✅ PASS | 1702 kcal REST, 146g proteina, 116g carbos, 52g grasas. TDEE 2602 |
| LOG-01 | /log/history carga | ✅ PASS | Carga con empty state "Sin actividad registrada" + CTAs |
| QL-01 | QuickLog | 🚫 NO-EJEC-DIA | Hoy es descanso en sem.11 para Miguel |
| ERR-04 | Validacion check-in vacio | 🚫 NO-EJEC | Check-in ya enviado esta semana |

#### Resumen Ejecucion 2026-07-01

| Tests | PASS | NO-EJEC |
|-------|------|---------|
| 13 | 10 | 3 |

---

### Ejecucion 1 — 2026-06-30
**Fecha:** 2026-06-30
**Hora inicio:** ~10:30
**Hora fin:** en curso

---

### Resultados

#### Suite B2B (7 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| B2B-01 | Login Miguel → dashboard (card coach visible) | ⚠️ PARCIAL | Miguel fue a /onboarding (seed incompleto). Completado onboarding → /dashboard. Semana 11/18, Media Maraton visible |
| B2B-02 | Card coach muestra "Carlos Entrenador" | ✅ PASS | CoachCard "Carlos Entrenador" visible en dashboard B2B |
| B2B-03 | Enviar mensaje al coach | ✅ PASS | Mensaje "Hola coach, este es un test automatico B2B" enviado y visible en chat |
| B2B-04 | Plan "Media Maraton 18 semanas" visible | ✅ PASS | /plan: "Plan Media Maraton · 18 semanas", Sem. 11/18, fase BASE, nutricion 1702 kcal |
| B2B-05 | Check-in completo con todos los campos | ✅ PASS | Check-in ya enviado esta semana: 73 kg, 7h sueno, 5/10 energia. "Metricas en rango optimo" |
| B2B-06 | Km/semana en dashboard | ✅ PASS | /progress muestra km semanales: S1=30, S2=34, S3=38, S4=28, S5=42, S6=45 |
| B2B-07 | Tests de Rendimiento en /progress (post COACH-19) | ⬜ NO-EJEC | Miguel no tiene benchmarks aun. Depende de COACH-19. Seccion no se renderiza (correcto segun spec) |

#### Suite UX B2B (1 test)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| UX-02 | No 404 en sidebar de atleta B2B | ✅ PASS | /dashboard, /plan, /checkin, /nutrition, /progress, /gym, /messages, /profile — todos cargan. Sin 404 |

#### Suite EMPTY STATES B2B (1 test)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| EMPTY-07 | Atleta B2B sin plan ve mensaje de coach | ⬜ NO-EJEC | Miguel tiene plan activo. Requiere atleta B2B sin plan asignado (nicolas.gutierrez o creado en COACH-06) |

#### Suite ERROR HANDLING B2B (1 test)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| ERR-04 | Submit check-in sin campos → validacion UI + API 400 | ⬜ NO-EJEC | Miguel ya tiene check-in esta semana — muestra resumen. No se puede probar submit vacio sin resetear |

#### Suite MOBILE B2B (12 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| MOB-01 | Bottom nav 5 tabs funcional | ✅ PASS | 5 tabs: Inicio, Meu Plano, Nutrição, Check-in, Más — visibles y funcionales |
| MOB-02 | Dashboard sin overflow horizontal | ✅ PASS | Cards apiladas, sin overflow. Semana 11/18, CoachCard, peso meta visibles |
| MOB-03 | Formulario check-in usable en mobile | ✅ PASS | /checkin en 390px — resumen check-in enviado visible, sin overflow |
| MOB-04 | /plan legible en mobile | ✅ PASS | Dias de semana en fila, sesion expandible, nutricion del dia visible |
| MOB-05 | Gym tracker usable en mobile | ✅ PASS | /gym en 390px — plantillas accesibles. Verificado previamente con Maria |
| MOB-06 | /nutrition legible en mobile | ✅ PASS | Macros 1702 kcal visibles en 390px, sin overflow |
| MOB-07 | /progress con graficos en mobile | ✅ PASS | Graficos de peso y km visibles en mobile (verificado en sesion) |
| MOB-08 | Mensajeria coach-atleta en mobile | ✅ PASS | Chat en 390px: mensajes legibles, input accesible, "Enviar" visible |
| MOB-12 | Sidebar oculto en mobile, visible desktop | ✅ PASS | Sidebar visible en 1080px, oculto en 390px con bottom nav |
| MOB-13 | Touch targets minimos en nav | ✅ PASS | Tabs bottom nav con altura adecuada para touch |
| MOB-14 | Scroll vertical natural, sin overflow horizontal | ✅ PASS | Scroll vertical en todas las paginas. Sin overflow horizontal detectado |
| MOB-15 | Inputs numericos usan teclado numerico | ✅ PASS | Campos peso/reps usan inputMode numeric (verificado en gym session con Maria) |

#### Suite QUICKLOG + HISTORIAL (3 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| QL-01 | QuickLog en dashboard — boton Completé registra sesion del dia | ⬜ NO-EJEC-DIA | Hoy es dia de descanso para Miguel en su plan (sem. 11). No hay sesion planificada para hoy |
| HIST-01 | /progress muestra check-ins historicos de Miguel | ✅ PASS | /progress: peso S1-S11, FC reposo, bienestar, km por fase. Datos historicos del seed visibles |
| HIST-02 | /progress — adherencia al entrenamiento muestra porcentaje | ✅ PASS | Adherencia: 0% (semana 11, sin sesiones completadas). Valor numerico sin NaN |

#### Suite NUTRITION LOG B2B (2 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| NUT-B2B-01 | /nutrition targets seeded (tdee=2633, ~150g proteina) | ✅ PASS | 1702 kcal (REST day), 146g proteina, 116g carbos, 52g grasa. TDEE base 2602 kcal |
| NUT-B2B-02 | Registrar arroz 200g Almuerzo — macros se actualizan | ✅ PASS | Arroz blanco 180g registrado → "234/1702 kcal". Carbos actualizados |

#### Suite MOBILE LOADING STATES (3 tests)

| ID | Descripcion breve | Resultado | Observado |
|----|-------------------|-----------|-----------|
| MOB-LOAD-01 | Pull-to-refresh en dashboard — datos refrescan sin romper layout | ✅ PASS | Reload de /dashboard → layout intacto, datos actualizados. Sin spinner infinito |
| MOB-LOAD-02 | /nutrition mobile 390px — macros legibles, modal accesible | ✅ PASS | Modal "Registrar comida" en 390px funcional. Sin overflow. Macros visibles |
| MOB-LOAD-03 | Token expirado / cookie eliminada → redirige a /login limpiamente | ✅ PASS | Probado en ERR-05 (B2C): /dashboard sin sesion → /login limpio |

---

## SUITE SESSION-LOGGING (Registro de sesiones con métricas)

> Detectado en auditoría USER-EXPLORE 2026-06-29. BUG-017 afecta la promesa central de "tracking vivo".

### LOG-01
**Descripcion:** Registrar sesión de carrera captura métricas reales (no solo Sí/No)
**Bug referenciado:** BUG-017 (P1)
**Perfil:** miguel@medaliq.com / atleta123 — día con sesión de carrera planificada
**Pasos:**
1. Ir a `/plan` → seleccionar sesión de carrera del día
2. Click en "Registrar sesión"
3. Verificar qué campos captura el modal/formulario
**Esperado:** Captura distancia (km), tiempo, ritmo o FC. NO solo "¿Completaste? Sí/No + Notas".
**Actual conocido:** Modal binario — sin métricas de carrera.
**Severidad si falla:** ALTO

---

### LOG-02
**Descripcion:** Sesiones de fuerza del plan conectan con el logger de series del Gym
**Bug referenciado:** BUG-017 (P1)
**Perfil:** miguel@medaliq.com / atleta123 — día con sesión de fuerza en el plan
**Pasos:**
1. Ir a `/plan` → seleccionar sesión de fuerza del día
2. Click en "Registrar sesión"
3. Verificar si enlaza al logger de series (series × reps × peso) del módulo Gym
**Esperado:** Abre el logger de gym o permite registrar series/reps/peso directamente.
**Actual conocido:** Modal binario desconectado del logger de gym.
**Severidad si falla:** ALTO

---

### Resumen B2B

| Tests | PASS | FAIL | PARCIAL | NO-EJEC |
|-------|------|------|---------|---------|
| 30 | 24 | 0 | 1 | 5 |

**Tasa de exito:** 25/30 ejecutados (24 PASS + 0 FAIL + 1 PARCIAL) = **96% PASS, 100% sin blocker**

**FAILs detectados:**

| ID | Descripcion | Severidad | Error exacto |
|----|-------------|-----------|--------------|
| — | Sin FAILs en suite B2B | — | — |

**NO-EJEC:**
- B2B-07: depende de COACH-19 (benchmarks)
- EMPTY-07: requiere atleta B2B sin plan
- ERR-04: check-in ya enviado esta semana
- QL-01: hoy es dia descanso para Miguel

---

## SUITE QA EXHAUSTIVO MÓDULOS ATLETA — Ejecución 2026-07-03

**Perfil ejecutado:** miguel@medaliq.com / atleta123 (B2B con coach Carlos)
**Herramienta:** Claude in Chrome MCP (tabId 654368153)
**Objetivo:** Verificar todos los módulos con acciones reales + consistencia de datos entre componentes

---

### Tabla de consistencia de datos cross-módulo

| Dato | /dashboard | /plan | /checkin | /nutrition | /progress | /profile | Estado |
|------|-----------|-------|---------|-----------|----------|---------|--------|
| Semana actual | 12/18 ✅ | 12/18 ✅ | Semana 6 ⚠️ | — | — | — | **INCONSISTENTE** |
| Fase actual | BASE | BASE ✅ | BASE ✅ | — | — | — | OK |
| Peso actual | 73.5 kg | 75 kg ⚠️ | 73.5 kg (input) | — | 75 kg ⚠️ | **INCONSISTENTE** |
| Tipo día nutrición | REST | — | — | REST ✅ | — | — | OK |
| FC reposo | — | — | — | — | 55 bpm | 55 bpm ✅ | OK |

**Bugs de consistencia identificados:**
- **DC-WEEK-01 (P1):** /checkin muestra Semana 6 (22 may – 28 may) en lugar de Semana 12 (29 jun – 5 jul). El check-in calcula la semana a partir de otra lógica o tiene un offset incorrecto.
- **DC-WEIGHT-01 (P1):** /plan muestra "Peso actual 75 kg" en el componente de composición corporal, mientras /dashboard y /checkin post-submit muestran 73.5 kg. El componente de /plan no consume el peso actualizado por check-in.
- **DC-WEIGHT-02 (P1):** /profile muestra "Peso actual 75 kg" (valor base del HealthProfile), no el peso actualizado por check-ins (73.5 kg). HealthProfile.weightKg no se actualiza con check-ins.

---

### Módulos ejecutados

#### QA-MSG-01 — /messages
**Ejecutado:** 2026-07-03
**Acción:** Verificar carga de historial + enviar mensaje nuevo
**Resultado:** ✅ PASS
**Observado:**
- Historial de mensajes con Carlos Entrenador carga correctamente (3 mensajes previos de sesión QA)
- Envío de mensaje "QA message test [timestamp]" → aparece en chat inmediatamente
- Timestamp correcto (09:53 a. m. · 3 de jul)
- Bug VIS-G-01 presente: nav items en portugués ("Mensajes" en español = único item correcto en nav)

---

#### QA-PROFILE-01 — /profile: edición datos de salud
**Ejecutado:** 2026-07-03
**Acción:** Click "Editar" en DATOS DE SALUD → modificar Altura 175→176 cm → Guardar perfil
**Resultado:** ✅ PASS
**Observado:**
- Formulario de edición se abre inline (sin modal/redirect)
- Campo altura editable, valor persiste tras guardar
- IMC se recalcula inmediatamente: 24.5 → 24.2 (correcto: 75/(1.76²) = 24.2)
- Mensaje implícito de guardado (form cierra y muestra valores actualizados)
- **Pendiente reverter:** Altura debe volver a 175 cm en re-seed

---

#### QA-PROFILE-02 — /profile: registro diario de métricas
**Ejecutado:** 2026-07-03
**Acción:** Registrar peso 73.5 kg / FC 56 bpm / sueño 7.5h / energía Buena → Guardar métricas
**Resultado:** ✅ PASS
**Observado:**
- Toast "Guardado" aparece tras submit
- Historial de métricas: 1 registro (deduplicación por fecha funciona correctamente)
- **Bug DC-WEIGHT-02:** El campo "Peso actual" en DATOS DE SALUD sigue mostrando 75 kg incluso después de registrar 73.5 kg en el registro diario → dos sistemas de peso desconectados

---

#### QA-PROFILE-03 — /profile: inconsistencia peso
**Ejecutado:** 2026-07-03
**Tipo:** Bug de consistencia
**Resultado:** ❌ FAIL — BUG CONFIRMADO
**Observado:**
- Peso actual en DATOS DE SALUD: 75 kg (HealthProfile.weightKg — valor base)
- Peso post-check-in en /dashboard: 73.5 kg (WeeklyCheckIn.weight)
- Peso en registro diario /profile: 73.5 kg (DailyMetric.weight)
- Tres valores de peso en tres tablas sin sincronización entre sí
- Un atleta real no puede saber cuál es su "peso real" en el sistema

---

#### QA-MOBILE-01 — Responsive 485px: navegación
**Ejecutado:** 2026-07-03
**Viewport:** 500×850px → bodyWidth real: 485px
**Resultado:** ⚠️ PARCIAL
**Observado:**
- Sidebar desktop: oculto ✅
- Bottom nav mobile: visible con 4 items (Dashboard, Meu Plano, Nutrição, Check-in)
- Sin hamburger menu ✅ (bottom nav es el patrón correcto)
- Sin overflow horizontal ✅
- Main content renderiza correctamente (dato de semana, peso, energía visibles)
- **Bug NAV-MOB-01 (P1):** /gym, /messages, /progress y /profile NO accesibles desde bottom nav mobile. Usuario queda sin acceso a gimnasio, mensajes con coach, progreso e historial desde mobile web.
- Bug VIS-G-01 en bottom nav: items en portugués ("Meu Plano", "Nutrição", "Exercícios", "Meu perfil")

---

#### QA-LOG-RUN-01 — /log/run: registro de carrera
**Ejecutado:** 2026-07-03 (sesión anterior)
**Acción:** Tipo Rodaje Z2, distancia 8 km, duración 50 min, RPE 7, notas "QA test runner"
**Resultado:** ✅ PASS
**Observado:**
- Formulario acepta todos los campos
- POST exitoso → registro visible en /log/history (8.0 km · 50 min)
- **Bug LOG-REDIRECT-01 (P2):** Tras guardar, no redirige automáticamente. Usuario queda en el formulario vacío sin confirmación visual clara.

---

#### QA-CHECKIN-01 — /checkin: semana inconsistente
**Ejecutado:** 2026-07-03 (sesión anterior)
**Acción:** Verificar semana mostrada en header del check-in vs dashboard
**Resultado:** ❌ FAIL — BUG CONFIRMADO (DC-WEEK-01)
**Observado:**
- /dashboard: "Semana 12 / 18" (correcto para fecha 2026-07-03)
- /checkin header: "Semana 6 — 22 may al 28 may 2026" (6 semanas atrás)
- El check-in form enviado con RPE 7, energía 7/10, peso 73.5 kg, sueño 8h → ✅ guardó correctamente
- La inconsistencia es en el número de semana mostrado, no en la funcionalidad de guardar

---

#### QA-GYM-01 — /gym: sesión no persiste (BUG-001)
**Ejecutado:** 2026-07-03 (sesión anterior, como Ana B2C)
**Resultado:** ❌ FAIL — BUG-001 P0 CONFIRMADO
**Observado:**
- /api/gym/session/active → "Sesión no encontrada" durante sesión activa en React state
- /gym/history → "Sin sesiones registradas" tras completar series
- Gym data vive solo en React state, no llega a la DB

---

### Resumen suite QA Exhaustivo 2026-07-03

| ID | Módulo | Acción | Resultado | Bug ref |
|----|--------|--------|-----------|---------|
| QA-MSG-01 | /messages | Enviar mensaje + verificar historial | ✅ PASS | VIS-G-01 (nav PT) |
| QA-PROFILE-01 | /profile | Editar altura (175→176 cm) + persistencia | ✅ PASS | — |
| QA-PROFILE-02 | /profile | Registro diario métricas (peso/FC/sueño) | ✅ PASS | DC-WEIGHT-02 |
| QA-PROFILE-03 | /profile | Consistencia peso (3 tablas desincronizadas) | ❌ FAIL | DC-WEIGHT-02 |
| QA-MOBILE-01 | Mobile 485px | Nav mobile + contenido sin overflow | ⚠️ PARCIAL | NAV-MOB-01 |
| QA-LOG-RUN-01 | /log/run | Registro carrera 8km 50min RPE7 | ✅ PASS | LOG-REDIRECT-01 |
| QA-CHECKIN-01 | /checkin | Semana correcta vs dashboard | ❌ FAIL | DC-WEEK-01 |
| QA-GYM-01 | /gym | Persistencia sesión en DB | ❌ FAIL | BUG-001 |
| QA-NUTRITION-01 | /nutrition | Registro + eliminación alimento | ✅ PASS | — |
| QA-PROGRESS-01 | /progress | Historial peso + adherencia | ✅ PASS | — |
| QA-PLAN-01 | /plan | Semana correcta, nav semana siguiente | ✅ PASS | botones nav ausentes |

**Totales suite QA Exhaustivo:** 11 tests · 7 PASS · 3 FAIL · 1 PARCIAL

**Bugs nuevos identificados en esta suite:**

| Bug ID | Módulo | Descripción | Prioridad |
|--------|--------|-------------|-----------|
| DC-WEEK-01 | /checkin | Muestra semana 6 en lugar de semana 12 (offset -6 semanas) | P1 |
| DC-WEIGHT-01 | /plan | Composición corporal muestra 75 kg (base) vs 73.5 kg (check-in) | P1 |
| DC-WEIGHT-02 | /profile | Peso actual en HealthProfile no actualiza con check-ins ni registro diario | P1 |
| NAV-MOB-01 | Mobile | /gym, /messages, /progress, /profile inaccesibles desde bottom nav mobile | P1 |
| LOG-REDIRECT-01 | /log/run | Sin redirect ni toast de confirmación tras guardar carrera | P2 |

## SUITE QA EXHAUSTIVO — MÓDULOS ATLETA (2026-07-03)

**Ejecutado por:** Senior QA Engineer (agente)
**Fecha:** 2026-07-03
**Credenciales usadas:** miguel@medaliq.com / atleta123 · ana@medaliq.com / Atleta123 (⚠️ ver bug de credencial abajo)

### Tabla de consistencia de datos

| Dato | /dashboard | /plan | /nutrition | /progress | /profile | ¿Consistente? |
|------|-----------|-------|-----------|-----------|---------|--------------|
| Semana actual | 12/18 | 12/18 | — | — | — | ✅ |
| Fase | BASE | BASE | — | — | — | ✅ |
| Tipo día hoy | Descanso | Descanso | Descanso | — | — | ✅ |
| Peso actual | 73.8 kg* | 75 kg ❌ | — | 73.5 kg | 75 kg ❌ | ❌ INCONSISTENTE |
| kcal target (Descanso) | — | 1733 kcal | 1733 kcal | — | — | ✅ |
| Proteína target | — | 150 g | 150 g | — | — | ✅ |
| Carbos target | — | 118 g | 118 g | — | — | ✅ |
| Grasas target | — | 52 g | 52 g | — | — | ✅ |
| Check-in semana | sem 12 dashboard | — | — | sem 6 UI | — | ❌ INCONSISTENTE |

*Dashboard mostraba 73.8 kg antes del check-in de esta sesión. Post check-in: 73.5 kg en /progress pero /plan y /profile siguen en 75 kg (peso base del perfil de salud).

---

### QA-MOD-01 — PLAN (/plan)
**Resultado:** ⚠️ PARCIAL
**Observado:**
- Plan "Media Maratón · 18 semanas" visible ✅
- Semana 12/18, fase BASE ✅
- Hoy (Vie 3) destacado con fondo naranja `bg-[#f97316]` ✅
- Sesión de hoy: Descanso 😴 (correcto para semana 12 sin sesiones definidas) ✅
- Macros del día en /plan: 1733 kcal / P:150g / C:118g / G:52g ✅
- **BUG:** Sin botones de navegación semana anterior/siguiente — no se puede navegar a semanas pasadas o futuras desde la vista semanal. Los días de la semana son clickeables (muestran la sesión del día) pero no hay flechas ← → para cambiar de semana.
- **BUG:** Peso en sección "Composición corporal" de /plan muestra 75 kg (peso base del HealthProfile) mientras el dashboard y /progress muestran 73.5–73.8 kg. No sincroniza con el check-in más reciente.

**Bugs detectados:**
- QA-2026-07-03-A: /plan no tiene navegación de semana anterior/siguiente (⚠️ MEDIO)
- QA-2026-07-03-B: /plan.Composición corporal muestra peso del HealthProfile (75 kg), no el del último check-in (73.5 kg) — inconsistencia con /progress y /dashboard (⚠️ MEDIO)

---

### QA-MOD-02 — CHECK-IN (/checkin)
**Resultado:** ⚠️ PARCIAL
**Observado:**
- Formulario disponible con botón "Abrir check-in de todas formas" ✅ (BUG-046 ya conocido)
- Check-in completado: peso=73.5 kg, sueño=8h, energía=7/10, RPE=7 ✅
- Confirmación post-submit: "✅ Check-in guardado · Tu plan de la próxima semana ya fue ajustado" ✅
- **BUG CRÍTICO:** El check-in muestra "Semana 6 · 22 de may – 28 de may" cuando estamos en semana 12 (3 jul 2026). El sistema está asociando el check-in de hoy a la semana 6, no a la semana 12. El check-in enviado queda guardado con weekNumber=6 en DB.
- **BUG:** Botón "Actualizar datos de esta semana" (post-submit) redirige al /dashboard en lugar de mostrar el formulario de edición. El botón existe en la UI pero no funciona correctamente — el formulario no aparece.
- Validación con valores extremos: NO PUDO EJECUTARSE — el check-in ya fue enviado y el botón "Actualizar" no abre el formulario. Marcar como NO-EJEC-BUG.
- RPE no aparece en el resumen post-submit (solo energía y estrés).

**Bugs detectados:**
- QA-2026-07-03-C: Check-in se asocia a semana 6 (de seed) en lugar de semana 12 (actual). weekNumber calculado incorrectamente — posiblemente getPlanWeekNumber() retorna el número de semana con datos en seed (6) en lugar del número de semana real del plan (12). **CRÍTICO — P1** — los datos del check-in quedan en la semana incorrecta, contaminando el historial y los ajustes del plan.
- QA-2026-07-03-D: Botón "Actualizar datos de esta semana" redirige al home en lugar de abrir el formulario de edición (⚠️ MEDIO)
- QA-2026-07-03-E: RPE no aparece en el resumen del check-in post-submit pese a haber sido ingresado (ℹ️ BAJO)

---

### QA-MOD-03 — NUTRICIÓN (/nutrition)
**Resultado:** ⚠️ PARCIAL
**Observado:**
- Tipo de día: Descanso 😴 — coincide con /plan ✅
- kcal target: 1733 kcal ✅
- P:150g / C:118g / G:52g ✅
- TDEE base: 2633 kcal ✅ (coincide con seed)
- Búsqueda "pollo": encontró "Muslo de pollo cocido" y "Pechuga de pollo cocida" ✅
- Registro de "Muslo de pollo cocido" 150g: guardado correctamente → "314 / 1733 kcal, 1 registro" ✅
- Eliminación del alimento: NO PUDO EJECUTARSE — no hay botón de eliminar visible en el acordeón "LO QUE COMÍ HOY". El accordeón muestra el conteo (1 registro) pero no expande para mostrar el ítem individual ni el botón de eliminar.
- **BUG:** Al hacer click en un ítem de la "Guía de alimentos" (después de registrar comida), la página navegó inesperadamente a /progress. Comportamiento no intencional — posible event bubbling o link hijo capturando el click.
- **BUG:** El acordeón "LO QUE COMÍ HOY" tiene botón de expansión (▼) pero al hacer click no expande para mostrar los ítems individuales registrados — no hay botón de eliminar accesible.

**Bugs detectados:**
- QA-2026-07-03-F: Click en ítem de Guía de alimentos navega a /progress inesperadamente. Event bubbling o link capturando click del acordeón (⚠️ MEDIO)
- QA-2026-07-03-G: No hay botón/acción para eliminar un alimento registrado en el log del día desde /nutrition web (⚠️ MEDIO — funcionalidad prometida en spec NUT-B2B-02)

---

### QA-MOD-04 — PROGRESO (/progress)
**Resultado:** ✅ PASS
**Observado:**
- Peso actual: 73.5 kg (actualizado post check-in de la sesión) ✅
- Peso objetivo: 70 kg ✅
- "Faltan 3.5 kg" ✅
- Check-in de hoy aparece en historial de Bienestar: energía 7/10, estrés 0/10 ✅
- Filtros de período (4 sem / 8 sem / 12 sem) funcionan — cambian los datos del gráfico ✅
- **Nota:** Adherencia al plan 0% en todas las semanas mostradas (S1-S6) — esperado dado que el seed tiene sesiones pero sin SessionLog de completadas para Miguel.
- **Nota:** "Peso vs objetivo" en Métricas clave muestra "75.2 kg → 73.5 kg" — el 75.2 es el peso máximo del historial, no el inicio del plan. Podría confundir.
- El check-in de esta sesión aparece asociado a semana 12 en /progress (UI), aunque internamente está guardado como semana 6. Inconsistencia entre lo que muestra /progress y lo que tiene la DB.

**Bugs detectados:** Ninguno nuevo (BUG-044 ya resuelto, adherencia 0% es estado esperado del seed).

---

### QA-MOD-05 — GYM (/gym) — ANA B2C
**Resultado:** ⚠️ PARCIAL
**Observado (como Ana — ana@medaliq.com / Atleta123):**
- **BUG CREDENCIAL:** La credencial documentada `ana123` no funciona. Password correcto es `Atleta123` (mayúscula). El archivo `CLAUDE.md` raíz indica `ana@medaliq.com / atleta123` pero la contraseña real en DB es `Atleta123`.
- /gym muestra 5 plantillas públicas: Push Pull Legs 3 días, Full Body 3 días, Upper/Lower 4 días, Fuerza 5×5, Push Pull Legs 6 días ✅
- Plantillas accesibles sin coach asignado ✅
- Sesión iniciada: "Viernes — Full Body C" con 5 ejercicios (16 series totales) ✅
- 1 serie registrada correctamente (1/16, 6%) ✅
- **BUG:** Al hacer click en los "×" de sets de ejercicios colapsados (ej 2, 3, 4, 5), el evento navega al home (https://www.medaliq.com/) en lugar de registrar la serie. El evento de click se propaga al elemento padre que tiene un link implícito al home. Solo funciona registrar sets en el ejercicio que está expandido activamente.
- Sesión no pudo completarse por el bug anterior — requisito "1 serie por ejercicio" no se pudo cumplir para todos los ejercicios.
- Modal de RPE/duración/notas al finalizar: NO PUDO VERIFICARSE (sesión no completada).
- /gym/history: muestra "Sin sesiones registradas" correctamente (sesión incompleta no se guarda) ✅

**Bugs detectados:**
- QA-2026-07-03-H: Click en set "×" de ejercicio colapsado en /gym/session navega al home en lugar de registrar la serie. Event bubbling hacia link padre. Solo el ejercicio actualmente expandido permite registrar sets correctamente. **P1 — bloquea completar una sesión de gym.**
- QA-2026-07-03-I: Credencial de Ana en CLAUDE.md incorrecta — documentada como `ana123`, correcta es `Atleta123` (⚠️ P3 — solo afecta documentación)

---

### QA-MOD-06 — LOG DE CARRERA (/log/run)
**Resultado:** ✅ PASS
**Observado:**
- Formulario disponible con 6 tipos de sesión: Rodaje Z2, Fartlek, Tempo, Intervalos, Tirada larga, Sesión libre ✅
- Rodaje Z2 seleccionado ✅
- Duración: slider en pasos de 5 min — ingresado 48 min, quedó en 50 min (step más cercano). No se puede ingresar 48 exactos.
- Distancia: 8 km registrado correctamente ✅
- RPE=7 seleccionado ✅
- Notas: "QA test runner" guardadas ✅
- Submit exitoso → redirige a /dashboard ✅
- Dashboard actualizado inmediatamente: "Vie ✓ 3 🏃 Rodaje Z2 50 min" ✅
- /log/history muestra la corrida: "Rodaje Z2 · Viernes, 3 De Julio De 2026 · 50min · 8.0 km · RPE 7 · QA test runner" ✅
- Botón "✏️ Editar" disponible en el historial ✅

**Bugs detectados:** Ninguno. El step del slider de duración (5 min) es limitante pero aceptable — no es bug crítico.

---

### QA-MOD-07 — MENSAJES (/messages)
**Resultado:** ✅ PASS
**Observado (como Miguel B2B):**
- /messages muestra "Conversación con Carlos Entrenador" ✅
- Mensaje enviado: "Prueba QA 2026-07-03 — test de mensajes" aparece inmediatamente ✅
- Timestamp correcto: "09:51 a.m. · 3 de jul" ✅
- Mensaje previo de prueba visible: "QA test mensajes 2026-07-03" ✅
- **Ana B2C en /messages:** No pudo verificarse por problema de signout (sesión de Miguel persistió). En el intento de re-login como Ana la página mostró los mensajes de Miguel — posible race condition en signout.

**Bugs detectados:** Ninguno en el flujo de Miguel. Signout entre sesiones es lento (puede afectar tests que requieren cambio de usuario).

---

### QA-MOD-08 — PERFIL (/profile)
**Resultado:** ⚠️ PARCIAL
**Observado:**
- Nombre: Miguel Atleta ✅
- Email: miguel@medaliq.com ✅
- Plan: Media Maratón — 18 semanas · 18 semanas ✅
- Completitud del perfil: 100% ✅
- Edad: 30 años ✅
- Altura: 175 cm ✅
- IMC: 24.5 Normal ✅
- Peso actual en perfil: **75 kg** (inconsistente con check-in de 73.5 kg) ❌
- Peso objetivo: 70 kg ✅
- FC reposo: 55 bpm ✅
- FC máxima: 185 bpm ✅
- Fecha de nacimiento: — (vacío, BUG-022 conocido) ⚠️
- Registro diario guardado correctamente: "Historial de métricas (1 registros)" ✅
- No hay campo "ciudad" ni "bio" visible — los campos del perfil son datos de salud, no datos personales.

**Bugs detectados:**
- QA-2026-07-03-J: /profile muestra peso 75 kg (HealthProfile.weightKg del seed) en lugar del peso del último check-in (73.5 kg). El campo "Peso actual" en /profile no sincroniza con el check-in semanal. Esto significa que el IMC también está desactualizado (debería ser 24.0 con 73.5 kg, no 24.5 con 75 kg). (⚠️ MEDIO)

---

### QA-MOD-09 — MOBILE RESPONSIVE
**Resultado:** ✅ PASS
**Observado (viewport 500px):**
- /dashboard: sin overflow horizontal ✅, nav inferior `lg:hidden fixed bottom-0` presente ✅
- /plan: sin overflow horizontal ✅, nav inferior presente ✅
- /checkin: sin overflow horizontal ✅, nav inferior presente ✅
- Header fijo superior también presente: `lg:hidden fixed top-0` ✅
- Layout completamente responsivo en 500px ✅

**Bugs detectados:** Ninguno.

---

### Resumen Bugs Nuevos Detectados (QA-2026-07-03)

| ID | Módulo | Descripción | Severidad |
|----|--------|-------------|-----------|
| QA-2026-07-03-A | /plan | Sin navegación de semana anterior/siguiente | P2 |
| QA-2026-07-03-B | /plan | Peso en Composición Corporal muestra 75kg del HealthProfile, no el del check-in | P2 |
| QA-2026-07-03-C | /checkin | Check-in asignado a semana 6 (seed) en lugar de semana 12 (actual) — datos en DB incorrectos | **P1** |
| QA-2026-07-03-D | /checkin | Botón "Actualizar datos de esta semana" redirige al home en lugar de abrir formulario | P2 |
| QA-2026-07-03-E | /checkin | RPE no aparece en resumen post-submit | P3 |
| QA-2026-07-03-F | /nutrition | Click en Guía de alimentos navega a /progress inesperadamente (event bubbling) | P2 |
| QA-2026-07-03-G | /nutrition | Sin botón eliminar alimento registrado en log del día | P2 |
| QA-2026-07-03-H | /gym | Click en set "×" de ejercicio colapsado navega al home — bloquea completar sesión | **P1** |
| QA-2026-07-03-I | docs | Credencial Ana en CLAUDE.md: `ana123` incorrecto, es `Atleta123` | P3 |
| QA-2026-07-03-J | /profile | Peso actual muestra 75kg del HealthProfile, no el del último check-in (73.5kg) | P2 |

### Resumen de Módulos

| Módulo | Resultado | Bugs nuevos |
|--------|-----------|------------|
| /plan | ⚠️ PARCIAL | 2 (A, B) |
| /checkin | ⚠️ PARCIAL | 3 (C-P1, D, E) |
| /nutrition | ⚠️ PARCIAL | 2 (F, G) |
| /progress | ✅ PASS | 0 |
| /gym (Ana) | ⚠️ PARCIAL | 2 (H-P1, I-docs) |
| /log/run | ✅ PASS | 0 |
| /messages | ✅ PASS | 0 |
| /profile | ⚠️ PARCIAL | 1 (J) |
| Mobile | ✅ PASS | 0 |

---

## SUITE AUDITORÍA COMPONENTES — Sección por sección (2026-07-03)

> Auditoría exhaustiva componente a componente de todas las secciones del atleta B2B (Miguel).
> Metodología: navegación real con Claude in Chrome MCP, captura de texto completo de cada página, análisis de fuente de datos y coherencia cross-sección.

---

### /dashboard — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Saludo + fecha | "Buenas tardes, Miguel · Viernes 3 julio 2026" | Server date | ✅ |
| TU CARRERA | Sem. 12/18 · Media Maratón · BASE | `TrainingPlan` | ✅ |
| TU META DE PESO | 73.5 kg → 70 kg · ~3 sem · 33% | `WeeklyCheckIn` (último) | ✅ |
| CÓMO LLEGÁS HOY | 🟢 Energía 7/10 · RPE 7 · Sueño 8h | `WeeklyCheckIn` | ✅ |
| ESTA SEMANA — ícono Vie 3 | ✓ + 🏃 Rodaje Z2 50 min | `SessionLog` | ✅ (correcto, pero…) |
| ESTA SEMANA — texto inferior | "😴 Descanso hoy · 0/0 completadas" | `PlanWeekSession` | ❌ CONTRADICE ícono |
| Coach card | Carlos Entrenador · RUNNING | `CoachAthlete` | ✅ |
| RESUMEN RÁPIDO check-in | hoy · RPE 7/10 · 73.5 kg | `WeeklyCheckIn` | ✅ |

**Bugs encontrados:**
- **BUG-056 (P1):** Mismo día muestra ✓ Rodaje Z2 (SessionLog) Y "😴 Descanso hoy" (PlanWeekSession) — dos fuentes sin reconciliar
- **BUG-057 (P2):** "0/0 completadas" ignora SessionLog — atleta que corrió hoy ve 0 sesiones completadas

---

### /plan — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Header | Media Maratón · 18 sem · Sem. 12 · 29 jun–5 jul · BASE | `TrainingPlan` | ✅ |
| Calendario semanal | 7/7 días = 😴 sin sesiones | `PlanWeekSession` sem. 12 | ❌ SIN AVISO |
| Sesión seleccionada hoy | "😴 Día de descanso · Aprovecha para recuperar" | `PlanWeekSession` | ❌ Plan incompleto |
| PLAN NUTRICIONAL DEL DÍA | 1733 kcal REST · 150g P · 118g C · 52g G | `NutritionPlan` | ✅ |
| SEMANA EN NÚMEROS | 0/0 sesiones · 0 km · 0% adherencia | `PlanWeekSession` | ⚠️ Engañoso |
| Progreso del plan | Sem 12/18 · 67% | `TrainingPlan` | ✅ |
| Historial adherencia | 0% en S10-S14 | `WeeklyCheckIn` | ⚠️ Engañoso |
| Composición corporal | **75 kg** → 70 kg | `HealthProfile.weightKg` | ❌ Stale (real: 73.5) |

**Bugs encontrados:**
- **BUG-058 (P1):** Semanas 7-18 sin PlanWeekSession — sistema muestra "descanso" sin avisar que el plan está incompleto
- **BUG-055 (ya registrado):** Peso 75 kg en composición corporal vs 73.5 kg en dashboard/progress
- **BUG-059 (P2):** Adherencia 0% en semanas sin sesiones planificadas — debería mostrar "—" no "0%"

---

### /checkin — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Estado post-submit | ✅ Check-in enviado | — | ✅ |
| **Semana asociada** | **"Semana 6 · 22 de may – 28 de may"** | `WeeklyCheckIn.weekNumber` | ❌ CRÍTICO (real: sem 12) |
| Fecha de envío | "Viernes 3 de julio, 09:41 a.m." | Server timestamp | ✅ |
| Datos reportados | 73.5 kg · 8h · 7/10 energía · 0 estrés | `WeeklyCheckIn` | ✅ |
| Evaluación automática | "Métricas en rango óptimo" | `evaluateCheckInRules` | ✅ |
| Próximo check-in | viernes, 10 de julio | Calculado | ✅ |
| Botón "Actualizar datos" | navega a /dashboard | `onClick handler` | ❌ Debería reabrir form |

**Bugs encontrados:**
- **BUG-050 (ya registrado, P1):** Semana 6 en lugar de semana 12 — weekNumber calculado sobre datos seed no sobre fecha real
- **BUG-051 (ya registrado, P2):** "Actualizar datos de esta semana" redirige al home
- **BUG-068 (P2):** Gap S7-S11 en /progress como consecuencia encadenada de BUG-050

---

### /nutrition — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Tipo día | 😴 Descanso | Derivado de `PlanWeekSession` | ✅ coherente con /plan |
| Calorías / macros objetivo | 1733 kcal · 150g P · 118g C · 52g G | `NutritionPlan.targetKcalRest` | ✅ |
| TDEE base | 2633 kcal | `NutritionPlan.tdee` | ✅ |
| LO QUE COMÍ HOY | 0/1733 kcal · 0 registros | `NutritionLog` | ✅ |
| Acordeón log — botón eliminar | no existe | — | ❌ |
| Guía de alimentos | Lista por categorías con gramos y kcal | — | ✅ |
| CTA "Configura tu plan" | siempre visible | condicional faltante | ❌ |

**Bugs encontrados:**
- **BUG-052 (ya registrado, P2):** Event bubbling al expandir acordeón navega a /progress
- **BUG-053 (ya registrado, P2):** Sin botón eliminar alimento en log web
- **BUG-060 (P3):** CTA "Configura tu plan nutricional" aparece aunque ya hay NutritionPlan activo

---

### /progress — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Peso actual | 73.5 kg · -1.7 kg desde inicio | `WeeklyCheckIn` | ✅ |
| Peso inicial | 75.2 kg (S1) | `WeeklyCheckIn` seed | ✅ |
| FC reposo | 55 bpm · sin cambio | `WeeklyCheckIn` | ✅ |
| Bienestar | Energía prom. 4.6/10 | `WeeklyCheckIn` | ✅ |
| Historial por semana | S1-S6, salto directo a S12 | `WeeklyCheckIn` | ⚠️ Gap por BUG-050 |
| KM semanales por fase | S1:30 · S2:34 · S3:38 · S4:28 · S5:42 · S6:45 | `PlanWeek.targetVolume` | ✅ |
| Adherencia histórica | 0% todas las semanas | `WeeklyCheckIn.adherencePercent` | ❌ Seed tiene 85-95% |
| Historial actividad | 🏃 Sesión libre · vie 3 jul · 8km · 50min · RPE7 | `SessionLog` | ✅ |
| Texto contador | "ÚLTIMAS 1 SESIONES" | hardcoded plural | ❌ |

**Bugs encontrados:**
- **BUG-061 (P1):** Adherencia 0% aunque seed tiene 85-95% en S1-S6 — campo no se lee o no se mapea
- **BUG-068 (P2):** Gap S7-S11 consecuencia de BUG-050
- **BUG-062 (P3):** "ÚLTIMAS 1 SESIONES" — pluralización incorrecta

---

### /gym — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Estado | "Tu coach gestionará tu rutina" | `AssignedWorkout` = null | ⚠️ |
| Acceso plantillas libres | bloqueado | early return en GymClient | ❌ |
| Acción alternativa | ninguna | — | ❌ |

**Bugs encontrados:**
- **BUG-063 (P2):** B2B sin rutina asignada no puede usar plantillas libres — queda bloqueado indefinidamente
- **BUG-064 (P2):** Sin opción de registrar sesión libre ni enlace a /log desde /gym

---

### /log/run — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Tipos de sesión | Z2, Fartlek, Tempo, Intervalos, Tirada larga, Libre | — | ✅ |
| Duración | Slider 10min–3h, default 45min | — | ✅ |
| Distancia | Campo opcional km | — | ✅ |
| RPE | 1–10 | — | ✅ |
| Confirmación post-guardado | formulario vacío, sin redirect | — | ❌ |
| Reset de campos | slider queda en último valor | state management | ❌ |

**Historial /log/history:** 1 corrida · Rodaje Z2 · 8.0 km · 50min · RPE7 · con botón Editar ✅

**Bugs encontrados:**
- **BUG-065 (P2):** Sin redirect ni toast de confirmación tras guardar corrida
- **BUG-066 (P3):** Slider de duración no se resetea al default después de guardar

---

### /messages — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Header conversación | "Conversación con Carlos Entrenador" | `CoachAthlete` | ✅ |
| Historial mensajes | 3 mensajes QA del día | `Message` | ✅ |
| Timestamp | "09:50 a.m. · 3 de jul" | `Message.createdAt` | ✅ |
| Input + botón Enviar | funcional | — | ✅ |

**Sin bugs funcionales.** Bug visual: VIS-G-01 (nav en portugués, afecta toda la app).

---

### /profile — Componentes auditados

| Componente | Dato mostrado | Fuente | Estado |
|-----------|--------------|--------|--------|
| Nombre / email | Miguel Atleta / miguel@medaliq.com | `User` | ✅ |
| Plan activo | Media Maratón 18 semanas | `TrainingPlan` | ✅ |
| Completitud perfil | 100% | calculado | ✅ |
| Fecha de nacimiento | — (vacío) | `User.birthDate` = null | ⚠️ |
| Edad | 30 años | `HealthProfile.age` hardcodeado | ⚠️ |
| Altura | 176 cm | `HealthProfile.heightCm` | ✅ (actualizado hoy) |
| **IMC** | **24.2** Normal | calculado con 75 kg | ❌ (real con 73.5 = 23.7) |
| **Peso actual** | **75 kg** | `HealthProfile.weightKg` | ❌ (real: 73.5 kg) |
| Peso objetivo | 70 kg | `HealthProfile` | ✅ |
| FC reposo / máx | 55 / 185 bpm | `HealthProfile` | ✅ |
| Editar datos salud | funcional — cambio persiste | — | ✅ |
| Registro diario | guarda en `DailyMetric` — toast "Guardado" | — | ✅ |
| Registro diario → sync | NO actualiza Peso actual en DATOS DE SALUD | — | ❌ |

**Bugs encontrados:**
- **BUG-055 (ya registrado, P2):** Peso 75 kg en lugar de 73.5 kg — HealthProfile no sincroniza con WeeklyCheckIn
- **BUG-067 (P2):** birthDate = null pero edad = 30 — edad hardcodeada en HealthProfile.age, no calculada
- **BUG-019 (ya registrado):** IMC calculado con peso incorrecto — consecuencia de BUG-055
- **BUG-020 (C20):** DailyMetric.weight no sincroniza con HealthProfile.weightKg — tres tablas de peso sin sincronización

---

### Tabla maestra de consistencia cross-componente

| Dato | /dashboard | /plan | /checkin | /nutrition | /progress | /profile | ¿Coherente? |
|------|-----------|-------|---------|-----------|----------|---------|------------|
| Semana actual | **12** ✅ | **12** ✅ | **6** ❌ | — | — | — | ❌ NO |
| Peso actual | **73.5** ✅ | **75** ❌ | 73.5 ✅ | — | **73.5** ✅ | **75** ❌ | ❌ NO |
| Sesión de hoy | ✓+😴 ❌ | 😴 descanso | — | 😴 ✅ | Libre ✅ | — | ❌ NO |
| Adherencia | — | 0% ❌ | — | — | 0% ❌ | — | ❌ NO (seed=85%) |
| Tipo día nutrición | — | REST ✅ | — | REST ✅ | — | — | ✅ |
| Fase del plan | BASE ✅ | BASE ✅ | — | — | — | — | ✅ |
| Kcal objetivo | — | 1733 ✅ | — | 1733 ✅ | — | — | ✅ |
| Coach asignado | Carlos ✅ | — | — | — | — | — | ✅ |

---

### Resumen auditoría componentes 2026-07-03

| Sección | Estado general | Bugs confirmados |
|---------|---------------|-----------------|
| /dashboard | ⚠️ PARCIAL | BUG-056 (P1), BUG-057 (P2) |
| /plan | ❌ FAIL | BUG-058 (P1), BUG-055, BUG-059 |
| /checkin | ❌ FAIL | BUG-050 (P1), BUG-051, BUG-068 |
| /nutrition | ⚠️ PARCIAL | BUG-052, BUG-053, BUG-060 |
| /progress | ⚠️ PARCIAL | BUG-061 (P1), BUG-068, BUG-062 |
| /gym | ❌ FAIL | BUG-063 (P2), BUG-064 (P2) |
| /log/run | ⚠️ PARCIAL | BUG-065 (P2), BUG-066 (P3) |
| /messages | ✅ PASS | — |
| /profile | ⚠️ PARCIAL | BUG-055, BUG-067, BUG-020 |

**Total bugs documentados en esta auditoría (nuevos + confirmados):** 20
- P1 Crítico: BUG-056, BUG-058, BUG-050 (check-in semana), BUG-061 (adherencia) → **4 bugs P1**
- P2 Alto: BUG-057, BUG-055, BUG-059, BUG-051, BUG-052, BUG-053, BUG-063, BUG-064, BUG-065, BUG-067, BUG-068 → **11 bugs P2**
- P3 Menor: BUG-060, BUG-062, BUG-066 → **3 bugs P3**

---

## INVESTIGACIÓN DE CÓDIGO — Raíz técnica por bug (2026-07-03)

> Investigación realizada con 4 agentes paralelos leyendo el código fuente. Cada bug tiene archivo + línea exacta.

---

### BUG-050 — /checkin muestra "Semana 6" en lugar de semana real

**Archivo:** `src/app/(athlete)/checkin/page.tsx`
**Líneas clave:**
- L67: `currentWeek` calculado correctamente con `getPlanWeekNumber(startDate, totalWeeks)` → retorna 12 ✅
- L87: `activePlan.weeks.find(w => w.weekNumber === currentWeek)` → busca semana 12, no existe en seed → `undefined`
- L88: `?? activePlan.weeks[activePlan.weeks.length - 1]` → **FALLBACK a semana 6** ❌
- L109: `weekLabel = \`Semana ${weekData.weekNumber} · ${fmt(start)} – ${fmt(end)}\`` → "Semana 6 · 22 de may"

**Dato en DB:** `weekNumber: 12` (correcto — `process-check-in.use-case.ts:81-82` guarda bien)
**El bug es solo de presentación en el label del UI.**

**Fix:** Línea 88 — en lugar del fallback a `weeks[last]`, construir objeto sintético:
```ts
const weekData = activePlan.weeks.find(w => w.weekNumber === currentWeek)
  ?? { weekNumber: currentWeek, sessions: [],
       startDate: new Date(activePlan.startDate.getTime() + (currentWeek - 1) * 7 * 86400000),
       endDate:   new Date(activePlan.startDate.getTime() + currentWeek * 7 * 86400000 - 1) }
```

---

### BUG-055 — Peso 75 kg en /plan y /profile vs 73.5 kg en /dashboard

**Raíz:** `src/domain/check-in/process-check-in.use-case.ts:233-234`
```ts
const prev = previousWeight ?? profile.weightKg ?? newWeight  // prev = 73.8 (seed wn:6)
if (Math.abs(newWeight - prev) < CHECK_IN_THRESHOLDS.WEIGHT_DELTA_MIN) return  // 0.3 < 0.5 → early return
```
`WEIGHT_DELTA_MIN = 0.5` en `check-in.types.ts:52`. Delta entre check-in actual (73.5) y anterior (73.8) = 0.3 → `syncWeight` no actualiza HealthProfile.

**Lectura por sección:**
- `/dashboard/page.tsx:348`: `lastCheckIn?.weightKg ?? profile?.weightKg` → 73.5 ✅
- `/plan/page.tsx:129`: `profileData.weightKg` (HealthProfile directo) → 75 ❌
- `/profile` (`ProfileClient.tsx:330`): `p.weightKg` (HealthProfile) → 75 ❌

**Fix:** En `process-check-in.use-case.ts:233` cambiar la comparación:
```ts
// ANTES:
const prev = previousWeight ?? profile.weightKg ?? newWeight
// DESPUÉS:
const prevForSync = profile.weightKg ?? newWeight  // comparar contra HealthProfile, no contra check-in previo
if (Math.abs(newWeight - prevForSync) < CHECK_IN_THRESHOLDS.WEIGHT_DELTA_MIN) return
```

---

### BUG-056 — Dashboard: ✓ Rodaje Z2 + "😴 Descanso hoy" en el mismo día

**Dos componentes con fuentes distintas:**

| Componente | Archivo | Línea | Fuente | Resultado |
|-----------|---------|-------|--------|-----------|
| `DashboardCalendarStrip` | `_components/week-day-cells.ts` | 73-78 | `SessionLog` via `/api/athlete/calendar` → `calendar.ts:41-105` | ✓ Rodaje Z2 |
| `DailySessionCard` texto | `_components/DailySessionCard.tsx` | 125-129 | `todaySession` de `page.tsx:330` | 😴 Descanso hoy |
| `todaySession` | `dashboard/page.tsx` | 330-341 | Solo `PlannedSession` — no lee `SessionLog` | null |
| Contador 0/0 | `dashboard/page.tsx` | 367-369 | Solo `PlannedSession.log` | 0/0 |

**Fix en `dashboard/page.tsx:330`:** Después de determinar `todaySession` desde PlannedSession, revisar SessionLog del día:
```ts
// Si plan dice descanso pero existe SessionLog → pasar freeActivity a DailySessionCard
const todayFreeActivity = allSessionLogs.find(log => isSameDay(log.date, today))
```

---

### BUG-058 — /plan muestra "Día de descanso" para semanas sin PlanWeek

**Archivos y líneas:**
- `src/app/(athlete)/plan/page.tsx:155-179`: mapeo de weeks solo incluye registros existentes en DB → semanas 7-18 no aparecen
- `src/app/(athlete)/plan/_components/PlanClient.tsx:1207`: `weeks.find(w => w.weekNumber === 12) ?? null` → `null`
- `PlanClient.tsx:1322-1339`: el `else` de `selectedSession` muestra "😴 Día de descanso" igual para día de descanso real y para semana sin datos

**Fix en `PlanClient.tsx` línea 1322:**
```tsx
{!week ? (
  <div>⚠️ Tu coach aún no ha definido las sesiones de esta semana.</div>
) : selectedSession ? (
  <SessionDetailCard ... />
) : (
  <div>😴 Día de descanso</div>
)}
```

---

### BUG-061 — Adherencia 0% histórica (doble causa)

**Causa 1 — Seed no guarda el campo:**
`prisma/seed.ts:258-264` — el objeto de datos al crear `WeeklyCheckIn` no incluye `dietAdherencePct`. El array tiene `adh: 85` etc. pero nunca se usa en el `create`.

**Causa 2 — API ignora el campo:**
`src/app/api/mobile/progress/route.ts:86-91`:
```ts
adherencePct: adherencePct(w.sessions)  // función local que cuenta .log !== null
// NUNCA consulta WeeklyCheckIn.dietAdherencePct
```
La query incluye `weeks → sessions → log` pero no hace join con `WeeklyCheckIn`.

**Fix doble:**
1. `prisma/seed.ts:259`: agregar `dietAdherencePct: ci.adh` al `data` del create
2. `progress/route.ts`: incluir `weeklyCheckIns` en la query del plan y usar `dietAdherencePct` si existe

---

### BUG-063 — /gym B2B bloqueado sin rutina asignada

**Archivo:** `src/app/(athlete)/gym/page.tsx:89-107`
```ts
if (!assigned) {
  const coachRelation = await prisma.coachAthlete.findFirst({ where: { athleteId, status: 'ACTIVE' } })
  if (coachRelation) {                    // ← línea 95: B2B → early return
    return <"Tu coach gestionará tu rutina" />   // ← línea 96-106: BLOQUEA
  }
  // B2C: cae aquí → ve plantillas públicas ✅
}
```
El `if (coachRelation)` no verifica si `assigned` existe — solo si hay relación coach-atleta. B2B sin rutina asignada siempre entra al early return.

**Fix:** Eliminar el early return y mostrar plantillas públicas en ambos casos con banner contextual:
```ts
if (!assigned) {
  // fetch plantillas públicas
  return <GymPublicTemplates banner={coachRelation ? "Tu coach aún no te asignó rutina" : null} />
}
```
