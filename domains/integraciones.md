# Domain: Integraciones con Wearables y Plataformas Deportivas
# Leer antes de tocar cualquier integración externa, sync de datos o importación de actividades.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Parcial (Strava connect/disconnect) |
| Mobile atleta | Parcial (Strava deeplink, Apple Health toggle) |
| Web coach | N/A |

## Por qué las integraciones son críticas para running

Hoy todos los datos de sesión en Medaliq son **entrada manual post-ejercicio**:
- Distancia: el atleta escribe cuánto corrió
- Pace: calculado de distancia + tiempo (ambos manuales)
- FC media/máxima: el atleta la recuerda o la copia de su reloj
- FC en reposo: campo manual en el check-in semanal
- VO2max: **no se trackea en absoluto**

Para un atleta de gym esto es tolerable. Para un atleta de running esto es un problema real:
- Los datos son imprecisos (el atleta no recuerda bien su FC)
- Hay fricción (registrar manualmente después de una carrera)
- Métricas clave de running (VO2max, HRV, Training Status) son imposibles sin dispositivo

**La solución no es reinventar el wearable — es conectarse con los que ya existen.**

---

## Estado actual de datos fisiológicos en Medaliq

| Dato | Cómo se obtiene hoy | Precisión |
|------|---------------------|-----------|
| FC en reposo | Manual en check-in (`heartRate`) | Baja — atleta lo estima |
| FC máxima | Fórmula Fox `211 - 0.64 × edad` | Estimación — no medida real |
| Distancia (running) | Manual post-sesión | Media — depende del recuerdo |
| Pace | Calculado desde distancia + tiempo manuales | Media |
| VO2max | **No se trackea** | N/A |
| HRV (variabilidad de FC) | **No se trackea** | N/A |
| Sueño (horas) | Manual en check-in | Baja — autoría subjetiva |
| Calorías quemadas | **No se trackea** | N/A |

---

## Integraciones prioritarias — qué resuelve cada una

### 1. Apple HealthKit + Google Health Connect — **P1 post-lanzamiento**

La integración de mayor impacto con menor esfuerzo de adopción: la mayoría de atletas ya tiene un smartphone que sincroniza con su wearable (cualquier marca).

**Qué datos provee:**
- Workouts completados: tipo, duración, distancia, calorías, HR media/máxima
- FC en reposo (tendencia, no solo un punto)
- Pasos diarios
- Sueño (horas + calidad si tienen Apple Watch / Pixel Watch / Fitbit)
- VO2max (solo Apple Watch — HealthKit lo expone como `HKQuantityTypeIdentifierVO2Max`)
- HRV (solo Apple Watch — `HKQuantityTypeIdentifierHeartRateVariabilitySDNN`)

**Cómo mapea a Medaliq:**
- Workout completado → auto-completa `SessionLog` (tipo, distancia, duración, FC media/máxima)
- FC en reposo → pre-rellena `WeeklyCheckIn.heartRate` automáticamente
- Sueño → pre-rellena `WeeklyCheckIn.sleepHours`
- VO2max → nuevo campo `HealthProfile.vo2maxEstimate Float?` o `PerformanceBenchmark`

**Requisitos técnicos (pendiente investigar):**
- iOS: `expo-health` o `react-native-health` — algunos features requieren bare workflow (salir de Expo managed)
- Android: `react-native-health-connect` (Health Connect API, Android 9+)
- Permisos: el usuario debe aprobar explícitamente por tipo de dato
- Privacy: datos de salud son categoría especial — documentar en Privacy Policy

---

### 2. Strava — **P1 post-lanzamiento**

Muy popular en la comunidad de running y ciclismo en LatAm. Muchos atletas ya tienen sus carreras en Strava.

**Qué datos provee (API pública, OAuth estándar):**
- Actividades completadas: tipo (run/ride/walk), distancia, tiempo, pace, elevación, HR media/máxima, RPE subjetivo, foto del mapa GPS
- Splits por kilómetro (pace por km)
- Kudos y comentarios de la comunidad (social)
- Segmentos y tiempos (comparativa vs historial propio)
- **NO provee:** VO2max, HRV, sueño — Strava es solo actividad

**Cómo mapea a Medaliq:**
- Actividad importada → auto-completa `SessionLog` con tipo, distancia, duración, FC
- Pace por km → nuevo campo `SessionLog.avgPaceSecPerKm Int?`
- El atleta vincula Strava una vez → las actividades se importan automáticamente via webhook

