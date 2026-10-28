# Nutrición — Informe de Inteligencia Competitiva

> Fuente: investigacion directa + analisis publico de sitios, App Store, Reddit, reviews especializados
> Fecha: 2026-07-06
> Competidores analizados: Cronometer · MyFitnessPal · Nutritionix Track · Lose It! · MyMacros+ · Fitia
> Vinculado a: `implementacion/nutricion.md` · `domains/nutricion.md`

---

## Resumen ejecutivo

El mercado de tracking nutricional esta dominado por 5 players con distintos focos. **Ninguno resuelve el problema de Medaliq**: la integracion nutricion-entrenamiento adaptativa para atletas guiados por un coach en LatAm. Los gaps estructurales del mercado son tres:

1. **Sin panel de coach funcional** — Cronometer Pro es lo mas cercano, pero solo permite ver y ajustar numeros, no asignar planes. MyFitnessPal, Lose It!, MyMacros+ y Nutritionix no tienen ninguna funcionalidad de coaching real.

2. **Cobertura LatAm nula o deficiente** — todas las plataformas son US-centric. MyFitnessPal tiene datos en espanol pero user-generated sin validacion. El resto ni siquiera tiene eso.

3. **Sin adaptacion nutricion-entrenamiento** — ninguna plataforma ajusta automaticamente las metas nutricionales segun el tipo de sesion planificada del dia. Todas usan un target estatico o un ajuste manual post-ejercicio.

---

## 1. Cronometer

### Que es

Tracking nutricional con foco en precision cientifica de micronutrientes. Fundada en 2011, bootstrapped. Sede: Canada. 45 empleados.

**Propuesta de valor:** "El tracker mas preciso del mercado." No vende bienestar generico — vende precision de datos. Cada alimento viene de fuentes verificadas (USDA, NCCDB, CIQUAL), sin entradas de usuarios en la base principal.

**Target primario:** usuario avanzado — personas con condiciones medicas, veganos que rastrean micronutrientes criticos, atletas de fuerza con tracking de aminoacidos, y nutricionistas/dietistas clinicos.

**Traccion:**
- 10M+ usuarios registrados (julio 2025)
- iOS App Store: 4.8/5 sobre 89,000+ ratings
- ARR: $3.8M (noviembre 2024). Crecimiento: $1.4M → $3.8M en 3 anos
- No hay VC — bootstrapped completamente

### Arquitectura del producto

```
Cronometer App
├── Diary (hub diario)
│   ├── Log por comida: Breakfast / Lunch / Dinner / Snacks
│   ├── Busqueda (texto + barcode + foto [Gold] + voz)
│   ├── Log de ejercicio integrado
│   ├── Biometricos del dia (peso, FC, sueno)
│   └── Resumen calorico (consumido vs objetivo)
│
├── Nutrition
│   ├── Macros (proteina / carbs / grasa)
│   └── 84-95 micronutrientes como barras de progreso
│       ├── 13 vitaminas completas (A, B1-B12, C, D, E, K)
│       ├── 17 minerales (calcio, hierro, magnesio, zinc, potasio, sodio...)
│       ├── Perfil completo de aminoacidos (esenciales + no esenciales)
│       └── Acidos grasos subtipificados (omega-3 EPA/DHA/ALA por separado)
│
├── Trends (historial)
│   ├── Graficos por nutriente especifico
│   ├── Historial de peso y biometricos
│   └── [Gold] Charts personalizados e ilimitados
│
├── Foods
│   ├── Busqueda en base verificada
│   ├── Crear alimentos personalizados
│   ├── Crear recetas
│   └── [Gold] Importador de recetas desde URL
│
├── Exercise
│   ├── Log manual (base de datos MET values)
│   └── Sync: Apple Health · Google Fit · Garmin · Strava · WHOOP · Oura · Fitbit · Polar · Suunto · Withings
│
└── Settings / Targets
    ├── Calculo TDEE (Mifflin-St Jeor o Harris-Benedict)
    └── [Gold] Macro Scheduler — targets distintos por dia de semana

Cronometer Pro (panel profesional — web separado)
├── Lista de clientes activos + grupos
├── Vista por cliente: diary · nutricion · charts · biometricos
├── Editar targets del cliente (calorias, macros, micros)
├── Target Scheduler — cambiar objetivos en fechas especificas
├── Chat 1:1 cifrado con el cliente
├── Snapshots & Notes del profesional
├── Printable reports (PDF de 92 nutrientes)
├── 24-hour dietary recall (< 10 min)
├── Display Settings — controlar que ve el cliente en su app
└── Compliance: HIPAA + GDPR + CCPA
```

### Base de datos

| Dimension | Dato |
|-----------|------|
| Tamano | 970K-1.1M entradas |
| Fuentes | USDA FDC · NCCDB (U. Minnesota) · CIQUAL (Francia) · AUSNUT (Australia) · BLS (Alemania) · CNF (Canada) · Nutritionix (barcodes) |
| Entradas de usuarios | No — solo bases oficiales verificadas |
| Precision calorica | +/-3.5% en prueba de 30 alimentos (30/30 dentro del 5%) |
| Cobertura LatAm | Practicamente nula. Sin TCAC, sin ENSANUT, sin ICBF. Alimentos tipicos locales no existen como entradas verificadas |

