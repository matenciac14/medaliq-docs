# ONBOARDING — Configuracion inicial del atleta

<!-- mirror: true -->
<!-- mirror-endpoints: POST /api/athlete/onboarding/generate ↔ POST /api/mobile/onboarding/generate -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Domain doc: `../domains/atleta.md`
> Archivos fuente:
> - `src/app/api/athlete/onboarding/generate/route.ts`
> - `src/app/api/athlete/onboarding/prefilled/route.ts`
> - `src/app/api/mobile/onboarding/generate/route.ts`
> - `src/app/onboarding/page.tsx` + `src/app/onboarding/_types.ts`
> - `src/domain/onboarding/complete_onboarding.use_case.ts`
> - `src/domain/onboarding/onboarding.types.ts`
> - `src/domain/plan/formulas.ts`
> - `src/infrastructure/db/user.repository.ts` + `health_profile.repository.ts`
> - `src/middleware.ts`

## TL;DR
- 3 endpoints (2 web, 1 mobile)
- Modelos: User, HealthProfile, NutritionPlan, UserSubscription
- Dependencias: completeOnboarding use case, calculateTDEE(), calculateMacros(), onboarding.schema.ts (Zod)
- Trampas criticas: B2B invitado salta a /pending (no onboarding normal), middleware redirect loop si onboarding incompleto, onboarding.schema valida por deporte
- Mirror mobile: generate (use case compartido, schema mobile tiene campos extra)

---

## Contratos de la AI

- [ ] El onboarding NO genera un TrainingPlan. Solo guarda perfil, crea NutritionPlan y WeeklyRoutine. Planes estructurados los asigna el coach (B2B)
- [ ] B2C y B2B usan el mismo use case (`completeOnboardingUseCase`) pero con resultados distintos: B2C activa features, B2B no activa ninguna — el coach las activa despues
- [ ] La deteccion de B2B ocurre dentro del use case via `coachAthlete.findFirst` — el cliente nunca declara si es B2B
- [ ] Mobile manda formato legacy (`mainGoal`, `sport`, `raceDistance`, `hoursPerSession`). El adaptador `mapMobilePayload` convierte a `WizardData`. Si el payload ya trae `activityType` (formato web), se pasa directo sin mapear
- [ ] El campo `activityType: 'FREE'` no tiene UI en el wizard web (solo RUNNING y GYM son seleccionables), pero existe en el tipo y el sistema lo maneja. Mobile puede generar FREE via el adaptador cuando `mainGoal` no mapea a nada conocido
- [ ] `activityType: 'BOTH'` no tiene UI en el wizard web — solo llega por mobile o programaticamente
- [ ] Mobile recibe un token JWT refrescado en la respuesta de onboarding (con `onboardingCompleted: true`). Web hace `refreshSession()` via next-auth. Sin esto, el middleware sigue redirigiendo a /onboarding
- [ ] `gender: 'other'` es valido en UI web pero se trata como 'male' en `calculateTDEE` (fallback: `gender === 'female' ? 'female' : 'male'`). No afecta la UI pero si el calculo de BMR
- [ ] El deficit calorico en onboarding es fijo: -500 kcal si `weightGoalKg` existe o `gymGoal` es FAT_LOSS/RECOMPOSITION. Sin opcion granular (esa la tiene el coach en check-in)
- [ ] `daysPerWeek` se guarda en `WeeklyRoutine`, no en `HealthProfile`. `sessionMinutes` se guarda en `HealthProfile`
- [ ] El wizard web tiene validacion de rango en el cliente: edad 10-100, altura 100-250 cm, peso 30-300 kg. El backend solo valida que los tres campos existan (no null/falsy) — rango no se re-valida en backend
- [ ] `injuries` y `conditions` llegan como string (texto libre) desde web. Desde mobile llegan como array de strings. `parseListField` unifica ambos en `string[]` para guardarlo en DB
- [ ] El endpoint prefilled (`GET /api/athlete/onboarding/prefilled`) solo retorna datos si existe un `HealthProfile`. Solo se llama si `isB2B === true`. Permite al atleta confirmar datos pre-cargados por el coach

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| POST | `/api/athlete/onboarding/generate` | `auth()` | 3/min por IP | Web: recibe WizardData, completa onboarding |
| GET | `/api/athlete/onboarding/prefilled` | `auth()` | Ninguno | Web: retorna HealthProfile pre-cargado (B2B) |
| POST | `/api/mobile/onboarding/generate` | `getMobileUser()` | 3/min por IP | Mobile: mismo use case, payload legacy, retorna token refrescado |

