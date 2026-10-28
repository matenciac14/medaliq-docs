# Domain: Nutrición
# Reglas de negocio no evidentes en el código. Leer antes de tocar cualquier feature de nutrición.
> **Flujos por actor → `flujos-por-actor.md`** — qué puede hacer cada actor (atleta Free/Pro/B2B, coach, admin) en este módulo, con endpoints.
> Spec de implementacion: `../specs/nutrition.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Completa (/nutrition, /nutrition/builder, /nutrition/planner) |
| Mobile atleta | Completa (30 endpoints, barcode scanner, grocery list) |
| Web coach | Completa (asignar plan, templates, proposals) |

## Filosofía del módulo

**El foco es la mejor experiencia de registro para el atleta.** No es un sistema de dieta ni un contador de calorías clínico — es una herramienta que acompaña al atleta en su día a día sin fricción. Si registrar una comida toma más de 30 segundos, el atleta deja de hacerlo. Toda decisión de UX debe partir de ese principio.

## Cómo el atleta obtiene su plan nutricional

```
Onboarding → datos físicos (peso, altura, edad, género, actividad)
  → TDEE calculado con Mifflin-St Jeor
  → Macros periodizados por intensidad de entrenamiento
  → NutritionPlan creado automáticamente

El atleta no hace nada extra — al salir del onboarding ya tiene su target.
```

El target varía día a día según la intensidad de la sesión planeada (ver sección Sincronización). El atleta ve un número diferente en días de entrenamiento duro vs días de descanso — eso es correcto, no un bug. Internamente el ajuste es automático por mecánica; la comunicación al atleta es de **sugerencia** semanal basada en sus sensaciones reportadas en el check-in.

## Registro sin plan activo

El atleta puede registrar comidas y calorías **aunque no tenga plan de entrenamiento ni plan nutricional activo**. El módulo de nutrición es independiente del plan de entrenamiento.

| Estado del atleta | Puede registrar comida | Ve target diario | Target varía por intensidad |
|-------------------|----------------------|-----------------|----------------------------|
| Con NutritionPlan + TrainingPlan | ✅ | ✅ | ✅ (HIGH/MODERATE/LOW/REST) |
| Con NutritionPlan, sin TrainingPlan | ✅ | ✅ | ❌ (target plano, mismo cada día) |
| Sin NutritionPlan | ✅ | ❌ (solo registro crudo) | ❌ |

**Nota técnica:** el onboarding siempre crea un `NutritionPlan` automáticamente. Un atleta sin NutritionPlan es un edge case (usuario en estado raro o sin onboarding completado). Hay lazy-init en `/api/athlete/nutrition` y `/api/mobile/nutrition` que lo crea si no existe.

**Historial por tier:** Free: historial de nutricion limitado a ultimos 30 dias. Pro/B2B: historial completo.

## Responsabilidades por actor — regla más importante

| Actor | Controla | NO controla |
|-------|----------|-------------|
| Coach / Nutricionista | Plan nutricional base + proponer ajustes en tiempo real | Modificar el FoodLog del atleta directamente |
| Sistema | Ajuste puntual del día según intensidad real de sesión | El plan base |
| Atleta | Acepta o rechaza cualquier ajuste (del coach o del sistema) | Nada se modifica sin su confirmación |

**Regla fundamental: el atleta siempre tiene la última palabra.** Ni el coach ni el sistema modifican el registro o el plan del atleta sin que él lo acepte.

**Flujo de ajuste propuesto por el coach:**
```
Coach ve FoodLog del atleta en tiempo real
  → Coach detecta déficit de proteína o exceso calórico
  → Coach propone ajuste: "Aumenta 30g de proteína en el almuerzo esta semana"
  → Atleta recibe notificación in-app
  → Atleta acepta → target del día/semana se actualiza
  → Atleta rechaza → plan base se mantiene sin cambios
