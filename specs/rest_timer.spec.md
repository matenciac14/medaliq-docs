---
tags: [medaliq, spec, rest_timer, gym, mobile]
mirror: false
note: Feature mobile-native. Web solo configura defaults.
---

# Spec: REST_TIMER — Timer interactivo de descanso entre series
# Domain doc: [[entrenamiento]] · [[atleta]]
# Leer _traps.spec.md SIEMPRE antes de modificar codigo.

## TL;DR
- 3 endpoints web (config), 3 endpoints mobile (config)
- Modelos nuevos: ExerciseRestConfig, RestTimerDefaults
- Dependencias: gym.spec.md, plan_sessions.spec.md
- Trampas: timer corre en mobile nativo, NO en servidor. Backend solo persiste configuracion
- Mirror mobile: NO — timer es mobile-only, web solo CRUD de defaults

---

## 4 preguntas obligatorias

**1. Que puede hacer el usuario?**
El atleta puede configurar tiempos de descanso por ejercicio y recibir un countdown interactivo entre series durante su sesion de gym. Puede ajustar (+30s/-30s), saltar el timer, o dejar que expire naturalmente.

**2. Que resultado obtiene?**
Timer visual circular con countdown, vibracion y sonido al expirar, preview de la siguiente serie/ejercicio, y transicion fluida al registro de la siguiente serie. Configuracion persistida por ejercicio para futuras sesiones.

**3. Que debe respetar?**
- Timer es 100% client-side (mobile). El backend NO trackea estado del timer
- Defaults por categoria: compuestos 120s, aislamiento 60s, cardio sin timer
- Rango valido: 15s-600s (maximo 10 min)
- Timer arranca automaticamente al completar una serie SI auto-start esta habilitado
- Timer debe funcionar con app en background (local notification)

**4. Como se demuestra?**
- Test: completar serie → timer arranca → countdown visible → vibracion al terminar
- Test: configurar 90s para bench press → cerrar app → reabrir → bench press muestra 90s
- Test: timer en background → local push notification al expirar

---

## Contratos de la AI

- [ ] El timer es 100% mobile-native. No hay WebSocket, no hay polling, no hay estado en el servidor
- [ ] Backend solo persiste `defaultRestSeconds` por ejercicio y defaults globales del atleta
- [ ] Mobile usa expo-notifications (local) para timer en background
- [ ] El timer NO esta vinculado a SessionLog ni GymSession — es un overlay de UX
- [ ] Si el ejercicio no tiene defaultRestSeconds, usar el default por categoria (compuesto/aislamiento)

---

## Endpoints

### Web (solo configuracion)

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| PATCH | `/api/athlete/gym/exercises/[exerciseId]/rest-config` | auth() | 60/min | Configurar defaultRestSeconds para un ejercicio |
| GET | `/api/athlete/gym/rest-defaults` | auth() | 300/min | Obtener defaults globales del atleta |
| PATCH | `/api/athlete/gym/rest-defaults` | auth() | 60/min | Actualizar defaults globales |

### Mobile

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/mobile/gym/rest-defaults` | getMobileUser() | 300/min | Defaults del atleta (auto-start, sound, vibration) |
| PATCH | `/api/mobile/gym/rest-defaults` | getMobileUser() | 60/min | Actualizar defaults |
| PATCH | `/api/mobile/gym/exercises/[exerciseId]/rest-config` | getMobileUser() | 60/min | Configurar rest para un ejercicio |

---

## Contratos de datos

### PATCH exercises/[exerciseId]/rest-config

Request:
```ts
{ defaultRestSeconds: number } // 15-600
```

Response 200:
```ts
{ ok: true, defaultRestSeconds: number }
```

Logica:
1. Auth check
2. Validar exerciseId pertenece al usuario o es global
3. Upsert: si el atleta ya tiene override, actualizar. Si no, crear
4. Return updated value

### GET rest-defaults

Response 200:
```ts
{
  autoStart: boolean                // default: true
  soundEnabled: boolean             // default: true
  vibrationEnabled: boolean         // default: true
  defaultCompoundSeconds: number    // default: 120
  defaultIsolationSeconds: number   // default: 60
}
```

### PATCH rest-defaults

Request:
```ts
{
  autoStart?: boolean
  soundEnabled?: boolean
  vibrationEnabled?: boolean
  defaultCompoundSeconds?: number   // 15-600
  defaultIsolationSeconds?: number  // 15-600
}
```

---

## Modelos DB involucrados

```prisma
// Nuevo modelo para override por ejercicio-atleta
model ExerciseRestConfig {
  id                 String @id @default(cuid())
  userId             String
  exerciseId         String  // puede ser Exercise global o del coach
  defaultRestSeconds Int     // 15-600

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, exerciseId])
  @@index([userId])
}

