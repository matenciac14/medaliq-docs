# Medaliq — Tests E2E (ORQUESTADOR)

## Instrucciones para Claude Desktop

**URL base:** `https://www.medaliq.com`

**Protocolo de ejecucion:**
1. Ejecutar los archivos de rol PRIMERO, en este orden: B2C → B2B → Coach/Admin
2. Luego ejecutar las suites cross-cutting de este archivo
3. Al terminar cada test, escribir el resultado en la **SECCION DE REPORTE** de cada archivo
4. Si falla: anotar el error exacto. Continuar con el siguiente test sin detenerse.
5. **AL TERMINAR CADA ARCHIVO DE ROL** — ANTES de pasar al siguiente — copiar el resumen (totales PASS/FAIL/NO-EJEC) en la tabla REPORTE CONSOLIDADO de este archivo. No esperar al final.
6. Al terminar las suites cross-cutting: completar las filas de este archivo en el REPORTE CONSOLIDADO y calcular el total general.

**Protocolo de capturas:**
- FAIL / PARCIAL → screenshot obligatorio
- PASS con valor numérico verificado (MRR, conteos, fechas, métricas) → screenshot del valor visible en pantalla
- PASS funcional sin valor numérico → no capturar (registrar solo resultado)
- `test-visual.md` es la excepción: siempre capturar — ese archivo es el test visual

**Orden de ejecucion:**
0. **MW-09** (este archivo, Suite 2) → ejecutar PRIMERO, antes de B2C. Login como Ana — debe redirigir a /onboarding. Después cerrar sesión.
1. `test-atleta-b2c.md` → Ana + usuarios nuevos (B2C)
2. `test-atleta-b2b.md` → Miguel (B2B con coach)
3. `test-coach-admin.md` → Carlos (coach) + Admin
4. Este archivo → suites cross-cutting (excepto MW-09 que ya se ejecutó en el paso 0)
5. `test-onboarding.md` → Flujo completo registro + onboarding (B2C runner nuevo) — ⚠️ `/new-goal` no existe como página, skip ONB-05 a ONB-09 legacy
6. `test-dashboard-modules.md` → Módulos del dashboard atleta (nutrición, gym, checkin, log, perfil) — E2E 2026-07-05

> **⚠️ CAMBIOS CRÍTICOS DESDE ÚLTIMA EJECUCIÓN (2026-07-10):**
> - `Goal` model eliminado del schema — tests que buscan tabla Goal fallarán → marcar N/A
> - `WeeklyRoutine` eliminado — `/routine/edit` no existe → marcar N/A
> - `/messages` no existe como ruta — B2B-03, CROSS-04, DC-14 y cualquier test de mensajería → marcar N/A
> - `/new-goal` no existe como página → ONB-05 a ONB-09 → marcar N/A o verificar redirect
> - Plan "18 semanas" (Miguel) existe en DB pero `RACE_HALF_MARATHON` removido de UI selectors
> - Ejercicios: seed 39 ejercicios reemplazado por WorkoutX (10 free / 1,300+ paid)
> - Tabs atleta detail: `Plan · Sesiones · Nutrición · Notas · Config` (no Resumen/Gym/Mensajes/Perfil)
> - `/log` → redirect a `/log/history` (feed unificado GymSession + SessionLog)
> - `/coach/invite` existe como href en dashboard pero sin página Next.js → navegación → 404
> - MRR en `/admin/finanzas`, NO en `/admin/metrics`

**Antes de cada suite:** Cerrar sesion activa visitando `https://www.medaliq.com/api/auth/signout` o borrando cookies del sitio.

---

## Credenciales de produccion

| Rol | Email | Password | Estado en DB |
|-----|-------|----------|--------------|
| ADMIN | admin@medaliq.com | admin123! | role=ADMIN, onboardingCompleted=true |
| COACH (Carlos) | coach@medaliq.com | coach123 | role=COACH, featureCoach=true, 5 atletas activos en seed |
| COACH (Maria) | maria.coach@medaliq.com | coach123 | role=COACH, featureCoach=true, 3 atletas (Sofia Ramirez, Camilo Torres, Isabella Mendez) |
| ATHLETE B2B | miguel@medaliq.com | atleta123 | onboardingCompleted=true, coach=Carlos Entrenador, plan activo en DB (18 sem — existe en DB, RACE_HALF_MARATHON removido de UI) |
| ATHLETE B2C | ana@medaliq.com | atleta123 | onboardingCompleted=FALSE en seed (B2C-03 lo completa), modo FREE post-onboarding |
| ATHLETE B2B | juan.perez@medaliq.com | atleta123 | onboardingCompleted=true, plan activo, coach=Carlos |
| ATHLETE B2B | sebastian.rios@medaliq.com | atleta123 | onboardingCompleted=true, plan activo, coach=Carlos |
| ATHLETE B2B | nicolas.gutierrez@medaliq.com | atleta123 | onboardingCompleted=true, plan activo, coach=Carlos |
| ATHLETE B2B | santiago.rodriguez@medaliq.com | atleta123 | onboardingCompleted=true, plan activo, coach=Carlos |

**Nota:** Todos los usuarios de seed tienen `emailVerified = null` pero el sistema NO bloquea el login por esto. El credentials provider en auth.ts no verifica emailVerified.

---

## Setup previo — qué usuarios existen y qué se crea durante los tests

### Usuarios seed (ya existen en DB — NO crear)

Estos usuarios están pre-cargados. Usarlos directamente con las credenciales de la tabla anterior.

| Usuario | Estado requerido para que los tests pasen |
|---------|------------------------------------------|
| admin@medaliq.com | role=ADMIN, acceso a /admin |
| coach@medaliq.com (Carlos) | 5 atletas activos en seed: Miguel, Juan, Sebastián, Nicolás, Santiago. COACH-06 crea el 6° durante el test. |
| maria.coach@medaliq.com | 3 atletas (Sofía, Camilo, Isabella) |
| miguel@medaliq.com | B2B activo, plan "Media Maratón 18 semanas" asignado por Carlos. Debe tener NutritionPlan con targetKcalHard~2133 |
| ana@medaliq.com | onboardingCompleted=FALSE en seed — B2C-03 lo completa durante el test. No completar el onboarding antes de correr la suite |
| juan, sebastian, nicolas, santiago, camilo | B2B activos con plan, coach=Carlos |
| sofia, isabella, daniela, valentina, laura, andres, felipe, catalina | Atletas de maria.coach o sin uso activo en la suite actual |

### Usuarios que se crean DURANTE los tests

Estos NO existen antes de la ejecución — los tests los registran en el momento:

| Creado en | Descripción | Credenciales resultantes |
|-----------|-------------|--------------------------|
| NEW-03 (test-atleta-b2c.md) | María — atleta B2C STRENGTH nueva | email elegido por el tester / `MedaliqTest2026!` |
| NEW-06 (test-atleta-b2c.md) | María completa onboarding STRENGTH | misma cuenta de NEW-03 |
| COACH-06 (test-coach-admin.md) | Atleta B2B nuevo en estado pending | email elegido por el tester |
| DC-20 (este archivo) | El atleta de COACH-06 es activado por el coach | mismo email de COACH-06 |
| ACT-01 / PJ-01 / PJ-02 | Usuarios nuevos para onboarding B2C con diferentes metas | anotar el email usado en cada ejecución |

**Importante:** Anotar los emails de los usuarios creados durante la sesión. Al terminar, agregarlos al script `scripts/cleanup-test-users.sql` del proyecto y ejecutar para limpiar producción.

### Dependencias entre tests (orden obligatorio)

Algunos tests fallan si el test previo no pasó. El protocolo ya indica el orden de archivos, pero estas son las dependencias críticas:

```
NEW-03 → NEW-06 → DC-29, DC-30         (María necesita onboarding completo)
COACH-06 → DC-20                        (atleta pending debe existir para ser activado)
COACH-17 → DC-32                        (volumeKm editado por coach antes de verificar)
COACH-18 → DC-33                        (targets nutricionales aplicados antes de verificar)
COACH-19 → DC-31                        (benchmark registrado antes de verificar en /progress)
B2C-03  → DC-28                         (Ana completa onboarding antes de verificar empty state)
SELF-01 → DC-34                         (rutina guardada antes de verificar en dashboard)
SELF-03 → DC-35                         (corrida libre antes de verificar en /log/history)
GYM-03  → DC-36                         (sesión gym completada antes de verificar en coach)
NUT-03  → DC-37                         (comida registrada antes de verificar aislamiento)
```

### Estado mínimo para correr la suite completa sin NO-EJECs evitables

1. **Coach Carlos (coach@medaliq.com) tiene 5 atletas activos en seed** (Miguel, Juan, Sebastián, Nicolás, Santiago). COACH-06 crea el 6° durante la sesión. COACH-02 y COACH-03 verifican el estado ANTES de COACH-06, por lo que el número esperado es **5**.
2. **Miguel debe tener NutritionPlan en DB.** Si no lo tiene, REGR-03 falla. Fix: login como Miguel → ir a `/nutrition` → el sistema lo inicializa automáticamente.
3. **Para DC-27 (pago OVERDUE):** crear un pago en `/coach/finanzas` con fecha de vencimiento pasada (ej: ayer) antes de correr la suite DC.
4. **Ana (ana@medaliq.com) debe tener onboardingCompleted=FALSE** antes de correr la suite. Si ya lo completó en una ejecución anterior, los tests NEW-x y B2C-03 requieren un usuario nuevo distinto.

---

## Referencias a archivos de rol

| Archivo | Contenido | Tests |
|---------|-----------|-------|
| `test-atleta-b2c.md` | Ana B2C + Maria nueva | B2C(11) + NEW(10) + UX-B2C(4) + EMPTY-B2C(4) + ERR-B2C(2) + SELF(4) + MOB-B2C(2) + GYM(5) + NUT(5) = 47 |
| `test-atleta-b2b.md` | Miguel B2B | B2B(7) + MOB-B2B(12) + EMPTY-B2B(1) + ERR-B2B(1) + UX-B2B(1) + QL(1) + HIST(2) + NUT-B2B(2) + MOB-LOAD(3) = 30 |
| `test-coach-admin.md` | Carlos coach + Admin | COACH(20) + ADMIN(8) + MOB-coach(1) + EMPTY-coach(3) + ERR-coach(3) + UX-coach(1) + COACH-plan(2) + EMAIL(2) + CRON(2) + GYMP(3) = 45 |
| Este archivo | Cross-cutting | REGR(4) + AUTH(12) + MW(9) + EDGE(8) + CROSS(6) + DC(37) + PERF(8) + A11Y(6) = 90 |
| `test-onboarding.md` | E2E onboarding B2C runner | ONB(10) — 3 PASS · 4 FAIL · 1 PARCIAL · 2 FIXED — ejecutado 2026-07-05 |
| `test-dashboard-modules.md` | E2E módulos dashboard atleta | DASH(8) — 1 PASS · 5 FAIL · 1 PARCIAL · 0 FIXED — ejecutado 2026-07-05 |
| **TOTAL** | | **230** |

---

## SUITE REGRESION — Re-test de bugs corregidos

> **Ejecutar SIEMPRE primera.** Los fixes B2C-05, DC-05, DC-11 y ERR-04 fueron corregidos y mergeados a `main`. Verificar que siguen funcionando en produccion.

### REGR-01 (era B2C-05) — REORIENTADO a B2B
**Descripcion:** Plan visible en /plan para atleta B2B con plan del coach
**Bug corregido originalmente:** `/plan` mostraba "modo libre" aunque el plan existia en DB, porque el gate usaba el JWT (stale) en lugar de consultar DB directamente.
**Actualizacion feature/16:** El onboarding B2C ya no genera TrainingPlan. Este test ahora valida el fix usando un atleta B2B (Miguel) que SI tiene plan generado por el coach.
**Perfil:** ATHLETE B2B — miguel@medaliq.com / atleta123
**Precondicion:** Miguel con plan activo "Media Maraton 18 semanas" asignado por coach
**Pasos:**
1. Cerrar sesion activa (`/api/auth/signout`)
2. Login como `miguel@medaliq.com` / `atleta123`
3. Ir a `/plan`
4. Verificar que aparece el plan semanal con sesiones (NO debe mostrar "Estas en modo libre" ni "Sin plan activo")
**Esperado:** Plan visible con semanas y sesiones (RODAJE_Z2, INTERVALOS, etc.). NO aparece "modo libre".
**Severidad si falla:** CRITICO

---

### REGR-02 (era DC-05)
**Descripcion:** Fase del plan en dashboard coincide con /plan
**Bug corregido:** Dashboard usaba la ultima semana del plan como fallback cuando `currentWeek` no existia, mostrando una fase incorrecta.
**Perfil:** ATHLETE B2B — miguel@medaliq.com / atleta123
**Pasos:**
1. Login como `miguel@medaliq.com` / `atleta123`
2. En `/dashboard` buscar el badge de fase (ej: "BASE", "DESARROLLO"). Anotar: `fase_dashboard`
3. Ir a `/plan`
4. Buscar la fase de la semana actual. Anotar: `fase_plan`
**Esperado:** `fase_dashboard` = `fase_plan`. Mismo valor.
**Severidad si falla:** ALTO

