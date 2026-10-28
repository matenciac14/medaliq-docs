# NUTRITION TRACKING — Food Log, Foods, Water, Barcode

<!-- mirror: true -->
<!-- mirror-endpoints: GET/POST/DELETE /api/athlete/nutrition/log ↔ /api/mobile/nutrition/log, GET /api/athlete/nutrition/foods ↔ /api/mobile/nutrition/foods, GET/POST /api/athlete/nutrition/water ↔ /api/mobile/nutrition/water -->

> Split de nutrition.spec.md. Solo tracking diario.
> Specs relacionadas: `nutrition_plans.spec.md`, `nutrition_templates.spec.md`, `nutrition_proposals.spec.md`
> Domain doc: `../domains/nutricion.md`

## TL;DR
- 16 endpoints (9 web, 7 mobile + barcode exclusivo)
- Modelos: Food, FoodLog, WaterLog, FoodProposal
- Dependencias: calcMacros(), countryFromTimezone(), buildFoodLogResponse()
- Trampas criticas: UTC midnight en web food log, kcalLogged null recalcula, water timezone asimetria
- Mirror mobile: log, foods, water (barcode solo mobile)

---

## Contratos de la AI

- Los macros en `FoodLog` son **snapshots inmutables** calculados al momento del log. `kcalLogged`, `proteinLogged`, `carbsLogged`, `fatLogged` se persisten en DB y NO se recalculan desde `Food` al leer. Si `kcalLogged` es null (logs previos a migracion), se recalcula on-the-fly con `calcMacros()`.
- El **upsert de FoodLog** (PERSIST-01) suma gramos si el mismo `userId+foodId+date+mealType` ya existe. No crea duplicados. Mobile usa `$transaction` para garantizar atomicidad; web hace findUnique+create/update secuencial.
- El **upsert de WaterLog** usa raw SQL (`$queryRaw`) con `ON CONFLICT DO UPDATE SET mlLogged = GREATEST(0, mlLogged + delta)`. Nunca puede quedar negativo.
- La funcion `countryFromTimezone()` tiene default `'CO'` cuando el timezone no esta en el mapa o es null. La ordenacion de alimentos en `/foods` depende de esto.
- La ordenacion de alimentos en GET /foods sigue este orden estricto: (0) favoritos del atleta (`FoodProfile.availableFoodIds`), (1) mismo pais que el atleta, (2) globales (`food.country === null`), (3) resto. El resultado final se trunca a 50 items aunque se consultaron 80.

---

## Endpoints

