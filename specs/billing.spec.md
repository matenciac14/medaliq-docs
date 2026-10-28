# BILLING — Spec del modulo de billing

<!-- mirror: false -->
<!-- note: billing es solo web. Mobile no tiene checkout propio -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Archivos fuente: `src/domain/billing/`, `src/domain/subscription/tier_features.ts`, `src/infrastructure/billing/`, `src/app/api/billing/`, `src/app/api/cron/billing-*`, `src/lib/config/user_config.ts`
> Domain doc: `../domains/pagos.md`

## TL;DR
- 5 endpoints (checkout coach/athlete, billing status, stub simulate, cron billing-check)
- Modelos: UserSubscription, Payment
- Dependencias: WompiPaymentGateway, getTrm(), tier_features.ts, user_config.ts
- Trampas criticas: getUserPlan() hardcodea PRO en beta, Wompi sin suscripciones nativas (manual +30d), downgrade en cron no webhook, TRIAL no usar
- Mirror mobile: NO — billing es web-only

---

## Contratos de la AI

- [ ] `getUserPlan()` en `src/lib/config/user_config.ts` retorna `'PRO'` para todos cuando `BILLING_ENABLED !== 'true'` — esto es INTENCIONAL durante beta. No "arreglarlo".
- [ ] Atletas B2B (con `CoachAthlete.status = ACTIVE`) siempre son PRO — su acceso lo paga el coach. El checkout les devuelve 403, no 402.
- [ ] Wompi NO tiene suscripciones nativas. Cada ciclo es un pago manual. El webhook APPROVED extiende `currentPeriodEnd +30 dias` server-side. El TRM se consulta en el momento del checkout, no en el webhook.
- [ ] El downgrade NO ocurre en el webhook `charge.failed`. Ocurre en el cron `billing-check` despues de 3 dias de gracia (`BILLING_GRACE_DAYS = 3`). Ver webhook: `webhooks.spec.md`.
- [ ] `UserSubscription.tier` usa el enum `SubscriptionTier` de Prisma (`TRIAL | FREE | PRO`). El dominio usa `'FREE' | 'PRO'` como string. `TRIAL` existe en el schema pero no en la logica activa — no usar.
- [ ] El cron `billing-renewal-reminder` llama a `gateway.createCoachCheckout` directamente (saltando `validateCoachUpgrade`) porque necesita renovar el mismo tier — no es un upgrade.
- [ ] Downgrade de coach: `coachTier → STARTER`, `currentPeriodEnd → null`. Los atletas del coach NO se pausan automaticamente — el coach supera su limite y recibe notificacion.
- [ ] Downgrade de atleta: se ejecuta en `$transaction`. Dos writes atomicos: `UserSubscription.tier → FREE` + `User.featurePlan/featureCheckin/featureProgress → false`.
- [ ] `Payment` (tabla de finanzas del coach hacia sus atletas) es un modulo separado del billing de plataforma. No confundir.

---

## Endpoints

| Metodo | Path | Auth | Descripcion |
|--------|------|------|-------------|
| POST | `/api/billing/athlete/checkout` | `auth()` ATHLETE | Crea session de checkout Pro para atleta B2C |
| POST | `/api/billing/coach/checkout` | `auth()` COACH | Crea session de checkout de upgrade de tier |
| GET | `/api/billing/stub/simulate` | Ninguna (dev only) | Simula pago exitoso en stub mode |
| GET | `/api/billing/status` | `auth()` | Devuelve tier actual, coachTier y currentPeriodEnd (poll post-pago) |
| GET | `/api/mobile/billing/prices` | Ninguna (publico) | Devuelve precio Pro en USD + COP con TRM vigente |
| POST | `/api/cron/billing-check` | `Bearer CRON_SECRET` | Downgrade de suscripciones vencidas (cron diario) |
| GET | `/api/cron/billing-renewal-reminder` | `Bearer CRON_SECRET` | Recordatorio de renovacion 7 dias antes (cron diario) |
| GET | `/api/cron/payment-overdue` | `Bearer CRON_SECRET` | Notifica coach por pagos de atletas vencidos (cron diario) |

> Los webhooks de Wompi y el webhook generico estan documentados en `webhooks.spec.md`.

---