### Targets y adaptacion

- Usa Mifflin-St Jeor o Harris-Benedict para TDEE. Mismo metodo que Medaliq.
- Los targets son **estaticos** — el usuario o el profesional los cambia manualmente.
- Gold: Macro Scheduler permite targets distintos por dia de semana, pero es configuracion manual, no ajuste automatico.
- Cuando el usuario loguea ejercicio: suma calorias quemadas al objetivo del dia. No es adaptacion del plan — es ajuste de presupuesto calorico reactivo.
- **No hay ajuste automatico por tipo de sesion planificada.**

### Panel profesional — Cronometer Pro

El mas avanzado del mercado en su categoria, pero con limites estructurales claros.

**Lo que puede hacer el profesional:**
- Ver diary completo del cliente en tiempo real
- Editar targets nutricionales del cliente (calorias, macros, micros individuales)
- Programar cambios de targets en fechas (Target Scheduler)
- Bloquear al cliente de modificar sus propios targets
- Chat 1:1 cifrado con el cliente
- Generar Nutrition Reports en PDF (analisis de 92 nutrientes)
- Ejecutar 24-hour dietary recall
- Compartir recetas con el cliente

**Lo que NO puede hacer:**
- Crear un plan de comidas estructurado (menu semanal con alimentos especificos) y enviarselo al cliente
- Asignar un plan de entrenamiento
- Ver metricas de adherencia a un plan prescrito (el plan prescrito no existe)
- Ver datos de rendimiento deportivo — no es una plataforma de coaching fitness
- Integrar la nutricion con el tipo de sesion de entrenamiento del dia

**Modelo de acceso:** el coach se registra gratis en Pro. El cliente que el coach invita recibe Gold gratis mientras esta vinculado.

### Pricing

| Plan | Precio | Incluye |
|------|--------|---------|
| Free | $0 | Tracking completo macros + 84 micronutrientes · Barcode scanner · Base USDA verificada · Biometricos basicos · Con anuncios |
| Gold Monthly | $10.99/mes | Todo Free + sin ads + historial ilimitado + fasting timer + Oracle Nutrient Search + Photo Logging + Macro Scheduler + meal scheduling + custom biometrics + printable reports |
| Gold Annual | $49.99/ano (~$4.16/mes) | Igual que Gold Monthly |
| Pro | $39.99/mes (10 clientes incluidos) + $2.50/cliente adicional | Panel profesional + cada cliente recibe Gold gratis + HIPAA compliant |

### Puntos fuertes

- Unica app del mercado consumer con tracking de aminoacidos completo y subtipos de acidos grasos en Free
- Precision de datos imbatible: +/-3.5% vs +/-6.8% de MFP
- Barcode scanner en Free (MFP y Lose It lo pusieron detras de paywall)
- Gold a $4.16/mes efectivo — 5x mas barato que MFP Premium
- Compliance HIPAA/GDPR abre canal de ventas B2B clinico
- Cronometer Pro es lo mas cercano a un panel de nutricionista real en el mercado

### Debilidades

- Cobertura LatAm nula — sin fuentes latinoamericanas integradas
- Sin generacion de planes de comida — el profesional no puede prescribir un menu, solo ajustar numeros
- Sin integracion nutricion-entrenamiento — no hay periodizacion, no hay sesiones, no hay zonas
- UI abrumadora para usuarios casuales — docenas de barras de progreso. TAM limitado por complejidad
- Sin adaptacion automatica — no reacciona a chequeos de fatiga, peso, energia
- Solo en ingles — friccion real para atletas LatAm no tecnicos

---

## 2. MyFitnessPal

### Que es

El tracker de calorias mas conocido del mundo. Lanzado en 2005, comprado por Under Armour en 2015, vendido a Francisco Partners en 2020. Sede: San Francisco.

**Propuesta de valor:** "Sabe cuanto comes, sabe cuanto quemas, te dice cuanto te falta." Herramienta de autogestión nutricional — no plataforma de coaching.

**Target:** adulto general que quiere perder peso o comer mejor. No atletas con plan estructurado. No coaches que gestionan clientes.

**Traccion:**
- 220M+ usuarios registrados
- 30M MAU (usuarios activos mensuales)
- 85M "avid users" (4+ horas/mes de uso activo)
- iOS: 4.7/5 · Google Play: 4.4/5
- Revenue 2024: $345M USD. 2025: $310M (-5.7% YoY)

### Arquitectura del producto