```

Este patrón es consistente con los ajustes de entrenamiento — el coach propone, el atleta decide. Nunca al revés.

**El plan base NUNCA se modifica automáticamente.** Solo el coach lo cambia, y solo con aceptación del atleta.

## Sincronización plan-nutrición (fuente canónica: `daily_target.ts`)

```
PlannedSession.intensity → kcal + macros del día
HIGH     → targetKcalHard + carbsHardG
MODERATE → targetKcalEasy + carbsEasyG
LOW      → targetKcalEasy × 0.88 + carbsEasyG × 0.75
REST     → targetKcalRest + carbsEasyG × 0.7   ← default/fallback para null/undefined intensity
```

**[R5 COMPLETADO]**: el sistema ya NO auto-modifica targets nutricionales por intensidad de sesion. El target diario es fijo (MODERATE/easy) segun el NutritionPlan configurado en onboarding o por el coach. La funcion `intensityToDayType` existe pero los consumers usan MODERATE hardcodeado.

## PendingNutritionAdjustment

**[R6 COMPLETADO]**: modelo, enum `AdjustmentStatus` y 4 endpoints (accept/reject web+mobile) eliminados del codigo y schema.prisma. Migracion DB pendiente. Los ajustes nutricionales solo provienen del coach via `CoachNutritionProposal` (B2B).

## Regla de snapshot en FoodLog

`FoodLog` tiene campos snapshot: `kcalLogged, proteinLogged, carbsLogged, fatLogged Float?`
- Si snapshot != null → usar snapshot (inmutable al momento del registro)
- Si snapshot == null → calcular desde `food.*` (backward-compat con registros históricos)
- `buildFoodLogResponse()` en `domain/nutrition/calculate_food_log.ts` aplica este fallback

## FoodProfile — perfil de alimentos del atleta

`FoodProfile` almacena qué alimentos consume habitualmente el atleta, sus restricciones y preferencias:

```
FoodProfile {
  availableFoodIds: String[]   → IDs de Food que el atleta consume
  availableFoods: String[]     → nombres (denormalizados para display)
  restrictions: String[]       → SIN_GLUTEN, SIN_LACTEOS, VEGETARIANO, VEGANO, etc.
  mealsPerDay: Int (2-6)       → estructura del día alimenticio
  weighsFood: Boolean          → si pesa alimentos (precisión del tracking)
  notes: String?               → notas adicionales
}
```

**Cuándo se llena:** post-onboarding, como paso opcional incentivado con CTA "Personaliza tu nutrición". NO se llena durante el onboarding (ya es largo).

**Para qué sirve:**
- Coach ve el FoodProfile en Tab Nutrición → sabe qué alimentos usar al construir templates
- Búsqueda de alimentos prioriza los del atleta al inicio de resultados
- Futuro → input para generar templates personalizadas respetando restricciones

**Endpoints:**
- Web: `GET/PUT /api/athlete/nutrition/food-profile`
- Mobile: `GET/PUT /api/mobile/nutrition/food-profile`

## Plantillas de nutrición del coach

El coach puede crear `NutritionTemplate` — planes base reutilizables que asigna a sus atletas.
Al asignar una plantilla, se crea (o reemplaza) el `NutritionPlan` del atleta.

Endpoints: `GET|POST /api/coach/nutrition/templates`, `PATCH|DELETE /api/coach/nutrition/templates/[id]`, `POST /api/coach/nutrition/templates/[id]/assign`

**Tres modelos DB coexisten para "lo que come el atleta" — no son redundantes:**

| Modelo | Qué representa | Quién lo crea |
|--------|---------------|---------------|
| `NutritionPlan` | Macros totales calculados (TDEE + periodización por intensidad) | Sistema en onboarding |
| `MealPlan` | Distribución de comidas en JSON `{ hard, easy, rest }` | Sistema al generar el plan de comidas |
| `AssignedNutritionPlan` | Template del coach asignado a este atleta (FK a `NutritionTemplate`) | Coach vía `POST .../assign` |

Los tres pueden coexistir para el mismo atleta. Cuando existe `AssignedNutritionPlan`, el plan del coach reemplaza el `NutritionPlan` base del sistema. `MealPlan` es la distribución concreta de comidas para el UI — complementa a `NutritionPlan`, no lo reemplaza. El agente que toque nutrición debe leer los tres modelos antes de asumir cuál aplica.

## PlannedMeal — planificación diaria de alimentos concretos (DB-12 ✅ implementado)

**Gap actual:** los tres modelos anteriores definen *cuántas* calorías y macros debe consumir el atleta, pero ninguno especifica *qué alimentos concretos comer en qué fecha*. El coach puede asignar una plantilla que diga "desayuno 480 kcal / 35g proteína" pero no puede decirle "el martes desayuna 100g de avena + 2 huevos".

`PlannedMeal` es el equivalente de `PlannedSession` para nutrición: un alimento concreto asignado a una fecha y tiempo de comida específicos.

```prisma
model PlannedMeal {
  id        String   @id @default(cuid())
  userId    String   // atleta que recibe el plan (o el mismo atleta si se planifica solo)
  date      DateTime @db.Date
  mealType  MealType
  foodId    String
  grams     Float
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  food      Food     @relation(fields: [foodId], references: [id])
  @@index([userId, date])
}
```

**Nota crítica:** `PlannedMeal` NO tiene campo `createdById` en el schema real. `userId` siempre es el atleta dueño del plan. Para distinguir si el plan lo creó el coach o el atleta mismo, el sistema usa el `userId` del JWT autenticado en el momento de la creación (si el JWT es de un coach → lo creó el coach; si es del atleta → se planificó él mismo).

### Flujo por actor

**Coach (NUTRITION o ALL):**
```
Tab Nutrición del atleta → Vista Semanal → Click en día
  → Agregar alimentos por tiempo de comida
  → Publicar → atleta lo ve como "Plan de tu coach"
