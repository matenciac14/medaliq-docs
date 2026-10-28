# Domain: Seguridad
# Reglas de seguridad de la plataforma. Leer antes de tocar auth, endpoints, DB o mobile.
> Spec de implementacion: `../specs/auth.spec.md` — contratos, endpoints, trampas.

## Principio base — multi-tenant estricto

**Regla no negociable:** toda query a la DB filtra por `userId` o `athleteId`. Nunca confiar en IDs del body del request — siempre leer de la sesión autenticada.

```ts
// ✅ Correcto
const plan = await prisma.trainingPlan.findFirst({
  where: { userId: session.user.id, status: 'ACTIVE' }
})

// ❌ Incorrecto — nunca
const plan = await prisma.trainingPlan.findFirst({
  where: { userId: body.userId }  // body puede ser manipulado
})
```

---

## Autenticación — dos sistemas paralelos e incompatibles

| Canal | Sistema | Token | Header de identificación |
|-------|---------|-------|--------------------------|
| Web | Auth.js v5 (JWT) | Cookie `next-auth.session-token` | Ninguno — cookie automática |
| Mobile | `jose` JWT propio | Bearer token en `Authorization` | `X-Client: medaliq-mobile` (obligatorio) |

**NO mezclar.** Los endpoints `/api/mobile/*` requieren `X-Client: medaliq-mobile` + JWT propio. Los endpoints `/api/*` web usan Auth.js. Si un endpoint web recibe el header mobile, debe rechazarlo (y viceversa).

### JWT mobile — reglas

- Firmado con `AUTH_SECRET` (fallback: `NEXTAUTH_SECRET`) — no existe variable separada `MOBILE_JWT_SECRET`
- Payload: `{ id, email, name, role, onboardingCompleted, userPlan, features }`
- El JWT queda **stale** cuando el coach activa features del atleta — auto-refresh implementado: push notification `features_updated` → `refreshUser()` en `_layout.tsx` → `POST /api/mobile/auth/refresh` → nuevo JWT sin interrumpir al atleta.
- En 401 (JWT expirado): `clearToken()` + `setUser(null)` → pantalla de login (no retry automático)

---

## Ownership — validación por actor

Cada endpoint valida que el actor autenticado tenga permiso sobre el recurso que accede:

| Actor | Validación obligatoria |
|-------|----------------------|
| Atleta | `where: { userId: session.user.id }` — nunca exponer datos de otro atleta |
| Coach | `CoachAthlete.findFirst({ coachId, athleteId, status: 'ACTIVE' })` antes de cualquier acción sobre un atleta |
| Admin | Sin restricción de datos — pero no puede actuar como coach ni registrar sesiones |

**Regla de mensajes (SEC-01, corregido):** `POST /api/messages` y `POST /api/mobile/messages` validan la relación `CoachAthlete` antes de permitir el mensaje. Sin relación activa → 403.

---

## Rate limiting

Implementado con Upstash Redis (`rateLimitAsync`):

```ts
const { allowed } = await rateLimitAsync(`mobile-${mobile.id}:endpoint-name`, {
  limit: 300,   // GET: 300 req/min | POST: 100 req/min
  windowMs: 60_000
})
if (!allowed) return NextResponse.json({ error: 'Demasiadas solicitudes.' }, { status: 429 })
```

**Endpoints protegidos con rate limiting:**
- Web: `/api/auth/register`, `/api/athlete/onboarding/generate`
- Mobile: todos los endpoints `/api/mobile/*` (GET 300/min, POST 100/min por usuario)
- Login: 10 intentos/min por cuenta (brute-force)
- Auth sensibles: `forgot-password`, `verify-email`, `set-password`, `set-role` — 5-10 req/min por IP

---

## Validación de inputs

Todos los endpoints validan con **Zod** antes de procesar:

```ts
const { data, error } = parseBody(req, MySchema)
if (error) return error  // 400 automático
```

Schemas centralizados en `src/lib/validation/index.ts`.

**Reglas:**
- Nunca confiar en tipos de campos del body — siempre validar
- UUIDs: `z.string().min(1)` no `z.string().uuid()` — los IDs son CUIDs, no UUIDs
- Enums: validar contra lista explícita, no asumir que el valor es válido

---

## Datos sensibles — clasificación

| Dato | Nivel | Quién puede ver |
|------|-------|-----------------|
| Peso, altura, medidas corporales | Sensible | Atleta + su coach activo + admin |
| FC en reposo, FC máxima | Sensible | Atleta + su coach activo + admin |
| FoodLog (qué comió) | Privado | Atleta + su coach activo |
| SessionLog (entrenamientos) | Privado | Atleta + su coach activo |
| Check-in (RPE, sueño, estrés, dolor) | Muy sensible | Atleta + su coach activo |
| Email | Identificativo | Admin únicamente (no se expone entre actores) |
| Identificación (`identification` — cédula/pasaporte) | Muy sensible | Admin únicamente — nunca exponer en ningún endpoint público |
| WhatsApp (`phoneWa`) | Contacto | Coach dueño + admin. Público en `/p/[slug]` solo si `showPhoneWa = true` |
| Datos de pago coach-atleta | Del coach | Coach + admin (atleta solo ve fecha de vencimiento) |

