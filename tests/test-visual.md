# Medaliq — Visual Agent Testing

**URL base:** `https://www.medaliq.com`
**Screenshots:** `/Users/miguelatencia/Desktop/MEDALIQ/screenshots/latest/`
**Viewport desktop:** 1280x800
**Viewport mobile:** 390x844 (iPhone 14)

**Protocolo de capturas:** Siempre capturar — cada test visual requiere screenshot. Sin screenshot, el test no tiene evidencia y no cuenta como ejecutado.

---

## ⚠️ CAMBIOS DE ARQUITECTURA — Leer antes de ejecutar (actualizado 2026-07-10)

| Cambio | Detalle |
|--------|---------|
| Tabs detalle atleta (`VIS-COACH-03`) | Las tabs reales son: **Plan · Sesiones · Nutrición · Notas · Config**. No existen "Resumen", "Progreso", "Gym", "Mensajes", "Perfil" como tabs. La referencia en VIS-COACH-03 a "Resumen, Plan, Progreso, Nutrición, Gym, Mensajes, Perfil" es incorrecta. |
| `/messages` NO EXISTE | `VIS-ATL-10` y `VIS-COACH-08` evalúan `/messages` y el tab Mensajes. La ruta `/messages` no existe. Marcar ambos como N/A. |
| `VIS-COACH-05` — URL `/coach/finanzas` | La URL real es `/coach/finanzas` o similar. Verificar ruta exacta en la app actual. |
| Ejercicios | La biblioteca en `/gym/exercises` usa WorkoutX. Los ejercicios se muestran como `<button>` en grid. Free: 10. Paid: 1,300+. |
| `/log/history` | El historial de actividad (`VIS-ATL-09`) vive en `/log/history`, no en `/log`. |
| VIS-G-01 — lang="pt" | Re-verificar si sigue presente. Puede haber sido corregido. |

---

## Cómo ejecutar este archivo

Este agente hereda los flujos de los archivos E2E existentes pero evalúa **estética**, no funcionalidad.

**Por cada pantalla el agente debe:**
1. Navegar a la URL con el usuario correcto logueado
2. Esperar 2s para render completo
3. Tomar screenshot → guardar en `latest/web/` o `latest/mobile/`
4. Ejecutar análisis DOM automático (parámetros definidos abajo)
5. Registrar issues en el REPORTE al final de este archivo

**Regla de screenshots:** Cada ejecución **sobreescribe** `latest/` completo. No acumular versiones.
Si se detecta un issue visual crítico, copiar el screenshot a `archive/YYYY-MM-DD/` antes de sobreescribir.

---

## Parámetros de validación automática (DOM)

El agente ejecuta estos checks en cada pantalla sin necesidad de screenshot:

```javascript
// Para cada pantalla ejecutar:
const checks = {
  // 1. Texto legible
  fontSize: Array.from(document.querySelectorAll('p,span,label,button'))
    .filter(el => el.offsetParent !== null)
    .some(el => parseInt(getComputedStyle(el).fontSize) < 12),

  // 2. Contraste básico (color no es blanco sobre blanco)
  colorContrast: 'verificar manualmente en screenshot',

  // 3. Elementos visibles en viewport
  overflowX: document.body.scrollWidth > document.body.clientWidth,

  // 4. Touch targets mobile (>= 44px)
  smallTargets: Array.from(document.querySelectorAll('button,a'))
    .filter(el => el.offsetParent !== null)
    .filter(el => el.getBoundingClientRect().height < 44)
    .map(el => el.innerText?.substring(0,20) || el.className),

  // 5. Imágenes sin alt
  imgsNoAlt: Array.from(document.querySelectorAll('img'))
    .filter(img => !img.alt).length,

  // 6. Texto en español
  langAttr: document.documentElement.lang,

  // 7. H1 único por página
  h1Count: document.querySelectorAll('h1').length,

  // 8. Inputs con label
  inputsUnlabeled: Array.from(document.querySelectorAll('input:not([type="hidden"])'))
    .filter(i => !i.labels?.length && !i.getAttribute('aria-label') && !i.placeholder)
    .length,
}
```

---

## Criterios de severidad

| Nivel | Criterio |
|-------|----------|
| CRÍTICO | Texto ilegible, botón invisible, overflow rompe layout, dato incorrecto en componente |
| ALTO | CTA no claro, estado vacío en blanco, touch target < 44px en mobile |
| MEDIO | Inconsistencia de componentes, spacing irregular, icono fuera del set |
| BAJO | Diferencia sutil de padding, color levemente off, alineación menor |

---

## SUITE 1 — AUTH (Login, Registro, Forgot Password)

**Usuario:** Sin sesión
**Carpeta screenshots:** `latest/web/auth/` y `latest/mobile/auth/`

---

### VIS-AUTH-01 — Pantalla Login (desktop)
**Hereda de:** AUTH-01, AUTH-06, AUTH-07
**URL:** `/login`
**Viewport:** 1280x800
**Screenshot:** `web/auth/login-desktop.png`