```
- El coach crea `PlannedMeal` con `userId = athleteId` (el atleta es el dueño del registro)
- Habilita la métrica de adherencia nutricional en el panel del coach

**Atleta B2C autónomo:**
```
Tab Nutrición → Vista Semanal → Click en día futuro
  → Planificar mi semana → agregar alimentos
  → El día de la comida: "¿Registrar lo planeado?" → 1 tap → FoodLog
```
- El atleta crea `PlannedMeal` con su propio `userId`
- Elimina el principal punto de fricción: no hay que volver a buscar cada alimento

**Atleta B2B:**
- Recibe el plan del coach en su app
- El día llega: acepta (PlannedMeal → FoodLog) o registra lo que realmente comió
- El coach ve adherencia: % de días donde el atleta siguió el plan nutricional

### Regla de interpretación: origen del plan

La distinción "plan del coach" vs "plan propio del atleta" se hace por contexto de request, no por un campo en DB. Si `AssignedNutritionPlan` existe para el atleta → el badge "Plan de tu coach" se muestra. Los `PlannedMeal` creados por el coach aparecen etiquetados como "Plan de tu coach" en la UI porque el endpoint del coach los crea en nombre del atleta.

### Endpoints — estado actual (2026-07-30)

**Atleta (web) — implementados:**
```
GET   /api/athlete/nutrition/planned-meals           → plan de la semana (PlannedMealPlannerClient)
POST  /api/athlete/planned-meals                     → crear PlannedMeal propio
PATCH /api/athlete/nutrition/planned-meals/[id]      → editar gramos
DELETE /api/athlete/nutrition/planned-meals/[id]     → eliminar entrada
POST  /api/athlete/nutrition/planned-meals/log-today → 1 tap: todos los PlannedMeals de HOY → FoodLog
```

**Atleta (mobile) — implementados:**
```
GET  /api/mobile/nutrition/plan?date=YYYY-MM-DD      → plan del día
POST /api/mobile/nutrition/plan/[id]/log             → convierte PlannedMeal → FoodLog
POST /api/mobile/nutrition/planned-meals/log-today   → 1 tap log todos los de hoy
POST /api/mobile/nutrition/templates/[id]/apply      → aplicar template a la semana
```

**Coach — implementados:**
```
POST   /api/coach/athletes/[id]/nutrition/plan          → coach crea PlannedMeal para atleta
GET    /api/coach/athletes/[id]/nutrition/plan?week=    → ver plan de la semana del atleta
DELETE /api/coach/athletes/[id]/nutrition/plan/[mealId] → eliminar entrada
```

**Estado DB:** ✅ implementado (migración 20260708180057). El schema confirma que `PlannedMeal` solo tiene `userId` — no hay campo `createdById`.

## Qué sugiere el sistema y qué no

**El sistema sugiere estructura calórica — no alimentos concretos.**

```
Lo que SÍ muestra:
  Desayuno     → 480 kcal | 35g proteína | 50g carbs | 14g grasa
  Almuerzo     → 620 kcal | 45g proteína | 65g carbs | 18g grasa
  Cena         → 540 kcal | 40g proteína | 55g carbs | 16g grasa
  Snack        → 200 kcal | 10g proteína | 20g carbs | 6g grasa

