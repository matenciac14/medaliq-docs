# Domain: Plataforma (Admin + Landing + Marketplace + Notificaciones)
# Reglas de negocio no evidentes en el código. Leer antes de tocar admin, landing, marketplace o notificaciones.
> **Flujos por actor → `flujos-por-actor.md`** — qué puede hacer el admin en cada módulo, con endpoints completos.
> Spec de implementacion: `../specs/cron.spec.md` — contratos, endpoints, trampas.

## Disponibilidad
| Canal | Estado |
|-------|--------|
| Web atleta | Parcial (/find-coach) |
| Mobile atleta | Parcial (find-coach informativo) |
| Web coach | N/A |
| Web admin | Completa (/admin/*) |

---

## Admin — panel de operación del negocio

El admin es el panel de operación de Miguel como founder. Tiene dos capas:

### 1. Gestión de usuarios

| Puede | NO puede |
|-------|----------|
| Ver todos los usuarios con sus roles y estados | Registrar sesiones o check-ins |
| Cambiar rol de cualquier usuario | Ver datos médicos privados del atleta |
| Cambiar tier de suscripción (coach y atleta) | Actuar como coach sobre un atleta |
| Bloquear, suspender, reactivar usuarios | Modificar FoodLog o SessionLog |
| Eliminar usuario (soft delete con doble confirmación) | — |
| Cambiar coach asignado a un atleta | — |
| Ver perfil completo de cualquier atleta o coach | — |

**Estados de usuario:**

| Estado | Qué significa | Puede loguearse |
|--------|---------------|-----------------|
| `ACTIVE` | Normal, acceso completo | ✅ |
| `SUSPENDED` | Suspensión temporal (ej. pago pendiente) — reversible | ❌ |
| `BLOCKED` | Bloqueado por admin (incumplimiento de términos) — requiere acción manual para reactivar | ❌ |
| `DELETED` | Soft delete — datos anonimizados, cuenta cerrada. Solo por solicitud del usuario o admin. | ❌ |

**Nota técnica:** `User.status UserStatus` implementado en schema (migración 20260709000001). Enum: ACTIVE | SUSPENDED | BLOCKED | DELETED. El middleware de auth aún no bloquea login por status — enforcement pendiente (PLT-01).

Al cambiar rol → sincronizar feature flags automáticamente via `featuresByRole` map.

### 2. Business intelligence — visión del negocio

El admin panel es el radar de producto para tomar decisiones. Métricas que debe mostrar:

**Usuarios y crecimiento:**
- Total coaches activos / suspendidos / bloqueados
- Total atletas: con coach activo / sin coach (B2C) / en /pending
- Tasa de onboarding completado (atletas que llegaron y completaron el perfil)
- Nuevos usuarios por semana/mes
- Distribución geográfica (ciudad/país) — dónde está la tracción

**Salud del producto:**
- Atletas activos últimos 7 días (logearon sesión o check-in)
- Tasa de abandono semana 2 (atletas que no vuelven tras el primer acceso)
- Adherencia promedio de la plataforma (sesiones completadas vs planeadas)
- Coaches con atletas activos vs coaches sin atletas (coaches dormidos)
- Atletas sin plan en ninguna modalidad (B2C tracker puro)

**Métricas de negocio (billing futuro):**
- MRR total = MRR coaches + MRR atletas B2C Pro (dos streams independientes)
  - MRR coaches: suma del fee por tier de cada coach activo (STARTER $0 / GROWTH $59 / PRO $139 / SCALE $139 + $4/atleta sobre 30)
  - MRR atletas: count(atletas PRO) × $9.99 (pendiente conectar Wompi/Stripe)
- Distribución de tiers de coach (STARTER / GROWTH / PRO / SCALE)

> **SCALE incluye cargo variable por atleta adicional sobre 30. Enum actual: `STARTER | GROWTH | PRO | SCALE`.**
- Proyección de upgrades por coach que se acerca al límite de asesorados
- Coaches candidatos a upgrade (activos + cerca del límite de su tier)
- Atletas B2C: distribución FREE vs PRO (cuando el tier esté enforcement activo)

**Estado actual:** `/admin/metrics` tiene contadores básicos. Las métricas de negocio están parcialmente implementadas. Ver roadmap para gaps.

**Dashboard — fechas y timezone:**
- Las fechas de actividad reciente en el dashboard se muestran en el timezone del usuario, no en UTC.
- El parámetro `weekOffset` para consultas semanales tiene un límite de [-52, 52] — máximo un año hacia atrás o hacia adelante.

---

## Marketplace — directorio de coaches

`/coaches` — directorio público de coaches con perfil visible.
`/p/[slug]` — perfil individual del coach.

### Flujo de contratación

```
Atleta navega /coaches → filtra por especialidad / ciudad / nivel
  → Ve perfil del coach /p/[slug] (bio, especialidades, precio referencial)
  → Click "Escribir por WhatsApp" → abre WhatsApp del coach con mensaje pre-redactado
      ("Hola, te encontré en Medaliq y me interesa tu asesoría")
  → Acuerdan términos y precio fuera de la plataforma (Nequi, Daviplata, transferencia)
  → Coach activa al atleta en su panel → atleta recibe acceso a features B2B
  → Atleta suma como usuario activo de Medaliq
```

**PLT-06 — Botón WhatsApp en /p/[slug] (implementado 2026-07-09):**
- Se muestra si `coach.showPhoneWa = true` AND `coach.phoneWa` existe
- Botón verde `#25D366` full-width con SVG WhatsApp + mensaje pre-redactado en URL
- Los links legacy `profile.whatsapp` (número en perfil público) e `profile.instagram` se mantienen como secundarios
- `coach.phoneWa` viene del campo `User.phoneWa` (E.164: `+57XXXXXXXXXX`) — activado en `/coach/profile`

**Modelo económico del marketplace:**
- Medaliq NO toma comisión de transacciones coach-atleta — 0% fee es permanente y estructural
- Medaliq cobra al coach por su tier de suscripción (STARTER/GROWTH/PRO/SCALE)
- El marketplace es un canal de adquisición de usuarios, no de ingresos directos
- Diferenciador explícito vs TrueCoach: "0% de comisión sobre tus cobros" — siempre

**Diferencia `/coaches` vs `/join/[code]`:**
- `/coaches`: el atleta llega solo, descubre al coach — adquisición inbound
- `/join/[code]`: el coach invita a un atleta específico — adquisición outbound del coach
- Los dos flujos terminan igual: coach activa atleta en su panel

### Regla de visibilidad del marketplace

El directorio `/coaches` está oculto de la navegación hasta tener 20+ coaches activos. Un directorio vacío daña la credibilidad. No agregar links sin decisión explícita de Miguel.

**Filtros del directorio (cuando se abra):** especialidad (RUNNING / GYM / NUTRITION / ALL), ciudad/país, idioma, precio referencial. Ordenamiento por: relevancia, atletas activos, antigüedad en plataforma.

---

## Sistema de notificaciones — diseño por canal

El principio es **in-app primero, canal externo solo cuando el atleta no está en la app.**

### Canal 1 — In-app (centro de notificaciones — pendiente de implementar)

Toda notificación se registra en el centro in-app. Es el canal primario.

| Evento | Quién lo recibe |
|--------|----------------|
| Sesión del día programada | Atleta |
| Check-in semanal disponible | Atleta |
| Plan publicado/actualizado por coach | Atleta |
| Mensaje del coach sin leer | Atleta |
| Ajuste de plan por check-in ("Bajamos tu volumen") | Atleta |
| Ajuste nutricional pendiente de aceptar/rechazar | Atleta |
| Logro desbloqueado (PR, racha, hito) | Atleta |
| Propuesta de ajuste nutricional del coach | Atleta |
| Nuevo atleta completó onboarding | Coach |
| Atleta con adherencia < 60% esta semana | Coach |
| Atleta lleva 48h en /pending sin activar | Coach |

### Canal 2 — Push notification (cuando la app no está abierta)

| Evento | Timing |
|--------|--------|
| Recordatorio de sesión del día | Mañana del día de sesión |
| Check-in pendiente | Domingo tarde |
| Racha en riesgo ("Llevas 1 día sin actividad") | Día siguiente sin registro |
| Mensaje del coach sin leer | 2h después del mensaje |
| Atleta en /pending 48h | Coach — 48h después del onboarding |

### Canal 3 — Email (app no abierta en 24h+)

| Evento | Trigger |
|--------|---------|
| Bienvenida coach | Al registrarse |
| Bienvenida atleta | Al completar onboarding |
| Coach asignado | Al activarse relación coach-atleta |
| Reset de contraseña | On demand |
| Pago vencido | Cron diario (ya implementado) |
| Re-engagement | Atleta sin abrir app 3+ días |
| Plan asignado | Al publicar plan (si app no abierta) |

### Canal 4 — WhatsApp (roadmap — post Meta Live Mode)

Recordatorios de alta prioridad que email no logra. Pendiente activación Meta Live Mode.

### Reglas de canal

- **In-app siempre** — todo evento genera registro en el centro de notificaciones
- **Push** solo cuando la app no está abierta — no duplicar con in-app visible
- **Email** solo si la app no fue abierta en 24h (excepto: bienvenida, reset, re-engagement)
- **No duplicar canales** para el mismo evento en el mismo momento
- **Frecuencia máxima de email:** 1/día por usuario — nunca más de uno diario
- **WhatsApp:** solo eventos de alta prioridad — nunca marketing

### Crons activos en Vercel

| Endpoint | Schedule | Qué hace |
|----------|----------|----------|
| `/api/cron/checkin-reminder` | Dom 23:00 UTC | Email recordatorio check-in |
| `/api/cron/session-reminder` | Lun 12:00 UTC | Email sesión del día |
| `/api/cron/payment-overdue` | Diario 14:00 UTC | Email pagos vencidos al coach |
| `/api/cron/pending-athlete-reminder` | Diario 12:00 UTC | Push al coach por atleta en /pending 48h+ |
| `/api/cron/expire-suggestions` | Diario 03:00 UTC | Expira CheckInSuggestions antiguas |
| `/api/cron/billing-check` | Diario 02:00 UTC | Downgrade coaches con pago vencido |
| `/api/cron/billing-renewal-reminder` | Diario 13:00 UTC | Email con link de pago Wompi a suscripciones que vencen en 7 días |
| `/api/cron/inactive-athlete-reminder` | Diario 14:00 UTC | Push + email a atleta sin actividad 3+ días |
| `/api/cron/streak-risk` | Diario 20:00 UTC | Push a atleta con racha en riesgo (1 día sin actividad) |
| `/api/cron/nutrition-alert` | Diario 09:00 UTC | Push al coach si atleta lleva 3 días con adherencia nutricional <60% |

Todos requieren header `Authorization: Bearer $CRON_SECRET`.

---

## Landing — mejoras implementadas (2026-07-09)

- **ROI Calculator** (`src/app/_components/ROICalculator.tsx`): slider 1-100 atletas → horas/semana ahorradas + USD equivalente. Sección antes de Pricing.
- **Sección seguridad**: card con escudo SVG entre WhatsApp CTA y garantía. Texto: HTTPS, Neon, backups, no compartir datos.
- **Badge garantía**: "✓ 30 días de garantía" en verde centrado encima del título de la sección garantía.
- **404**: `not-found.tsx` ya tenía logo + botones — confirmado correcto.

## Landing — propuesta de valor

La landing es la misma para atletas y coaches. La propuesta de valor principal:

**El dolor que resuelve:**
- Coach: gestiona a sus asesorados con WhatsApp y Excel → pierde tiempo, pierde contexto, no escala
- Atleta: sigue un PDF de entrenamiento sin feedback real → el plan nunca se adapta a cómo se siente

**El flywheel de crecimiento:** más coaches adoptan Medaliq → más atletas descargan la app (los coaches los incorporan) → más atletas = más credibilidad para el marketplace → más coaches inbound. El coach es el canal de distribución.

**Diferenciadores a destacar siempre:**
- 0% de comisión sobre tus cobros (vs TrueCoach 5%)
- El plan se ajusta en tiempo real según cómo se siente el atleta
- WhatsApp es el canal de contacto estándar en LatAm — debe estar visible en la landing

**Reglas de contenido:**
- No mostrar número de coaches/atletas hasta tener 20+ reales
- No mostrar pricing de coaches hasta tener enforcement de tiers activo (hoy todo hardcodeado a PRO)
- La propuesta de valor para coach y atleta puede estar en la misma página pero en secciones distintas

---

## Internacionalización (i18n)

El producto está pensado para LatAm: español colombiano es el idioma principal. El schema soporta `User.locale` y `User.timezone`.

**Estado:** implementación parcial activa. `src/lib/i18n/` con traducciones en 3 idiomas (es, en, pt). Cubre sidebar, labels administrativos y textos de UI comunes. NO cubre todo el producto — muchos textos están hardcodeados en español.

**Archivos clave:**
- `src/lib/i18n/index.ts` — hook y provider
- `src/lib/i18n/server.ts` — i18n server-side
- `src/lib/i18n/types.ts` — tipos de traducciones
- `src/lib/i18n/translations/{es,en,pt}.ts` — diccionarios

**Orden de expansión:** es-CO (principal) → en (parcial, existente) → pt-BR (parcial, existente) → es-MX → es-PE.

---

## Deploy

- `main` → auto-deploy en Vercel (medaliq.com)
- NO pushear a `main` sin autorización explícita de Miguel
- Migraciones en producción: requieren `DIRECT_URL` — el pooler Neon no soporta DDL
- NUNCA usar `prisma db push` en producción — solo `prisma migrate deploy`

---

## Scope deseado — no priorizado (análisis competitivo 2026-08)

Features identificadas tras análisis de Ladder (`joinladder.com`). **No implementar sin decisión explícita de Miguel.**

### Free trial 7 días sin tarjeta — B2C (DESIRED-03)

Al activar billing B2C (Wompi conectado), reducir fricción de conversión con un trial sin tarjeta: el atleta accede a Pro 7 días gratis, al día 7 se solicita pago o revierte a Free automáticamente.

**Implementación:**
- Columna `trialEndsAt DateTime?` en `UserSubscription`
- `getUserPlan()` retorna `'PRO'` si `trialEndsAt > now()` aunque `tier = FREE`
- Email al día 5: "Te quedan 2 días de Pro — no pierdas tus ajustes automáticos"
- Cron diario: evalúa `trialEndsAt` y ejecuta downgrade si venció sin pago

**Prerequisito estricto**: implementar únicamente cuando billing B2C esté conectado y enforcement de tiers activo. No tiene sentido sin el gate de pago real.

### Video form feedback — coach revisa técnica del atleta (DESIRED-04)

El atleta sube un clip corto de su técnica (sentadilla, peso muerto) desde la app. El coach lo ve en el panel y deja una nota de corrección. El atleta recibe la nota con el clip embebido.

**Complejidad alta** — requiere:
- Infraestructura de video: Cloudflare R2 o S3 + transcoding (MUX o ffmpeg lambda)
- Límites de tamaño (ej. max 30s, max 50MB)
- Visor de video en el panel del coach con campo de nota/feedback
- Notificación al atleta cuando el coach responde

Evaluar demanda real antes de construir. La infraestructura de media es el mayor costo operativo nuevo que introduciría esta feature.
