# NUTRITION TEMPLATES — Swap, Grocery, MealTemplates, NutritionTemplates

<!-- mirror: true -->
<!-- mirror-endpoints: GET/POST/DELETE /api/athlete/nutrition/meal-templates ↔ /api/mobile/nutrition/meal-templates, POST /api/athlete/nutrition/templates/[id]/apply ↔ /api/mobile/nutrition/templates/[id]/apply -->

> Split de nutrition.spec.md. Templates y herramientas de planificacion.
> Specs relacionadas: `nutrition_tracking.spec.md`, `nutrition_plans.spec.md`, `nutrition_proposals.spec.md`
> Domain doc: `../domains/nutricion.md`

## TL;DR
- 16 endpoints (8 web, 8 mobile + swap exclusivo mobile)
- Modelos: MealTemplate, NutritionTemplate, NutritionTemplateDay, NutritionTemplateMeal, NutritionTemplateFoodItem
- Dependencias: getIntensityMapForDateRange(), calcMacros()
- Trampas criticas: apply borra TODA la semana (destructivo), coachId:null filtro critico, swap ±10% kcal
- Mirror mobile: meal-templates, templates (swap solo mobile, grocery difiere en servingLabel)

---

## Contratos de la AI

- El swap de alimentos tiene tolerancia de **±10% kcal** entre el alimento original y el sustituto. Si la diferencia supera el 10%, devuelve 422.
- `NutritionTemplate` con `coachId: null` es una plantilla del atleta B2C. Las plantillas con `coachId != null` son del coach. El atleta B2C solo puede crear/editar templates propias (`coachId: null`).
- Un atleta con `CoachAthlete.status = 'ACTIVE'` NO puede crear `NutritionTemplate` propia. Recibe 403.
- La macro `apply` de `NutritionTemplate` hace un **delete + createMany** atomico en `$transaction`. Borra TODOS los `PlannedMeal` de la semana antes de crear los nuevos.
- `log-today` es idempotente: usa `createMany({ skipDuplicates: true })`.
- Los `NutritionTemplateFoodItem` guardan macros pre-calculados como snapshot (no se recalculan al leer).
- `NutritionTemplateMeal` hace upsert por `dayId_mealType`: reutiliza la meal existente o la crea.

---

## Endpoints

### Web

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/athlete/nutrition/grocery-list` | ninguna | ninguna | Lista de compras semanal |
| GET | `/api/athlete/nutrition/meal-templates` | ninguna | ninguna | Listar MealTemplates |
| POST | `/api/athlete/nutrition/meal-templates` | ninguna | ninguna | Crear MealTemplate (max 20 items) |
| DELETE | `/api/athlete/nutrition/meal-templates/[id]` | ninguna | ninguna | Borrar MealTemplate |
| GET | `/api/athlete/nutrition/templates` | ninguna | ninguna | Listar NutritionTemplates propias |
| POST | `/api/athlete/nutrition/templates` | ninguna | ninguna | Crear NutritionTemplate (B2C sin coach) |
| GET | `/api/athlete/nutrition/templates/[id]` | ninguna | ninguna | Detalle con arbol completo |
| PATCH | `/api/athlete/nutrition/templates/[id]` | ninguna | ninguna | Editar name/description/goal |
| DELETE | `/api/athlete/nutrition/templates/[id]` | ninguna | ninguna | Borrar (cascade) |
| POST | `/api/athlete/nutrition/templates/[id]/meals` | ninguna | ninguna | Agregar alimento a comida |
| DELETE | `/api/athlete/nutrition/templates/[id]/meals` | ninguna | ninguna | Borrar item (body: itemId) |
| POST | `/api/athlete/nutrition/templates/[id]/apply` | ninguna | ninguna | Expandir a semana como PlannedMeals |

### Mobile

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/mobile/nutrition/grocery-list` | 60/min | nutrition | Lista de compras semanal |
| GET | `/api/mobile/nutrition/meal-templates` | 300/min | nutrition | Listar MealTemplates |
| POST | `/api/mobile/nutrition/meal-templates` | 100/min | nutrition | Crear MealTemplate |
| DELETE | `/api/mobile/nutrition/meal-templates/[id]` | 100/min | nutrition | Borrar MealTemplate |
| GET | `/api/mobile/nutrition/templates` | 300/min | nutrition | Listar propias |
| POST | `/api/mobile/nutrition/templates` | 30/min | nutrition | Crear (B2C sin coach) |
| POST | `/api/mobile/nutrition/templates/[id]/meals` | 120/min | nutrition | Agregar alimento |
| DELETE | `/api/mobile/nutrition/templates/[id]/meals` | 60/min | nutrition | Borrar item |
| POST | `/api/mobile/nutrition/templates/[id]/apply` | 100/min | nutrition | Expandir a semana |
| POST | `/api/mobile/nutrition/plan/[id]/swap` | 100/min | nutrition | Sustituir alimento (±10% kcal) |
| DELETE | `/api/mobile/nutrition/plan/[id]/swap` | 100/min | nutrition | Restaurar alimento original |

---

## Detalle de endpoints

### Swap de Alimentos (solo mobile)

#### POST `/api/mobile/nutrition/plan/[id]/swap`
**Body**: `{ foodId: string, grams: number }`
1. Verifica ownership del PlannedMeal
2. Calcula diferencia porcentual kcal
3. Si > 10%: 422 con mensaje que incluye kcal de ambos
4. Upsert en `AthleteNutritionOverride`