**Regla de salud:** el sistema NUNCA diagostica ni medica. Cualquier dato de salud (dolor, lesión) se usa solo para ajustar el plan de entrenamiento — nunca para inferir condiciones médicas.

---

## Seguridad de la DB

- **ORM Prisma**: elimina riesgo de SQL injection — nunca construir queries con concatenación de strings
- **Neon (producción)**: cifrado en reposo y en tránsito por defecto (TLS)
- **Migrations solo con `DIRECT_URL`**: el pooler Neon no soporta DDL — `prisma db push` NUNCA en producción
- **Partial indexes**: persisten en migraciones SQL, NO usar `prisma db push` en producción (borra indexes)
- **Constraints DB**: CHECK constraints en `GymSession`, `PerformanceBenchmark` — validación a nivel DB, no solo aplicación

---

## Seguridad de variables de entorno

Variables que NUNCA van en código:

| Variable | Uso |
|----------|-----|
| `DATABASE_URL` | Pooler Neon (runtime) |
| `DIRECT_URL` | Neon directo (migraciones) |
| `AUTH_SECRET` / `NEXTAUTH_SECRET` | Auth.js JWT signing + JWT mobile signing (mismo secret, no hay variable separada para mobile) |
| `CRON_SECRET` | Autenticación de cron jobs |
| `RESEND_API_KEY` | Email transaccional |
| `UPSTASH_REDIS_REST_URL` / `TOKEN` | Rate limiting |
| `WOMPI_PRIVATE_KEY` | Crear payment links en Wompi — `Bearer` en `/v1/payment_links` |
| `WOMPI_INTEGRITY_SECRET` | Verificar firma SHA256 de webhooks Wompi en `/api/webhooks/wompi` |

**Cron endpoints:** requieren `Authorization: Bearer $CRON_SECRET`. Sin este header → 401.

---

## Protección de rutas — middleware

`src/middleware.ts` protege todas las rutas en este orden:

```
1. No autenticado + ruta no pública → /login
2. needsRoleSelection → /select-role
3. onboardingCompleted = false → /onboarding
4. ATHLETE + B2B + !activated → /pending
5. /coach/* + role !== COACH → /dashboard
6. /admin/* + role !== ADMIN → /dashboard
7. ADMIN → solo accede a /admin/*
8. COACH + /dashboard → /coach/dashboard
```

Rutas públicas: `/`, `/login`, `/register`, `/set-password`, `/forgot-password`, `/terminos`, `/privacidad`, `/api/*`, `/join/*`, `/coaches`, `/p/*`

**Nota:** `/api/*` es pública en middleware — la validación de sesión ocurre dentro de cada endpoint (`auth()` o `getMobileUser(req)`), no en el middleware.

---

## Passwords

- **bcrypt** con salt de 12 rounds (`bcrypt.hash(password, 12)`)
- Nunca almacenar passwords en texto plano — `User.password` es el hash
- Login compara con `bcrypt.compare(input, hash)` — timing-safe por diseño
- Google OAuth users no tienen password (campo `null`) — solo pueden autenticarse via OAuth

---

## Protecciones de autenticación adicionales

- **Google OAuth y usuarios bloqueados:** un usuario con status BLOCKED o SUSPENDED no puede autenticarse via Google OAuth aunque tenga `needsRoleSelection` pendiente. El sistema valida el status antes de permitir completar el flujo.
- **set-password:** el link de reset de contraseña es de un solo uso. La protección es atómica — si dos requests llegan simultáneamente con el mismo token, solo una puede consumirlo.
- **Google OAuth mobile:** la validación de audience es obligatoria. Si los client IDs de Google (iOS/Android/web) no están configurados en el servidor, la autenticación OAuth mobile falla con error explícito.
- **Mobile set-role:** al seleccionar rol desde mobile, el sistema crea automáticamente CoachProfile y subscription (paridad con el flujo web).
- **Body malformado:** todos los endpoints POST/PATCH/DELETE retornan 400 si el body del request es JSON inválido o no parseable. Nunca produce un error 500 por body malformado.

---

## Protección OWASP