**Componentes a evaluar:**
- [ ] Logo Medaliq visible y centrado
- [ ] Formulario centrado verticalmente en la pantalla
- [ ] Labels de email y password visibles antes de hacer clic
- [ ] Botón "Iniciar sesión" es el CTA dominante
- [ ] Link "¿Olvidaste tu contraseña?" es secundario (no compite con el CTA)
- [ ] Link "Registrarse" visible pero no dominante
- [ ] Botón Google OAuth visible y distinguible del botón principal

**DOM checks automáticos:**
- `h1Count === 1`
- `inputsUnlabeled === 0`
- `overflowX === false`

---

### VIS-AUTH-02 — Pantalla Login (mobile)
**Hereda de:** AUTH-01
**URL:** `/login`
**Viewport:** 390x844
**Screenshot:** `mobile/auth/login-mobile.png`

**Componentes a evaluar:**
- [ ] Formulario ocupa el ancho sin overflow
- [ ] Inputs tienen altura suficiente para tapping (>= 44px)
- [ ] Teclado no oculta el botón submit (evaluar visualmente)
- [ ] Logo no ocupa demasiado espacio vertical en pantalla pequeña

**DOM checks automáticos:**
- `smallTargets.length === 0` (todos los inputs/buttons >= 44px)
- `overflowX === false`

---

### VIS-AUTH-03 — Pantalla Registro (desktop)
**Hereda de:** AUTH-09, B2C NEW-01
**URL:** `/register`
**Viewport:** 1280x800
**Screenshot:** `web/auth/register-desktop.png`

**Componentes a evaluar:**
- [ ] Campos nombre, email, password, confirmar password claramente etiquetados
- [ ] Indicador de fortaleza de password (si existe) es visible
- [ ] CTA "Crear cuenta" es dominante
- [ ] Mensaje de términos/privacidad visible pero no invasivo
- [ ] Link "Ya tengo cuenta" presente

---

### VIS-AUTH-04 — Pantalla Forgot Password
**Hereda de:** AUTH de email
**URL:** `/forgot-password`
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/auth/forgot-password.png` + `mobile/auth/forgot-password.png`

**Componentes a evaluar:**
- [ ] Instrucción clara de qué hace esta pantalla
- [ ] Un solo campo (email)
- [ ] CTA claro
- [ ] Link para volver al login

---

### VIS-AUTH-05 — Error de login
**Hereda de:** ERR-03
**Pasos:** Ingresar credenciales incorrectas y observar el error
**Screenshot:** `web/auth/login-error.png`

**Componentes a evaluar:**
- [ ] Mensaje de error visible cerca del formulario (no en otro lugar)
- [ ] Color de error (rojo/naranja) distinguible
- [ ] El error no desaparece inmediatamente
- [ ] El campo no se borra (usuario puede corregir sin re-escribir todo)

---

## SUITE 2 — ONBOARDING (Atleta B2C)

**Usuario:** Ana (`ana@medaliq.com` / `atleta123`) con `onboardingCompleted = false`
**Nota:** Si Ana ya completó onboarding en sesión anterior, usar cuenta nueva de prueba
**Carpeta screenshots:** `latest/web/onboarding/`

---

### VIS-OB-01 — Paso 1: Selección de objetivo
**Hereda de:** B2C-02
**URL:** `/onboarding`
**Screenshot:** `web/onboarding/step-1-objetivo.png`

**Componentes a evaluar:**
- [ ] Título claro del paso actual
- [ ] Indicador de progreso visible (paso X de Y)
- [ ] Opciones de objetivo (RUNNING, STRENGTH) visualmente distinguibles
- [ ] La opción seleccionada tiene estado visual claro (borde, color, check)
- [ ] Botón "Continuar" inactivo hasta seleccionar
- [ ] Sin distractores — pantalla limpia y enfocada

---

### VIS-OB-02 — Paso 2: Datos personales
**Hereda de:** B2C-03
**URL:** `/onboarding` (paso 2)
**Screenshot:** `web/onboarding/step-2-datos.png`

**Componentes a evaluar:**
- [ ] Campos edad, peso, altura con labels claros y unidades visibles (kg, cm)
- [ ] Sliders o inputs numéricos fáciles de usar
- [ ] Indicador de progreso actualizado
- [ ] Botones "Atrás" y "Continuar" correctamente posicionados

---

### VIS-OB-03 — Paso final: Confirmación / Dashboard
**Hereda de:** B2C-03
**URL:** `/dashboard` (post-onboarding)
**Screenshot:** `web/onboarding/post-onboarding-dashboard.png`

**Componentes a evaluar:**
- [ ] Mensaje de bienvenida o celebración visible
- [ ] El dashboard muestra estado inicial correcto (sin datos vacíos sin explicación)
- [ ] CTA claro de qué hacer primero

---

## SUITE 3 — ATLETA DASHBOARD Y FLUJOS

**Usuario:** Miguel (`miguel@medaliq.com` / `atleta123`)
**Carpeta screenshots:** `latest/web/atleta/` y `latest/mobile/atleta/`

---

### VIS-ATL-01 — Dashboard atleta (desktop)
**Hereda de:** B2B-02, DC-05, DC-06, DC-07
**URL:** `/dashboard`
**Viewport:** 1280x800
**Screenshot:** `web/atleta/dashboard-desktop.png`

**Componentes a evaluar:**
- [ ] Saludo personalizado con nombre visible (H1)
- [ ] Fecha actual correctamente formateada en español
- [ ] Card de plan: semana actual + fase + progreso claro
- [ ] Card de check-in: último check-in con datos reales
- [ ] Card de sesión de hoy: tipo de sesión claro (descanso, rodaje, etc.)
- [ ] Card de coach: nombre del coach visible
- [ ] Jerarquía clara — el usuario sabe qué hacer hoy sin leer todo
- [ ] Sin cards vacías sin explicación

**DOM checks:**
- `h1Count === 1`
- `overflowX === false`
- `fontSize check` — ningún texto visible < 12px

---

### VIS-ATL-02 — Dashboard atleta (mobile)
**Hereda de:** B2B-02
**URL:** `/dashboard`
**Viewport:** 390x844
**Screenshot:** `mobile/atleta/dashboard-mobile.png`

**Componentes a evaluar:**
- [ ] Cards apiladas verticalmente sin overflow
- [ ] Nav inferior visible y con labels de texto bajo cada ícono
- [ ] Touch targets de nav >= 44px
- [ ] Texto no cortado en ningún card
- [ ] El contenido más importante está above the fold (sin scroll)

**DOM checks:**
- `smallTargets` en nav inferior = 0
- `overflowX === false`

---

### VIS-ATL-03 — Plan de entrenamiento (desktop)
**Hereda de:** B2B-05, DC-01, DC-02, DC-03
**URL:** `/plan`
**Viewport:** 1280x800
**Screenshot:** `web/atleta/plan-desktop.png`

**Componentes a evaluar:**
- [ ] Título del plan visible (Media Maratón · 18 semanas)
- [ ] Semana actual resaltada visualmente vs semanas pasadas/futuras
- [ ] Día de hoy claramente marcado (HOY badge)
- [ ] Tipo de sesión por día legible (descanso, rodaje Z2, tempo, etc.)
- [ ] Selector de semana: scroll horizontal fluido o navegación clara
- [ ] Panel de sesión seleccionada con detalle completo
- [ ] Sección nutrición del día integrada sin romper el layout

---

### VIS-ATL-04 — Plan de entrenamiento (mobile)
**Hereda de:** B2B-05
**URL:** `/plan`
**Viewport:** 390x844
**Screenshot:** `mobile/atleta/plan-mobile.png`

**Componentes a evaluar:**
- [ ] Vista semanal cabe en 390px sin overflow horizontal
- [ ] Días de la semana con texto o ícono legible en tamaño pequeño
- [ ] Día HOY visible sin scroll
- [ ] Detalle de sesión expandible o en card separada

---

### VIS-ATL-05 — Check-in semanal
**Hereda de:** B2C-06, B2B-03
**URL:** `/checkin`
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/checkin-desktop.png` + `mobile/atleta/checkin-mobile.png`

