# MESSAGES — Spec de mensajeria coach-atleta

<!-- mirror: true -->
<!-- mirror-endpoints: GET/POST /api/messages ↔ /api/mobile/messages, POST /api/messages/read ↔ /api/mobile/messages/read -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-09-29.
> Archivos fuente: `src/app/api/messages/`, `src/app/api/mobile/messages/`

## TL;DR
- 6 endpoints (3 web, 3 mobile)
- Modelos: Message (CoachAthlete relation required)
- Dependencias: createNotification()
- Trampas criticas: /read response diverge (web:{marked} vs mobile:{ok}), web paginacion cursor vs mobile ultimos 100
- Mirror mobile: messages GET/POST, messages/read (response shapes diferentes)

---

## Contratos de la AI

- [ ] Mensajeria es SOLO entre coach y atleta con relacion CoachAthlete — no entre desconocidos
- [ ] Web y mobile POST exigen `status: ACTIVE` en la relacion CoachAthlete — un atleta PAUSED no puede enviar mensajes
- [ ] El response shape de `/read` diverge: web retorna `{ marked: number }`, mobile retorna `{ ok: true }`
- [ ] Web tiene paginacion por cursor; mobile retorna los ultimos 100 sin paginacion
- [ ] `createNotification` siempre usa tipo `'MENSAJE_COACH'` incluso cuando el sender es el atleta

---

## Endpoints

| Metodo | Path | Auth | Rate limit |
|--------|------|------|------------|
| GET | `/api/messages?with=&take=&cursor=` | `auth()` | 300/min |
| POST | `/api/messages` | `auth()` | 100/min |
| PATCH | `/api/messages/read` | `auth()` | ninguno |
| GET | `/api/messages/unread-count` | `auth()` | ninguno |
| GET | `/api/messages/me` | `auth()` | ninguno |
| GET | `/api/mobile/messages?with=` | `getMobileUser()` | 300/min |
| POST | `/api/mobile/messages` | `getMobileUser()` | 100/min |
| PATCH | `/api/mobile/messages/read` | `getMobileUser()` | 100/min |
| GET | `/api/mobile/messages/unread-count` | `getMobileUser()` | 300/min |
| GET | `/api/mobile/messages/me` | `getMobileUser()` | 300/min |

---

## GET /api/messages — Listar conversacion

**Query params:**
- `with` (requerido) — userId del interlocutor
- `take` (opcional, default 50, max 100)
- `cursor` (opcional, cuid) — paginacion por cursor

**Prisma:**
```ts
message.findMany({
  where: { OR: [
    { fromId: me, toId: with },
    { fromId: with, toId: me }
  ]},
  orderBy: { createdAt: 'asc' },
  // + cursor pagination
  select: { id, fromId, toId, content, readAt, createdAt }
})
```

**Regla:** NO verifica relacion CoachAthlete en GET — cualquier usuario autenticado puede leer mensajes donde es parte.

**Response:** `{ messages: Message[] }`

---

## GET /api/mobile/messages — Listar conversacion (mobile)

**Diferencias con web:**
- SI verifica relacion `CoachAthlete` (pero sin filtro `status: ACTIVE` — cualquier status pasa)
- Sin paginacion — `take: 100` hardcoded
- Sin custom `select` — retorna objeto completo

---

## POST /api/messages — Enviar mensaje

**Body:** `{ toId: string, content: string }`

**Validacion:** `toId` presente, `content` no vacio, `fromId !== toId`

**Queries paralelas:**
1. `user.findUnique({ id: toId })` — existencia + pushToken
2. `coachAthlete.findFirst({ status: ACTIVE, OR: [coach=me/athlete=them, vice versa] })` — gate

**Regla:** Requiere relacion `ACTIVE`. Sin relacion activa → `403`.

**Write:** `message.create({ fromId: me, toId, content: content.trim() })`

**Side effects (fire-and-forget):**
- `sendPushNotification(pushToken, "Mensaje de {name}", content, { screen: 'messages' })`
- `createNotification(toId, 'MENSAJE_COACH', ...)` — siempre tipo `MENSAJE_COACH`

**Response:** `201 { message: Message }`

---

## POST /api/mobile/messages — Enviar mensaje (mobile)

