# NUTRITION — Indice de specs de nutricion

> **ARCHIVO INDICE** — no contiene contratos. Lee el sub-spec relevante a tu tarea.
> Domain doc: `../domains/nutricion.md`

## Sub-specs (lee SOLO el que necesites)

| Sub-spec | Scope | Cuando leer |
|----------|-------|-------------|
| `nutrition_tracking.spec.md` | Food log, foods, water, barcode, log/summary | Tocas registro de alimentos, busqueda de foods, agua, barcode |
| `nutrition_plans.spec.md` | Planned meals, targets, B2B assigned plan, food profile, init/generate | Tocas planificacion de comidas, targets nutricionales, food profile, B2B |
| `nutrition_templates.spec.md` | MealTemplates, NutritionTemplates, swap, grocery list | Tocas plantillas, swap de alimentos, lista de compras |
| `nutrition_proposals.spec.md` | Coach proposals, /today endpoint unificado, UI CTAs | Tocas propuestas del coach, endpoint /today mobile, UI nutricion |

## Regla

NO leas este archivo completo. Identifica tu tarea, lee el sub-spec correspondiente.
Si tu tarea cruza multiples sub-specs, lee solo los relevantes.

---

## Paridad web <-> mobile (resumen)

Cada sub-spec tiene su tabla de paridad detallada. Resumen ejecutivo:

| Funcionalidad | Web | Mobile | Sub-spec |
|--------------|-----|--------|---------|
| Food log GET/POST/DELETE | `/api/athlete/nutrition/log` | `/api/mobile/nutrition/log` (+ feature gate `nutrition`) | tracking |
| Food log summary semanal | No existe | `GET /api/mobile/nutrition/log/summary` | tracking |
| Foods search | `/api/athlete/nutrition/foods` | `/api/mobile/nutrition/foods` | tracking |
| Foods crear directo | `POST /api/athlete/nutrition/foods` | No existe (solo via propose) | tracking |
| Barcode scanner | No existe | `GET/POST /api/mobile/nutrition/foods/barcode` | tracking |
| Water GET/POST | `/api/athlete/nutrition/water` | `/api/mobile/nutrition/water` | tracking |
| Food proposals | `/api/athlete/nutrition/foods/propose` | `/api/mobile/nutrition/foods/propose` | tracking |
| Planned meals | `/api/athlete/nutrition/planned-meals` | `/api/mobile/nutrition/planned-meals` | plans |
| Targets nutricionales | `GET/PATCH /api/athlete/nutrition/targets` | No existe (B2B no puede editar) | plans |
| Food profile | `/api/athlete/nutrition/food-profile` | `/api/mobile/nutrition/food-profile` | plans |
| Plan fecha especifica | No existe | `GET /api/mobile/nutrition/plan` | plans |
| Assigned plan (B2B) | No existe | `GET /api/mobile/nutrition/assigned-plan` | plans |
| Grocery list | `/api/athlete/nutrition/grocery-list` | `/api/mobile/nutrition/grocery-list` (sin `servingLabel`) | templates |
| Meal templates | `/api/athlete/nutrition/meal-templates` | `/api/mobile/nutrition/meal-templates` | templates |
| Nutrition templates | `/api/athlete/nutrition/templates` | `/api/mobile/nutrition/templates` (sin PATCH template) | templates |
| Swap alimento | No existe | `POST/DELETE /api/mobile/nutrition/plan/[id]/swap` | templates |
| Coach proposals | `GET/PATCH /api/athlete/nutrition/proposals` | `GET/POST /api/mobile/nutrition/proposals` (POST vs PATCH) | proposals |
| Endpoint unificado hoy | No existe | `GET /api/mobile/nutrition/today` (13 queries paralelas) | proposals |
| Adjustments (DEPRECATED) | `/api/athlete/nutrition/adjustment/[id]/accept|reject` | `/api/mobile/nutrition/adjustment/[id]/accept|reject` | proposals |

**Divergencias clave:**
- `NUT-14`: `/api/mobile/nutrition/today` es el endpoint unificado mobile (13 queries). No tiene equivalente web — web usa RSC + endpoints separados.
- `NUT-15`: `PendingNutritionAdjustment` DEPRECATED. `pendingAdjustment` siempre `null` en `/today`. No generar nuevos.
- Barcode scanner es exclusivo mobile (OpenFoodFacts integration).
- Targets solo editables desde web (B2C sin coach activo). Mobile consume pero no edita.

---

*Archivo original (936 lineas) dividido el 2026-10-02 para reducir consumo de tokens.*
