# Flujos de verificación — Pre/Post Fix

> Este documento define qué verificar ANTES y DESPUÉS de cada fix para asegurarse de que no se rompe nada.
> Ejecutar todos los flujos marcados ✅ al aplicar el fix correspondiente.

---

## FIX-01 — BUG-025: z.string().uuid() → z.string().min(1) en rutas de gym y log

**Archivos a modificar:**
- `src/app/api/gym/session/complete/route.ts` — líneas 9, 17, 18, 24, 25
- `src/app/api/log/session/route.ts` — línea 7 (`plannedSessionId`)
- `src/app/api/mobile/log/session/route.ts` — línea 9 (`sessionId`)

**Riesgo de romper:** BAJO. La validación se vuelve menos restrictiva — cualquier string no vacío pasa. Si el ID no existe en DB, el handler retorna 404 normalmente. Sin cambio de comportamiento funcional.

**Área de impacto:** gym web, log de sesiones plan (web + mobile)

### Pre-condición: confirmar que el bug existe

```bash
# Desde /gym/session, completar una sesión y ver el error en consola del browser:
# POST /api/gym/session/complete → 400 {"error":"Invalid uuid"}
```

### Flujos de verificación post-fix

#### VERIFY-01A — Happy path gym completo (CRITICO)
1. Login como Maria o Ana (atleta B2C, `featureGym = true`)
2. Ir a `/gym/session` — debe cargar con ejercicios
3. Expandir ejercicio → ingresar sets (peso + reps) → marcar como completados
4. Click "Finalizar sesión" → ajustar RPE → click "Guardar sesión"
5. **Esperado:** `POST /api/gym/session/complete → 201`, sin error. Redirect a `/gym?completed=1`. Banner "Sesión completada" o "🏆 Nuevo Récord Personal"

#### VERIFY-01B — Historial gym actualizado
1. Inmediatamente después de VERIFY-01A, ir a `/gym/history`
2. **Esperado:** La sesión recién completada aparece como primera entrada con fecha hoy, duración, ejercicios y sets. Si es primera sesión: badge "🏆 PR" en al menos 1 set.

#### VERIFY-01C — Validación del campo vacío (regresión negativa)
1. Desde DevTools, ejecutar:
   ```js
   fetch('/api/gym/session/complete', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({ dayOfWeek: 1, sets: [{ workoutExerciseId: '', setNumber: 1, weightKg: 60, repsCompleted: 10, completed: true }] })
   }).then(r => r.json()).then(console.log)
   ```
2. **Esperado:** `400` con error de validación (min(1) rechaza string vacío)

#### VERIFY-01D — ID inválido retorna 404, no 500
1. Desde DevTools:
   ```js
   fetch('/api/gym/session/complete', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({ assignedWorkoutId: 'id-que-no-existe', dayOfWeek: 1 })
   }).then(r => r.json()).then(console.log)
   ```
2. **Esperado:** `404 {"error":"Asignación no encontrada"}` — NO un 500

#### VERIFY-01E — Log de sesión del plan (ruta web)
1. Ir a `/plan` con atleta que tiene plan activo y una sesión FUERZA hoy
2. Click en el botón de log de la sesión FUERZA → modal de registro
3. Completar y guardar
4. **Esperado:** Sin error. La sesión queda marcada como completada. `POST /api/log/session → 200/201`

#### VERIFY-01F — Log mobile (si disponible)
1. En la app mobile, registrar una sesión del plan
2. **Esperado:** `POST /api/mobile/log/session → 201`, sin error 400 de UUID

---

## FIX-02 — MERGE bugfix/17-edge-a11y-fixes → main

**Archivos modificados por la rama:**
- `src/app/api/checkin/route.ts` — validación Zod min/max en campos numéricos (EDGE-06)
- `src/app/api/mobile/checkin/route.ts` — mismo fix para mobile
- `src/app/(athlete)/_components/SidebarClient.tsx` — aria-label en botón logout (A11Y-03)

**Riesgo de romper:** BAJO. La validación de checkin se vuelve más estricta (rechaza valores fuera de rango). El aria-label en logout no afecta comportamiento. Riesgo real: que un campo numérico válido quede fuera del rango configurado — verificar límites.

**Área de impacto:** checkin web, checkin mobile, accesibilidad sidebar

### Flujos de verificación post-merge

#### VERIFY-02A — Check-in web con valores válidos (CRITICO — regresión)
1. Login como atleta → ir a `/checkin`
2. Completar el formulario con valores normales:
   - Peso: `70` (kg)
   - Horas de sueño: `8`
   - Nivel de energía: `7` (1-10)
   - RPE sesión más dura: `6` (1-10)
   - Estrés: `4` (0-10)
3. Submit
4. **Esperado:** `POST /api/checkin → 200/201`. Sin errores. Redirect o confirmación de éxito.

#### VERIFY-02B — Check-in web con valores en el límite (edge cases válidos)
1. Repetir con valores extremos pero válidos:
   - Peso: `40` kg (mínimo razonable) y `200` kg (máximo razonable)
   - Sueño: `2` horas (mínimo) y `12` horas (máximo)
   - RPE: `1` y `10`
2. **Esperado:** Ambos casos deben retornar 201. Si retornan 400, revisar los límites en el schema Zod.

