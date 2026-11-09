---
tags: [medaliq, spec, plataforma, notificaciones]
---

# SMART_NOTIFICATIONS — Notificacion Pre-Sesion Inteligente

<!-- mirror: false -->
<!-- note: Cron backend + push. Solo mobile recibe push contextual -->

> Spec nueva. Push notification personalizada antes de la sesion del dia con contexto del ultimo entrenamiento.
> Specs relacionadas: `notifications.spec.md`, `cron.spec.md`, `plan_sessions.spec.md`, `gym.spec.md`
> Domain doc: [[plataforma]] · [[entrenamiento]]

## TL;DR
- 1 cron endpoint nuevo (extension del patron existente session-reminder)
- Modelos: PlannedSession, SessionLog, GymSession, SetLog, AssignedWorkout (lectura)
- Dependencias: sendPushNotification() (push directo, sin registro in-app)
- Trampas: es push EFIMERO (sin Notification en DB), no duplicar con session-reminder existente
- Mirror: backend-only push, mobile solo recibe

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
El atleta recibe una push notification 30-60 minutos antes de su sesion planificada (o a la hora configurada) con contexto personalizado: "Hoy toca Piernas — tu ultimo squat fue 100kg x 8. Listo?"

**2. Que resultado obtiene?**
Push contextual que le dice: (1) que sesion tiene hoy, (2) dato relevante de la ultima vez que hizo esa sesion (PR, peso, distancia). Motiva y prepara al atleta sin abrir la app.

**3. Que debe respetar?**
- Push EFIMERO (como onboarding B2B, celebrate-pr) — NO crear registro Notification en DB
- No duplicar con session-reminder existente (ese se envia los lunes a las 12 UTC para toda la semana)
- Solo enviar si hay sesion planificada o rutina del dia
- Respetar timezone del atleta para el horario de envio
- Contexto limitado: 1 dato relevante, no un resumen completo

**4. Como se demuestra?**
- Test: atleta con plan y sesion de piernas hoy → push "Hoy toca Piernas — tu ultimo squat fue 100kg x 8"
- Test: atleta con rutina gym (sin plan) → push "Hoy toca Upper Body — tu ultimo bench fue 80kg x 10"
- Test: atleta sin sesion hoy → NO recibe push
- Test: cron sin CRON_SECRET → 401

## Contratos de la AI

- [ ] Push EFIMERO: usar `sendPushNotification()` directo, NO `createNotification()`. No crear registro en Notification table
- [ ] Patron identico a celebrate-pr y status-change: push directo sin persistencia
- [ ] session-reminder existente se envia los LUNES para toda la semana. smart_notifications se envia el MISMO DIA de la sesion. No compiten
- [ ] Contexto del ultimo entrenamiento: buscar la sesion mas reciente del MISMO tipo o del MISMO grupo muscular
- [ ] Solo enviar a atletas con pushToken no null
- [ ] Respetar User.timezone para determinar "hoy" y hora de envio
- [ ] Si no hay dato contextual (primer sesion de ese tipo) → push sin contexto: "Hoy toca Piernas. A darle!"

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| POST | `/api/cron/smart-session-notify` | CRON_SECRET | N/A | Push personalizado pre-sesion |

### POST /api/cron/smart-session-notify

**Auth:** `Authorization: Bearer CRON_SECRET`
**Schedule:** Cada hora de 6:00 a 20:00 UTC (el cron filtra por timezone del atleta)

**Logica:**
1. Verificar CRON_SECRET
2. Determinar hora UTC actual
3. Buscar atletas donde:
   - pushToken IS NOT NULL
   - User.timezone mapea a una hora local de ~30-60 min antes de la sesion (o 9:00 AM local como default)
   - Tienen sesion planificada HOY (PlannedSession del plan activo) O rutina del dia (AssignedWorkout con WorkoutDay del dow actual)
4. Para cada atleta (paginar con cursor, batch 100):
   a. Determinar sesion de hoy:
      - Si plan activo: PlannedSession del weekNumber + dayOfWeek actual
      - Si rutina sin plan: WorkoutDay del dow actual del AssignedWorkout activo
      - Si ambos: plan tiene prioridad (misma regla que dashboard)
   b. Buscar contexto:
      - Para gym/FUERZA: ultimo GymSession completado con sets del mismo grupo muscular → mejor set (max weight)
      - Para running: ultimo SessionLog con discipline=RUNNING → pace y distancia
      - Para otro tipo: ultimo SessionLog del mismo type → duracion
   c. Componer mensaje:
      - Con contexto: "Hoy toca {tipo} — tu ultimo {ejercicio} fue {peso}kg x {reps}. Listo?"
      - Sin contexto: "Hoy toca {tipo}. A darle!"
   d. sendPushNotification({ pushToken, title, body, data: { screen: 'session' } })