```
MyFitnessPal App
├── Today (hub diario)
│   ├── Calorie ring (consumido vs objetivo)
│   ├── Macros card (pie chart carbs/protein/fat)
│   ├── Meals: Breakfast · Lunch · Dinner · Snacks
│   │   └── Add food: texto | barcode [Premium] | foto [Premium] | voz [Premium] | recientes | comidas guardadas
│   ├── Exercise card
│   ├── Water tracker
│   └── Steps tracker
│
├── Diary
│   ├── Food diary (4 comidas + ejercicio + agua)
│   ├── [Premium] Macros por comida (breakdown por meal)
│   ├── [Premium] Multi-day logging
│   └── [Premium] Copy meal / Copy day
│
├── Nutrition
│   ├── Macros del dia (pie chart)
│   ├── [Premium] Nutrient Dashboard: 50+ micronutrientes
│   └── Tendencia semanal de calorias
│
├── Progress
│   ├── Weight log + grafica
│   ├── Measurements (cuello, pecho, cintura, caderas, muslos, brazos)
│   └── Historial de ejercicio
│
├── Coach (nuevo — jun 2026) [Premium]
│   └── AI chatbot: preguntas abiertas sobre el diary del usuario
│
└── Plan [Premium+]
    ├── Meal Planner (planes 7 dias desde libreria de 1,500+ recetas)
    ├── Meal Prep Mode (batch cooking + escalado porciones)
    ├── Grocery List auto-generada
    └── Integracion: Instacart · Walmart+ · Amazon Fresh (solo EEUU)
```

### Base de datos — el problema central

| Dimension | Dato |
|-----------|------|
| Tamano declarado | 14-18M entradas |
| Fuente | Mixta: datos oficiales (USDA, fabricantes) + user-generated SIN validacion |
| Verificacion | "Green check" = upvotes de usuarios, NO revision de nutricionistas |
| Precision calorica | +/-6.8% MAPE — peor score entre apps de tracking |
| Error medio | +/-185 kcal/dia en test independiente de 20 alimentos |
| Cobertura LatAm | Deficiente — entries en espanol existen pero son user-generated con errores sistematicos |

**Por que es un problema estructural:** cualquier usuario puede crear una entrada. Buscar "pollo a la plancha" retorna 5+ entradas con valores de 120 a 280 kcal/100g. Para un atleta que optimiza rendimiento, un error de 185 kcal/dia invalida el tracking.

Estudio publicado en *Journal of Human Nutrition and Dietetics* (oct 2025): "los atletas deben saber que MFP puede proporcionar informacion dietetica que no refleja con precision la ingesta real."

### Targets y adaptacion

- TDEE con Mifflin-St Jeor + multiplicador de actividad
- Ajuste calorico por ejercicio: sistema "calorie back" — si el usuario loguea ejercicio, el objetivo del dia sube. **Es reactivo a lo que el usuario ingresa, no al plan planificado.**
- Recalculo por cambio de peso: MFP lo notifica, el usuario debe actualizar manualmente
- Premium+: "Different goals by day of week" — manual, no automatico

### Panel de coaching

**No existe.** MFP es B2C puro. Coaches que usan MFP con clientes dependen de integraciones de terceros (ABC Trainerize, PT Distinction) que consumen la API de MFP — MFP no compite en ese espacio.

El "AI Coach" de junio 2026 es un chatbot del usuario final sobre sus propios datos, no un panel para profesionales.

### Pricing

| Plan | Mensual | Anual | Efectivo/mes |
|------|---------|-------|--------------|
| Free | $0 | $0 | — |
| Premium | $19.99 | $79.99 | $6.67 |
| Premium+ | $24.99 | $99.99 | $8.33 |

Premium agrega: barcode scanner · foto logging · voice logging · macros por comida · 50+ micronutrientes · custom macro goals · fasting tracker · data export CSV · AI Coach.

Premium+ agrega: Meal Planner 7 dias · Meal Prep Mode · Grocery list · integracion Instacart/Walmart+.

**Limitacion critica del Meal Planner:** el usuario no puede incluir sus propias recetas en el plan generado — solo las 1,500 de la libreria de MFP. Queja activa en comunidad sin resolver.

### Puntos fuertes

- Brand awareness dominante — es el benchmark que todos conocen
- Ecosistema de integraciones mas amplio del mercado (50+ wearables y apps)
- Historial acumulado de usuarios — lock-in fuerte despues de anos de datos
- Meal Planner en Premium+ es genuinamente util para planificar sin esfuerzo
- AI Coach (2026) — primer chatbot nutricional masivo con datos propios del usuario
- ChatGPT integration (800M+ usuarios como canal de adquisicion) — movimiento estrategico

### Debilidades

- Calidad de datos: el peor score de precision entre todos los trackers (+/-185 kcal/dia)
- Barcode scanner detras de paywall (fue gratis hasta 2022) — resentimiento activo en comunidad
- Sin modelo coach-atleta real
- Adaptacion nutricional no es inteligente — solo reacciona al ejercicio que el usuario loguea
- Cobertura LatAm deficiente — datos en espanol existen pero son user-generated
- Photo recognition inferior a Lose It! (Meal Scan vs Snap It)
- 2026 redesign regresivo segun usuarios — anadio taps al flujo de log diario
- Breach de datos 2018 (150M cuentas) — sigue apareciendo en reviews negativos

---

## 3. Nutritionix Track

### Que es

Nutritionix opera como dos productos distintos: la base de datos nutricional (B2B) y Track, la app de tracking para usuarios finales (B2C). La empresa fue adquirida por Syndigo.

**Nutritionix (empresa):** proveedor de datos nutricionales B2B. Su API la usan clinicas, plataformas de salud y cadenas de restaurantes para datos nutricionales confiables.

**Nutritionix Track (app):** tracker de calorias con foco en velocidad de log. Su diferenciador es la busqueda por texto en lenguaje natural (NLP) — escribe "2 huevos revueltos con tostada y mantequilla" y el sistema lo parsea y desglosa automaticamente.

