# Medaliq — Tests E2E Dashboard Módulos (B2C Atleta)

**URL base:** `http://localhost:3000`
**Ejecutado:** 2026-07-05 (E2E Chrome MCP, local)
**Usuario de prueba:** `carlos.qa.e2e@medaliq.com` — B2C runner, onboarding completado, activityType=RUNNING, datos: Edad 28 · Altura 172 cm · Peso 70 kg · Género Hombre · Nivel Intermedio

**Protocolo de capturas:**
- FAIL / PARCIAL → screenshot obligatorio (la mayoría de este archivo son bugs conocidos)
- PASS con valor numérico verificado (kcal, macros, IMC, FC) → screenshot del valor visible en pantalla
- PASS funcional sin valor numérico → no capturar (registrar solo resultado)

---

## ⚠️ CAMBIOS POST-EJECUCIÓN (actualizado 2026-07-10)

| Test | Estado actualizado | Detalle |
|------|--------------------|---------|
| DASH-05 — Gym no contextualizado para runners | ⚠️ Revisar | El módulo `/gym` ahora muestra `AssignedWorkout` (si coach asignó rutina) o plantillas públicas. Sin asignación, los templates son genéricos — la contextualización por deporte sigue siendo un gap (BUG-NEW-06 activo). |
| DASH-06 — Naming "Ejercicios" vs /gym | ⚠️ Re-verificar | Puede estar resuelto o no. La ruta sigue siendo `/gym`. Verificar el label del nav en la versión actual. |
| DASH-04 — Defaults hardcodeados en registro diario | ⚠️ Re-verificar | Puede haber sido corregido. Verificar si el form ahora carga `weightKg` y `hrResting` del HealthProfile al montar. |
| `/log` → `/log/history` | ✅ Aclarado | `/log` redirige a `/log/history`. El historial unificado (GymSession completadas + SessionLog libres) vive en `/log/history`. DC-13 debe apuntar a `/log/history`. |
| Nutrición B2B | ✅ Aclarado | Prioridad plan en `/nutrition`: `AssignedNutritionPlan` > `MealPlan` > `NutritionPlan` base. Si el atleta tiene plan del coach, aparece badge "Plan de tu coach: [nombre]". |

---

## SUITE DASH — Dashboard y módulos del atleta

### DASH-01 — Dashboard home: capitalización de fecha (BUG-NEW-03)

**Descripción:** La fecha en el header del dashboard debe estar capitalizada correctamente
**Precondición:** Sesión iniciada, atleta en `/dashboard`
**Pasos:**
1. Observar el header del dashboard
2. Leer la fecha mostrada (ej. "domingo, 5 de julio de 2026")

**Esperado:** Fecha capitalizada: "Domingo, 5 de julio de 2026" — primera letra en mayúscula.
**Resultado:** ❌ FAIL — La fecha aparece con la primera letra en minúscula: "domingo, 5 de julio de 2026". Comportamiento nativo de `Date.toLocaleDateString('es-CO', { weekday: 'long', ... })` sin capitalización manual.
**Causa raíz:** El formato de fecha no aplica `.charAt(0).toUpperCase() + slice(1)` o equivalente al resultado del formateador de fecha.
**Bug:** BUG-NEW-03 — componente del dashboard, cálculo de fecha. Fix: capitalizar la primera letra del string resultante.

---

### DASH-02 — Dashboard: estado del plan para atleta sin plan (BUG-NEW-04)

**Descripción:** El módulo de plan/check-in debe mostrar copy coherente para un atleta sin plan activo
**Precondición:** Atleta B2C recién registrado, sin plan generado
**Pasos:**
1. Ir a `/dashboard`
2. Observar el widget/card de plan o check-in semanal
3. Leer el texto del CTA o estado

