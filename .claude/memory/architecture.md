# Medaliq — Decisiones de Arquitectura de Producto

> Decisiones que afectan ambos repos (web + mobile). Actualizar cuando cambie el diseño del producto.

## Stack general
- Web: Next.js 16 + React 19 + TypeScript + PostgreSQL + Prisma 7 + Auth.js v5
- Mobile: React Native + Expo ~54 + Expo Router v6 + NativeWind v4 + TanStack Query v5
- Auth mobile: JWT jose en SecureStore, Bearer token, 30d expiry
- Rutas mobile: /api/mobile/* (separadas de las rutas web)

## Decisiones de producto
- Sistema determinista — sin generación automática de planes, sin AI/LLM en flujos de entrenamiento
- Coach es el cliente principal — adquirir coaches = adquirir atletas
- Billing desactivado en beta — todos PRO hasta activar Wompi
- Strava: backend listo, no activado
- Coach mobile: pendiente, web-first

## Actors y tenant keys
- Atleta: `userId` / `athleteId`
- Coach: `userId`
- Admin: rol en sesión
- Multi-tenant: filtrar siempre por userId o athleteId según contexto

## Repos
- Web: `matenciac14/medaliq-web` (antes: Medaliq) — `main → develop → feature/*`
- Mobile: `matenciac14/medaliq-mobile` — `main → feature/*`
- Docs: `matenciac14/medaliq-docs` — este repo
