---
tags: [medaliq, spec, wearables, integraciones, strava]
---

# STRAVA_ACTIVATION — Activacion de Strava Sync + Hub Unificado

<!-- mirror: partial -->
<!-- mirror-endpoints: Strava OAuth es web-only. Mobile importa runs via Strava webhook (server-push) -->
<!-- note: Backend 100% implementado (STRA-01 a STRA-10). Este spec documenta la ACTIVACION + extension hub -->

> Backend ya implementado. Esta spec cubre: (1) activacion de env vars, (2) extension del dashboard para mostrar runs importados, (3) PRs de running, (4) calendario unificado gym+running.
> Specs relacionadas: `wearables.spec.md`, `dashboard.spec.md`, `plan_sessions.spec.md`
> Domain doc: [[wearables]] · [[integraciones]]

## TL;DR
- 0 endpoints nuevos de backend Strava (ya implementados)
- 2 endpoints nuevos: running PRs, calendario unificado con fuente de datos
- Modelos: SessionLog (con dataSource STRAVA), WearableConnection
- Trampas: Strava OAuth es web-only, mobile conecta via deep link a web
- Lo que SI es nuevo: presentacion de runs en dashboard + PRs running + vista unificada

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
El atleta conecta Strava desde la web (OAuth). Sus runs se importan automaticamente via webhook. En la app ve gym + runs de Strava juntos en el calendario, con PRs de running (mejor pace por distancia) junto a PRs de gym.

**2. Que resultado obtiene?**
Calendario unificado: lunes gym, martes run (Strava), miercoles gym. PRs de running: mejor 5K, 10K, 21K. Balance energetico incluye calorias de runs importados. Todo sin abrir Strava.

**3. Que debe respetar?**
- Backend Strava ya implementado (STRA-01 a STRA-10) — NO reescribir
- Deduplicacion por externalId — ya funciona en createWearableSession
- OAuth Strava es web-only — mobile usa deep link
- Strava API NO provee: sueno, FC reposo, VO2max — solo actividades deportivas
- Datos de Strava se persisten como SessionLog con dataSource: 'STRAVA'

**4. Como se demuestra?**
- Test: run importado de Strava aparece en calendario del dia correcto
- Test: PRs de running calculados sobre SessionLog con dataSource STRAVA o discipline RUNNING
- Test: balance energetico del dia incluye calorias del run importado
- Deploy: env vars STRAVA_CLIENT_ID + STRAVA_CLIENT_SECRET + STRAVA_WEBHOOK_VERIFY_TOKEN configuradas

## Contratos de la AI

- [ ] NO tocar endpoints Strava existentes (connect, callback, disconnect, webhook) — estan implementados y testeados
- [ ] SessionLog de Strava tiene: dataSource='STRAVA', externalId=activityId, discipline, distanceKm, durationMin, hrAvg, hrMax, caloriesBurned, avgPaceSecPerKm
- [ ] PRs de running: buscar en SessionLog WHERE discipline='RUNNING' (incluye tanto manuales como Strava)
- [ ] Deduplicacion: si externalId ya existe → skip (createWearableSession ya maneja esto)
- [ ] El calendario `buildCalendarWeek()` ya incluye SessionLog libres (freeRun slot) — runs de Strava SIN plannedSessionId ya aparecen ahi
- [ ] Strava webhook es POST /api/webhooks/strava — recibe eventos asincronos (~1-5 min post actividad)
- [ ] Token refresh automatico en strava.service.ts — si accessToken expiro, usa refreshToken

## Paso 0 — Activacion (ops, no codigo)

Miguel debe hacer:
1. Crear app en strava.com/settings/api
2. Agregar a .env.local y Vercel:
   - `STRAVA_CLIENT_ID`
   - `STRAVA_CLIENT_SECRET`
   - `STRAVA_WEBHOOK_VERIFY_TOKEN` (string aleatorio)
3. Deploy a produccion
4. POST /api/admin/integrations/strava/subscribe (one-time, crea webhook en Strava)
5. Verificar: GET /api/admin/integrations/strava/subscribe → estado activo

## Endpoints nuevos