#### VERIFY-02C — Check-in web RECHAZA valores negativos (EDGE-06)
1. Desde DevTools, ejecutar:
   ```js
   fetch('/api/checkin', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({ weightKg: -50, sleepHours: -8, energyLevel: 5, hardestRpe: 5, stressLevel: 3 })
   }).then(r => r.json()).then(console.log)
   ```
2. **Esperado:** `400` con error de validación

#### VERIFY-02D — Check-in mobile con valores válidos (regresión)
1. En la app mobile, abrir la pantalla de check-in
2. Completar con valores normales y enviar
3. **Esperado:** Submit OK, sin error 400

#### VERIFY-02E — Logout botón accesible via teclado (A11Y-03)
1. En el dashboard del atleta (sidebar desktop, viewport > 1024px)
2. Tab hasta el botón de logout
3. Inspeccionar el elemento en DevTools
4. **Esperado:** El botón tiene atributo `aria-label="Cerrar sesión"` (o similar). No es solo un ícono sin label.

---

## FIX-03 — BUG-026: Dashboard dots de consistencia semanal (modo FREE)

**Archivo a modificar:** `src/app/(athlete)/dashboard/page.tsx`

**Root cause probable:**
- `GymSession.date` se setea como `new Date(); today.setHours(0,0,0,0)` en el servidor (UTC)
- `weekStart/weekEnd` en dashboard también se calculan con UTC, pero el atleta está en Bogotá (UTC-5)
- Si la sesión se completa el martes a las 20:00 Bogotá (01:00 UTC del miércoles), `GymSession.date` cae fuera de `weekStart..weekEnd` del dashboard
- Resultado: `weekGymSessions = []`, `weekSessionCount = 0`, dots vacíos

**Riesgo de romper:** MEDIO. Cambiar cómo se calculan weekStart/weekEnd podría afectar qué sesiones aparecen en el conteo.

**Área de impacto:** Solo `dashboardMode === 'FREE'` (atletas sin plan activo). No afecta TRAINING mode.

> **Nota:** Este fix es P2 — no es bloqueante. Investigar antes de implementar.

### Flujos de verificación post-fix

#### VERIFY-03A — Dot se llena inmediatamente tras completar gym (CRITICO para el fix)
1. Login como atleta FREE (sin plan activo, `dashboardMode === 'FREE'`)
2. Ir a `/gym/session` → completar sesión con al menos 1 set
3. Volver al `/dashboard`
4. **Esperado:**
   - Contador: "1/N días esta semana" (N = objetivo de rutina o 4 por defecto)
   - Dots: primer dot naranja (`bg-[#f97316]`)
   - Ambos deben coincidir

#### VERIFY-03B — Dot refleja el día correcto de la semana
1. Si hoy es miércoles: completar gym → verificar que solo hay 1 dot naranja (no el del lunes o martes sin actividad)
2. **Esperado:** Exactamente `weekSessionCount` dots naranjos, el resto grises

#### VERIFY-03C — Consistencia de sesiones de la misma semana (no semanas anteriores)
1. Verificar que una sesión gym de la semana pasada NO incrementa el contador esta semana
2. **Esperado:** Contador muestra solo días activos de la semana ISO actual

---

## Checklist de regresión transversal

Ejecutar después de CUALQUIER fix que modifique rutas de API o componentes compartidos:

| Test | Descripción | Archivo referencia |
|------|-------------|-------------------|
| ✅ B2C-07 | Check-in semanal web funciona | test-atleta-b2c.md |
| ✅ GYM-01/02 | `/gym/session` carga y registra sets | test-atleta-b2c.md |
| ✅ GYM-03 | Finalizar sesión retorna 201 | test-atleta-b2c.md |
| ✅ NUT-01 | `/nutrition` carga targets > 0 | test-atleta-b2c.md |
| ✅ SELF-03 | `/log/run` guarda corrida libre | test-atleta-b2c.md |
| ✅ B2B-06 | Check-in en contexto B2B | test-atleta-b2b.md |
| ✅ COACH-01 | Panel coach carga sin errores | test-coach-admin.md |
| ✅ TypeScript | `pnpm tsc --noEmit` sin errores | — |

---

## Orden recomendado de ejecución de fixes

```
1. FIX-01 (BUG-025)  — P0, 5 líneas de cambio, riesgo bajo, desbloquea gym
2. FIX-02 (EDGE-06 + A11Y-03) — P1, merge rama existente, verificar límites del schema
3. FIX-03 (BUG-026) — P2, investigar timezone antes de implementar
```

---

## Cómo ejecutar verificaciones rápidas en local

```bash
# Levantar dev server
cd /Users/miguelatencia/Desktop/MEDALIQ/MEDALIQ-PROJECT
pnpm dev

# Verificar TypeScript antes de cada PR
pnpm tsc --noEmit

# Probar endpoint directamente (reemplazar TOKEN con cookie de sesión)
curl -X POST http://localhost:3000/api/checkin \
  -H "Content-Type: application/json" \
  -d '{"weightKg":-50,"sleepHours":-8,"energyLevel":5,"hardestRpe":5,"stressLevel":3}'
# Esperado post-FIX-02: 400
```