Lo que NO hace:
  ✗ "Come 2 huevos + arepa + aguacate"
  ✗ Recetas específicas (eso es el módulo de recetas — roadmap)
  ✗ Sustituir el criterio del nutricionista o del coach
```

**Por qué este enfoque:**
- La diversidad alimentaria en LATAM es enorme — prescribir alimentos específicos sería invasivo y culturalmente incorrecto
- El atleta conoce su contexto, su presupuesto y sus preferencias
- El módulo de recetas (próximo) será construido con la comunidad — los mismos usuarios contribuyen recetas con sus macros, y el sistema las integra como opciones sugeridas dentro del target

**Guardrail importante:** el sistema nunca reemplaza a un nutricionista. Si el atleta tiene coach/nutricionista asignado, el plan base viene de él — el sistema solo ajusta el target del día según la intensidad del entrenamiento.

## Hoja de ruta del registro — por orden de impacto

El registro de comidas es el punto crítico. Cada mejora debe reducir la fricción del atleta, no agregar pasos.

### Prioridad 1 — Alimentos frecuentes (ya implementado parcialmente)
Los últimos alimentos registrados aparecen primero en la búsqueda. Sin tener que escribir nada, el atleta ve lo que comió ayer y lo repite en 1 tap.

### Prioridad 2 — Comidas guardadas (meal templates) — parcialmente implementado
El atleta guarda "Desayuno habitual" = arepa + huevo + jugo → lo registra en 1 tap cualquier día. En LATAM la gente come lo mismo repetidamente — esta feature tiene impacto alto con complejidad baja. Schema: `MealTemplate` + `MealTemplateItem` en DB. Endpoints: `api/athlete/nutrition/templates/`. UI web: `/nutrition/builder`. UI mobile: `nutrition-builder.tsx` + `nutrition-apply-template.tsx`.

### Prioridad 3 — Vista de progreso del día
Barra visual de kcal consumidas vs target + macros restantes en número: "Te faltan 45g de proteína". Ya existe parcialmente — necesita mejor visibilidad y ser el primer elemento visible en la pantalla de nutrición.

### Prioridad 4 — Resumen semanal de adherencia
"Esta semana llegaste a tu meta nutricional 5 de 7 días." Cierra el loop del registro y motiva la consistencia. Feed directo al coach si está asignado. Los boundaries de la semana (inicio/fin) se calculan respetando el timezone del usuario para que los datos agrupados sean consistentes con su día local.

### Prioridad 5 — Recetas — roadmap medio plazo
Guardar una receta con ingredientes → calcular macros totales → registrar como una unidad. Reduce el registro de comidas caseras complejas a 1 tap.

### Prioridad 6 — Reconocimiento de alimentos por foto (AI) — P2 roadmap
Foto de la comida → reconocimiento automático de alimentos y porciones via Claude Vision API. **No antes de validar el producto con usuarios reales** (condición vigente). Esta es la primera feature que introduce AI en producción — el producto es 100% determinista hoy. Decisión anterior de "P3/fuera de roadmap" estaba basada en modelos especializados tipo Lose It! Snap It (68.7% accuracy). Con LLM vision (Claude/GPT-4o) la accuracy es superior y no requiere modelo propio. Arquitectura: port IFoodRecognitionService en domain/ → adaptador ClaudeFoodRecognitionService en infrastructure/ai/ → endpoints API con rate limit 20/hora. Ver NUT-AI-01 en roadmap para detalle técnico completo.

## Librería de alimentos — regla de visibilidad

La librería es **global y compartida**. Todos los alimentos son visibles para todos los atletas. La personalización ocurre en el **plan nutricional**, no en la librería.

| Campo | Significado |
|-------|-------------|
| `isVerified: true` | Alimento curado por el equipo — aparece sin badge |
| `isVerified: false` | Alimento propuesto por la comunidad — aparece con badge "En revisión" |
| `isActive: false` | Rechazado o desactivado por admin — no aparece en ninguna búsqueda |
| `source: 'system'` | Seed del equipo Medaliq |
| `source: 'community'` | Propuesto por un atleta vía FoodProposal |
| `source: 'openfoodfacts'` | Importado por barcode scan desde Open Food Facts |
| `createdBy` | userId del atleta que lo propuso — solo para contexto admin, no controla visibilidad |

**Regla**: nunca filtrar `Food` por `createdBy` en búsquedas de atletas. El filtro correcto es solo `isActive: true`.

### Escáner de código de barras — implementado
Endpoint: `api/mobile/nutrition/foods/barcode/route.ts` — lookup EAN-8/13 vía `OpenFoodFactsClient` (`infrastructure/food/open-food-facts.client.ts`). Si el producto no existe en DB, se importa y cachea automáticamente. UI mobile: `BarcodeScannerModal` en la pantalla de nutrición.

### Lo que NO se construye ahora
Micronutrientes en cálculos/recomendaciones — los 6 campos (fibra, calcio, hierro, potasio, vitamina C, magnesio) se almacenan en Food y se muestran como badges informativos en la UI, pero NO se usan en fórmulas, targets ni propuestas. Integraciones con wearables para nutrición — complejidad alta para el valor que generan en esta etapa.

## Contexto de fase del plan en /nutrition (2026-07-09)

La página de nutrición del atleta muestra un banner azul si tiene plan activo:

```
PlanWeek.isRecoveryWeek = true  → "Semana de descarga — prioriza proteína y descanso"
Mayoría intensidades HIGH       → "Semana de carga alta — maximiza carbohidratos"
Mayoría intensidades MODERATE   → "Semana de carga moderada — equilibra macros"
Ninguna condición               → banner oculto
```

- Query: `prisma.planWeek.findFirst({ where: { planId, weekNumber: currentWeek }, select: { isRecoveryWeek, sessions: { select: { intensity } } } })`
- El banner es informativo — NO cambia los targets calóricos automáticamente
- Se inserta antes de las propuestas del coach y después del header

## Adherencia nutricional del coach — endpoint + card (2026-07-09)

**Endpoint:** `GET /api/coach/athletes/[id]/nutrition/adherence`
- Auth COACH + verifica `CoachAthlete` ownership
- Query: `FoodLog` últimos 28 días + `NutritionPlan.targetKcalEasy` del atleta
- Agrupa por día (`date.toISOString().slice(0,10)`), calcula `adherencePct = kcalLogged / targetKcalEasy * 100`
- Retorna `{ days: DayAdherence[], targetKcal: number | null }`

**Componente:** `NutritionAdherenceCard.tsx` en `/coach/athlete/[id]/_components/`
- Badge semana actual: verde ≥80%, amarillo 60-79%, rojo <60%
- Días registrados "X de 7"
- Sparkline 4 semanas: 4 barras verticales (naranja si ≥80%, gris si menor)
- Integrado en el Tab Nutrición de `AthleteDetailClient.tsx` ANTES de `FoodLogsSection`

**Cron alerta:** `GET /api/cron/nutrition-alert` (schedule: `0 9 * * *`)
- Si un atleta tiene 3 días seguidos con logs Y todos <60% del target → push al coach
- Solo aplica si el atleta registró algo esos días (no detecta "no registró nada")

## Historial adherencia nutricional en /progress (2026-07-09)

Gráfica de barras verticales con los últimos 30 días de FoodLog:
- Verde ≥80% del target, amarillo 60-79%, rojo <60%
- Target: `NutritionPlan.targetKcalEasy ?? targetKcalHard`
- Promedio del período en naranja (`#ea580c`) arriba a la derecha
- Solo se muestra si `nutritionAdherence.length > 0`
- Props nuevas en `ProgressClientProps`: `nutritionAdherence: NutritionAdherencePoint[]` + `nutritionTargetKcal: number`
- Type `NutritionAdherencePoint = { date: string, adherencePct: number }` exportado desde `ProgressClient.tsx`