### Web (auth via `auth()` de Auth.js)

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/athlete/nutrition/log` | 300/min | featureNutrition (session) | Food log del dia (date param o hoy UTC) |
| POST | `/api/athlete/nutrition/log` | 100/min | featureNutrition (session) | Registrar alimento (upsert si existe mismo food+date+mealType) |
| DELETE | `/api/athlete/nutrition/log/[id]` | 60/min | featureNutrition (session) | Borrar entrada del food log |
| GET | `/api/athlete/nutrition/foods` | 300/min | featureNutrition (session) | Buscar alimentos (q param), ordenados por pais/favoritos |
| POST | `/api/athlete/nutrition/foods` | 10/min | featureNutrition (session) | Crear alimento propio (no verificado) |
| POST | `/api/athlete/nutrition/foods/propose` | 10/hora | featureNutrition (session) | Proponer alimento para revision admin |
| GET | `/api/athlete/nutrition/foods/my-proposals` | 300/min | featureNutrition (session) | Ver propias propuestas de alimento |
| GET | `/api/athlete/nutrition/water` | 300/min | featureNutrition (session) | Agua de hoy (timezone del usuario) |
| POST | `/api/athlete/nutrition/water` | 100/min | featureNutrition (session) | Sumar/restar ml de agua (delta, atomic upsert SQL) |

### Mobile (auth via `getMobileUser()`, JWT jose)

| Method | Path | Rate limit | Feature gate | Descripcion |
|--------|------|-----------|--------------|-------------|
| GET | `/api/mobile/nutrition/log` | 300/min | nutrition | Food log del dia con soporte de ?tz= y ?date= |
| POST | `/api/mobile/nutrition/log` | 100/min | nutrition | Registrar alimento (upsert atomico con $transaction) |
| DELETE | `/api/mobile/nutrition/log/[id]` | 60/min | nutrition | Borrar entrada del food log |
| GET | `/api/mobile/nutrition/log/summary` | 300/min | nutrition | Resumen semanal: dias con log, avg kcal, adherencia |
| GET | `/api/mobile/nutrition/foods` | 300/min | nutrition | Buscar alimentos (q param), mismo algoritmo de orden que web |
| POST | `/api/mobile/nutrition/foods/propose` | 10/hora | ninguna | Proponer alimento para revision admin |
| GET | `/api/mobile/nutrition/foods/my-proposals` | 120/min | ninguna | Ver propias propuestas de alimento |
| GET | `/api/mobile/nutrition/foods/barcode` | 60/min | ninguna | Lookup por codigo de barras (DB → OpenFoodFacts) |
| POST | `/api/mobile/nutrition/foods/barcode` | 10/min | ninguna | Confirmar y crear alimento desde Open Food Facts |
| GET | `/api/mobile/nutrition/water` | 300/min | ninguna | Agua de hoy (?tz= param) |
| POST | `/api/mobile/nutrition/water` | 100/min | ninguna | Sumar/restar ml de agua (delta, atomic upsert SQL) |

---

## Detalle de endpoints

### Grupo 1 — Food Log

#### GET `/api/athlete/nutrition/log` y GET `/api/mobile/nutrition/log`

**Request**
- `?date=YYYY-MM-DD` (opcional) — sin fecha: web usa UTC hoy, mobile usa `todayInTz(tz)`
- `?tz=America/Bogota` (solo mobile) — timezone para calcular "hoy"

**Logica**
1. Resuelve `dayStart`/`dayEnd` para el rango del dia
2. Queries paralelas: `FoodLog[]` + `NutritionPlan` + sesion activa del dia
3. Web: busca sesion via `week.plan.userId` con status ACTIVE. Mobile: busca via `week.planId + weekNumber`
4. Llama a `buildFoodLogResponse()` — calcula totals, targets, pct

**Response**
```json
{
  "date": "YYYY-MM-DD",
  "dayType": "hard|easy|low|rest",
  "logs": [{ "id", "foodId", "food": {...}, "grams", "mealType", "date", "kcal", "proteinG", "carbsG", "fatG" }],
  "totals": { "kcal", "proteinG", "carbsG", "fatG" },
  "target": { "kcal", "proteinG", "carbsG", "fatG" } | null,
  "pct": { "kcal", "proteinG", "carbsG", "fatG" } | null
}
```

**Trampas**
- Web calcula `dayStart` como `new Date(\`${dateParam}T00:00:00.000Z\`)` — siempre UTC midnight. No hay timezone awareness en web para el food log (a diferencia del water y planned-meals).
- Mobile calcula `dayEnd` como `dayStart + 86_399_999 ms` (no usa `T23:59:59.999Z`).
- `buildFoodLogResponse`: si `kcalLogged` es null, recalcula desde `food.kcalPer100g * grams / 100`. Esto puede diferir levemente de lo que se guardo originalmente si los macros del alimento cambiaron.

#### POST `/api/athlete/nutrition/log` y POST `/api/mobile/nutrition/log`

**Request body**
```json
{ "foodId": "string", "grams": number, "mealType": "BREAKFAST|LUNCH|DINNER|SNACK|PRE_WORKOUT|POST_WORKOUT", "date": "YYYY-MM-DD" }
```

**Validacion** (via `parseFoodLogPost`):
- `foodId`, `grams`, `mealType` requeridos
- `grams` debe ser positivo y <= 5000
- `date` en formato YYYY-MM-DD si se provee
- `mealType` debe estar en los 6 valores validos

**Logica**
1. Busca el `Food` por id
2. Calcula snapshot de macros via `calcMacros(grams, food)`
3. Busca si ya existe un `FoodLog` con el mismo `userId_foodId_date_mealType`
4. Si existe: suma los gramos, recalcula snapshot total, hace UPDATE
5. Si no existe: hace CREATE
6. Web: secuencial (findUnique + create/update). Mobile: `$transaction` para atomicidad

**Response**: el FoodLog creado/actualizado con macros inline. Status 200 si update, 201 si create.

#### DELETE `/api/athlete/nutrition/log/[id]` y DELETE `/api/mobile/nutrition/log/[id]`

- Verifica que `log.userId === session.userId` antes de borrar (403 si no coincide)
- Mobile agrega rate limit 60/min y feature gate `nutrition`

---

### Grupo 2 — Foods

#### GET `/api/athlete/nutrition/foods` y GET `/api/mobile/nutrition/foods`

**Request**: `?q=texto` (opcional, case-insensitive, sin minimo de caracteres)

**Logica**
1. Query paralela: `Food[]` (max 80, `isActive: true`, filtro por nombre si hay `q`) + `FoodProfile` del usuario + `User.timezone`
2. `countryFromTimezone(user.timezone)` → default `'CO'` si timezone no reconocido
3. Sort in-memory con ranking: 0=favorito, 1=mismo pais, 2=global (sin pais), 3=otro
4. Retorna `.slice(0, 50)` del resultado ordenado

**Diferencia web vs mobile**: identica logica. Web no tiene rate limit en este endpoint; mobile tiene 300/min.

#### POST `/api/athlete/nutrition/foods` (solo web)

Crea un alimento con `isVerified: false`. Solo requiere name, category, y los 4 macros base. Micronutrientes opcionales. `servingG` default 100 si no se provee.

**NO existe equivalente mobile** para crear alimentos libremente. Mobile usa barcode o propose.

#### GET + POST `/api/mobile/nutrition/foods/barcode`

- GET `?code=...`: valida formato EAN-8/EAN-13. Busca en DB primero; si no, consulta OpenFoodFacts. Si OFF responde, retorna `{ needsConfirmation: true, suggestion: {...} }` sin crear nada.
- POST: recibe los datos del alimento confirmado por el atleta y lo crea en DB con `source: 'openfoodfacts'`, `isVerified: false`, `category: 'OTHER'`.

---

### Grupo 3 — Water

#### GET `/api/athlete/nutrition/water` y GET `/api/mobile/nutrition/water`

- Web: obtiene timezone del usuario desde DB, calcula `today` con `todayInTz(tz)`
- Mobile: recibe `?tz=` del cliente (no consulta DB en GET)
- Retorna `{ mlLogged: number, waterMlTarget: number }`. Default `waterMlTarget: 2000` si no hay NutritionPlan.

#### POST `/api/athlete/nutrition/water` y POST `/api/mobile/nutrition/water`

**Request body**: `{ delta: number }` — puede ser positivo (sumar) o negativo (restar). No puede quedar por debajo de 0.

**Logica**: raw SQL con `INSERT ... ON CONFLICT DO UPDATE SET mlLogged = GREATEST(0, mlLogged + delta)`. Atomico.

**Diferencia mobile**: si no viene `?tz=` en el POST, busca timezone en DB como fallback. Web siempre consulta DB para el timezone.

**Cast SQL:** Water POST usa `::date` cast (no `::timestamp`) para la columna `date` que es `@db.Date`. Ver trampa T23 en `_traps.spec.md`.

---

## Modelos DB

### Food
```
id, name, category (FoodCategory), isActive, isVerified
kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g
fiberPer100g?, calciumMg?, ironMg?, potassiumMg?, vitaminCMg?, magnesiumMg?
servingG (default 100), servingLabel?
country? (ISO 3166-1 alpha-2)
barcode? (unique), source? (openfoodfacts | manual)
createdBy?
```

### FoodLog
```
id, userId, foodId
date (@db.Date — date only, no time component)
mealType (MealType enum)
grams
kcalLogged?, proteinLogged?, carbsLogged?, fatLogged? — snapshot
@@unique([userId, foodId, date, mealType])
```

### WaterLog
```
id, userId, date (@db.Date)
mlLogged
@@unique([userId, date])
```

### FoodProposal (para review de admin)
```
id, submittedById, name, category
kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g
servingG?, servingLabel?, country?, notes?
status ('PENDING' | 'APPROVED' | 'REJECTED')
reviewNote?
foodId? (cuando se aprueba y se crea el Food)
```

---

## Reglas de negocio

1. Los macros en `FoodLog` son snapshots: se calculan y guardan al momento del log. No dependen de futuras actualizaciones al alimento.
2. El agua nunca puede quedar negativa: `GREATEST(0, mlLogged + delta)` en SQL.
3. Los alimentos del catalogo se filtran por `isActive: true` en todas las queries del atleta.
4. `countryFromTimezone()` tiene default `'CO'` (Colombia) para timezones no reconocidos o null.
5. La ordenacion de alimentos prioriza: favoritos del atleta > mismo pais > globales (sin pais) > resto. Resultado truncado a 50 items.
6. `log-today` es idempotente via `skipDuplicates: true` en `createMany`. Puede ejecutarse multiples veces sin efectos secundarios.
7. `planned-summary` tiene el timezone hardcodeado a `'America/Bogota'`. No es dinamico.
8. Propuestas de alimentos (`/foods/propose`): rate limit de 10 por hora. No 10 por minuto.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Web food log usa UTC midnight | Puede parecer que soporta timezone | `new Date(\`${dateParam}T00:00:00.000Z\`)` siempre UTC. El usuario en Bogota que registra a las 11pm podria logear en "otro dia". |
| Mobile log `dayEnd` | `dayStart + 86399999ms` parece correcto | Es correcto para dias de 24h pero falla en cambios de horario de verano (Bogota no tiene DST, pero otros timezones si). |
| `buildFoodLogResponse` usa snapshot si existe | Parece que siempre usa snapshot | Solo usa snapshot si `kcalLogged != null`. Logs pre-migracion recalculan desde macros actuales del alimento. |
| `FoodProfile.availableFoodIds` en ordenacion | Parece que filtra los alimentos | Solo reordena. Los alimentos no en el perfil siguen apareciendo, solo con rank mas bajo. |
| Water POST mobile: timezone | Parece que usa `?tz=` del request | Si no viene `?tz=` en el POST, consulta DB. El GET lee `?tz=` directamente. Asimetria intencional. |
| log/summary week boundaries | Parece que usa rangos fijos de 7 dias | Usa `getWeekMonday()` timezone-aware para calcular limites de semana — el lunes se calcula en el timezone del usuario, no en UTC. |
| FoodSearchModal res.json() | Parece seguro llamar res.json() directo | Debe verificar `res.ok` ANTES de `res.json()` — un 4xx/5xx puede crashear la UI si no se maneja. |
| Barcode POST: race condition | Dos requests simultaneos podrian crear el mismo barcode | El endpoint tiene una verificacion `findUnique` antes del `create`, pero no usa una transaccion. En raza podrian crearse dos. El `barcode` es unique en DB, el segundo fallaria con error de Prisma. Manejarlo en cliente. |

---

## Paridad web vs mobile

| Funcionalidad | Web path | Mobile path | Diferencia |
|--------------|---------|-------------|-----------|
| Food log GET | `/api/athlete/nutrition/log` | `/api/mobile/nutrition/log` | Mobile: feature gate `nutrition`, soporte `?tz=`, $transaction en POST |
| Food log POST | idem | idem | Mobile usa $transaction para atomicidad del upsert |
| Food log DELETE | `/api/athlete/nutrition/log/[id]` | `/api/mobile/nutrition/log/[id]` | Mobile: rate limit 60/min, feature gate |
| Foods GET | `/api/athlete/nutrition/foods` | `/api/mobile/nutrition/foods` | Logica identica. Web: sin rate limit. |
| Foods POST (crear) | `/api/athlete/nutrition/foods` | NO EXISTE | Solo web puede crear alimentos directamente |
| Barcode lookup | NO EXISTE | `/api/mobile/nutrition/foods/barcode` | Solo mobile |
| Water GET | `/api/athlete/nutrition/water` | `/api/mobile/nutrition/water` | Mobile: `?tz=` en query param; web consulta DB |
| Water POST | idem | idem | Mobile: fallback timezone desde DB si no hay `?tz=` |
| Food proposals | `/api/athlete/nutrition/foods/propose` | `/api/mobile/nutrition/foods/propose` | Identico. Rate limit 10/hora. |
| My proposals | `/api/athlete/nutrition/foods/my-proposals` | `/api/mobile/nutrition/foods/my-proposals` | Web: sin rate limit. Mobile: 120/min |

---

## Tests requeridos

### Food Log
- [ ] POST log: upsert suma gramos correctamente (mismo food+date+mealType)
- [ ] POST log: crea nuevo registro si es food diferente
- [ ] POST log: `mealType` invalido retorna 400
- [ ] POST log: `grams > 5000` retorna 400
- [ ] POST log: `grams <= 0` retorna 400
- [ ] DELETE log: retorna 403 si el log no pertenece al usuario
- [ ] GET log: macros calculados desde snapshot si `kcalLogged` existe
- [ ] GET log: macros recalculados desde food si `kcalLogged` es null
- [ ] GET log: dayType correcto segun intensidad de la sesion

### Water
- [ ] POST water: delta positivo suma correctamente
- [ ] POST water: delta negativo no puede dejar mlLogged < 0
- [ ] POST water: `delta = 0` retorna 400
- [ ] GET water: default waterMlTarget 2000 si no hay NutritionPlan

### Foods
- [ ] GET foods: ordenacion correcta (favorito > mismo pais > global > resto)
- [ ] GET foods: usuario sin timezone → country default 'CO'
- [ ] GET foods: resultado truncado a 50 aunque hay mas
- [ ] GET foods barcode: alimento existente en DB → retorna sin consultar OFF
- [ ] GET foods barcode: no encontrado → retorna needsConfirmation
- [ ] GET foods barcode: formato invalido → 400

### countryFromTimezone
- [ ] Timezone valido retorna codigo correcto
- [ ] Timezone null retorna 'CO'
- [ ] Timezone desconocido retorna 'CO'

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-10-05 | Fix: feature gate `nutrition` en log/summary y foods mobile (antes decia "ninguna") |
| 2026-10-02 | Split desde nutrition.spec.md — solo tracking (Groups 1-3) |
| 2026-09-29 | Spec original creada |
| 2026-10-09 | Auditoria pre-prod: water POST ::date cast, log/summary week boundaries con getWeekMonday timezone-aware, FoodSearchModal res.ok check |