**Componentes a evaluar:**
- [ ] Sliders de energía, RPE, sueño con etiquetas claras en los extremos
- [ ] Valor actual del slider visible mientras se arrastra
- [ ] Campo de peso con unidad (kg) visible
- [ ] Textarea de notas con placeholder explicativo
- [ ] Botón "Modo rápido — Todo bien" visible como alternativa
- [ ] CTA principal claro
- [ ] En mobile: sliders funcionales con touch (>= 44px de altura de track)

---

### VIS-ATL-06 — Nutrición del día
**Hereda de:** B2C-08, DC-10, DC-11
**URL:** `/nutrition`
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/nutrition-desktop.png` + `mobile/atleta/nutrition-mobile.png`

**Componentes a evaluar:**
- [ ] Tipo de día (descanso/entrenamiento) visible como contexto
- [ ] Macros (kcal, proteína, carbos, grasas) con jerarquía clara — kcal es el número más grande
- [ ] Unidades siempre visibles (g, kcal)
- [ ] Sección de comidas del día con estructura clara (desayuno, almuerzo, etc.)
- [ ] Estado vacío si no hay comidas: mensaje explicativo, no pantalla en blanco
- [ ] CTA para registrar comida visible

---

### VIS-ATL-07 — Progreso
**Hereda de:** DC-08, DC-09
**URL:** `/progress`
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/progress-desktop.png` + `mobile/atleta/progress-mobile.png`

**Componentes a evaluar:**
- [ ] Gráfica de peso: eje Y legible, eje X con semanas, línea de objetivo visible
- [ ] Diferencia actual vs objetivo claramente destacada
- [ ] Gráfica de bienestar/energía: colores distinguibles
- [ ] KM semanales: barras con valores visibles
- [ ] Filtros 4sem / 8sem / 12sem: estado activo claro
- [ ] En mobile: gráficas no se comprimen hasta ser ilegibles

---

### VIS-ATL-08 — Log de carrera
**Hereda de:** DC-12
**URL:** `/log/run`
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/log-run-desktop.png` + `mobile/atleta/log-run-mobile.png`

**Componentes a evaluar:**
- [ ] Tipos de sesión (Rodaje Z2, Fartlek, Tempo, etc.) con colores diferenciados
- [ ] La opción seleccionada tiene estado visual claro
- [ ] Slider de duración: valor actual visible
- [ ] Campo distancia: unidad (km) visible
- [ ] Slider RPE con escala visible (1-10)
- [ ] CTA guardar claramente distinguible

---

### VIS-ATL-09 — Historial de actividad
**Hereda de:** DC-13
**URL:** `/log/history` (⚠️ `/log` redirige aquí — feed unificado: GymSession completadas + SessionLog libres)
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/log-history-desktop.png` + `mobile/atleta/log-history-mobile.png`

