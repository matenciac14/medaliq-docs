# AUTH — Autenticacion y sesion

<!-- mirror: true -->
<!-- mirror-endpoints: POST /api/auth/set-role (solo web), POST /api/mobile/auth/login, POST /api/mobile/auth/google -->

> Spec extraida del codigo real. Ultima actualizacion: 2026-10-01.
> Archivos fuente: `src/auth.ts`, `src/middleware.ts`, `src/lib/auth/mobile_auth.ts`, `src/app/api/auth/`, `src/app/api/mobile/auth/`
> Domain doc: `../domains/seguridad.md`

## TL;DR
- 8 endpoints (5 web, 3 mobile)
- Modelos: User, UserSubscription, Account
- Dependencias: session_mappers.ts (fuente de verdad), mobile_auth.ts (jose JWT), middleware.ts
- Trampas criticas: getUserPlan() hardcodea PRO, getMobileUser() datos stale 30d, Google OAuth needsRoleSelection, set-role requiere needsRoleSelection
- Mirror mobile: login (mobile-only), google OAuth (mobile-only), set-role (web-only)

---

## Contratos de la AI

- [ ] DOS sistemas de auth separados: web (Auth.js v5, JWT cookie) y mobile (JWT propio con `jose`, Bearer header). NUNCA mezclar helpers ni tokens
- [ ] `getUserPlan()` SIEMPRE retorna `'PRO'` hoy — billing no activado. No implementar logica de tier real
- [ ] `getMobileUser()` retorna payload JWT decodificado, NO datos frescos de DB. Puede estar stale hasta 30d
- [ ] Google OAuth crea usuario con `needsRoleSelection: true` — features son `DEFAULT_USER_CONFIG` hasta llamar `set-role`. Google OAuth jwt callback crea `UserSubscription` si no existe
- [ ] `set-role` requiere `needsRoleSelection: true` — sin eso retorna 403 (previene escalacion de privilegios)
- [ ] Invalidacion masiva JWT web via `AUTH_MIN_ISSUED_AT` env var (Unix timestamp)
- [ ] `profileComplete` = `!!(identification && phoneWa)` — calculado, no almacenado en DB
- [ ] `activated` = `featurePlan` — NO indica suscripcion paga, solo si tiene el modulo plan habilitado
- [ ] `EMAIL_GATE_ENABLED` hoy esta `false` — no bloquea login sin email verificado. Mobile login usa `!user.emailVerified` (no `in` operator)
- [ ] `/api/mobile/auth/google` requiere header `X-Client: medaliq-mobile` — sin el, 403
- [ ] Endpoints que cambian estado de sesion web DEBEN usar `setFreshJwtCookie()` para actualizar cookie JWT atomicamente en la response. NUNCA depender de `useSession().update()` para navegacion inmediata
- [ ] `MobileTokenPayload` incluye `trialDaysLeft: number | null` — siempre `null` hoy (billing no activado)

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET/POST | `/api/auth/[...nextauth]` | Auth.js interno | Auth.js interno | Handler Auth.js (credentials + Google) |
| POST | `/api/auth/register` | Ninguna | 5/min por IP | Registro email+password |
| POST | `/api/auth/forgot-password` | Ninguna | 3/min por IP | Solicitar reset contrasena |
| POST | `/api/auth/set-password` | JWT reset (1h) en body | Ninguno | Aplicar nueva contrasena |
| POST | `/api/auth/set-role` | `auth()` + `needsRoleSelection` | Ninguno | Asignar rol post-Google OAuth web |
| GET | `/api/auth/verify-email` | Token hex en query | Ninguno | Verificar email (redirect) |
| POST | `/api/mobile/auth/login` | Ninguna | 10/min por email | Login mobile |
| POST | `/api/mobile/auth/refresh` | `getMobileUser()` | 10/min por userId | Refrescar JWT mobile |
| GET | `/api/mobile/auth/me` | `getMobileUser()` | 300/min | Perfil actual desde DB (incluye healthProfile para sport + status check) |
| PATCH | `/api/mobile/auth/me` | `getMobileUser()` | 100/min | Actualizar timezone/locale |
| POST | `/api/mobile/auth/google` | `X-Client` header + idToken | 20/min por email | Google OAuth mobile |
| POST | `/api/mobile/auth/set-role` | `getMobileUser()` | 20/min | Asignar rol post-Google mobile ($transaction: user + CoachProfile + subscription) |

---