**Target:** consumidor final en EEUU/Canada. El Coach Portal existe pero es un visor de logs, no un sistema de gestion de coaching.

### Arquitectura del producto

```
Track App
├── Dashboard / Home
│   ├── Resumen calorico del dia
│   ├── Macros del dia (pie chart)
│   └── Agua del dia
│
├── Food Log
│   ├── Busqueda por texto libre (NLP) — diferenciador
│   ├── Escaner de codigo de barras [requiere Pro para cuentas nuevas]
│   ├── Mis alimentos (custom foods)
│   ├── Mis recetas (recipe builder)
│   └── Por comida: Desayuno / Almuerzo / Cena / Snacks
│
├── Exercise Log
│   ├── Cardio (MET-based, no estructurado)
│   └── Fuerza (log basico)
│
├── Progress
│   ├── Peso (grafica historica)
│   └── Calorias historicas
│
└── Coach Portal [requiere Track Pro — $5.99/mes]
    ├── Vista por cliente (solo lectura)
    ├── Resumen mensual (barra por dia)
    └── Detalle diario de log de comidas
```

### Base de datos

| Dimension | Dato |
|-----------|------|
| API (empresa) | 1.9M alimentos unicos |
| Track App | 800K+ items |
| Restaurantes | 760+ cadenas de EEUU — cobertura 92% |
| Barcodes | 600,000+ UPC con 92% match rate |
| Verificacion | Equipo interno de dietistas — sin user-generated |
| Cobertura LatAm | **Practicamente nula.** Base EEUU/Canada first. Alimentos colombianos y mexicanos locales no existen. |

### Coach Portal — detalle

**Modelo de acceso problematico:**
- El coach: se registra **gratis**. Recibe un Coach ID.
- El cliente: debe tener **Track Pro** ($5.99/mes). Sin suscripcion Pro, no puede compartir su log con el coach.

El cliente paga, no el coach. Esta friccion de onboarding es un bloqueador real de adopcion.

**Lo que el coach puede VER:**
- Log de alimentos en tiempo real del cliente
- Resumen mensual (barra calorica por dia)
- Detalle diario: desglose por comida con alimentos especificos
- Macros del dia

**Lo que el coach NO puede hacer:**
- Asignar planes de alimentacion
- Crear templates de comidas y enviarlos
- Establecer metas personalizadas por cliente (las configura el cliente en su propia app)
- Ver historial de entrenamiento o integracion con plan de ejercicio
- Gestionar cobros, citas, ni administracion de practica
- Enviar mensajes o notas al cliente
- Ver metricas de adherencia ni alertas de incumplimiento

**Conclusion:** el Coach Portal de Nutritionix es un visor de logs de solo lectura.

### API de Nutritionix

| Tier | Precio |
|------|--------|
| Development / Free | Hasta 2 usuarios activos |
| Enterprise | Desde $1,850/mes (custom, via Syndigo) |

Endpoints principales: `/natural/nutrients` (texto libre → 30 nutrientes), `/search/instant` (autocomplete), `/search/item` (lookup por UPC/barcode), `/natural/exercise` (texto → calorias quemadas).

**¿Puede Medaliq usar esta API?** No viable por dos razones: cobertura LatAm nula en su base y pricing enterprise ($1,850/mes minimo) incompatible con etapa actual.

### Pricing

| Plan | Precio |
|------|--------|
| Free | $0 — tracking basico |
| Track Pro Mensual | $5.99/mes |
| Track Pro Anual | $29/ano (~$2.42/mes) |

### Puntos fuertes

- Log por texto libre (NLP) — genuinamente rapido para alimentos anglosajones
- Base de datos verificada por dietistas (sin ruido user-generated)
- Mejor cobertura de restaurantes EEUU del mercado (760+ cadenas)
- Coach Portal gratuito para el profesional (bajo friccion de adopcion del lado del coach)

### Debilidades

- Cobertura LatAm: cero — inutilizable como referencia nutricional para LatAm
- El cliente paga $5.99/mes para que el coach pueda verlo — friccion enorme
- Coach Portal de solo lectura — no puede prescribir nada
- Deuda tecnica acumulada: barcode scanner falla en cuentas nuevas, bugs sin resolver
- Sin targets adaptativos — metas estaticas
- Sin modulo de entrenamiento real (log de ejercicio es MET/calorias, sin planes ni zonas)
- Sin foto logging — retraso significativo en 2026
- API inaccesible para startups ($1,850/mes minimo)

---

## 4. Lose It!

### Que es

App de tracking calorico lanzada en 2008 por FitNow. La mas antigua del segmento aun en desarrollo activo. Propuesta de valor: simplicidad — configura tu objetivo de peso, el sistema calcula tu presupuesto calorico, tú logueas lo que comes.

**Target:** adulto en proceso de perdida de peso. No atletas de performance.

**Traccion:**
- 50M+ descargas totales iOS + Android
- 2M MAU
- Rating App Store: 4.7/5 sobre 700,000+ reviews
- Revenue 2025: $23.1M USD anuales
- 120M libras perdidas reportadas por usuarios

### Base de datos

