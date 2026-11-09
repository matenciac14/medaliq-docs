---
tags: [medaliq, spec, entrenamiento, gym]
---

# SESSION_SUMMARY — Resumen Post-Sesion

<!-- mirror: false -->
<!-- note: Mobile-first. Web muestra version simplificada en toast/modal -->

> Spec nueva. Pantalla de resumen al completar una sesion de entrenamiento (gym o running).
> Specs relacionadas: `gym.spec.md`, `plan_sessions.spec.md`
> Domain doc: [[entrenamiento]]

## TL;DR
- 1 endpoint mobile, 1 web (datos para resumen post-sesion)
- Modelos: SessionLog, GymSession, SetLog (lectura)
- Dependencias: gym.spec.md, plan_sessions.spec.md
- Trampas: PRs se detectan DURANTE la sesion (ya implementado), resumen es lectura post-facto
- Mirror: mobile pantalla completa, web modal/toast simplificado

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
Al completar una sesion (gym complete o log session), el atleta ve un resumen con: duracion, volumen total, calorias estimadas, PRs nuevos, musculos trabajados, y un boton para compartir.

**2. Que resultado obtiene?**
Pantalla de resumen con stats de la sesion recien completada. Opcion de compartir como imagen (share card). Sensacion de logro y cierre.

**3. Que debe respetar?**
- PRs ya se detectan en el flujo de gym/complete — NO re-detectar
- Calorias son estimacion (MET * peso * duracion) cuando no hay wearable
- El resumen se genera DESPUES de persistir la sesion — es read-only
- Volumen = sum(weight * reps) de todos los sets completados

**4. Como se demuestra?**
- Test: completar sesion gym → response incluye summary con volumen, PRs, duracion
- Test: sesion sin PRs → prs: [] (array vacio, no null)
- Test: sesion running → distancia y pace en vez de volumen

## Contratos de la AI

