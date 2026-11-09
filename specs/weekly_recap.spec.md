---
tags: [medaliq, spec, plataforma, notificaciones]
---

# WEEKLY_RECAP — Resumen Semanal Automatico

<!-- mirror: false -->
<!-- note: Cron job backend + push notification. Mobile muestra el recap, web no -->

> Spec nueva. Push notification dominical con resumen de la semana del atleta.
> Specs relacionadas: `notifications.spec.md`, `cron.spec.md`, `dashboard.spec.md`
> Domain doc: [[plataforma]] · [[atleta]]

## TL;DR
- 1 cron endpoint nuevo, 1 endpoint mobile para obtener recap
- Modelos: SessionLog, GymSession, FoodLog, WeeklyCheckIn, Notification (lectura + creacion)
- Dependencias: createNotification(), sendPushNotification(), computeFoodTotals()
- Trampas: cron usa CRON_SECRET auth, recap es READ-ONLY de datos existentes
- Mirror: cron es backend-only, recap endpoint solo mobile

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
El atleta recibe una push notification cada domingo con su resumen semanal: sesiones completadas, PRs nuevos, calorias promedio, cambio de peso. Al tocar la notificacion, ve el detalle completo.

**2. Que resultado obtiene?**
Push: "Tu semana: 5 sesiones, 2 PRs, 2,100 kcal/dia, -0.3kg". Pantalla de detalle con metricas completas y comparacion vs semana anterior.

**3. Que debe respetar?**
- Cron protegido con CRON_SECRET (mismo patron que los 9 crons existentes)
- Solo enviar a atletas con al menos 1 actividad en la semana (no spam a inactivos)
- createNotification() con registro in-app + push
- Datos son lectura de modelos existentes — NO crear modelos nuevos
- Push notification es fire-and-forget (sendPushNotification pattern existente)

**4. Como se demuestra?**
- Test: cron ejecuta, atleta con 5 sesiones recibe push con "5 sesiones"
- Test: atleta sin actividad en la semana NO recibe push
- Test: cron sin Authorization Bearer → 401
- Test: recap endpoint retorna datos correctos de la semana

## Contratos de la AI

- [ ] Cron auth: `Authorization: Bearer ${CRON_SECRET}` — mismo patron que los 9 crons existentes
- [ ] Solo enviar a atletas con >= 1 SessionLog O GymSession completada en la semana (lunes a domingo)
- [ ] createNotification() crea registro DB + push. Tipo: 'WEEKLY_RECAP'
- [ ] Push es fire-and-forget — sendPushNotification().catch(() => {}). Si falla, el registro in-app queda
- [ ] Recap endpoint es lectura pura — no modifica datos
- [ ] Semana = lunes 00:00 UTC a domingo 23:59 UTC (misma convencion que el resto del sistema)
- [ ] El cron NO debe cargar todos los atletas en memoria — paginar con cursor

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| POST | `/api/cron/weekly-recap` | CRON_SECRET | N/A | Genera y envia recaps semanales |
| GET | `/api/mobile/recap/weekly` | getMobileUser() | 60/min | Recap de la semana actual o anterior |

### POST /api/cron/weekly-recap

**Auth:** `Authorization: Bearer CRON_SECRET`
**Schedule:** Domingo 21:00 UTC (4pm Colombia)

**Logica:**
1. Verificar CRON_SECRET
2. Calcular rango: lunes 00:00 UTC → domingo 23:59 UTC de la semana que termina
3. Paginar atletas con cursor (batch de 100):
   a. Para cada atleta: contar SessionLog + GymSession completadas en el rango
   b. Si count == 0 → skip
   c. Calcular metricas:
      - sessionsCompleted: count de dias unicos con actividad
      - newPRs: count de SetLog.isPR en la semana
      - avgKcal: promedio diario de FoodLog (solo dias con registro)
      - weightChange: ultimo WeeklyCheckIn.weightKg - primero de la semana
   d. createNotification({
        userId,
        type: 'WEEKLY_RECAP',
        title: 'Tu semana en Medaliq',
        body: `${sessionsCompleted} sesiones, ${newPRs} PRs, ${avgKcal} kcal/dia${weightChange ? `, ${weightChange > 0 ? '+' : ''}${weightChange.toFixed(1)}kg` : ''}`,
        metadata: { sessionsCompleted, newPRs, avgKcal, weightChange, weekStart, weekEnd }
      })
4. Retornar { ok: true, sent: number, skipped: number }

### GET /api/mobile/recap/weekly

**Query params:**
```ts
{
  week?: 'current' | 'previous'  // default: 'previous' (la semana que termino)
  tz?: string
}
```