| Dimension | Dato |
|-----------|------|
| Tamano | 27M+ items (otras fuentes citan hasta 47M con user-generated) |
| Fuente | USDA + restaurantes + user-generated |
| Cobertura LatAm | Baja — US-centric. Items colombianos/mexicanos son contribucion de usuarios sin validacion |

### Snap It — la feature diferenciadora

La unica feature que distingue a Lose It de sus competidores.

**Como funciona:**
1. El usuario abre el log y toca "Snap It"
2. Toma una foto del plato o alimento
3. Sistema analiza la imagen con un modelo entrenado sobre 230,000 imagenes de comida y 4 billion de foods logueados desde 2008
4. Entrega sugerencias de que es el alimento con porcentajes de confianza
5. El usuario selecciona y ajusta la porcion manualmente

**Metricas de precision:**
- Tasa de identificacion correcta: **68.7%**
- Error en estimacion de porcion: **+/-22% MAPE**
- Sigue marcado como "beta" en documentacion oficial

**Implicacion para LatAm:** el modelo fue entrenado con datos dominantemente anglosajones. Para bandeja paisa, arepa con huevo o pozole, el accuracy caeria significativamente.

### Features diferenciadores

- **Snap It AI** — unica del segmento a esta escala (aunque accuracy es limitado)
- **Weekly calorie cycling** (Premium) — redistribuir el presupuesto calorico por dia en la semana
- **Integracion de wearables** — Fitbit, Garmin, Samsung Health, Oura Ring, Apple Health
- **Intermittent Fasting tracker** (Premium)
- **Comunidad activa** con foros dentro del app
- 18 anos de datos acumulados retroalimentando el modelo de IA

### Panel de coaching

No existe. Lose It! es B2C puro. Un nutricionista que use Lose It con pacientes tendria que pedirle al paciente que comparta capturas de pantalla.

### Pricing

| Plan | Precio |
|------|--------|
| Free | $0 — tracking basico (barcode ahora requiere Premium para cuentas nuevas) |
| Premium Mensual | $9.99/mes |
| Premium Anual | $39.99/ano (~$3.33/mes) |
| Lifetime | $149.99-$299.99 (pago unico) |

Nota: usa **dynamic pricing** — usuarios Free reciben ofertas de captacion con descuento (se reportan precios anuales de $23.99).

### Puntos fuertes

- Snap It es genuinamente util y unico (aunque con limites)
- Precio anual muy competitivo ($3.33/mes)
- Rating excepcional (4.7/5 sobre 700K reviews)
- Integraciones de wearables completas
- Producto maduro sin bugs criticos conocidos

### Debilidades

- Snap It accuracy 68.7% — inaceptable para tracking de precision atletica
- Cobertura LatAm practicamente nula (items locales sin validacion)
- Barcode scanner movido a Premium para cuentas nuevas — erosiona propuesta Free
- No disenado para atletas de performance — es para perdida de peso, no periodizacion
- Sin ajuste dinamico segun carga de entrenamiento
- Sin panel de profesionales

---

## 5. MyMacros+

### Que es

App de tracking de macros construida para atletas de fitness — bodybuilders, powerlifters, atletas con periodizacion. La propuesta de valor es precision y flexibilidad en macros para usuarios avanzados, no simplicidad para perdida de peso.

**Traccion:**
- 1M+ usuarios
- Rating App Store: 4.7/5 sobre ~26,000 reviews (volumen mucho menor que los grandes)
- Precio Pro mas bajo del mercado

### Base de datos

| Dimension | Dato |
|-----------|------|
| Tamano | 5M+ items (la mas pequeña del grupo) |
| Fuente | Mix USDA + FatSecret API + user-generated |
| Cobertura LatAm | Sin datos verificados. Usuarios reportan gaps frecuentes en barcode fuera de EEUU |

### Feature diferenciador — metas de macros por dia de semana

El diferenciador mas real de MyMacros+: puedes configurar macros distintos para cada dia de la semana. Lunes (entrenamiento pesado) tiene objetivos diferentes a domingo (descanso). MFP no soporta esto nativamente.

Tambien soporta:
- **Carb cycling** nativo
- **Smart search** — aprende los alimentos mas usados para reducir tiempo de log
- **Meal timers** — recordatorios de cuándo es la proxima comida
- **Macro Coach** — AI bot automatizado (NO un panel para coaches humanos) co-creado con una nutricionista registrada. Ajusta macros semana a semana segun check-in de progreso.

### Panel de coaching

No existe para coaches humanos. "Macro Coach" es frecuentemente confundido con un panel pro — es un servicio automatizado de recomendacion dentro del app del atleta, no una herramienta para que un coach gestione su cartera de clientes.

### Pricing

| Plan | Precio |
|------|--------|
| Free | $0 |
| Pro Mensual | $2.99/mes (el mas barato del mercado) |
| Pro Anual | $29.99/ano (~$2.50/mes) |
| Macro Coach | <$10/mes (add-on sobre Pro) |

### Puntos fuertes

- Metas de macros por dia de semana — diferencial real para atletas con periodizacion
- Precio Pro mas bajo del mercado ($2.50/mes)
- Disenado para atletas, no para perdida de peso casual
- Sin ads — experiencia limpia
- Interface rapida para usuarios avanzados

### Debilidades