---

### POST /api/athlete/onboarding/generate

**Request body** (`WizardData`):
```ts
{
  activityType:    'GYM' | 'RUNNING' | 'BOTH' | 'FREE' | null
  gymGoal:         'MUSCLE_GAIN' | 'FAT_LOSS' | 'RECOMPOSITION' | null
  runningGoal:     'GENERAL_FITNESS' | 'RACE_5K' | 'RACE_10K' | null
  age:             number | null   // obligatorio — falla 400 si null
  heightCm:        number | null   // obligatorio — falla 400 si null
  weightKg:        number | null   // obligatorio — falla 400 si null
  gender:          'male' | 'female' | 'other' | null
  weightGoalKg:    number | null   // opcional
  daysPerWeek:     number          // default 4
  sessionMinutes:  number          // default 60, opciones: 30|45|60|90
  experienceLevel: 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED' | null  // opcional
  injuries:        string          // texto libre, puede ser ''
  conditions:      string          // texto libre, puede ser ''
}
```

**Response (200):**
```ts
{
  success: true
  isB2B:   boolean
  planId:  null  // siempre null — no se genera TrainingPlan en onboarding
}
```

**Logica:**
1. Rate limit 3/min por IP
2. Parsear body como `WizardData`
3. Validar presencia de `age`, `weightKg`, `heightCm` — si alguno es falsy → 400
4. `auth()` → userId
5. `completeOnboardingUseCase(data, userId, deps)` — ver seccion use case
6. Si `result.isB2B`: notificacion push + email al coach (fire-and-forget, errores ignorados)
7. Retornar `{ success: true, isB2B, planId: null }`

**Side effects B2B (fire-and-forget):**
- Push notification al coach: `"${athleteName} completó su perfil"` — `sendPushNotification`
- Email al coach: `sendAthleteReadyEmail(coach.email, coach.name, athleteName, athleteId)`

---

### GET /api/athlete/onboarding/prefilled

**Response (200):**
```ts
{ prefilled: null }
// o
{
  prefilled: {
    age:             number
    heightCm:        number
    weightKg:        number
    gender:          string | null
    dateOfBirth:     DateTime | null
    experienceLevel: string | null
  }
}
```

**Logica:**
1. `auth()` → userId
2. `healthProfile.findUnique({ where: { userId } })` — campos seleccionados arriba
3. Si no existe → `{ prefilled: null }`
4. Si existe → `{ prefilled: profile }`

**Uso en UI:** Solo se llama si `session.user.isB2B === true`. Si `dateOfBirth` existe, la UI calcula `age` desde ahi en lugar de usar el campo `age` directo.

---

### POST /api/mobile/onboarding/generate

**Request body** — dos formatos aceptados:

**Formato legacy (mobile nativo):**
```ts
{
  mainGoal?:        'SPORT' | 'GYM' | 'BODY' | string | null
  sport?:           'RUNNING' | 'STRENGTH' | string | null
  raceDistance?:    'RACE_5K' | 'RACE_10K' | 'RACE_HALF_MARATHON' | 'RACE_MARATHON' | null
  hrMax?:           number
  hrSource?:        string
  gender?:          string
  age?:             number
  weightKg?:        number
  heightCm?:        number
  daysPerWeek?:     number
  hoursPerSession?: number   // se convierte a sessionMinutes = round(horas * 60)
  injuries?:        string[] // 'Ninguna' se filtra antes de join
  conditions?:      string[] // 'Ninguna' se filtra antes de join
  experienceLevel?: string | null
}
```