**Requisitos técnicos:**
- API pública, bien documentada, OAuth 2.0
- Webhook para recibir nuevas actividades en tiempo real
- Rate limit: 100 req/15min, 1000 req/día por atleta — suficiente
- **No requiere aprobación especial** — la más fácil de implementar

---

### 3. Garmin Connect API — **P2**

La más popular entre corredores serios en LatAm (Garmin Forerunner, Fenix). Provee los datos más ricos del mercado.

**Qué datos provee:**
- Actividades GPS completas con HR por segundo
- VO2max estimado (Garmin First Beat analytics)
- HRV score diario
- Body Battery (índice de energía Garmin)
- Training Status (productivo / mantenimiento / sobrecarga — algoritmo Garmin)
- Training Load (carga de entrenamiento semanal)
- Sueño (fases, puntuación)
- Estrés (medido desde FC en reposo)

**Cómo mapea a Medaliq:**
- Actividad → `SessionLog` completo con datos reales de FC
- VO2max → `HealthProfile.vo2maxEstimate` actualizable automáticamente
- HRV → nuevo campo `WeeklyCheckIn.hrvMs Float?` o `HealthProfile.hrvMs`
- Training Status → input para `evaluateCheckInRules` (si Garmin ya dice "sobrecarga" → refuerza triggers)

**Requisitos técnicos (requiere investigación):**
- API Health: requiere aplicar a programa de partnership con Garmin — **no es acceso inmediato**
- Alternativa para MVP: Garmin Connect IQ (app en el reloj) o import manual de .fit files
- Webhook push para actividades nuevas disponible una vez aprobado
- **Prioridad de investigación: confirmar proceso de aprobación y tiempo estimado**

---

### 4. BLE HRM (Bluetooth Heart Rate Monitors) — **P2**

Conectar monitors de FC por Bluetooth durante la sesión. Los más populares: Polar H10, Wahoo TICKR, Garmin HRM-Pro.

**Qué resuelve:**
- FC en TIEMPO REAL durante el entrenamiento (no manual después)
- Útil especialmente en gym (zonas FC durante cardio o HIIT)
- Atletas que no tienen smartwatch pero sí una banda de FC (~$50-80 USD)

**Cómo mapea a Medaliq:**
- FC en tiempo real → visualización de zona actual durante la sesión en el gym tracker
- FC media/máxima → auto-guardada en `SessionLog`

**Requisitos técnicos:**
- `react-native-ble-plx` en Expo
- Perfil GATT: UUID `0x180D` (Heart Rate Service estándar Bluetooth)
- Requiere bare workflow en Expo o config plugin
- Permisos Bluetooth en iOS y Android

---

### 5. TrainingPeaks — **P3**

Plataforma que muchos coaches ya usan. La integración sería principalmente como herramienta de **migración de coaches** que vienen de TP.

**Contexto estratégico:**
- Medaliq quiere reemplazar TP para sus coaches, no integrarse con él a largo plazo
- Una integración bidireccional al inicio baja la fricción de adopción: "Puedes usar Medaliq sin perder tus atletas en TP"
- A medida que el coach migra completamente, la integración se vuelve innecesaria

**Requisitos técnicos (requiere investigación):**
- TrainingPeaks no tiene API pública documentada — requiere partner agreement
- Alternativa: importar archivos .fit/.tcx/.gpx que TP exporta

---

## Impacto en modelos de datos — campos nuevos requeridos

Antes de implementar cualquier integración, evaluar si el schema DB soporta los datos:

| Dato nuevo | Modelo afectado | Campo sugerido |
|-----------|-----------------|----------------|
| Pace por km | `SessionLog` | `avgPaceSecPerKm Int?` |
| FC media durante sesión | `SessionLog` | `hrAvg Int?` |
| FC máxima durante sesión | `SessionLog` | `hrMax Int?` |
| Calorías quemadas | `SessionLog` | `caloriesBurned Int?` |
| VO2max estimado | `HealthProfile` | `vo2maxEstimate Float?` |
| HRV | `HealthProfile` o `WeeklyCheckIn` | `hrvMs Float?` |
| Fuente del dato | `SessionLog` | `dataSource String?` (MANUAL/STRAVA/GARMIN/HEALTHKIT) |
| ID externo | `SessionLog` | `externalId String?` (Strava activity ID, Garmin activity ID) |

