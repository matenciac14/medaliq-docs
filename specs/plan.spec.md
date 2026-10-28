# PLAN — Indice de specs de plan, sesiones, check-in y dashboard

> **ARCHIVO INDICE** — no contiene contratos. Lee el sub-spec relevante a tu tarea.
> Domain doc: `../domains/plan.md`

## Sub-specs (lee SOLO el que necesites)

| Sub-spec | Scope | Cuando leer |
|----------|-------|-------------|
| `plan_checkin.spec.md` | Check-in semanal, sugerencias, processCheckIn use case, evaluateRules, syncWeight | Tocas check-in, sugerencias, ajustes automaticos, peso |
| `plan_sessions.spec.md` | Calendar, sessions PATCH, log session/run, history, delete log | Tocas calendario, editar sesiones, registrar/editar/borrar logs, historial |
| `plan_dashboard.spec.md` | Mobile dashboard, week-sessions, auto-complete plan, overlayGymSessions | Tocas dashboard mobile, CalendarStrip, lifecycle del plan |

## Contratos compartidos (rapido)

| Canal | Auth | Tenant |
|-------|------|--------|
| Web | `auth()` Auth.js | `session.user.id` |
| Mobile | `getMobileUser(req)` jose | `mobile.id` |

**Feature gates mobile**: `checkin` (POST checkin), `plan` (PATCH sessions), `log` (POST log/session)

## Regla

NO leas este archivo completo. Identifica tu tarea, lee el sub-spec correspondiente.
Si tu tarea cruza multiples sub-specs, lee solo los relevantes.

---

*Archivo original (1098 lineas) dividido el 2026-10-02 para reducir consumo de tokens.*