### POST /api/billing/athlete/checkout

**Auth:** `auth()` — rol debe ser `ATHLETE`.

**Body (opcional):**
```ts
{ returnTo?: '/upgrade' | '/settings/plan' }
```

**Guards (en orden):**
1. `CoachAthlete.findFirst({ athleteId, status: 'ACTIVE' })` — si existe → `403 { error: "Tienes un entrenador activo..." }`
2. `BillingRepository.findByUserId` — si `sub.tier === 'PRO'` → `409 { error: "Ya tienes Plan Pro activo." }`

**Logica:**
1. Parsea `returnTo` del body. Whitelist: `['/upgrade', '/settings/plan']`. Default: `/upgrade`.
2. Construye `successUrl = ${NEXT_PUBLIC_APP_URL}${returnTo}?billing=success` y `cancelUrl`.
3. Llama `createAthleteCheckout(input, getPaymentGateway())` → `CheckoutOutput`.

**Nota:** `/upgrade` envia checkout sin body (default). `/settings/plan` envia `{ returnTo: '/settings/plan' }` para que el redirect post-pago vuelva a la misma pagina donde el polling esta activo.

**Response 200:**
```ts
{
  checkoutUrl: string  // URL de Wompi o stub
  sessionId: string    // reference del pago
}
```

---

### POST /api/billing/coach/checkout

**Auth:** `auth()` — rol debe ser `COACH`.

**Body:**
```ts
{ targetTier: 'GROWTH' | 'PRO' | 'SCALE' }
```

**Guards:**
- `targetTier` no es string o no esta en `{ STARTER, GROWTH, PRO, SCALE }` → `400`
- `validateCoachUpgrade(current, target)` lanza si es downgrade o mismo tier → `400 { error: mensaje }`

**Logica:**
1. `BillingRepository.findByUserId` → `current = sub?.coachTier ?? 'STARTER'`
2. `createCoachCheckout({ userId, currentTier: current, targetTier, successUrl, cancelUrl }, gateway)`

**Response 200:**
```ts
{
  checkoutUrl: string
  sessionId: string
}
```

---

### GET /api/mobile/billing/prices

**Auth:** Ninguna — publico. Se usa en pantalla de pricing antes del login.

**Response 200:**
```ts
{
  priceUSD: 9.99
  priceCOP: number   // redondeado a multiplo de 100 COP
  trmValue: number   // TRM vigente
  trmDate: string | null  // YYYY-MM-DD, null si es fallback
}
```

---

### GET /api/billing/stub/simulate

**Solo dev.** Bloqueado si `PAYMENT_GATEWAY` existe y no es `'stub'` → `403`.

**Domain validation:** `successUrl` se valida contra el dominio de `NEXT_PUBLIC_APP_URL` — previene open redirect a dominios externos.

**Query params:**
```ts
type:       'coach' | 'athlete'
userId:     string
tier?:      CoachTier  // solo si type=coach
successUrl: string
```

**Logica:** construye un `WebhookEvent charge.success` con `newPeriodEnd = now + 1 mes` → POST a `/api/webhooks/payment` → redirect a `successUrl`.

---

### POST /api/cron/billing-check

**Auth:** `Authorization: Bearer CRON_SECRET`

**Schedule Vercel:** `0 2 * * *` (2am UTC = 9pm COT). **Estado: desactivado** — reactivar cuando billing este live.

**Logica:** `runBillingCheck(repo)` → `findExpired(BILLING_GRACE_DAYS=3, now)` → downgrade por cada suscripcion expirada.

**Response 200:**
```ts
{ ok: true, downgradedCount: number, timestamp: string }
```

---

### GET /api/cron/billing-renewal-reminder

**Auth:** `Authorization: Bearer CRON_SECRET`

**Schedule Vercel:** `0 13 * * *` (1pm UTC = 8am COT). **Estado: desactivado** — reactivar cuando billing este live.

**Logica:**
1. Busca `UserSubscription` con `gateway='wompi'` y `currentPeriodEnd` entre `now+7d` y `now+8d`.
2. Para cada una genera un nuevo payment link (coach: mismo tier; atleta: Pro).
3. Envia `sendBillingRenewalReminderEmail`.