- [ ] El resumen es READ-ONLY — se genera a partir de datos ya persistidos
- [ ] PRs nuevos vienen del response de gym/complete (campo `newPRs`) — no re-computar
- [ ] Volumen total = sum(weightKg * repsCompleted) de SetLog WHERE completed = true
- [ ] Calorias: usar caloriesBurned de SessionLog/GymSession si existe, sino estimar con MET
- [ ] Share card es generada client-side (canvas/SVG) — NO endpoint de imagen en backend
- [ ] El endpoint retorna datos, la UI decide el layout

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/mobile/gym/session/[sessionId]/summary` | getMobileUser() | 300/min | Resumen de sesion gym completada |
| GET | `/api/mobile/log/session/[logId]/summary` | getMobileUser() | 300/min | Resumen de sesion running/libre |
| GET | `/api/athlete/gym/session/[sessionId]/summary` | auth() | 300/min | Resumen de sesion gym (web) |

### GET /api/mobile/gym/session/[sessionId]/summary

**Response 200:**
```ts
{
  sessionId: string
  type: 'gym'
  completedAt: string             // ISO 8601
  durationMin: number

  // Gym-specific
  totalVolume: number             // kg * reps, sum de todos los sets
  totalSets: number               // sets completados
  totalExercises: number          // ejercicios unicos

  // PRs (ya detectados en complete)
  newPRs: Array<{
    exerciseName: string
    type: 'weight' | 'reps' | 'volume'  // tipo de PR
    value: number
    unit: string                  // 'kg', 'reps', 'kg×reps'
  }>

  // Musculos trabajados
  musclesWorked: Array<{
    name: string                  // targetMuscle del ejercicio
    sets: number                  // cuantos sets para ese musculo
  }>

  // Estimacion
  caloriesBurned: number | null   // real si wearable, estimado si no
  caloriesEstimated: boolean      // true si fue estimacion MET

  // Contexto
  workoutName: string | null      // nombre del template si aplica
  planContext: string | null       // "Semana 4 de 12 — Hipertrofia" si hay plan
}
```

### GET /api/mobile/log/session/[logId]/summary

**Response 200:**
```ts
{
  logId: string
  type: 'running' | 'free'
  completedAt: string
  durationMin: number | null

  // Running-specific
  distanceKm: number | null
  avgPaceSecPerKm: number | null  // pace en seg/km
  avgPaceFormatted: string | null // "5:30 min/km"

  // General
  caloriesBurned: number | null
  caloriesEstimated: boolean
  rpe: number | null

  // Contexto
  sessionType: string             // RODAJE_Z2, FARTLEK, etc.
  planContext: string | null
}
```

**Logica (ambos endpoints):**
1. Auth + ownership check (sesion pertenece al usuario)
2. Cargar sesion con datos completos (sets, ejercicios, PRs)
3. Calcular aggregates (volumen, musculos, etc.)
4. Si caloriesBurned es null → estimar con MET table
5. Return summary

## Modelos DB involucrados

No requiere modelos nuevos. Solo lectura de:

```prisma
GymSession    { id, athleteId, date, durationMin, completed, assignedWorkout, sets }
SetLog        { gymSessionId, exerciseName, weightKg, repsCompleted, completed, isPR }
SessionLog    { id, userId, completedAt, durationMin, distanceKm, rpe, caloriesBurned, avgPaceSecPerKm, discipline, freeSessionType }
Exercise      { name, targetMuscle }  // para musclesWorked
TrainingPlan  { name, totalWeeks }     // para planContext
PlanWeek      { weekNumber, phase }    // para planContext
```

## Reglas de negocio (invariantes)

1. **Volumen total**: sum(weightKg * repsCompleted) donde completed = true. Sets incompletos no cuentan.
2. **musclesWorked**: agrupado por targetMuscle de los ejercicios, conteo de sets por musculo. Ordenado desc por sets.
3. **newPRs**: viene del campo `isPR: true` en SetLog (ya marcado durante gym/complete). NO re-detectar.
4. **avgPaceFormatted**: `Math.floor(pace/60):${(pace%60).toString().padStart(2,'0')}` min/km.
5. **caloriesEstimated**: true si NO hay wearable data y se uso tabla MET. UI debe mostrar "~" si true.
6. **planContext**: format `"Semana {weekNumber} de {totalWeeks} — {phase}"`. null si no hay plan activo.
7. **Ownership**: sessionId/logId DEBE pertenecer al userId autenticado. 404 si no.

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Re-detectar PRs | Parece que hay que correr deteccion de PRs | PRs ya estan marcados (isPR en SetLog) — solo leerlos |
| Share card endpoint | Parece que el backend genera imagen | Client-side canvas/SVG — backend solo provee datos |
| Volumen con sets incompletos | Sumar todo | Solo sets con completed: true cuentan |
| caloriesBurned: 0 vs null | 0 significa sin ejercicio | null = no se sabe. 0 = se midio y fue 0 (raro). Usar null |

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Datos del resumen | GET /api/athlete/gym/session/[id]/summary | GET /api/mobile/gym/session/[id]/summary |
| Pantalla completa post-sesion | NO — modal/toast simple | SI — pantalla dedicada con animaciones |
| Share card | Boton share → genera imagen client-side | Boton share → genera imagen + expo-sharing |
| Musculos trabajados visual | Texto simple | SVG anatomico (MuscleMap existente) |
| PRs destacados | Badge en toast | Animacion de celebracion |

## Tests requeridos

- [ ] GET gym summary: volumen calculado correctamente (sum weight * reps, solo completed)
- [ ] GET gym summary: musclesWorked agrupado por targetMuscle
- [ ] GET gym summary: newPRs lee isPR de SetLog, no recalcula
- [ ] GET gym summary: sesion sin PRs → prs: []
- [ ] GET gym summary: caloriesBurned null → estima con MET, caloriesEstimated: true
- [ ] GET running summary: pace formateado correctamente (300 → "5:00")
- [ ] GET running summary: sin distancia → distanceKm: null, pace: null
- [ ] Auth: sesion de otro usuario → 404
- [ ] planContext: con plan activo → formato correcto
- [ ] planContext: sin plan → null

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — resumen post-sesion |