// Nuevo modelo para defaults globales del atleta
model RestTimerDefaults {
  id                      String  @id @default(cuid())
  userId                  String  @unique
  autoStart               Boolean @default(true)
  soundEnabled            Boolean @default(true)
  vibrationEnabled        Boolean @default(true)
  defaultCompoundSeconds  Int     @default(120)
  defaultIsolationSeconds Int     @default(60)

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
}
```

---

## Mobile — Componentes nativos (NO son endpoints, son mobile-only)

### RestTimerOverlay

Componente principal del timer. Se muestra como overlay sobre la pantalla de sesion.

Props:
```ts
{
  durationSeconds: number
  onComplete: () => void
  onSkip: () => void
  nextSetPreview: {
    exercise: string
    setNumber: number
    targetWeight: number
    targetReps: number
  } | null
}
```

Comportamiento:
1. Countdown circular animado (Reanimated)
2. Botones: +30s, -30s, Skip
3. Preview de siguiente serie/ejercicio debajo del timer
4. Tip contextual del ejercicio actual (texto estatico de exercise.instructions)
5. Al expirar: vibracion (`Haptics.notificationAsync`) + sonido
6. Si app en background: `scheduleNotificationAsync` de expo-notifications (local, no push)

### useRestTimer hook

```typescript
function useRestTimer(config: {
  exerciseId: string
  isCompound: boolean
  overrideSeconds?: number
}) {
  // Determina duracion: override > exercise config > category default > global default
  // Retorna: { seconds, isRunning, start, pause, skip, addTime, subtractTime }
}
```

### Integracion con flujo de sesion

Punto de integracion: cuando el atleta completa un set (POST set log):
1. SetLog se guarda → response ok
2. Si autoStart: timer arranca automaticamente
3. Timer overlay aparece sobre la pantalla de sesion
4. Al expirar o skip → overlay desaparece → foco en siguiente serie

Si es el ULTIMO set del ejercicio:
- Timer muestra "Siguiente: [nombre ejercicio]" en vez de "Serie X de Y"
- Al expirar → transicion al siguiente ejercicio

---

## Reglas de negocio (invariantes)

1. Timer es client-side only — el backend NO sabe si el timer esta corriendo
2. `defaultRestSeconds` rango: 15-600 (15s minimo, 10min maximo)
3. Prioridad de duracion: override manual > exercise config > category default > global default
4. Categorias: compound (squat, deadlift, bench, row, overhead press) = 120s, isolation = 60s
5. Cardio exercises: sin timer (no arranca)
6. Background timer: usa `expo-notifications scheduleNotificationAsync` con trigger `{ seconds: remaining }`
7. El timer NO afecta `durationMin` registrado de la sesion (GymSession.durationMin)

---

## Trampas

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| Timer en servidor | Parece que necesita WebSocket/polling | Es 100% client-side. Backend solo guarda config |
| Background notification | Parece push notification | Es LOCAL notification (expo-notifications, no expo_push.ts) |
| durationMin de sesion | Timer deberia sumar al duration | Timer NO afecta durationMin — la sesion dura lo que dura |
| Exercise categoria | Parece que necesita campo nuevo | Se infiere del targetMuscle o del ejercicio — no campo nuevo en schema |

---

## Plataforma por feature

| Feature | Web | Mobile |
|---------|-----|--------|
| Configurar defaults (auto-start, sound, duracion) | PATCH /api/athlete/gym/rest-defaults | PATCH /api/mobile/gym/rest-defaults |
| Configurar por ejercicio | PATCH /api/athlete/gym/exercises/[id]/rest-config | PATCH /api/mobile/gym/exercises/[id]/rest-config |
| Timer countdown interactivo | NO | RestTimerOverlay component |
| Timer en background | NO | expo-notifications local |
| Vibracion/sonido al expirar | NO | Haptics + Audio |
| Preview siguiente serie | NO | RestTimerOverlay |

---

## Tests requeridos

### Backend
- [ ] PATCH rest-config: `defaultRestSeconds < 15` → 400
- [ ] PATCH rest-config: `defaultRestSeconds > 600` → 400
- [ ] PATCH rest-config: upsert — crear y luego actualizar mismo exerciseId
- [ ] GET rest-defaults: usuario sin config → devuelve defaults (120/60/true/true/true)
- [ ] PATCH rest-defaults: parcial — solo autoStart → otros campos intactos

### Mobile (unit tests)
- [ ] useRestTimer: exercise con override → usa override
- [ ] useRestTimer: exercise sin override, compound → 120s
- [ ] useRestTimer: exercise sin override, isolation → 60s
- [ ] RestTimerOverlay: countdown decrementa correctamente
- [ ] RestTimerOverlay: +30s agrega tiempo
- [ ] RestTimerOverlay: skip llama onComplete

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| 2026-11-08 | Spec creada | Analisis de gaps de retencion — timer de descanso interactivo |