**Nota:** Wompi no renueva automaticamente. Mercado Pago si — este cron lo omite.

---

### GET /api/cron/payment-overdue

**Auth:** `Authorization: Bearer CRON_SECRET`

**Schedule Vercel:** `0 14 * * *` (2pm UTC = 9am COT). **Estado: desactivado** — reactivar cuando billing este live.

**Logica:** `Payment.findMany({ status: 'PENDING', dueDate: { lt: now } })` → agrupa por coach → envia un email por coach con todos los pagos vencidos → `PaymentAuditLog.createMany` por cada pago (fire-and-forget).

**Importante:** Este cron opera sobre `Payment` (finanzas del coach), NO sobre `UserSubscription` (billing de plataforma).

---

## Modelos DB involucrados

```prisma
enum SubscriptionTier {
  TRIAL  // existe en schema, no activo en logica de dominio
  FREE
  PRO
}

enum CoachSubscriptionTier {
  STARTER  // hasta 2 asesorados — $0
  GROWTH   // hasta 10 asesorados — $59/mes
  PRO      // hasta 30 asesorados — $139/mes
  SCALE    // sin limite          — $139/mes + $4/atleta sobre 30
}

model UserSubscription {
  id                 String                @id @default(cuid())
  userId             String                @unique
  tier               SubscriptionTier      @default(TRIAL)
  coachTier          CoachSubscriptionTier @default(STARTER)
  trialEndsAt        DateTime?             // no activo
  currentPeriodEnd   DateTime?             // null = sin periodo activo / ya expired
  externalCustomerId String?               // futuro Stripe
  externalPriceId    String?               // futuro Stripe
  cancelAtPeriodEnd  Boolean               @default(false)
  gateway            String?               // 'wompi' | null
  lastWebhookEventId String?               // idempotencia webhook
  createdAt          DateTime              @default(now())
  updatedAt          DateTime              @updatedAt
}

// Campos de User relevantes para billing
// featurePlan, featureCheckin, featureProgress: Boolean
// Se activan en upgradeAthlete y se apagan en downgradeAthlete (atomico con UserSubscription)
```

---

## Tier model

### Atleta B2C

| Tier | Precio | Features activas |
|------|--------|-----------------|
| FREE | $0 | log, nutrition, gym |
| PRO | $9.99/mes · $79.99/año | log, nutrition, gym, plan, checkin, progress |

B2B (coach activo): siempre PRO sin pagar. Coach activa features via `PATCH /api/coach/athletes/[id]/status`.

### Coach

| Tier | Max atletas | Precio USD/mes | Lógica |
|------|-------------|----------------|--------|
| STARTER | 2 | $0 | Gratis |
| GROWTH | 10 | $59 | Fijo |
| PRO | 30 | $139 | Fijo |
| SCALE | sin límite | $139 + $4/atleta sobre 30 | Base + variable |

Limite se evalua en `POST /api/coach/clients/create` — retorna `402 COACH_LIMIT_REACHED` si `activeCount >= maxAthletes`.

---

## TRM — conversion USD a COP

**Fuente:** `TrmService` + `BancoRepublicaTrmAdapter` (datos.gov.co — Superintendencia Financiera oficial).

**Jerarquia de fallback:**
1. Cache interno TTL 1h → `datos.gov.co/resource/32sa-8pi3.json`
2. Env var `TRM_USD_COP` (override manual)
3. `DEFAULT_TRM = 4200` (siempre loggea como error en produccion)

**Funciones de conversion** (en `billing.types.ts`):
- `usdToCopCents(usd, trm)` → centavos COP para Wompi (`Math.round(usd*trm/100)*100 * 100`)
- `usdToCopDisplay(usd, trm)` → COP redondeado a multiplo de 100 para UI

---

## Arquitectura hexagonal — capas