## Paridad web/mobile — estado actual

| Feature | Mobile | Web |
|---------|--------|-----|
| Ver target diario + macros | ✅ | ✅ |
| Registrar comida (FoodLog) | ✅ | ✅ |
| Ver ajuste nutricional pendiente | ✅ | ✅ |
| Aceptar/rechazar ajuste | ✅ | ✅ |
| Ver plan de comidas sugerido | ✅ | ✅ |
| Banner contexto fase del plan (carga/descarga) | ❌ | ✅ |
| Gráfica adherencia 30 días en /progress | ✅ (2026-07-30) | ✅ |
| Coach ve adherencia nutricional del atleta | ❌ | ✅ (endpoint + card) |
| Water tracking widget | ✅ (2026-07-29) | ✅ (HydrationWidget) |
| Macro donut SVG (CalorieDonutHero) | ✅ (2026-07-29) | ✅ (CalorieDonutHero web) |
| TipCard contextual por tipo de día | ✅ (2026-09-10) | ✅ (tipSlot) |
| ProximaComidaCard (siguiente comida no logueada) | ✅ (2026-09-10) | ✅ (ProximaComidaCard web) |
| MealChecklistInline (checklist de comidas del plan) | ✅ (2026-09-10) | ✅ (MealListInline web) |
| CoachBanner B2B (nombre coach + plan asignado) | ✅ (2026-09-10) | ✅ (coachBannerSlot) |
| CoachCTA B2B ("Mensaje al coach") | ✅ (2026-09-10) | ✅ (Link → /mensajes) |
| Diferenciación 3 estados (sin-plan/con-plan/b2b) | ✅ (2026-09-10) | ✅ (NutritionPageClient) |
| 1-tap log de comidas planeadas de hoy | ✅ (2026-07-29) | ✅ (2026-07-29) |
| Apply NutritionTemplate a semana | ✅ (ApplyWeekModal/planner) | ✅ (2026-07-29) |
| Planificar alimentos concretos (atleta) | ✅ CRUD + planner web | ✅ GET + log |
| Coach asigna alimentos concretos al atleta | ⚙️ DB lista, endpoints pendientes | ✅ implementado |