**Formato web (forward-compatible):** Si el payload incluye `activityType`, se trata como `WizardData` directamente y se omite el mapeo.

**Response (200):**
```ts
{
  success: true
  isB2B:   boolean
  planId:  null
  token:   string   // JWT mobile refrescado con onboardingCompleted: true
}
```

**Logica:**
1. `getMobileUser(req)` — 401 si no autenticado
2. Rate limit 3/min por IP
3. Parsear body como `MobilePayload`
4. `mapMobilePayload(raw)` → `WizardData`
5. Validar presencia de `age`, `weightKg`, `heightCm`
6. `completeOnboardingUseCase(data, mobile.id, deps)` — mismo use case que web
7. Side effects B2B identicos al endpoint web
8. Fetch usuario actualizado de DB con `MOBILE_USER_SELECT`
9. `buildMobileTokenPayload(updatedUser, { isB2B })` → `signMobileToken(payload)` → `token`
10. Retornar `{ success: true, isB2B, planId: null, token }`

---

## Use Case: completeOnboardingUseCase

**Archivo:** `src/domain/onboarding/complete_onboarding.use_case.ts`

**Flujo completo:**

```
1. checkIsB2B(db, userId)
   → coachAthlete.findFirst({ where: { athleteId: userId } })

2. calculateTDEE(weightKg, heightCm, age, gender, daysPerWeek)
   → Mifflin-St Jeor BMR × factor de actividad (por volumen semanal)

3. hasDeficit = weightGoalKg existe || gymGoal === FAT_LOSS || gymGoal === RECOMPOSITION
   kcalAdjustment = hasDeficit ? -500 : 0

4. calculateMacros(tdee, weightKg, kcalAdjustment)
   → { hard, easy, rest } con proteina 2g/kg, carbos periodizados, grasa restante

5. activityToSport(activityType) → sportType
6. activityToSportGoal(activityType, gymGoal, runningGoal) → sportGoal

7. $transaction:
   a. planRepo.upsertNutrition(userId, nutritionTargets)
      → NutritionPlan upsert con TDEE + macros
   b. healthProfileRepo.upsertProfile(userId, { ...datosDelPerfil })
      → HealthProfile upsert con sport=sportType, sportGoal via completeOnboarding
   c. Si B2B:
      userRepo.completeOnboarding(userId, {
        onboarding: { completed: true, completedAt: now() },
        sport: { type: sportType, goal: sportGoal },
        // sin features — el coach las activa
      })
   d. Si B2C:
      userRepo.completeOnboarding(userId, {
        features: { plan: true, nutrition: true, progress: true, log: true, checkin: true, gym: true },
        onboarding: { completed: true, completedAt: now() },
        sport: { type: sportType, goal: sportGoal },
      })
      tx.weeklyRoutine.upsert({ where: { userId }, create/update: { daysPerWeek } })

8. return { isB2B, planId: null }
```

**Mapeo activityType → sportType:**
| activityType | sportType en DB |
|---|---|
| `GYM` | `STRENGTH` |
| `RUNNING` | `RUNNING` |
| `BOTH` | `RUNNING` (running es deporte primario) |
| `FREE` / null | `GENERAL` |

**Mapeo activityType + goal → sportGoal:**
| activityType | gymGoal | runningGoal | sportGoal en DB |
|---|---|---|---|
| `GYM` o `BOTH` | `MUSCLE_GAIN` | — | `STRENGTH_TRAINING` |
| `GYM` o `BOTH` | `FAT_LOSS` o `RECOMPOSITION` | — | `BODY_RECOMPOSITION` |
| `RUNNING` | — | `RACE_5K` | `RACE_5K` |
| `RUNNING` | — | `RACE_10K` | `RACE_10K` |
| cualquier otro | — | — | `GENERAL_FITNESS` |

---

## Adaptador mobile → WizardData