```
domain/billing/
  billing.types.ts          ← precios, tipos, WebhookEvent, SubscriptionSnapshot
  checkout.use_case.ts      ← validateCoachUpgrade, createCoachCheckout, createAthleteCheckout
  downgrade.use_case.ts     ← isGracePeriodExpired, runBillingCheck

domain/subscription/
  tier_features.ts          ← computeAthleteFeatures(tier), getCoachLimits(CoachTier)

domain/ports/
  billing.repository.ts     ← IBillingRepository
  payment_gateway.ts        ← IPaymentGateway
  trm.provider.ts           ← ITrmProvider

infrastructure/billing/
  billing.repository.ts     ← BillingRepository (Prisma)
  wompi_payment_gateway.ts  ← WompiPaymentGateway
  stub_payment_gateway.ts   ← StubPaymentGateway (dev)
  payment_gateway.factory.ts← getPaymentGateway() lee PAYMENT_GATEWAY env
  trm.ts                    ← TrmService + getTrm() + getTrmWithMeta()
  banco_republica_trm.adapter.ts ← BancoRepublicaTrmAdapter

lib/config/
  user_config.ts            ← getUserPlan() + UserConfig + parseUserConfig()
```

**Gateway factory:** `PAYMENT_GATEWAY=wompi` → `WompiPaymentGateway`. Ausente o `stub` → `StubPaymentGateway`.

---

## Reglas de negocio (invariantes)

1. **Solo upgrades hacia arriba.** `validateCoachUpgrade` lanza si `targetIdx <= currentIdx` en `[STARTER, GROWTH, PRO, SCALE]`. No existe endpoint de downgrade manual — solo el cron lo hace.
2. **Grace period = 3 dias.** Tras `currentPeriodEnd`, el usuario conserva acceso 3 dias. El cron `billing-check` corre a las 2am UTC y degrada los que superaron el grace.
3. **Upgrade de atleta es atomico.** `upgradeAthlete` usa `$transaction`: upsert `UserSubscription` + update `User.featurePlan/featureCheckin/featureProgress`. Si falla uno, falla todo.
4. **Downgrade de atleta es atomico.** `downgradeAthlete` usa `$transaction`: `tier → FREE` + las 3 features → `false`.
5. **Downgrade de coach no pausa atletas.** `downgradeCoach` solo actualiza `coachTier → STARTER` y `currentPeriodEnd → null`. El coach supera su limite del nuevo tier — la UI/cron notifica.
6. **Idempotencia webhook.** Antes de cualquier write se chequea `lastWebhookEventId`. Si coincide → `{ received: true, duplicate: true }` sin escribir.
7. **B2B siempre PRO.** `getUserPlan()` retorna `'PRO'` si `isB2B = true`, sin importar `subscriptionTier`.
8. **Beta flag.** `getUserPlan()` retorna `'PRO'` para todos si `BILLING_ENABLED !== 'true'`. Al activar Wompi y conectar billing real → setear `BILLING_ENABLED=true`.
9. **`newPeriodEnd` lo calcula el servidor.** Wompi no envia fecha de renovacion. El webhook de `charge.success` calcula `now + 30 dias`. No confiar en datos del payload para calcular fechas.
10. **Precios son la fuente canonica del dominio.** `COACH_TIER_PRICES_USD` y `ATHLETE_PRO_PRICE_USD` viven en `billing.types.ts`. Nunca hardcodear precios en la infra o en rutas.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| `getUserPlan` lee la DB | Funcion de dominio query | Lee `process.env.BILLING_ENABLED` — si es false retorna PRO para todos sin tocar DB |
| `SubscriptionTier.TRIAL` esta activo | El schema lo define | No tiene logica activa en el codigo. `getUserPlan` no lo maneja. No usar hasta decision explicita |
| Downgrade al recibir `charge.failed` | El webhook maneja todo | `charge.failed` no escribe nada. Solo el cron hace downgrade, con 3 dias de gracia |
| `billing-renewal-reminder` valida upgrade | Usa `createCoachCheckout` del use case | Llama al gateway DIRECTO (sin use case) para evitar que `validateCoachUpgrade` rechace `currentTier === targetTier` en renovaciones |
| `Payment` es billing de plataforma | Misma tabla para todo | `Payment` es finanzas del coach hacia sus atletas (cobros de asesoria). `UserSubscription` es el billing de plataforma (SaaS). Son modulos distintos |
| El stub simula pago haciendo redirect | Es una UI | Es un GET que hace un POST interno a `/api/webhooks/payment` y luego redirige. Requiere que el servidor este corriendo |
| `UpgradeClient` res.json() directo | Parece seguro despues de fetch | Debe verificar `res.ok` ANTES de `res.json()` — un 4xx/5xx causa crash en la UI |
| `CoachPlanClient` res.json() directo | Idem | Idem — verificar `res.ok` primero |
| `AthletePlanClient` billing poll | Parece que siempre retorna JSON | Debe tener guard `res.ok` en el polling de `/api/billing/status` |
| `upgradeCoach` en `billing.repository.ts` acepta `gateway` | La interfaz `IBillingRepository` no lo tiene | `upgradeCoach` y `upgradeAthlete` tienen un parametro opcional `gateway?: string` que NO esta en la interfaz del port. Deuda tecnica menor |
| TRM viene de Wompi | El gateway sabe el tipo de cambio | TRM se obtiene de `datos.gov.co` via `TrmService`. Wompi recibe los centavos ya calculados — no conoce el TRM |