### Running PRs

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/athlete/running/prs` | auth() | 300/min | PRs de running del atleta |
| GET | `/api/mobile/running/prs` | getMobileUser() | 300/min | PRs de running (mobile) |

### GET running/prs

**Response 200:**
```ts
{
  prs: Array<{
    distance: '1K' | '5K' | '10K' | '21K' | '42K'
    bestPaceSecPerKm: number | null    // mejor pace para esa distancia
    bestPaceFormatted: string | null   // "4:30 min/km"
    bestTimeSeconds: number | null     // tiempo total
    bestTimeFormatted: string | null   // "23:15"
    achievedAt: string | null          // fecha ISO
    source: 'MANUAL' | 'STRAVA' | 'HEALTHKIT'
  }>
}
```

**Logica:**
1. Query SessionLog WHERE userId AND discipline = 'RUNNING' AND distanceKm IS NOT NULL
2. Agrupar por distancia bucket: 0.9-1.1 → 1K, 4.5-5.5 → 5K, 9.5-10.5 → 10K, 20.5-21.5 → 21K, 41.5-42.5 → 42K
3. Para cada bucket: mejor avgPaceSecPerKm (menor = mas rapido)
4. Si no hay logs en un bucket → bestPace: null
5. Retornar array ordenado por distancia

### Calendario unificado — extension

No se necesita endpoint nuevo. `buildCalendarWeek()` ya muestra:
- `sport` slot: PlannedSession del plan
- `gym` slot: GymSession del dia
- `freeRun` slot: SessionLog libre (incluye Strava)

Lo que falta es que el `freeRun` slot incluya `dataSource` para que la UI muestre el icono de Strava:

**Cambio en buildCalendarWeek response — agregar campo:**
```ts
freeRun: {
  sessionLogId: string
  type: string
  durationMin: number | null
  distanceKm: number | null
  dataSource: string | null  // NUEVO: 'MANUAL' | 'STRAVA' | 'HEALTHKIT' | null
}
```

## Modelos DB involucrados

No requiere modelos nuevos. Solo lectura + un campo adicional en response:

```prisma
// Ya existentes
SessionLog        { dataSource, externalId, discipline, distanceKm, avgPaceSecPerKm, durationMin, caloriesBurned }
WearableConnection { userId, provider, accessToken, refreshToken, expiresAt }
```

## Reglas de negocio (invariantes)

1. **Strava solo importa actividades deportivas** — no sueno, no FC reposo, no pasos
2. **Un run de Strava = un SessionLog** con dataSource='STRAVA' y externalId=activityId
3. **PRs de running son cross-source**: incluyen runs manuales + Strava + HealthKit
4. **Distance bucket tolerance**: 10% (5K = 4.5-5.5km) porque GPS no es perfecto
5. **OAuth Strava es web-only** — mobile redirige a web via deep link
6. **Desconectar Strava no borra SessionLogs** — datos historicos persisten
7. **Webhook Strava no tiene firma HMAC** — Strava no firma POSTs (verificar solo via subscription)

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Strava OAuth en mobile | Parece que hay OAuth in-app | Web-only. Mobile deep link → web → callback → redirect back |
| Webhook sin firma | Parece inseguro | Strava NO firma webhooks. Se verifica via challenge de suscripcion + verify_token |
| PRs de Strava vs PRs de gym | Parecen el mismo sistema | Son sistemas separados: gym usa isPR en SetLog (peso), running usa pace en SessionLog |
| buildCalendarWeek ya muestra runs | Parece que hay que agregar logica | Solo falta exponer dataSource en el freeRun slot |

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Conectar Strava (OAuth) | GET /api/athlete/integrations/strava/connect | Deep link → web |
| Ver runs importados en calendario | buildCalendarWeek (ya funciona) | buildCalendarWeek (ya funciona) |
| PRs de running | GET /api/athlete/running/prs | GET /api/mobile/running/prs |
| Desconectar Strava | DELETE /api/athlete/integrations/strava | Deep link → web |
| Icono Strava en run | dataSource en freeRun slot | dataSource en freeRun slot |

## Tests requeridos

- [ ] GET running/prs: atleta sin runs → prs con todos bestPace: null
- [ ] GET running/prs: run de 5.2km → bucket 5K
- [ ] GET running/prs: run de 4.4km → NO entra en bucket 5K (fuera de tolerancia)
- [ ] GET running/prs: mejor pace seleccionado correctamente (menor = mas rapido)
- [ ] GET running/prs: incluye runs de Strava Y manuales
- [ ] buildCalendarWeek: SessionLog con dataSource STRAVA → freeRun.dataSource = 'STRAVA'
- [ ] Auth: sin sesion → 401

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — activacion Strava + hub unificado |
