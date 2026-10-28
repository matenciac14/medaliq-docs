# Medaliq — Arquitectura de Produccion

> Infraestructura, servicios, costos y decisiones tecnicas.
> Ultima actualizacion: 2026-10-02

---

## Stack actual (produccion)

> Stack completo: ver `MEDALIQ-PROJECT/CLAUDE.md` seccion Stack.

**Servicios de infraestructura**: Vercel (Free) · Neon PostgreSQL (Free) · Upstash Redis (Free) · Resend (Free) · Expo Push (Free)

**Costo mensual actual: $0**

---

## Inventario de features en produccion

### Atleta — 48 funcionalidades

| Modulo | Features |
|--------|----------|
| **Auth** | Login email+password, registro, Google OAuth, forgot password, seleccion de rol post-OAuth, JWT mobile 30d, refresh token, sync timezone |
| **Onboarding** | Wizard multi-paso (deporte, datos fisicos, disponibilidad, salud), genera perfil + plan nutricional |
| **Dashboard** | Saludo + streak, calendario semanal navegable, sesion del dia, hero cards (KPIs), macros de hoy, hidratacion, meal slots, actividad reciente, banner FREE upsell, banner sugerencias pendientes, trial countdown |
| **Plan** | Ver plan activo (semanas/fases/sesiones), zonas FC (Karvonen), targets nutricion del dia, auto-complete planes expirados, plan completado con stats |
| **Check-in** | Formulario semanal (peso, FC, sueno, energia, RPE, estres, motivacion, dolor, adherencia nutricional, medidas corporales), sugerencias del coach (aceptar/rechazar), ventana Vie-Dom |
| **Nutricion** | Plan del dia por tipo (Hard/Easy/Rest), log comida (busqueda + upsert), agua (upsert atomico SQL), builder plantilla B2C, planner semanal, apply template, meal templates reutilizables, swap comida del plan (+-10% kcal), proponer alimento nuevo, food profile (preferencias/restricciones), propuestas del coach (aceptar/rechazar), barcode scanner (mobile: camara + Open Food Facts), lista de compras (mobile), resumen semanal adherencia |
| **Gym** | Sesion del dia con ejercicios + sets + reps scheme, completar sesion con peso/reps, PRs (Epley 1RM), builder de rutinas, asignar template publico, historial (60 sesiones), vista semanal, mapa muscular + fatiga, sugerencia peso siguiente, timer de descanso, ejercicios alternativos, GIFs animados, draft offline (mobile: AsyncStorage + SecureStore), superseries/biseries/dropsets, keep-awake (mobile) |
| **Ejercicios** | Biblioteca 1,330+ ejercicios paginada, filtros (bodyPart, target, equipment), busqueda espanol/ingles, GIF demostracion, detalle con instrucciones |
| **Running** | Log carrera libre (tipo, duracion, distancia, RPE), comparativa vs ultima sesion, historial combinado gym+running |
| **Progreso** | Evolucion peso (sparkline), FC reposo tendencia, bienestar semanal (energia/estres/motivacion), adherencia running (km/semana), adherencia gym (sesiones/semana), medidas corporales, PRs gym (top 20), historial 1RM (curvas Epley), actividad mensual, adherencia nutricional 30d, benchmarks rendimiento |
| **Perfil** | Datos fisicos (edad, peso, altura, FC, lesiones, condiciones), metricas diarias (DailyLog: peso, FC, sueno, energia), deporte y nivel |
| **Mensajes** | Chat 1:1 con coach, polling 30s, mark as read, badge unread |
| **Notificaciones** | Centro in-app (30 ultimas), mark all read, 8 tipos de notificacion |
| **Billing** | Comparativa Free vs Pro, precio COP via TRM (Banco Republica), flujo Wompi in-app browser (mobile), upgrade/downgrade |
| **Integraciones** | Strava (connect/disconnect OAuth), Apple Health pre-fill check-in (iOS), push notifications (Expo) |
| **Otros** | Rutina semanal self-directed (Free), buscar coach (marketplace), compartir milestone (share card), PWA install banner (web), centro de ayuda FAQ (web) |