---

## Investigación pendiente antes de implementar

| Integración | Qué investigar | Urgencia |
|-------------|---------------|----------|
| Apple HealthKit | ¿Expo managed soporta VO2max y HRV, o requiere bare? | Alta |
| Google Health Connect | Versión mínima Android, disponibilidad en LatAm | Alta |
| Garmin Health API | Proceso de aprobación, tiempo estimado, requisitos | Alta |
| Strava Webhooks | Rate limits, política de uso de datos de usuario | Media |
| TrainingPeaks | ¿Existe API pública o solo partner program? | Baja |

---

## Lo que NO se hace con datos de wearables

- No se almacena el track GPS completo de las carreras (privacy + storage)
- No se comparten datos de wearables con el coach sin consentimiento explícito del atleta
- No se usa HRV o Body Battery para diagnosticar condiciones médicas — solo para reforzar señales en el check-in
- No se muestran datos de wearables como "verdad absoluta" — son estimaciones del dispositivo

---

## Estado en código

**Strava — IMPLEMENTADO (backend completo, pendiente activación en producción)**

| Componente | Archivo | Estado |
|-----------|---------|--------|
| OAuth redirect | `src/app/api/athlete/integrations/strava/connect/route.ts` | ✅ |
| OAuth callback | `src/app/api/athlete/integrations/strava/callback/route.ts` | ✅ |
| Desconectar | `src/app/api/athlete/integrations/strava/route.ts` (DELETE) | ✅ |
| Webhook challenge + handler | `src/app/api/webhooks/strava/route.ts` | ✅ |
| Token refresh + activity fetch | `src/infrastructure/wearable/strava.service.ts` | ✅ |
| Mapper Activity→SessionLog | `src/infrastructure/wearable/strava.mapper.ts` | ✅ |
| Use case createWearableSession | `src/domain/wearables/create_wearable_session.use_case.ts` | ✅ |
| UI settings atleta | `src/app/(athlete)/settings/integrations/page.tsx` | ✅ |

**Pendiente para activar en producción:**
- `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_WEBHOOK_VERIFY_TOKEN` en Vercel env
- `prisma migrate deploy` (migración `WearableConnection`)
- Ejecutar `POST /api/admin/integrations/strava/subscribe` una vez (registra webhook en Strava)

**Apple HealthKit (iOS) — IMPLEMENTADO PARCIAL (mobile)**
- Permisos, sync de workouts, pre-fill check-in (sueno + FC reposo), auto-sync al abrir app
- Falta: auto-sync diario sueno/FC → DailyLog, VO2max sync, Health Connect Android
- Ver domain doc completo: `domains/wearables.md` | Spec: `specs/wearables.spec.md`

**Google Health Connect (Android) — NO implementado.** Gap critico: 50%+ atletas LatAm son Android.

**Garmin, BLE HRM — NO implementados.** Garmin requiere partnership (P2). BLE HRM requiere bare workflow (P2).

**Campos DB ya disponibles en el schema** (migrados, listos para wearables — la tabla de arriba está desactualizada):

| Campo | Modelo | Estado |
|-------|--------|--------|
| `hrAvg`, `hrMax` | `SessionLog` | ✅ en schema |
| `caloriesBurned` | `SessionLog` | ✅ en schema |
| `avgPaceSecPerKm` | `SessionLog` | ✅ en schema |
| `dataSource` | `SessionLog` | ✅ en schema (`MANUAL\|STRAVA\|GARMIN\|HEALTHKIT`) |
| `externalId`, `garminActivityId` | `SessionLog` | ✅ en schema |
| `vo2maxEstimate` | `HealthProfile` | ✅ en schema |
| `hrvMs` | `WeeklyCheckIn` | ✅ en schema |

**DB implementada (migración 20260708180057):**
`WearableConnection` ✅ — `userId`, `provider String` (strava|garmin|healthkit), `accessToken`, `refreshToken?`, `expiresAt?`, `scopes String[]`, `providerAccountId String?` (usado para mapear webhooks). `@@unique([userId, provider])`. Implementado. Endpoints activos: connect, callback, DELETE, webhook. Pendiente solo activar env vars en produccion.