**Esperado:** Texto como "Aún no tienes un plan activo" o "Empieza configurando tu primera meta". Sin mencionar "ajustar tu plan".
**Resultado:** ❌ FAIL — El widget muestra texto que referencia "ajustar tu plan" a pesar de que el atleta no tiene plan. El copy asume que existe un plan activo — genera confusión y expectativa incorrecta.
**Causa raíz:** El componente de check-in no tiene estado condicional para `planId = null`. Renderiza el mismo copy para atletas con y sin plan.
**Bug:** BUG-NEW-04 — componente del dashboard (card plan/check-in). Agregar condicional: `if (!activePlan) → mostrar estado vacío con CTA de configurar meta`.

---

### DASH-03 — Nutrición: calorías totales no coinciden con suma de macros (BUG-NEW-05)

**Descripción:** Las calorías mostradas en la pantalla de nutrición deben coincidir con la suma calórica de los macros
**Precondición:** Atleta con HealthProfile completo. TDEE calculado en onboarding.
**Pasos:**
1. Ir a `/nutrition`
2. Observar las calorías totales del día mostradas (ej. 2142 kcal)
3. Observar los macros: Proteína (g), Carbohidratos (g), Grasa (g)
4. Calcular manualmente: P×4 + C×4 + G×9
5. Comparar suma con calorías mostradas

**Esperado:** Suma de macros = calorías totales (±5 kcal por redondeo).
**Resultado:** ❌ FAIL — Calorías mostradas: 2142 kcal. Macros observados: ~140g proteína · ~144g carbohidratos · ~79g grasa.
- Suma: (140×4) + (144×4) + (79×9) = 560 + 576 + 711 = **1847 kcal**
- Gap: **295 kcal de diferencia**
**Causa raíz:** `getDailyNutritionTarget()` en `src/lib/nutrition/daily-target.ts` calcula los macros sobre una base calórica diferente a la que muestra en pantalla. El display de calorías totales y el cálculo de macros usan valores de entrada distintos (posiblemente TDEE ajustado vs TDEE base, o intensidad de sesión no aplicada al display pero sí a los macros).
**Impacto:** El atleta ve un objetivo calórico que no puede alcanzar siguiendo exactamente los macros indicados.
**Bug:** BUG-NEW-05 — `src/lib/nutrition/daily-target.ts` + componente de nutrición. P1.

---

### DASH-04 — Registro diario: pre-carga peso y FC reposo incorrectos (BUG-NEW-08)

**Descripción:** El formulario de registro diario debe pre-cargar los valores del HealthProfile del atleta
**Precondición:** Atleta con HealthProfile guardado (Peso: 70 kg, FC reposo: registrada en onboarding)
**Pasos:**
1. Ir al formulario de registro diario (log sesión)
2. Observar el valor pre-cargado del campo "Peso"
3. Observar el valor pre-cargado del campo "FC reposo" o "Frecuencia cardíaca en reposo"

**Esperado:** Peso = 70 kg (del HealthProfile). FC reposo = valor guardado en HealthProfile.
**Resultado:** ❌ FAIL — El formulario pre-carga:
- Peso: **75.0 kg** (hardcodeado — no es el peso del atleta de prueba)
- FC reposo: **55 bpm** (hardcodeado — no lee de HealthProfile)
**Causa raíz:** El componente usa valores literales hardcodeados en el estado inicial en lugar de cargar desde `GET /api/athlete/profile` o equivalente. El componente no hace fetch del HealthProfile al montar.
**Impacto:** Todo registro de sesión parte de datos incorrectos → el cálculo de zonas y ajustes del check-in usará datos de base erróneos.
**Bug:** BUG-NEW-08 — componente de registro diario (log). Fix: cargar HealthProfile en mount y usar `profile.weightKg` y `profile.hrResting` como valores iniciales. P1.

---

### DASH-05 — Módulo Ejercicios (/gym): rutinas de fuerza visibles para atleta runner (BUG-NEW-06)

**Descripción:** El módulo de ejercicios debe mostrar contenido relevante al deporte del atleta
**Precondición:** Atleta registrado como runner (activityType=RUNNING)
**Pasos:**
1. Ir a `/gym` (nav: "Ejercicios")
2. Observar las rutinas disponibles