5. Retornar { ok: true, sent: number, skipped: number }

## Contexto por tipo de sesion

| Tipo sesion | Donde buscar contexto | Dato a mostrar |
|-------------|----------------------|----------------|
| FUERZA / gym day | Ultimo GymSession + SetLog del mismo muscleGroup | "{ejercicio} {peso}kg x {reps}" |
| RODAJE_Z2 / running | Ultimo SessionLog discipline=RUNNING | "{distancia}km en {pace} min/km" |
| INTERVALOS / FARTLEK / TEMPO | Ultimo SessionLog del mismo type | "{duracion}min" |
| TIRADA_LARGA | Ultimo SessionLog type=TIRADA_LARGA | "{distancia}km" |
| DESCANSO | NO enviar push | — |
| Cualquier otro | Ultimo SessionLog del mismo type | "{duracion}min" si existe |

## Modelos DB involucrados

No requiere modelos nuevos:

```prisma
// Lectura
User             { pushToken, timezone }
TrainingPlan     { userId, status: 'ACTIVE', startDate, totalWeeks }
PlanWeek         { planId, weekNumber }
PlannedSession   { weekId, type, dayOfWeek }
AssignedWorkout  { athleteId, isActive, template.days }
WorkoutDay       { dayOfWeek, label, muscleGroups }
GymSession       { athleteId, completed, sets }
SetLog           { exerciseName, weightKg, repsCompleted, completed }
SessionLog       { userId, discipline, freeSessionType, distanceKm, durationMin, avgPaceSecPerKm }
```

## Reglas de negocio (invariantes)

1. **Push efimero** — NO crear Notification record. Patron identico a celebrate-pr
2. **Prioridad plan > rutina** — si tiene plan activo con sesion hoy, usar esa. Si no, rutina
3. **No enviar en DESCANSO** — PlannedSession type=DESCANSO → skip
4. **Timezone-aware** — usar User.timezone para determinar "hoy" y hora local
5. **Dedup intrasesion** — si el cron corre cada hora, marcar con cache key `smart-notify:{userId}:{date}` en Redis (TTL 24h) para no enviar dos veces el mismo dia
6. **Contexto es "best effort"** — si no hay historial, enviar push generico. No fallar
7. **Solo atletas con pushToken** — skip silencioso si no tiene token

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| createNotification | Parece el patron correcto para push | Este es EFIMERO — usar sendPushNotification directo, sin DB record |
| session-reminder duplicado | Parece que ya existe | session-reminder se envia los LUNES para la semana. Este es el MISMO DIA, personalizado |
| Hora de envio | Parece que se envia a una hora fija | Depende del timezone del atleta — el cron corre cada hora y filtra |
| Dedup | Parece que no necesita | Si el cron corre cada hora, sin dedup el atleta recibe push repetido |
| dayOfWeek | Parece getDayOfWeek() simple | Usar todayDowInTz(timezone) — misma funcion que el calendario. Base-1 (1=Lun..7=Dom) |

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Cron de envio | POST /api/cron/smart-session-notify (backend) | N/A |
| Push notification | N/A | Recibe push con contexto |
| Registro in-app | NO (push efimero) | NO (push efimero) |
| Deep link | N/A | data: { screen: 'session' } → abre sesion del dia |

## Tests requeridos

- [ ] POST cron sin CRON_SECRET → 401
- [ ] Atleta con plan + sesion FUERZA hoy → push con contexto gym
- [ ] Atleta con plan + sesion RODAJE_Z2 hoy → push con contexto running
- [ ] Atleta con plan + sesion DESCANSO → NO recibe push
- [ ] Atleta con rutina (sin plan) + dia gym hoy → push con contexto
- [ ] Atleta sin sesion ni rutina hoy → NO recibe push
- [ ] Atleta sin pushToken → skip silencioso
- [ ] Atleta sin historial previo → push generico sin contexto
- [ ] Dedup: segundo run del cron en el mismo dia → no envia de nuevo
- [ ] Retorna { sent, skipped } correcto

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — notificacion pre-sesion inteligente |