**Archivo:** `src/app/api/mobile/onboarding/generate/route.ts` — funcion `mapMobilePayload`

**Tabla de mapeo:**
| Campo mobile legacy | Campo WizardData | Logica |
|---|---|---|
| `activityType` (si existe) | pass-through | Formato web — sin mapeo |
| `mainGoal='SPORT'` + `sport='RUNNING'` | `activityType: 'RUNNING'` | — |
| `mainGoal='SPORT'` + `sport='STRENGTH'` | `activityType: 'GYM'` | — |
| `mainGoal='GYM'` | `activityType: 'GYM'`, `gymGoal: 'MUSCLE_GAIN'` | — |
| `mainGoal='BODY'` | `activityType: 'GYM'`, `gymGoal: 'RECOMPOSITION'` | — |
| cualquier otro | `activityType: 'FREE'` | Fallback |
| `raceDistance='RACE_5K'` | `runningGoal: 'RACE_5K'` | — |
| `raceDistance='RACE_10K'` | `runningGoal: 'RACE_10K'` | — |
| `raceDistance='RACE_HALF_MARATHON'` | `runningGoal: 'GENERAL_FITNESS'` | Distancias >10K no estan en UI |
| `raceDistance='RACE_MARATHON'` | `runningGoal: 'GENERAL_FITNESS'` | Idem |
| `raceDistance` null/otro | `runningGoal: 'GENERAL_FITNESS'` | Default |
| `hoursPerSession` | `sessionMinutes = round(horas * 60)` | — |
| `injuries: ['Ninguna', ...]` | `injuries: ''` (filtrado) | 'Ninguna' se elimina antes de join |
| `weightGoalKg` | siempre `null` | No expuesto en mobile legacy |

---

## Wizard web — Pasos y validacion

**Archivo:** `src/app/onboarding/_types.ts`, `src/app/onboarding/page.tsx`

### Pasos del wizard
```
goal → profile → generating
```

`generating` es un step de UI (spinner) — no es un paso interactivo. El wizard tiene 2 pasos reales.

**`getSteps(data)` — logica de avance:**
1. Siempre empieza en `['goal']`
2. Agrega `profile` solo si:
   - `activityType` no es null
   - Si `GYM` o `BOTH`: `gymGoal` no es null
   - Si `RUNNING` o `BOTH`: `runningGoal` no es null
3. Agrega `generating` solo si ademas: `age`, `heightCm`, `weightKg`, `gender` son no-null

**`isStepValid(stepId, data)` — habilitacion del boton Siguiente:**
- `goal`: activityType + sub-goal segun disciplina
- `profile`: los 4 campos obligatorios + rangos validos (10-100, 100-250, 30-300)
- `generating`: siempre true

### Campos del wizard
**Paso 1 — Objetivo:**
- `activityType`: RUNNING o GYM (BOTH y FREE no tienen UI)
- `runningGoal` (si RUNNING): GENERAL_FITNESS, RACE_5K, RACE_10K
- `gymGoal` (si GYM): MUSCLE_GAIN, FAT_LOSS, RECOMPOSITION

**Paso 2 — Perfil:**
- Obligatorios: edad, altura, peso, genero
- Opcionales: weightGoalKg (solo si GYM/BOTH/FREE/FAT_LOSS/RECOMPOSITION)
- Disponibilidad: daysPerWeek (3/4/5/6), sessionMinutes (30/45/60/90)
- Opcionales: experienceLevel, injuries, conditions

### Prefilled (B2B)
Si `session.user.isB2B === true`, el wizard llama a `/api/athlete/onboarding/prefilled` al montar y pre-carga los campos del paso 2. Si `dateOfBirth` existe, calcula `age` desde ahi. Muestra banner informativo al usuario.

---

## Post-onboarding — Estado del sistema

