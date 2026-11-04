# FTD: [nombre del cambio]
# Carril medio — 1 a 5 archivos, sin nueva abstraccion ni modelo DB nuevo.
# Crear ANTES del primer Edit. Llenar durante el build. Queda como audit trail.

## 4 preguntas (obligatorias — no empezar sin responder)

**1. Que puede hacer el usuario?**

**2. Que resultado obtiene?**

**3. Que debe respetar?**

**4. Como se demuestra?**

## Intent
[Que problema resuelve en 1-2 lineas. Por que ahora.]

## Scope — archivos que se tocan
- [ ] `src/...` —
- [ ] `src/...` —

## Fuera de scope — NO tocar
-

## Checklist
- [ ] Leer archivo completo antes de editar
- [ ] Verificar campos en schema.prisma si toca DB
- [ ] `res.ok` antes de `res.json()` si hay client fetch
- [ ] Traps del modulo revisados (ver CLAUDE.md indice)
- [ ] `pnpm typecheck` sin errores
- [ ] `pnpm test` sin regresiones

## Evidencia (llenar al terminar)
- Build: [ ] pasa
- Tests: [ ] pasan
- Comportamiento verificado manualmente: [ ]

## Decisiones tomadas
<!-- Por que se hizo asi, que alternativas se descartaron -->

## Parked (blockers para Miguel)
<!-- Items que requieren decision humana — ver /build decision queue -->

## Estado
- [ ] En progreso
- [ ] Completo — pendiente PR