**Esperado:** Rutinas de complemento para runners (fuerza funcional, movilidad, core para running). O módulo vacío con mensaje indicando que es para atletas de gym.
**Resultado:** ❌ FAIL — El módulo muestra rutinas de fuerza de gym (press de banca, sentadillas, etc.) sin contextualización para running. Un atleta de running que entra al módulo ve contenido diseñado para culturismo/gym, no para complementar su entrenamiento de carrera.
**Causa raíz:** El módulo `/gym` no filtra ni personaliza contenido según `activityType` del perfil.
**Bug:** BUG-NEW-06 — módulo `/gym`. Opciones: (a) mostrar solo rutinas de complemento running si activityType=RUNNING, (b) mostrar mensaje de contexto explicando para qué sirve el módulo. P2.

---

### DASH-06 — Naming inconsistente: nav "Ejercicios" vs ruta /gym (BUG-NEW-07)

**Descripción:** El nombre en la navegación y la ruta deben ser coherentes
**Precondición:** Ninguna — verificación visual
**Pasos:**
1. Observar la navegación del dashboard
2. Leer el label del módulo de gym/ejercicios
3. Verificar la URL al hacer click

**Esperado:** Coherencia entre label de nav y ruta. Ej: nav "Gym" → `/gym` o nav "Ejercicios" → `/ejercicios`.
**Resultado:** ❌ FAIL — La navegación dice "Ejercicios" pero la URL es `/gym`. Inconsistencia de naming entre UI y URL.
**Impacto:** Menor — pero genera confusión en soporte, documentación y comunicación con el usuario.
**Bug:** BUG-NEW-07 — decidir nombre canónico: "Gym" o "Ejercicios" y unificar en nav + ruta + título de página. P3.

---

### DASH-07 — Perfil del atleta: métricas calculadas correctas

**Descripción:** Las métricas derivadas del HealthProfile deben calcularse correctamente
**Precondición:** Atleta con datos completos: Edad 28 · Altura 172 cm · Peso 70 kg · FC reposo (si aplica)
**Pasos:**
1. Ir a `/profile` o equivalente
2. Verificar IMC mostrado
3. Verificar FC máxima estimada
4. Verificar zonas de entrenamiento (si se muestran)

**Esperado:**
- IMC = 70 / (1.72)² = 70 / 2.9584 = **23.66** (≈ 23.7)
- FC máx = 211 - (0.64 × 28) = 211 - 17.92 = **193.08** (≈ 193 bpm)
- Zonas Karvonen si hrResting > 0

**Resultado:** ✅ PASS — Valores verificados en E2E 2026-07-05:
- IMC: 23.7 ✅
- FC máx: 193 bpm ✅
- Fórmulas Karvonen aplicadas correctamente ✅
**Nota:** Las fórmulas físicas son correctas. El problema de datos incorrecto está en DASH-04 (registro diario), no en el cálculo del perfil.

---

### DASH-08 — Check-in semanal: formulario accesible sin plan activo

**Descripción:** El check-in semanal no debe ser accesible (o debe mostrar estado vacío) para atletas sin plan
**Precondición:** Atleta sin plan activo (activityType=RUNNING, sin TrainingPlan generado)
**Pasos:**
1. Ir a `/checkin`
2. Observar si el formulario está disponible o hay bloqueo/mensaje de estado vacío

**Esperado:** Estado vacío con mensaje: "Necesitas un plan activo para hacer el check-in" o CTA para crear un plan.
**Resultado:** ⚠️ PARCIAL — El formulario de check-in es accesible aunque el atleta no tiene plan. Técnicamente el check-in puede procesarse (la lógica busca `findActivePlan` y maneja null), pero el UX no indica al usuario que sin plan el check-in no tiene efecto adaptativo.
**Nota:** No es un bug bloqueante — el check-in guarda datos independientemente. El problema es de expectativa del usuario.
**Mejora:** Agregar banner informativo: "Sin plan activo, el check-in registra tus datos pero no generará ajustes automáticos".

---

## RESUMEN DE SUITE DASH