### Coach — 25+ funcionalidades

| Modulo | Features |
|--------|----------|
| **Panel** | Dashboard con KPIs, lista de atletas con status, actividad reciente |
| **Atletas** | Ver perfil completo, asignar features, activar/desactivar, celebrar PR |
| **Planes** | Disenar plan de entrenamiento (semanas, sesiones, zonas), asignar a atleta |
| **Gym** | Crear WorkoutTemplates, asignar rutinas, ver historial del atleta |
| **Nutricion** | Crear NutritionTemplates, asignar plan, enviar propuestas, ver adherencia |
| **Mensajes** | Chat con atletas, coach inbox mobile |
| **Finanzas** | Pagos pendientes/completados, historial, revenue por atleta |
| **Perfil publico** | Slug unico, headline, especialidades, marketplace |
| **Billing** | Tiers (Starter/Growth/Elite), upgrade via Wompi |

### Admin — 15+ funcionalidades

| Modulo | Features |
|--------|----------|
| **Usuarios** | Lista completa, cambiar rol, activar/desactivar, ver features |
| **Ejercicios** | Sincronizar biblioteca, CRUD ejercicios |
| **Alimentos** | Aprobar/rechazar propuestas, CRUD alimentos |
| **Config** | SystemConfig (TRM, feature flags globales) |
| **Crons** | Estado de crons, trigger manual |
| **Roadmap** | Vista de progreso del producto |
| **Codigos** | InviteCodes para B2B |

### Crons — 10 jobs (todos DESACTIVADOS)

> Detalle completo de cada cron (queries, guards, acciones, trampas): ver `specs/cron.spec.md`.
> Plan de reactivacion gradual: ver seccion "Cuando activar crons" mas abajo.

---

## Servicios externos en uso

| Servicio | Proposito | Tier | Limite free | Env var |
|----------|----------|------|-------------|---------|
| **Vercel** | Web + API + SSR | Free | 100GB bandwidth, 100h build/mes | — |
| **Neon** | PostgreSQL | Free | 191h compute/mes, 512MB storage | `DATABASE_URL` |
| **Upstash Redis** | Rate limiting | Free | 10k req/dia | `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` |
| **Resend** | Email transaccional | Free | 100 emails/dia, 1 dominio | `RESEND_API_KEY` |
| **Expo Push** | Push notifications | Free | Ilimitado | — |
| **Google OAuth** | Login social | Free | Ilimitado | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| **Strava** | Wearable sync | Free | 100 req/15min, 1000/dia | `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET` |
| **Banco Republica API** | TRM USD/COP | Free | Sin limite conocido | — (datos.gov.co publico) |
| **Open Food Facts** | Barcode lookup | Free | Sin limite (open source) | — |

---

## Limites criticos del free tier

### Neon — el cuello de botella

```
Compute: 191h/mes (~6.3h/dia)
Storage: 512MB
Branches: 10

El compute se activa con cada query y permanece activo 5 minutos (auto-suspend).
```

**Calculo de consumo:**

| Escenario | Queries/dia | Compute activo | Horas/mes |
|-----------|-------------|----------------|-----------|
| 1 usuario activo | ~50 | ~30min | 15h |
| 10 usuarios activos | ~500 | ~3h | 90h |
| 30 usuarios activos | ~1500 | ~6h | 180h (al limite) |
| 50+ usuarios activos | ~2500 | ~8h+ | **EXCEDE free tier** |
| + 10 crons diarios | +80 queries | +40min/dia | +20h/mes |

**Regla: sin crons el free tier aguanta ~30 usuarios activos. Con crons, ~20.**

### Como proteger el free tier de Neon

