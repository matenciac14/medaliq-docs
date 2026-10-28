# Domain: Wearables y Sincronizacion de Salud
# Leer antes de tocar cualquier integracion con wearables, sync de datos de salud, HealthKit, Health Connect, Strava o Garmin.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Strava connect/disconnect (OAuth web) |
| Mobile atleta iOS | HealthKit (workouts + pre-fill check-in) + Strava (via web) |
| Mobile atleta Android | Solo manual — Health Connect NO implementado |
| Web coach | Vista de datos sincronizados del atleta (SessionLog, DailyLog, CheckIn) |

---

## Principios

1. **El dato vive en el dispositivo, no en la plataforma externa.** HealthKit/Health Connect son la fuente primaria. Strava y Garmin son fuentes secundarias.
2. **Sync automatico, edicion manual.** Los datos se pre-llenan automaticamente pero el atleta siempre puede editar antes de enviar.
3. **Deduplicacion por externalId.** Cada actividad importada tiene un ID externo unico. Si ya existe, se ignora (upsert idempotente).
4. **Privacidad primero.** El atleta aprueba cada tipo de dato individualmente. Datos de salud no se comparten con el coach sin consentimiento explicito.
5. **Graceful degradation.** Si el permiso se niega o el wearable no esta disponible, el sistema funciona con entrada manual sin errores.

---

## Fuentes de datos

### 1. Apple HealthKit (iOS) — IMPLEMENTADO PARCIAL

Libreria: `react-native-health` (bare workflow / EAS build).

**Implementado:**
- Permisos: Workout, HeartRate, RestingHeartRate, SleepAnalysis, VO2Max (lectura)
- `syncRecent()`: importa workouts de los ultimos 7 dias → POST `/api/mobile/log/session` con `dataSource: HEALTHKIT`
- Pre-fill check-in semanal: `querySleepHours()` + `queryRestingHeartRate()` → campos editables con badge "Apple Health"
- Auto-trigger: `syncRecent()` se ejecuta al abrir la app (`_layout.tsx`)
- UI: toggle en `/integrations` (solo iOS)

**NO implementado:**
- Auto-sync diario de sueno → DailyLog (solo pre-fill semanal en check-in)
- Auto-sync diario de FC reposo → DailyLog
- VO2max sync → HealthProfile.vo2maxEstimate (permiso solicitado pero no se lee)
- Escritura a `HealthProfile.dataSources` para tracking de provenance

### 2. Google Health Connect (Android) — NO IMPLEMENTADO

Equivalente a HealthKit para Android. Requiere `react-native-health-connect`. Soporta Android 9+ (API 28+).

**Debe proveer (paridad con HealthKit):**
- Workouts → SessionLog (sync automatico)
- Sueno → DailyLog.sleepHours (auto-sync diario)
- FC reposo → DailyLog.hrResting (auto-sync diario)
- Pre-fill check-in semanal (sueno + FC)

**Fuentes que alimentan Health Connect:**
Samsung Health, Google Fit, Garmin Connect, Fitbit, Xiaomi Health, Polar Flow, Whoop — cualquier app que escriba a Health Connect.

### 3. Strava — IMPLEMENTADO COMPLETO

Backend webhook-driven. OAuth desde web, actividades llegan por webhook push.

**Implementado:**
- OAuth web: connect → callback → WearableConnection
- Webhook: recibe nuevas actividades → refresh token → fetch activity → mapper → createWearableSession
- Deduplicacion por externalId (activity ID de Strava)
- Disconnect con deauthorize API
- Mapeo: Run/Ride/Swim/Strength → WearableDiscipline

**Limitaciones de Strava (API):**
- NO provee: sueno, FC reposo, VO2max, HRV, calorias en reposo
- Solo actividades deportivas — no datos de salud pasivos

### 4. Garmin Connect API — NO IMPLEMENTADO (P2)

La fuente mas rica de datos para runners serios. Requiere partnership con Garmin Health API.

**Datos exclusivos que Garmin provee (y ningun otro):**
- Training Status (productivo/mantenimiento/sobrecarga)
- Body Battery (indice de energia)
- Training Load (carga semanal)
- HRV score diario
- Estres (desde FC en reposo)

**Datos compartidos con HealthKit:**
- Workouts, sueno (fases + puntuacion), FC reposo, VO2max

---

## Flujos de datos

### Flujo A: HealthKit/Health Connect → Medaliq (client-pull)

```
Wearable (Apple Watch, Garmin, Fitbit, etc.)
  → OS Health Store (HealthKit / Health Connect)
    → App Medaliq (al abrir)
      → syncRecent(): workouts → POST /api/mobile/log/session
      → syncDailyHealth(): sueno + FC → POST /api/mobile/metrics/log
      → pre-fill check-in: sueno + FC → formulario editable
```

**Trigger:** cada vez que el atleta abre la app.
**Deduplicacion:** por `externalId` en SessionLog, por `userId+date` en DailyLog (upsert).

### Flujo B: Strava → Medaliq (server-push)