---

## Paridad web <-> mobile

| Funcionalidad | Web | Mobile | Diferencia |
|--------------|-----|--------|-----------|
| Ver precio Pro | `/settings/plan` (UI, requiere auth) | `GET /api/mobile/billing/prices` (sin auth — publico) | Mobile es publico, web es autenticado |
| Iniciar checkout atleta | `POST /api/billing/athlete/checkout` → redirect Wompi | No implementado — se usa la URL web en in-app browser | Mobile abre `checkoutUrl` en in-app browser (WebView/SafariVC) |
| Flujo post-pago mobile | Redirect `successUrl` → `getDashboardData` | Polling a `GET /api/mobile/auth/me` o `/refresh` hasta que features se actualicen | Web: la cookie Auth.js se renueva sola. Mobile: el JWT no cambia hasta refresh explicito |
| Upgrade coach | `POST /api/billing/coach/checkout` | No implementado | Solo web |
| Estado de suscripcion | Sesion Auth.js (`getUserPlan`) — cookie fresca | JWT mobile — features del token al momento del ultimo login/refresh, potencialmente stale | Sin refresh, el atleta que paga no ve el cambio hasta el proximo login |
| Suscripcion activa | `GET /api/billing/status` — tier + currentPeriodEnd | No existe | Solo web |
| Downgrade (cron) | Cron `billing-check` — server-side | Idem — afecta al JWT en el proximo refresh | Transparente para mobile |

**Flujo mobile completo post-pago:**
1. Mobile llama `POST /api/billing/athlete/checkout` (mismo endpoint web, Auth mobile Bearer)
2. Abre `checkoutUrl` en in-app browser
3. Wompi procesa → `successUrl` → webhook `charge.success` activa features en DB
4. Mobile hace polling a `GET /api/mobile/auth/me` o `POST /api/mobile/auth/refresh` hasta que `features.plan === true`
5. Guarda el nuevo token y navega a dashboard

**Diferencia critica:** el JWT mobile se firma al hacer login/refresh. Si el usuario paga y no hace refresh, el token refleja el tier anterior. Al activar billing real → agregar endpoint `POST /api/mobile/auth/refresh` o automatizar polling post-pago en el cliente.

---

## Env vars requeridas

```
BILLING_ENABLED           — 'true' para activar gates reales (beta: ausente = todos PRO)
PAYMENT_GATEWAY           — 'wompi' (produccion) | 'stub' (dev, default)
WOMPI_PRIVATE_KEY         — crear payment links
WOMPI_INTEGRITY_SECRET    — verificar checksum de webhooks
WOMPI_SANDBOX             — 'true' para sandbox.wompi.co
TRM_USD_COP               — override manual del TRM (emergencia / dev local)
CRON_SECRET               — autenticacion de rutas cron
NEXT_PUBLIC_APP_URL       — base URL para successUrl/cancelUrl
```

---

## Tests existentes

Los tests corren con Vitest. Domain en `src/domain/billing/`, infra en `src/infrastructure/billing/`, guards en `src/lib/guards/`.