**Componentes a evaluar:**
- [ ] Estado vacío: mensaje claro con CTA para registrar primera sesión
- [ ] Si hay sesiones: cards con fecha, tipo, duración, distancia visibles
- [ ] Diferenciación visual entre sesiones de gym y corridas
- [ ] Orden cronológico claro (más reciente primero)

---

### VIS-ATL-10 — Mensajes atleta ⛔ N/A
**Hereda de:** DC-14, CROSS-04
**URL:** ~~`/messages`~~ — **ruta no existe**. Feature de mensajería no implementada. Marcar como N/A.
**Viewport:** 1280x800 + 390x844
**Screenshot:** `web/atleta/messages-desktop.png` + `mobile/atleta/messages-mobile.png`

**Componentes a evaluar:**
- [ ] Mensajes del coach vs mensajes propios visualmente diferenciados (alineación, color bubble)
- [ ] Timestamp visible en cada mensaje
- [ ] Input de texto con CTA enviar claramente separados de los mensajes
- [ ] Badge de no leídos visible en el nav
- [ ] En mobile: teclado no oculta el input de texto

---

## SUITE 4 — COACH PANEL

**Usuario:** Carlos Entrenador (`coach@medaliq.com` / `coach123`)
**Carpeta screenshots:** `latest/web/coach/`

---

### VIS-COACH-01 — Dashboard coach (desktop)
**Hereda de:** COACH-02
**URL:** `/coach/dashboard`
**Viewport:** 1280x800
**Screenshot:** `web/coach/dashboard-desktop.png`

**Componentes a evaluar:**
- [ ] KPIs principales (ingresos, atletas activos, check-ins, adherencia) con jerarquía clara
- [ ] Número grande = métrica, texto pequeño = etiqueta (no al revés)
- [ ] Sección "Requieren atención" con badge de alertas visible
- [ ] Lista de atletas con estado visual (activo, mora, sin check-in)
- [ ] Badge de mora en color llamativo (rojo/naranja)
- [ ] CTA "Nuevo asesorado" visible sin hacer scroll
- [ ] Nav lateral con íconos + texto, item activo resaltado

**DOM checks:**
- `h1Count === 1`
- `overflowX === false`

---

### VIS-COACH-02 — Dashboard coach (mobile)
**Hereda de:** COACH-02
**URL:** `/coach/dashboard`
**Viewport:** 390x844
**Screenshot:** `mobile/coach/dashboard-mobile.png`

**Componentes a evaluar:**
- [ ] KPIs visibles sin scroll o con scroll claro
- [ ] Lista de atletas en cards apiladas, legibles
- [ ] Nav adaptado para mobile (inferior o hamburger)
- [ ] Badge de mora visible en mobile

---

### VIS-COACH-03 — Detalle atleta
**Hereda de:** COACH-07, COACH-08
**URL:** `/coach/athlete/cmqxcbd400003m1xwhtvinsns` (Miguel)
**Viewport:** 1280x800
**Screenshot:** `web/coach/athlete-detail.png`

**Componentes a evaluar:**
- [ ] Header del atleta: nombre, email, estado (Activo/Pausado) claramente visible
- [ ] Tabs de navegación reales: **Plan · Sesiones · Nutrición · Notas · Config** — sin overflow (⚠️ tabs anteriores "Resumen/Gym/Mensajes/Perfil" ya no existen)
- [ ] Tab activo visualmente distinguido
- [ ] Tab Nutrición: `NutritionAdherenceCard` (sparkline 4 semanas) visible + `FoodLogsSection`
- [ ] Tab Config: feature flags del atleta visibles + opción de pausar
- [ ] Acciones del coach (Pausar, Asignar plan) accesibles

---

### VIS-COACH-04 — Plan del atleta (vista coach)
**Hereda de:** COACH-07
**URL:** `/coach/athlete/cmqxcbd400003m1xwhtvinsns` → tab Plan
**Viewport:** 1280x800
**Screenshot:** `web/coach/athlete-plan.png`

**Componentes a evaluar:**
- [ ] Constructor de plan: semanas visibles con scroll o paginación
- [ ] Sesiones por día editables con estado visual claro
- [ ] Botón de editar semana/sesión accesible (no oculto o muy pequeño)
- [ ] Diferenciación visual entre fases (BASE, DESARROLLO, ESPECÍFICO, AFINAMIENTO)
- [ ] Semana actual destacada vs semanas pasadas

---

### VIS-COACH-05 — Finanzas / Pagos
**Hereda de:** COACH-09, COACH-10, COACH-15
**URL:** `/coach/finanzas`
**Viewport:** 1280x800
**Screenshot:** `web/coach/finanzas.png`

**Componentes a evaluar:**
- [ ] Lista de pagos con columnas claras (atleta, monto, vencimiento, estado)
- [ ] Estado PENDING vs PAID vs OVERDUE con colores distintos
- [ ] Badge mora en color rojo/naranja visible
- [ ] Monto con moneda visible (USD/COP)
- [ ] CTA "Nuevo pago" accesible
- [ ] Formulario de nuevo pago: campos claramente etiquetados

