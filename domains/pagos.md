# Domain: Pagos y Suscripciones

> Reglas de negocio y guía técnica completa de billing. Leer antes de tocar cualquier archivo en `src/domain/billing/`, `src/infrastructure/billing/`, o `src/app/api/billing/`.
> Flujos por actor → `flujos-por-actor.md`
> Specs de implementacion: `../specs/billing.spec.md` · `../specs/webhooks.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Completa (/settings/plan, upgrade) |
| Mobile atleta | Completa (pricing, upgrade via in-app browser Wompi) |
| Web coach | Completa (suscripción coach) |

---

## Modelo de negocio — dos relaciones financieras independientes

```
Medaliq ←→ Coach      Medaliq le cobra al coach por su tier (cantidad de atletas)
Coach   ←→ Atleta     El coach le cobra al atleta directamente (Nequi, Daviplata, transferencia)
```

**Medaliq NUNCA toca el dinero entre coach y atleta.** El módulo de finanzas del coach es un CRM de cuentas por cobrar, no un procesador de pagos. El 0% fee no es pricing — es estructural.

---

## Tiers y precios

### Coach (plataforma)

| Tier | Asesorados activos | USD/mes | COP/mes |
|------|--------------------|---------|---------|
| STARTER | Hasta 2 | $0 | $0 |
| GROWTH | 3–10 | $59 | $247.800 |
| PRO | 11–30 | $139 | $583.800 |
| SCALE | 31+ | $139 + $4/atleta sobre 30 | $583.800 + $16.800/atleta sobre 30 |

TRM de referencia: 1 USD = 4.200 COP. Revisar trimestralmente y actualizar `COACH_TIER_PRICES_COP` en `billing.types.ts`.

**Atleta activo para billing — definición canónica:**
- `CoachAthlete.status = 'ACTIVE'`

**Estado actual en código:** el conteo usa solo `status: 'ACTIVE'` (`create_athlete.use_case.ts`, `status/route.ts`). Los criterios adicionales (onboardingCompleted + SessionLog) están pendientes de implementar.

Un atleta PAUSED no cuenta para el límite del tier.

### Atleta B2C

| Tier | Precio | Features habilitadas |
|------|--------|---------------------|
| FREE | $0 permanente | featureLog · featureNutrition · featureGym. Historial limitado a ultimos 30 dias (entrenamiento y nutricion). Sin planificacion futura. |
| PRO mensual | $41.980 COP/mes (~$9.99 USD) | Todo FREE + featurePlan · featureCheckin · featureProgress. Historial completo desde fecha de suscripcion. Puede planificar semanas futuras. |
| PRO anual | $251.960 COP/ano (~$59.99 USD) → $5.00 USD/mes efectivo | Mismo acceso que Pro mensual. Descuento ~40%. Período de 365 dias. |

**Atleta B2B → siempre $0.** Su acceso está incluido en el tier del coach. Nunca ve pantalla de pago.

---

## Arquitectura técnica — hexagonal, gateway-agnostic

```
src/domain/
  ports/
    payment_gateway.ts          IPaymentGateway — interface que todo gateway implementa
    billing.repository.ts       IBillingRepository — interface de persistencia
  billing/
    billing.types.ts            Tipos + constantes (precios COP/USD, BILLING_GRACE_DAYS)
    checkout.use_case.ts        createCoachCheckout, createAthleteCheckout, validateCoachUpgrade
    downgrade.use_case.ts       runBillingCheck, isGracePeriodExpired

src/infrastructure/billing/
  wompi_payment_gateway.ts      WompiPaymentGateway implements IPaymentGateway  [ACTIVO]
  stub_payment_gateway.ts       StubPaymentGateway — dev/testing local
  payment_gateway.factory.ts    getPaymentGateway() lee env PAYMENT_GATEWAY
  billing.repository.ts         BillingRepository implements IBillingRepository

