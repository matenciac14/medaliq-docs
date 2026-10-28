# [MODULE-ID] — [Nombre del modulo]

<!-- mirror: true|false -->
<!-- mirror-endpoints: GET/POST /api/athlete/X ↔ /api/mobile/X (listar pares) -->
<!-- note: si mirror:false, explicar por que (ej: "coach es web-only") -->

> Spec extraida del codigo real. Ultima actualizacion: YYYY-MM-DD.
> Fuente canonica: esta spec refleja el comportamiento ACTUAL del codigo, no el deseado.
> Specs relacionadas: `otra.spec.md` (si aplica)

<!-- LECTURA PROGRESIVA:
  Capa 1 (SIEMPRE): TL;DR + Contratos AI
  Capa 2 (si toca endpoint): seccion del endpoint especifico
  Capa 3 (si toca DB): Modelos DB involucrados
  Capa 4 (si codigo raro): Trampas + Paridad
  Capa 5 (al final): Tests requeridos
  Regla: si la tarea se resuelve con Capa 1, NO leer el resto.
-->

## TL;DR
- N endpoints (X web, Y mobile)
- Modelos: Model1, Model2
- Dependencias: useCase(), helper()
- Trampas criticas: trampa1, trampa2
- Mirror mobile: descripcion breve de paridad

---

## Contratos de la AI

<!-- Lo que la AI DEBE saber antes de tocar este modulo. Si no lees esto, alucinaras. -->

- [ ] Regla 1
- [ ] Regla 2

---

## Endpoints

| Metodo | Path | Auth | Rate limit | Descripcion |
|--------|------|------|------------|-------------|
| GET | `/api/...` | `auth()` | 300/min | ... |
| POST | `/api/mobile/...` | `getMobileUser()` | 100/min | ... |

### `GET /api/...`

**Request:**
```ts
// Query params
{ param1: string }
```

**Response:**
```ts
{
  field1: string
  field2: number | null
}
```

**Logica:**
1. Paso 1
2. Paso 2

---

## Modelos DB involucrados

<!-- Solo los relevantes para este modulo, con los campos que importan -->

```prisma
model Example {
  id        String   @id @default(cuid())
  userId    String
  // ... campos relevantes
}
```

---

## Reglas de negocio (invariantes)

<!-- Lo que el codigo cumple pero NO es obvio leyendolo -->

1. **Regla**: descripcion clara
2. **Regla**: descripcion clara

---

## Trampas

<!-- Lo que la AI alucinara si no lee esto -->

| Trampa | Que parece | Que es realmente |
|--------|-----------|-----------------|
| ... | ... | ... |

---

## Paridad web <-> mobile

<!-- Si este modulo tiene endpoints espejo -->

| Web | Mobile | Divergencias |
|-----|--------|-------------|
| `/api/athlete/...` | `/api/mobile/...` | Misma logica, diferente auth |

---

## Tests requeridos

<!-- Casos minimos que deben pasar al modificar este modulo -->

- [ ] Caso 1
- [ ] Caso 2

---

## Historial de cambios

| Fecha | Cambio | Referencia |
|-------|--------|-----------|
| YYYY-MM-DD | Spec creada | Extraida del codigo |