### B2C (sin coach)
Tras `completeOnboardingUseCase`:
- `User.onboardingCompleted = true`
- `User.onboardingCompletedAt = now()`
- `User.featurePlan = true`
- `User.featureCheckin = true`
- `User.featureNutrition = true`
- `User.featureProgress = true`
- `User.featureLog = true`
- `User.featureGym = true`
- `NutritionPlan` creado/actualizado (source=SYSTEM por defecto)
- `HealthProfile` creado/actualizado
- `WeeklyRoutine` creado/actualizado con `daysPerWeek`
- `HealthProfile.sport` y `HealthProfile.sportGoal` actualizados

Redireccion web: `/dashboard`

### B2B (con coach)
Tras `completeOnboardingUseCase`:
- `User.onboardingCompleted = true`
- `User.onboardingCompletedAt = now()`
- Features: sin cambios (todas en false/default — coach las activa)
- `NutritionPlan` creado/actualizado
- `HealthProfile` creado/actualizado
- `WeeklyRoutine`: NO se crea
- Coach recibe push notification + email (fire-and-forget)

Redireccion web: `/pending`

**`/pending`:** UI de espera con stepper de progreso. `PendingPoller` hace polling periodico; cuando el coach activa al atleta (`featurePlan=true`), redirige automaticamente a `/dashboard`.

---

## Modelos DB involucrados

```prisma
model User {
  onboardingCompleted   Boolean   @default(false)
  onboardingCompletedAt DateTime?
  featurePlan           Boolean   @default(false)
  featureCheckin        Boolean   @default(false)
  featureNutrition      Boolean   @default(false)
  featureProgress       Boolean   @default(false)
  featureLog            Boolean   @default(false)
  featureGym            Boolean   @default(true)
}

model HealthProfile {
  userId          String   @unique
  age             Int
  heightCm        Float
  weightKg        Float
  weightGoalKg    Float?
  gender          String?  // male | female
  sport           String?  // RUNNING | STRENGTH | GENERAL
  sportGoal       String?  // RACE_5K | RACE_10K | STRENGTH_TRAINING | BODY_RECOMPOSITION | GENERAL_FITNESS
  experienceLevel String?  // BEGINNER | INTERMEDIATE | ADVANCED
  sessionMinutes  Int?
  injuries        String[]
  conditions      String[]
  sportDetails    Json     @default("{}")  // { gymGoal?, runningGoal? }
  dataSources     Json     @default("{}")
}

model NutritionPlan {
  userId         String @unique
  source         NutritionSource @default(SYSTEM)
  tdee           Int
  targetKcalHard Int
  targetKcalEasy Int
  targetKcalRest Int
  proteinG       Int
  carbsHardG     Int
  carbsEasyG     Int
  fatG           Int
  kcalAdjustment Int   @default(0)  // -500 si deficit, 0 si mantenimiento
}

model WeeklyRoutine {
  userId      String @unique
  daysPerWeek Int    @default(4)
  days        Json   @default("[]")
}

model CoachAthlete {
  coachId:   String
  athleteId: String  // se consulta para detectar B2B
}
```

---

## Reglas de negocio (invariantes)

1. **Sin TrainingPlan en onboarding**: ningun path genera un `TrainingPlan` durante el onboarding. Planes estructurados son responsabilidad del coach.

2. **B2B detectado por DB, no por cliente**: `isB2B` se determina con `coachAthlete.findFirst` dentro del use case. El cliente no puede declararse B2B.

3. **Features B2B las activa el coach**: un atleta B2B que completa el onboarding queda en `/pending` indefinidamente hasta que el coach active `featurePlan`. El coach hace esto desde el panel `/coach/athletes/[id]`.

4. **Atomicidad del onboarding**: NutritionPlan + HealthProfile + User (features + onboarding flag) + WeeklyRoutine se escriben en un solo `$transaction`. Si cualquiera falla, nada persiste.

5. **Token mobile obligatorio al terminar**: el endpoint mobile siempre retorna un token JWT refrescado. Sin este paso, el cliente mobile sigue viendo `onboardingCompleted: false` hasta el proximo refresh y el middleware lo redirige a onboarding en bucle.

