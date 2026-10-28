# Spec: Wearables y Sincronizacion de Salud
# Domain doc: ../domains/wearables.md
# Leer _traps.spec.md SIEMPRE antes de modificar codigo.

## TL;DR
- 4 integraciones: HealthKit (iOS, parcial), Health Connect (Android, pendiente), Strava (completo), Garmin (pendiente)
- 2 patrones de sync: client-pull (HealthKit/HC desde mobile) y server-push (Strava/Garmin via webhook)
- Deduplicacion por externalId en SessionLog, upsert por userId+date en DailyLog
- 18 endpoints (4 web Strava + 2 admin + 2 webhook + 1 mobile log + 9 pendientes)

---

## Endpoints implementados

### Web — Strava OAuth

| Metodo | Ruta | Auth | Rate limit | Descripcion |
|--------|------|------|-----------|-------------|
| GET | `/api/athlete/integrations/strava/connect` | session | 10/min | Redirect a Strava OAuth |
| GET | `/api/athlete/integrations/strava/callback` | session | 10/min | Exchange code → upsert WearableConnection |
| DELETE | `/api/athlete/integrations/strava` | session | 10/min | Deauthorize + delete connection |

### Web — Admin Strava

| Metodo | Ruta | Auth | Rate limit | Descripcion |
|--------|------|------|-----------|-------------|
| POST | `/api/admin/integrations/strava/subscribe` | ADMIN | 3/min | Registra webhook en Strava (one-time) |
| GET | `/api/admin/integrations/strava/subscribe` | ADMIN | 3/min | Verifica estado de la suscripcion |

### Webhooks

| Metodo | Ruta | Auth | Descripcion |
|--------|------|------|-------------|
| GET | `/api/webhooks/strava` | verify_token | Challenge de suscripcion |
| POST | `/api/webhooks/strava` | ninguna (Strava no firma POSTs) | Recibe actividades nuevas |

### Mobile — Log con soporte wearable

| Metodo | Ruta | Auth | Rate limit | Descripcion |
|--------|------|------|-----------|-------------|
| POST | `/api/mobile/log/session` | JWT mobile | existente | Acepta dataSource + externalId para wearable logs |

---

## Endpoints pendientes

### Health Connect + Auto-sync diario

| Metodo | Ruta | Auth | Rate limit | Descripcion | Prioridad |
|--------|------|------|-----------|-------------|-----------|
| POST | `/api/mobile/health/sync-daily` | JWT mobile | 30/min | Recibe sleepHours + hrResting del OS → upsert DailyLog | P1 |
| GET | `/api/mobile/health/status` | JWT mobile | 300/min | Estado de conexiones del atleta (providers conectados, ultimo sync) | P1 |
| POST | `/api/mobile/health/connect` | JWT mobile | 10/min | Registra WearableConnection para HealthKit/HC (flag, no OAuth) | P2 |
| DELETE | `/api/mobile/health/disconnect` | JWT mobile | 10/min | Elimina WearableConnection | P2 |

### Garmin (P2 — requiere partnership)

| Metodo | Ruta | Auth | Rate limit | Descripcion | Prioridad |
|--------|------|------|-----------|-------------|-----------|
| GET | `/api/athlete/integrations/garmin/connect` | session | 10/min | Redirect a Garmin OAuth | P2 |
| GET | `/api/athlete/integrations/garmin/callback` | session | 10/min | Exchange code → upsert WearableConnection | P2 |
| DELETE | `/api/athlete/integrations/garmin` | session | 10/min | Deauthorize + delete | P2 |
| POST | `/api/webhooks/garmin` | signature | — | Recibe actividades + dailies + sleep | P2 |
| POST | `/api/admin/integrations/garmin/subscribe` | ADMIN | 3/min | Registra webhook en Garmin | P2 |

---

## Use cases

### Implementados

**`createWearableSession(input)`**
- Input: `userId, dataSource, externalId, discipline, durationMin, distanceKm?, hrAvg?, hrMax?, caloriesBurned?, avgPaceSecPerKm?, completedAt`
- Logica: `findByExternalId(userId, externalId)` → si existe, retorna `{ id, created: false }` → si no, `createFromWearable(input)` → `{ id, created: true }`
- Deduplicacion: upsert idempotente por `(userId, externalId)`

### Pendientes

**`syncDailyHealth(input)` — P1**
- Input: `userId, date, sleepHours?, hrResting?, source: WearableDataSource`
- Logica:
  1. Buscar DailyLog existente para `(userId, date)`
  2. Si ya existe Y los campos fueron ingresados manualmente (source: MANUAL) → NO sobreescribir
  3. Si no existe o campos estan vacios → upsert con datos del wearable
  4. Actualizar `HealthProfile.dataSources` JSON con provenance
- Deduplicacion: upsert por `(userId, date)` — DailyLog ya tiene `@@unique([userId, date])`

**`syncVO2max(input)` — P3**
- Input: `userId, vo2max: number, source: WearableDataSource`
- Logica: actualizar `HealthProfile.vo2maxEstimate` si el valor es diferente al actual

---

## Mobile — Servicios de plataforma

### healthkit.service.ts (iOS) — IMPLEMENTADO

```typescript
// Funciones existentes:
isSyncEnabled(): boolean           // AsyncStorage flag
setSyncEnabled(v: boolean): void
syncRecent(): Promise<void>        // Workouts ultimos 7 dias → POST /api/mobile/log/session
queryRestingHeartRate(): Promise<number | null>  // Ultimos 7 dias, limit 1
querySleepHours(): Promise<number | null>        // Ayer 18:00 → ahora, suma fases reales

// Funciones pendientes:
syncDailyHealth(): Promise<void>   // Sleep + HR → POST /api/mobile/health/sync-daily
queryVO2Max(): Promise<number | null>  // HKQuantityTypeIdentifierVO2Max
```

