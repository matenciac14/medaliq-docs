# WEBHOOKS — Spec de webhooks de pago y Strava

<!-- mirror: false -->
<!-- note: webhooks son server-to-server. No hay endpoints de usuario -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Archivos fuente: `src/app/api/webhooks/wompi/route.ts`, `payment/route.ts`, `strava/route.ts`, `mercadopago/route.ts`
> Domain doc: `../domains/pagos.md`

## TL;DR
- 4 endpoints (Wompi, payment generico, Strava, MercadoPago stub)
- Modelos: UserSubscription, Payment, SessionLog (Strava)
- Dependencias: WompiPaymentGateway.parseWebhookEvent(), processPayment use case, refreshStravaToken()
- Trampas criticas: Wompi sin signature en header (SHA-256 del body), Strava POST sin verificacion de firma, idempotencia via lastWebhookEventId
- Mirror mobile: N/A — server-to-server

---

## Contratos de la AI

- [ ] Los webhooks de pago manejan dinero real — un bug aqui = suscripciones rotas silenciosamente
- [ ] Wompi NO envia signature en header HTTP — la verificacion es SHA-256 del body
- [ ] Strava POST no tiene verificacion de firma — todo POST entrante se procesa
- [ ] El webhook hace upgrade (`charge.success`) y cancelacion inmediata (`subscription.cancelled`). El cron `billing-check` maneja el downgrade por non-payment despues del grace period de 3 dias
- [ ] Idempotencia via `lastWebhookEventId` — si ya se proceso, retorna `duplicate: true` sin escribir

---

## Endpoints

| Metodo | Path | Auth | Descripcion |
|--------|------|------|-------------|
| POST | `/api/webhooks/wompi` | SHA-256 checksum en body | Webhook de pago Wompi (produccion) |
| POST | `/api/webhooks/payment` | `x-payment-signature` header + factory gateway | Webhook generico (dev/stub) |
| GET | `/api/webhooks/strava` | `hub.verify_token` query param | Challenge de suscripcion Strava |
| POST | `/api/webhooks/strava` | Ninguna | Evento de actividad Strava |
| POST | `/api/webhooks/mercadopago` | Ninguna | Stub — retorna 200 sin procesar |

---

## Wompi — POST /api/webhooks/wompi

### Verificacion de integridad

```
SHA256(tx.reference + tx.amount_in_cents + tx.currency + WOMPI_INTEGRITY_SECRET) === tx.signature.checksum
```

Si `WOMPI_INTEGRITY_SECRET` no existe o checksum no coincide → `400 { error: "Firma Wompi invalida." }`

### Request payload

```ts
{
  event: "transaction.updated"
  data: {
    transaction: {
      id: string
      status: "APPROVED" | "DECLINED" | "ERROR" | "VOIDED" | "PENDING"
      reference: string           // "coach-{userId}-{tier}-{ts}" o "athlete-{userId}-pro-{ts}"
      amount_in_cents: number
      currency: "COP"
      metadata: {
        userId: string            // requerido
        userRole: "COACH" | "ATHLETE"  // requerido
        targetTier?: "GROWTH" | "PRO" | "SCALE"  // solo para COACH
      }
      signature: { checksum: string }
    }
  }
}
```

### State machine

```
tx.status APPROVED → eventType "charge.success"
tx.status DECLINED|ERROR|VOIDED|PENDING → eventType "charge.failed"
```

### Transiciones de DB por eventType

**`charge.success` + COACH:**
- `UserSubscription.upsert` → `coachTier = targetTier`, `currentPeriodEnd = now + 30d`, `gateway = 'wompi'`

**`charge.success` + ATHLETE** (en `$transaction`):
- `UserSubscription.upsert` → `tier = 'PRO'`, `currentPeriodEnd = now + 30d`, `gateway = 'wompi'`
- `User.update` → `featurePlan = true`, `featureCheckin = true`, `featureProgress = true`

**`charge.failed`:** NO escribe nada. El downgrade lo hace el cron `billing-check` despues del grace period.

**`subscription.cancelled` + COACH:**
- `UserSubscription.update` → `coachTier = 'STARTER'`, `currentPeriodEnd = null`
- Los atletas del coach NO se tocan

**`subscription.cancelled` + ATHLETE** (en `$transaction`):
- `UserSubscription.update` → `tier = 'FREE'`, `currentPeriodEnd = null`
- `User.update` → `featurePlan = false`, `featureCheckin = false`, `featureProgress = false`

### Idempotencia

1. Lee `UserSubscription.lastWebhookEventId` para el userId
2. Si `lastEventId === event.eventId` → `200 { received: true, duplicate: true }`
3. Despues de procesar → `updateMany` para guardar el nuevo eventId (updateMany para evitar P2025)

### Responses