1. **Crons on-demand** — mover `expire-suggestions` y `billing-check` a ejecutarse inline cuando el usuario abre dashboard o auth/me
2. **Reducir frecuencia de crons** — cuando se activen, usar 2-3x/semana en vez de diario
3. **Connection pooling** — Neon lo incluye gratis. Usar `?pgbouncer=true` en `DATABASE_URL`
4. **Select scoping** — no usar `include: { relation: true }` (trae 30+ campos). Usar `select` con campos especificos
5. **Query batching** — `Promise.all()` con multiples queries en paralelo (ya implementado en dashboard, nutrition, gym)

### Vercel — generous pero con limites

```
Bandwidth: 100GB/mes (suficiente para ~50k page views)
Build time: 100h/mes (suficiente)
Serverless executions: 100GB-hours (suficiente para <1000 usuarios)
Edge: 500k invocaciones (suficiente)
Cron jobs: 1 por proyecto (free), cada 24h minimo
```

**Limite real: Vercel free solo permite 1 cron job con frecuencia minima de 1x/dia.** Para multiples crons necesitas Pro ($20/mes) o Upstash QStash.

### Upstash Redis — holgado

```
10,000 requests/dia = ~7 req/min
Rate limiting usa ~2 req por API call (check + increment)
Con 50 usuarios activos haciendo 20 API calls/dia = 2,000 req/dia → 20% del free tier
```

### Resend — suficiente para beta

```
100 emails/dia
Tipos de email: registro, forgot password, check-in reminder, session reminder,
               re-engagement, payment overdue, billing renewal, coach pending athlete
Sin crons: ~5-10 emails/dia (registros + forgot password)
Con crons: hasta 50-80 emails/dia con 30 usuarios
```

---

## Arquitectura por fase de crecimiento

### Fase 0 — Beta (0-30 usuarios) — $0/mes

```
┌─────────────┐     ┌──────────────┐
│   Mobile    │────▶│              │
│  Expo/RN    │     │   Vercel     │
└─────────────┘     │   (Free)     │
                    │              │
┌─────────────┐     │  Next.js 16  │     ┌──────────────┐
│   Browser   │────▶│  Web + API   │────▶│  Neon (Free)  │
│   Web app   │     │  + RSC       │     │  PostgreSQL   │
└─────────────┘     │              │     └──────────────┘
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Upstash  │ │  Resend  │ │  Expo    │
        │ Redis    │ │  Email   │ │  Push    │
        │ (Free)   │ │  (Free)  │ │  (Free)  │
        └──────────┘ └──────────┘ └──────────┘
```

**Acciones inmediatas:**
- Mover `expire-suggestions` a on-demand (inline en GET /checkin)
- Mover `billing-check` a on-demand (inline en GET /auth/me o /dashboard)
- NO activar crons en vercel.json
- Usar Upstash QStash (free, 500 msg/dia) para los 2-3 crons criticos cuando haya usuarios
- Connection pooling en Neon (`?pgbouncer=true`)

### Fase 1 — Lanzamiento (30-200 usuarios) — $0-20/mes

```
┌─────────────┐     ┌──────────────┐
│   Mobile    │────▶│              │
│  Expo/RN    │     │   Vercel     │
└─────────────┘     │   (Pro $20)  │
                    │              │
┌─────────────┐     │  Next.js 16  │     ┌──────────────┐
│   Browser   │────▶│  Web + API   │────▶│  Neon        │
│   Web app   │     │  + Crons     │     │  (Launch $19)│
└─────────────┘     │              │     └──────────────┘
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Upstash  │ │  Resend  │ │  Expo    │
        │ Redis    │ │  Email   │ │  Push    │
        │ (Free)   │ │  (Free)  │ │  (Free)  │
        └──────────┘ └──────────┘ └──────────┘
              │
              ▼
        ┌──────────┐
        │ QStash   │  ← cron scheduler (Free)
        │ (Free)   │  ← dispara HTTP a tu API
        └──────────┘
```

**Trigger para escalar:**
- Neon compute > 150h/mes → upgrade a Launch ($19/mes, 300h)
- Vercel: > 100GB bandwidth o necesitas multiples crons → Pro ($20/mes)
- Activar 3-5 crons via QStash (checkin-reminder, session-reminder, streak-risk)