| Test | Resultado | Bug/Mejora |
|------|-----------|------------|
| DASH-01 — Fecha capitalización dashboard | ❌ FAIL | BUG-NEW-03 (P3) |
| DASH-02 — Copy "ajustar plan" sin plan activo | ❌ FAIL | BUG-NEW-04 (P2) |
| DASH-03 — Macros no suman calorías totales | ❌ FAIL | BUG-NEW-05 (P1) |
| DASH-04 — Registro diario defaults incorrectos | ❌ FAIL | BUG-NEW-08 (P1) |
| DASH-05 — Gym muestra rutinas de fuerza a runner | ❌ FAIL | BUG-NEW-06 (P2) |
| DASH-06 — Naming "Ejercicios" vs /gym | ❌ FAIL | BUG-NEW-07 (P3) |
| DASH-07 — Métricas perfil (IMC, FC máx) | ✅ PASS | — |
| DASH-08 — Check-in sin plan activo | ⚠️ PARCIAL | UX mejora (P3) |

**Total:** 8 tests · 1 PASS · 5 FAIL · 1 PARCIAL · 0 FIXED

---

## INFORME DE BUGS — CAUSAS TÉCNICAS

### BUG-NEW-03 — Fecha sin capitalizar
**Causa:** `Date.toLocaleDateString('es-CO', {...})` retorna "domingo, 5 de julio de 2026" en minúsculas. No hay transformación posterior.
**Fix:** `dateStr.charAt(0).toUpperCase() + dateStr.slice(1)` o usar una utility de formato.
**Archivo probable:** `src/app/(athlete)/dashboard/` — componente header o date display.

### BUG-NEW-04 — Copy "ajustar plan" sin plan activo
**Causa:** El componente del widget de plan/check-in no evalúa `if (!activePlan)` antes de renderizar el copy. Usa el mismo texto para ambos estados.
**Fix:** Condicional en el componente: si `activePlan === null` → renderizar estado vacío con CTA apropiado.
**Archivo probable:** `src/app/(athlete)/dashboard/_components/` — card de plan o check-in.

### BUG-NEW-05 — Macros no suman calorías (295 kcal gap)
**Causa profunda:** Dos posibles rutas:
1. Las calorías totales se muestran con ajuste por intensidad de sesión (ej. multiplicador 0.85 para día de descanso) pero los macros se calculan sin ese ajuste, o viceversa.
2. La función `getDailyNutritionTarget()` distribuye macros sobre TDEE base mientras la UI muestra TDEE ajustado.
**Fix:** Asegurar que el valor calórico mostrado = `sum(macros_calories)`. Si hay ajuste por intensidad, aplicarlo a ambos o a ninguno.
**Archivo:** `src/lib/nutrition/daily-target.ts` + componente `/nutrition`.

### BUG-NEW-06 — Gym no contextualizado para runners
**Causa:** El módulo `/gym` carga rutinas sin filtrar por `activityType` del `HealthProfile`.
**Fix:** En el query o en el componente, verificar `activityType` y filtrar/contextualizar el contenido.
**Archivo probable:** `src/app/(athlete)/gym/` — page o componente de lista de rutinas.

### BUG-NEW-07 — Naming inconsistente nav vs URL
**Causa:** El label de navegación fue cambiado a "Ejercicios" (más natural en español) pero la ruta `/gym` no fue renombrada.
**Fix:** Decisión de producto — elegir nombre canónico y aplicar en nav label + `href` + `pathname` + page title.

### BUG-NEW-08 — Defaults hardcodeados en registro diario
**Causa:** El estado inicial del formulario usa `weight: 75.0` y `hrResting: 55` como literales en lugar de cargar desde el perfil del usuario.
**Fix:** Al montar el componente, hacer `GET /api/athlete/profile` (o usar datos ya cargados en context/session) y setear `weight: profile.weightKg` y `hrResting: profile.hrResting`.
**Archivo probable:** `src/app/(athlete)/log/` o componente de SessionLog — estado inicial del form.
