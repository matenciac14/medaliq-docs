# FTD: [nombre del cambio]
# Carril medio — 1 a 5 archivos, sin nueva abstracción ni modelo DB nuevo.
# Crear ANTES del primer Edit. Llenar durante el build. Queda como audit trail.

## Intent
[Qué problema resuelve en 1-2 líneas. Por qué ahora.]

## Scope — archivos que se tocan
- [ ] `src/...` —
- [ ] `src/...` —

## Fuera de scope — NO tocar
-

## Checklist
- [ ] Leer archivo completo antes de editar
- [ ] Verificar campos en schema.prisma si toca DB
- [ ] `res.ok` antes de `res.json()` si hay client fetch
- [ ] Traps del módulo revisados (ver CLAUDE.md índice)
- [ ] `pnpm typecheck` sin errores
- [ ] `pnpm test` sin regresiones

## Evidencia (llenar al terminar)
- Build: [ ] pasa
- Tests: [ ] pasan
- Comportamiento verificado manualmente: [ ]

## Decisiones tomadas
<!-- Por qué se hizo así, qué alternativas se descartaron -->

## Estado
- [ ] En progreso
- [ ] Completo — pendiente PR
