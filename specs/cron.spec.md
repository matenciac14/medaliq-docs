# CRON — Spec de cron jobs (notificaciones, billing, cleanup)

<!-- mirror: false -->
<!-- note: crons son server-side. No hay endpoints de usuario -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-07.
> 10 crons DESACTIVADOS en `vercel.json` para ahorrar Neon compute. Código 100% listo.
> Domain doc: `../domains/plataforma.md`
> Activar: copiar bloque `crons` de la sección "Para reactivar" a `vercel.json`.

## TL;DR
- 10 cron jobs (código listo, desactivados en vercel.json para ahorrar Neon compute)
- Auth: `Authorization: Bearer CRON_SECRET`
- Jobs: billing-check, billing-renewal-reminder, checkin-reminder, expire-suggestions, inactive-athlete-reminder, nutrition-alert, payment-overdue, pending-athlete-reminder, session-reminder, streak-risk
- Trampas criticas: billing-check usa POST no GET, todos desactivados en vercel.json
- Mirror mobile: N/A

---

## Contratos de la AI

- [ ] 10 crons desactivados en `vercel.json` — activar cuando haya usuarios reales
- [ ] Schedules documentados en sección "Para reactivar" — copiar a `vercel.json`
- [ ] Auth: todos usan `Authorization: Bearer CRON_SECRET` header
- [x] `billing-check` exporta GET + POST — compatible con Vercel cron (GET) y admin trigger (POST)
- [ ] `expire-suggestions` no tiene schedule definido en ningun lugar
- [ ] `inactive-athlete-reminder` no tiene cooldown — puede notificar al mismo atleta cada dia
- [ ] `payment-overdue` escribe `PaymentAuditLog` con fire-and-forget — errores silenciados

---

## Resumen

| Cron | Schedule (UTC) | Metodo | Target | Accion | DB Write |
|------|---------------|--------|--------|--------|----------|
| `session-reminder` | Lun 12:00 | GET | Atletas con plan activo | Email + Push | No |
| `streak-risk` | Diario 20:00 | GET | Atletas con racha >= 3 en riesgo | Push | No |
| `inactive-athlete-reminder` | Diario 14:00 | GET | Atletas inactivos 3+ dias | Email + Push | No |
| `checkin-reminder` | Dom 23:00 | GET | Atletas con plan sin checkin esta semana | Email + Push | No |
| `payment-overdue` | Diario 14:00 | GET | Coaches con pagos vencidos | Email | Si (AuditLog) |
| `billing-renewal-reminder` | Diario 13:00 | GET | Subs Wompi expiran en 7 dias | Email + Wompi link | No |
| `expire-suggestions` | Sin schedule | GET | CheckInSuggestion PENDING expiradas | — | Si (status→EXPIRED) |
| `billing-check` | Diario 02:00 | POST | Subs expiradas + 3d gracia | — | Si (downgrade tier) |
| `pending-athlete-reminder` | Diario 12:00 | GET | Coaches con atletas sin activar >= 48h | Email + Push | No |
| `nutrition-alert` | Diario 09:00 | GET | Coaches con atletas < 60% kcal 3 dias | Push | No |

---

## Detalle por cron

### session-reminder — Lun 12:00 UTC (07:00 COT)

**Query:** `TrainingPlan.findMany({ status: ACTIVE })` + `PlannedSession.findMany({ dayOfWeek: 1, weekNumber: current })`

**Guards:**
- Salta sesiones tipo `DESCANSO`
- Salta users sin `email`
- Salta planes donde `weekNumber < 1` (plan no iniciado)

**Acciones:** Email `sendSessionReminderEmail` + Push con tipo/duracion/detalle

---

### streak-risk — Diario 20:00 UTC (15:00 COT)

**Query:** `User.findMany({ role: ATHLETE, onboardingCompleted: true, status: ACTIVE })` con sessionLogs + gymSessions de 30 dias

**Guards (TODOS deben cumplirse):**
- >= 3 dias distintos de actividad en ultimos 30 dias
- Entreno ayer
- NO entreno hoy
- Racha consecutiva terminando ayer >= 3 dias
- Tiene pushToken

**Acciones:** Push "Tu racha esta en riesgo" con conteo de dias

---

### inactive-athlete-reminder — Diario 14:00 UTC (09:00 COT)

**Query:** `User.findMany({ role: ATHLETE, onboardingCompleted: true, status: ACTIVE })` con ultimo sessionLog + gymSession

**Threshold:** 3 dias sin actividad (`lastActivity < now - 72h`)

**Guards:**
- Salta atletas sin historial de actividad (`lastActivity === null`)
- Salta atletas activos en ultimos 3 dias

**SIN cooldown** — puede notificar al mismo atleta cada dia si sigue inactivo.

**Acciones:** Push + Email `sendReengagementEmail` con dias de inactividad

---

### checkin-reminder — Dom 23:00 UTC (18:00 COT)

**Query:** `TrainingPlan.findMany({ status: ACTIVE })` + `WeeklyCheckIn.findMany({ recordedAt >= mondayUTC })`

**Guards:**
- Solo atletas con plan ACTIVE
- Salta si ya tiene WeeklyCheckIn esta semana (lunes 00:00 COT a ahora)

**Acciones:** Email `sendCheckinReminderEmail` + Push con deeplink `screen: 'checkin'`

---

### payment-overdue — Diario 14:00 UTC (09:00 COT)

**Query:** `Payment.findMany({ status: PENDING, dueDate: { lt: now } })` con atleta name + coach email/name