| Vulnerabilidad | Protección | Estado |
|---------------|------------|--------|
| **SQL Injection** | Prisma ORM — queries parametrizadas, nunca concatenación de strings | ✅ Activo |
| **XSS** | React escapa output por defecto. No usar `dangerouslySetInnerHTML`. CSP headers pendiente | ⚠️ Parcial |
| **CSRF** | Auth.js maneja CSRF token automáticamente en forms web. Mobile usa Bearer token (inmune a CSRF) | ✅ Activo |
| **Broken Auth** | Rate limiting en login/register/forgot-password. JWT firmado con secret. Cookies HttpOnly+Secure+SameSite | ✅ Activo |
| **IDOR** | Ownership validation por actor en cada endpoint — nunca confiar en IDs del body | ✅ Activo |
| **Mass Assignment** | Zod schemas filtran campos permitidos — campos extra del body se ignoran | ✅ Activo |
| **Security Misconfiguration** | Variables sensibles en Vercel env vars, nunca en código. `.env.example` sin valores reales | ✅ Activo |

---

## Transporte — HTTPS/TLS

- **Producción (Vercel)**: HTTPS forzado por defecto — todo el tráfico web va sobre TLS 1.3. No requiere configuración.
- **Base de datos (Neon)**: conexión cifrada con TLS — el connection string incluye `sslmode=require`.
- **Mobile → API**: todas las requests van sobre HTTPS. `expo-secure-store` cifra tokens en reposo (Keychain iOS / Keystore Android).
- **Emails (Resend)**: enviados sobre TLS. Links transaccionales (`set-password`, `verify-email`) usan HTTPS con tokens de un solo uso.

---

## Soft delete — privacidad del usuario

Cuando un usuario solicita eliminar su cuenta (PLT-01):

```
User.status → DELETED
  → Email → null o anonimizado (user_[id]@deleted.medaliq.com)
  → Nombre → "Usuario eliminado"
  → HealthProfile → eliminado
  → FoodLog → eliminado
  → SessionLog → anonimizado (userId removido)
  → WeeklyCheckIn → eliminado
  → Datos financieros del coach → conservados por obligación legal (5 años)
```

**No existe hard delete inmediato** — los datos relacionales se preservan para integridad del historial de otros actores (ej. el coach tiene registros de pagos).

---

## Hardening pre-produccion (auditoria 2026-10-09)

Reglas aplicadas en 8 rondas de auditoria con ~100 fixes:

| Regla | Descripcion | Estado |
|-------|-------------|--------|
| `req.json().catch` obligatorio | Todos los endpoints con body DEBEN usar `await req.json().catch(() => null)` — body vacio/malformado causa 500 sin catch | Aplicado en todos los endpoints |
| IP rate limit en auth | `forgot-password`, `login`, `google mobile`, `set-password`, `set-role`, `verify-email` tienen rate limit por IP como primera capa (anti brute-force) | Aplicado |
| Status check en refresh/me/google | `POST /refresh` bloquea BLOCKED/SUSPENDED. `GET /me` incluye status check. `POST /google` status check incondicional (sin `&& !needsRoleSelection`) | Aplicado |
| TOCTOU prevention | `set-password` usa `updateMany` atomico (no read-then-write). `verify-email` usa delete-first. Mobile set-role usa `$transaction` | Aplicado |
| Domain validation redirect URLs | `successUrl` en stub simulate se valida contra dominio de `NEXT_PUBLIC_APP_URL` — previene open redirect | Aplicado |
| `res.ok` en client components | Verificar `res.ok` ANTES de `res.json()` en `UpgradeClient`, `CoachPlanClient`, `AthletePlanClient`, `FoodSearchModal` | Aplicado |
| `validAudiences` fail-safe | Si el array de audiencias Google tiene 0 elementos validos → 500. Nunca aceptar tokens sin audiencias configuradas | Aplicado |
| Mobile set-role atomico | `$transaction` para user.update + CoachProfile + UserSubscription upsert (paridad con web register) | Aplicado |
| `::date` vs `::timestamp` | Usar cast correcto segun tipo de columna en raw SQL. Water usa `::date` para `@db.Date` | Aplicado |

---

## Lo que NO existe todavía (gaps de seguridad)

| Gap | Riesgo | Prioridad |
|-----|--------|-----------|
| ~~`User.status` enum~~ | ~~Admin no puede bloquear usuarios~~ | ✅ Resuelto — enum `UserStatus` implementado (migración 20260709000001). Middleware enforcement de login-block por status pendiente (PLT-01). |
| ~~Refresh token para mobile JWT~~ | ~~Atleta con JWT expirado en momento crítico queda sin acceso~~ | ✅ Resuelto — `POST /api/mobile/auth/refresh` + `refreshUser()` en store + listener de notificación `features_updated` en `_layout.tsx` |
| Auditoría de acciones admin (quién cambió qué) | Sin trazabilidad de cambios manuales del admin | P2 |
| CSP headers (Content Security Policy) | XSS en caso de inyección de scripts | P2 |
| Rotación de `NEXTAUTH_SECRET` sin logout masivo | Secret comprometido → no hay mecanismo de invalidación | P3 |