**Diferencias con web:**
- Auth: `getMobileUser()` en vez de `auth()`
- Gate: verifica `CoachAthlete` con `status: ACTIVE` (igual que web)
- Sender name fallback: `mobile.name ?? 'Tu atleta'` (web usa `'Tu coach'`)

---

## PATCH /api/messages/read — Marcar como leidos

**Body:** `{ fromId: string }`

**Prisma:** `message.updateMany({ where: { fromId, toId: me, readAt: null }, data: { readAt: new Date() } })`

**Response web:** `{ marked: number }` (count de rows actualizados)
**Response mobile:** `{ ok: true }` (NO retorna count)

---

## GET /api/messages/unread-count — Badge de no leidos

**Prisma:** `message.count({ where: { toId: me, readAt: null } })`

**Response:** `{ count: number }`

---

## GET /api/messages/me — Bootstrap de chat

**Prisma:** `coachAthlete.findFirst({ athleteId: me, status: ACTIVE })` → select coach id + name

**Response:** `{ id: string, coachId: string | null, coachName: string | null }`

**Divergencia mobile:** NO filtra por `status: ACTIVE` — retorna primer coach sin importar status.

---

## Modelo DB

```prisma
model Message {
  id        String    @id @default(cuid())
  fromId    String?   // nullable — SetNull on user deletion
  toId      String?   // nullable — SetNull on user deletion
  content   String
  readAt    DateTime? // null = no leido
  createdAt DateTime  @default(now())

  @@index([fromId, toId, createdAt])  // fetch de conversacion
  @@index([toId, readAt])             // count no leidos + mark-read
}
```

---

## Reglas de negocio

1. **Solo coach-atleta:** mensajeria restringida a pares con registro `CoachAthlete`. Desconocidos no pueden mensajear.
2. **Bidireccional:** el `OR` en la query permite que ambos lados inicien conversacion.
3. **Read receipt batch:** `readAt` se marca por lote (todos los mensajes de un sender), no por mensaje individual.
4. **Soft delete safe:** `fromId`/`toId` son nullable con `SetNull` — mensajes sobreviven eliminacion de usuario.

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|--------------------|
| Web y mobile tienen misma logica POST | Son iguales | Ambos exigen `status: ACTIVE` en la relacion CoachAthlete |
| `/read` retorna lo mismo | Son iguales | Web: `{ marked: number }`, mobile: `{ ok: true }` |
| `MENSAJE_COACH` es el tipo correcto | El atleta manda como atleta | Siempre se usa `MENSAJE_COACH` — incluso cuando el sender es el atleta |
| Mobile tiene paginacion | Tiene | Mobile: `take: 100` flat. Web: cursor pagination con `take` configurable |
| GET web no verifica relacion | Inseguro | Correcto — solo retorna mensajes donde el user es `fromId` o `toId` |

---

## Paridad web <-> mobile

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `GET /api/messages` | `GET /api/mobile/messages` | Web: cursor+take. Mobile: take:100 flat. Mobile verifica relacion, web no |
| `POST /api/messages` | `POST /api/mobile/messages` | Ambos: status ACTIVE. Sender name fallback diferente |
| `PATCH /api/messages/read` | `PATCH /api/mobile/messages/read` | Response shape diferente |
| `GET /api/messages/unread-count` | `GET /api/mobile/messages/unread-count` | Identicos |
| `GET /api/messages/me` | `GET /api/mobile/messages/me` | Web: status ACTIVE. Mobile: cualquier status |

---

## Tests requeridos

- [ ] POST con relacion ACTIVE → mensaje creado + push + notificacion
- [ ] POST sin relacion → 403
- [ ] POST con relacion PAUSED (web) → 403
- [ ] POST con relacion PAUSED (mobile) → 403 (corregido)
- [ ] GET con cursor → paginacion correcta
- [ ] PATCH /read → readAt actualizado en todos los mensajes del sender
- [ ] unread-count → solo cuenta mensajes donde toId = me AND readAt = null

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo por agentes SDD |
| 2026-10-03 | Fix BUG mobile POST: agregado filtro `status: ACTIVE` en CoachAthlete. Spec actualizada para reflejar paridad web/mobile | Auditoria SDD |