**Web es el canal de gestión completa de nutrición.** El coach gestiona plantillas, targets y propone ajustes desde web. El atleta puede gestionar todo desde web también — `NutritionAdjustmentCard` + endpoints `/api/athlete/nutrition/adjustment/[id]/accept|reject` implementados (BUG-038 resuelto). Mobile es el canal de registro diario rápido del atleta.

## Pantalla de nutrición — 3 estados y orden de render (2026-09-10)

La pantalla de nutrición (web y mobile) renderiza componentes en diferente orden según el estado del atleta. Fuente de verdad: Figma frames `4523:550` (sin-plan), `4523:633` (con-plan), `4523:753` (b2b).

**Detección de estado:**
- `sin-plan`: `!hasNutritionPlan` (atleta sin plan nutricional activo)
- `con-plan`: `hasNutritionPlan && !isB2B` (plan del sistema o propio)
- `b2b`: `!!assignedNutritionPlan` (coach asignó template de nutrición)

**Orden mobile (React Native `nutrition.tsx`):**
```
sin-plan:  Donut(0/0) → Hydration → Activity → EmptyState → Tip → Weekly
con-plan:  Adjustment → Activity → Donut → Hydration → MealChecklist → NextMeal → Weekly → Tip → CTAs
b2b:       CoachBanner → Adjustment → Donut → Hydration → Activity → MealChecklist → NextMeal → Tip → CoachCTA → Weekly
```

**Orden web mobile (`NutritionPageClient.tsx` — div `lg:hidden`):**
```
sin-plan:  Proposal → Donut → Hydration → Activity → EmptyState → Tip → Adherence → Weekly → Tracking
con-plan:  Proposal → Activity → Donut → Hydration → MealChecklist → NextMeal → Adherence → Tip → Weekly → Tracking
b2b:       CoachBanner → Proposal → Donut → Hydration → Activity → MealChecklist → NextMeal → Tip → CoachCTA → Adherence → Weekly → Tracking
```

**API unificada mobile:** `GET /api/mobile/nutrition/today` retorna todos los campos necesarios en un solo request:
- `isB2B`, `coachName`, `planName` — detección de estado B2B
- `mealChecklist: MealCheckItem[]` — comidas del plan con estado logged/pending
- `nextMeal: NextMealData | null` — siguiente comida no logueada
- `tip: { title, body } | null` — tip contextual por intensidad del día