### healthconnect.service.ts (Android) — PENDIENTE

```typescript
// Interfaz identica a healthkit.service.ts para paridad:
isSyncEnabled(): boolean
setSyncEnabled(v: boolean): void
syncRecent(): Promise<void>        // Workouts → POST /api/mobile/log/session
queryRestingHeartRate(): Promise<number | null>
querySleepHours(): Promise<number | null>
syncDailyHealth(): Promise<void>   // Sleep + HR → POST /api/mobile/health/sync-daily
```

Libreria: `react-native-health-connect`
Permisos: `ExerciseSession`, `SleepSession`, `HeartRate`, `RestingHeartRate`
Minimo: Android 9 (API 28) con Health Connect app instalada

### Hook unificado — PENDIENTE

```typescript
// useHealthSync() — reemplaza useHealthKit() con soporte multiplataforma
export function useHealthSync() {
  // Platform.OS === 'ios' → healthkit.service
  // Platform.OS === 'android' → healthconnect.service
  // Interfaz identica para ambos
  return { authorized, loading, error, requestPermissions, syncNow }
}
```

---

## Contratos de datos

### POST /api/mobile/health/sync-daily (PENDIENTE)

Request:
```json
{
  "date": "2026-10-08",
  "sleepHours": 7.5,
  "hrResting": 58,
  "source": "HEALTHKIT"
}
```

Response 200:
```json
{
  "ok": true,
  "synced": { "sleepHours": true, "hrResting": true },
  "skipped": {}
}
```

Response 200 (campo ya existe manual):
```json
{
  "ok": true,
  "synced": { "hrResting": true },
  "skipped": { "sleepHours": "manual_entry_exists" }
}
```

### GET /api/mobile/health/status (PENDIENTE)

Response 200:
```json
{
  "providers": [
    { "provider": "healthkit", "connectedAt": "2026-09-15T...", "lastSyncAt": "2026-10-08T..." },
    { "provider": "strava", "connectedAt": "2026-08-01T...", "lastSyncAt": "2026-10-07T..." }
  ],
  "syncEnabled": true
}
```

---

## Flujo de auto-sync diario (PENDIENTE — P1)

```
1. Atleta abre la app
2. _layout.tsx: useEffect → syncRecent() (workouts, ya existe)
3. _layout.tsx: useEffect → syncDailyHealth() (NUEVO)
   a. querySleepHours() → horas de sueno de anoche
   b. queryRestingHeartRate() → FC reposo reciente
   c. POST /api/mobile/health/sync-daily { date: hoy, sleepHours, hrResting, source }
   d. Backend: upsert DailyLog — no sobreescribe entradas manuales
4. Si es dia de check-in: pre-fill formulario (ya existe)
```

---

## Prioridades de implementacion

### Sprint 1 — Auto-sync diario + Health Connect (P1)

**Backend (web):**
1. Crear `syncDailyHealth` use case en `domain/wearables/`
2. Crear `POST /api/mobile/health/sync-daily` endpoint
3. Crear `GET /api/mobile/health/status` endpoint

**Mobile — iOS:**
4. Agregar `syncDailyHealth()` a `healthkit.service.ts`
5. Llamar desde `_layout.tsx` junto a `syncRecent()`

**Mobile — Android:**
6. Instalar `react-native-health-connect`
7. Crear `healthconnect.service.ts` (paridad con healthkit.service)
8. Crear `useHealthConnect.ts` hook
9. Unificar: `useHealthSync()` hook multiplataforma
10. Actualizar `integrations.tsx` — toggle para Android

### Sprint 2 — VO2max + provenance (P2-P3)

11. `queryVO2Max()` en healthkit.service
12. `syncVO2max` use case + endpoint
13. Escritura a `HealthProfile.dataSources` JSON

### Sprint 3 — Garmin directo (P2, requiere partnership)

14. Garmin OAuth flow (connect/callback/disconnect)
15. Garmin webhook handler
16. Garmin mapper (activities + sleep + HRV + VO2max + Training Status)
17. Admin endpoint para registrar webhook

---

## Testing

### Tests existentes
- `create_wearable_session.use_case.test.ts` — 4 tests (idempotencia, deduplicacion)

### Tests pendientes
- `syncDailyHealth` use case — no sobreescribe manual, upsert correcto, campos parciales
- `POST /api/mobile/health/sync-daily` — auth, validacion, rate limit, respuesta
- `healthconnect.service` — mock de react-native-health-connect
- Garmin mapper — mapeo correcto de activity types, sleep phases

---

## Notas tecnicas

- **react-native-health** requiere bare workflow. El plugin debe estar en `app.json` plugins[] para EAS build.
- **react-native-health-connect** requiere Android 9+ con Health Connect app instalada. En devices sin Health Connect, degradar gracefully.
- **Strava OAuth es web-only.** En mobile, deep link a web para conectar. No hay in-app OAuth para Strava.
- **Garmin Health API requiere partnership.** Aplicar en developer.garmin.com. Tiempo de aprobacion: 2-4 semanas.
- **Conflicto de zona horaria en sueno:** HealthKit reporta sueno con timestamps UTC. `querySleepHours()` ya maneja esto filtrando desde ayer 18:00 local.