| Archivo | Cobertura |
|---------|-----------|
| `billing.types.test.ts` | `usdToCopDisplay` (redondeo, TRM bajo/alto, 0) · `usdToCopCents` (multiplo 10000, 0) |
| `checkout.use_case.test.ts` | `validateCoachUpgrade` (upgrades validos, downgrade, mismo tier) · `nextCoachTier` (todos los tiers, SCALE→null) · `createCoachCheckout` (gateway llamado, error propagado sin llamar gateway) · `createAthleteCheckout` (gateway llamado con params correctos) |
| `downgrade.use_case.test.ts` | `isGracePeriodExpired` (dentro gracia, limite exacto, un segundo pasado, mucho despues, graceDays personalizado, constante=3) · `runBillingCheck` (0 expiradas, 1 coach, 1 atleta, multiples, pasa graceDays a findExpired) |
| `billing_activation.test.ts` | `resolveReturnTo` whitelist (5 tests) · `successUrl` dinamico (2) · `StubPaymentGateway` (3) · SHA256 integrity (2) |
| `payment_gateway.factory.test.ts` | Factory: wompi→Wompi, stub→Stub, undefined→Stub, unknown→Stub, no singleton |
| `wompi_webhook.test.ts` | `parseWebhookEvent`: APPROVED atleta (+30d), APPROVED coach (coachTargetTier), DECLINED/ERROR/VOIDED→charge.failed, checksum invalido, payload sin transaction, metadata incompleta, secret no configurado |
| `trm.test.ts` | `TrmService.getWithMeta` (API ok, fallback env, fallback default, env invalido, negativo, cache) · `TrmService.get` (numero, default) · `getTrmSync` (env valido, undefined, invalido, negativo) |
| `tier_features.test.ts` | `computeAthleteFeatures` PRO/FREE · `getCoachLimits` todos los tiers · enforcement pattern · `configToAthleteFeatures` (all on, coach always false, all off) |
| `feature_gate.test.ts` | `requireFeature`: activa→null, inactiva→402, 402 incluye `/upgrade`, undefined→402, todas las keys |

---

## Tests requeridos al modificar

- [ ] `getUserPlan` con `BILLING_ENABLED=false` → siempre PRO
- [ ] `getUserPlan` con `BILLING_ENABLED=true` + `isB2B=true` → PRO
- [ ] `getUserPlan` con `BILLING_ENABLED=true` + `subscriptionTier='PRO'` → PRO
- [ ] `getUserPlan` con `BILLING_ENABLED=true` + `subscriptionTier=null` → FREE
- [ ] Checkout atleta: B2B activo → 403
- [ ] Checkout atleta: ya PRO → 409
- [ ] Checkout coach: downgrade → 400
- [ ] Checkout coach: mismo tier → 400
- [ ] Cron billing-check: CRON_SECRET invalido → 401
- [ ] Cron billing-check: 0 expiradas → `{ downgradedCount: 0 }`
- [ ] `upgradeAthlete`: fallo en User.update revierte UserSubscription (atomicidad)
- [ ] `downgradeAthlete`: fallo en User.update revierte UserSubscription (atomicidad)

---

## BILLING-ACT — Activacion de billing real (Wompi sandbox → produccion)

> **Estado**: Implementado. UI conectada al checkout Wompi. Pendiente: E2E test sandbox, activar crons, deploy produccion.
> **Fecha**: 2026-10-02

### Contexto

El billing esta implementado end-to-end (gateway, webhook, repository, crons) pero desconectado en la UI.
`getUserPlan()` hardcodea PRO para todos (`BILLING_ENABLED !== 'true'`).
La pagina `/upgrade` usa `mailto:` en vez del checkout Wompi.
Hay codigo muerto y referencias a "trial" (eliminado del modelo de negocio).

### Problemas detectados

| # | Problema | Archivo | Severidad |
|---|---------|---------|-----------|
| 1 | `/upgrade` boton Pro es `mailto:` — no llama al checkout Wompi | `src/app/upgrade/page.tsx` | **P0** |
| 2 | `DowngradeButton` llama a `/api/athlete/upgrade/downgrade` — **endpoint no existe** | `src/app/upgrade/_components/DowngradeButton.tsx` | **P0** |
| 3 | `successUrl` del checkout atleta redirige a `/dashboard?billing=success` pero el polling post-pago esta en `AthletePlanClient` (`/settings/plan`) — el usuario nunca ve la confirmacion | `src/app/api/billing/athlete/checkout/route.ts` | **P1** |
| 4 | `TrialCountdownBanner` referencia "trial" — eliminado del modelo de negocio | `src/app/(athlete)/dashboard/_components/TrialCountdownBanner.tsx` | **P2** |
| 5 | `feature_gate.ts` URL hardcodeada `https://medaliq.com/upgrade` — deberia ser relativa | `src/lib/guards/feature_gate.ts` | **P2** |
| 6 | `PaywallCard` y multiples CTAs apuntan a `/upgrade` (el placeholder con mailto) | `src/app/_components/PaywallCard.tsx`, progress, gym/session, gym/history | **P1** |

