# NOTIFICATIONS — Notificaciones in-app y push

<!-- mirror: true -->
<!-- mirror-endpoints: GET /api/athlete/notifications ↔ GET /api/mobile/notifications, PATCH /api/athlete/notifications/read-all ↔ PATCH /api/mobile/notifications/read-all -->
<!-- note: POST /api/mobile/push-token es mobile-only (no tiene sentido en web) -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-02.
> Archivos fuente: `src/app/api/mobile/push-token/`, `src/app/api/mobile/notifications/`, `src/app/api/athlete/notifications/`, `src/lib/push/expo_push.ts`, `src/infrastructure/db/notification.ts`
> Specs relacionadas: `cron.spec.md`, `messages.spec.md`

## TL;DR

- 5 endpoints (2 web, 3 mobile)
- Modelos: Notification, User.pushToken
- Dependencias: `sendPushNotification()` (lib/push/expo_push.ts), `createNotification()` (infrastructure/db/notification.ts)
- Trampas criticas: eventos efimeros no crean registro in-app, mensajes tienen push separado del registro, un dispositivo por usuario, tipo es String libre (no enum Prisma)
- Mirror mobile: GET y PATCH son espejo exacto, diverge solo en auth (auth() vs getMobileUser())

---

## Contratos de la AI

- [ ] `sendPushNotification()` es fire-and-forget — NUNCA lanza excepciones. Siempre `.catch(() => {})`. No esperar resultado antes de retornar response
- [ ] `createNotification()` crea registro DB + llama `sendPush` internamente, SALVO que se pase `push: false`. Pasar `push: false` cuando ya se envio push por separado (ej: mensajes)
- [ ] Mensajes: el handler envia `sendPushNotification()` directo y luego llama `createNotification({ push: false })` — dos pasos, no doble push. Parece duplicado pero es intencional (R03)
- [ ] Algunos eventos de negocio solo generan push efimero (sin registro in-app): status change, celebrate-pr, onboarding B2B completado. No crear Notification record en esos casos
- [ ] `User.pushToken` es un campo String? en el modelo User — un token por usuario, ultimo dispositivo gana. No hay tabla separada de dispositivos
- [ ] El tipo de notificacion (`type`) es String libre en DB, no un enum Prisma. No hay validacion a nivel DB. Los tipos reales en uso son: SESION_HOY, CHECKIN_DISPONIBLE, PLAN_ACTUALIZADO, MENSAJE_COACH, AJUSTE_NUTRICIONAL, LOGRO, PROPUESTA_COACH, SUGERENCIA_NUTRICIONAL
- [ ] SUGERENCIA_NUTRICIONAL existe en codigo como tipo pero NO debe aparecer en comentario del schema — es un detalle de implementacion, no un enum declarado
- [ ] Crons se autentican con header `Authorization: Bearer CRON_SECRET` — sin ese header retornan 401. No usan Auth.js ni JWT mobile
- [ ] POST /api/mobile/push-token valida que el token empiece con `"ExponentPushToken["` — tokens invalidos retornan 400
- [ ] GET notifications retorna maximo 30 notificaciones ordenadas por `createdAt DESC` + `unreadCount` separado

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| POST | `/api/mobile/push-token` | `getMobileUser()` | 30/min | Registrar Expo push token |
| GET | `/api/mobile/notifications` | `getMobileUser()` | 120/min | Ultimas 30 notificaciones |
| PATCH | `/api/mobile/notifications/read-all` | `getMobileUser()` | — | Marcar todas como leidas |
| GET | `/api/athlete/notifications` | `auth()` | — | Ultimas 30 notificaciones (web) |
| PATCH | `/api/athlete/notifications/read-all` | `auth()` | — | Marcar todas como leidas (web) |

---

### POST /api/mobile/push-token

**Request:**
```ts
{ token: string }  // debe empezar con "ExponentPushToken["
```

**Response 200:**
```ts
{ ok: true }
```

**Logica:**
1. `getMobileUser(req)` — 401 si no autenticado
2. Rate limit 30/min
3. Validar que `token.startsWith('ExponentPushToken[')` — 400 si no cumple
4. `user.update({ pushToken: token })` — sobreescribe token anterior (ultimo dispositivo gana)
5. Retornar `{ ok: true }`

---

### GET /api/mobile/notifications

**Response 200:**
```ts
{
  notifications: Array<{
    id: string
    type: string
    title: string
    body: string
    read: boolean
    metadata: Record<string, unknown> | null
    createdAt: string  // ISO 8601
  }>
  unreadCount: number
}
```

**Logica:**
1. `getMobileUser(req)` — 401 si no autenticado
2. Rate limit 120/min
3. `notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 30 })`
4. `notification.count({ where: { userId, read: false } })`
5. Retornar `{ notifications, unreadCount }`