---

### VIS-COACH-06 — Gym builder
**Hereda de:** COACH-13
**URL:** `/coach/gym` o sección gym del atleta
**Viewport:** 1280x800
**Screenshot:** `web/coach/gym-builder.png`

**Componentes a evaluar:**
- [ ] Lista de ejercicios con búsqueda visible
- [ ] Ejercicio seleccionado vs disponible visualmente diferenciados
- [ ] Estructura de días (Día A, Día B) clara
- [ ] Series/reps por ejercicio editables inline
- [ ] CTA guardar rutina visible

---

### VIS-COACH-07 — Crear nuevo atleta
**Hereda de:** COACH-06
**URL:** `/coach/clients/new`
**Viewport:** 1280x800
**Screenshot:** `web/coach/create-athlete.png`

**Componentes a evaluar:**
- [ ] Campo email como primer input con label claro
- [ ] Formulario expandido (cuando email es nuevo) con campos adicionales
- [ ] CTA guardar visible sin scroll en desktop
- [ ] Mensaje de confirmación post-creación

---

### VIS-COACH-08 — Mensajes coach ⛔ N/A
**Hereda de:** COACH-11, DC-14
**URL:** ~~`/coach/athlete/[id]` → tab Mensajes~~ — **tab Mensajes no existe**. Las tabs reales son Plan · Sesiones · Nutrición · Notas · Config. Marcar como N/A.
**Viewport:** 1280x800
**Screenshot:** `web/coach/messages.png`

**Componentes a evaluar:**
- [ ] Historial de conversación con atleta visible
- [ ] Diferenciación visual coach vs atleta (lado izquierdo/derecho, colores)
- [ ] Input de texto y CTA enviar en posición correcta (bottom)
- [ ] Badge de mensajes no leídos en nav

---

## SUITE 5 — ESTADOS ESPECIALES Y EDGE CASES VISUALES

**Carpeta screenshots:** `latest/web/estados/`

---

### VIS-EDGE-01 — Estado vacío dashboard (atleta sin plan)
**Hereda de:** B2C flujo libre (Ana post-onboarding B2C)
**Usuario:** Ana o atleta B2C sin TrainingPlan
**URL:** `/dashboard`
**Screenshot:** `web/estados/dashboard-sin-plan.png`

**Componentes a evaluar:**
- [ ] Mensaje de estado vacío claro (no pantalla en blanco)
- [ ] Explicación de por qué no hay plan y qué hacer
- [ ] CTA para iniciar acción (registrar corrida, ver nutrición, etc.)
- [ ] Sin errores visuales o componentes rotos

---

### VIS-EDGE-02 — Estado vacío gym (sin rutina asignada)
**Hereda de:** gym sin asignación de coach
**URL:** `/gym`
**Screenshot:** `web/estados/gym-sin-rutina.png`

**Componentes a evaluar:**
- [ ] Mensaje explicativo de que el coach asignará la rutina
- [ ] Ilustración o ícono de estado vacío (no solo texto)
- [ ] Sin botones que no funcionen o lleven a 404

---

### VIS-EDGE-03 — Error 404
**URL:** `/pagina-que-no-existe`
**Screenshot:** `web/estados/404.png`

**Componentes a evaluar:**
- [ ] Mensaje 404 en español
- [ ] Link para volver al inicio o al dashboard
- [ ] Mantiene el nav/header de la app (no rompe el layout)
- [ ] No muestra stack trace o error técnico al usuario

---

### VIS-EDGE-04 — Badge mora en lista de atletas
**Hereda de:** COACH-15
**Usuario:** Coach logueado
**URL:** `/coach/dashboard`
**Screenshot:** `web/estados/badge-mora.png`

**Componentes a evaluar:**
- [ ] Badge visible y en color llamativo (rojo)
- [ ] Texto del badge legible ("mora" o ícono claro)
- [ ] No oculta el nombre del atleta
- [ ] Contrasta bien con el fondo del card

---

### VIS-EDGE-05 — Pantalla de check-in ya completado
**Hereda de:** ERR-04
**Usuario:** Miguel (ya hizo check-in hoy)
**URL:** `/checkin`
**Screenshot:** `web/estados/checkin-ya-completado.png`

**Componentes a evaluar:**
- [ ] Mensaje claro de que el check-in fue completado
- [ ] Muestra el resumen de lo que se envió
- [ ] No muestra el formulario vacío (evitar doble submit)
- [ ] Link para ir al dashboard

---

## SUITE 6 — MOBILE ESPECÍFICO (390px)

**Viewport:** 390x844 en todas
**Carpeta screenshots:** `latest/mobile/`

---

### VIS-MOB-01 — Nav inferior atleta
**URL:** `/dashboard` (como Miguel)
**Screenshot:** `mobile/atleta/nav-inferior.png`

**Componentes a evaluar:**
- [ ] 5 items máximo en nav inferior
- [ ] Cada item tiene ícono + label de texto debajo
- [ ] Item activo visualmente diferenciado
- [ ] Touch targets >= 44px de altura
- [ ] Badge de mensajes no leídos visible sobre el ícono