### Fase 2 — Crecimiento (200-2000 usuarios) — $50-80/mes

```
┌─────────────┐     ┌──────────────┐
│   Mobile    │────▶│   Fly.io     │
│  Expo/RN    │     │   (API)      │
└─────────────┘     │   Hono+Node  │     ┌──────────────┐
                    │   Always-on  │────▶│  Neon        │
┌─────────────┐     │   Sao Paulo  │     │  (Scale $69) │
│   Browser   │──┐  └──────────────┘     │  Sao Paulo   │
│   Web app   │  │                       └──────────────┘
└─────────────┘  │  ┌──────────────┐            │
                 └─▶│   Vercel     │            │
                    │   (Pro $20)  │────────────┘
                    │   Web + SSR  │
                    └──────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   ┌──────────┐     ┌──────────┐     ┌──────────┐
   │ Upstash  │     │  Resend  │     │ R2       │
   │ Redis+   │     │  (Pro)   │     │ Storage  │
   │ QStash   │     │  ($20)   │     │ GIFs     │
   │ ($0-10)  │     └──────────┘     │ (Free)   │
   └──────────┘                      └──────────┘
```

**Trigger para separar API:**
- Cold starts de Vercel > 2s en endpoints mobile
- Necesitas API always-on para UX mobile rapida
- Hono en Fly.io: ~50ms startup vs ~2-3s cold start Vercel

### Fase 3 — Escala + AI (2000+ usuarios) — $100-200/mes

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   Mobile    │────▶│   Fly.io     │────▶│  Neon Scale  │
│  Expo/RN    │     │   API        │     │  PostgreSQL  │
└─────────────┘     │   Hono+Node  │     │  ($69)       │
                    │   2 VMs GRU  │     └──────────────┘
┌─────────────┐     └──────┬───────┘
│   Browser   │──┐         │
│   Web app   │  │         ▼
└─────────────┘  │  ┌──────────────┐     ┌──────────────┐
                 │  │  Modal.com   │     │ Cloudflare   │
                 │  │  AI/ML       │     │ R2 Storage   │
                 │  │  Python      │     │ (Free 10GB)  │
                 │  │  GPU on-use  │     └──────────────┘
                 │  └──────────────┘
                 │         │
                 │  ┌──────┴───────┐
                 │  │ Features AI: │
                 │  │ - Foto→macros│
                 │  │ - %grasa     │
                 │  │ - Coaching   │
                 │  └──────────────┘
                 │
                 └─▶┌──────────────┐
                    │   Vercel     │
                    │   Web SSR    │
                    │   (Pro $20)  │
                    └──────────────┘