src/app/api/
  billing/coach/checkout/       POST — genera payment link coach
  billing/athlete/checkout/     POST — genera payment link atleta
  billing/status/               GET  — polling post-pago (tier actual del usuario)
  webhooks/wompi/               POST — webhook dedicado Wompi (producción)
  webhooks/mercadopago/         POST — stub P2 (retorna 200, sin lógica)
  webhooks/payment/             POST — webhook genérico stub/dev
  cron/billing-check/           GET|POST — downgrade automático (diario 2am UTC, Vercel cron envía GET)
  cron/billing-renewal-reminder/GET  — recordatorio 7 días antes (diario 1pm UTC)
```

### IPaymentGateway — contrato del port

```ts
interface IPaymentGateway {
  createCoachCheckout(input: CoachCheckoutInput): Promise<CheckoutOutput>
  createAthleteCheckout(input: AthleteCheckoutInput): Promise<CheckoutOutput>
  parseWebhookEvent(rawBody: string, signature: string): Promise<WebhookEvent>
}
```

Cualquier gateway nuevo (Mercado Pago, Stripe) solo necesita implementar esta interface + wiring en `payment_gateway.factory.ts`. El dominio no cambia.

### IBillingRepository — métodos clave

```ts
findByUserId(userId)                          → SubscriptionSnapshot | null
upgradeCoach(userId, data)                    → void  // upsert coachTier + currentPeriodEnd
upgradeAthlete(userId, data)                  → void  // upsert tier + activa features
downgradeCoach(userId)                        → void  // coachTier = STARTER
downgradeAthlete(userId)                      → void  // tier = FREE + desactiva features
findExpired(graceDays, now)                   → SubscriptionSnapshot[]
saveWebhookEventId(userId, eventId)           → void  // updateMany — no lanza P2025
getLastWebhookEventId(userId)                 → string | null
```

> **Nota: `saveGateway` ya está en la interfaz del port `IBillingRepository` — deuda técnica resuelta.**

**Nota sobre `saveWebhookEventId`**: usa `updateMany` (no `update`) para no lanzar P2025 si el registro de suscripción aún no existe cuando llega el webhook por primera vez.

---

## Wompi — detalles de implementación

### Por qué Wompi no tiene suscripciones nativas

Wompi soporta pagos únicos y payment links, pero no cobra automáticamente mes a mes. El sistema implementa **suscripción manual**:

1. El usuario paga con un payment link (single_use: true)
2. El webhook APPROVED extiende `currentPeriodEnd + 30 días`
3. 7 días antes de vencer: cron envía email con nuevo link de pago
4. Si no renueva: grace de 3 días → cron de downgrade

### Verificación de integridad del webhook

Wompi incluye en el payload un `signature.checksum` que se verifica así:

```
SHA256(reference + amount_in_cents + currency + WOMPI_INTEGRITY_SECRET) === checksum
```

Si no coincide → rechazar con 400 sin procesar. Esto previene webhooks falsificados.

### Idempotencia

Wompi puede reenviar el mismo evento si no responde 200 a tiempo. El handler:
1. Lee `lastWebhookEventId` de la DB
2. Si `event.id === lastWebhookEventId` → retorna `{ received: true, duplicate: true }` sin procesar
3. Al finalizar el procesamiento → guarda el nuevo `event.id`

### Metadata en el payment link

Al crear el link se pasa en `metadata`:
```json
{ "userId": "...", "userRole": "COACH", "targetTier": "GROWTH", "successUrl": "..." }
```

Wompi devuelve esta metadata intacta en el webhook → así sabemos a quién actualizar y a qué tier, sin necesidad de buscar en DB por referencia.

### Reference format

```
coach-{userId}-{targetTier}-{timestamp}     ej: coach-cluabc123-GROWTH-1723123456789
athlete-{userId}-pro-{timestamp}            ej: athlete-cludef456-pro-1723123456789
```

### `validateCoachUpgrade` — regla importante

El use case `createCoachCheckout` rechaza si `currentTier === targetTier`. Esto previene que un coach pague por el mismo tier que ya tiene.

**Excepción**: el cron de renovación necesita crear un link para el **mismo tier** (renovar, no subir). Por eso llama directamente a `gateway.createCoachCheckout()` sin pasar por el use case. Este comportamiento está documentado con comentario en el cron.

---

## Flujos completos

### Flujo 1: Upgrade de tier

```
1. Coach abre /coach/settings/plan → ve tier actual + opciones superiores
2. Click "Subir a Growth" → POST /api/billing/coach/checkout { targetTier: 'GROWTH' }
3. use case: validateCoachUpgrade (bloques si ya es GROWTH o superior)
4. gateway.createCoachCheckout → POST Wompi /v1/payment_links → { url }
5. Respuesta: { checkoutUrl }  → window.location.href = checkoutUrl
6. Usuario paga en Wompi
7. Wompi redirige a /coach/settings/plan?billing=success
8. UI inicia polling: GET /api/billing/status cada 2s (máx 5 intentos = 10s)
9. Wompi envía POST /api/webhooks/wompi (asíncrono, puede llegar antes o después del redirect)
10. Webhook verifica SHA256, chequea idempotencia, llama upgradeCoach(userId, { GROWTH, now+30d }, 'wompi')
11. Polling detecta coachTier !== currentTier → router.refresh()
12. Server component recarga con tier actualizado

