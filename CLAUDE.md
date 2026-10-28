# Medaliq — Contexto del Producto

> Tecnico web -> `MEDALIQ-PROJECT/CLAUDE.md` | Mobile -> `MEDALIQ-MOBILE/CLAUDE.md` | Schema -> `MEDALIQ-PROJECT/prisma/schema.prisma`

## Que es
Plataforma de tracking y coaching deportivo para LatAm. B2C (atleta autonomo) + B2B (coach diseña, atleta ejecuta). **Cliente principal: el entrenador** — adquirir coaches = adquirir atletas.

**Actores**: Atleta (mobile diario) · Coach (panel web) · Admin (SaaS completo)

**Filosofia**: simple para el atleta · mobile-first · determinista (sin AI/LLM) · LatAm primero (espanol, COP/USD/MXN, timezone del usuario)

## Pricing

| | Tier | Precio | Limite |
|-|------|--------|--------|
| B2C | Free | $0 | Log, nutricion, gym — sin plan ni metricas |
| B2C | Pro | $9.99/mes | + plan + check-in + metricas + sugerencias |
| B2B | Starter | $0 | 2 atletas |
| B2B | Growth | $59/mes | 10 atletas |
| B2B | Pro | $139/mes | 30 atletas |
| B2B | Scale | $139 + $4/extra | sin limite |

- Atleta B2B: registro normal → onboarding → `/pending` hasta que coach active
- Coach paga por tier, no por atleta. 0% comision sobre cobros coach-atleta
- **Billing desactivado en beta** — todos PRO hasta activar Wompi

## Scope

- **Gym completo, running parcial** (sin biblioteca ejercicios running). Cycling/swimming/triathlon/football excluidos
- **Sin generacion automatica** — coach diseña, atleta Pro configura, Free solo tracking
- **Solo macros + kcal en calculos** — micronutrientes son badges informativos, no formulas
- **Strava** backend listo, no activado
- **Coach mobile** pendiente — web-first

## Repos — DOS separados

| Repo | Flujo |
|------|-------|
| `MEDALIQ-PROJECT/` (web) | `main` → `develop` → `feature/*` |
| `MEDALIQ-MOBILE/` (app) | `main` → `feature/*` |

**NUNCA mezclar commits entre repos.** `domains/` y `specs/` estan fuera de ambos repos (solo disco local).

## Figma
fileKey: `fV1SK1rxdJHAmA8n1zK3Cm` · Paleta: Navy `#1a2744` + Naranja `#f97316`
Paginas y node-ids → `memory/figma.md`