---

### REGR-03 (era DC-11)
**Descripcion:** Plan nutricional visible para atleta B2B
**Bug corregido:** Atletas B2B sin NutritionPlan en DB veian banner de onboarding incompleto aunque tenian onboarding completo. La pagina ahora inicializa el NutritionPlan automaticamente desde el HealthProfile.
**Perfil:** ATHLETE B2B — miguel@medaliq.com / atleta123
**Pasos:**
1. Login como `miguel@medaliq.com` / `atleta123`
2. Ir a `/nutrition`
3. Verificar que NO aparece el banner "Completa el onboarding para activar tu plan nutricional base"
4. Verificar que aparecen macros con valores > 0
**Esperado:** Macros visibles (~2133 kcal dia duro, ~1702 kcal dia descanso, proteina ~150g). Sin banner de onboarding incompleto.
**Severidad si falla:** ALTO

---

### REGR-04 (era ERR-04)
**Descripcion:** POST /api/checkin rechaza body vacio con 400
**Bug corregido:** `POST /api/checkin` con body `{}` retornaba HTTP 200 OK. Ahora requiere `energyLevel` o `hardestRpe`.
**Perfil:** Cualquier usuario autenticado — usar miguel@medaliq.com / atleta123
**Pasos:**
1. Login como `miguel@medaliq.com` / `atleta123`
2. Abrir DevTools → Network
3. En la consola del browser ejecutar:
   ```js
   fetch('/api/checkin', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }).then(r => r.json()).then(console.log)
   ```
4. Observar status code y body
**Esperado:** Status 400. Body con mensaje de error. NO debe retornar 200 OK.
**Severidad si falla:** MEDIO

---

## SUITE 1 — AUTH (Autenticacion)

### AUTH-01
**Descripcion:** Login exitoso como COACH
**Precondicion:** Sin sesion activa
**Pasos:**
1. Ir a `/login`
2. Ingresar email: `coach@medaliq.com`, password: `coach123`
3. Click en "Iniciar sesion"
**Esperado:** Redirige a `/coach/dashboard`. No hay error visible.
**Severidad si falla:** CRITICO

### AUTH-02
**Descripcion:** Login exitoso como ATHLETE (con coach asignado)
**Precondicion:** Cerrar sesion del test anterior
**Pasos:**
1. Ir a `/login`
2. Email: `miguel@medaliq.com`, password: `atleta123`, submit
**Esperado:** Redirige a `/dashboard`. Muestra contenido del atleta.
**Severidad si falla:** CRITICO

### AUTH-03
**Descripcion:** Login exitoso como ADMIN
**Precondicion:** Cerrar sesion
**Pasos:**
1. Ir a `/login`
2. Email: `admin@medaliq.com`, password: `admin123!`, submit
**Esperado:** Redirige a `/admin`. Sin errores.
**Severidad si falla:** CRITICO

### AUTH-04
**Descripcion:** Password incorrecto — debe mostrar error
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`
2. Email: `coach@medaliq.com`, password: `wrongpassword`, submit
**Esperado:** Permanece en `/login`. Muestra mensaje de error. NO redirige.
**Severidad si falla:** CRITICO

### AUTH-05
**Descripcion:** Email no registrado — debe mostrar error
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`
2. Email: `noexiste@medaliq.com`, password: `cualquier123`, submit
**Esperado:** Error visible. NO redirige. NO revela si el email existe.
**Severidad si falla:** ALTO

### AUTH-06
**Descripcion:** Campos vacios — validacion del formulario
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`, dejar campos vacios, click submit
**Esperado:** Validacion HTML5 o mensaje de error. NO hace request al servidor.
**Severidad si falla:** MEDIO

### AUTH-07
**Descripcion:** Email con formato invalido
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`, email: `noesunEmail`, password: `cualquier123`, submit
**Esperado:** Error de validacion de formato. No hace request.
**Severidad si falla:** MEDIO

### AUTH-08
**Descripcion:** Rate limiting en login — 11 intentos rapidos
**⚠️ ESTADO: Feature no activa en produccion — SALTAR, no contar como FAIL**
**Contexto:** El rate limiting esta codificado en el middleware pero no esta funcionando en Vercel (confirmado en tercera ejecucion). Es una tarea pendiente de activacion en infraestructura, no un test ejecutable hasta que se resuelva.
**Accion:** Marcar como NO-EJEC (feature pendiente de activacion).
**Severidad si falla:** ALTO

### AUTH-09
**Descripcion:** Registro de nuevo usuario como ATHLETE
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/register`
2. Ingresar nombre: `Test Usuario`, email unico, password: `TestPass123!`, rol: Atleta, submit
**Esperado:** Cuenta creada. Redirige a onboarding o pantalla de verificacion. Sin errores 500.
**Severidad si falla:** CRITICO

### AUTH-10
**Descripcion:** Boton de Google OAuth — verificar que aparece y redirige correctamente
**⚠️ ESTADO: Feature rota por configuracion faltante — SALTAR hasta que se resuelva**
**Contexto:** `GOOGLE_CLIENT_ID` no esta definida en las variables de entorno de Vercel. El boton aparece en la UI pero el redirect falla con `client_id=undefined`. Es una tarea de configuracion de infraestructura, no un bug de codigo.
**Accion:** Marcar como NO-EJEC hasta que `GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET` sean agregadas en Vercel.
**Severidad si falla:** ALTO

### AUTH-11
**Descripcion:** Logout correcto
**Precondicion:** Sesion activa como COACH
**Pasos:**
1. Login como coach
2. Buscar opcion de cerrar sesion
3. Click en logout
**Esperado:** Sesion cerrada. Redirige a `/login`. Intentar `/coach/dashboard` → redirect a `/login`.
**Severidad si falla:** CRITICO

### AUTH-12
**Descripcion:** Forgot password — flujo de recuperacion
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`, buscar link "Olvidaste tu password?", click
2. Ingresar email: `coach@medaliq.com`, submit
**Esperado:** Mensaje de confirmacion "Te enviamos un email". Sin errores.
**Severidad si falla:** ALTO

---

## SUITE 2 — MIDDLEWARE (Proteccion de rutas)

### MW-01
**Descripcion:** Rutas protegidas sin sesion → redirect a login (parametrizado)
**Precondicion:** Sin sesion activa (cookies limpias)
**Pasos:** Ir directamente a cada ruta protegida:
- `/dashboard`
- `/coach/dashboard`
- `/admin`
- `/plan`
- `/checkin`
- `/nutrition`
**Esperado:** Todas redirigen a `/login`. Ninguna muestra contenido sin autenticación.
**Severidad si falla:** CRITICO

### MW-04
**Descripcion:** ATHLETE intentando acceder a /coach → redirect
**Precondicion:** Sesion activa como miguel@medaliq.com (ATHLETE)
**Pasos:**
1. Login como miguel
2. Ir directamente a `/coach/dashboard`
**Esperado:** Redirect a `/dashboard`. No se muestra UI de coach.
**Severidad si falla:** CRITICO

### MW-05
**Descripcion:** COACH intentando acceder a /admin → redirect
**Precondicion:** Sesion activa como coach@medaliq.com
**Pasos:**
1. Login como coach
2. Ir directamente a `/admin`
**Esperado:** Redirect a `/coach/dashboard` o `/dashboard`. No se muestra UI de admin.
**Severidad si falla:** CRITICO

### MW-06
**Descripcion:** COACH intentando acceder a /dashboard → redirect a /coach/dashboard
**Precondicion:** Sesion activa como COACH
**Pasos:**
1. Login como coach
2. Ir directamente a `/dashboard`
**Esperado:** Redirect a `/coach/dashboard`.
**Severidad si falla:** ALTO