### POST /api/auth/register

**Request:**
```ts
{ name: string, email: string, password: string, role?: 'ATHLETE' | 'COACH' }
```

**Logica ($transaction):**
1. Rate limit por IP (5/min)
2. Zod validation, email lowercase+trim
3. Existencia → 409
4. `bcrypt.hash(password, 12)`
5. En `$transaction`: `user.create` + `userSubscription.create(tier:'PRO')` + si COACH: `coachProfile.create(slug)`
6. COACH: `featureCoach:true`, demas `false`, `onboardingCompleted:true`
7. Side effects fire-and-forget: email bienvenida coach + email verificacion

**Coach slug:** `${nombre-kebab-sin-acentos}-${userId.slice(-6)}`

---

### POST /api/auth/forgot-password

**Anti-enumeracion:** Siempre retorna `200 { ok: true }` — no revela si el email existe.

Si existe: firma JWT HS256 con `{ purpose: 'set-password', sub: userId, exp: 1h }` usando `AUTH_SECRET` → email con link.

---

### POST /api/auth/set-password

**Request:** `{ token: string, newPassword: string }`

Verifica JWT con `purpose === 'set-password'`. Si invalido/expirado → 400.
`bcrypt.hash(newPassword, 12)` → `user.updateMany` (atomico, previene TOCTOU race condition — no read-then-write).

---

### GET /api/auth/verify-email

Token hex en `?token=`. Patron **delete-first** (previene TOCTOU race en double-click):
1. `prisma.verificationToken.delete({ where: { token } }).catch(() => null)`
2. Si `null` → redirect con error (token ya usado o invalido)
3. Verificar expiracion del record borrado
4. `user.update({ emailVerified: new Date() })` → redirect `/login?verified=1`

---

### POST /api/mobile/auth/login

**Request:** `{ email: string, password: string }`

**Response 200:**
```ts
{
  token: string  // JWT 30d
  user: { id, email, name, role, onboardingCompleted, activated, isB2B, userPlan, profileComplete, features, sport }
}
```

**Logica:**
1. IP rate limit como primera capa (brute-force protection por IP)
2. Rate limit 10/min por email
3. Lookup user + bcrypt.compare
4. `status !== 'ACTIVE'` → 403 (BLOCKED: mensaje especifico)
5. Derivar `isB2B` desde `CoachAthlete(status:ACTIVE)`
6. Derivar `sport` desde `HealthProfile.sportGoal`: STRENGTH_TRAINING→'STRENGTH', BODY_RECOMPOSITION→'BOTH', otro→'RUNNING'
7. `signMobileToken(payload)` — JWT HS256, 30d

---

### POST /api/mobile/auth/google

**Requiere header `X-Client: medaliq-mobile`** — sin el → 403.

**Request:** `{ idToken: string }`

**Logica:**
1. IP rate limit como primera capa
2. Verificar idToken via `googleapis.com/tokeninfo`
3. Validar `aud` contra `GOOGLE_CLIENT_ID` + iOS + Android client IDs. **Fail-safe:** si `validAudiences` filtrado tiene 0 elementos → 500 (nunca aceptar sin audiencias configuradas)
4. User nuevo → crear con `role:'ATHLETE'`, `needsRoleSelection:true`
5. Status check incondicional: `status !== 'ACTIVE'` → 403 (sin `&& !needsRoleSelection` — bloquea BLOCKED/SUSPENDED siempre)
6. `needsRoleSelection:true` → features `DEFAULT_USER_CONFIG`, `userPlan:'FREE'`
7. Rol asignado → features reales de DB

**Response:** `{ token, needsRoleSelection, user }`

---

### POST /api/mobile/auth/refresh

Sin body. Lee user fresco de DB → firma nuevo JWT 30d.
**Nota:** No refresca `sport` — solo se calcula en login.
**Guard:** Bloquea usuarios con `status` BLOCKED o SUSPENDED → 403.

---

### Campos en JWT y Session

```ts
{
  id: string
  role: 'ATHLETE' | 'COACH' | 'ADMIN'
  status: 'ACTIVE' | 'SUSPENDED' | 'BLOCKED' | 'DELETED'
  onboardingCompleted: boolean
  activated: boolean           // = featurePlan
  isB2B: boolean               // derivado de CoachAthlete, no almacenado
  userPlan: 'FREE' | 'PRO'    // hardcoded 'PRO' hoy
  needsRoleSelection: boolean
  profileComplete: boolean     // !!(identification && phoneWa)
  features: { plan, checkin, nutrition, progress, log, coach, gym }
}
```