Si pasan 5 intentos sin cambio (10s) → toast: "Pago recibido. Recarga si tu plan no se actualizó."
```

El flujo de atleta es idéntico: `/api/billing/athlete/checkout` → `upgradeAthlete` (también activa featurePlan + featureCheckin + featureProgress en `User`).

### Flujo 2: Renovación mensual

```
Cron GET /api/cron/billing-renewal-reminder  [diario, 1pm UTC / 8am COT]
  Busca: gateway='wompi' AND currentPeriodEnd entre (now+7d, now+8d)
    → ventana de 1 día para evitar emails duplicados

  Por cada suscripción encontrada:
    Coach → gateway.createCoachCheckout(tier, tier)  [mismo tier = renovación]
    Atleta → gateway.createAthleteCheckout(userId, ...)
    sendBillingRenewalReminderEmail(email, name, tierName, renewalDate, renewalLink)

  Usuario recibe email → hace clic → paga → webhook APPROVED → currentPeriodEnd +30d
```

### Flujo 3: Downgrade por no-renovación

```
Cron POST /api/cron/billing-check  [diario, 2am UTC / 9pm COT]
  runBillingCheck(repo)
    findExpired(graceDays=3, now)
      → WHERE currentPeriodEnd < (now - 3 días)  [gracia de 3 días post-vencimiento]
      → AND (tier='PRO' OR coachTier != 'STARTER')

  Por cada vencida:
    COACH  → downgradeCoach(userId)   → coachTier='STARTER', currentPeriodEnd=null
    ATHLETE → downgradeAthlete(userId) → tier='FREE', featurePlan/Checkin/Progress=false

Nota: los atletas del coach NO se desactivan. El coach los conserva, solo pierde
el acceso a gestionar más de 5 atletas hasta que renueve.
```

**Timeline de un ciclo completo:**
- Día 0: pago exitoso → `currentPeriodEnd = now + 30d`
- Día 23: email de renovación con nuevo link
- Día 30: vence. Grace activa.
- Día 33: cron de downgrade ejecuta.

---

## Variables de entorno

### Requeridas para activar Wompi en producción

```bash
PAYMENT_GATEWAY=wompi
WOMPI_PRIVATE_KEY=prv_prod_...        # dashboard.wompi.co > API keys > Llave privada
WOMPI_INTEGRITY_SECRET=...            # dashboard.wompi.co > Webhooks > Integrity Secret
```

### Para testing en sandbox

```bash
PAYMENT_GATEWAY=wompi
WOMPI_SANDBOX=true                    # apunta a sandbox.wompi.co en lugar de production.wompi.co
WOMPI_PRIVATE_KEY=prv_test_...        # llave privada del ambiente de pruebas
WOMPI_INTEGRITY_SECRET=test_integrity_...  # integrity secret del sandbox
```

### Crons (ya configurados en vercel.json)

```bash
CRON_SECRET=...    # cualquier string seguro — header Authorization: Bearer <CRON_SECRET>
```

### URL del webhook en dashboard Wompi

```
Producción: https://medaliq.com/api/webhooks/wompi
Sandbox:    usar ngrok o similar para exponer localhost durante desarrollo
```

---

## Guía de testing

### Prerequisitos

1. Tener llaves de sandbox en dashboard.wompi.co (modo pruebas)
2. `.env.local` con `PAYMENT_GATEWAY=wompi`, `WOMPI_SANDBOX=true`, llaves de sandbox
3. `ngrok http 3000` para exponer localhost al webhook de sandbox

### Test 1: Upgrade de coach (sandbox)

```bash
# 1. Levantar app en sandbox
WOMPI_SANDBOX=true pnpm dev