**Guards:**
- Retorna early si no hay pagos vencidos
- Salta coaches sin email
- OVERDUE es derivado — `Payment.status` sigue `PENDING`, no se actualiza

**Acciones:**
- Email `sendPaymentOverdueCoachEmail` — un email por coach, lista agregada de pagos
- DB: `PaymentAuditLog.createMany({ action: 'REMINDED' })` — fire-and-forget

**SIN dedup** — el mismo pago puede generar reminders diarios.

---

### billing-renewal-reminder — Diario 13:00 UTC (08:00 COT)

**Query:** `UserSubscription.findMany({ gateway: 'wompi', currentPeriodEnd: [7d..8d from now], tier PRO OR coachTier != STARTER })`

**Guards:**
- Solo gateway `wompi` — MercadoPago auto-renueva
- Ventana de 1 dia (7-8 dias antes) previene duplicados
- Salta users sin email
- Salta STARTER/FREE

**Acciones:**
- Llama `WompiPaymentGateway.createCoachCheckout/createAthleteCheckout` (I/O externo)
- Email `sendBillingRenewalReminderEmail` con link de pago pre-generado

---

### expire-suggestions — Sin schedule definido

**Query (via repo):** `CheckInSuggestion.updateMany({ status: PENDING, expiresAt: { lt: now } }, { status: EXPIRED })`

**Puramente DB cleanup** — sin notificaciones.

---

### billing-check — Diario 02:00 UTC (21:00 COT) — POST

**Query:** `UserSubscription.findMany({ currentPeriodEnd < now - 3d, tier PRO OR coachTier != STARTER })`

**`BILLING_GRACE_DAYS = 3`**

**Transiciones:**
- Coach: `coachTier → STARTER`, `currentPeriodEnd → null`
- Atleta ($transaction): `tier → FREE`, `currentPeriodEnd → null`, `featurePlan/Checkin/Progress → false`

**Idempotente:** subs downgradeadas no matchean la query de nuevo.

**Los atletas del coach NO se suspenden** — solo cambia el tier del coach.

---

### pending-athlete-reminder — Diario 12:00 UTC (07:00 COT)

**Query:** `CoachAthlete.findMany({ status: ACTIVE, createdAt < now-48h, athlete.onboardingCompleted: true, athlete.featurePlan: false })`

**Threshold:** relacion >= 48h Y atleta con `featurePlan = false`

**SIN cooldown** — mismo coach recibe reminder diario por el mismo atleta.

**Acciones:** Email + Push al coach con nombre del atleta

---

### nutrition-alert — Diario 09:00 UTC

**Query (2 fases):**
1. `CoachAthlete.findMany({ status: ACTIVE })` con nutritionPlan + foodLogs de 3 dias
2. Para atletas sin nutritionPlan: `AssignedNutritionPlan` + `getIntensityMapForDateRange`

**Guards (TODOS deben cumplirse):**
- Coach tiene pushToken
- Atleta tiene nutritionPlan o AssignedNutritionPlan
- FoodLogs en >= 3 dias distintos en ultimos 3 dias
- TODOS los dias con kcal < 60% del target (ajustado por intensidad)
- Target > 0

**Acciones:** Push al coach "Nutricion baja" con nombre del atleta

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|--------------------|
| Los crons estan activos | Funcionan | DESACTIVADOS — `vercel.json` no tiene entradas cron (ahorrar Neon compute) |
| `billing-check` solo acepta POST | Falla con Vercel cron | Exporta GET + POST desde 2026-10-07 — compatible con Vercel cron |
| `expire-suggestions` tiene schedule | Configurado | NO tiene schedule en ningun lugar — ni comentario ni vercel.json |
| `inactive-athlete-reminder` no repite | Tiene dedup | SIN cooldown — notifica al mismo atleta cada dia |
| `payment-overdue` marca pagos como OVERDUE | Cambia status | Status sigue PENDING — OVERDUE es derivado, no almacenado |

---

## Para reactivar

Agregar a `vercel.json`:
```json
{
  "crons": [
    { "path": "/api/cron/session-reminder", "schedule": "0 12 * * 1" },
    { "path": "/api/cron/streak-risk", "schedule": "0 20 * * *" },
    { "path": "/api/cron/inactive-athlete-reminder", "schedule": "0 14 * * *" },
    { "path": "/api/cron/checkin-reminder", "schedule": "0 23 * * 0" },
    { "path": "/api/cron/payment-overdue", "schedule": "0 14 * * *" },
    { "path": "/api/cron/billing-renewal-reminder", "schedule": "0 13 * * *" },
    { "path": "/api/cron/expire-suggestions", "schedule": "0 3 * * *" },
    { "path": "/api/cron/pending-athlete-reminder", "schedule": "0 12 * * *" },
    { "path": "/api/cron/nutrition-alert", "schedule": "0 9 * * *" },
    { "path": "/api/cron/billing-check", "schedule": "0 2 * * *" }
  ]
}
```

`billing-check` exporta GET + POST (handler unificado) — compatible con Vercel cron (GET) y admin trigger manual (POST).

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-07 | Reactivación: 10 crons activos en vercel.json. billing-check exporta GET+POST. Spec actualizada. |
| 2026-10-05 | Fix: TL;DR corregido de 5 a 10 crons, eliminados plan-lifecycle y strava-sync inexistentes |
| 2026-09-29 | Spec creada | Extraida del codigo por agentes SDD |