---

### PATCH /api/mobile/notifications/read-all

**Response 200:**
```ts
{ ok: true, updated: number }
```

**Logica:**
1. `getMobileUser(req)` — 401 si no autenticado
2. `notification.updateMany({ where: { userId, read: false }, data: { read: true } })`
3. Retornar `{ ok: true, updated: count }`

---

### GET /api/athlete/notifications

Identico a `GET /api/mobile/notifications`. Diverge solo en auth.

**Logica:**
1. `auth()` — 401 si no autenticado, verificar `session.user.id`
2. Misma query que mobile: `findMany` + `count`
3. Retornar `{ notifications, unreadCount }`

---

### PATCH /api/athlete/notifications/read-all

Identico a `PATCH /api/mobile/notifications/read-all`. Diverge solo en auth.

**Logica:**
1. `auth()` — 401 si no autenticado
2. `updateMany({ where: { userId, read: false }, data: { read: true } })`
3. Retornar `{ ok: true, updated: count }`

---

## Infraestructura

### `lib/push/expo_push.ts` — sendPushNotification()

```ts
sendPushNotification(payload: {
  pushToken: string
  title: string
  body: string
  data?: Record<string, unknown>
}): Promise<void>
```

- POST a `https://exp.host/--/api/v2/push/send`
- Timeout: 5 segundos
- Fire-and-forget: `.catch(() => {})` — nunca lanza
- Si `pushToken` es null/undefined, retorna inmediatamente sin llamar Expo

---

### `infrastructure/db/notification.ts` — createNotification()

```ts
createNotification(params: {
  userId: string
  type: string
  title: string
  body: string
  metadata?: Record<string, unknown>
  push?: boolean  // default: true
}): Promise<Notification>
```

**Logica:**
1. `notification.create({ data: { userId, type, title, body, metadata, read: false } })`
2. Si `push !== false`: leer `User.pushToken` del usuario
3. Si tiene pushToken: `sendPushNotification({ pushToken, title, body, data: metadata }).catch(() => {})`
4. Retornar el registro creado

---

## Puntos de disparo

### Via createNotification (registro DB + push)

| Evento | Tipo | Destinatario | Cuando |
|--------|------|-------------|--------|
| Coach modifica sesion de plan | PLAN_ACTUALIZADO | Atleta | Al guardar cambios en sesion planificada |
| Coach asigna rutina gym | PLAN_ACTUALIZADO | Atleta | Al crear `AssignedWorkout` |
| Check-in web ajusta sesiones futuras | PLAN_ACTUALIZADO | Atleta | Al procesar ajuste post-checkin |
| Log sesion (web/mobile) intensidad != planificada, delta >= 200 kcal | SUGERENCIA_NUTRICIONAL | Atleta | Al registrar sesion con diferencia significativa |
| Gym session con PRs nuevos | LOGRO | Atleta | Al detectar nuevo record personal en set log |
| Mensaje enviado (web/mobile) | MENSAJE_COACH | Destinatario | Con `push: false` — push se envia por separado |

### Via sendPushNotification directo (solo push, sin registro in-app)

| Evento | Tipo push | Destinatario | Pantalla sugerida |
|--------|-----------|-------------|-------------------|
| Onboarding B2B completado | (titulo libre) | Coach | `screen: 'coach'` |
| Coach cambia status atleta | `features_updated` | Atleta | — |
| Coach celebra PR del atleta | `pr_celebration` | Atleta | — |
| Log sesion running/gym (B2B) | (titulo libre) | Coach | `screen: 'coach'` |

---

## Crons con notificaciones

| Cron | Schedule (UTC) | Canal | Descripcion |
|------|---------------|-------|-------------|
| checkin-reminder | Dom 23:00 | email + push | Atletas sin check-in de la semana |
| session-reminder | Lun 12:00 | email + push | Atletas con sesion planificada para lunes |
| inactive-athlete-reminder | Diario 14:00 | email + push | Atletas inactivos >= 3 dias |
| streak-risk | Diario 20:00 | solo push | Atletas con racha en riesgo de romperse |
| nutrition-alert | Diario 09:00 | solo push | Coach si atleta tiene <60% adherencia nutricional 3 dias consecutivos |
| pending-athlete-reminder | Diario 12:00 | email + push | Coach si tiene atleta en estado PENDING >= 48h |

**Auth de crons:** Header `Authorization: Bearer CRON_SECRET` — sin el, 401.

---

## Modelos DB involucrados