# 2. Exponer al webhook
ngrok http 3000
# copiar URL: https://xxxx.ngrok.io

# 3. Configurar en dashboard.wompi.co (modo pruebas) > Webhooks
#    URL: https://xxxx.ngrok.io/api/webhooks/wompi

# 4. En app: ir a /coach/settings/plan → click "Subir a Growth"
# 5. En checkout de Wompi sandbox, usar datos de prueba:
#    Tarjeta: 4242 4242 4242 4242 | Exp: cualquier fecha futura | CVV: cualquiera
#    Nombre: cualquier nombre | Cuotas: 1

# 6. Verificar en DB:
SELECT "coachTier", "currentPeriodEnd", gateway, "lastWebhookEventId"
FROM "UserSubscription"
WHERE "userId" = '<id del coach>';
# Esperado: coachTier='GROWTH', currentPeriodEnd ≈ now+30d, gateway='wompi'
```

### Test 2: Upgrade de atleta (sandbox)

```bash
# 1. Ir a /upgrade o /(athlete)/settings/plan → "Activar Pro"
# 2. Pagar con tarjeta de sandbox
# 3. Verificar en DB:
SELECT tier, "currentPeriodEnd", gateway FROM "UserSubscription" WHERE "userId" = '<id>';
SELECT "featurePlan", "featureCheckin", "featureProgress" FROM "User" WHERE id = '<id>';
# Esperado: tier='PRO', featurePlan=true, featureCheckin=true, featureProgress=true
```

### Test 3: Idempotencia del webhook

```bash
# Enviar el mismo payload del webhook dos veces (desde ngrok o Wompi dashboard > re-send)
# Primera vez: procesa normalmente → 200 { received: true }
# Segunda vez:  detecta duplicate → 200 { received: true, duplicate: true }
# La DB NO debe haber cambiado en el segundo envío

# Verificar:
SELECT "lastWebhookEventId" FROM "UserSubscription" WHERE "userId" = '<id>';
# Debe ser el id del primer evento, no cambia en el segundo
```

### Test 4: Verificación de firma inválida

```bash
# Enviar webhook con checksum modificado
curl -X POST http://localhost:3000/api/webhooks/wompi \
  -H "Content-Type: application/json" \
  -d '{
    "event": "transaction.updated",
    "data": {
      "transaction": {
        "id": "test-123",
        "status": "APPROVED",
        "reference": "coach-xxx-GROWTH-1234",
        "amount_in_cents": 16380000,
        "currency": "COP",
        "metadata": { "userId": "xxx", "userRole": "COACH", "targetTier": "GROWTH" },
        "signature": { "checksum": "firma_invalida_aqui", "properties": [] }
      }
    }
  }'
# Esperado: 400 { error: "Firma Wompi inválida." }
# La DB NO debe haber cambiado
```

### Test 5: Downgrade manual por cron

```bash
# 1. Setear currentPeriodEnd en el pasado (más de 3 días atrás)
UPDATE "UserSubscription"
SET "currentPeriodEnd" = NOW() - INTERVAL '5 days'
WHERE "userId" = '<id>';

# 2. Ejecutar el cron manualmente
curl -X POST http://localhost:3000/api/cron/billing-check \
  -H "Authorization: Bearer <CRON_SECRET>"

# Esperado: { ok: true, downgraded: 1 }
# Verificar:
SELECT "coachTier", "currentPeriodEnd" FROM "UserSubscription" WHERE "userId" = '<id>';
# Coach: coachTier='STARTER', currentPeriodEnd=null
# Atleta: tier='FREE', featurePlan=false, featureCheckin=false, featureProgress=false
```

### Test 6: Cron de renovación

```bash
# 1. Setear currentPeriodEnd en 7 días exactos
UPDATE "UserSubscription"
SET "currentPeriodEnd" = NOW() + INTERVAL '7 days 30 minutes'
WHERE "userId" = '<id>' AND gateway = 'wompi';