**Response 200:**
```ts
{
  weekStart: string             // YYYY-MM-DD
  weekEnd: string               // YYYY-MM-DD

  // Entrenamiento
  sessionsCompleted: number     // dias unicos con actividad
  totalDurationMin: number      // suma de duraciones
  totalVolume: number | null    // kg*reps de gym (null si no hubo gym)
  newPRs: Array<{
    exerciseName: string
    type: 'weight' | 'reps' | 'volume' | 'pace'
    value: number
    unit: string
  }>

  // Nutricion
  avgKcal: number | null        // promedio diario (solo dias con registro)
  daysLogged: number            // dias con al menos 1 FoodLog
  avgProteinG: number | null

  // Peso
  weightStart: number | null    // primer peso de la semana
  weightEnd: number | null      // ultimo peso de la semana
  weightChange: number | null   // diferencia

  // Comparacion vs semana anterior
  comparison: {
    sessionsChange: number      // +2, -1, 0
    avgKcalChange: number | null
    volumeChange: number | null // % cambio
  } | null

  // Streak
  currentStreak: number         // racha actual de dias
}
```

**Logica:**
1. Auth getMobileUser()
2. Calcular rango de semana (current o previous)
3. Queries en paralelo:
   a. SessionLog + GymSession completadas del rango → sessionsCompleted, totalDurationMin
   b. SetLog.isPR del rango → newPRs
   c. GymSession sets → totalVolume
   d. FoodLog del rango → avgKcal, daysLogged, avgProteinG
   e. WeeklyCheckIn del rango → weightStart, weightEnd
   f. Mismas queries para semana anterior → comparison
   g. Streak actual (reutilizar logica de dashboard)
4. Serializar response

## Modelos DB involucrados

No requiere modelos nuevos:

```prisma
// Lectura
SessionLog     { userId, completedAt, durationMin, discipline }
GymSession     { athleteId, date, completed, durationMin }
SetLog         { gymSessionId, weightKg, repsCompleted, completed, isPR, exerciseName }
FoodLog        { userId, date, kcalLogged, proteinLogged }
WeeklyCheckIn  { userId, weightKg, createdAt }

// Escritura (solo el cron)
Notification   { userId, type, title, body, metadata }
```

## Reglas de negocio (invariantes)

1. **Solo atletas activos con actividad** — no enviar a atletas sin SessionLog ni GymSession en la semana
2. **sessionsCompleted = dias unicos** con actividad, no conteo de sesiones individuales (misma regla que dashboard weekSessionCount)
3. **avgKcal excluye dias sin registro** — no promediar 7 dias si solo 3 tienen FoodLog
4. **Comparacion vs semana anterior** — null si no hay datos de la semana anterior (primer semana del atleta)
5. **Cron paginado** — batch de 100 atletas con cursor para no cargar memoria
6. **Push fire-and-forget** — no bloquear el batch si un push falla
7. **Notification metadata** — guardar metricas en JSON para que el tap en la notificacion abra el recap sin re-query

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Cron sin auth | Parece endpoint publico | CRON_SECRET obligatorio — 401 sin el |
| Cargar todos los atletas | Parece un findMany simple | Debe paginar con cursor — 10K atletas en memoria mata el serverless |
| sessionsCompleted = count logs | Parece count de SessionLog | Es dias UNICOS con actividad (Set de fechas) |
| avgKcal con 0s | Parece promedio de 7 dias | Solo dias con FoodLog (daysLogged > 0) |
| WEEKLY_RECAP tipo | Parece necesitar enum Prisma | Notification.type es String libre — solo agregar a la lista de tipos en uso |

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Cron de generacion | POST /api/cron/weekly-recap (backend) | N/A |
| Push notification | N/A | Expo push via createNotification() |
| Pantalla de recap | NO | GET /api/mobile/recap/weekly |
| Notificacion in-app | GET /api/athlete/notifications (ya existe) | GET /api/mobile/notifications (ya existe) |
| Comparacion vs semana anterior | NO | Inline en recap screen |

## Tests requeridos

### Cron
- [ ] POST cron/weekly-recap sin Authorization Bearer → 401
- [ ] POST cron/weekly-recap: atleta con 3 sesiones → recibe push con "3 sesiones"
- [ ] POST cron/weekly-recap: atleta sin actividad → NO recibe push
- [ ] POST cron/weekly-recap: metadata incluye metricas correctas
- [ ] POST cron/weekly-recap: retorna { sent, skipped } correcto

### Recap endpoint
- [ ] GET recap/weekly: sessionsCompleted = dias unicos, no count de logs
- [ ] GET recap/weekly: avgKcal excluye dias sin FoodLog
- [ ] GET recap/weekly: comparison vs semana anterior calculado correctamente
- [ ] GET recap/weekly: week=current → semana en curso
- [ ] GET recap/weekly: week=previous → semana pasada completa
- [ ] Auth: sin JWT → 401

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — resumen semanal automatico |