#### DELETE `/api/mobile/nutrition/plan/[id]/swap`
Borra override. Idempotente.

### Grocery List (web y mobile)

**Request**: `?weekStart=YYYY-MM-DD` (default: lunes actual UTC)
Agrupa gramos por alimento, agrupa por categoria, ordena: PROTEIN, CARB, VEGETABLE, FRUIT, DAIRY, LEGUME, FAT, NUT_SEED, OTHER.
**Diferencia**: web incluye `servingLabel`; mobile no.

### MealTemplates

**POST schema**: `{ name: string, mealType?: string, items: [{ foodId, grams }] min(1) max(20) }`
DELETE verifica `template.userId === session.userId`.

### NutritionTemplates

**POST**: Verifica B2C (sin coach ACTIVE). Crea con 3 dias: HARD, EASY, REST.

**POST meals**: `{ dayType, mealType, foodId, grams }` en `$transaction`: upsert meal por `dayId_mealType`, crea item con macros snapshot.

**POST apply (web)**: `{ weekStartDate }` — calcula intensityMap desde DB, mapea HIGH→HARD, luego delete+createMany en $transaction.

**POST apply (mobile)**: `{ weekStart, intensityMap }` — mobile envia el intensityMap directamente. Misma logica de delete+createMany.

---

## Modelos DB

### MealTemplate
```
id, userId, name, mealType?
items → MealTemplateItem[] (foodId, grams)
```

### NutritionTemplate
```
id, athleteId, coachId? (null = del atleta)
name, description?, goal?
days → NutritionTemplateDay[] (dayType: HARD|EASY|REST)
  meals → NutritionTemplateMeal[] (mealType, order)
    items → NutritionTemplateFoodItem[] (foodId, grams, kcal, proteinG, carbsG, fatG, order)
```

---

## Reglas de negocio

1. `apply` de template borra TODOS los PlannedMeals de la semana antes de crear los nuevos. Es destructivo.
2. El swap requiere kcal dentro del ±10% del original. Se valida con grams incluidos.
3. Los `NutritionTemplateFoodItem` guardan macros pre-calculados como snapshot.
4. `NutritionTemplateMeal` hace upsert por `dayId_mealType`.
5. La adherencia en `planned-summary` se capea al 150%.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `apply` template: week borrada | Parece que solo agrega meals | Borra TODOS los PlannedMeals. Si el template no tiene un dia, queda sin meals. |
| `NutritionTemplate coachId: null` | Parece innecesario filtrar | Critico: sin el filtro, el atleta podria ver/editar templates del coach. |

---

## Paridad web vs mobile

| Funcionalidad | Web | Mobile | Diferencia |
|--------------|-----|--------|-----------|
| Grocery list | `GET /athlete/nutrition/grocery-list` | `GET /mobile/nutrition/grocery-list` | Web incluye `servingLabel`; mobile no |
| Meal templates GET | `GET /athlete/nutrition/meal-templates` | `GET /mobile/nutrition/meal-templates` | Identico |
| Meal templates POST | `POST /athlete/nutrition/meal-templates` | `POST /mobile/nutrition/meal-templates` | Identico |
| Meal templates DELETE | `DELETE /athlete/nutrition/meal-templates/[id]` | `DELETE /mobile/nutrition/meal-templates/[id]` | Identico |
| Nutrition templates GET | `GET /athlete/nutrition/templates` | `GET /mobile/nutrition/templates` | Identico |
| Nutrition templates POST | `POST /athlete/nutrition/templates` | `POST /mobile/nutrition/templates` | Identico. B2B → 403 en ambos |
| Nutrition templates PATCH | `PATCH /athlete/nutrition/templates/[id]` | No existe | Solo web |
| Nutrition templates DELETE | `DELETE /athlete/nutrition/templates/[id]` | No existe | Solo web |
| Template meals POST/DELETE | `POST/DELETE /athlete/nutrition/templates/[id]/meals` | `POST/DELETE /mobile/nutrition/templates/[id]/meals` | Identico |
| Template apply | `POST /athlete/nutrition/templates/[id]/apply` | `POST /mobile/nutrition/templates/[id]/apply` | Web calcula intensityMap desde DB. Mobile recibe `intensityMap` directamente en el body |
| Swap alimento | No existe | `POST/DELETE /mobile/nutrition/plan/[id]/swap` | Solo mobile — sustituye alimento en PlannedMeal con tolerancia ±10% kcal |

---

## Tests requeridos

### Swap
- [ ] POST swap: diferencia kcal <= 10% → crea override
- [ ] POST swap: diferencia kcal > 10% → 422
- [ ] DELETE swap: idempotente

### Templates
- [ ] POST templates: atleta B2B recibe 403
- [ ] POST templates/[id]/apply: borra PlannedMeals existentes de la semana
- [ ] DELETE templates/[id]/meals: verifica ownership completo

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-05 | Fix: feature gate `nutrition` en los 9 endpoints mobile (antes decia "ninguna") |
| 2026-10-02 | Split desde nutrition.spec.md — templates (Groups 6, 9-11) |
| 2026-10-02 | Paridad web↔mobile completada: swap solo mobile, apply difiere en intensityMap, grocery servingLabel |
| 2026-09-29 | Spec original creada |