```prisma
model Notification {
  id        String   @id @default(cuid())
  userId    String
  type      String   // String libre, no enum — ver tipos en uso abajo
  title     String
  body      String
  read      Boolean  @default(false)
  metadata  Json?
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, read])
  @@index([userId, createdAt(sort: Desc)])
}

// En modelo User (campo adicional):
model User {
  // ... campos existentes
  pushToken String?  // Expo push token — un dispositivo por usuario, ultimo gana
}
```

**Tipos en uso** (String, no enum Prisma):
`SESION_HOY` | `CHECKIN_DISPONIBLE` | `PLAN_ACTUALIZADO` | `MENSAJE_COACH` | `AJUSTE_NUTRICIONAL` | `LOGRO` | `PROPUESTA_COACH` | `SUGERENCIA_NUTRICIONAL`

---

## Reglas de negocio (invariantes)

1. **R01 — Un dispositivo por usuario**: `User.pushToken` es un campo unico por usuario. Al registrar nuevo token, sobreescribe el anterior. Multi-dispositivo no soportado.
2. **R02 — Push silencioso**: `sendPushNotification()` nunca lanza. Errores de red, tokens expirados, rate limits de Expo se descartan silenciosamente con `.catch(() => {})`.
3. **R03 — Mensajes: push separado**: Al enviar un mensaje, el handler envia push directo con `sendPushNotification()` y luego llama `createNotification({ push: false })`. Esto evita doble push. Parece redundante pero es intencional.
4. **R04 — Crons con secret**: Todo endpoint de cron valida `Authorization: Bearer CRON_SECRET` header contra `CRON_SECRET` env var. Sin el, 401 inmediato.
5. **R05 — SUGERENCIA_NUTRICIONAL sin declarar**: Este tipo existe en codigo como string literal pero no debe aparecer listado en comentarios del schema prisma. Es un detalle de implementacion.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Eventos de status/PR/onboarding no tienen registro in-app | createNotification() se llama siempre | Algunos eventos solo hacen sendPushNotification() directo — no hay Notification en DB |
| Mensajes crean doble notificacion | push + createNotification = dos pushes | createNotification se llama con `push: false` — solo un push, enviado antes por separado |
| pushToken en tabla separada | Multi-dispositivo posible | pushToken es campo String? en User — un token, un dispositivo |
| type es enum seguro | Prisma valida el tipo | type es String libre — no hay validacion DB, cualquier string es valido |
| Rate limit en PATCH read-all | Sin limite = no hay problema | No tiene rate limit declarado — si se abusa es barato (una query updateMany) |
| createNotification espera push | Fire-and-forget = puede fallar silente | Si pushToken es null, la funcion retorna sin llamar Expo. Si Expo falla, el registro DB ya existe — la notificacion in-app siempre queda |

---

## Paridad web <-> mobile

| Web | Mobile | Divergencias |
|-----|--------|-------------|
| `GET /api/athlete/notifications` | `GET /api/mobile/notifications` | Solo auth: `auth()` vs `getMobileUser()`. Logica identica |
| `PATCH /api/athlete/notifications/read-all` | `PATCH /api/mobile/notifications/read-all` | Solo auth. Logica identica |
| No existe | `POST /api/mobile/push-token` | Web no registra push tokens |

---

## Tests requeridos

- [ ] POST /api/mobile/push-token sin auth → 401
- [ ] POST /api/mobile/push-token token invalido (no empieza con "ExponentPushToken[") → 400
- [ ] POST /api/mobile/push-token valido → guarda en User.pushToken, sobreescribe token anterior
- [ ] POST /api/mobile/push-token: 31 llamadas en un minuto → 429
- [ ] GET /api/mobile/notifications → retorna max 30, ordenadas desc, con unreadCount correcto
- [ ] GET /api/mobile/notifications sin auth → 401
- [ ] PATCH /api/mobile/notifications/read-all → todas quedan read:true, retorna updated correcto
- [ ] PATCH /api/mobile/notifications/read-all sin notificaciones pendientes → updated:0
- [ ] GET /api/athlete/notifications sin sesion → 401
- [ ] PATCH /api/athlete/notifications/read-all sin sesion → 401
- [ ] createNotification con push:true y usuario con pushToken → llama sendPushNotification
- [ ] createNotification con push:false → NO llama sendPushNotification
- [ ] createNotification con usuario sin pushToken → no llama Expo, registro DB existe
- [ ] sendPushNotification con token invalido → no lanza, resuelve silenciosamente
- [ ] Cron checkin-reminder sin Authorization Bearer → 401
- [ ] Cron con secret correcto → ejecuta y retorna ok

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-10-05 | Fix: auth header de crons corregido de `x-cron-secret` a `Authorization: Bearer CRON_SECRET` |
| 2026-10-02 | Spec creada | Extraida de requerimientos por agente SDD |