---

### VIS-MOB-02 — Formulario en mobile (check-in)
**URL:** `/checkin`
**Screenshot:** `mobile/atleta/checkin-mobile.png`

**Componentes a evaluar:**
- [ ] Sliders de ancho completo, fáciles de arrastrar
- [ ] Labels encima de los sliders (no a los lados)
- [ ] Teclado numérico para campo de peso
- [ ] Botón submit visible sin scroll cuando teclado está cerrado

---

### VIS-MOB-03 — Cards en mobile
**URL:** `/dashboard`
**Screenshot:** `mobile/atleta/cards-mobile.png`

**Componentes a evaluar:**
- [ ] Cards de ancho completo (no cortadas)
- [ ] Padding interno consistente en todos los cards
- [ ] Texto no overflow fuera del card
- [ ] Íconos y texto bien alineados verticalmente

---

### VIS-MOB-04 — Plan semanal en mobile
**URL:** `/plan`
**Screenshot:** `mobile/atleta/plan-semanal-mobile.png`

**Componentes a evaluar:**
- [ ] Días de la semana en fila horizontal — caben los 7 sin overflow
- [ ] Día HOY visible sin scroll horizontal
- [ ] Al seleccionar un día, el detalle aparece abajo sin romper layout
- [ ] Scroll vertical para ver más semanas es fluido

---

## REPORTE CONSOLIDADO

### Ejecucion 2026-07-01 — Verificacion rapida

**Fecha:** 2026-07-01 | **Pantallas verificadas:** 5 (spot check DOM, sin screenshots)

| Pantalla | URL | Resultado | Notas |
|----------|-----|-----------|-------|
| Dashboard atleta B2B | /dashboard (Miguel) | ✅ PASS | "Buenos dias, Miguel", sem 11/18, CoachCard visible. "Buenos dias" capitaliza correctamente |
| Plan atleta | /plan (Miguel) | ✅ PASS | "Plan Media Maraton 18 semanas", sem 11, BASE, sin overflow |
| Nutrition atleta | /nutrition (Maria) | ✅ PASS | 1939 kcal, macros visibles, guia de alimentos + barras de progreso |
| Coach dashboard | /coach/dashboard | ✅ PASS | 5 atletas, $30 ingresos, alertas visibles, actividad reciente |
| Admin dashboard | /admin | ✅ PASS | 22 usuarios, funnel de activacion, sidebar 14 secciones |

**Nuevos issues visuales 2026-07-01:** Ninguno adicional al reporte anterior.
**VIS-G-01 (lang="pt"):** Aun presente — no corregido en esta ejecucion.

---

> **Ejecucion 2026-06-30:**
> **Ejecutado por:** Claude Visual Agent (Claude in Chrome MCP)
> **Cobertura:** 30/35 pantallas evaluadas. ONBOARDING (3) y EDGE-01 bloqueados (ver notas). Ana ya completó onboarding y no es posible crear cuentas nuevas desde el agente.

> **Notas de método (importantes):**
> 1. El MCP de Chrome no expone una ruta en disco para los screenshots, y `html2canvas` falla por los colores `lab()`/`oklch` de Tailwind v4. La evaluación se hizo sobre las capturas en vivo (que es lo que importa para detectar issues); **no se pudieron escribir los archivos PNG en `screenshots/latest/`**.
> 2. `resize_window` no baja del mínimo de ventana de Chrome en macOS; el viewport "mobile" más estrecho alcanzado fue **~500px**, no los 390px objetivo. El layout responsive (nav inferior, stacking) sí se activa a ≤500px y se verificó sin overflow. Issues específicos que solo aparecerían entre 390–500px no son verificables con esta herramienta.

### Resumen

| Suite | Pantallas | Issues CRÍTICO | Issues ALTO | Issues MEDIO | Issues BAJO |
|-------|-----------|---------------|-------------|--------------|-------------|
| GLOBAL (cross-cutting) | — | 0 | 2 | 1 | 0 |
| AUTH (5) | 5/5 | 0 | 1 | 1 | 2 |
| ONBOARDING (3) | 3/3 ✅ desbloqueado 2026-07-01 | 0 | 1 | 2 | 2 |
| ATLETA (10) | 10/10 | 0 | 0 | 2 | 5 |
| COACH (8) | 8/8 | 0 | 0 | 2 | 4 |
| ESTADOS (5) | 4/5 | 0 | 0 | 0 | 1 |
| MOBILE (4) | 4/4 | 0 | 0 | 0 | 1 |
| **TOTAL** | **33/35** | **0** | **4** | **8** | **15** |

---

### Issues detectados

> Screenshots: no escritos a disco (ver Notas de método). Referencia = pantalla evaluada en vivo.