```
Atleta completa actividad
  → Garmin/reloj sync a Strava
    → Strava webhook POST /api/webhooks/strava
      → refreshStravaTokenIfNeeded()
      → fetchStravaActivity()
      → stravaActivityToSessionLog()
      → createWearableSession()
```

**Trigger:** webhook automatico de Strava (~1-5 min post-actividad).
**Deduplicacion:** por `externalId` (Strava activity ID).

### Flujo C: Garmin API → Medaliq (server-push) — FUTURO

```
Atleta completa actividad / duerme / mide HRV
  → Garmin Connect cloud
    → Garmin webhook POST /api/webhooks/garmin
      → Actividades → createWearableSession()
      → Sueno → upsert DailyLog.sleepHours
      → HRV → upsert WeeklyCheckIn.hrvMs o HealthProfile
      → VO2max → upsert HealthProfile.vo2maxEstimate
```

---

## Modelos de datos involucrados

### WearableConnection
Almacena credenciales OAuth por proveedor. `@@unique([userId, provider])`.

| Campo | Tipo | Uso |
|-------|------|-----|
| provider | String | "strava" / "garmin" / "healthkit" |
| accessToken | String | OAuth token (Strava/Garmin) o flag (HealthKit) |
| refreshToken | String? | Solo OAuth providers |
| expiresAt | DateTime? | TTL del token |
| providerAccountId | String? | Mapeo webhook → userId |

### SessionLog (campos wearable)
| Campo | Tipo | Uso |
|-------|------|-----|
| dataSource | String? | MANUAL / STRAVA / GARMIN / HEALTHKIT |
| externalId | String? | ID de la actividad en el sistema externo |
| hrAvg, hrMax | Int? | FC promedio y maxima de la sesion |
| caloriesBurned | Int? | Calorias estimadas |
| avgPaceSecPerKm | Int? | Pace promedio (running) |

### DailyLog (targets de auto-sync)
| Campo | Tipo | Fuente auto-sync |
|-------|------|-----------------|
| sleepHours | Float? | HealthKit / Health Connect / Garmin |
| hrResting | Int? | HealthKit / Health Connect / Garmin |
| weightKg | Float? | Manual (wearables no proveen peso confiable) |

### HealthProfile (targets de auto-sync)
| Campo | Tipo | Fuente auto-sync |
|-------|------|-----------------|
| vo2maxEstimate | Float? | HealthKit (Apple Watch) / Garmin |
| dataSources | Json | Tracking de provenance por campo |

### WeeklyCheckIn (pre-fill targets)
| Campo | Tipo | Fuente pre-fill |
|-------|------|----------------|
| sleepHours | Float? | HealthKit / Health Connect |
| hrResting | Int? | HealthKit / Health Connect |
| hrvMs | Float? | HealthKit (Apple Watch) / Garmin |

---

## Arquitectura de codigo

```
src/
  domain/wearables/
    create_wearable_session.use_case.ts    <- upsert idempotente de actividad
    sync_daily_health.use_case.ts          <- PENDIENTE: sync sueno+FC a DailyLog
    wearable.types.ts                      <- WearableDataSource, WearableDiscipline
  domain/ports/
    wearable.repository.ts                 <- IWearableRepository
    session_log.repository.ts              <- ISessionLogRepository
  infrastructure/wearable/
    strava.service.ts                      <- refresh token + fetch activity
    strava.mapper.ts                       <- StravaActivity → CreateWearableSessionInput
    garmin.service.ts                      <- PENDIENTE
    garmin.mapper.ts                       <- PENDIENTE
  infrastructure/db/
    wearable.repository.ts                 <- PrismaWearableRepository
```

Mobile:
```
MEDALIQ-MOBILE/src/
  services/
    healthkit.service.ts                   <- syncRecent, querySleep, queryHR
    healthconnect.service.ts               <- PENDIENTE: equivalente Android
  hooks/
    useHealthKit.ts                        <- permisos + estado
    useHealthConnect.ts                    <- PENDIENTE: equivalente Android
```

---

## Reglas de negocio

1. **Un usuario puede tener multiples wearables conectados.** Strava + HealthKit simultaneo es comun.
2. **Conflicto de fuentes:** si la misma actividad llega por Strava Y HealthKit, el `externalId` diferente crea dos SessionLogs. El flujo acepta duplicados de diferentes fuentes — el atleta puede borrar uno manualmente.
3. **Auto-sync diario no sobreescribe entrada manual.** Si el atleta ya registro sleepHours hoy manualmente, el auto-sync no lo pisa.
4. **HealthKit/Health Connect son read-only.** Medaliq nunca escribe datos al OS health store.
5. **Garmin/Strava requieren internet.** HealthKit/Health Connect funcionan offline (datos locales del dispositivo).
6. **Desconectar un wearable no borra los datos historicos.** Los SessionLogs importados persisten.

---

## Lo que NO se hace

- No se almacena el track GPS completo (privacy + storage)
- No se usa HRV o Body Battery para diagnosticar condiciones medicas
- No se comparten datos de wearables con el coach sin consentimiento del atleta
- No se muestran datos de wearables como "verdad absoluta" — son estimaciones del dispositivo
- No se implementa sync bidireccional (Medaliq no escribe a HealthKit/Garmin/Strava)
