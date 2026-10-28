# Contexto: [nombre-feature]
# Memoria persistente de esta feature entre sesiones.
# Actualizar al TERMINAR cada sesion — especialmente "Donde quede".

## Que es esta feature
[descripcion en 1-2 lineas — que problema resuelve, quien lo usa]

## Domain docs a leer antes de empezar
<!-- OBLIGATORIO — marcar los que aplican antes de abrir el worktree.
     Leer flujos-por-actor.md SIEMPRE como primer paso — tiene el estado de implementacion ([roadmap]/[parcial]).
     Si todos estan sin marcar, el contexto esta incompleto: pedir a Miguel que los identifique. -->
- [ ] `../domains/flujos-por-actor.md` <- LEER PRIMERO — que puede hacer cada actor + estado de cada feature
- [ ] `../domains/atleta.md`
- [ ] `../domains/coach.md` (incluye identidad/verificación si toca registro, onboarding coach o billing)
- [ ] `../domains/nutricion.md`
- [ ] `../domains/entrenamiento.md` (si la feature toca gym, ejercicios, rutinas)
- [ ] `../domains/plan.md` (si la feature toca plan de entrenamiento, check-in, sesiones)
- [ ] `../domains/plataforma.md`
- [ ] `../domains/pagos.md`
- [ ] `../domains/flujos-cruzados.md`
- [ ] `../domains/seguridad.md` (si la feature toca auth, endpoints, o datos sensibles)
- [ ] `../domains/integraciones.md` (si la feature toca wearables o sync de actividades)
- [ ] `../MEDALIQ-PROJECT/prisma/schema.prisma` (si la feature toca DB)
- [ ] `../MEDALIQ-MOBILE/CLAUDE.md` (si la feature requiere mobile)

## Specs a leer
<!-- Identifica el spec del modulo que toca tu feature. Ver lista en MEDALIQ-PROJECT/CLAUDE.md seccion Specs. -->
- [ ] `../specs/_traps.spec.md` <- SIEMPRE
- [ ] `../specs/_mobile_mirror.spec.md` (si toca web Y mobile)
- [ ] `../specs/[modulo].spec.md` <- especificar cual

## Proyectos involucrados
- [ ] MEDALIQ-PROJECT (web + API)
- [ ] MEDALIQ-MOBILE

## Scope — que toca

### Web (MEDALIQ-PROJECT)
- Modelos DB / migraciones:
- Endpoints (`src/app/api/`):
- Domain use cases (`src/domain/`):
- UI pages/components:

### Mobile (MEDALIQ-MOBILE)
- Screens (`app/`):
- API calls (`src/api/`):

## Fuera de scope — NO tocar sin consultar
-

## Estado
- [ ] Sin empezar
- [ ] En progreso — web
- [ ] En progreso — mobile
- [ ] Web completa, mobile pendiente
- [ ] Completa — pendiente PR
- [ ] Mergeada a develop

## Donde quede
<!-- LO MAS IMPORTANTE — que falta, proximos pasos exactos -->

## Decisiones tomadas
<!-- Tradeoffs, cambios de enfoque, por que se hizo asi -->

## Migraciones DB
<!-- Nombre exacto si se creo alguna -->