- Base de datos mas pequena del grupo (5M) — gaps frecuentes en barcode
- Cobertura LatAm practicamente inexistente
- Sin reconocimiento visual IA
- Sin integracion wearables comparable a Lose It
- Curva de aprendizaje alta para usuarios sin conocimiento de macros
- Macro Coach es un AI bot, no panel para coaches humanos

---

## 6. Fitia

### Que es

App movil de nutricion y tracking fitness fundada en Peru (2021, YC S21). El unico player del mercado con base de datos verificada de alimentos latinoamericanos — ese es su moat real. Posicionamiento: "Tu asesor de nutricion personalizado, siempre en tu bolsillo". Target: consumidor final B2C en LatAm que quiere perder peso o ganar musculo.

- **Apps**: iOS + Android — canal UNICO (sin web funcional)
- **Pais**: Peru (Lima) — cobertura LatAm + Espana
- **Fundadores**: Paulo Reyes (CEO) + equipo 23 personas
- **Inversion**: $125K (YC S21, unica ronda) — bootstrapped a ~$3.5M ARR
- **Traccion**: 10M+ usuarios · 14M+ descargas · 4.9/5 App Store · supera a MFP en descargas LatAm (Sensor Tower 2025)

### Arquitectura del producto

```
Fitia App (solo mobile)
├── Inicio           — resumen del dia: macros, agua, pasos, calorias quemadas
├── Diario           — log por tiempo de comida (Desayuno / Almuerzo / Cena / Snack)
│   ├── Busqueda     — texto libre en base de datos propia
│   ├── Barcode      — productos empacados
│   ├── Foto IA      — identifica alimento desde camara [Premium]
│   ├── Voz          — descripcion de voz → alimento [Premium]
│   └── Favoritos / Recetas guardadas
├── Plan de comidas  — menu semanal generado [Premium]
├── Coach IA         — recomendaciones adaptativas [Premium]
├── Progreso         — graficas peso, medidas, macros historicos
├── Micronutrientes  — 20+ vitaminas y minerales [Premium]
├── Ayuno            — timer de ayuno intermitente
└── Social           — feed de comunidad, recetas compartidas
```

### Base de datos — el activo diferenciador

| Dimension | Dato |
|-----------|------|
| Tamano | 10M+ items verificados |
| Metodo | Equipo propio de nutricionistas — NO crowdsourced |
| Cobertura geografica | Peru, Colombia, Mexico, Argentina, Chile, Espana |
| Incluye | Productos de supermercado locales (Exito, Jumbo, D1, Wong, Plaza Vea), platos tipicos regionales (bandeja paisa, ceviche, ajiaco), marcas locales con barcode |
| Precision | Alta — sin ruido user-generated |
| Cobertura LatAm vs MFP | Fitia gana por amplio margen — MFP tiene items en espanol pero user-generated con errores sistematicos |

### Targets y adaptacion

- Formula base: Mifflin-St Jeor para TDEE
- Ajuste por objetivo: perder peso (deficit), ganar musculo (surplus), mantenimiento
- **Adaptacion dinamica**: cuando el progreso de peso difiere del esperado, el sistema ajusta automaticamente los targets nutricionales
- **Sin ajuste por tipo de sesion**: el dia de intervalos (HIGH) tiene los mismos macros que el dia de descanso. El sistema no conoce el plan de entrenamiento del atleta

### Panel de coaching

**No existe.** Fitia es 100% B2C. No hay panel web para coaches, asignacion de planes, seguimiento multi-atleta, ni cobros. Los nutricionistas recomiendan la app a sus pacientes pero no tienen visibilidad centralizada — los datos del atleta estan atrapados en su propia app.

### Pricing

| Plan | Precio | Nota |
|------|--------|------|
| Free | $0 | Con publicidad in-app — log basico + barcode funcional |
| Premium mensual | $19.99/mes | Sin ads + foto IA + voz + plan de comidas + coach IA + micronutrientes |
| Premium anual | ~$60/ano (~$5/mes) | 75% mas barato que mensual — driver principal de conversion |

### Puntos fuertes

- **Base de datos LatAm con moat real**: 10M+ items verificados por nutricionistas con cobertura geografica real de LatAm. Tarda anos en construir — MFP no puede igualar esto en el corto plazo
- **Targets adaptativos**: el plan reacciona al progreso real de peso del atleta — misma filosofia que Medaliq pero aplicada solo a nutricion
- **Foto IA + Voz**: reducen la friccion de registro al minimo — dos metodos que ningun competidor en LatAm combina con cobertura local
- **Precio anual accesible**: $60/ano (~$5/mes) elimina la barrera de precio para el usuario latinoamericano
- **Traccion organica masiva**: 14M descargas con $125K de inversion externa indica PMF genuino y viralidad por referencia (nutricionistas recomiendan a pacientes)
- **Micronutrientes completos**: 20+ en Premium — mas profundo que cualquier competidor en LatAm
- **Modelo ligero y rentable**: $3.5M ARR con 23 personas — unit economics solido para B2C de nutricion en LatAm

### Debilidades

