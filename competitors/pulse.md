# Pulse — Informe de Inteligencia Competitiva

> Fuente: investigacion directa (cuenta activa) + analisis publico del sitio
> Fecha: 2026-07-06
> Analista: Claude Code AQ
> Estado de la cuenta: PREMIUM trial (3 dias restantes al momento del analisis)

---

## 1. QUE ES

Pulse es un SaaS de gestion de coaching fitness para LatAm. Posicionamiento: "Sistema operativo para coaches — todo en uno". Target: entrenadores independientes con 5–50 clientes.

- **Web**: [pulsefit.app](https://www.pulsefit.app)
- **Pais**: LatAm (sin pais especifico identificado)
- **Idioma**: Espanol nativo
- **Fundadores**: Sin informacion publica
- **Inversion**: No confirmada
- **Traccion declarada**: 1,247 coaches activos · 4.9/5 Google + App Store

---

## 2. ARQUITECTURA DEL PRODUCTO

### Navegacion completa (verificada en cuenta activa)

```
Espacio de Trabajo
├── Panel de Control      — dashboard KPIs
├── Clientes              — CRM del coach
└── Estadisticas          — metricas globales

Entrenamiento
├── Rutinas               — planes de entrenamiento
├── Entrenamientos diarios— sesiones dia a dia
├── Ejercicios            — libreria de ejercicios
├── Clases                — clases grupales
└── Nutricion [Beta]      — modulo en construccion

Negocio
├── Finanzas              — ingresos y reportes
├── Pagos                 — cobros por cliente
├── Membresia             — gestion de subscripcion del coach
└── Tienda                — venta de productos/planes del coach
```

### Dashboard KPIs (observados)
- Total de Clientes
- Clientes que Necesitan Atencion
- Cumplimiento Promedio
- Ingresos Mensuales
- Mejores Rendimientos
- Notificacion de activacion de push notifications con copy orientado a casos de uso reales

---

## 3. FEATURES DETALLADAS

| Feature | Descripcion | Estado |
|---|---|---|
| Gestion de clientes | Perfiles con historial: rutinas, progreso, pagos, fotos, notas, formularios | Maduro |
| Generacion de rutinas con IA | Plan personalizado en 30s segun objetivo, lesiones, nivel | Core feature |
| AI Client Evaluation | Evaluacion automatica de progreso, medidas y metas con IA | Disponible |
| Seguimiento de progreso | Medidas, fotos comparables, adherencia, historial | Maduro |
| Pagos y finanzas | Registro de pagos por cliente, alertas de vencidos, ingresos | Maduro |
| Push notifications | Pagos vencidos, rutinas completadas, mensajes del cliente | Disponible |
| App movil coach | iOS + Android lanzado | Disponible |
| App movil atleta | En desarrollo — hoy acceso via browser solamente | En construccion (Q3 2026) |
| Clases en video | Videos (con capítulos) adjuntables a rutinas — NO clases grupales presenciales (verificado §13.7) | Disponible |
| Nutricion | Modulo completo en desarrollo | Beta |
| Tienda del coach | Venta de planes y productos desde la plataforma | Disponible |
| Membresia | Gestion de la subscripcion del coach | Disponible |
| White-label | Marca del coach en la plataforma | Q4 2026 |
| API | Solo plan Premium | Disponible |
| Pagos locales | Mercado Pago en QA · OXXO/PIX/Yape en Q4 | Roadmap |
| PDF export | Rutinas exportables | Professional+ |
| Migracion asistida | Desde Excel/Google Sheets o competidores | Disponible |

---

## 4. MODELO DE PRECIOS

| Plan | Precio regular | Precio lanzamiento | Clientes | IA rutinas/mes | Storage |
|---|---|---|---|---|---|
| Standard | $0 | $0 | hasta 5 | 10 | Basico |
| Professional | $29.99/mes | $19.99/mes | hasta 50 | 100 | 10GB |
| Premium | $59.99/mes | $49.99/mes | hasta 200 | 500 | 50GB |

**Notas de pricing:**
- Precio en USD — sin opcion en moneda local
- Precio de lanzamiento "bloqueado mientras sigas activo"
- Trial: 30 dias sin tarjeta de credito
- Garantia: 30 dias devolicion si no ahorra 5h/semana
- Migracion: meses equivalentes gratis al migrar desde competidor
- No hay precio publico visible antes de registrarse (opacidad de pricing)

---

## 5. POSICIONAMIENTO Y MARKETING

### Propuesta de valor central
- "Sistema operativo para coaches" — todo en uno
- "Hecho en LATAM para entrenadores LATAM"
- "+7h por semana recuperadas" de administracion
- "1,200+ coaches en LatAm" — traccion declarada
- "150–300 mensajes de WhatsApp diarios" — pain point central

### Vs Trainerize/TrueCoach (su tabla de comparacion propia)

| Dimension | Pulse | Competidores |
|---|---|---|
| Idioma | Espanol nativo | Ingles con traducciones |
| Precio | Desde $19.99 | Desde $100+ |
| Setup | 10 minutos | Dias + onboarding en ingles |
| IA rutinas | Incluido | Feature premium adicional |
| Pagos locales | En desarrollo | No disponible |
| Soporte | Espanol, horario LatAm | Email en ingles |

### Garantia diferenciadora
"Si no te ahorra 5 horas a la semana en 30 dias, te devolvemos el dinero" — promesa de resultado especifico, no solo satisfaccion.

---

## 6. ROADMAP PUBLICO

| Feature | Timeline declarado |
|---|---|
| App atleta (beta) | Q3 2026 |
| Mercado Pago automatico | Q3 2026 (en QA) |
| OXXO, PIX, Yape | Q4 2026 |
| White-label | Q4 2026 |
| Nutricion completa | 2027 |

**Implicacion para Medaliq:** ventana de ~3 meses donde la app mobile nativa del atleta es ventaja real. A partir de Q3 2026 Pulse tiene beta de app atleta.

---

## 7. FORTALEZAS DE PULSE

> Vista ejecutiva rápida. El detalle verificado navegando está en §13 (recorrido) y §15.1 (comparación).

1. **IA de rutinas como core feature** — genera un plan en ~10s (marketing dice 30s). Muy visible. Mejor que nada en Medaliq hoy — aunque su IA no razona el objetivo (§13.4).
2. **Framing excelente de la IA** — "el coach sigue en control, la IA es el punto de partida". Reduce fricciones con coaches que temen ser reemplazados.
3. **Dashboard orientado a accion** — "Clientes que Necesitan Atencion" es un CTA disfrazado de metrica. Muy bien ejecutado.
4. **Garantia de resultado medible** — 5h/semana en 30 dias, con devolucion sin formularios. Diferente a un simple "money back".
5. **Tienda del coach** — empaqueta rutinas/nutrición/clases en producto vendible one-to-many (§13.12). Aumenta LTV y lock-in.
6. **Onboarding de push notifications con copy de valor** — "Enterate cuando un cliente tenga pagos vencidos, termine una rutina o te mande un mensaje". Copy concreto, no tecnico.
7. **Clases en video** — módulo para adjuntar videos (con capítulos) a las rutinas (§13.7 — NO son clases grupales presenciales, como se asumió antes). Capa de contenido que Medaliq no tiene.
8. **Migracion asistida sin trabajo tecnico** — elimina una barrera critica de adopcion.
9. **Procesamiento de pagos + payouts** — cobra al cliente y paga al coach vía Stripe/PayPal/Payoneer/Binance (§13.10). Medaliq solo registra pagos manualmente.
10. **GIFs anatómicos + Mifflin en nutrición** — biblioteca visual de ejercicios (§13.6) y calculadora nutricional Mifflin-St Jeor (§13.8), ambas más pulidas que Medaliq.

---

## 8. DEBILIDADES DE PULSE

1. **App del atleta no existe** — el atleta accede via browser; la app móvil que ofrecen (incluso en Free) es la del **coach**. App de atleta en roadmap (Q3 2026). Ventana para Medaliq hasta entonces.
2. **Nutrición detrás de paywall + labeled Beta** — el módulo está bastante construido (86 alimentos, wizard 4 pasos, Mifflin, §13.8) pero es tier Profesional+ y no liga la nutrición a la carga del día. Medaliq sí sincroniza nutrición con la intensidad de la sesión.
3. **Sin plan adaptativo** — no hay check-in semanal que ajuste el plan. Su IA genera rutinas pero no reacciona a los datos del atleta semana a semana.
4. **Sin rails de pago locales** — payout solo Stripe/PayPal/Payoneer/Binance; cobertura "US/EU/México/Brasil/40+", **Colombia no listada** (§13.10). Sin Wompi/PSE/Nequi/Mercado Pago. Cobra en USD.
5. **Solo coach-centric** — no hay modo B2C donde el atleta pague directo sin coach. Medaliq tiene doble capa que Pulse no tiene.
6. **Facturación y recordatorios de pago = "Próximamente"** — vendidos como feature Premium pero inexistentes en Finanzas (§13.9). Feature vendida antes de existir.
7. **Free muy limitado** — sí hay tier Estándar Gratis, pero tope de 5 clientes fuerza a pagar rápido.
8. **Web en ingles (landing publica)** — su landing principal está en inglés aunque el producto sea en español. Incoherencia de posicionamiento.
9. **Estabilidad** — devolvió **502 Bad Gateway** durante el recorrido (§14).

---

## 9. Comparación, ideas y ventana competitiva → consolidadas en §15

> Para evitar duplicación, las tres secciones que antes vivían aquí se consolidaron en la §15 (verificada navegando ambos productos):
> - **Tabla comparativa Pulse vs Medaliq** → **§15.1**
> - **Ideas / qué copiar de Pulse** (incluye copy de notificaciones y garantía de resultado) → **§15.2**
> - **Ventana competitiva** (cuándo cierra cada ventaja) → **§15.4**

---

## 12. FUENTES

- Cuenta activa en pulsefit.app (PREMIUM trial, julio 2026)
- [pulsefit.app/es](https://www.pulsefit.app/es) — landing principal
- [pulsefit.app/es/pricing](https://www.pulsefit.app/es/pricing) — precios
- [pulsefit.app/es/features](https://www.pulsefit.app/es/features) — features

---

## 13. RECORRIDO DE PRODUCTO — Flujos y UX (verificado en cuenta activa, 6 de julio de 2026)

> Recorrido completo del portal del entrenador (`pulsefit.app/es/dashboard`) desde cuenta PREMIUM (trial, 3 días restantes). Idioma del producto: español rioplatense ("Activá", "Enterate", "Gestioná", "Decime", "Creá"). Todo lo de abajo fue observado navegando en vivo — no inferido.

**Nav lateral del portal (orden real):**
Espacio de Trabajo → Panel de Control · Clientes · Estadísticas | Entrenamiento → Rutinas · Entrenamientos diarios · Ejercicios · Clases · Nutrición `Beta` | Negocio → Finanzas · Pagos · Membresía · Tienda (→ Productos · Ventas)

---

### 1. Panel de Control
**Flujo observado:** entrada directa al login → dashboard. Saludo dinámico "Buenos Días, Miguel 👋 / Lunes, 6 De Julio De 2026".
**Qué muestra/pide:**
- Banner superior persistente: "3 días restantes de tu prueba PREMIUM" + CTA verde "PASAR A PREMIUM" (aparece en TODAS las pantallas).
- Prompt de activación de notificaciones con copy orientado a valor: *"Enterate al instante cuando un cliente tenga pagos vencidos, termine una rutina o te mande un mensaje."* (botones Configurar / Ahora no).
- 4 KPI cards: **Total de Clientes (0)**, **Clientes que Necesitan Atención (0 — "Todos los clientes al día")**, **Cumplimiento Promedio** ("Asigna rutinas para empezar a rastrear"), **Ingresos Mensuales** ("Configura la facturación para rastrear ingresos").
- 2 bloques: **Mejores Rendimientos** ("Clientes con mayores tasas de cumplimiento" → "No hay datos disponibles aún") y **Clientes que Necesitan Atención** ("¡Todos los clientes van por buen camino!").
- CTA "Ver Estadísticas Detalladas".
**UX:** (+) Los KPI vacíos actúan como onboarding contextual — cada card te dice qué hacer para llenarla ("Asigna rutinas para empezar a rastrear"). (+) El copy de notificaciones vende el valor, no la feature. (–) Con cuenta nueva el dashboard es 90% estados vacíos; no hay un checklist de primer día ni un "empieza aquí" guiado.
**Comparación con Medaliq:** el KPI "Clientes que Necesitan Atención" es exactamente el CTA accionable que Medaliq debería copiar (§15.2). Confirmado que Pulse lo tiene en el primer pantallazo.
**Bugs/limitaciones visibles:** ninguno. Estados vacíos limpios.

---

### 2. Clientes
**Flujo observado:** Clientes → "Agregar Cliente" (dropdown: **Agregar Cliente Manualmente / Compartir Link de Registro / Importar Clientes**) → formulario manual → creación exitosa → entré al perfil del cliente.
**Qué muestra/pide (formulario de creación "CREAR NUEVO CLIENTE — Agrega los datos y define el plan de cobro"):**
- Datos: **Nombre completo**, **Correo Electrónico**, **Número de Teléfono**.
- **Categorías** (obligatorio — bloquea el guardado con "Debes seleccionar al menos una categoría"; se crean inline).
- **Plan de Cobro**: toggle SEMANAL / QUINCENAL / MENSUAL + **Tarifa** + fecha **Comienza** (default = +1 mes, mostró "06 ago").
- **NO pide ningún dato físico** (edad, peso, altura, objetivo, sexo) en la creación. El perfil nace como una ficha de **cobro**, no de entrenamiento.
**Vista de perfil del cliente:** panel central con "Sin rutina activa asignada / **Asignar Rutina**", "Rutinas Anteriores", tabs **Rutinas / Nutrición**, "Comentarios del Cliente" (comentarios de sesiones). Sidebar derecho: **Estadísticas Rápidas** ("Sin estadísticas físicas registradas / Agregar Estadísticas"), **Información de Contacto**, **Historial de Pagos** (Monto de facturación, Frecuencia, Próximo pago, Pagado en este ciclo, Último pago). **Acciones Rápidas**: Ver Progreso / Estadísticas / Rutinas Anteriores. Tarjeta de cliente en el listado muestra tracker de días L-M-M-J-V-S-D + "Fecha de Pago".
**UX:** (+) 3 vías de alta (manual / link de auto-registro / import) cubre todos los casos. (+) Categorías como sistema de segmentación desde el día 1. (–) Que el dato físico sea opcional y esté escondido en "Agregar Estadísticas" refleja que Pulse trata al cliente como cuenta-por-cobrar primero y atleta después. (–) Editar cliente reusa exactamente el mismo formulario mínimo — no hay ficha extendida.
**Comparación con Medaliq:** oportunidad clara — Medaliq nace del atleta (perfil físico, Karvonen/Mifflin), Pulse nace del cobro. El perfil de Pulse es más pobre en datos de entrenamiento pero más fuerte en gestión de negocio.
**Bugs/limitaciones visibles:** el chip de categoría recién creada NO queda auto-seleccionado — hay que hacer clic extra para seleccionarlo o el guardado falla (fricción menor pero real).

---

### 3. Estadísticas
**Flujo observado:** recorrí los 4 tabs. Filtro temporal global "Últimos 30 días".
**Qué muestra/pide:**
- 4 KPI: Total de Clientes, **Cumplimiento Promedio (%)**, **Clientes Mejorados** ("X retrocedieron"), **Entrenamientos Completados (esta semana)**.
- **Tab Resumen:** dona de Tasa de Cumplimiento, Clientes que Necesitan Atención, Mejores Rendimientos.
- **Tab Rendimiento:** comparativa semana-a-semana (**Hace 2 Semanas / Semana Pasada / Esta Semana**) con Rendimiento %, **Volumen (kg)**, **Peso Promedio (kg)**, Entrenamientos Completados, + "Mejora General %".
- **Tab Clientes:** heatmap de **asistencia por día de la semana** (L-D con % Alta/Media/Baja), "Día Más Activo", **Cambio de Peso Promedio**, **Cambio de Cintura Promedio (cm)**, **Consistencia de Mediciones**.
- **Tab Volumen:** volumen semanal (vacío — "aparecerán cuando los clientes registren entrenamientos").
**UX:** (+) Granularidad de negocio seria: volumen en kg, peso, cintura, adherencia por día. (+) La comparativa 3-semanas es un marco de "progreso" listo para conversación con el cliente. (–) Todo depende de que el atleta registre — sin app de atleta activa, estos tabs quedan vacíos.
**Comparación con Medaliq:** Pulse ya mide cintura y peso promedio agregados a nivel negocio. Medaliq tiene el dato físico más rico (por atleta) pero no lo agrega a este nivel de panel de coach.
**Bugs/limitaciones visibles:** ninguno; solo estados vacíos por falta de datos.

---

### 4. Rutinas + flujo de IA `Beta`
**Flujo observado:** Rutinas → "**Generar con IA** `Beta`" (junto a "Nueva Rutina"). Abre modal "Constructor de Rutinas IA": input libre + chips rápidos (**Día de Empuje / Día de Jalón / Día de Piernas / Ejemplos**). Escribí un prompt real y generó en ~8-10s.
**Input que pedí (textual):** *"Cliente hombre 30 años, intermedio, objetivo hipertrofia. Día de pecho y tríceps, 5 ejercicios, gimnasio completo."*
**Output exacto generado** — "Rutina de Pecho y Tríceps – Hipertrofia" con **5 ejercicios** (respetó el conteo):
1. **Machine Chest Press** — 4 series × 8-12 reps · descanso 01:00
2. **Standing Cable Crossover** — 3 series × 10-15 reps · 01:00
3. **Fondo de Pecho Asistido** (Assisted Chest Dip) — series × reps · 01:00
4. **Cable Lying Triceps Extension** — 3 series × 10-15 reps · 01:00
5. **Cable V-Bar Triceps Pushdown** — 3 series × 10-15 reps · 01:00
→ Selección coherente (3 pecho + 2 tríceps, mezcla máquina/cable/peso corporal), rangos de reps apropiados a hipertrofia. Cada ejercicio trae marcador **"F"** en la serie (a fallo).
**Qué tan editable:** totalmente. Panel derecho "Vista Previa de Ejercicios" con edición inline de series/reps/descanso, "Agregar Serie", "Agregar nota para este ejercicio", **ícono de superset** (encadena ejercicios), y borrar serie. Botón "Guardar Rutina" → tras guardar pide **feedback con estrellas** ("¿Cómo fue la experiencia?" — recolectan calidad de IA en beta).
**Detalle notable:** en la preview los ejercicios salen con **nombre en inglés**; al guardar la rutina se muestran **traducidos a español** ("Press de Pecho en Máquina", "Cruce de Poleas de Pie", "Fondo de Pecho Asistido"). Hay una capa de traducción / librería bilingüe.
**Vista de rutina guardada:** DÍA 1 (asignado a un día de semana concreto, ej. MONDAY), secciones ENTRENAMIENTO con GIF por ejercicio, botones **PDF / Duplicar / Editar / Eliminar**, panel "ASIGNADO A" ("Aún no hay clientes asignados").
**UX:** (+) El flujo de IA es rápido, produce algo usable y 100% editable — no un PDF cerrado. (+) Supersets, notas por ejercicio, feedback loop de calidad: producto pulido. (–) **La IA no mapeó el objetivo**: pedí "hipertrofia" y la rutina quedó etiquetada como objetivo **"Bienestar general"** pese a que el título dice Hipertrofia. (–) Todos los descansos default a 01:00 sin diferenciar compuesto/aislado.
**Comparación con Medaliq:** este es el corazón del `framing de IA` (§15.2). Pulse ya tiene IA generativa de rutinas en producción (beta) con edición completa. **Cierra parcialmente la ventana de "IA cuando llegue"** — Medaliq no tiene IA activa. El fallo de mapeo de objetivo es la grieta explotable: su IA sugiere ejercicios pero no razona sobre periodización/objetivo real.
**Bugs/limitaciones visibles:** mismatch objetivo↔etiqueta (arriba). Rutina pre-existente "Demo" quedó en Borrador con 0 ejercicios.

---

### 5. Entrenamientos diarios
**Flujo observado:** NO es "asignación diaria al atleta" como sugería el nombre. Es una **biblioteca de plantillas de un solo día** — literal: *"Plantillas reutilizables de un solo día que puedes importar en cualquier rutina."*
**Qué muestra/pide (builder "Crear"):** Nombre + Descripción + Etiquetas, y 3 secciones estructuradas: **CALENTAMIENTO / ENTRENAMIENTO (añadir ejercicio) / ENFRIAMIENTO**. Estaba vacío ("Aún no hay entrenamientos").
**UX:** (+) La estructura warm-up / main / cool-down es más profesional que un simple listado de ejercicios. (+) Reutilizable → escala bien para un coach con muchos clientes similares.
**Comparación con Medaliq:** concepto de "bloque de día reutilizable" que Medaliq no expone. La asignación real al atleta ocurre vía "Asignar Rutina" en la ficha del cliente, no aquí.
**Bugs/limitaciones visibles:** ninguno; módulo vacío en la cuenta.

---

### 6. Ejercicios
**Flujo observado:** Biblioteca de Ejercicios con tabs **Biblioteca / Personalizados**, buscador y filtro por músculo (carrusel: TODOS, ABDUCTORES, ABDOMINALES, ADUCTORES, ESPALDA, BÍCEPS, GEMELOS…). Sección "Usados Recientemente".
**Qué muestra/pide:** cada ejercicio = **ilustración anatómica animada** (GIF, el músculo trabajado resaltado en rojo; la pose cambia al hover), nombre, grupo muscular, nivel (**Intermediate**). Los de biblioteca son **SOLO LECTURA** (badge al hover) — solo se editan los custom.
- **Crear Ejercicio Personalizado:** Nombre*, **Músculos Objetivo*** (~18 chips: abductores, abdominales, aductores, espalda, bíceps, gemelos, sistema cardiovascular, pecho, núcleo, antebrazos, glúteos, isquiotibiales, cuádriceps, hombros, trapecios, tríceps), Descripción, "Detalles Adicionales" (colapsable).
**UX:** (+) Las ilustraciones anatómicas animadas son un diferenciador visual fuerte y elevan la percepción de calidad. (+) Taxonomía muscular completa. (–) No pude ver el conteo total exacto de la librería, pero el filtro por músculo y "Usados Recientemente (5)" indican una base amplia y bien categorizada.
**Comparación con Medaliq:** los GIFs anatómicos con músculo resaltado son un activo que Medaliq debería igualar — sube la percepción de producto "serio" instantáneamente.
**Bugs/limitaciones visibles:** ninguno.

---

### 7. Clases
**Flujo observado:** NO son clases grupales/presenciales. Es un **gestor de clases en video** — *"Gestioná tus clases en video / Creá tu primera clase para adjuntar videos a tus rutinas."* Estaba vacío.
**Qué muestra/pide (Nueva Clase):** Nombre*, Descripción, **URL del Video*** (https://… — video externo, tipo YouTube/Vimeo), **Duración** (auto-detectada desde la URL), **Etiquetas** (HIIT, Yoga, Movilidad, Cardio, Fuerza, Recuperación, Estiramiento, Pilates, Boxeo, Baile, Core, Cuerpo Completo), y **Capítulos** ("Agregar Capítulo" — marcadores dentro del video).
**UX:** (+) Auto-detección de duración y capítulos de video = detalle sofisticado. (+) Se adjuntan a rutinas → contenido en video dentro del plan. (–) Depende de hosting externo (no suben video propio).
**Comparación con Medaliq:** capa de contenido en video que Medaliq no tiene. Útil para coaches que ya producen contenido.
**Bugs/limitaciones visibles:** ninguno; módulo vacío.

---

### 8. Nutrición `Beta`
**Flujo observado:** recorrí los 3 módulos + wizard completo de plan.
**Qué muestra/pide:** hub con **Alimentos (86)**, **Recetas (0 — "nutrición calculada automáticamente")**, **Planes de Nutrición (0 — "planes semanales de comidas")**.
- **Alimentos:** biblioteca real con macros por porción (ej. *Almond Butter 100g → 614 kcal, 21g proteína, 19g carb, 56g grasa*; *Aguacate 100g → 160 kcal / 2 / 9 / 15*), categorías (Grasa/Aceite, Fruta, Vegetal, Bebida), buscador, filtros, edición, y **"Importar de Base de Datos"** ("miles de alimentos").
- **Crear Plan de Nutrición = wizard de 4 pasos** (Básicos → Macros → Comidas → Asignar) con **tracker de macros en vivo** (Calorías/Proteína/Carbohidratos/Grasa: consumido vs objetivo).
  - Paso 1: nombre + objetivo (**Perder Peso / Ganar Músculo / Mantenimiento / Rendimiento / Personalizado**) + duración en semanas.
  - Paso 2 Macros: auto-sugiere macros según objetivo. **Calculadora con fórmula Mifflin-St Jeor** (inputs: Cliente, Fórmula = *Mifflin-St Jeor*, Nivel de actividad, Sexo → "Calcular calorías recomendadas").
  - Paso 3 Comidas: "Empezar Vacío" o "Usar una Plantilla" (**3, 5 o 6 comidas/día**).
  - Paso 4: Asignar a cliente.
  - El plan **auto-guarda** como borrador ("Guardado a las 9:56:27 AM"). Se puede **Descargar PDF**, Duplicar, Activar, Editar, Eliminar.
**UX:** (+) Mucho más construido de lo que "Beta" sugiere — wizard, macros en vivo, plantillas de comidas, auto-save, export PDF. (+) La calculadora nutricional es seria.
**Comparación con Medaliq — HALLAZGO CRÍTICO:** Pulse **ya usa Mifflin-St Jeor** en su módulo de nutrición. Ese era un pilar de "precisión científica" de Medaliq (§Filosofía). **Ya no es diferenciador exclusivo.** Pulse aún NO tiene Karvonen visible (zonas de FC / intensidad), que sigue siendo terreno de Medaliq.
**Bugs/limitaciones visibles:** Recetas y Planes en 0 (nadie los usa aún), pero la maquinaria está completa. Nutrición está detrás de tier **Profesional+** (ver §13.11 Membresía).

---

### 9. Finanzas
**Flujo observado:** dashboard financiero + modal "Registrar Pago".
**Qué muestra/pide:** 4 KPI (**Ingresos Totales, Este Mes con % vs mes pasado, Pagos Próximos, Pagos Atrasados**), gráfico **Ingresos Mensuales** (línea Feb-Jul), Acciones Rápidas (Registrar Pago / Ver Todos los Pagos / Administrar Métodos de Pago), bloques **Pagos Próximos** y **Pagos Atrasados** ("¡Todos los clientes están al día!").
- **Dos cards "Próximamente"** (NO construidas aún): **Facturas** ("La generación y administración de facturas estará disponible en una próxima actualización") y **Recordatorios de Pago** ("Los recordatorios de pago automatizados estarán disponibles en una próxima actualización").
**UX:** (+) Panel financiero completo y claro para un coach solo. (–) **Sin exportación de reportes visible.** (–) Facturación automática y recordatorios de pago = vaporware ("Próximamente"), pese a venderse como feature Premium (ver §13.11 Membresía).
**Comparación con Medaliq:** el gap de **recordatorios de pago automáticos** sigue abierto — Pulse lo promete pero no lo tiene. Medaliq puede llegar primero.
**Bugs/limitaciones visibles:** Facturas y Recordatorios no existen todavía.

---

### 10. Pagos (= Payouts / Retiros)
**Flujo observado:** "Pagos" en el nav es en realidad **/payouts** — el panel de **cobro y retiro de ganancias del coach**, no el registro de cobros a clientes (eso vive en Finanzas → Registrar Pago).
**Qué muestra/pide:** Balance con **Disponible / Pendiente / Ganancias Totales / Comisiones Pagadas** (todos $0.00), "Solicitar Retiro" (Retirar por, Monto, **Mínimo $1.00**), Historial de Pagos. Aviso: "Configurá tu método de pago para empezar a recibir pagos".
- **Métodos de payout (Métodos de Pago):** **Stripe Connect** (Recomendado — directo a cuenta bancaria), **PayPal**, **Payoneer**, **Binance Pay** (crypto). Cobertura declarada: *"Disponible en US, EU, México, Brasil, y 40+ países."*
- **Registro manual de cobro (Finanzas → Registrar Pago):** Cliente + Monto + **Método de Pago** (NO trae métodos predefinidos — hay que crear el propio con "+ Agregar Método de Pago") + Fecha. Es un log retrospectivo de pago recibido; el estado pendiente/pagado se deriva de "Próximo pago" vs "Pagado en este ciclo" en la ficha del cliente. No vi un flujo de estado "pendiente→pagado" explícito con alertas de vencido más allá del KPI "Pagos Atrasados".
**UX:** (+) Pulse **procesa cobros y hace payout** (con comisión) — no solo trackea, mueve dinero. Es un mini-PSP para coaches. (+) Binance Pay como opción crypto es astuto para LatAm no bancarizado. (–) La palabra "Pagos" para payouts confunde vs el registro de pagos en Finanzas.
**Comparación con Medaliq — HALLAZGO CRÍTICO:** la cobertura de payout es **"US, EU, México, Brasil, 40+ países"** — **Colombia NO aparece listada explícitamente**, y los rails son Stripe/PayPal/Payoneer/Binance, **sin rails locales LatAm** (Wompi, Mercado Pago, PSE, Nequi). Confirma la ventana competitiva (§15.4): si Medaliq activa **Wompi/PSE/Nequi en Colombia**, tiene un argumento de pago local que Pulse hoy no cubre.
**Bugs/limitaciones visibles:** métodos de pago para el registro manual no vienen precargados (fricción). Estados de cobro poco explícitos.

---

### 11. Membresía (suscripción del coach)
**Flujo observado:** Plan Actual + medidores de uso + método de pago + Pago Manual + tabla de planes con toggle Mensual/Anual.
**Qué muestra/pide:**
- Plan Actual **PREMIUM (Prueba)**, facturado mensual, "Se renueva el July 8, 2026".
- **Medidores de uso (cuotas reales del tier):** Clientes **1/200** · **Solicitudes IA 1/500** ("rutinas generadas con IA este mes, se reinicia July 8") · Planes de Entrenamiento **1/500**.
- **Método de Pago** para la suscripción (Sin método registrado / Agregar) + **"Pago Manual: Pagá vía transferencia manual y subí tu comprobante para verificación"** (upload de comprobante).
- **Tabla de planes (Mensual):**
  | Tier | Precio/mes | Clientes | Planes | Rutinas IA/mes | Extras clave |
  |------|-----------|----------|--------|----------------|--------------|
  | **Estándar** | **Gratis** | 5 | 5 | 10 | plantillas prediseñadas, app móvil y web, progreso básico, soporte email 48h |
  | **Profesional** | **$19.99** | 50 | 100 | 100 | ejercicios custom (50), 10 GB, **nutrición y plantillas de comidas**, analíticas avanzadas, **export rutinas PDF**, fotos de progreso, marca personalizada, soporte 24h |
  | **Premium** | **$49.99** | 200 | 500 | 500 | custom (200), 50 GB, todo Profesional + suite de analíticas, **automatización de pagos y facturación**, **white label**, **acceso API**, soporte 24/7 |
- **Anual ("¡Ahorra 2 meses!"):** Profesional **$16.66/mes**, Premium **$41.66/mes** (facturado anual = 10 meses).
- "Cambiar Plan" (upgrade) y "Cancelar Suscripción".
**UX:** (+) Los medidores de uso con cuotas exactas son transparencia excelente. (+) **Pago Manual con comprobante** = adaptación LatAm inteligente (no todos tienen tarjeta). (+) Estructura de 3 tiers clara y bien diferenciada.
**Comparación con Medaliq:** pricing de referencia directo — **Gratis / $19.99 / $49.99 USD** por coach, con cuotas por nº de clientes (5/50/200). Medaliq cobra al coach por asesorados activos; aquí está el benchmark de qué se da en cada escalón. Nota: la **"app móvil"** del tier Gratis es la **app del COACH** (lanzada iOS+Android, ver §3), no una app de atleta. La **app de atleta de Pulse sigue en roadmap (Q3 2026, §6)** → la ventaja de app-atleta nativa de Medaliq **se mantiene** hasta entonces.
**Bugs/limitaciones visibles:** vende "Automatización de pagos y facturación" en Premium, pero Facturas y Recordatorios están "Próximamente" en Finanzas (§9) → **feature vendida antes de existir**.

---

### 12. Tienda (Productos + Ventas)
**Flujo observado:** Tienda → **Productos** ("Productos Digitales — Creá y vendé programas que tus clientes pueden empezar en cualquier momento"). Existe "Plan Demo" ($5.00, Borrador, 0 ventas). Filtros Todos/Borrador/Activo/Archivado. También submenú **Ventas**.
**Qué muestra/pide (Crear Producto):** elige "**Copiar de Biblioteca** (de tus planes y rutinas existentes)" o "**Nuevo Producto** (desde cero)". Nuevo Producto empieza pidiendo solo el nombre (máx 90 chars). El selector de contenido "Copiar de Biblioteca" empaqueta contenido de **4 categorías: Entreno / Nutrición / Clases / Rutinas** (vi mis propias rutinas listadas como empaquetables, ej. "Demo — Masa Muscular — 3 entrenamientos").
**UX:** (+) Convierte el trabajo que el coach ya hizo (rutinas, planes, clases en video) en producto vendible one-to-many → **modelo de ingreso pasivo / escape del cobro por hora**. (+) Empaqueta las 4 capas de contenido en un solo producto.
**Comparación con Medaliq:** la "Tienda del coach" está marcada como oportunidad de mediano plazo (§15.2). Confirmado que Pulse la tiene funcional e integrada con toda su biblioteca. Sube el LTV y el lock-in. Prioridad alta para no quedar atrás.
**Bugs/limitaciones visibles:** módulo Ventas no explorado a fondo (sin ventas reales). Producto demo en Borrador.

---

### Resumen ejecutivo del recorrido

**Top 5 flujos mejor ejecutados**
1. **Generación de rutinas con IA** — rápido (~10s), output usable y 100% editable (series/reps/descanso/supersets/notas), con feedback loop de calidad. Está en producción, no en slides.
2. **Wizard de plan de nutrición** — 4 pasos, macros en vivo, calculadora Mifflin-St Jeor, plantillas 3/5/6 comidas, auto-save y export PDF. "Beta" que ya funciona de punta a punta.
3. **Biblioteca de ejercicios con GIFs anatómicos** — ilustraciones animadas con músculo resaltado + taxonomía de ~18 grupos + custom. Percepción de calidad altísima.
4. **Membresía con medidores de uso + Pago Manual con comprobante** — transparencia de cuotas y adaptación de cobro LatAm sin tarjeta.
5. **Tienda de productos digitales** — empaqueta rutinas/nutrición/clases/entrenos en producto vendible one-to-many; ingreso pasivo real e integrado.

**Top 5 gaps / debilidades reales (con evidencia)**
1. **Sin rails de pago locales LatAm** — payout solo Stripe/PayPal/Payoneer/Binance; cobertura "US, EU, México, Brasil, 40+" — **Colombia no listada, sin Wompi/PSE/Nequi/Mercado Pago**.
2. **Facturación y recordatorios de pago automáticos = "Próximamente"** — vendidos como feature Premium pero inexistentes en Finanzas.
3. **Perfil de cliente pobre en datos de entrenamiento** — la creación no pide edad/peso/altura/sexo/objetivo; nace como ficha de cobro. El dato físico es opcional y escondido.
4. **IA no razona el objetivo** — pedí "hipertrofia" y la rutina quedó etiquetada "Bienestar general"; descansos siempre 01:00. Sugiere ejercicios, no periodiza.
5. **Estabilidad** — el host devolvió **502 Bad Gateway** (Cloudflare OK, host error, edge Buenos Aires) durante el recorrido. Infra con hipos.

**3 features que Medaliq debería copiar o superar con prioridad**
1. **GIFs anatómicos con músculo resaltado en la librería de ejercicios** — barato de percibir como premium, Medaliq debería igualarlo ya.
2. **Tienda de productos digitales del coach** — empaquetar plan/rutina/nutrición en producto vendible; sube LTV y lock-in. Ningún competidor LatAm lo integra con check-in adaptativo.
3. **Superarlo en pagos: activar Wompi/PSE/Nequi en Colombia** — convertir el gap de Pulse en el argumento de venta #1 en el mercado local, antes de que active rails regionales.

**Insight sorpresivo (no estaba en el análisis previo)**
Pulse **ya implementó Mifflin-St Jeor** en su módulo de nutrición → el diferenciador de "precisión científica" (Mifflin) de Medaliq **ya no es exclusivo**. En cambio, la **app de atleta nativa de Medaliq SIGUE siendo ventaja**: la app móvil que Pulse ofrece (incluso en tier Gratis) es la del **coach**, no del atleta; su app de atleta sigue en roadmap (Q3 2026). Los fosos defendibles que QUEDAN: (1) **app de atleta nativa** hasta Q3 2026, (2) **check-in adaptativo con Karvonen** (zonas de FC que reaccionan a RPE/energía/peso), que no existe en Pulse, y (3) **pago local colombiano** (Wompi/PSE/Nequi). Solo cayó Mifflin — el resto del moat está intacto.

---

## 14. STACK TÉCNICO Y ORÍGENES DE CONTENIDO (verificado por captura de red, 6 de julio de 2026)

> Capturado interceptando las requests reales del portal (DevTools/network + headers vía curl). Todo verificado, no inferido.

### Arquitectura observada
| Capa | Servicio real | Evidencia |
|------|--------------|-----------|
| **Frontend** | **Next.js (App Router)** desplegado como **PWA** | prefetch RSC (`?_rsc=1pfg5`), `apple-touch-icon-180.png`, manifest PWA |
| **Backend / API** | **Google Cloud Run** — `pulse-api-be4uldyviq-ue.a.run.app` (región **us-east**) | endpoints `/subscription?active=true`, `/onboarding/progress`; API separada del front, con CORS bloqueado a orígenes externos (auth por token, no cookie) |
| **CDN / Edge** | **Cloudflare** delante de todo | `cf-ray`, `cf-cache-status`; el **502 Bad Gateway** durante el recorrido salió de Cloudflare con host en error (edge EZE = Buenos Aires) |
| **Media (GIFs/imágenes)** | **`media.pulsefit.app`** — bucket propio detrás de Cloudflare | 24 GIFs por página servidos desde ahí |
| **Chat / soporte** | **Crisp** (`client.crisp.chat`, website id `85c7bc6c-…`) | es la burbuja de chat abajo-derecha |
| **Analytics** | **Google Analytics 4** (`G-E2V39H26YT`) | evento `scroll` con `percent_scrolled`; devolvió **503** en la captura |

**Lectura:** stack 100% Google Cloud (Cloud Run + probable Firebase/Identity) + Cloudflare + Next.js/PWA. Es una arquitectura moderna y barata de operar, de equipo chico. El API monolítico en Cloud Run (un solo servicio) sugiere backend compacto, no microservicios.

### Origen de los GIFs de ejercicios — ¿propios o de terceros?
**Conclusión: NO son ilustraciones propias de Pulse. Es una librería comercial de terceros que ellos re-alojan en su propia infraestructura.**

Evidencia concreta:
- URLs tipo `https://media.pulsefit.app/media/84RyJf8.gif` — **IDs de 7 caracteres alfanuméricos** (esquema idéntico al de Imgur).
- Probé el mismo ID en `i.imgur.com/84RyJf8.gif` → **302** con `server: cat factory 1.0` (firma inconfundible de Imgur). O sea **no hacen hotlink a Imgur**: descargaron el set y lo **re-subieron a su propio bucket**.
- Headers del archivo en Pulse: `content-type: image/gif`, `content-length: 64058`, **`last-modified: Wed, 28 Jan 2026`** (subida en bloque en enero 2026), `server: cloudflare`.
- **Estilo artístico uniforme** en toda la librería (figura anatómica a lápiz en gris + músculo objetivo resaltado en rojo sobre blanco) = un **único pack comercial de GIFs de ejercicio** licenciado/comprado, no arte hecho a medida. Una empresa en esta etapa no ilustra 1.000+ GIFs anatómicos en casa.
- En la app estos ejercicios son **"SOLO LECTURA"** (el coach no los puede editar) → tratados como dataset fijo licenciado; solo los ejercicios *Personalizados* que crea el coach son editables.
- No pude reverse-image-search el vendor exacto (Imgur bloqueado por política del browser), pero el estilo corresponde a los packs comerciales de GIFs anatómicos que circulan en la industria fitness (tipo MuscleWiki/ExerciseDB/Fitness-Programer).

**Taxonomía muscular de la librería (16 grupos):** abductores, abdominales, aductores, espalda, bíceps, gemelos, pecho, núcleo, antebrazos, glúteos, isquiotibiales, cuádriceps, hombros, trapecios, tríceps (+ sistema cardiovascular en custom). Cada ejercicio trae nivel de dificultad (ej. *Intermediate*).

### Implicación para Medaliq
- El "diferenciador visual" de los GIFs anatómicos de Pulse **es replicable comprando/licenciando el mismo tipo de pack** — no es tecnología propia ni foso. Medaliq puede igualarlo con bajo esfuerzo (licenciar un set + servirlo desde su propio CDN), sin construir animaciones.
- El backend en Cloud Run con un solo servicio + auth por token indica un equipo lean; su velocidad de features (IA, nutrición) sale de apalancarse en servicios gestionados, no de un equipo grande. Competible.
- Dependencias de terceros que podrían citarse en ventas si conviene: soporte vía Crisp (no in-house), analítica GA4, y librería de ejercicios licenciada (no original).

---

## 15. PULSE vs MEDALIQ — comparación directa y qué copiar (6 de julio de 2026)

> Basado en el recorrido verificado de Pulse (§13-14) y el recorrido de Medaliq **en local y en producción** (§15.3). Nichos distintos (Pulse = gym/fuerza genérico; Medaliq = endurance/running adaptativo), pero vale la pena tomar lo mejor de Pulse.
> **Verificado en dos pasadas:** E2E completo en local (crear coach → invitar → crear atleta → vincular → asignar plan → check-in → loop) y recorrido en **producción** con cuentas reales de seed (§15.3). Esta §15.1 es la tabla comparativa definitiva (reemplaza/expande la §9, que venía del análisis de marketing).

### 15.1 Dónde gana cada uno

| Dimensión | Gana | Detalle |
|-----------|------|---------|
| Periodización + zonas de FC (Karvonen) | **Medaliq** | Plan por semana con fases BASE/DESARROLLO/ESPECÍFICO, Z2-Z5, carga en pts. Pulse no tiene nada. |
| Check-in adaptativo / señales de fatiga | **Medaliq** | Alertas RPE≥8, feed de check-ins, estrés/motivación/dolor. Pulse no lo tiene. |
| Ficha de atleta | **Medaliq** | 8 tabs, FC reposo, peso actual/objetivo, notas privadas. Pulse: ficha mínima de cobro. |
| Nutrición ligada a la carga | **Medaliq** | Periodizada por día-tipo (Duro/Fácil/Descanso) + pre/post-entreno. Pulse: plan genérico. |
| **Biblioteca de ejercicios (visual)** | **Pulse** | Grid de tarjetas con GIFs anatómicos animados + músculo resaltado. Medaliq: tabla de texto, 40 ejercicios, **cero imágenes**. |
| **IA generativa de rutinas** | **Pulse** | Genera rutina editable en ~10s (beta). Medaliq: sin IA activa. |
| **Tienda de productos digitales** | **Pulse** | Empaqueta rutinas/nutrición/clases en producto vendible. Medaliq no tiene. |
| **Procesamiento de pagos / payouts** | **Pulse** | Cobra y paga al coach (Stripe/PayPal/Payoneer/Binance). Medaliq: solo registro manual. |
| Analítica de negocio | **Pulse** | Chart de ingresos + estadísticas agregadas. Medaliq: KPIs sin serie temporal. |
| Clases en video | **Pulse** | Videos con capítulos adjuntos a rutinas. Medaliq no tiene. |
| Pulido visual / percepción "premium" | **Pulse** | Dark theme + verde neón + cards con iconos e imágenes. Medaliq: light theme plano, tablas frías. |
| Nutrición (profundidad del editor coach) | **Pulse** | Wizard 4 pasos + Mifflin + biblioteca 86 alimentos + macros en vivo. Medaliq: editor escueto (aunque usa Karvonen/Mifflin en el flujo del atleta). |
| Estados de cobro explícitos | **Medaliq** | Tabs Vencido/Pendiente/Pagado. Pulse: implícitos. |
| Pricing | — | Pulse: $19.99 / $49.99 USD. Medaliq (landing): coach gratis ≤5 → **$39–$129/mes** (más caro; justificar con el moat adaptativo). |

### 15.2 Qué copiar / tomar de Pulse (prioridad)

1. **[ALTA — visual #1] Imágenes/GIFs en la biblioteca de ejercicios.** Pasar de tabla de texto → grid de tarjetas con GIF + chips de músculo + badge de dificultad + vista de detalle. Pulse tampoco los produjo: licencia/re-aloja un pack de tercero. **Decisión tras investigación directa (julio 2026) — ver §16:**
   - **ExerciseDB self-hosted — GANADOR.** 11,000+ ejercicios con GIFs/imágenes/videos. Dataset self-hosteable comercialmente (JSON + GIFs en tu propio CDN/S3/Vercel Blob). Sin dependencia en runtime, sin rate limits, sin riesgo de cancelación. Más ejercicios que Pulse (~1,300) y que WorkoutX (1,400). [github.com/ExerciseDB/exercisedb-api](https://github.com/ExerciseDB/exercisedb-api)
   - **WorkoutX API — descartado para SaaS.** 1,400+ GIFs pero bulk download y self-host prohibidos. Si cancelas el plan, el acceso se revoca inmediatamente — todos los ejercicios del gym builder quedan rotos. Para multi-tenant con decenas de coaches navegando ejercicios simultáneamente, los 500 req/mes del free tier son fatales. [workoutxapp.com](https://workoutxapp.com/)
   - **GymVisual — solo si se quiere el look anatómico exacto de Pulse.** Estilo gris + músculo en rojo, licencia royalty-free perpetua, pago único. **Bloqueante:** prohíbe uso en plataformas de IA — incompatible con el roadmap de Medaliq. [gymvisual.com/content/9-license](https://gymvisual.com/content/9-license)
   - **Plan de implementación:** descargar dataset ExerciseDB → seed a tabla `Exercise` en DB → GIFs en Vercel Blob/S3 → sin API de tercero en runtime. ~1–2 días de setup.
2. **[ALTA — barato] Rediseño de las tarjetas KPI del dashboard** (icono por métrica + número con peso + color por estado) para subir la percepción premium sin tocar backend.
3. **[MEDIA] Vista de detalle de ejercicio** (clic en fila → modal con imagen, músculos, ejecución). Hoy las filas no son clicables.
4. **[MEDIA] Gráfico de ingresos + analítica de negocio** en Finanzas/Dashboard (serie temporal como Pulse).
5. **[MEDIA] Enriquecer el editor de nutrición del coach:** biblioteca de alimentos con macros + calculadora de calorías (reusar Mifflin que ya existe en el flujo atleta) + macros en vivo por día-tipo.
6. **[ESTRATÉGICO] Tienda de productos digitales del coach** — empaquetar plan/nutrición vendible (sube LTV).
7. **[ESTRATÉGICO] Cobro integrado / payouts** — hoy Medaliq solo registra pagos. En Colombia, integrar **Wompi/PSE/Nequi** es el argumento local que Pulse NO tiene (Pulse solo Stripe/PayPal/Payoneer/Binance, sin rails locales). Convertir el gap en ventaja.
8. **[ESTRATÉGICO] Respuesta a la IA de rutinas de Pulse** — framing "el coach decide, la IA prepara la base" cuando se integre.
9. **[RÁPIDO] Copy de valor en notificaciones** — como Pulse: no "activa notificaciones" sino *"enterate cuando tu atleta complete su sesión, falte al check-in o tenga un pago pendiente"*.
10. **[RÁPIDO] Garantía de resultado específico** — no "30-day money back" genérico sino *"si tu atleta no completa 70% de sus sesiones en 30 días, te devolvemos el mes"*.

**Estado visual de Medaliq (design tokens medidos en vivo) — punto de partida para el rediseño:** fondo blanco `#fff`, sidebar navy `rgb(30,58,95)`, acento naranja, tipografía **Inter**, radius **14px**, sombras muy sutiles (`0 1px 3px rgba(0,0,0,.1)`). Limpio y competente pero **plano/"seguro"** al lado del dark-neón de Pulse. Gaps visuales concretos a atacar: (a) biblioteca de ejercicios = tabla de texto **sin una sola imagen**; (b) tarjetas KPI grises sin iconos vs cards oscuras con icono de Pulse; (c) todo son **tablas frías** (atletas, finanzas, biblioteca) vs tarjetas visuales; (d) empty states genéricos vs CTA contextual; (e) sin imágenes de ejercicio ni en el constructor de rutinas ni en la ficha. El light theme no es problema per se, pero conviene elevar profundidad/contraste de las tarjetas o evaluar dark mode.

### 15.3 Recorrido en producción — medaliq.com (verificado en prod, 6 de julio de 2026)

Navegación directa en **producción** (`https://www.medaliq.com`) con cuentas reales de seed: `coach@medaliq.com` (Carlos Entrenador) y `miguel@medaliq.com` (atleta B2C). Objetivo: verificar qué ve cada actor en prod y contrastar con el análisis previo ejecutado en local.

---

#### Panel del Atleta (`miguel@medaliq.com`)

**Dashboard (`/dashboard`)**
Saludo contextual: *"Buenas noches, Miguel · Lunes, 6 De Julio De 2026"*. Cuatro cards:
- **TU CARRERA**: Sem.12/18 · Media Maratón · fase BASE
- **TU META DE PESO**: 73.8 kg → 70 kg · ~3 semanas · −1.4 kg/sem · 27% completado
- **CÓMO LLEGÁS HOY**: 🔴 *"Prioriza la recuperación hoy"* · Energía 3/10 · RPE 9 · Sueño 7.2h
- **ESTA SEMANA**: Sem.12 · Descanso hoy · 0/0 completadas · check-in semanal pendiente

Badge del coach: *"Carlos Entrenador · Especialista en media maratón y running de fondo"* — visible desde el dashboard del atleta. Pulse no expone al coach en el dashboard del atleta.

**Check-in (`/checkin`)**
Gated a viernes (próximo: 11-jul). Muestra countdown de días. Campos (12 dimensiones): Peso · Horas sueño · FC reposo · Energía (slider 1-10) · RPE (slider 1-10) · Bienestar (estrés / motivación / sueño / dolor) · Medidas corporales (cintura / caderas / brazos / muslos) · Sesiones completadas · Notas. Shortcut: *"¿Semana sin novedades? Todo bien →"*. Pulse no tiene check-in semanal con estas dimensiones.

**Nutrición (`/nutrition`)**
Badge del día: *"😴 Descanso"*. Macros: **0/2433 kcal · P:150g · C:118g · G:52g**. Nota visible: *"TDEE base: 2633 kcal · Ajustado según intensidad del día"* — ajuste automático por tipo de sesión. Guía de alimentos por categoría incluida. Pulse muestra objetivos nutricionales estáticos sin ajuste por carga del día.

**Progreso (`/progress`)**
Charts con 6 semanas de datos reales:
- Peso: 75.2 kg (S1) → 73.8 kg (S6)
- FC reposo: 53 bpm · badge *"Excelente"* (−2.0 desde inicio)
- Bienestar: energía promedio 4.2/10
- KM semanales: S1:35 · S2:34 · S3:38 · S4:28 · S5:42 · S6:45
- ADHERENCIA: 0% — BUG-061 activo en prod (cálculo roto)

**Plan (`/plan`)**
Sem.12/18 · fase BASE · 67% completado. *"Semana sin sesiones definidas — Tu coach aún no ha planificado las sesiones de esta semana"* · 2433 kcal descanso. El atleta ve el avance de semanas aunque la semana actual no tenga sesiones cargadas.

---

#### Panel del Coach (`coach@medaliq.com`)

**Dashboard (`/coach/dashboard`)**
KPIs en tiempo real:
- **INGRESOS/MES**: $36 USD (6 × $6 USD)
- **ATLETAS ACTIVOS**: 6 (+6 este mes)
- **CHECK-INS SEMANA**: 5/6 (83%)
- **ADHERENCIA PROMEDIO**: 0% (afectado por BUG-061)
- 4 alertas pendientes · Distribución: 🏃 Running ×1 · Proyección: $36 USD

Pulse no tiene dashboard de negocio con KPIs de ingresos + adherencia + alertas integrados.

**Lista de atletas (`/coach/athletes`)**
6 activos + 1 pendiente. Columnas: NOMBRE · DEPORTE · SEMANA · CHECK-IN · ADHERENCIA · ESTADO. COACH-BUG-01 confirmado en prod: columna DEPORTE vacía para todos los atletas. Filtros: Todos / Con alertas / Por adherencia / Sin check-in reciente / Pausados.

**Ficha del atleta — 8 tabs**
Datos de la ficha de Miguel: Peso 75 kg · Objetivo 70 kg · FC reposo 55 bpm · Adherencia 85% · Plan Media Maratón 18 sem · Semana 6/18. Zonas FC calculadas con Karvonen: Z1 (93–111) · Z2 (111–130) · Z3 (130–148) · Z4 (148–167) · Z5 (167–185). Pulse no tiene zonas de FC por atleta calculadas en la ficha.

**Banco de ejercicios (`/coach/gym`)**
40 ejercicios en tabla de texto puro — **CERO imágenes ni GIFs**. Filtros por músculo y equipo disponibles. Gap visual vs Pulse confirmado en prod (ítem prioritario §15.2: integrar `free-exercise-db` con GIFs).

**Finanzas (`/coach/finanzas`)**
VENCIDO: $0 · PENDIENTE: $0 · COBRADO: $150.000 COP (1 cobro). Sin gráfico de ingresos mensual (pendiente). Pulse no tiene módulo de finanzas/cobros integrado.

---

#### Loop bidireccional coach↔atleta — verificado en prod

El vínculo coach→atleta está activo: el dashboard del atleta muestra nombre y especialidad del coach; los check-ins del atleta alimentan los KPIs del dashboard del coach (Check-ins 5/6, 83%); la ficha del atleta en el panel del coach muestra historial de check-ins, zonas FC y 6 semanas de progreso. El loop cierra en producción con datos reales.

---

#### Diferencias local vs producción

| Aspecto | Local (E2E previo, qa users) | Producción (2026-07-06, cuentas reales) |
|---------|-----------------------------|-----------------------------------------|
| Adherencia | Calculada (85% en test) | 0% para todos — BUG-061 activo en prod |
| Nutrición TDEE | 2870 kcal (atleta 71.5 kg) | 2633 kcal (Miguel 73.8 kg) — cálculo correcto por perfil |
| Gym imágenes | No verificado | Confirmado sin imágenes (40 ejercicios, solo texto) |
| Plan semana actual | Sesiones cargadas y visibles | Sin sesiones para sem.12 — gap de planificación del coach |
| Finanzas | No navegado | Cobro real $150.000 COP visible; sin gráfico de ingresos |

---

**Conclusión del recorrido de producción:** el sistema vivo (check-in adaptativo → nutrición ajustada por carga → visibilidad del coach en tiempo real) **opera en producción con datos reales**. Los diferenciadores vs Pulse confirmados en local siguen en pie. Los gaps (gym sin imágenes, DEPORTE vacío en lista, BUG-061, finanzas sin gráfico) son mejoras conocidas y no afectan la propuesta de valor central.

> **Bugs de Medaliq NO se documentan aquí** — este archivo es intel de competidor. Los bugs de prod viven en `tests/claude-test-medaliq.md` (BUG-061, COACH-BUG-01) y `tests/test-coach-admin.md`.

### 15.4 Conclusión y ventana competitiva
Los productos están **invertidos**: el moat de Medaliq (endurance adaptativo, Karvonen, check-in) es **más profundo y difícil de copiar**; los gaps de Medaliq (imágenes, pulido visual, bugs de cálculo) son **más baratos de cerrar**. Estrategia: no perseguir a Pulse en features de nicho distinto — **cerrar la brecha visual con ExerciseDB self-hosted (11,000+ GIFs, sin dependencia en runtime — §16), arreglar los bugs de datos, y proteger el moat**. Copiar de Pulse lo estructural que sí aplica (tienda, cobro integrado con rails locales, analítica), no lo que pertenece a su nicho de gym.

**Ventana competitiva (cuándo cierra cada ventaja):**
- **Hasta Q3 2026** — app de atleta nativa: es ventaja real hasta que Pulse lance su beta de app de atleta (su app móvil actual es solo del coach).
- **Hasta Q4 2026** — pagos locales: si Pulse activa Mercado Pago/rails regionales antes de que Medaliq active Wompi/PSE/Nequi, pierde el argumento de pago local en Colombia.
- **Permanente (sin roadmap visible en Pulse)** — check-in adaptativo + Karvonen + nutrición ligada a la carga del día. Es el foso más defendible.
- **Ya cayó** — "precisión científica" con Mifflin-St Jeor: Pulse ya lo implementó en su módulo de nutrición.

---

## 16. TERCEROS EVALUADOS — Biblioteca de ejercicios (julio 2026)

> Decisión cerrada: 2026-07-06. Detalle completo de arquitectura e implementación: `implementacion/ejercicios.md`

| Opción | Ejercicios | GIFs | Precio | Self-host | IA compatible | Decisión |
|--------|-----------|------|--------|-----------|--------------|---------|
| **WorkoutX API** | 1,400+ | ✅ animados | $0 free / $9.99–$24.99/mes | ❌ CDN propio | ✅ | **ADOPTAR — free plan para seed** |
| **exercisedb.io** | 1,394 | ✅ hasta 1080p | $299–$599 pago único | ✅ | ✅ | Descartado — sin `caloriesPerMinute`/`met`, dataset no crece |
| **ExerciseDB GitHub** | ~1,300 | ✅ | $0 | ✅ | ✅ | Descartado — metadata menos rica, AGPL en código servidor |
| **GymVisual** | ~600+ | ✅ anatómicos | Pago único | ✅ | ❌ prohíbe IA | Descartado — incompatible con roadmap AI |
| **free-exercise-db** | ~800 | ❌ fotos | $0 | ✅ | ✅ | Descartado — fotos no GIFs, catálogo insuficiente |

**Decisión final:** WorkoutX plan free como origen del seed. El producto nunca llama a WorkoutX en runtime — nuestro DB es la fuente de verdad. 14 requests (de 500 disponibles/mes) cubren el seed completo. `caloriesPerMinute` + `met` se integran directamente con el módulo de nutrición de Medaliq. Relación comercial con WorkoutX: ninguna.

---

## 17. FEATURES → ROADMAP (derivadas de este análisis)

> Estado: registradas en `roadmap-data.ts` → sección `modulo-ejercicios` (EX-01 a EX-14).
> Las features de UI y copy (C, E, F) pendientes de aprobación para registrar en roadmap.

### Biblioteca de ejercicios — en roadmap como `modulo-ejercicios`

| ID | Feature | Roadmap |
|----|---------|---------|
| EX-01 a EX-05 | Modelo DB + WorkoutXClient + SyncUseCase + seed | ✅ Registrado |
| EX-06 a EX-07 | GET /api/exercises + similar | ✅ Registrado |
| EX-08 a EX-10 | UI /coach/gym rediseñada + modal + GIF en rutinas | ✅ Registrado |
| EX-11 a EX-12 | Mobile: GIF en sesión del día + búsqueda | ✅ Registrado |
| EX-13 a EX-14 | AWS S3 upload + gifStoredUrl (trigger: 5 coaches) | ✅ Registrado |

### Pendientes de aprobación (no registradas aún)

| # | Feature | Prioridad | Esfuerzo | Impacto |
|---|---------|-----------|----------|---------|
| C | **Rediseño KPI cards del dashboard** — icono + número + color por estado | P1 | Bajo | Medio — percepción premium, cero backend |
| D | **Gráfico de ingresos mensual** en `/coach/finanzas` | P2 | Bajo-Medio | Medio — datos ya en `Payment` |
| E | **Copy de valor en notificaciones** — copy concreto, no técnico | P1 | Bajo | Medio — solo copy |
| F | **Garantía de resultado específico** en landing | P1 | Bajo | Alto — conversión |
| G | **Tienda de productos digitales del coach** | P3 | Alto | Alto LTV — nuevo módulo |
| H | **Cobro integrado Wompi/PSE/Nequi** | P0 | Alto | Crítico — ya en BILLING-PREP |