# 2. Ejecutar el cron
curl -H "Authorization: Bearer <CRON_SECRET>" \
  http://localhost:3000/api/cron/billing-renewal-reminder

# Esperado: { ok: true, sent: 1, failed: 0 }
# Verificar en el email (Resend dashboard) que llegó con link de pago válido
```

### Test 7: Polling desde UI

```bash
# El polling está en los client components (CoachPlanClient, AthletePlanClient)
# Para testear manualmente:

# 1. Abrir /coach/settings/plan?billing=success
# 2. Ver en DevTools > Network: requests repetidos a /api/billing/status cada 2s
# 3. Máximo 5 requests. Si el tier no cambió → toast de fallback

# Para forzar el cambio vía DB y ver router.refresh():
UPDATE "UserSubscription" SET "coachTier" = 'GROWTH' WHERE "userId" = '<id>';
# El siguiente poll detecta el cambio y recarga
```

---

## Casos de borde documentados

| Caso | Comportamiento |
|------|---------------|
| Webhook llega antes que el redirect | El polling detecta el tier actualizado en el primer intento |
| Webhook llega 10s después del redirect | El polling agota los 5 intentos → toast fallback. El tier se actualiza correctamente en DB de todas formas |
| Mismo webhook reenviado 2 veces | Idempotencia via `lastWebhookEventId` — segunda llamada retorna `duplicate: true` sin modificar DB |
| Coach intenta renovar mismo tier desde UI | `validateCoachUpgrade` bloquea. El cron de renovación usa `gateway.createCoachCheckout` directo para saltarlo |
| Coach cancela pago | Wompi redirige con `?billing=cancelled` → toast de error en UI. DB sin cambios. Grace no aplica |
| Webhook con firma inválida | 400 inmediato. Sin logs en DB |
| `WOMPI_PRIVATE_KEY` no configurado | `createPaymentLink` lanza `Error('WOMPI_PRIVATE_KEY no configurado.')` → 400 al cliente |
| `WOMPI_INTEGRITY_SECRET` no configurado | `verifyIntegrity` lanza error → 400 al webhook |
| Atleta B2B intenta ir a /settings/plan | Ve mensaje "Tu acceso está gestionado por [coach]" — sin CTA de pago |

---

## Mercado Pago P2 — diferencias vs Wompi

| Aspecto | Wompi (P1 — activo) | Mercado Pago (P2 — pendiente) |
|---------|---------------------|-------------------------------|
| Suscripciones nativas | No — payment link por ciclo | Sí — cobra automáticamente |
| Mercados | Colombia | MX, AR, CL, CO alternativo |
| Métodos de pago | PSE, Nequi, Daviplata, tarjeta | Tarjeta, OXXO, PIX, transferencia |
| Verificación webhook | SHA256 en body (`signature.checksum`) | HMAC header `X-Signature` |
| Ruta webhook | `/api/webhooks/wompi` | `/api/webhooks/mercadopago` (stub hoy) |
| Cron de renovación | Necesario — MP no renueva | NO necesario — MP cobra solo |
| Adapter | `WompiPaymentGateway` (DONE) | `MercadoPagoPaymentGateway` (pendiente) |

Para implementar P2: solo crear `MercadoPagoPaymentGateway implements IPaymentGateway` + `case 'mercadopago'` en factory. El dominio no cambia.

---

## Finanzas del coach → atleta

El coach registra cobros manualmente. El pago ocurre fuera de la app.

```
Coach crea Payment (monto, descripción, fecha de vencimiento)
  → PaymentAuditLog: action = 'CREATED'
  → Atleta ve fecha de vencimiento de su asesoría (solo eso, no el monto)

Si no paga → Coach envía recordatorio desde /coach/finanzas
  → Email + notificación al atleta
  → PaymentAuditLog: action = 'REMINDED'

Coach marca como pagado
  → PaymentAuditLog: action = 'MARKED_PAID'
  → status → PAID