### Cambios requeridos

#### CAMBIO 1 — Conectar `/upgrade` al checkout Wompi (P0)

**Archivo**: `src/app/upgrade/page.tsx`

**Antes**: Server component con `mailto:` hardcodeado y precio en USD.

**Despues**: Convertir a page server + client component.
- Server: obtener `tier`, `priceCOP`, `priceUSD`, `trmDate` (igual que `/settings/plan/page.tsx`)
- Si ya es PRO → redirect a `/dashboard`
- Si es B2B activo → redirect a `/dashboard`
- Client: boton "Activar Pro" llama `POST /api/billing/athlete/checkout` → `window.location.href = checkoutUrl`
- Mostrar precio en COP (fuente: TRM real) + equivalente USD
- Toast + polling post-pago con `?billing=success` en query params

**Endpoint existente usado**: `POST /api/billing/athlete/checkout` (sin cambios).

**`successUrl` corregido**: `${baseUrl}/upgrade?billing=success` (ver CAMBIO 3).

#### CAMBIO 2 — Eliminar DowngradeButton y endpoint muerto (P0)

**Archivo**: `src/app/upgrade/_components/DowngradeButton.tsx`

**Accion**: Eliminar `DowngradeButton` component. Reemplazar con boton "Continuar gratis" que hace `router.push('/dashboard')` — sin llamar a ningun endpoint.

**Justificacion**: No existe `/api/athlete/upgrade/downgrade`. El downgrade real ocurre via cron `billing-check` tras 3 dias de gracia. En `/upgrade`, "Continuar gratis" simplemente cierra la pagina — el usuario ya es FREE por defecto.

#### CAMBIO 3 — successUrl dinamico con `returnTo` (P1)

**Archivo**: `src/app/api/billing/athlete/checkout/route.ts`

**Antes**:
```ts
const successUrl = `${baseUrl}/dashboard?billing=success`
const cancelUrl  = `${baseUrl}/dashboard?billing=cancelled`
```

**Despues**:
```ts
const body = await req.json().catch(() => ({})) as { returnTo?: string }
const allowedReturns = ['/upgrade', '/settings/plan']
const returnTo = allowedReturns.includes(body.returnTo ?? '') ? body.returnTo! : '/upgrade'
const successUrl = `${baseUrl}${returnTo}?billing=success`
const cancelUrl  = `${baseUrl}${returnTo}?billing=cancelled`
```

**Justificacion**: Cada pagina que inicia checkout envia `returnTo` para que el redirect post-pago vuelva a la misma pagina donde el polling esta activo. Whitelist previene open redirect. Default `/upgrade` si no se envia body.

#### CAMBIO 4 — Eliminar TrialCountdownBanner (P2)

**Archivo**: `src/app/(athlete)/dashboard/_components/TrialCountdownBanner.tsx`

**Accion**: Eliminar componente. Eliminar import/uso en el dashboard.

**Justificacion**: Trial fue eliminado del modelo de negocio (2026-07-03). El banner referencia "trial" y confunde al usuario. Free es permanente, no temporal.

#### CAMBIO 5 — feature_gate URL relativa (P2)

**Archivo**: `src/lib/guards/feature_gate.ts`

**Antes**: `upgrade: 'https://medaliq.com/upgrade'`
**Despues**: `upgrade: '/upgrade'`

#### CAMBIO 6 — PaywallCard y CTAs ya apuntan a /upgrade (OK)

**Accion**: Sin cambios. `PaywallCard` y los CTAs en progress/gym ya apuntan a `/upgrade`. Una vez CAMBIO 1 conecte `/upgrade` al checkout Wompi, todos estos CTAs funcionaran automaticamente.