```

---

## Acciones inmediatas para proteger el free tier

### 1. Crons → on-demand (zero compute extra)

| Cron | Mover a | Implementacion |
|------|---------|----------------|
| `expire-suggestions` | `GET /api/mobile/checkin` y `GET /api/athlete/checkin` | Antes de responder, correr `repo.expireOld()`. 1 query extra, sin cron |
| `billing-check` | `GET /api/mobile/dashboard` y `GET /api/mobile/auth/me` | Ya haces auto-complete de planes. Agregar: verificar suscripcion expirada inline |

### 2. Connection pooling

```env
# .env
DATABASE_URL="postgresql://...@ep-xxx.us-east-2.aws.neon.tech/medaliq?pgbouncer=true&connect_timeout=15&pool_timeout=15"
```

### 3. Select scoping (ya en progreso)

Cambios aplicados en sesion anterior:
- `dashboard_queries.ts` — exercise include scoped a 5 campos
- `get_today_session.use_case.ts` — exercise include scoped a 10 campos
- `get_nutrition_today.use_case.ts` — buildWeeklySummary pre-fetched

### 4. Cuando activar crons (via Upstash QStash)

```
0 usuarios   → 0 crons (todo on-demand)
10 usuarios  → checkin-reminder (1x/sem) + session-reminder (1x/sem)
30 usuarios  → + streak-risk (3x/sem)
50 usuarios  → considerar Neon Launch ($19/mes)
Coaches      → + pending-athlete-reminder + nutrition-alert
Billing live → + billing-check + payment-overdue + billing-renewal-reminder
```

---

## Costos proyectados

| Usuarios | Vercel | Neon | Upstash | Resend | Fly.io | Total |
|----------|--------|------|---------|--------|--------|-------|
| 0-30 | $0 | $0 | $0 | $0 | — | **$0** |
| 30-100 | $0 | $0-19 | $0 | $0 | — | **$0-19** |
| 100-500 | $20 | $19 | $0 | $0 | — | **$39** |
| 500-2000 | $20 | $69 | $10 | $20 | $5 | **$124** |
| 2000+ | $20 | $69 | $10 | $20 | $10 | **$129 + AI** |

**Breakeven: 13 usuarios Pro ($10/mes) cubren los $129/mes de infra en Fase 2.**

---

## Decisiones de arquitectura documentadas

### Por que NO separar el backend ahora

- Equipo de 1 persona — dos proyectos = doble ops
- Vercel free tier cubre web + API sin costo
- Use cases compartidos entre RSC y API mobile — un solo repo es mas simple
- Cold starts de Vercel son ~1-2s — aceptable para beta

### Cuando separar

- Cold starts > 2s afectan UX mobile
- Equipo > 1 persona (alguien trabaja en web mientras otro en API)
- Neon compute sobrepasado por volumen de queries

### Por que Hono y no NestJS (cuando se separe)

- Hono: ~2MB, ~50ms startup, Express-like
- NestJS: ~50MB, DI container + decorators + modules = ceremonia sin valor para 1-3 devs
- La arquitectura hexagonal actual ya separa capas — NestJS duplicaria estructura

### Por que no Python para el backend

- El dominio es calculo deportivo (Karvonen, Mifflin-St Jeor, Epley) — TypeScript lo maneja
- 12 use cases + 31 repositorios + 90 rutas en TypeScript — reescribir = cero beneficio
- Python SI para AI/ML futuro (foto→macros, %grasa) como microservicio separado (Modal.com)

### Por que multiples servicios especializados vs todo en AWS

- AWS minimo (RDS + Lambda): $30-50/mes con 0 usuarios
- Stack propuesto: $0/mes con 0 usuarios
- Cada servicio es best-in-class para su funcion
- Zero ops — sin VPC, IAM, Security Groups, CloudWatch
- LatAm: todos tienen regiones en Sao Paulo (~40ms a Colombia)

---

## Checklist pre-lanzamiento

- [ ] Connection pooling en DATABASE_URL (`?pgbouncer=true`)
- [ ] Mover `expire-suggestions` a on-demand
- [ ] Mover `billing-check` a on-demand
- [ ] Crear cuenta Upstash QStash (free) para crons futuros
- [ ] Verificar Neon compute actual en dashboard.neon.tech
- [ ] Mover GIFs de ejercicios a Cloudflare R2 (libera bandwidth Vercel)
- [ ] Configurar Neon auto-suspend a 5 min (default, verificar)
- [ ] Verificar `UPSTASH_REDIS_REST_URL` configurado en Vercel env vars
- [ ] Wompi sandbox E2E test (cuando billing este listo)
- [ ] EAS build con push notifications projectId real

---

## Historial de decisiones

| Fecha | Decision | Razon |
|-------|----------|-------|
| 2026-09-25 | Desactivar todos los crons | Neon free tier agotado por compute de crons |
| 2026-10-02 | Documentar arquitectura de produccion | Definir estrategia de infra por fase de crecimiento |
| — | Mover crons criticos a on-demand | Eliminar consumo de compute innecesario |
| — | Separar backend a Fly.io (futuro) | Cuando cold starts afecten UX mobile |
| — | AI/ML en Modal.com (futuro) | Cuando features de vision/LLM lo requieran |