| Condicion | Status | Body |
|-----------|--------|------|
| Checksum invalido | 400 | `{ error: "Firma Wompi invalida." }` |
| Duplicado | 200 | `{ received: true, duplicate: true, eventId }` |
| Exito | 200 | `{ received: true, eventId }` |

---

## Payment generico — POST /api/webhooks/payment

Misma logica que Wompi pero usa `getPaymentGateway()` factory en vez de instanciar `WompiPaymentGateway` directo. Lee `x-payment-signature` header (Wompi lo ignora internamente). **No pasa `'wompi'` como gateway** a `upgradeCoach/upgradeAthlete` — el campo `gateway` queda `undefined`.

---

## Strava — GET /api/webhooks/strava (challenge)

```ts
// Query params requeridos
hub.mode === 'subscribe'
hub.verify_token === process.env.STRAVA_WEBHOOK_VERIFY_TOKEN
hub.challenge = string  // se devuelve tal cual
```

Exito → `200 { "hub.challenge": challenge }`
Fallo → `403 { error: "Forbidden" }`

---

## Strava — POST /api/webhooks/strava (evento)

### Sin verificacion de firma — Strava no firma webhooks

### Guard: solo procesa `aspect_type === 'create' AND object_type === 'activity'`

### Flujo (fire-and-forget, retorna 200 inmediatamente)

1. `wearableRepository.findByProviderAccountId('strava', owner_id)` → mapea a userId
2. `refreshStravaTokenIfNeeded(userId)` → renueva si expira en <10min
3. `fetchStravaActivity(object_id, accessToken)` → GET Strava API
4. `stravaActivityToSessionLog(activity, userId)` → mapea campos
5. `createWearableSession(input)` → upsert idempotente por `(userId, externalId)`

### Mapeo Strava → SessionLog

| Strava | SessionLog | Transformacion |
|--------|-----------|----------------|
| `activity.id` | `externalId` | `.toString()` |
| `sport_type` | `discipline` | Run/TrailRun→RUNNING, Ride→CYCLING, Swim→SWIMMING, WeightTraining→STRENGTH, otro→OTHER |
| `distance` | `distanceKm` | `/ 1000` |
| `moving_time` | `durationMin` | `/ 60` |
| `average_heartrate` | `hrAvg` | `Math.round` |
| `average_speed` | `avgPaceSecPerKm` | `Math.round(1000 / speed)` |

### Idempotencia: dedup por `(userId, externalId)` — si ya existe, retorna `{ created: false }`

---

## Mercado Pago — POST /api/webhooks/mercadopago

**Stub completo.** Retorna `200 { message: "Mercado Pago integration coming in P2" }`. No lee body, no escribe DB.

---

## Modelos DB involucrados

```
UserSubscription: userId, tier, coachTier, currentPeriodEnd, gateway, lastWebhookEventId
User: featurePlan, featureCheckin, featureProgress, role
WearableConnection: userId, provider, providerAccountId, accessToken, refreshToken, expiresAt
SessionLog: userId, externalId, dataSource, discipline, distanceKm, durationMin, hrAvg, hrMax
```

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|--------------------|
| `charge.failed` hace downgrade | El webhook maneja todo | Solo upgrade. Downgrade es via cron `billing-check` con 3 dias de gracia |
| `newPeriodEnd` viene de Wompi | El gateway lo calcula | Se calcula server-side: `new Date() + 30d` |
| `/webhooks/payment` es igual a `/webhooks/wompi` | Son intercambiables | payment NO pasa `gateway = 'wompi'` al repo — el campo queda `undefined` |
| Strava POST tiene auth | Seguro contra spam | NO tiene verificacion de firma. Cualquier POST a la URL se procesa |
| `saveWebhookEventId` usa `update` | Falla si no existe la fila | Usa `updateMany` para evitar P2025 si no existe UserSubscription |

---

## Env vars requeridas

```
WOMPI_INTEGRITY_SECRET    — verificacion checksum
WOMPI_PRIVATE_KEY         — crear payment links
WOMPI_SANDBOX             — 'true' para sandbox
PAYMENT_GATEWAY           — 'wompi' o 'stub'
STRAVA_WEBHOOK_VERIFY_TOKEN — challenge GET
STRAVA_CLIENT_ID          — token refresh
STRAVA_CLIENT_SECRET      — token refresh
```

---

## Tests requeridos

- [ ] Wompi: checksum invalido → 400
- [ ] Wompi: evento duplicado → 200 + duplicate: true + sin DB write
- [ ] Wompi: APPROVED COACH → coachTier actualizado
- [ ] Wompi: APPROVED ATHLETE → tier PRO + 3 features activados en $transaction
- [ ] Wompi: DECLINED → sin cambio en DB
- [ ] Strava: challenge GET con token correcto → 200 + challenge echo
- [ ] Strava: actividad nueva → SessionLog creado con dataSource STRAVA
- [ ] Strava: actividad duplicada → sin nuevo SessionLog

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo por agentes SDD |