### Checklist de activacion (orden)

1. [x] CAMBIO 1 — Conectar `/upgrade` al checkout Wompi (2026-10-02)
2. [x] CAMBIO 2 — Eliminar DowngradeButton muerto (2026-10-02)
3. [x] CAMBIO 3 — Corregir successUrl → `/upgrade?billing=success` (2026-10-02)
4. [x] CAMBIO 4 — Eliminar TrialCountdownBanner (2026-10-02)
5. [x] CAMBIO 5 — feature_gate URL relativa (2026-10-02)
6. [ ] E2E test: tunnel + Wompi sandbox + tarjeta test `4242 4242 4242 4242`
7. [ ] Setear `BILLING_ENABLED=true` en `.env.local` para pruebas
8. [ ] Activar crons: billing-check, billing-renewal-reminder, payment-overdue
9. [ ] Deploy a produccion con llaves `prod_` y `WOMPI_SANDBOX=false`

### Env vars para activacion

```
# Ya configuradas en .env.local:
PAYMENT_GATEWAY=wompi
WOMPI_PUBLIC_KEY=pub_test_...
WOMPI_PRIVATE_KEY=prv_test_...
WOMPI_INTEGRITY_SECRET=test_integrity_...
WOMPI_SANDBOX=true

# Pendiente de activar:
BILLING_ENABLED=true          # Switch: todos dejan de ser PRO gratis
NEXT_PUBLIC_APP_URL=http://localhost:3000  # Para successUrl/cancelUrl en dev
```

### Tests requeridos para esta activacion

- [ ] `/upgrade` FREE → muestra boton "Activar Pro" con precio COP
- [ ] `/upgrade` PRO → redirect a `/dashboard`
- [ ] `/upgrade` B2B activo → redirect a `/dashboard`
- [ ] Click "Activar Pro" → `POST /api/billing/athlete/checkout` → redirect a Wompi
- [ ] Post-pago: Wompi redirige a `/upgrade?billing=success` → polling hasta tier=PRO
- [ ] `?billing=cancelled` → toast de error
- [ ] "Continuar gratis" → navega a `/dashboard` (sin llamar endpoint)
- [ ] `PaywallCard` CTA → navega a `/upgrade` → checkout funciona
- [ ] `feature_gate` retorna `upgrade: '/upgrade'` (relativa)

---

## Pendientes criticos (roadmap)

| Item | Prioridad | Estado |
|------|-----------|--------|
| **BILLING-ACT: Conectar UI al checkout Wompi** | **P0** | **Implementado 2026-10-02** |
| End-to-end test con Wompi sandbox | P0 | Pendiente (requiere BILLING-ACT primero) |
| Snapshot de atletas activos para billing (definicion canonica) | P1 | Pendiente |
| Notificacion pre-billing al coach 3 dias antes del cobro | P1 | Pendiente |
| Activar crons billing-check, billing-renewal-reminder, payment-overdue | P2 | Desactivados 2026-09-25 |
| Free trial 7 dias sin tarjeta (trialEndsAt) | P3 | Futuro |
| Refresh token mobile tras pago | P1 | No implementado |
| `gateway` en interfaz IBillingRepository (upgradeCoach/upgradeAthlete) | P3 | Deuda tecnica |

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo real |
| 2026-10-02 | Paridad web↔mobile completada: prices sin auth, flujo mobile post-pago, polling refresh | Revision de paridad |
| 2026-10-02 | BILLING-ACT: spec de activacion — 6 problemas detectados, 5 cambios requeridos, checklist de activacion | Auditoria pre-Wompi |
| 2026-10-02 | BILLING-ACT fix: `/pricing` → `/upgrade` (link roto en MobileCardsSection), `returnTo` dinamico en checkout (whitelist), 38 tests nuevos | Post-auditoria |
| 2026-10-02 | Doc sync: estado BILLING-ACT→implementado, CAMBIO 3 refleja `returnTo` real, tests existentes actualizados (9 archivos) | Verificacion documental |
| 2026-10-09 | Auditoria pre-prod: stub simulate domain validation en successUrl, UpgradeClient/CoachPlanClient res.ok antes de res.json en checkout, AthletePlanClient billing poll res.ok guard | 8 rondas de auditoria |