**Componentes mobile (inline en `nutrition.tsx`):**
- `TipCard` — card amber con tip contextual por dayType
- `ProximaComidaCard` — highlight de siguiente comida con accent naranja
- `CoachBanner` — avatar + nombre del coach + nombre del plan (solo B2B)
- `CoachCTA` — pill "Mensaje al coach" (solo B2B)
- `MealChecklistInline` — checklist de comidas del plan con estado logged/pending

## Modelos adicionales — DB-17/18/19 (migración 20260708180057)

### WaterLog (DB-18)
Tracking de hidratación diaria del atleta.
- `userId`, `date @db.Date`, `mlLogged Int`
- `@@unique([userId, date])` — un registro por día (se acumula en el mismo registro o se reemplaza)
- La operación de registro es un upsert atómico — si ya existe un registro para ese día, se suma al existente en una sola operación. El cast de fecha a tipo date asegura que la comparación sea correcta independientemente del timezone del request.
- `NutritionPlan.waterMlTarget Int? @default(2000)` — meta diaria personalizable
- **Web ✅ (NUT-WATER-01 2026-07-29):** `GET|POST /api/athlete/nutrition/water`. `HydrationWidget.tsx` con update optimista, 3 botones (+250ml/+500ml/+1L), barra azul, badge "¡Meta lograda!".
- **Mobile ✅ implementado:** endpoint `GET|POST /api/mobile/nutrition/water` + widget equivalente en mobile.

### Recipe + RecipeIngredient (DB-17)
Recetas compuestas del atleta: combinación de alimentos del catálogo con gramos específicos.
- `Recipe`: `userId`, `name`, `ingredients RecipeIngredient[]`
- `RecipeIngredient`: `recipeId`, `foodId`, `grams Float`
- Una Recipe se puede loguear como una entrada en FoodLog (los macros se calculan sumando ingredientes)
- **DEPRECATED (NUT-13): modelos presentes en schema.prisma pero sin endpoints activos. No implementar ni referenciar desde código nuevo. Pendientes de eliminación del schema.**

### MealPlanVersion (DB-19)
Historial de versiones del plan de comidas asignado al atleta.
- `mealPlanId`, `version Int`, `planData Json` (snapshot completo), `assignedById?`
- Permite auditar cambios que el coach hace al plan nutricional a lo largo del tiempo
- **DEPRECATED (NUT-13): modelo presente en schema.prisma pero sin endpoints activos. No implementar ni referenciar desde código nuevo. Pendiente de eliminación del schema.**

## Principio de tracking: solo lo que el usuario confirma

**Regla fundamental: el sistema NO registra comida automáticamente. Solo muestra lo que el atleta registró explícitamente.**

```
FoodLog se crea SOLO cuando:
  1. Atleta busca un alimento y lo registra manualmente (POST /api/.../nutrition/log)
  2. Atleta confirma "Registrar lo planeado" para sus PlannedMeals del día (POST .../log-today)
  3. Atleta escanea un barcode y confirma gramos (POST /api/mobile/nutrition/log)

FoodLog NUNCA se crea por:
  ✗ Tener un plan nutricional activo
  ✗ Tener PlannedMeals asignados (planear ≠ comer)
  ✗ Pasar a un nuevo día del calendario
  ✗ El sistema o el coach de forma automática
  ✗ El seed para el día actual (seed solo crea datos históricos, d >= 1)
```

**Consecuencia en dashboard:** si `computeFoodTotals()` retorna `null` (0 food logs para hoy), el componente muestra "Sin registros hoy" y 0 kcal consumidas. El donut queda vacío. Esto es correcto — el atleta aún no ha comido (o no lo ha registrado).

**Consecuencia en adherencia:** un día sin FoodLog no cuenta como "0% adherencia" — cuenta como "sin datos". La adherencia solo se calcula sobre días donde el atleta registró al menos 1 comida.

## Lo que NO hace el módulo

- No recalcula TDEE automáticamente — `syncWeight` solo guarda el peso nuevo en `HealthProfile.weightKg`, sin recalcular TDEE ni macros (R3 completado)
- No genera meal plans sin que haya un `NutritionPlan` activo
- No modifica macros del plan base cuando el atleta registra comida
- No crea FoodLog automáticamente — solo el atleta decide qué y cuándo registrar