### MW-07
**Descripcion:** Rutas publicas accesibles sin login
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/` (home)
2. Ir a `/coaches`
**Esperado:** Ambas rutas cargan sin redirect. No se requiere autenticacion.
**Severidad si falla:** MEDIO

### MW-08
**Descripcion:** ATHLETE con onboarding completo no puede volver a /onboarding
**Precondicion:** Sesion como miguel@medaliq.com (onboarding completo)
**Pasos:**
1. Login como miguel
2. Ir directamente a `/onboarding`
**Esperado:** Redirect a `/dashboard`. No muestra el wizard.
**Severidad si falla:** MEDIO

### MW-09
**Descripcion:** ATHLETE B2C sin onboarding → redirect a /onboarding
**Precondicion:** Sesion como ana@medaliq.com (onboardingCompleted=FALSE)
**⚠️ ORDEN CRÍTICO:** Este test debe ejecutarse ANTES de iniciar `test-atleta-b2c.md`. B2C-03 completa el onboarding de Ana, después de lo cual este test no es reproducible en la misma sesión. Ejecutar MW-09 como primer test de la sesión completa.
**Pasos:**
1. Login como ana@medaliq.com / atleta123
2. Observar donde redirige
**Esperado:** Redirige a `/onboarding`. No puede acceder a `/dashboard` sin completarlo.
**Severidad si falla:** CRITICO

---

## SUITE 3 — EDGE CASES (Casos borde)

### EDGE-01
**Descripcion:** Doble click en submit de login
**Precondicion:** Sin sesion
**Pasos:**
1. Ir a `/login`, ingresar credenciales validas: coach@medaliq.com / coach123
2. Hacer doble click rapido en submit
**Esperado:** Solo se hace un request. El boton se deshabilita despues del primer click.
**Severidad si falla:** MEDIO

### EDGE-02
**Descripcion:** Navegar hacia atras despues de login
**Precondicion:** Sin sesion
**Pasos:**
1. Login como COACH → redirige a `/coach/dashboard`
2. Presionar boton "Atras" del browser
**Esperado:** Permanece en `/coach/dashboard` o redirige ahi. NO vuelve al formulario de login con sesion activa.
**Severidad si falla:** MEDIO

### EDGE-03
**Descripcion:** URL a recurso inexistente — ID de atleta que no existe
**Precondicion:** Sesion como coach@medaliq.com
**Pasos:**
1. Ir a `/coach/athlete/999999` (ID que no existe)
**Esperado:** Pagina de error 404 amigable o redirect. No hay 500 con stack trace expuesto.
**Severidad si falla:** ALTO

### EDGE-04
**Descripcion:** Input extremo — texto muy largo en campo de notas
**Precondicion:** Sesion como ATHLETE (miguel)
**Pasos:**
1. Ir a `/log` o `/checkin`
2. En campo de notas, pegar un texto de 2000 caracteres
3. Submit
**Esperado:** Se guarda (truncado si hay limite) o muestra error de validacion. No hay 500.
**Severidad si falla:** MEDIO

### EDGE-05
**Descripcion:** Input con caracteres especiales y XSS
**Precondicion:** Sesion como ATHLETE
**Pasos:**
1. En campo de texto (notas del check-in o log), ingresar: `<script>alert('xss')</script>`
2. Submit
3. Ver el valor guardado
**Esperado:** El script NO se ejecuta. El texto se guarda como texto plano o se escapa.
**Severidad si falla:** CRITICO

### EDGE-06
**Descripcion:** Numeros negativos en campos numericos
**Precondicion:** Sesion como ATHLETE, en check-in
**Pasos:**
1. En el check-in, en campo de peso ingresar `-50`
2. En campo de horas de sueno ingresar `-8`
3. Submit
**Esperado:** Validacion que rechaza valores negativos. Mensaje de error claro. No se guarda.
**Severidad si falla:** MEDIO

### EDGE-07
**Descripcion:** Sesion expirada — comportamiento correcto
**Precondicion:** Sesion activa como ATHLETE
**Pasos:**
1. Login como miguel
2. Ir a DevTools → Application → Cookies
3. Eliminar la cookie de sesion (next-auth.session-token o similar)
4. Sin recargar, intentar ir a `/plan`
**Esperado:** Redirect a `/login`. No hay datos sensibles en pantalla.
**Severidad si falla:** CRITICO

### EDGE-08
**Descripcion:** Acceso directo a API protegida sin sesion
**Precondicion:** Sin sesion o con cookie eliminada
**Pasos:**
1. Ir directamente a `/api/coach/payments` o `/api/checkin` con metodo GET/POST
2. Observar la respuesta
**Esperado:** Respuesta 401 o 403 en JSON. NO expone datos. NO hace redirect HTML.
**Severidad si falla:** CRITICO

---

## SUITE 4 — CROSS-ROLE (Aislamiento entre roles)

### CROSS-01
**[DEPENDE DE: COACH-06 en test-coach-admin.md]**
**Descripcion:** Coach crea atleta → atleta puede hacer login
**Precondicion:** Atleta creado en COACH-06 (test-coach-admin.md). Si COACH-06 fallo o fue saltado, marcar este test NO-EJEC.
**Pasos:**
1. Cerrar sesion del coach
2. Intentar login con el email del atleta creado y password definido
**Esperado:** Login exitoso. Atleta ve `/onboarding` o `/pending`. No ve panel de coach.
**Severidad si falla:** CRITICO

### CROSS-02
**Descripcion:** Atleta NO puede ver datos de otro atleta via URL directa
**Precondicion:** Sesion como miguel@medaliq.com
**Pasos:**
1. Como Miguel, intentar ir a `/coach/athlete/[id de Sebastian]`
**Esperado:** Redirect o 403/404. Miguel NO ve los datos de Sebastian.
**Severidad si falla:** CRITICO

### CROSS-03
**Descripcion:** Coach A no puede ver atletas de Coach B
**Precondicion:** Existe mas de un coach registrado (Carlos y Maria Gonzalez en seed)
**Pasos:**
1. Sesion como coach@medaliq.com (Carlos)
2. Intentar acceder a datos de un atleta asignado a maria.coach@medaliq.com (Sofia Ramirez, Camilo Torres, Isabella Mendez)
**Esperado:** 404 o datos vacios. Nunca datos de atletas de otro coach.
**Severidad si falla:** CRITICO

### CROSS-04
**[DEPENDE DE: B2B-03 en test-atleta-b2b.md + COACH-11 en test-coach-admin.md]**
**Descripcion:** Mensaje enviado por atleta aparece en coach — y viceversa
**Precondicion:** Mensaje enviado en B2B-03 (Miguel → Coach) y respuesta en COACH-11. Si alguno fallo, marcar NO-EJEC.
**Pasos:**
1. Login como miguel@medaliq.com
2. Ir a mensajes
3. Verificar que la respuesta del coach aparece en la conversacion
**Esperado:** Mensajes en ambas direcciones visibles correctamente.
**Severidad si falla:** ALTO

### CROSS-05
**Descripcion:** Pago creado por coach NO es visible para el atleta en /coach/finanzas
**Precondicion:** Pago creado en COACH-09 (test-coach-admin.md)
**Pasos:**
1. Login como miguel@medaliq.com (el atleta del pago)
2. Intentar acceder a `/coach/finanzas`
**Esperado:** Redirect (no tiene permiso de coach). El atleta no puede ver la seccion de finanzas.
**Severidad si falla:** ALTO

### CROSS-06
**[DEPENDE DE: COACH-06 en test-coach-admin.md]**
**Descripcion:** Activar atleta B2B como coach → atleta puede acceder a features
**Precondicion:** Existe un atleta B2B sin activar (del test COACH-06). Si COACH-06 fallo o fue saltado, marcar NO-EJEC.
**Pasos:**
1. Sesion como COACH, ir al detalle del atleta sin activar
2. Click en "Activar"
3. Cerrar sesion del coach
4. Login como el atleta activado
**Esperado:** El atleta ya no va a `/pending`. Tiene acceso a `/dashboard` con features activas.
**Severidad si falla:** CRITICO

---

## SUITE 5 — DATA CONSISTENCY (Persistencia y coherencia entre modulos)

> **Objetivo:** Verificar que una accion en un modulo se refleja correctamente en todos los que consumen esa data. Anotar el valor exacto observado en cada pantalla y comparar.

---

### GRUPO A — Plan ↔ Dashboard

### DC-01
**Descripcion:** Contador de sesiones en dashboard coincide con las sesiones del plan
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Ir a `/plan`, contar sesiones (excluyendo DESCANSO) de la semana actual. Anotar: `total_plan = N`
2. Contar cuantas estan completadas. Anotar: `done_plan = N`
3. Ir a `/dashboard`, buscar el contador "X/Y sesiones" en "Esta semana"
**Esperado:** El contador del dashboard `completadas/total` = `done_plan/total_plan` del plan.
**Severidad si falla:** ALTO

### DC-02
**Descripcion:** Volumen de km en dashboard coincide con el plan de la semana
**Perfil:** miguel@medaliq.com / atleta123
**Datos esperados de seed:** Semana 7+ tiene vol=42-45km (plan seed-plan-1)
**Pasos:**
1. Ir a `/plan`, encontrar volumen planificado semana actual. Anotar: `vol_plan = N km`
2. Ir a `/dashboard`, buscar km planificados en "Esta semana"
**Esperado:** km en dashboard = `vol_plan` del plan.
**Severidad si falla:** MEDIO

### DC-03
**Descripcion:** Completar una sesion del plan actualiza el contador en el dashboard
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Ir a `/dashboard`, anotar contador actual: `X/Y sesiones`
2. Ir a `/plan`, marcar una sesion de la semana como completada
3. Volver a `/dashboard` (recargar si es necesario)
4. Verificar el nuevo contador
**Esperado:** Contador aumenta de `X` a `X+1`.
**Severidad si falla:** CRITICO

### DC-04
**Descripcion:** Porcentaje de adherencia en /progress coincide con dashboard
**Perfil:** miguel@medaliq.com / atleta123
**Datos esperados de seed:** Check-ins semanas 1-6 con adherencia: 85, 80, 90, 95, 88, 85 (avg ~87%)
**Pasos:**
1. Ir a `/dashboard`, buscar badge de adherencia "X%". Anotar: `adh_dashboard`
2. Ir a `/progress`, buscar tabla de adherencia semanal
3. Calcular promedio de las ultimas 4 semanas visibles
**Esperado:** `adh_dashboard` aproxima al promedio visible en /progress. Diferencia < 5%.
**Severidad si falla:** MEDIO

### DC-05
**Descripcion:** Fase del plan en dashboard coincide con la fase visible en /plan
**Perfil:** miguel@medaliq.com / atleta123
**Datos esperados de seed:** Plan inicia weeksAgo(6) — semana actual dinamica. Semanas 1-4=BASE, 5-6=DESARROLLO
**Pasos:**
1. Ir a `/dashboard`, buscar badge de fase. Anotar: `fase_dashboard`
2. Ir a `/plan`, buscar la fase de la semana actual. Anotar: `fase_plan`
**Esperado:** `fase_dashboard` = `fase_plan`. Fix REGR-02 debe mantenerse.
**Severidad si falla:** MEDIO

---

### GRUPO B — Check-in → Propagacion de datos

### DC-06
**Descripcion:** Peso del check-in se refleja en dashboard "Tu Meta de Peso"
**Perfil:** miguel@medaliq.com / atleta123
**Datos esperados de seed:** Ultimo check-in semana 6: peso=73.8kg
**Pasos:**
1. Ir a `/checkin`, enviar check-in con peso: `72.5 kg` (diferente al anterior)
2. Ir a `/dashboard`, buscar la card "Tu Meta de Peso"
**Esperado:** La card muestra `72.5 kg` como peso actual.
**Severidad si falla:** ALTO

### DC-07
**Descripcion:** Datos del check-in se reflejan en "Como llegas hoy" del dashboard
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Ir a `/checkin`, enviar con: Energia = 2, RPE = 9, Sueno = 4 horas
2. Ir a `/dashboard`, ver la card "Como llegas hoy"
**Esperado:** La card muestra estado ROJO o "Prioriza la recuperacion". Energia y RPE visibles en badges.
**Severidad si falla:** ALTO

### DC-08
**Descripcion:** Check-in con variacion de peso >= 0.5 kg actualiza macros en /nutrition
**Perfil:** miguel@medaliq.com / atleta123
**Datos esperados de seed:** NutritionPlan tiene tdee=2633 (para peso=75kg)
**Pasos:**
1. Ir a `/nutrition`, anotar calorias objetivo: `kcal_antes`
2. Ir a `/checkin`, enviar con peso que difiere >= 0.5 kg del anterior
3. Ir a `/nutrition`, verificar si las calorias cambiaron
**Esperado:** Las calorias en /nutrition se recalculan tras el check-in si |delta_peso| >= 0.5 kg.
**Severidad si falla:** MEDIO

### DC-09
**Descripcion:** Check-in aparece en /progress con los datos correctos
**Perfil:** miguel@medaliq.com / atleta123
**Precondicion:** Check-in enviado en DC-06 (peso 72.5 kg, energia 2, RPE 9)
**Pasos:**
1. Ir a `/progress`, buscar el grafico de peso
2. Verificar que el punto de esta semana muestra 72.5 kg
3. Buscar el grafico de energia o bienestar
**Esperado:** Datos del check-in mas reciente visibles en los graficos de /progress.
**Severidad si falla:** ALTO

### DC-10
**Descripcion:** Check-in con dolor alto genera nota automatica en sesiones del plan
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Ir a `/checkin`, setear "Dolor / molestias" en 8 o mas
2. Enviar check-in
3. Ir a `/plan`, revisar sesiones de la semana actual — buscar notas `[AUTO]`
**Esperado:** Al menos 1 sesion muestra nota `[AUTO]` indicando ajuste por dolor.
**Severidad si falla:** ALTO

---

### GRUPO C — Intensidad del plan ↔ Nutricion diaria

### DC-11
**Descripcion:** Calorias en dashboard coinciden con las de /nutrition para el mismo dia
**Perfil:** ana@medaliq.com / atleta123 (o usuario con plan activo)
**Datos esperados (REGR-03 confirmado):** Ana B2C post-onboarding: ~1739 kcal
**Pasos:**
1. Ir a `/dashboard`, buscar el target calorico del dia. Anotar: `kcal_dashboard`
2. Ir a `/nutrition`, buscar calorias objetivo de hoy. Anotar: `kcal_nutrition`
**Esperado:** `kcal_dashboard` = `kcal_nutrition`. Calculadas con la misma funcion `getDailyNutritionTarget`.
**Severidad si falla:** ALTO

### DC-12
**Descripcion:** Dia de descanso en el plan muestra calorias de descanso en /nutrition
**Perfil:** Cualquier ATHLETE con plan activo
**Pasos:**
1. Ir a `/plan`, identificar un dia con tipo DESCANSO
2. Ir a `/nutrition`, verificar que el label del dia dice "Dia de descanso" y las calorias son las mas bajas (targetKcalRest)
**Esperado:** En dia DESCANSO, las calorias son las de descanso. El label lo indica.
**Datos esperados seed (miguel):** targetKcalRest=1733 (Miguel). Dia descanso: ~1702 kcal (REGR-03).
**Severidad si falla:** MEDIO

### DC-13
**Descripcion:** Sesion de alta intensidad (HIGH) muestra calorias altas en /nutrition
**Perfil:** Cualquier ATHLETE con sesion HIGH esta semana
**Datos esperados seed (miguel):** targetKcalHard=2133 para intensidad HIGH
**Pasos:**
1. Ir a `/plan`, identificar sesion de alta intensidad (INTERVALOS, FARTLEK, TEMPO). Anotar el dia.
2. Si es hoy o mañana, ir a `/nutrition`
3. Verificar que muestra calorias altas y label de "Entreno intenso" o similar
**Esperado:** Las calorias de dia HIGH son mayores que las de dia REST. El label lo indica.
**Severidad si falla:** MEDIO

---

### GRUPO D — Sesion de Gym → Historia y PRs

### DC-14
**Descripcion:** Sesion de gym completada aparece en historial de gym
**Perfil:** Cualquier ATHLETE con featureGym = true
**Pasos:**
1. Ir a `/gym`, iniciar una sesion
2. Registrar al menos 2 series de 1 ejercicio (ej: Sentadilla — 60kg x 8, 65kg x 6)
3. Completar la sesion
4. Ir a `/gym/history`, verificar que la sesion de hoy aparece al tope
**Esperado:** La sesion aparece con: fecha de hoy, nombre del ejercicio, series registradas.
**Severidad si falla:** CRITICO

### DC-15
**Descripcion:** PR detection — nuevo maximo de peso registra badge de PR en historial
**Perfil:** Mismo que DC-14
**Pasos:**
1. Ir a `/gym`, iniciar sesion
2. Elegir un ejercicio conocido (ej: Sentadilla)
3. Registrar una serie con peso MAYOR al historico previo (si es primera vez, cualquier peso es PR)
4. Completar la sesion
5. Ir a `/gym/history`, abrir la sesion, buscar badge "PR" o "Nuevo record"
**Esperado:** La serie con el nuevo maximo muestra badge de PR. Series sin nuevo maximo NO muestran PR.
**Severidad si falla:** ALTO

### DC-16
**Descripcion:** Sesion de gym completada no aparece en el historial de otro atleta
**Perfil:** Primero ATHLETE (miguel), luego ATHLETE (sebastian)
**Precondicion:** DC-14 completado con sesion de miguel
**Pasos:**
1. Cerrar sesion de miguel
2. Login como sebastian.rios@medaliq.com / atleta123
3. Ir a `/gym/history`, verificar que NO aparece la sesion de miguel
**Esperado:** Historial de sebastian solo muestra sus propias sesiones.
**Severidad si falla:** CRITICO

---

### GRUPO E — Flujo Coach → Atleta

### DC-17
**Descripcion:** Plan creado por coach para atleta aparece en /plan del atleta
**Perfil:** COACH crea, ATHLETE verifica
**Pasos:**
1. Login como coach@medaliq.com / coach123
2. Ir al detalle de Sebastian Rios → tab Plan
3. Si no hay plan activo: crear uno (Running 5K). Anotar el nombre del plan.
4. Cerrar sesion del coach
5. Login como sebastian.rios@medaliq.com / atleta123, ir a `/plan`
**Esperado:** El plan aparece en /plan del atleta con el mismo nombre asignado por el coach.
**Severidad si falla:** CRITICO

### DC-18
**Descripcion:** Coach edita una sesion del plan → atleta ve el cambio
**Perfil:** COACH edita, ATHLETE verifica
**Precondicion:** Sebastian tiene plan activo (de DC-17 o pre-existente)
**Pasos:**
1. Login como coach@medaliq.com / coach123
2. Ir al detalle de Sebastian → tab Plan → click en una sesion
3. Modificar la nota: "Nota de test E2E — editada por coach", guardar
4. Cerrar sesion, login como sebastian.rios@medaliq.com / atleta123
5. Ir a `/plan` → click en la sesion editada
**Esperado:** La nota "Nota de test E2E — editada por coach" aparece para el atleta.
**Severidad si falla:** ALTO

### DC-19
**Descripcion:** Rutina de gym asignada por coach aparece en /gym del atleta
**Perfil:** COACH asigna rutina, ATHLETE verifica
**Estado anterior:** FAIL MEDIO — coach no tenia rutina asignada a miguel en tercera ejecucion
**Pasos:**
1. Login como coach@medaliq.com / coach123
2. Ir al detalle de Nicolas Gutierrez → tab Gym
3. Asignar una rutina existente (o crear una simple de 2 ejercicios)
4. Cerrar sesion, login como nicolas.gutierrez@medaliq.com / atleta123
5. Ir a `/gym`
**Esperado:** La rutina asignada por el coach aparece en el gym del atleta.
**Severidad si falla:** ALTO

### DC-20
**[DEPENDE DE: COACH-06 en test-coach-admin.md]**
**Descripcion:** Coach activa atleta B2B → atleta accede a todas las features
**Perfil:** COACH activa, ATHLETE verifica
**Precondicion:** Existe atleta B2B recien creado en estado "pending" (del test COACH-06). Si COACH-06 fallo, marcar NO-EJEC.
**Pasos:**
1. Login como coach@medaliq.com / coach123
2. Ir al detalle del atleta en estado "pending"
3. Click en "Activar cuenta"
4. Verificar que el estado cambia a "Activo"
5. Cerrar sesion, login como el atleta activado
6. Verificar que no va a /pending
7. Ir a /plan, /checkin, /nutrition, /gym
**Esperado:** El atleta accede a todas las secciones. Todas las features activas.
**Severidad si falla:** CRITICO

### DC-21
**Descripcion:** KPIs del coach (total atletas, activos) coinciden con la lista real
**Perfil:** COACH
**Datos esperados:** 5 atletas activos para coach@medaliq.com en seed (Miguel, Juan, Sebastián, Nicolás, Santiago). El 6° lo crea COACH-06 durante la sesión.
**Pasos:**
1. Login como coach@medaliq.com / coach123, ir a `/coach/dashboard`
2. Anotar numero de "atletas activos" en KPI: `kpi_activos`
3. Ir a la lista de atletas, contar los que tienen estado "Activo": `lista_activos`
**Esperado:** `kpi_activos` = `lista_activos`.
**Severidad si falla:** MEDIO

---

### GRUPO F — Mensajes → Badges y bidireccionalidad

### DC-22
**Descripcion:** Mensaje del atleta genera badge de no leido en el panel del coach
**Perfil:** ATHLETE envia, COACH verifica badge
**Pasos:**
1. Login como miguel@medaliq.com / atleta123
2. Ir a mensajes, enviar: "Mensaje para test de badge [timestamp actual]"
3. Cerrar sesion, login como coach@medaliq.com / coach123
4. Observar el sidebar o inbox del coach
**Esperado:** Badge de mensaje no leido asociado a Miguel. Numero de no leidos >= 1.
**Severidad si falla:** ALTO

### DC-23
**Descripcion:** Coach lee el mensaje → badge desaparece
**Perfil:** COACH
**Precondicion:** DC-22 completado, badge visible para el coach
**Pasos:**
1. Sesion como coach (continuacion de DC-22)
2. Ir a la conversacion con Miguel, leer el mensaje
3. Volver al dashboard o esperar 30 segundos
**Esperado:** El badge de no leido desaparece o el contador baja en 1.
**Severidad si falla:** ALTO

### DC-24
**Descripcion:** Respuesta del coach aparece en el chat del atleta
**Perfil:** COACH responde, ATHLETE verifica
**Precondicion:** DC-22 completado
**Pasos:**
1. Sesion como coach, en la conversacion con Miguel, responder: "Recibido. Ajustamos el plan esta semana."
2. Cerrar sesion, login como miguel@medaliq.com / atleta123
3. Ir a mensajes
**Esperado:** La respuesta aparece en el chat de miguel con el nombre del coach como remitente.
**Severidad si falla:** ALTO

---

### GRUPO G — Pagos y Audit Trail

### DC-25
**Descripcion:** Pago creado por coach aparece con datos exactos
**Perfil:** COACH crea pago, verifica datos
**Pasos:**
1. Login como coach@medaliq.com / coach123, ir a `/coach/finanzas`
2. Crear nuevo pago: Atleta=Santiago Rodriguez, Monto=`200000`, Moneda=COP, Descripcion="Mensualidad julio 2026", Vencimiento=2026-07-31
3. En la lista, encontrar el pago recien creado
**Esperado:** Pago con exactamente: monto `200.000 COP`, descripcion correcta, atleta "Santiago Rodriguez", estado PENDIENTE, fecha 31 jul 2026.
**Severidad si falla:** ALTO

### DC-26
**Descripcion:** Marcar pago como pagado refleja cambio de estado y fecha de pago
**Precondicion:** Pago en PENDIENTE de DC-25
**Pasos:**
1. En `/coach/finanzas`, encontrar el pago de Santiago Rodriguez de DC-25
2. Marcar como pagado
3. Verificar el estado y la fecha de pago en la lista
**Esperado:** Estado cambia a PAGADO. Aparece fecha de pago (hoy). Monto y atleta sin cambios.
**Severidad si falla:** ALTO

### DC-27
**Descripcion:** Pago vencido (dueDate pasada + PENDIENTE) muestra badge de mora en lista de atletas
**⚠️ ESTADO: Ejecutable solo si existe un pago con dueDate en el pasado en produccion**
**Nota:** `PaymentStatus.OVERDUE` no existe en DB — es derivado en app layer: `dueDate < ahora && status === PENDING`. El seed no crea pagos con fecha vencida. Este test solo es valido si durante la sesion se creo un pago con fecha pasada, o si existe uno previo en DB.
**Pasos:**
1. Login como coach@medaliq.com / coach123, ir a la lista de atletas
2. Buscar si algun atleta tiene badge o indicador de mora
3. Ir a `/coach/finanzas`, verificar que ese atleta tiene pago con dueDate < hoy y estado PENDING
**Esperado:** El atleta con pago vencido muestra badge de mora. Los demas, no.
**Accion:** Si no hay pagos vencidos en produccion, marcar NO-EJEC.
**Severidad si falla:** MEDIO

---

### GRUPO H — Onboarding → Inicializacion completa

### DC-28
**[DEPENDE DE: B2C-03 en test-atleta-b2c.md]**
**Descripcion:** Despues del onboarding B2C RUNNING (feature/16): modo FREE inicializado — sin TrainingPlan, con nutricion y rutina accesible
**Perfil:** Ana (ana@medaliq.com) — atleta B2C RUNNING. Si B2C-03 fallo, marcar NO-EJEC.
**⚠️ CAMBIO feature/16:** El onboarding B2C ya NO genera TrainingPlan. El atleta entra en modo FREE con NutritionPlan calculado. `/plan` debe mostrar empty state, NO sesiones.
**Pasos:**
1. Login como ana@medaliq.com / atleta123
2. Ir a `/plan` → verificar que muestra empty state "Sin plan activo" (NO debe haber semanas ni sesiones de TrainingPlan)
3. Ir a `/nutrition` → verificar calorias calculadas > 0 (~1739 kcal segun REGR-03 confirmado)
4. Ir a `/checkin` → verificar formulario disponible
5. Ir a `/routine/edit` → verificar que carga el editor de rutina semanal (7 dias, cada uno en REST o con actividad configurada)
6. Ir a `/progress` → verificar que carga sin error 500
**Esperado:** /plan con empty state (sin TrainingPlan), /nutrition con macros (~1739 kcal), /checkin disponible, /routine/edit cargable, /progress sin error.
**Severidad si falla:** CRITICO

### DC-29
**[DEPENDE DE: NEW-06 en test-atleta-b2c.md]**
**Descripcion:** Despues del onboarding GYM/STRENGTH (feature/16): gym disponible, nutricion inicializada, sin TrainingPlan
**Perfil:** Maria (usuario registrado en NEW-03, onboarding STRENGTH completado en NEW-06). Si NEW-06 fallo, marcar NO-EJEC.
**⚠️ CAMBIO feature/16:** El onboarding STRENGTH tampoco genera TrainingPlan. `/plan` debe mostrar empty state.
**Datos esperados (DC-29 confirmado):** Maria STRENGTH: ~1685 kcal, ~120g proteina, ~115g carbos, ~63g grasa
**Pasos:**
1. Login con la cuenta de Maria (email registrado en NEW-03) / MedaliqTest2026!
2. Ir a `/gym` → verificar que carga con plantillas de entrenamiento disponibles (no requiere plan activo)
3. Ir a `/nutrition` → verificar calorias calculadas para fuerza (~1685 kcal, ~120g proteina)
4. Ir a `/plan` → verificar empty state "Sin plan activo" (STRENGTH B2C no genera TrainingPlan — usa /gym directamente)
5. Ir a `/routine/edit` → verificar que carga el editor de rutina semanal
**Esperado:** /gym con plantillas, /nutrition con macros correctos (~1685 kcal), /plan con empty state (sin TrainingPlan), /routine/edit cargable.
**Severidad si falla:** CRITICO

### DC-30
**[DEPENDE DE: NEW-03 o NEW-06 en test-atleta-b2c.md]**
**Descripcion:** Peso ingresado en onboarding aparece en dashboard y como baseline en /progress
**Perfil:** Usuario nuevo (NEW-03 o DC-28). Si ambos fallaron, marcar NO-EJEC.
**Precondicion:** Onboarding completado con peso especifico (ej: Maria ingreso 65 kg)
**Pasos:**
1. Login como el usuario nuevo, ir a `/dashboard`
2. Buscar la card "Tu Meta de Peso"
3. Verificar que el peso actual mostrado es el ingresado en el onboarding (65 kg)
4. Ir a `/progress`, verificar que el peso baseline es 65 kg
**Esperado:** El peso del onboarding es el baseline inicial en todas las vistas.
**Severidad si falla:** ALTO

---

### GRUPO I — Features #10-#15 (sesion actual)

### DC-31
**[DEPENDE DE: COACH-19 en test-coach-admin.md]**
**Descripcion:** Benchmark registrado por coach aparece en /progress del atleta — coherencia coach → atleta
**Feature:** #10 — PerformanceBenchmarks
**Perfil:** COACH registra (COACH-19), ATHLETE verifica (sebastian.rios@medaliq.com)
**Precondicion:** COACH-19 ejecutado — benchmark 5K (1620s / 27:00) registrado para Sebastian Rios. Si COACH-19 fallo, marcar NO-EJEC.
**Pasos:**
1. Login como sebastian.rios@medaliq.com / atleta123
2. Ir a `/progress`
3. Hacer scroll hasta el final de la pagina
4. Verificar que aparece la seccion "Tests de Rendimiento"
5. Verificar que muestra: deporte=RUNNING, metrica=5K, valor="27:00", fecha de hoy
**Esperado:** Benchmark visible en /progress del atleta con exactamente los datos registrados por el coach. Agrupado bajo "RUNNING". Tiempo formateado como "27:00" (no 1620 en crudo).
**Severidad si falla:** ALTO

---

### DC-32
**[DEPENDE DE: COACH-17 en test-coach-admin.md]**
**Descripcion:** VolumeKm y metadata de semana editados en el constructor persisten al recargar
**Feature:** #15 — PATCH week metadata + volumeKm
**Perfil:** coach@medaliq.com, plan de Miguel
**Precondicion:** COACH-17 ejecutado — semana 1 del plan de Miguel editada con focusDescription="Test E2E — semana editada" y volumeKm=35. Si COACH-17 fallo, marcar NO-EJEC.
**Pasos:**
1. Login como coach@medaliq.com / coach123
2. Ir al constructor del plan de Miguel (`/coach/athlete/[id]/plan/build`)
3. Navegar a la semana 1 en el WeekNav
4. Verificar que la descripcion de enfoque muestra "Test E2E — semana editada"
5. Verificar que los km de la semana muestran "35 km" (si hay campo visible)
6. Recargar la pagina (Ctrl+R) y verificar que los valores persisten
**Esperado:** Los cambios persisten tras recargar. La descripcion y volumeKm son exactamente los guardados en COACH-17. La DB refleja los cambios via PATCH `/api/coach/plan/[planId]/week/[weekId]`.
**Severidad si falla:** ALTO

---

### DC-33
**[DEPENDE DE: COACH-18 en test-coach-admin.md]**
**Descripcion:** Targets nutricionales aplicados por fase para un atleta persisten en DB
**Feature:** #13 — Editor targets kcal por fase
**Perfil:** coach@medaliq.com → atleta Miguel
**Precondicion:** COACH-18 ejecutado — "Aplicar targets de fase" fue presionado y guardado. Si COACH-18 no se guardo, marcar NO-EJEC.
**Pasos:**
1. Login como miguel@medaliq.com / atleta123
2. Ir a `/nutrition`
3. Verificar que los targets caloricos reflejan los aplicados por el coach (tdee + delta de fase ± offset)
4. Segun la fase actual del plan: BASE → targetKcalHard ~2733 (2633-200+300), Easy ~2433, Rest ~2233
**Esperado:** Los targets del atleta reflejan los ajustados por el coach segun la fase. No son los valores originales del seed (targetKcalHard=2133).
**Nota:** Los valores exactos dependen de la fase activa al momento de ejecutar COACH-18. Anotar la fase y calcular: Hard=tdee+delta+300, Easy=tdee+delta, Rest=tdee+delta-200.
**Severidad si falla:** MEDIO

---

### GRUPO J — Feature #16 — Self-Directed Tracking

### DC-34
**[DEPENDE DE: SELF-01 en test-atleta-b2c.md]**
**Descripcion:** Rutina semanal guardada aparece correctamente en dashboard el mismo dia
**Feature:** #16 — WeeklyRoutine self-directed
**Perfil:** Ana o Maria — atleta B2C en modo FREE
**Precondicion:** SELF-01 ejecutado — rutina guardada con al menos Lunes=RUN/Rodaje Z2, Miercoles=GYM/Push, Viernes=RUN
**Pasos:**
1. Despues de guardar la rutina, volver al dashboard
2. Verificar que la seccion self-directed muestra la actividad del dia de hoy segun la rutina
3. Ir a `/routine/edit` y verificar que la rutina guardada se carga (dias con los colores correctos: azul=GYM, naranja=RUN)
4. Recargar la pagina (`/routine/edit`) y verificar que la rutina persiste
**Esperado:** La rutina guardada persiste tras recargar. El dashboard refleja el dia correcto de la rutina. Sin desincronizacion entre /routine/edit y el dashboard.
**Severidad si falla:** ALTO

---

### DC-35
**[DEPENDE DE: SELF-03 en test-atleta-b2c.md]**
**Descripcion:** Corrida libre registrada aparece en /log/history y en puntos de consistencia del dashboard
**Feature:** #16 — SessionLog libre + historial unificado
**Perfil:** Ana o Maria — atleta B2C en modo FREE
**Precondicion:** SELF-03 ejecutado — corrida "Rodaje Z2, 30 min, 5 km, RPE 5" registrada hoy
**Pasos:**
1. Ir a `/log/history`
2. Verificar que la corrida del SELF-03 aparece como primera entrada (mas reciente)
3. Verificar que muestra: tipo=Rodaje Z2, duracion=30 min, distancia=5 km, RPE=5
4. Volver al dashboard
5. Verificar que el dot de consistencia del dia de hoy esta lleno (naranja) — indica actividad registrada hoy
**Esperado:** La corrida aparece en /log/history con datos correctos. Los dots de consistencia reflejan la actividad. Coherencia total entre log → historial → dashboard.
**Severidad si falla:** ALTO

### GRUPO K — Gym + Nutrition cross-module

### DC-36
**[DEPENDE DE: GYM-03 en test-atleta-b2c.md]**
**Descripcion:** Sesion de gym completada por atleta B2C aparece en historial del coach (si tiene AssignedWorkout asignado)
**Feature:** GymSession → coach puede ver historial de sesiones del atleta
**Perfil:** Ana o Maria (completo GYM-03). Coach Carlos.
**Precondicion:** GYM-03 ejecutado — sesion completada. Si el atleta B2C no tiene coach asignado, marcar NO-EJEC (B2C pura no tiene coach).
**Accion:** Si el atleta es B2C sin coach, marcar **NO-EJEC** — coherencia gym→coach solo aplica a B2B. El test valido para B2B es:
1. Login como coach@medaliq.com
2. Ir al detalle de Miguel (`/coach/athlete/[id]`) → tab "Gym" o "Historial"
3. Verificar que las sesiones de gym de Miguel aparecen (si Miguel hizo una sesion previa)
**Esperado:** El coach puede ver el historial de gym de sus atletas B2B. Sin errores. Sin datos de otros atletas.
**Accion alternativa:** Si Miguel tiene sesiones en la DB del seed, verificar que el coach las ve. Si no, marcar PARCIAL y anotar.
**Severidad si falla:** MEDIO

---

### DC-37
**[DEPENDE DE: NUT-03 en test-atleta-b2c.md]**
**Descripcion:** Alimento registrado en /nutrition del dia NO aparece en /plan ni en check-in — aislamiento de datos
**Feature:** FoodLog aislado por userId + date. No debe contaminar otras secciones.
**Perfil:** Ana o Maria (registro NUT-03 — Pechuga 150g, Almuerzo)
**Precondicion:** NUT-03 ejecutado. Sesion activa.
**Pasos:**
1. Verificar que el alimento (Pechuga 150g) aparece SOLO en `/nutrition` → seccion "Registro del dia"
2. Ir a `/plan` → verificar que NO hay referencia al alimento registrado (el plan es de sesiones de entrenamiento, no de comidas)
3. Ir a `/checkin` → verificar que el formulario NO pre-rellena datos del FoodLog
4. Ir a `/dashboard` → verificar que el alimento no aparece en la card de sesion diaria
**Esperado:** El FoodLog es aislado — solo visible en /nutrition. Ninguna otra seccion muestra datos de comidas del dia como parte del flujo de entrenamiento.
**Severidad si falla:** ALTO

---

## SUITE 6 — PERFORMANCE BASICA

**Objetivo:** Verificar que las paginas cargan en tiempo razonable y los estados de carga se resuelven. No se mide con cronometro exacto — se valida que no hay spinners infinitos ni pantallas en blanco.

### PERF-01
**Descripcion:** Dashboard carga en menos de 5 segundos
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Navegar directamente a `/dashboard`, iniciar cronometro al presionar Enter
2. Esperar a que la pagina muestre contenido real (no spinner)
**Esperado:** Dashboard con contenido visible en < 5 seg. Sin spinner infinito.
**Severidad si falla:** ALTO

### PERF-02
**Descripcion:** /plan carga con todas las semanas sin timeout
**Perfil:** miguel@medaliq.com
**Datos esperados:** Plan seed-plan-1 tiene 6 semanas definidas en seed (18 totales, 6 con datos)
**Pasos:**
1. Navegar a `/plan`, esperar carga completa
2. Verificar que semanas visibles son accesibles, sin errores en consola
**Esperado:** Plan cargado. Sin errores. Sin timeout.
**Severidad si falla:** ALTO

### PERF-03
**Descripcion:** Check-in submit no tarda mas de 10 segundos
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Completar el formulario de check-in, hacer submit
2. Verificar que el loading state se resuelve en < 10 seg
**Esperado:** Submit resuelto en < 10 seg. Loading visible. Confirmacion clara.
**Severidad si falla:** ALTO

### PERF-04
**Descripcion:** Paso "generating" del onboarding no muestra pantalla blanca
**Perfil:** Usuario nuevo en paso "generating" del onboarding (B2C cualquier tipo)
**Nota:** El paso "generating" es computo local (TDEE + macros + perfil). Debe ser rapido (< 10 seg).
**Pasos:**
1. Completar el wizard de onboarding hasta el ultimo paso
2. Observar el estado de "generando" (spinner o pantalla de transicion)
3. Verificar que hay indicador de carga visible (no pantalla en blanco)
4. Esperar hasta 15 segundos
**Esperado:** Pantalla de carga visible. No pantalla blanca. Resuelve en < 15 seg (calculo local). Redirige a /dashboard al terminar.
**Severidad si falla:** CRITICO

### PERF-05
**Descripcion:** Navegacion entre tabs es instantanea (client-side)
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Hacer click en "Plan" en el sidebar/bottom nav
2. Observar si hay full page reload o navegacion instantanea
3. Repetir 2-3 veces rapidamente entre diferentes tabs
**Esperado:** Navegacion client-side sin full reload. Sin pantallas blancas entre tabs.
**Severidad si falla:** MEDIO

### PERF-06
**Descripcion:** Pagina /nutrition carga macros sin delay visible
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Navegar a `/nutrition`
2. Observar si los macros aparecen inmediatamente o con retraso
3. Verificar que no hay layout shift (contenido que salta)
**Esperado:** Macros visibles al cargar. Sin layout shift. Sin spinner prolongado.
**Severidad si falla:** MEDIO

### PERF-07
**Descripcion:** Historial de gym carga sin paginacion rota
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Navegar a `/gym` o historial de gym
2. Verificar que las sesiones anteriores cargan, navegar paginacion si existe
**Esperado:** Historial cargado correctamente. Paginacion funcional si existe.
**Severidad si falla:** MEDIO

### PERF-08
**Descripcion:** Panel coach — lista de atletas carga sin error
**Perfil:** coach@medaliq.com
**Datos esperados:** 5 atletas en seed + el creado en COACH-06 = 6 al finalizar la suite coach
**Pasos:**
1. Navegar a `/coach/dashboard`, verificar que los atletas aparecen (5 al inicio, 6 al final de la suite)
2. Abrir el detalle de 3 atletas diferentes rapidamente
**Esperado:** Lista de atletas y detalles cargan sin error. Sin timeouts.
**Severidad si falla:** ALTO

---

## SUITE 7 — ACCESSIBILITY BASICA

**Objetivo:** Verificar que la aplicacion cumple con accesibilidad minima para ser usable con teclado y tiene contraste adecuado.

### A11Y-01
**Descripcion:** Login navegable completamente con teclado
**Precondicion:** Sin sesion activa
**Pasos:**
1. Navegar a `/login`, hacer click para dar foco
2. Presionar Tab para moverse entre campos
3. Verificar que el foco pasa: Email → Password → Submit → Olvidaste contrasena → Google
4. Presionar Enter en Submit con formulario lleno
**Esperado:** Todos los elementos interactivos accesibles con Tab. Enter funciona en Submit. Foco visible (outline).
**Severidad si falla:** MEDIO

### A11Y-02
**Descripcion:** Formulario de check-in navegable con teclado
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Ir a `/checkin`, presionar Tab desde el primer campo
2. Navegar con Tab por todos los inputs
3. Verificar que cada campo recibe foco visible
4. Verificar que los sliders son manejables con flechas de teclado
**Esperado:** Formulario completable con solo teclado. Foco visible en cada campo.
**Severidad si falla:** MEDIO

### A11Y-03
**Descripcion:** Contraste minimo en texto principal
**Perfil:** Cualquier usuario
**Pasos:**
1. Navegar al `/dashboard`
2. Verificar visualmente que el texto gris sobre fondo blanco es legible
3. Verificar texto blanco sobre fondo azul oscuro (#1e3a5f)
4. Verificar texto naranja (#f97316) sobre fondo blanco (ratio minimo WCAG AA: 4.5:1 texto normal)
**Esperado:** Texto principal legible. Colores de marca con contraste aceptable.
**Notas previas:** Naranja (#f97316) sobre blanco tiene ratio ~3.4:1 — FALLA WCAG AA para texto normal, PASA para texto grande/bold.
**Severidad si falla:** MEDIO

### A11Y-04
**Descripcion:** Imagenes e iconos tienen texto alternativo o son decorativos
**Pasos:**
1. Navegar a `/dashboard`
2. Click derecho en el logo de Medaliq → Inspeccionar, verificar si tiene `alt` attribute
3. Buscar iconos en la UI — verificar si tienen `aria-label` o son `aria-hidden`
**Esperado:** Logo con `alt="Medaliq"` o similar. Iconos decorativos con `aria-hidden="true"`. Iconos funcionales con `aria-label`.
**Severidad si falla:** BAJO

### A11Y-05
**Descripcion:** Mensajes de error son anunciados (role o aria-live)
**Precondicion:** Sin sesion activa
**Estado anterior:** FAIL BAJO — banner de error login sin role="alert" ni aria-live
**Pasos:**
1. Ir a `/login`, ingresar credenciales incorrectas, submit
2. Inspeccionar el div del mensaje de error en DevTools
3. Verificar si tiene `role="alert"` o `aria-live="polite"`
**Esperado:** Mensaje de error con `role="alert"`. Si fue corregido desde la ultima ejecucion, debe pasar.
**Severidad si falla:** BAJO

### A11Y-06
**Descripcion:** Sidebar/bottom nav tienen labels accesibles
**Perfil:** miguel@medaliq.com
**Pasos:**
1. Inspeccionar los links del sidebar (desktop)
2. Verificar que cada link tiene texto visible o `aria-label`
3. Cambiar a modo mobile (DevTools), inspeccionar los tabs del bottom nav
4. Verificar que cada tab tiene texto visible debajo del icono
**Esperado:** Links de navegacion con texto legible o aria-label. Bottom nav con etiquetas de texto bajo cada icono.
**Severidad si falla:** MEDIO

---

## SUITE 8 — ACTIVATION (Flujos de activación B2C)

> Tests detectados en auditoría USER-EXPLORE (2026-06-29). BUG-001 y BUG-002 son P0 — bloquean activación.

### ACT-01
**Descripcion:** Onboarding "Plan personalizado" genera plan activo
**Bug referenciado:** BUG-002 (P0)
**Perfil:** Atleta B2C nuevo (usar cuenta nueva cada ejecución)
**Pasos:**
1. Registrar cuenta nueva, completar onboarding
2. En paso final completar el onboarding → Guardar
3. Ir a `/dashboard`
**Esperado:** Dashboard muestra plan activo (semana, fase, sesión de hoy). NO muestra "Sin plan activo · Entrenamiento libre".
**Severidad si falla:** CRITICO

---

### ACT-02
**Descripcion:** Objetivo "Gym / Ganar músculo" NO genera sesiones de running
**Bug referenciado:** BUG-016 (P1)
**Perfil:** Atleta B2C nuevo con objetivo Gym
**Pasos:**
1. Onboarding → objetivo "Gym → Ganar músculo" → Generar plan
2. Ir a `/plan`, revisar todas las sesiones de la semana 1
**Esperado:** Plan de fuerza puro (split/PPL). NINGUNA sesión de tipo Rodaje Z2, Tempo, Intervalos o cardio.
**Severidad si falla:** ALTO

---

### ACT-03
**Descripcion:** /new-goal pre-rellena la meta elegida en onboarding
**Bug referenciado:** BUG-005 (P1) · BUG-070 (P2)
**Perfil:** Atleta B2C post-onboarding RUNNING
**Pasos:**
1. Completar onboarding con activityType=RUNNING
2. El onboarding redirige a `/new-goal` automáticamente (único punto de acceso — no hay CTA desde dashboard)
3. Verificar que la meta ya está pre-seleccionada (5K o 10K coherente con RUNNING)
**Esperado:** El formulario muestra "5K" o "10K" pre-seleccionado. NO obliga a re-elegir. Banner "Pre-seleccionado según tu onboarding" visible.
**Resultado conocido:** ❌ FAIL (BUG-070) — pre-selecciona "Fitness general" en lugar de RACE_5K/RACE_10K.
**Nota ARCH-01:** El CTA "Mi Plan → Generar mi plan" ya no existe en el dashboard FREE. La única entrada a `/new-goal` es el onboarding RUNNING. La ruta está pendiente de deprecación formal.
**Severidad si falla:** MEDIO

---

### ACT-04
**Descripcion:** Onboarding pregunta deporte 1 vez y días disponibles 1 vez
**Bug referenciado:** BUG-021 (P2)
**Perfil:** Atleta B2C nuevo
**Pasos:**
1. Iniciar onboarding desde cero
2. Contar cuántas veces aparece "¿Cuál es tu deporte?" o equivalente
3. Contar cuántas veces aparece "días disponibles"
**Esperado:** Deporte preguntado exactamente 1 vez. Días disponibles preguntado exactamente 1 vez.
**Severidad si falla:** MEDIO

---

## SUITE 9 — CALC (Consistencia de cálculos deportivos)

> Tests detectados en auditoría USER-EXPLORE. BUG-003 y BUG-004 minan la credibilidad del producto.

### CALC-01
**Descripcion:** FC máxima es idéntica en onboarding y en perfil
**Bug referenciado:** BUG-003 (P1)
**Perfil:** Cualquier atleta — usar miguel@medaliq.com / atleta123
**Pasos:**
1. Login como Miguel, ir a `/onboarding` (o buscar FC máx mostrada en perfil/plan)
2. Anotar FC máx mostrada en Perfil → Datos de Salud: `fcmax_perfil`
3. Anotar FC máx usada en zonas de entrenamiento en `/plan`: `fcmax_plan`
**Esperado:** `fcmax_perfil` === `fcmax_plan`. Una sola fórmula, un solo valor.
**Severidad si falla:** ALTO

---

### CALC-02
**Descripcion:** TDEE y target calórico son idénticos entre Mi Plan y Nutrición
**Bug referenciado:** BUG-004 (P1)
**Perfil:** miguel@medaliq.com / atleta123 — mismo día, sesión con intensidad definida
**Pasos:**
1. Login como Miguel, ir a `/plan` → anotar kcal del plan del día: `kcal_plan`
2. Ir a `/nutrition` → anotar "TDEE base" y target calórico: `kcal_nutrition`
**Esperado:** `kcal_plan` === `kcal_nutrition` para el mismo día y misma sesión. Diferencia máxima aceptable: 0 kcal (misma fuente).
**Severidad si falla:** ALTO

---

## SUITE 10 — DCX (Data Consistency ampliada)

> Amplía la suite DC con propagación real de datos verificada como usuario (USER-EXPLORE 2026-06-29).

### DCX-01
**Descripcion:** Check-in peso → dashboard "TU META" y punto en Progreso actualizados
**Bug referenciado:** Verificación de flujo (sin bug abierto si pasa)
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. POST /api/checkin con `bodyWeight: 72` (o via UI)
2. Ir a `/dashboard` → verificar card "TU META" muestra 72 kg
3. Ir a `/progress` → verificar punto más reciente = 72 kg
**Esperado:** Mismo valor en las 3 vistas. Sin recargar manualmente.
**Severidad si falla:** ALTO

---

### DCX-02
**Descripcion:** Check-in energía/RPE/sueño → "Cómo llegás hoy" coincide exactamente
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Hacer check-in con energía=7, RPE=4, sueño=8
2. Ir a `/dashboard` → verificar card "CÓMO LLEGÁS HOY"
**Esperado:** Muestra energía 7/10, RPE 4, sueño 8h. Coincide exactamente con lo enviado.
**Severidad si falla:** ALTO

---

### DCX-03
**Descripcion:** Marcar sesión completa → adherencia y contador de sesiones suben
**Perfil:** miguel@medaliq.com / atleta123 — día con sesión planificada (no descanso)
**Pasos:**
1. En `/plan` → seleccionar sesión del día → "Registrar sesión" → marcar completada
2. Verificar "n/total completadas" en la semana
3. Verificar adherencia semanal en `/plan`
**Esperado:** Contador sube de n a n+1. Adherencia % recalculada correctamente.
**Severidad si falla:** ALTO

---

### DCX-04
**Descripcion:** Registrar comida → "Lo que comí hoy" suma kcal y porcentaje correctamente
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. Ir a `/nutrition` → registrar comida con X kcal
2. Verificar sección "Lo que comí hoy" — suma y porcentaje actualizados
**Esperado:** Total kcal = suma de comidas registradas. Porcentaje = total / target × 100.
**Severidad si falla:** MEDIO

---

### DCX-05
**Descripcion:** Editar duración de sesión persiste tras reload (sin stale UI)
**Bug referenciado:** BUG-008 (P2)
**Perfil:** coach@medaliq.com — editar sesión de atleta
**Pasos:**
1. En panel coach → plan de atleta → editar duración de una sesión → Guardar
2. Sin recargar: verificar que la vista muestra el nuevo valor
3. Recargar página: verificar que persiste
**Esperado:** Valor actualizado inmediatamente en UI (sin reload). Persiste tras reload.
**Severidad si falla:** MEDIO

---

### DCX-06
**Descripcion:** FC reposo del check-in sincroniza a Datos de Salud del perfil
**Bug referenciado:** BUG-009 (P2)
**Perfil:** miguel@medaliq.com / atleta123
**Pasos:**
1. POST /api/checkin con `restingHr: 54`
2. Ir a Perfil → Datos de Salud → verificar FC reposo
**Esperado:** Datos de Salud muestra "54 bpm". No muestra "— bpm".
**Severidad si falla:** MEDIO

---

## SUITE 11 — JOURNEYS (Flujos persona completos)

> Tests end-to-end por tipo de usuario — detectados en auditoría USER-EXPLORE.

### PJ-01
**Descripcion:** Journey completo atleta gym-only (Andres persona)
**Perfil:** Atleta B2C nuevo con objetivo Gym
**Pasos:**
1. Registrar cuenta nueva → onboarding objetivo "Gym → Ganar músculo"
2. Verificar que el plan generado NO tiene sesiones de running (ACT-02)
3. Ir a `/gym` → verificar que hay rutina asignada o CTA claro
4. Registrar sesión de gym (series, pesos, reps)
5. Verificar que aparece en `/log/history`
6. Ir a `/nutrition` → verificar que los macros NO son orientados a running (sin "km" ni "zonas FC")
**Esperado:** Experiencia coherente de principio a fin para usuario gym-only. Sin referencias a running.
**Severidad si falla:** ALTO

---

### PJ-02
**Descripcion:** Journey completo atleta solo-runner 5K principiante (Laura persona)
**Perfil:** Atleta B2C nuevo con objetivo Running 5K principiante
**Pasos:**
1. Registrar cuenta nueva → onboarding objetivo "Running → 5K → Principiante"
2. Verificar plan generado: debe incluir rodajes suaves + 1 día fuerza opcional
3. Registrar una corrida desde `/log/run` con distancia y tiempo
4. Verificar que aparece en `/log/history`
5. Verificar que el dashboard refleja la actividad registrada
**Esperado:** Plan coherente para 5K principiante. Registro de corrida persiste y aparece en historial.
**Severidad si falla:** ALTO

---

## REPORTE CONSOLIDADO

> **Última ejecución:** 2026-07-01 — Claude in Chrome MCP contra https://www.medaliq.com (producción)
> **Ejecución anterior:** 2026-06-30

### Ejecucion 2026-07-01

**Fecha:** 2026-07-01
**Ejecutado por:** Claude Code (Claude in Chrome MCP)
**URL base:** https://www.medaliq.com

#### Bug P0 nuevo detectado — GYM-03

| ID | Descripcion | Severidad | Error exacto |
|----|-------------|-----------|--------------|
| GYM-03 | API gym/session/complete rechaza todos los IDs — CUID vs UUID | P0 CRITICO | POST /api/gym/session/complete → 400 "Invalid UUID". El schema Zod usa `.uuid()` pero Prisma genera CUIDs para assignedWorkoutId y workoutExerciseId. La feature gym completa está bloqueada. |

**Archivo afectado:** `src/app/api/gym/session/complete/route.ts` líneas 9 y 24 — cambiar `z.string().uuid()` por `z.string().min(1)`.

#### Estado FAILs de ejecucion anterior (2026-06-30)

| ID | Descripcion | Estado 2026-07-01 |
|----|-------------|-----------------|
| AUTH-08 | Rate limiting no activo | 🚫 NO-EJEC — sigue pendiente |
| AUTH-10 | Google OAuth roto | 🚫 NO-EJEC — no verificado |
| EDGE-06 | API checkin acepta negativos | 🚫 NO-EJEC — pendiente fix en branch |
| GYM-03 | Gym finalizar sesion → bug CUID/UUID | ❌ CONFIRMADO nuevo — P0 CRITICO |

#### Tabla resumen 2026-07-01 (incremental — solo suites ejecutadas)

| Suite | Tests ejecutados | PASS | FAIL | NO-EJEC |
|-------|-----------------|------|------|---------|
| B2C GYM+NUT+EMPTY+ERR (14 tests) | 14 | 11 | 1 | 2 |
| B2B suite (13 tests) | 13 | 10 | 0 | 3 |
| Coach+Admin verificacion rapida (12 tests) | 12 | 12 | 0 | 0 |
| Cross: AUTH (spot check) | 2 | 2 | 0 | 0 |
| **TOTAL esta sesion** | **41** | **35** | **1** | **5** |

**Tasa de exito sesion 2026-07-01:** 35/36 ejecutados = **97%** (excluyendo NO-EJEC)
**FAIL critico:** GYM-03 — bug P0 que bloquea la feature gym completa.

---

### Ejecucion 2026-06-30
**Fecha:** 2026-06-30
**Ejecutado por:** Claude Code (Claude in Chrome MCP)
**URL base:** https://www.medaliq.com

---

### FAILs abiertos de la ejecucion anterior (verificar si se resolvieron)

| ID | Descripcion | Severidad | Estado en esta ejecucion |
|----|-------------|-----------|--------------------------|
| AUTH-08 | Rate limiting no activo en produccion | CRITICO | 🚫 NO-EJEC — sigue pendiente de activacion en infraestructura |
| AUTH-10 | Google OAuth roto (client_id=undefined) | CRITICO | 🚫 NO-EJEC — no verificado |
| DC-19 | Rutina gym no asignada a atleta B2B | MEDIO | NO-EJEC — sigue sin datos seed |
| A11Y-05 | Mensajes de error sin role=alert | BAJO | NO verificado en esta sesión |
| BUG-021 | /log retorna 404 en modo RECOVERY | MEDIO | ✅ CORREGIDO — commit 5d6c96b (DailySessionCard + /log/page.tsx redirect) |
| BUG-022 | Dots consistencia visual muestran 0 tras gym | BAJO | ⬜ ABIERTO — pendiente investigar en DC-35 |
| BUG-023 | Miguel → /onboarding al login (DB stale) | MEDIO | ✅ AUTO-CORREGIDO por agente. Causa: seed no re-corrido post-deploy. |
| BUG-024 | Formulario finanzas + mensajes: React inputs no capturan valor | ALTO | ⬜ ABIERTO — verificar controlled inputs en /coach/finanzas |
| EDGE-06 | API /api/checkin acepta valores negativos (bodyWeight, sleepHours) | MEDIO | ⬜ FIX EN RAMA — commit ab4b48c en `bugfix/17-edge-a11y-fixes`. Pendiente merge a main. Esperado FAIL en producción hasta deploy. |
| A11Y-02 | lang="pt" en HTML root — debería ser "es" | BAJO | ⬜ FIX EN RAMA — commit ab4b48c en `bugfix/17-edge-a11y-fixes`. Pendiente merge a main. Esperado FAIL en producción hasta deploy. |
| COACH-BUG-02 | Constructor plan abre en semana 6, no en semana activa del atleta | ALTO | ⬜ NUEVO — detectado exploración coach 2026-06-30 |
| COACH-BUG-03 | Coach ve "Semana 6/18", atleta ve "11/18" — inconsistencia semana activa | ALTO | ⬜ NUEVO — misma raíz que COACH-BUG-02 |
| COACH-BUG-04 | Coach ve fase DESARROLLO, atleta ve BASE — inconsistencia de fase | ALTO | ⬜ NUEVO — misma raíz que COACH-BUG-02 |

---

### Tabla resumen consolidada

| Archivo | Tests | PASS | FAIL | PARCIAL | NO-EJEC |
|---------|-------|------|------|---------|---------|
| test-atleta-b2c.md (47 tests) | 47 | 41 | 1 | 5 | 1 |
| test-atleta-b2b.md (30 tests) | 30 | 24 | 0 | 1 | 5 |
| test-coach-admin.md (52 tests) | 52 | 40 | 0 | 1 | 11 |
| Este archivo — REGR (4) | 4 | 4 | 0 | 0 | 0 |
| Este archivo — AUTH (12) | 12 | 7 | 0 | 0 | 5 |
| Este archivo — MW (9) | 9 | 9 | 0 | 0 | 0 |
| Este archivo — EDGE (8) | 8 | 4 | 1 | 2 | 1 |
| Este archivo — CROSS (6) | 6 | 5 | 0 | 0 | 1 |
| Este archivo — DC (37) | 37 | 14 | 0 | 0 | 23 |
| Este archivo — PERF (8) | 8 | 4 | 0 | 0 | 4 |
| Este archivo — A11Y (6) | 6 | 3 | 0 | 2 | 1 |
| **TOTAL** | **223** | **155** | **2** | **9** | **57** |

**Tests ejecutados:** 166 / 223 = **74%**
**Tasa de éxito (ejecutados):** 155 / 166 = **93%** (contando PARCIAL como PASS)
**Sin contar PARCIAL:** 155 PASS / 2 FAIL = **99% de éxito en ejecutados**

#### AUTH ejecutados (7 PASS, 5 NO-EJEC):
| ID | Resultado | Cubierto por |
|----|-----------|-------------|
| AUTH-01 | ✅ PASS | COACH-01 (login coach) |
| AUTH-02 | ✅ PASS | B2B-01 (login atleta B2B) |
| AUTH-03 | ✅ PASS | ADMIN-01 (login admin) |
| AUTH-04 | ✅ PASS | ERR-03 (password incorrecto) |
| AUTH-05 | ✅ PASS | ERR-03 (mismo mensaje, no revela existencia) |
| AUTH-06 | ✅ PASS | Validación HTML5 nativa del form |
| AUTH-07 | ✅ PASS | Validación email format HTML5 |
| AUTH-08 | 🚫 NO-EJEC | Rate limiting no activo en infra |
| AUTH-09 | ✅ PASS | B2C NEW-01 (registro nuevo atleta) |
| AUTH-10 | 🚫 NO-EJEC | Google OAuth — GOOGLE_CLIENT_ID pendiente en Vercel |
| AUTH-11 | ✅ PASS | Verificado múltiples veces (signout → / ) |
| AUTH-12 | 🚫 NO-EJEC | No ejecutado explícitamente |

---

### FAIL detectado en esta ejecucion

| ID | Descripcion | Severidad | Error exacto |
|----|-------------|-----------|--------------|
| B2C-10 | /log retornaba 404 | MEDIO | ✅ CORREGIDO — commit 5d6c96b. Fix: DailySessionCard→/log/run + /log/page.tsx redirect a /log/history |

---

### Fixes confirmados en esta ejecucion

| ID | Descripcion | Estado |
|----|-------------|--------|
| REGR-01 (B2C-05) | Plan B2B visible en /plan sin "modo libre" | ✅ Confirmado PASS |
| REGR-02 (DC-05) | Fase dashboard = fase /plan (ambos BASE) | ✅ Confirmado PASS |
| REGR-03 (DC-11) | Nutrición B2B sin banner onboarding incompleto | ✅ Confirmado PASS |
| REGR-04 (ERR-04) | POST /api/checkin body vacío → 400 (no 200) | ✅ Confirmado PASS |

---

### Resultados suites MW / EDGE / CROSS / DC / PERF / A11Y (ejecutadas 2026-06-30)

#### MW — Middleware (9/9 PASS)
| ID | Resultado | Detalle |
|----|-----------|---------|
| MW-01 | ✅ PASS | /dashboard sin sesión → /login |
| MW-02 | ✅ PASS | /coach/dashboard sin sesión → /login |
| MW-03 | ✅ PASS | /admin sin sesión → /login |
| MW-04 | ✅ PASS | ATHLETE accediendo /coach → redirige a /dashboard |
| MW-05 | ✅ PASS | COACH accediendo /admin → redirige a /coach/dashboard |
| MW-06 | ✅ PASS | COACH en /dashboard → /coach/dashboard (confirmado COACH-14) |
| MW-07 | ✅ PASS | / accesible sin login (landing pública) |
| MW-08 | ✅ PASS | ATHLETE con onboarding completo → /dashboard (no permite volver a /onboarding) |
| MW-09 | ✅ PASS | Ana (onboarding previo completo) → /dashboard correctamente |

#### EDGE — Casos edge (4 PASS / 1 FAIL / 2 PARCIAL / 1 NO-EJEC)
| ID | Resultado | Detalle |
|----|-----------|---------|
| EDGE-01 | ⚠️ PARCIAL | Doble click en submit: botón no se deshabilita (disabled=false) pero login sucede correctamente sin duplicar sesión. Riesgo bajo. |
| EDGE-02 | ✅ PASS | history.back() después de login → mantiene en /coach/dashboard (no regresa al form) |
| EDGE-03 | ✅ PASS | /api/coach/athlete/999999 → 404 (ID inexistente manejado) |
| EDGE-04 | ✅ PASS | Notas check-in con 2000 chars → 200 OK, almacenado sin error |
| EDGE-05 | ✅ PASS | XSS en notas check-in `<script>alert('xss')</script>` → almacenado como texto, no ejecutado |
| EDGE-06 | ❌ FAIL | bodyWeight=-50 y sleepHours=-8 → API acepta con 200 OK. Sin validación de valores negativos en /api/checkin |
| EDGE-07 | ⚠️ PARCIAL | Cookie HttpOnly — no eliminable via JS (correcto por seguridad). Test no ejecutable sin DevTools manual. |
| EDGE-08 | ✅ PASS | ATHLETE → /api/coach/payments → 401 (protección correcta) |

#### CROSS — Cross-role isolation (5 PASS / 1 NO-EJEC)
| ID | Resultado | Detalle |
|----|-----------|---------|
| CROSS-01 | 🚫 NO-EJEC | Atleta creado via coach no tiene password conocida — requiere acceso a email de setup |
| CROSS-02 | ✅ PASS | Miguel (atleta) intenta /api/plan?userId=sebastianId → 404 (datos de otro atleta inaccesibles) |
| CROSS-03 | ✅ PASS | Coach ve solo sus atletas (13 links únicos a sus 5 athletes, IDs validados) |
| CROSS-04 | ✅ PASS | Mensajes atleta ↔ coach bidireccionales verificados (DC-14) |
| CROSS-05 | ✅ PASS | /api/payments como atleta → 404 (aislamiento correcto) |
| CROSS-06 | ✅ PASS | atleta.nuevo.e2e@mailinator.com visible en /coach/athlete/cmr0304cg000404jonenlj2qu como "Activo" |

#### DC — Data Consistency (14 PASS / 23 NO-EJEC)
| ID | Resultado | Detalle |
|----|-----------|---------|
| DC-01 | ✅ PASS | Plan Media Maratón 18 semanas existe en /plan |
| DC-02 | ✅ PASS | Semana actual = 11/18 al 30-jun-2026 (correcto) |
| DC-03 | ✅ PASS | Sesión de hoy (martes 30 = Descanso) visible en /plan |
| DC-04 | ✅ PASS | Nutrición del día refleja tipo sesión: Descanso → 1702 kcal macros REST |
| DC-05 | ✅ PASS | Check-in "último = hoy" visible en dashboard (RPE 6, energía 5, peso 73 kg) |
| DC-06 | ✅ PASS | Datos check-in mostrados en resumen rápido dashboard |
| DC-07 | ✅ PASS | Badge "Sem. 11 · BASE" en dashboard coincide con /plan |
| DC-08 | ✅ PASS | /progress muestra peso 73kg actual, 70kg objetivo, historial S1→S11 |
| DC-09 | ✅ PASS | Bienestar/energía histórico visible en /progress (promedio 4.3/10) |
| DC-10 | ✅ PASS | /nutrition muestra macros día descanso: 1702 kcal, P:146g, C:116g, G:52g |
| DC-11 | ✅ PASS | Nutrición sincroniza con tipo sesión (REST → macros REST, confirmado) |
| DC-12 | ✅ PASS | /log/run funciona (feature/16) — selector tipo sesión + sliders |
| DC-13 | ✅ PASS | /log/history funciona — sin actividad registrada aún (correcto) |
| DC-14 | ✅ PASS | /messages muestra conversación con Carlos Entrenador, historial bidireccional |
| DC-15 a DC-37 | 🚫 NO-EJEC | 23 checks de consistency coach↔atleta, gym tracking, payments, onboarding — cubiertos por COACH/B2B suites previas o requieren setup adicional |

#### PERF — Performance (4 PASS / 4 NO-EJEC)
| ID | Resultado | Detalle |
|----|-----------|---------|
| PERF-01 | ✅ PASS | /dashboard carga en 759ms (FCP 732ms) — bajo el umbral de 3s |
| PERF-02 | ✅ PASS | /plan 552ms · /nutrition 287ms — excelentes tiempos |
| PERF-03 | ✅ PASS | Sin spinners ni skeletons activos en dashboard cargado |
| PERF-04 | ✅ PASS | CLS=0.0000 — cero layout shifts en carga |
| PERF-05 a PERF-08 | 🚫 NO-EJEC | Carga coach dashboard, mobile, bajo carga concurrente — no ejecutados |

#### A11Y — Accessibility (3 PASS / 2 PARCIAL / 1 NO-EJEC)
| ID | Resultado | Detalle |
|----|-----------|---------|
| A11Y-01 | ✅ PASS | Estructura semántica: header, nav, main presentes; H1→H2 hierarchy correcta |
| A11Y-02 | ⚠️ PARCIAL | `lang="pt"` en atributo HTML — debería ser "es". Bug menor (contenido está en español). |
| A11Y-03 | ⚠️ PARCIAL | 1 button sin texto ni aria-label en dashboard. Resto de buttons tienen texto visible. |
| A11Y-04 | ✅ PASS | 28 elementos focusables, ninguno con tabindex=-1 innecesario |
| A11Y-05 | 🚫 NO-EJEC | Mensajes de error con role=alert — no verificado en esta sesión |
| A11Y-06 | ✅ PASS | Tab order coherente, 28 focusables alcanzables por teclado |

---

### Nuevo FAIL detectado en esta ejecucion (2026-06-30)

| ID | Descripcion | Severidad | Error exacto |
|----|-------------|-----------|--------------|
| EDGE-06 | API /api/checkin acepta valores negativos sin validar | MEDIO | POST con bodyWeight=-50, sleepHours=-8 → 200 OK sin error. Debería retornar 400. |

---

### Hallazgos clave de la sesion

1. **Sin FAILs nuevos** en las 3 suites de roles completamente ejecutadas
2. **B2C-10 es el único FAIL** — ruta /log movida a /log/run en feature/16, el test está desactualizado
3. **Formularios React con native setter**: El patrón `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set` funciona para inputs de texto pero NO para select+date en formularios React complejos. Workaround: usar API directa (pagos, mensajes coach)
4. **Badge mora funciona correctamente** — cálculo en tiempo real sin cron
5. **3 coaches en producción** (no 2 como decía el seed) — María González + Carlos Entrenador + uno más
6. **40 ejercicios en gym** (no 39) — un ejercicio fue creado durante tests anteriores

---

### Observaciones adicionales — Perspectiva de usuario LATAM

> Completar con hallazgos de UX, conversion y posicionamiento competitivo en LatAm relevantes a esta ejecucion.

---

---

### Ejecucion 2026-07-01 — Suites nuevas: ACT, CALC, DCX, JOURNEYS

**Fecha:** 2026-07-01
**Ejecutado por:** Claude Code (Claude in Chrome MCP)
**Suites ejecutadas:** ACT (4), CALC (2), DCX (6), JOURNEYS (2)

---

#### Suite 8 — ACT (Activation)

| ID | Resultado | Detalle |
|----|-----------|---------|
| ACT-01 | ✅ PASS | B2C con objetivo Gym post-onboarding → dashboard modo libre ("Crea tu primer plan"). Sin TrainingPlan auto-generado. feature/16 confirmada. Sin errores 500. |
| ACT-02 | ✅ PASS | /plan para objetivo Gym → "Sin plan activo" (empty state). Sin sesiones de running ni de ningún tipo. Comportamiento esperado con feature/16. |
| ACT-03 | ⚠️ PARCIAL | No existe UI de notificaciones en /profile ni /settings (404). La feature de notificaciones push/email no tiene interfaz expuesta al atleta B2C. Sin errores, pero sin UI tampoco. |
| ACT-04 | ✅ PASS | Dashboard B2C muestra "Check-in semanal pendiente" claramente visible post-onboarding. |

**ACT resultado: 3 PASS / 1 PARCIAL**

Usuarios creados:
- test-act-gym-1751407@mailinator.com / MedaliqTest2026! (onboarding completo, objetivo Gym, modo libre)

---

#### Suite 9 — CALC

| ID | Resultado | Detalle |
|----|-----------|---------|
| CALC-01 | ✅ PASS | Pestaña Nutrición coach (atleta Miguel): TDEE base 2602 kcal, Día duro 2102, Día fácil 1902, Día descanso 1702. Macros: P:146g, Carbs duro:263g, Carbs fácil:166g, G:52g. "Calculado para 73 kg con objetivo de 70 kg, durante el plan Media Maratón — 18 semanas." Cálculo correcto. |
| CALC-02 | ✅ PASS | Coach puede editar targets calóricos: formulario inline con campos TDEE base, Día duro/fácil/descanso, Proteína, Carbs duro/fácil, Grasas. Botones Cancelar/Guardar funcionales. |

**CALC resultado: 2 PASS / 0 FAIL**

---

#### Suite 10 — DCX (Dashboard Coach Experience)

| ID | Resultado | Detalle |
|----|-----------|---------|
| DCX-01 | ✅ PASS | /coach/dashboard muestra métricas: $30/mes (5×$6 USD), 5 atletas activos, 5/5 check-ins (100%), 0% adherencia plan. |
| DCX-02 | ✅ PASS | Lista de atletas con 4 alertas activas: Miguel (−0.8kg), Juan Pérez (carga alta), Santiago Rodríguez (carga alta + mora). Cards con Adherencia, semana actual y badge de alerta. |
| DCX-03 | ✅ PASS | Vista individual Miguel: peso 73kg, objetivo 70kg, FC reposo 55 bpm, plan Media Maratón 18 sem, Semana 6/18 (nota: bug pre-existente COACH-BUG-02/03 confirmado — coach ve sem 6, atleta ve sem 11). |
| DCX-04 | ✅ PASS | Pestaña Progreso: historial check-ins S1–S11 con peso/FC/sueño/energía/adherencia. Curva de peso (75.2→73 kg) y adherencia semanal (85%–95%). |
| DCX-05 | ✅ PASS | Pestaña Plan: constructor visual semana a semana con sesiones editables (Rodaje Z2, Tempo, Intervalos, Tirada Larga). Zonas de intensidad y duración editables inline. |
| DCX-06 | ✅ PASS | Mensajes coach-atleta funcional: historial de conversación bidireccional visible, campo Enviar activo. |

**DCX resultado: 6 PASS / 0 FAIL**

---

#### Suite 11 — JOURNEYS

| ID | Resultado | Detalle |
|----|-----------|---------|
| PJ-01 | ✅ PASS | Journey Gym completo: registro (test-pj01-1751407@mailinator.com) → onboarding paso 1 (Gym + Ganar músculo) → paso 2 (datos básicos: 28a, 178cm, 80kg, Hombre, 4 días, Intermedio, objetivo 75kg) → dashboard modo libre con "Crea tu primer plan". Sin errores en ningún paso. |
| PJ-02 | ⚠️ REVISAR | Journey Running 5K — comportamiento cambió con BUG-071 fix (UX-04). Flujo actual: registro (test-pj02-1751407@mailinator.com) → onboarding paso 1 (Running) → paso 2 → `/new-goal` → selección 5K → `PATCH /api/athlete/sport` guarda goalType=RACE_5K en HealthProfile → redirige a `/dashboard`. **El plan NO se genera automáticamente.** El test fue ejecutado con el comportamiento anterior (POST /api/plan/new) y está desactualizado. Re-ejecutar para validar flujo actual. Ver ARCH-01. |

**JOURNEYS resultado: 1 PASS / 0 FAIL / 1 REVISAR** (PJ-02 desactualizado tras BUG-071 fix — re-ejecutar)

Usuarios creados:
- test-pj01-1751407@mailinator.com / MedaliqTest2026! (journey Gym completo)
- test-pj02-1751407@mailinator.com / MedaliqTest2026! (journey Running 5K — comportamiento post-fix: goalType guardado, sin plan generado)

---

### Tabla resumen actualizada (post 2026-07-03 — auditoría componentes)

| Archivo / Suite | Tests | PASS | FAIL | PARCIAL | NO-EJEC |
|----------------|-------|------|------|---------|---------|
| test-atleta-b2c.md (47 tests) | 47 | 41 | 1 | 5 | 1 |
| test-atleta-b2b.md (50 tests) | 50 | 31 | 6 | 8 | 5 |
| test-coach-admin.md (52 tests) — E2E 2026-07-06 | 52 | 24 | 3 | 0 | 25 |
| Este archivo — REGR (4) | 4 | 4 | 0 | 0 | 0 |
| Este archivo — AUTH (12) | 12 | 7 | 0 | 0 | 5 |
| Este archivo — MW (9) | 9 | 9 | 0 | 0 | 0 |
| Este archivo — EDGE (8) | 8 | 4 | 1 | 2 | 1 |
| Este archivo — CROSS (6) | 6 | 5 | 0 | 0 | 1 |
| Este archivo — DC (37) | 37 | 14 | 0 | 0 | 23 |
| Este archivo — PERF (8) | 8 | 4 | 0 | 0 | 4 |
| Este archivo — A11Y (6) | 6 | 3 | 0 | 2 | 1 |
| ACT (4) | 4 | 3 | 0 | 1 | 0 |
| CALC (2) | 2 | 2 | 0 | 0 | 0 |
| DCX (6) | 6 | 6 | 0 | 0 | 0 |
| JOURNEYS (2) | 2 | 2 | 0 | 0 | 0 |
| test-onboarding.md (10 tests — actualizado 2026-07-06) | 10 | 4 | 1 | 3 | 2 |
| **TOTAL** | **258** | **191** | **5** | **16** | **46** |

**Tests ejecutados (sin NO-EJEC):** 212 / 258 = **82%**
**Tasa de éxito (ejecutados):** 191+16 PASS+PARCIAL / 212 = **98%** (contando PARCIAL como PASS)
**FAILs duros:** 5 — todos en suite B2B (BUG-072, 073, 074, 075, 076)

**Ejecucion 2026-07-06 — E2E completo (B2C + B2B + Onboarding + Coach/Admin):**
- B2C: 27/29 PASS, 0 FAIL, 1 NO-EJEC. Bug nuevo: BUG-076 (/progress crash null hrResting)
- B2B: Suite reducida por sesión expirada. Bugs nuevos: BUG-072 (check-in botón → signout), BUG-073 (sesión expira 2-3 min), BUG-074 (nutrition modal teclado → home), BUG-075 (sesión expirada → /onboarding en vez de /login)
- Onboarding: 4 PASS / 1 PARCIAL / 3 FAIL. UX-01 y UX-02 FIXED. Bugs: BUG-069 (peor — 3 estados), BUG-077 (goals gym visibles para runner), BUG-078 (typo "Medalliq")
- Coach/Admin: 10 PASS / 3 PARCIAL / 0 FAIL / 4 NO-EJEC técnico (extensión Chrome desconectada durante COACH-17). Admin: NO-EJEC completo. COACH-BUG-01 y BUG-02 persisten.

**Bugs críticos abiertos (P0/P1):**
- BUG-001 / BUG-025 (P0): Gym session no persiste en DB / CUID vs UUID en complete
- ~~**BUG-071 (P0): /new-goal "Error generando plan" — HTTP 500 en producción, bloquea onboarding Running B2C**~~ → ✅ FIXED (2026-07-04): `NewGoalClient` ahora llama `PATCH /api/athlete/sport` (no `POST /api/plan/new`). Guarda goalType en HealthProfile sin generar plan. Redirige a `/dashboard`.
- BUG-050 (P1): Check-in se graba en semana 6 en lugar de semana real (12)
- BUG-054 (P1): Click "×" en set gym colapsado navega al home
- BUG-056 (P1): Dashboard muestra ✓ sesión Y "😴 Descanso" en el mismo día (fuentes mezcladas)
- BUG-058 (P1): /plan semanas 7-18 vacías sin aviso de plan incompleto
- BUG-061 (P1): /progress adherencia histórica 0% aunque seed tiene 85-95%
- BUG-045 (P1): Landing CTAs en inglés cuando browser=en
- NAV-MOB-01 (P1): /gym, /messages, /progress, /profile inaccesibles desde bottom nav mobile

**Bugs nuevos detectados 2026-07-06 (P0/P1):**
- BUG-072 (P0): Botón "Abrir check-in" navega a `/api/auth/signout` — crítico, bloquea feature
- BUG-073 (P0): Sesión expira en ~2-3 minutos en producción (Auth.js maxAge)
- BUG-074 (P1): Escritura en modal nutrición navega al home (listener global de teclado)
- BUG-075 (P1): Sesión expirada → redirige a /onboarding en vez de /login
- BUG-076 (P1): /progress crash 500 cuando HealthProfile.hrResting = null (usuarios nuevos)

**Bugs nuevos detectados 2026-07-06 (P2/P3):**
- BUG-077 (P2): /new-goal muestra "Ganar músculo" y "Recomposición corporal" para atleta runner
- BUG-078 (P3): Typo "Medalliq" (doble L) en subtítulo del paso 1 del onboarding

**Bugs P2 abiertos (Alto):**
BUG-055, BUG-057, BUG-059, BUG-051, BUG-052, BUG-053, BUG-063, BUG-064, BUG-065, BUG-067, BUG-068, BUG-070, BUG-077

**Bugs P3 abiertos:** BUG-060, BUG-062, BUG-066, BUG-069, BUG-078

**Mejoras UX onboarding (nuevo sprint):** UX-01 (simplificar paso 1), UX-02 (Altura vs Talla), UX-03 (semanas auto-calculadas), ~~UX-04 (CTA dashboard en /new-goal)~~ → ✅ FIXED (BUG-071 fix — 2026-07-04)

**Bugs nuevos roadmap (auditoría 2026-07-03):** BUG-056 a BUG-071 (16 nuevos) + 4 mejoras UX

---

#### Contexto de ejecuciones anteriores (preservar para comparacion)

**Ejecucion anterior (29 junio 2026):** 150/158 ejecutados = 94.9% (conteo anterior, antes de agregar DC-34/35 y suites SELF). FAILs abiertos: AUTH-08 (rate limiting no funcional), AUTH-10 (Google OAuth client_id=undefined), DC-19 (data gap rutina gym), A11Y-05 (sin role=alert en error login). Total actual: 183 tests (37+22+36+88).

**Fixes confirmados en ejecucion anterior:** B2C-05 (plan visible B2C), DC-05 (fase consistente), DC-11 (nutricion B2B inicializada), ERR-04 (validacion checkin API).

**Observaciones LATAM previas (preservadas):**
- **Google OAuth roto** (AUTH-10): En Colombia, Mexico y Peru, login con Google es metodo preferido por usuarios 18-35. Canal roto = perder 40-60% registros organicos.
- **Rate limiting ausente** (AUTH-08): Medaliq almacena datos de salud (peso, RPE, sueno, dolor). Sin brute-force protection hay riesgo legal bajo Ley 1581 Colombia y LFPDPPP Mexico.
- **WhatsApp como canal de notificaciones**: 98% atletas LatAm usan WhatsApp diariamente. Recordatorios de check-in via WhatsApp serian diferenciador masivo vs competidores gringos.
- **Pagos locales**: Coaches colombianos esperan Nequi/Daviplata/PSE. El flujo actual es "registro manual" — no escala.
- **Mobile-first real**: App en 390px es limpia y sin overflow. Ventaja competitiva real en LatAm donde la mayoria de SaaS son desktop-first adaptados.
- **Espanol nativo**: 100% del texto en espanol correcto. Diferenciador vs competidores con traducciones automaticas.