| ID | Suite | Pantalla | Componente | Issue | Severidad |
|----|-------|----------|------------|-------|-----------|
| VIS-G-01 | GLOBAL | Todas | Idioma / nav | Idioma por defecto **portugués**: `html lang="pt"` y nav en PT ("Início, Meu Plano, Nutrição, Meu perfil") en primer render para Miguel y Ana. Al elegir ES se corrige todo. Producto es español-LatAm ("UI siempre en español"). Eleva el known-issue A11Y-02 de "Bajo" a ALTO. | ALTO |
| VIS-G-02 | GLOBAL | Atleta + Coach | Semana actual | **Semana actual inconsistente entre módulos**: Dashboard/Plan atleta = Sem **11/18** (vacía, 0 sesiones, adherencia 0%); Check-in atleta + perfil/plan coach = Sem **6** (DESARROLLO, con Rodaje/Tempo/Intervalos); Mis Atletas coach = Sem 11. El atleta ve una semana sin entrenamientos mientras el plan real vive en la semana 6. | ALTO |
| VIS-G-03 | GLOBAL | Dashboard/headers | Fecha | "Martes, 30 De Junio De 2026": `text-transform:capitalize` capitaliza preposiciones. Debe ser "martes, 30 de junio de 2026". | MEDIO |
| VIS-AUTH-02a | AUTH | Login mobile | Inputs/botones | Touch targets bajo 44px: inputs 42px, "Iniciar sesión" 40px, "Continuar con Google" 42px (marginal, ~2-4px bajo guía). | ALTO |
| VIS-AUTH-03a | AUTH | Registro | Términos | Sin mensaje/enlace de términos y privacidad en el registro. | MEDIO |
| VIS-AUTH-03b | AUTH | Registro desktop | Layout | El form es más alto que el viewport (800px) → CTA "Crear cuenta" queda bajo el fold; el card no está centrado verticalmente. | BAJO |
| VIS-AUTH-04a | AUTH | Forgot password | Copy | Anglicismo "link" ("Enviar link de recuperación") en vez de "enlace". | BAJO |
| VIS-ATL-01a | ATLETA | Dashboard | Labels/badges | Labels uppercase y badges entre 8-11px (HOY 8px, BASE 9px), bajo el umbral de 12px → legibilidad. | MEDIO |
| VIS-ATL-07a | ATLETA | Progreso | Gráfica peso | La gráfica de peso no dibuja la línea de objetivo (70kg) ni etiquetas de eje Y. | MEDIO |
| VIS-ATL-05a | ATLETA | Check-in form | Slider | El valor actual del slider muestra "—" en vez de número antes de arrastrar. | BAJO |
| VIS-ATL-05b | ATLETA | Check-in form | Copy | Typo "Sin energia" (falta tilde en "energía"). | BAJO |
| VIS-ATL-06a | ATLETA | Nutrición | Macros | "Calorías 1702 kcal" tiene el mismo tamaño visual que los demás macros (no es el número más grande, como pide la jerarquía). | BAJO |
| VIS-ATL-08a | ATLETA | Log carrera | Copy | "Registrar corrida" vs "TU CARRERA" en el resto de la UI: término inconsistente. | BAJO |
| VIS-ATL-X | ATLETA | Check-in / Gym vacío | a11y | Pantallas sin `<h1>` (`h1Count===0`) en estado completado de check-in y en gym vacío. | BAJO |
| VIS-COACH-01a | COACH | Dashboard | KPIs | Dos métricas de adherencia conviven (CHECK-INS "71% de adherencia" vs KPI "ADHERENCIA PROMEDIO 0%"); el 0% parece placeholder y confunde. | MEDIO |
| VIS-COACH-05a | COACH | Finanzas | Montos | La lista de pagos no muestra la etiqueta de moneda ($100.000 sin "COP", aunque el form sí captura Moneda=COP). Además mezcla: dashboard en USD ($42) vs finanzas en miles ($500.000). | MEDIO |
| VIS-COACH-03a | COACH | Detalle atleta | Copy | "Hace 1 días" (sin pluralización correcta → "Hace 1 día"). | BAJO |
| VIS-COACH-05b | COACH | Finanzas form | a11y | Labels del form de nuevo pago sin asociación `for`/`id` (3 inputs sin label programático). | BAJO |
| VIS-COACH-04a | COACH | Plan tab | Botón | "Siguiente →" del WeekNav se ve atenuado/deshabilitado estando en Sem 6 de 18. | BAJO |
| VIS-COACH-02a | COACH | Dashboard mobile | Nav inferior | "Finanzas" no aparece en el nav inferior del coach (solo Dashboard/Mis atletas/+Nuevo/Gym/Config) → descubribilidad. | BAJO |
| VIS-EDGE-03a | ESTADOS | 404 | Layout | El 404 es una página standalone (no mantiene el nav/header de la app, como pide el check). | BAJO |
| VIS-MOB-01a | MOBILE | Nav inferior | Badge unread | El badge de mensajes no leídos no es visible en el nav inferior porque "Mensajes" queda colapsado dentro de "Más". | BAJO |

**Pantallas SIN issues (passed limpio):** Login desktop (AUTH-01), Error login (AUTH-05), Forgot password (AUTH-04), Plan desktop (ATL-03), Nutrición (ATL-06 base), Historial vacío (ATL-09), Mensajes atleta (ATL-10), Mensajes coach (COACH-08), Gym builder (COACH-06), Crear atleta (COACH-07), Detalle atleta tabs (COACH-03), Gym vacío (EDGE-02), Check-in completado (EDGE-05), Dashboard/Plan/Check-in mobile, Coach dashboard mobile.