- **Sin integracion nutricion-entrenamiento por intensidad**: registra sesiones para calcular calorias quemadas, pero no ajusta los macros del dia segun el TIPO de entrenamiento planificado. Es el gap critico frente a Medaliq
- **Sin entrenamiento real**: no hay rutinas, planes periodizados, seguimiento de carga en gym ni zonas HR — el modulo de ejercicio existe solo para el calculo calorico
- **Sin panel de coach**: el coach que usa Fitia con pacientes esta ciego — no tiene visibilidad centralizada ni puede asignar planes
- **Solo mobile**: sin experiencia web para configurar metas o analizar datos desde un computador
- **Datos del atleta atrapados**: sin API publica ni exportacion estructurada — lock-in del usuario sin beneficio para el coach
- **Sin B2B**: no hay modelo para gimnasios, clinicas de nutricion ni equipos deportivos

---

## Tabla comparativa maestra

| Feature | Cronometer | MyFitnessPal | Nutritionix | Lose It! | MyMacros+ | Fitia |
|---------|------------|--------------|-------------|----------|-----------|-------|
| **Usuarios** | 10M+ | 220M+ | N/D | 50M descargas | 1M+ | 10M+ |
| **Revenue/ano** | $3.8M | $310M | N/D | $23.1M | N/D | ~$3.5M ARR |
| **Rating iOS** | 4.8/5 | 4.7/5 | N/D | 4.7/5 | 4.7/5 | **4.9/5** |
| **Base de datos** | 1.1M verificada | 14-18M mixta | 1.9M verificada | 27M+ mixta | 5M mixta | **10M+ verificada LatAm** |
| **Precision calorica** | +/-3.5% | +/-6.8% | Alta | Media | Media | Alta (sin ruido user-gen) |
| **Cobertura LatAm** | Nula | Deficiente | Nula | Nula | Nula | **Nativa** |
| **Barcode scan** | Si (Free) | Premium | Premium (nuevas ctas) | Premium (nuevas ctas) | Free (gaps) | Si (Free) |
| **Foto IA** | Si (Gold) | Si (Premium) | No | Si (68.7% accuracy) | No | Si (Premium) |
| **Voz** | Si (reciente) | Si (Premium) | No | No | No | Si (Premium) |
| **Micronutrientes** | 84-95 (Free) | 50+ (Premium) | ~30 (Pro) | Premium | Limitados | 20+ (Premium) |
| **Aminoacidos** | Si (Free) | No | Si (API) | No | No | No |
| **Panel coach real** | Si — visor + ajuste numeros | No | Solo lectura | No | No | No |
| **Asignar plan de comidas** | No | No | No | No | No | No |
| **Metas por dia semana** | Si (Gold) | Si (Premium, manual) | No | No | Si (Free diferenciador) | No |
| **Wearable integration** | Completa (10+) | Completa (50+) | Limitada | Completa | Limitada | Apple Health · Google Fit · Garmin |
| **Meal planner** | No | Premium+ (1,500 recetas) | No | No | No | Si (Premium) |
| **IA adaptativa** | No | AI Coach basico | No | No | Macro Coach (bot) | Coach IA — targets adaptativos por progreso de peso |
| **Ajuste por tipo de sesion** | No | No | No | No | No | No |
| **Free tier funcional** | Si — muy completo | Si (limitado) | Si (limitado) | Si (sin barcode) | Si | Si (con ads) |
| **Precio premium/mes (anual)** | $4.16 | $6.67-$8.33 | $2.42 | $3.33 | $2.50 | ~$5 |
| **Precio premium/mes (mensual)** | $10.99 | $19.99-$24.99 | $5.99 | $9.99 | $2.99 | $19.99 |
| **Panel pro / coach** | $39.99/mes | No | Gratis (solo lectura) | No | No | No |
| **Compliance clinico** | HIPAA/GDPR/CCPA | No declarado | No | No | No | No |

---

## Gaps de mercado — lo que nadie resuelve

### Gap 1: Panel de coach con asignacion real de planes

**El estado del mercado:** Cronometer Pro es lo mas cercano — el coach puede ver el log del cliente, editar sus targets y chatear. Nutritionix tiene un visor de solo lectura. Todos los demas no tienen nada.

**El gap especifico:** ningun tracker permite que el profesional cree un menu de comidas estructurado (lunes: desayuno X, almuerzo Y, cena Z) y se lo envie al atleta para que lo ejecute desde su app. El coach ve lo que el cliente comio, no lo que deberia comer.

**Oportunidad para Medaliq:** el coach en Medaliq ya asigna el plan de entrenamiento y define las guias de alimentacion por fase. El siguiente paso natural es un constructor de menus semana a semana que el atleta recibe como tarea — igual que las sesiones de entrenamiento.

### Gap 2: Cobertura LatAm

**El estado del mercado:** ninguna plataforma tiene cobertura verificada de alimentos latinoamericanos. MyFitnessPal tiene entries en espanol pero user-generated con errores. Las demas ni siquiera eso.

**Oportunidad para Medaliq:** construir la primera base de datos verificada de alimentos LatAm (basada en USDA + ICBF para Colombia, y referencias equivalentes para Mexico, Peru, Argentina) es una ventaja estructural. No es facil de copiar porque requiere trabajo editorial.

### Gap 3: Nutricion adaptativa al tipo de sesion