6. **Reentry bloqueado**: middleware redirige a `/dashboard` si `onboardingCompleted === true` y la ruta es `/onboarding`. No se puede repetir el onboarding.

7. **Coach bloqueado del wizard**: middleware redirige a `/coach/dashboard` si `role === 'COACH'` y la ruta es `/onboarding`.

8. **Rate limit identico en web y mobile**: 3 intentos por minuto por IP en ambos endpoints.

9. **Deficit calorico fijo en onboarding**: -500 kcal si hay objetivo de perdida de peso/grasa. Sin opciones granulares — esa configuracion la hace el coach post-onboarding o el atleta Pro en check-in.

10. **`gender: 'other'` usa formula de hombre**: `calculateTDEE` solo acepta `'male' | 'female'`. El fallback `gender === 'female' ? 'female' : 'male'` aplica `'male'` para `'other'` y `null`.

---

## Formulas cientificas

**TDEE — Mifflin-St Jeor:**
```
BMR (hombre) = 10×kg + 6.25×cm − 5×edad + 5
BMR (mujer)  = 10×kg + 6.25×cm − 5×edad − 161

Factor de actividad (por volumen semanal = daysPerWeek × sessionMinutes):
  < 120 min/sem  → 1.375
  120-300        → 1.55
  300-600        → 1.725
  > 600          → 1.9

Sin sessionMinutes (compat): 3d=1.375 | 4d=1.55 | 5d=1.725 | ≥6d=1.9
```

**Macros periodizados:**
```
Proteina: 2g/kg (fija, todos los dias)
Carbos: 50% kcal (dia duro) | 35% (facil) | 25% (descanso)
Grasa: resto de kcal, minimo 0.5g/kg
Minimo calorico: 1200 kcal por dia
```

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `activityType: 'FREE'` | No tiene UI — parece que no existe | Existe en el tipo y el use case lo maneja. Mobile puede generarlo via el adaptador. `activityToSport('FREE') = 'GENERAL'` |
| `activityType: 'BOTH'` | Parece accesible en UI web | No tiene SelectCard en el wizard — solo llega desde mobile o pruebas directas |
| `daysPerWeek` en HealthProfile | Parece estar en HealthProfile | Vive en `WeeklyRoutine.daysPerWeek`. HealthProfile tiene `sessionMinutes`, no `daysPerWeek` |
| `sportGoal` en User | Parece estar en User | Vive en `HealthProfile.sportGoal`. `completeOnboarding` en UserRepository hace un segundo `$executeRawUnsafe` sobre `HealthProfile` |
| `gender: 'other'` en TDEE | Parece que no afecta el calculo | Usa formula de hombre por fallback. La UI permite seleccionarlo pero la diferencia de BMR (~166 kcal) queda sesgada |
| Token mobile en onboarding | Parece que la respuesta es igual a web | Mobile retorna `{ ..., token: string }` adicional. Sin guardar ese token, el JWT mobile sigue con `onboardingCompleted: false` |
| Validacion de rangos | Parece estar en el backend | Solo esta en el cliente. El backend solo valida existencia (no null/falsy). Un valor `age: 5` pasaria la validacion del backend |
| `injuries` tipo | Parece que web y mobile mandan el mismo tipo | Web manda string (`"dolor rodilla"`), mobile manda string[] (`["dolor rodilla"]`). `parseListField` los unifica |
| `planId` en respuesta | Parece que podria ser un plan generado | Siempre `null`. El tipo `CompleteOnboardingResult.planId: string | null` es anticipacion futura — hoy siempre null |
| `RACE_HALF_MARATHON` y `RACE_MARATHON` en mobile | Parecen mapear a esos runningGoals | Mapean a `GENERAL_FITNESS`. RunningGoal solo tiene GENERAL_FITNESS, RACE_5K, RACE_10K |
| Prefilled solo para B2B | Parece disponible para todos | El endpoint existe para todos pero la UI solo lo llama si `session.user.isB2B === true` |

---