---

## setFreshJwtCookie (patron centralizado)

**Archivo:** `src/lib/auth/refresh_jwt_cookie.ts`

Helper reutilizable que lee estado fresco de DB, codifica un JWT nuevo, y lo setea como cookie en la response. Elimina race conditions entre `useSession().update()` y navegacion.

**Usado por:** onboarding/generate, set-role, invite/[code]

**Logica:**
1. `getToken(req)` — obtiene token actual
2. `Promise.all([user, coachAthlete, subscription])` — 3 queries paralelas
3. Construye token con campos frescos (role, status, features, isB2B, userPlan, profileComplete, etc.)
4. `encode({ token, secret, salt: COOKIE_NAME })` → JWT string
5. `response.cookies.set(COOKIE_NAME, jwt, { httpOnly, secure, sameSite:'lax', path:'/', maxAge:30d })`

**Cookie name:** `__Secure-authjs.session-token` (HTTPS) o `authjs.session-token` (HTTP). Derivado de `NEXTAUTH_URL.startsWith('https://')`.

**Regla:** Siempre llamar con `.catch(() => {})` — si falla, el login de Auth.js normal eventualmente actualiza la cookie. No bloquear la response.

---

## Auth.js callbacks

**jwt callback — logica de actualizacion:**
- `AUTH_MIN_ISSUED_AT`: tokens con `iat < threshold` → `exp: 0` (invalida sesion)
- `trigger === 'update'`: re-lee User + CoachAthlete de DB (post-onboarding, post-set-role)
- `userExistsCheckedAt`: verifica existencia max 1 vez cada 5 min

---

## Middleware — Reglas de routing

**Rutas publicas:** `/`, `/login`, `/register`, `/set-password`, `/forgot-password`, `/terminos`, `/privacidad`, `/api/**`, `/join/**`, `/coaches/**`, `/p/**`

**Flujo (en orden de prioridad):**
1. Cookie stale sin sesion → borrar cookies + redirect `/login`
2. No autenticado en ruta privada → redirect `/login`
3. `status !== 'ACTIVE'` → redirect `/login?error=...`
4. `needsRoleSelection` y no en `/select-role` → redirect `/select-role`
5. `!onboardingCompleted` y no en `/onboarding` → redirect `/onboarding`
6. ATHLETE B2B `!activated` y no en `/pending,/log,/nutrition` → redirect `/pending`
7. `/coach` y role !== COACH → redirect `/dashboard`
8. `/admin` y role !== ADMIN → redirect `/dashboard`
9. ADMIN en ruta no-admin → redirect `/admin`
10. COACH en `/dashboard` → redirect `/coach/dashboard`
11. COACH en `/onboarding` → redirect `/coach/dashboard`
12. ATHLETE completado en `/onboarding` → redirect `/dashboard`

**CRITICO:** `/api/**` es publica en middleware — la auth la hace cada handler.

---

## Modelos DB

```
User: id, email, password?, role, status, emailVerified?, needsRoleSelection,
      onboardingCompleted, identification?, phoneWa?, timezone?, locale?,
      featurePlan, featureCheckin, featureNutrition, featureProgress,
      featureLog, featureCoach, featureGym

UserSubscription: userId(unique), tier, coachTier?
CoachProfile: coachId(unique), slug(unique)
CoachAthlete: athleteId, status
VerificationToken: identifier(email), token(unique, hex), expires
HealthProfile: userId(unique), sportGoal?
```

---

## Reglas de negocio