**El estado del mercado:** todos los trackers usan un target estatico o un ajuste manual post-ejercicio. Ninguno ajusta automaticamente las metas nutricionales segun el TIPO de sesion planificada para ese dia.

**Lo que hace Medaliq:** `getDailyNutritionTarget(intensity, plan)` ya calcula el target del dia segun si la sesion es HIGH/MODERATE/LOW/REST. Esto es exactamente lo que el mercado no tiene — y se puede articular claramente como ventaja.

### Gap 4: Ajuste automatico por datos reales del atleta

**El estado del mercado:** ningun tracker reacciona a cambios de peso, fatiga acumulada, o señales de sobreentrenamiento para ajustar la meta nutricional. El usuario (o el profesional) tiene que hacerlo manualmente.

**Lo que hace Medaliq:** el check-in semanal captura RPE, energia, sueno y peso. `syncWeight` recalcula TDEE y macros automaticamente si el peso cambia mas de 0.5kg. `evaluateCheckInRules` ajusta las sesiones siguientes segun fatiga. El sistema reacciona — los otros no.

---

## Decisiones de producto para Medaliq

### 1. Barcode scanner — alta prioridad

Todos los players han confirmado que el barcode scanner es una feature de entrada — sin ella, el log de nutricion es muy lento para adherencia diaria. Cronometer lo da gratis. MFP y Lose It lo pusieron detras de paywall y perdieron traccion.

**Decision:** implementar barcode scanning via Open Food Facts (gratis, sin key, sin rate limit practico). Flujo: DB lookup primero, OFF solo si no existe. Ver `implementacion/nutricion.md` para arquitectura completa.

### 2. No construir foto IA ahora

Lose It tiene Snap It a 68.7% de accuracy y todavia es "beta". Para atletas con planes de periodizacion, 68.7% de precision es inaceptable — introduce error sistematico. El effort de construirlo supera el beneficio en etapa actual.

**Decision:** foto IA es una feature P3 o fuera de roadmap cercano. Priorizar barcode (que resuelve productos empacados) y log manual rapido con busqueda mejorada.

### 3. Diferenciador claro vs. Cronometer Pro

Cronometer Pro es el competidor mas directo en el espacio de coaching. Su gap: puede VER pero no PRESCRIBIR. El coach no puede crear un menu y enviarselo al atleta.

**Mensaje de posicionamiento:** "Cronometer te dice lo que el atleta comio. Medaliq te deja asignarle lo que debe comer — y el sistema lo adapta automaticamente segun su sesion del dia."

### 4. Precio de referencia

El mercado va de $2.50/mes (MyMacros+) a $8.33/mes (MFP Premium+). Cronometer Pro a $39.99/mes para coaches es el unico punto de referencia B2B.

Para el atleta B2C Pro de Medaliq ($9.99/mes del roadmap), el precio es razonable — entre Cronometer Gold mensual ($10.99) y Lose It Premium ($9.99). Se justifica con la ventaja de la integracion entrenamiento-nutricion que ninguno de los dos tiene.

### 5. Fitia — el competidor que resuelve la cobertura LatAm (ver seccion 6)

Fitia ya resolvio el gap de cobertura LatAm: 10M+ items verificados por nutricionistas con cobertura real de Colombia, Peru, Mexico, Argentina y Chile. Supera a MFP en descargas en LatAm (Sensor Tower 2025).

**Implicacion:** construir una base de datos de alimentos latinoamericanos propia no es viable — Fitia lleva anos de ventaja y $3.5M ARR haciendolo. La estrategia de Medaliq frente a Fitia no es competir en datos de nutricion sino en la integracion que Fitia no tiene: **los macros del dia cambian segun el tipo de sesion planificada por el coach**. Ese ajuste `getDailyNutritionTarget(intensity, plan)` es el diferenciador que ningun tracker puro puede copiar sin tener primero el plan de entrenamiento.

---

## Resumen de ventajas competitivas de Medaliq

| Dimension | Lo que el mercado ofrece | Lo que Medaliq puede ofrecer |
|-----------|--------------------------|------------------------------|
| **Nutricion adaptativa** | Target estatico o ajuste manual | Target dinamico segun tipo de sesion del plan del coach |
| **Integracion entrenamiento** | Nula (log de ejercicio separado para ajuste calorico) | Nativa — el plan de entrenamiento del coach informa la meta nutricional del dia |
| **Check-in con ajuste automatico** | No existe en ninguno | RPE + energia + peso → ajuste automatico de sesiones Y macros |
| **Panel de coach** | Visor de logs (Cronometer) o nada | Asignacion de plan de entrenamiento + guia nutricional + seguimiento desde un panel |
| **Cobertura LatAm** | Nula o deficiente | Oportunidad de ser la primera base verificada LatAm |
| **Idioma y contexto** | Ingles o espanol sin contexto LatAm | Espanol nativo, COP/USD/MXN, America/Bogota, alimentos colombianos y mexicanos |

**La ventaja no replicable:** la integracion nutricion-entrenamiento adaptativa. Un tracker puro puede copiar el barcode scanner, puede mejorar sus datos, puede traducir la UI. No puede copiar la logica de que la meta nutricional del dia sea una funcion del plan de entrenamiento del coach — porque eso requiere tener el plan de entrenamiento en primer lugar, que es el nucleo del producto.