## Paridad web <-> mobile

| Aspecto | Web | Mobile |
|---|---|---|
| Endpoint | `POST /api/athlete/onboarding/generate` | `POST /api/mobile/onboarding/generate` |
| Auth | `auth()` (Auth.js session cookie) | `getMobileUser()` (Bearer JWT jose) |
| Payload | `WizardData` directamente | `MobilePayload` legacy → adaptador → `WizardData` |
| Use case | `completeOnboardingUseCase` | Identico |
| Token refresh | `refreshSession({ onboardingCompleted: true })` via next-auth | Token JWT en respuesta: `{ ..., token: string }` |
| Redireccion post-onboarding | Web hace `router.push('/dashboard')` o `router.push('/pending')` | Mobile maneja la redireccion desde el cliente con el nuevo token |
| Side effects B2B | Push + email al coach (identico) | Identico |
| Prefilled | `GET /api/athlete/onboarding/prefilled` | Sin endpoint equivalente |
| `hoursPerSession` | No existe — usa `sessionMinutes` directo | Se convierte: `sessionMinutes = round(hoursPerSession * 60)` |
| `injuries`/`conditions` | String texto libre | Array de strings — 'Ninguna' se filtra |
| `weightGoalKg` | Campo en UI (opcional) | Siempre `null` en el adaptador (no expuesto) |

---

## Tests existentes

### `src/app/onboarding/onboarding_steps.test.ts`
Cubre `getSteps` e `isStepValid` para todos los `activityType`:
- Estado inicial → solo `['goal']`
- FREE: avanza a profile con datos fisicos completos
- RUNNING: se bloquea en goal sin runningGoal
- GYM: se bloquea en goal sin gymGoal
- BOTH: requiere gymGoal + runningGoal para avanzar
- Invariantes: goal siempre primero, generating siempre ultimo, exactamente 3 pasos cuando completo

### `src/domain/onboarding/complete_onboarding.use_case.test.ts`
Cubre el use case con mocks de repos:
- B2C: retorna `{ isB2B: false, planId: null }`
- B2C: activa todas las features
- B2C: crea WeeklyRoutine con daysPerWeek correcto
- B2C: llama upsertNutrition con TDEE positivo
- B2B: retorna `{ isB2B: true, planId: null }`
- B2B: NO incluye `features` en completeOnboarding
- B2B: NO crea WeeklyRoutine
- Mapeos activityToSport: GYM→STRENGTH, RUNNING→RUNNING, BOTH→RUNNING
- Mapeos activityToSportGoal: GYM+MUSCLE_GAIN→STRENGTH_TRAINING, GYM+FAT_LOSS→BODY_RECOMPOSITION, RUNNING+RACE_5K→RACE_5K

### `src/domain/onboarding/onboarding.utils.test.ts`
Cubre `resolveSportConfig` y `timeStringToSecs` (usado en coach plan builder, no en onboarding wizard).

---

## Tests requeridos al modificar este modulo

- [ ] `getSteps` retorna secuencia correcta para cada activityType (ya existe)
- [ ] `isStepValid` bloquea avance sin campos obligatorios (ya existe)
- [ ] B2C activa todas las features post-onboarding (ya existe)
- [ ] B2B no activa features, no crea WeeklyRoutine (ya existe)
- [ ] `mapMobilePayload` convierte mainGoal+sport → activityType correcto
- [ ] `mapMobilePayload` filtra 'Ninguna' de injuries/conditions
- [ ] `mapMobilePayload` pasa directo si activityType ya presente
- [ ] `hoursPerSession: 1.5` → `sessionMinutes: 90`
- [ ] RACE_HALF_MARATHON en mobile → runningGoal: GENERAL_FITNESS
- [ ] Onboarding idempotente: segunda llamada sobrescribe pero no duplica (upsert, no create)
- [ ] `gender: 'other'` → usa BMR de hombre en TDEE
- [ ] Token mobile incluido en respuesta y contiene `onboardingCompleted: true`

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo real |