```

**Reglas técnicas del model Payment:**
- `Payment.amount` es `Decimal @db.Decimal(12,2)` → usar `Number(p.amount)` para aritmética JS
- `PaymentStatus: PENDING | PAID` — OVERDUE **no existe en DB**, se calcula: `dueDate < now() && status === 'PENDING'`
- `action` válidos: `CREATED | MARKED_PAID | REMINDED` — String libre, no enum DB, usar exactamente estos valores
- DELETE de payment va dentro de `$transaction` con el AuditLog

---

## Design partners — billing manual

Los primeros coaches (socios de diseño) tienen tier configurado manualmente por admin.
Admin actualiza `UserSubscription.coachTier` directamente en panel `/admin` o via DB.
Sin pasarela activa — acuerdo comercial directo.

---

## Análisis de pasarelas — Colombia 2026

> Última actualización: 2026-10-02

### Comparativa de comisiones

| Pasarela | Comisión | Fee fijo | Suscripciones nativas | Medios locales | Dispersión |
|----------|----------|----------|----------------------|----------------|------------|
| **Wompi** | 2.65% | $700 COP | Tokenización (lógica propia) | Nequi, PSE, Bancolombia, tarjeta | Siguiente día hábil |
| **ePayco** | 2.79-3.5% | $700 COP | Suscripciones 2.0 (portal, reintentos, landing) | Nequi, PSE, Efecty, Baloto, tarjeta | Negociable |
| **Bold** | 2.89-3.29% | $300-$900 | No | Tarjeta, Nequi | Siguiente día |
| **Mercado Pago** | 2.79-3.29% | $800 COP | Limitado | Tarjeta, PSE | Instantáneo a 14 días |
| **PayU** | ~2.99% | $700 COP | Sí | Tarjeta, PSE, Efecty, Baloto | Quincenal |
| **Rebill** | No publicada | — | Core business (retry 60% rechazos) | Tarjeta, PSE, Efecty, Baloto | Variable |
| **Stripe** | **No disponible en Colombia** | — | Stripe Billing (el mejor) | — | — |

Nota: todas las comisiones llevan +19% IVA sobre la comisión (no sobre la venta).

### Decisión: Wompi → V1, ePayco o Rebill → V2

**V1 (ahora):** Wompi ya está implementado (`WompiPaymentGateway`). Comisión más baja del mercado (2.65%), dispersión rápida, Nequi/PSE. La recurrencia la maneja nuestro cron `CRON-09` con tokenización Wompi.

**V2 (20+ coaches):** Evaluar ePayco Suscripciones 2.0 si la gestión manual de reintentos genera churn. ePayco automatiza reintentos, portal de suscripción y landing por plan. La arquitectura `IPaymentGateway` permite swap sin reescribir.

**Expansión México:** Rebill (multi-país, un SDK) o Stripe (requiere LLC en USA, ~$500 + $99/año). Stripe no soporta Nequi/PSE — pierde ~40% conversión en Colombia. Solo para mercados fuera de CO.

### Pasos para activar Wompi

1. Registrarse en `dashboard.wompi.co` (RUT + cuenta Bancolombia o Nequi)
2. Obtener `WOMPI_PRIVATE_KEY` + `WOMPI_INTEGRITY_SECRET`
3. Configurar env vars en Vercel: `PAYMENT_GATEWAY=wompi`
4. Verificar E2E en sandbox: tarjeta test `4242 4242 4242 4242`
5. Activar Nequi + PSE en el dashboard de Wompi
6. Activar crons de billing: `CRON-09` (billing-check) + `CRON-10` (renewal-reminder)

### Mercado fitness apps LatAm

- Tamaño 2026: **~USD $1.1B** | Proyección 2034: **USD $7.87B** (CAGR 27.88%)
- Drivers: mobile payments, coaching accesible, comunidad social
- Sub-segmento coaching B2B: crecimiento más rápido que B2C — coaches profesionalizando operación
- Competidores directos con billing activo: Gravl (1M+ usuarios, US-first), Trainerize (anglófono)
- Gap de mercado: **nadie ataca LatAm con español-first + B2B coaching + multi-disciplina**