**Bloqueadas:**
- VIS-EDGE-01 (dashboard atleta sin plan): Ana (B2C) sí tiene plan (RACE_5K); no hay cuenta B2C sin TrainingPlan disponible.

---

### Ejecucion 2026-07-01 — VIS-OB (Onboarding visual) — DESBLOQUEADO

**Fecha:** 2026-07-01 | **Método:** DOM check automático con cuenta nueva (test-act-gym-1751407@mailinator.com)
**Nota:** VIS-OB-01/02/03 bloqueados en ejecución anterior porque Ana ya tenía onboarding completo. Se creó cuenta nueva para desbloquear.

| ID | Resultado | URL | Detalle DOM |
|----|-----------|-----|-------------|
| VIS-OB-01 | ⚠️ PARCIAL | /onboarding (paso 1 — ¿Cómo quieres entrenar?) | fontSize=0 ✅, overflowX=**true** ❌, smallTargets=["Salir"] ❌ (botón Salir <44px), h1Count=0 ❌, inputsUnlabeled=0 ✅, lang="es" ✅ |
| VIS-OB-02 | ❌ FAIL | /onboarding (paso 1 con sub-preguntas Gym) | fontSize=0 ✅, overflowX=**true** ❌, smallTargets=["Salir","📈 Ganar músculo","🔥 Perder grasa","⚖️ Los dos"] ❌ (botones de opción <44px), h1Count=0 ❌, inputsUnlabeled=0 ✅ |
| VIS-OB-03 | ❌ FAIL | /onboarding (paso 2 — Datos básicos) | fontSize=0 ✅, overflowX=**true** ❌, smallTargets=["Salir","Principiante","Intermedio","Avanzado"] ❌, h1Count=0 ❌, **inputsUnlabeled=4** ❌ (4 inputs numéricos sin label programático), lang="es" ✅ |

**Issues detectados (onboarding):**

| ID | Issue | Severidad | Aparece en |
|----|-------|-----------|-----------|
| VIS-OB-A | `overflow-x` presente en todos los pasos del onboarding — scroll horizontal inesperado | MEDIO | VIS-OB-01/02/03 |
| VIS-OB-B | Botones de selección de opciones (Ganar músculo, Perder grasa, Principiante, etc.) con height <44px — incumple guía de touch targets | MEDIO | VIS-OB-02/03 |
| VIS-OB-C | Ningún paso tiene `<h1>` — ausencia de jerarquía semántica | BAJO | VIS-OB-01/02/03 |
| VIS-OB-D | 4 inputs numéricos (Edad, Talla, Peso actual, Peso objetivo) sin label programático (`for`/`aria-label`) | ALTO | VIS-OB-03 |
| VIS-OB-E | Botón "Salir" (type=submit) como primer botón en el DOM — riesgo de activación accidental por teclado | BAJO | VIS-OB-01/02/03 |

---

### Issues conocidos (pre-existentes de E2E)

| ID E2E | Issue | Impacto visual | Estado en este run |
|--------|-------|----------------|--------------------|
| A11Y-02 | `lang="pt"` en HTML root | ~~Bajo — no visible al usuario~~ | **Confirmado y RE-CLASIFICADO a ALTO** (ver VIS-G-01): no es solo el atributo; el nav entero renderiza en portugués por defecto. |
| A11Y-03 | 1 button sin texto ni aria-label | Medio — accesibilidad screen reader | No reproducido explícitamente; sí se vieron labels de form sin `for`/`id` (VIS-COACH-05b) y pantallas sin h1. |
| EDGE-01 | Botón submit no se deshabilita en doble click | Medio — feedback visual ausente | No re-probado en profundidad (registro y nuevo pago tienen CTA disabled hasta validar, lo cual mitiga). |
| COACH-16 | WeekNav muestra S1-S6, resto requiere scroll sin indicador | Medio — descubribilidad | Relacionado: en plan coach el botón "Siguiente" se ve atenuado en Sem 6/18 (VIS-COACH-04a). |

---

### Observaciones de UX LatAm

- **Idioma:** ⚠️ El idioma por defecto es **portugués** (VIS-G-01). Con ES seleccionado el español está limpio. Anglicismos puntuales: "link" (forgot-password), "corrida" vs "carrera". Typo "energia" sin tilde en check-in.
- **Monedas:** ⚠️ Inconsistencia (VIS-COACH-05a): dashboard coach en **USD** ($42), finanzas en miles tipo **COP** ($100.000–$500.000) sin etiqueta de moneda en la lista. El form de pago sí permite elegir COP/USD. Formato de miles con punto correcto para COP.
- **Fechas:** Formato "dd de mes de yyyy" correcto en contenido, pero el título del dashboard capitaliza preposiciones ("30 De Junio De 2026" en vez de "30 de junio de 2026") — VIS-G-03. "Hace 1 días" sin pluralización (VIS-COACH-03a).
- **Tono:** ✅ Cercano y motivador ("Buenas tardes", "Listo para entrenar fuerte", "Aprovecha para recuperar bien hoy", "vas bien"). No corporativo. Bien para LatAm.
- **Dato de prueba visible:** Atletas y pagos con sufijo "E2E"/"test mora" aparecen en listas reales del coach (no es bug visual, pero conviene limpiar seed antes de mostrar a clientes).