1. Coach al registrar/asignar rol: `featureCoach:true`, demas `false`, `onboardingCompleted:true`
2. Registro en `$transaction` — atomico (user + subscription + coachProfile)
3. `forgot-password` siempre 200 (anti-enumeracion)
4. JWT mobile TTL 30d, renovacion explicita via `/refresh`
5. JWT web TTL 30d, renovacion automatica por Auth.js
6. `isB2B` se calcula en cada sign-in — no almacenado en DB
7. Token reset usa JWT con `AUTH_SECRET` (mismo que Auth.js), proposito `set-password`, TTL 1h
8. `sport` solo se calcula en login (no en refresh)

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|--------------------|
| `getMobileUser()` da datos frescos | Payload parece DB | Es JWT decodificado — stale hasta 30d |
| `set-role` web actualiza sesion | Llamar al endpoint basta | El endpoint usa `setFreshJwtCookie()` — cookie se actualiza en la response. El cliente debe usar `window.location.href` (hard nav), NO `router.push` |
| `/api/**` requiere auth en middleware | Middleware protege | `/api/**` es publica — auth en cada handler |
| `userPlan: 'PRO'` viene de DB | buildMobileTokenPayload lee tier | Hardcodeado `'PRO'`. Ver T06 |
| `activated` = suscripcion paga | `session.user.activated` indica pago | `activated = featurePlan` — feature gate, no pago |
| Reset usa VerificationToken | Mismo modelo que verify-email | Reset usa JWT en body. VerificationToken solo para verify-email |
| Google mobile sin coachAthlete | Lee isB2B de DB | `isB2B:false` hardcoded. Refresh posterior puede corregir |

---

## Paridad web <-> mobile

| Web | Mobile | Divergencia |
|-----|--------|-------------|
| `POST /api/auth/register` | No existe | Registro solo via web o Google OAuth |
| `POST /api/auth/set-role` | `POST /api/mobile/auth/set-role` | Web: `{ok,role}` + setFreshJwtCookie. Mobile: nuevo JWT + user en response |
| `GET /api/auth/[...nextauth]` (OAuth flow) | `POST /api/mobile/auth/google` | Web: redirect OAuth completo. Mobile: idToken directo + `X-Client: medaliq-mobile` header requerido |
| No existe (sesion en cookie) | `POST /api/mobile/auth/login` | Login mobile con email+password retorna JWT 30d |
| No existe (Auth.js renueva auto) | `POST /api/mobile/auth/refresh` | Mobile requiere refresh explicito. Nota: no refresca campo `sport` |
| No existe (sesion via cookie) | `GET /api/mobile/auth/me` | Perfil fresco desde DB. 300/min |
| No existe | `PATCH /api/mobile/auth/me` | Actualizar timezone/locale del usuario. 100/min |
| Auth.js session (cookie HttpOnly) | `getMobileUser()` Bearer JWT | Sistemas completamente separados — nunca mezclar helpers |
| Renovacion automatica Auth.js | Manual via `/refresh` | Mobile necesita refresh explicito |
| `verify-email`, `forgot-password`, `set-password` | No existen en mobile | Solo via web |

**Diferencia sistemica:** Auth.js (web) y jose JWT (mobile) son stacks independientes. `getMobileUser()` retorna payload del JWT decodificado — puede estar stale hasta 30 dias. Datos frescos de DB solo via `GET /mobile/auth/me`.

---

## Tests requeridos

- [ ] Registro email existente → 409
- [ ] Registro COACH crea user+subscription+coachProfile en $transaction
- [ ] Registro COACH: `featureCoach:true`, `featurePlan:false`, `onboardingCompleted:true`
- [ ] Rate limit registro: 6ta desde misma IP → 429
- [ ] Login mobile credenciales incorrectas → 401
- [ ] Login mobile cuenta BLOCKED → 403
- [ ] `forgot-password` email inexistente → 200 `{ok:true}`
- [ ] `set-password` token expirado → 400
- [ ] `verify-email` token valido → redirect + emailVerified seteado + token borrado
- [ ] Google mobile sin `X-Client` header → 403
- [ ] Google mobile nuevo usuario → `needsRoleSelection:true`
- [ ] Middleware: ATHLETE B2B no activado → redirect `/pending`
- [ ] Middleware: cookie stale → borrar cookies + redirect `/login`

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-09-29 | Spec creada | Extraida del codigo por agentes SDD |
| 2026-10-01 | Auth audit: 14 fixes (3 CRITICAL, 4 HIGH, 3 MEDIUM, 4 LOW) | setFreshJwtCookie patron, privilege escalation guard, TOCTOU fix, email gate fix, MobileTokenPayload alignment |
| 2026-10-05 | Fix: forgot-password rate limit corregido de "Ninguno" a "3/min por IP" |
| 2026-10-02 | Paridad web↔mobile completada: login, refresh, me GET/PATCH, diferencia sistemica Auth.js vs jose | Revision de paridad |
| 2026-10-09 | Auditoria pre-prod: IP rate limit en login/google, validAudiences fail-safe, status check incondicional en google, refresh bloquea BLOCKED/SUSPENDED, me query healthProfile+status, set-password updateMany atomico, mobile set-role $transaction | 8 rondas de auditoria |
