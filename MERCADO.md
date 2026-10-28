# Medaliq — Análisis de Mercado

> Fuente canónica de inteligencia competitiva y estrategia de mercado.
> Actualizar cada vez que haya nueva información relevante.
> Última actualización: 2026-08-05
>
> **Informes detallados por competidor:** `competitors/pulse.md` · `competitors/nutricion.md`

---

## BLOQUE 1 — Pricing validado

### Atletas

| Tier | Precio | Cómo entra | Qué incluye |
|------|--------|-----------|-------------|
| **B2C Free** | $0 permanente | Se registra solo | Herramienta de registro. Log de sesiones, nutrición y gym. El sistema acumula datos pero no reacciona. |
| **B2C Pro** | $9.99/mes · $79.99/año | Se registra solo + paga | Capa de inteligencia. Check-in semanal con sugerencias de ajuste, métricas de progreso, plan periodizado. |
| **B2B** | $0 — incluido en plan del coach | El coach lo invita vía `/join/[code]` | Acceso completo. El coach activa las features. La inteligencia la provee el coach, no el sistema. |

**Lógica del modelo:**
- **Free = hábito**: el atleta construye su rutina — registra entrenamientos, nutrición y gym. El sistema acumula datos pero no reacciona.
- **Pro = inteligencia**: el sistema reacciona. Check-in semanal ajusta el plan automáticamente, notifica cambios, muestra si está progresando. Eso es lo que mueve a pagar.
- **B2B = incluido**: el atleta del coach no paga. El coach ya pagó su tier que cubre el acceso completo de sus asesorados. El coach puede decirle a su atleta: *"La app es gratis para ti."* Eso reduce fricción de adopción y aumenta retención del coach.
- **Gate de pago B2C**: `checkin` (ajustes automáticos + notificaciones) y `progress` (métricas históricas y benchmarks).
- **Dos fuentes de revenue independientes**: tiers de coach (mes a mes por asesorados activos) + Pro de atletas B2C ($9.99/mes). Sin canibalización.

**Techo validado Colombia**: ~$10 USD/mes = COP ~42,000.
Por encima compite con membresía Smart Fit (COP 40,000–60,000/mes).
Plan anual a $79.99 = $6.67/mes efectivo — ancla de retención y reducción de churn.

**Benchmarks competencia atletas:**

| App | Precio LatAm | Precio US | Qué incluye |
|-----|-------------|-----------|-------------|
| Strava | ~$2–3/mes (~$26–30/año) | $11.99/mes | Social + tracking — sin planes adaptativos |
| Garmin Connect+ | $6.99/mes | Igual | Nutrición + datos device — requiere hardware Garmin |
| MyFitnessPal | ~$6.67/mes ($80/año) | Igual | Log nutricional — sin entrenamiento |
| Fitia | ~$5/mes ($60/año) | Igual | Log nutricional con cobertura LatAm verificada — sin entrenamiento ni panel de coach |
| MyFitCoach | $9.99/mes · $59.99/año | Igual | Gym/fuerza adaptativo con AI — sin running, sin coach platform, sin LatAm native |
| TrainingPeaks | $19.95/mes · $134.99/año | Igual | Planes endurance avanzados — mercado triatleta, no amateur |

> Análisis completo del segmento de trackers nutricionales (Cronometer, MFP, Fitia, Lose It!, Nutritionix, MyMacros+): `competitors/nutricion.md`

**Benchmarks de conversión freemium (industria fitness):**
- Sin trial: 2–5% free a pago
- Trial opt-in sin tarjeta: 18–25%
- Trial opt-out con tarjeta: 49–60%
- Mediana apps fitness con trial activo: 39.9%

**Features que mueven la aguja Free a Pro:**
1. Planes personalizados adaptativos (no genéricos)
2. Zonas de FC y análisis de carga científico (Karvonen)
3. Nutrición sincronizada con entrenamiento del día
4. Check-in semanal con ajuste automático del plan
5. Historial de PRs y benchmarks de rendimiento
6. Marketplace de coaches verificados

---

### Entrenadores / Nutricionistas (B2B SaaS)

| Tier | Asesorados activos | Precio/mes | Racional |
|------|--------------------|-----------|---------|
| Starter | Hasta 5 | Gratis | Sin fricción — TrueCoach da 5, PTdistinction da 3 |
| Growth | 6 – 25 | $39/mes | Cubre al coach que arranca online |
| Pro | 26 – 75 | $79/mes | Competitivo vs PTdistinction 50 a $89.90 |
| Scale | +75 | $129/mes | Precio fijo transparente — sin "precio a convenir" |

**Diferenciador crítico: 0% fee sobre pagos.**
TrueCoach cobra 5% desde enero 2026. Coach con 50 clientes a $100 USD c/u = $5,000/mes en cobros.
Fee TrueCoach: $250 adicionales. Costo real efectivo: $129 + $250 = $379/mes.
Medaliq Pro: $79/mes, $0 en fees.

**Perfil del entrenador tipo en Colombia:**
- 10–25 asesorados online
- Ingreso bruto ~$1,200 USD/mes (20 clientes × COP 250,000)
- Herramientas actuales: WhatsApp + Excel + Nequi — sin software de coaching
- Precio máximo tolerable en software: $40–80 USD/mes

---

## BLOQUE 2 — Mapa competitivo

### Tabla maestra

| Plataforma | Web | Mercado | Coaches | ~25 clientes | ~50 clientes | Nutrición | Check-in | Running |
|------------|-----|---------|---------|--------------|--------------|-----------|----------|---------|
| Trainerize | [trainerize.com](https://trainerize.com) | Global | 400,000+ | $120+/mes real | $165+/mes | Add-on $45/mes extra | No | No |
| TrueCoach | [truecoach.co](https://truecoach.co) | Global | 15,000–20,000 | $64/mes | $129/mes + 5% fee | No | No | No |
| PT Distinction | [ptdistinction.com](https://ptdistinction.com) | Global | Sin dato | $59.90/mes | $89.90/mes | Si — AI Meal Planner | Si | No |
| TrainHeroic | [trainheroic.com](https://trainheroic.com) | Global / Equipos | Universidades, militares | $99/mes | $199/mes | No | Readiness | Parcial |
| Final Surge | [finalsurge.com](https://finalsurge.com) | Endurance | Sin dato | $32/mes (hasta 100) | incluido | No | No | Si |
| Feast Fit | [feast-fit.com](https://feast-fit.com) | Mexico | ~250 coaches | En pesos MXN | En pesos MXN | No | No | No |
| Pulse | [pulsefit.app](https://pulsefit.app/es) | LatAm | 1,247 coaches · 4.9/5 | $19.99/mes (hasta 50) | $49.99/mes (hasta 200) | Beta (2027) | AI Evaluation | No — sin app atleta (Q3 2026) |
| Hodara | [hodara.co](https://hodara.co) | Colombia | Pre-lanzamiento | Modelo B2B2C — se vende al gym, no al coach | — | Si — recomendaciones | Reportes físicos | No |
| Medaliq | medaliq.com | Colombia | En captación | $39/mes | $79/mes | Si — integrada | Si — adaptativo | Si — Karvonen |
| **Fitia** *(B2C atleta)* | fitia.app | LatAm | 10M+ usuarios · 14M descargas | $5/mes (anual) | $19.99/mes | Si — 10M+ items verificados LatAm | Adaptativos por peso (sin sesion) | No |
| **Floga** *(B2C yoga)* | [floga.io](https://floga.io) | Global | ~4,000 usuarios · ~$10K/mes | $14.99/mes | $129.99/ano | No | No | No — solo yoga (sequence builder + player, filtros chakra/meridiano, estilos: Hatha/Vinyasa/Yin/Restorative) |
| **Symmetry** *(B2C gym)* | [symmetry.club](https://symmetry.club) | Global | 1M+ usuarios · 3M+ descargas · 4.8/5 | Freemium | Premium (precio no publico) | No | No | No — solo gym (AI body scan, planes personalizados, progressive overload, video form guidance) |

> Trainerize plan base "$22/mes" es engañoso. Nutrición (+$45/mes) + branding (+$169 setup) llevan el costo real a $120–165/mes.

---

## BLOQUE 3 — Deep Dive competidores LatAm

### Feast Fit — Competidor principal

**Web**: [feast-fit.com](https://feast-fit.com) · **IG**: @feastfitmx (3,198 seguidores) · **Pais**: Mexico

**Fundadores**: Emiliano Carrillo y Angel Genis — estudiantes de TI mexicanos. Startup bootstrapped, sin inversión institucional confirmada.

**Tracción real:**
- "15,000 usuarios activos" = coaches + atletas combinados
- ~250 coaches pagos reales
- ~14,750 atletas (clientes de esos coaches)
- App Store: 5.0/5 con 8,000+ descargas
- Instagram: 3,198 seguidores — motor de contenido muy incipiente
- Sin expansión confirmada fuera de Mexico

**Features:**
- 1,300+ ejercicios animados + custom ilimitados
- Superseries, dropsets, RIR, RPE, tiempos de descanso
- Pagos recurrentes en pesos MXN (modelo suscripcion como Netflix)
- Chat coach-atleta integrado
- Fotos de progreso comparables
- App gratis para el atleta
- SIN nutricion
- SIN check-in adaptativo
- SIN planes running periodizados
- SIN panel web coach confirmado
- SIN precio publico — requiere registro

**Ventaja clave**: cobros en pesos sin conversion + soporte en espanol mexicano.
**Debilidad clave**: solo gym/fuerza, sin nutricion, sin running, sin Colombia.

---

### Pulse — Competidor regional activo

> Informe completo con analisis de cuenta activa: `competitors/pulse.md`

**Web**: [pulsefit.app/es](https://pulsefit.app/es) · **Pais**: LatAm generico

**Fundadores**: Sin informacion publica. Sin inversion confirmada.

**Traccion confirmada**: 1,247 coaches activos declarados · 4.9/5 Google + App Store · Trial 30 dias sin tarjeta · PREMIUM $49.99/mes (lanzamiento).

**Features confirmadas (cuenta activa, julio 2026):**
- Gestion de clientes (stats, metas, historial, fotos progreso)
- IA generacion de rutinas en 30 segundos — core feature, muy visible en marketing
- AI Client Evaluation — evaluacion automatica de progreso, medidas y metas
- Gestion de pagos integrada + finanzas
- Clases grupales
- Tienda del coach (venta de planes/productos)
- App movil iOS + Android para el COACH (lanzada)
- Push notifications con copy orientado a casos de uso reales
- SIN nutricion completa — Beta, modulo completo en 2027
- SIN check-in semanal adaptativo
- SIN planes periodizados running
- SIN app movil atleta — browser only (beta Q3 2026)
- SIN pagos locales — USD solamente (Mercado Pago Q3 en QA, OXXO/PIX/Yape Q4)
- SIN modo B2C atleta sin coach

**Precios:** Standard $0 (5 clientes) · Professional $19.99/mes lanzamiento (50 clientes) · Premium $49.99/mes lanzamiento (200 clientes)

**Riesgo para Medaliq**: posicionamiento geografico identico, traccion real y creciendo. Si consiguen coach ancla famoso en Colombia pueden crecer rapido. Su IA de rutinas es un diferenciador de marketing que Medaliq no tiene aun.

**Ventana competitiva actual:**
- App atleta mobile nativa: ventaja hasta Q3 2026 (su beta de app atleta)
- Nutricion integrada: ventaja permanente (su roadmap no incluye esto antes de 2027)
- Check-in adaptativo: ventaja permanente (no en su roadmap)
- Pagos locales: ventana hasta Q3-Q4 2026 (Mercado Pago en QA, OXXO/PIX/Yape en Q4)

---

### Hodara — Referente de features (modelo B2B2C, NO competidor directo)

**Web**: [hodara.co](https://hodara.co) · **Pais**: Colombia · **Etapa**: pre-lanzamiento ("2 grupos de implementacion al mes", venta con demo + config personalizada)

**Que es**: nacio como control de acceso inteligente para gimnasios (reconocimiento facial <2s, POS, facturacion electronica, gestion de miembros) y esta evolucionando a suite all-in-one para el DUENO DEL GIMNASIO FISICO — operacion + app de miembro + coaching con IA.

**Diferencia de modelo — clave estrategica:**
- **Medaliq vende al COACH ONLINE independiente** (10-25 asesorados por WhatsApp+Excel, sin gym fisico). El coach trae sus clientes.
- **Hodara vende al DUENO DEL GYM FISICO.** Los miembros ya estan cautivos adentro. El coaching con IA es un *upsell de ARPU*, no su core. Resuelve la distribucion que Medaliq no tiene resuelta — pero solo dentro del gym fisico.

**No compiten por el mismo problema ni por el mismo bolsillo.** Hodara es irrelevante para el coach 100% online. Su venta es de alto touch (demo + instalacion), lenta y atada a presencia fisica.

**Flanco real a vigilar**: coaches empleados o afiliados a un gym fisico. Si ese gym adopta Hodara, Medaliq pierde a ese coach. No pelear de frente a quien ya esta en la puerta.

**Features del pitch de su CEO (fuente de ideas):**
- App de miembro conectada al gym con racha de asistencia estilo Duolingo (gamificacion de constancia)
- Membresia, dias restantes, acceso rapido a entreno/nutricion/progreso/coach
- Coach crea rutinas + IA genera planes personalizados (activable por el dueno)
- Ejecucion guiada: ejercicios del dia, imagenes de como hacerlos, marcar completado, descansos, registro
- Analisis de progreso: reportes fisicos del coach, graficas, comparacion mes a mes, cambio corporal
- Nutricion por objetivo (recomendaciones e ideas de comida)
- Calendario de asistencia + entrenamientos realizados
- **Debito automatico / renovacion de membresia in-app** (sin recepcion persiguiendo pagos)
- **AI coach con contexto del usuario** (asistencias, entrenos, progreso, nutricion) — chat que responde sobre SU proceso. Vendido como membresia premium intermedia entre estandar y coach personalizado.
- Facial + POS + facturacion electronica + gestion de colaboradores (operacion de gym — fuera del scope de Medaliq)

**Insight de retencion que vale oro** (usar en marketing de Medaliq): *"muchas veces el cliente progresa, pero no lo vive como parte de su membresia."* Hacer el progreso VISIBLE es lo que crea arraigo.

> Features de Hodara consolidadas en el **Bloque 4 — Matriz de Features**.

---

### MyFitCoach — Competidor B2C gym (referente de conversión y UX)

**Web**: [myfitcoach.app/es](https://www.myfitcoach.app/es) · **Pais**: Hannover, Alemania (global con /es) · **Fundado**: 2019

**Fundadores**: Maximilian Hamann y Tim Wurth. 14 empleados. **Sin funding — bootstrapped.** No es LatAm-native: tiene versión en español pero no opera desde LatAm.

**Modelo**: B2C puro. No hay coach, no hay B2B. El producto reemplaza al coach personal con AI.

**Tracción referencial:**
- Revenue en Statista (detrás de paywall, confirma que existe y es medible)
- App Store: 4.7+ con miles de reviews
- Endorsements de culturistas naturales y atletas physique (mercado europeo)
- Trial 14 días sin tarjeta + 50% de descuento introductorio en web frecuente

**Features de producto:**
- Plan 100% personalizado por nivel, tiempo, equipamiento y objetivo — generado por AI en onboarding
- Progresión automática de pesos y reps por sesión — la AI calcula el próximo peso óptimo
- Recuperación por grupo muscular (semanal) — más granular que RPE general: el atleta reporta cómo siente piernas, espalda, pecho, hombros
- Macros personalizados que se optimizan semanalmente según evolución de peso corporal
- 99 recetas de fitness (ingredientes + macros exactos, opciones veg)
- Registro de peso corporal → ajuste automático de entrenamiento y nutrición
- **Onboarding web pre-descarga**: quiz de 1 minuto en la landing → plan visible → CTA de descarga. El usuario ve su plan ANTES de instalar la app.

**Pricing:** $9.99/mes · $22.99/trimestre · $59.99/año. Trial 14 días sin tarjeta (App Store). Web: sin trial pero 50% descuento introductorio frecuente.

**Lo que NO tienen:**
- Running / endurance (cero)
- Coach platform / panel B2B (no existe)
- Chat atleta-coach (no hay coach)
- LatAm native (español de traducción, no colombiano/mexicano)
- Pagos en moneda local LatAm
- Check-in adaptativo con ajuste de zonas (solo recuperación por músculo)

**Por qué importa para Medaliq:**
1. **Valida el precio B2C**: $9.99/mes funciona — empresa bootstrapped de 14 personas con revenue real.
2. **El onboarding pre-descarga es probablemente su mayor driver de conversión**: ver el plan antes de instalar elimina la fricción principal. Ningún competidor LatAm lo hace.
3. **Recuperación por grupo muscular**: input más granular y accionable que el RPE global. Mejora la calidad del ajuste automático.
4. **Testimonios antes/después con peso concreto** ("63 kg → 76 kg") son más persuasivos que texto. Formato replicable.
5. **No es amenaza directa**: no tiene running ni coach platform. Si entrara a LatAm compite solo en el segmento B2C gym sin coach.

---

### TrueCoach — Referencia global mas relevante

**Cambio critico enero 2026**: implementaron 5% fee sobre todos los pagos procesados en la plataforma. Coaches buscan alternativas activamente.

**Costo real efectivo con fee:**

| Clientes | Cobros mensuales al coach | Fee TrueCoach (5%) | Plan TrueCoach | Costo total |
|----------|--------------------------|-------------------|----------------|-------------|
| 20 | $2,000 | $100 | $64 | $164/mes |
| 50 | $5,000 | $250 | $129 | $379/mes |
| 75 | $7,500 | $375 | $165 | $540/mes |

Medaliq equivalente: plan fijo, $0 en fees.

---

## BLOQUE 4 — Matriz de Features

> **Propósito**: fuente única de decisión sobre qué features de la competencia vale la pena adoptar.
> **Flujo**: referente (Bloque 3) → esta matriz → decisión → item en `roadmap-data.ts`.
> **Filtro de decisión**: encaja con la filosofía "el sistema se siente vivo" + mobile-first + retención del atleta, sin sacar a Medaliq de su foco (coach online independiente).
> Actualizar cada vez que un competidor nuevo aporte una feature no listada.

**Leyenda de decisión:**
`Adoptar P1` alto impacto / bajo-medio esfuerzo · `Adoptar P2` valioso pero no urgente · `Acelerar` ya en roadmap, subir prioridad · `Horizonte` futuro / monetización · `Ya existe` en Medaliq hoy · `Ignorar` fuera de foco.

| Feature | Fuente(s) | ¿En Medaliq? | Esfuerzo | Impacto | Decisión | Alineación (schema / roadmap) |
|---------|-----------|--------------|----------|---------|----------|-------------------------------|
| **Racha de adherencia (streak)** | Hodara | **Sí** — badge 🔥 web+mobile en dashboard, cron PLT-09 (racha en riesgo), cron PLT-08 (re-engagement 3d sin actividad), ShareMilestoneButton en racha ≥7d | Bajo | Alto (churn) | **Ya existe** | Completado. `ActivityStreak` model + `streakDays` en dashboard hero. |
| **Fotos de progreso comparables** | Feast Fit · Pulse · Hodara | No (solo medidas numéricas) | Bajo | Alto | **Adoptar P1** | Extiende `WeeklyCheckIn` + `featureProgress`. Table-stakes (3 competidores). |
| **Vista "evolución mes a mes"** | Hodara | Datos sí, vista no | Bajo | Medio-Alto | **Adoptar P1** | Empaqueta `WeeklyCheckIn` + `PerformanceBenchmark`. Materializa "hacer el progreso visible". |
| **Programación de fuerza avanzada** (superseries, dropsets, RIR, RPE/serie, tempo, descansos) | Feast Fit | Parcial — `GymSession`+`SetLog` ejecutan supersets/dropsets (WORK/WARMUP/DROPSET enum), timer descanso, referencia sesión anterior. Programación en `AssignedWorkout` (RIR/tempo/supersets en el builder del coach) pendiente | Medio | Alto | **Adoptar P1** | Gap reducido en el lado atleta. Pendiente: lado coach — programar superseries/dropsets en el plan builder. Extiende `AssignedWorkout`. |
| **Informe automático de progreso** (evaluación de medidas/metas) | Pulse | No | Medio-Alto | Alto | **Acelerar** | Neutraliza el único diferenciador visible de Pulse. Se apoya en el check-in semanal. |
| **Coach con contexto enriquecido** (dashboard con métricas del atleta) | Hodara | Parcial — panel coach con KPIs | Medio | Alto | **Mejorar** | Hodara lo vende como premium. Medaliq ya tiene panel coach — profundizar métricas. |
| **Ejecución guiada de la sesión** (marcar set, temporizador descanso, entreno del día) | Hodara | Parcial (`GymSession`+`SetLog`) | Medio | Medio | **Adoptar P2** | UX de guía en vivo. Mobile-first. |
| **Biblioteca de ejercicios con demo visual** | Feast Fit (1,300+) · Hodara | Probablemente no | Alto | Medio | **Adoptar P2** | Table-stakes. Requiere assets — evaluar librería licenciada antes de producir. |
| **Readiness score** (disposición diaria para entrenar) | TrainHeroic | No (inputs sí) | Medio | Medio | **Adoptar P2** | Deriva de `WeeklyCheckIn` (RPE, energía, peso). Encaja con "sistema vivo". |
| **Débito automático / cobro recurrente** | Hodara · Feast Fit | Pendiente Stripe/Wompi | Alto | Alto | **Acelerar** | Ya es P0. Cobro coach→atleta en COP. Mantener diferenciador 0% fee. |
| **White-label / marca del coach** | Trainerize (+$169 setup) | No | Medio | Medio (monetización) | **Horizonte** | Tier alto del coach. No MVP. |
| **Calendario de asistencia** | Hodara | Parcial | Bajo | Bajo | **Horizonte** | Solo como calendario de constancia/adherencia, no de acceso físico. |
| **Chat coach-atleta** | Feast Fit | Sí (`Message`) | — | — | **Ya existe** | — |
| **Gestión de clientes** (stats/metas/historial) | Pulse | Sí (panel coach) | — | — | **Ya existe** | — |
| **Nutrición integrada y sincronizada** | PT Distinction · Trainerize (add-on) | Sí — sincronizada con intensidad del día | — | — | **Ya existe** (ventaja) | Diferenciador propio; nadie en LatAm la tiene integrada. |
| **Running periodizado (endurance)** | Final Surge | Sí — Karvonen | — | — | **Ya existe** (ventaja) | Diferenciador propio. |
| **Onboarding pre-descarga** (quiz 1 min en landing → plan visible → CTA registro/app) | MyFitCoach | No — el atleta necesita crear cuenta antes de ver cualquier plan | Medio | Alto (conversión) | **Adoptar P1** | Landing actual solo tiene CTAs de registro. Un quiz de 1 min que genere un plan preview antes de registrarse elimina la fricción principal de adquisición. |
| **Recuperación por grupo muscular** (piernas/espalda/pecho/hombros en check-in) | MyFitCoach | No — check-in tiene RPE general + energía pero no por músculo | Bajo | Medio-Alto | **Adoptar P2** | Extiende `WeeklyCheckIn` con campos opcionales por grupo. Input más accionable para ajuste de volumen. |
| **Progresión automática de carga sugerida** (basada en `SetLog` previo → sugiere próximo peso) | MyFitCoach | Parcial — muestra último peso registrado, no sugiere el próximo | Bajo | Medio | **Adoptar P2** | Lógica: `lastWeight * 1.025` o `lastWeight + 2.5kg` si completó todas las series sin fallar reps. Ya tenemos `SetLog` con `weight` y `repsCompleted`. |
| **Testimonios antes/después con número de kg** (formato social proof) | MyFitCoach | No (no tenemos casos documentados aún) | Bajo | Medio (marketing) | **Adoptar (marketing, no código)** | "63 kg → 76 kg" es más persuasivo que texto. Recopilar estos casos de los primeros atletas beta. |
| **Facial / POS / facturación / gestión colaboradores** | Hodara | No aplica | — | — | **Ignorar** | Operación de gym físico. Fuera de foco. |
| **Enfoque equipos** (universidades/militares) | TrainHeroic | No | — | — | **Ignorar** | No es el segmento (coach online individual). |

**Secuencia recomendada** (quick wins de retención primero, todo con datos que ya existen en schema):
1. Racha de adherencia → 2. Fotos de progreso → 3. Vista evolución mes a mes → 4. Programación de fuerza avanzada.
Luego P2 (ejecución guiada, biblioteca de ejercicios, readiness). Cobro recurrente ya vive en el roadmap — subir prioridad.

---

## BLOQUE 5 — Posicionamiento de Medaliq

**Argumento central:**

> "La unica plataforma en Colombia que combina planes de entrenamiento adaptativos (running + gym), nutricion sincronizada con cada sesion, y cobros en COP — sin quedarnos con el 5% de lo que tus clientes te pagan."

**Los 3 diferenciadores tecnicos que nadie en LatAm tiene juntos:**
1. Check-in semanal -> ajuste automatico del plan (RPE, zonas, volumen)
2. Nutricion sincronizada con la intensidad del dia (Karvonen + Mifflin-St Jeor)
3. Planes running periodizados cientificamente (no solo gym)

**Ganchos de arraigo del atleta** (retencion — de la Matriz de Features, Bloque 4):
El insight robado a Hodara: *"el cliente progresa pero no lo vive como parte de su membresia."* Medaliq lo resuelve haciendo el progreso VISIBLE y la constancia RECOMPENSADA.
- Racha de adherencia — la constancia se siente, no se supone
- Progreso visible — fotos + evolucion mes a mes, no solo numeros sueltos
- El sistema reacciona en tiempo real (ya es filosofia de producto): el plan se ajusta a cada dato que el atleta registra

> Posicion frente a Hodara: Hodara digitaliza al miembro del gym FISICO; Medaliq entrena al atleta donde sea que este. No compiten por el mismo problema — Hodara es referente de features, no rival directo.

> Posicion frente a Fitia: Fitia ya resolvio el gap de cobertura de alimentos LatAm (10M+ items verificados, 14M descargas, $3.5M ARR). No atacar ese espacio. El diferenciador es la integracion que Fitia no tiene: los macros del dia cambian segun el tipo de sesion planificada por el coach. Fitia sabe que el atleta corrio — no le dice que coma diferente por haberlo hecho. Ver `competitors/nutricion.md` §6.

### Atleta receptor vs atleta participante

La mayoría de plataformas trata al atleta como receptor pasivo del trabajo del coach:
el coach crea → el atleta ejecuta → el coach revisa. El atleta no tiene voz en el proceso.

- **Feast Fit**: marca series, no hay plan que reaccione.
- **TrueCoach**: recibe workouts, puede escribirle al coach. Nada más.
- **PT Distinction**: el más avanzado — check-in y AI meal planner, pero nutrición no sincronizada con la intensidad del día.
- **Hodara**: racha + progreso visual + AI chat — pero el atleta es miembro de un gym físico, no independiente.

Ninguno tiene un atleta que sienta que el plan lo conoce.

Medaliq resuelve esto en lógica: el check-in ajusta el plan, la nutrición cambia con la intensidad del día, los PRs se celebran. El gap está en hacerlo VISIBLE en la UX — ahí está el trabajo pendiente (R11).

**Mapa de posicion:**

```
                    FEATURES COMPLETAS
                           |
           PT Distinction  |
                           |
       Trainerize ---------+----------------- MEDALIQ (objetivo)
                           |                  + Nutricion integrada
                           |                  + Check-in adaptativo
                           |                  + Running + Gym
GLOBAL --------------------+-------------------------------- LATAM
                           |
   TrueCoach               |    Feast Fit (Mexico)
                           |    Pulse (pre-PMF)
   Final Surge             |
   TrainHeroic             |
                           |
                    FEATURES BASICAS
```

---

## BLOQUE 6 — Plan de accion

### Urgente — 2 semanas

- [x] Publicar pricing del coach en el sitio — ser el unico transparente en LatAm es ventaja inmediata · Sección Pricing completa en landing con tiers Starter/Growth/Pro/Scale
- [x] Landing page coach colombiano — hablar de COP, "sin fees sobre tus cobros", soporte en espanol colombiano · Landing en ES con pill "✓ 0% de comisión · tus ingresos son tuyos, siempre" en hero + WhatsApp flotante + ROI calculator + sección B2C
- [ ] Activar 5 coaches beta en Colombia — LinkedIn/IG fitness CO, coaches con 15–40 clientes online. Oferta: 3 meses gratis + testimonial
- [ ] Integrar cobro en COP via Stripe o Wompi — sin esto no hay argumento de "cobros en pesos locales"

### Prioritario — 30 dias

- [ ] Demo video 90 segundos para el coach — flujo: crear atleta -> asignar plan -> ver check-in -> ver nutricion del dia
- [x] Pagina comparativa vs TrueCoach — Decisión: sin menciones a competidores. Implementado: sección "Todo lo que necesitas" (6 feature cards) + pill "✓ 0% de comisión" en hero. Diferenciador comunicado por valor propio.
- [x] Activar pagina publica del coach /join/[code] — coach comparte link, atleta se registra, CAC de atletas = $0 · Implementado con branding completo del coach (avatar, headline, specialties, bio)
- [x] Mostrar nutricion como feature de marketing — nadie en LatAm la tiene integrada con el entrenamiento · Sección "¿Sin entrenador? Medaliq también es para ti" en landing: Free incluye log + nutrición + gym gratis

### Importante — 60–90 dias

- [ ] Vista "mis finanzas" exportable — PDF de pagos por mes. Feature de retencion
- [ ] Contenido educativo IG/LinkedIn para coaches — Feast Fit tiene 3,198 seguidores, el espacio esta vacio
- [ ] Sistema de referidos coach -> coach — 1 mes gratis al referido + descuento al que refiere
- [ ] Onboarding coach < 10 minutos — crear primer atleta + asignar plan + enviar link en menos de 10 min. Medir y optimizar

### Horizonte — 90–180 dias

- [ ] Informe automático de progreso (check-in + métricas) — neutraliza el diferenciador de Pulse
- [ ] Marketplace de planes — coach vende planes a atletas externos, Medaliq cobra 15–20%. Nadie en LatAm lo tiene
- [ ] Expansion Mexico — con PMF en Colombia y cases de exito, entrar al territorio de Feast Fit

### Producto — Features priorizadas (de la Matriz, Bloque 4)

Quick wins de retencion primero. Todas usan datos que ya existen en el schema. Al bajarlas a ejecucion, registrarlas en `roadmap-data.ts`.

- [x] **P1 · Racha de adherencia** — constancia del plan (sesion/check-in/comida), estilo streak. Bajo esfuerzo, alto impacto en churn · Badge 🔥 en dashboard web+mobile, cron re-engagement 3d, cron racha en riesgo, tarjeta compartible en racha ≥7d
- [ ] **P1 · Fotos de progreso comparables** — extiende `WeeklyCheckIn`. Table-stakes (Feast Fit + Pulse + Hodara ya lo tienen)
- [ ] **P1 · Vista evolucion mes a mes** — empaqueta `WeeklyCheckIn` + `PerformanceBenchmark` en narrativa visual
- [ ] **P1 · Programacion de fuerza avanzada** — superseries, dropsets, RIR, RPE/serie, tempo. Extiende `AssignedWorkout`. Cierra el gap del modulo gym vs Feast Fit
- [ ] **Acelerar · Informe automático de progreso** — evaluación semanal basada en check-in. Neutraliza el diferenciador de Pulse
- [ ] **P2 · Ejecucion guiada + biblioteca de ejercicios con demo** — UX de sesion en vivo + libreria de movimientos

---

## BLOQUE 7 — Metricas de PMF

Medaliq esta en etapa **Launch** segun el framework de Anthropic Founder's Playbook (2026).
Los indicadores para confirmar PMF real (no hype inicial):

| Metrica | Senal negativa | Senal positiva |
|---------|---------------|----------------|
| Retencion de coaches | No vuelven la semana 2 | Activos mes 2 y 3 |
| Conversion free a pago | < 5% | > 20% |
| NPS coaches | < 30 | > 50 |
| Ciclo de feedback | Silencio del coach | Coaches piden features especificas |
| Atletas por coach | < 5 activos | > 10 activos y creciendo |

**Principio operativo (Founder's Playbook):**
En etapa Launch, el riesgo del founder solo es quemar atencion en tareas que pueden automatizarse.
- Automatizar: onboarding, recordatorios, soporte frecuente y repetitivo
- Enfocar al founder en: relaciones con coaches clave, decisiones de producto, vision

---

## BLOQUE 8 — Ventanas de oportunidad con fecha de vencimiento

1. **Fee de TrueCoach (enero 2026)** — llevamos 6 meses de la ventana de 6–12 meses. ESTAMOS EN EL PUNTO MEDIO — la urgencia no bajó, subió. Si no capitalizamos esta ventana en los próximos 3–6 meses, el mercado se habrá acomodado.

2. **Feast Fit sin Colombia** — 250 coaches en Mexico, sin expansion confirmada a Colombia. Un coach colombiano influyente que los adopte puede cerrar esta ventana sin aviso.

3. **Pulse pre-PMF** — sin traccion visible, sin precio publico, web en ingles. Medaliq puede tomar posicion en Colombia antes de que Pulse encuentre su primer coach ancla.

4. **Vacio de contenido coach-tech en LatAm** — nadie educa al entrenador colombiano sobre como escalar su negocio online. El primero en hacerlo se convierte en autoridad del nicho.

5. **Hodara en venta activa (Colombia)** — "2 grupos de implementacion al mes" = ya están vendiendo. La ventana para posicionarse antes de que Hodara estandarice el coaching dentro del gym se angosta. Riesgo puntual: coaches afiliados a gimnasios que adopten Hodara. **Verificar en Q3 2026 si ya tienen módulo de coaching consolidado.**

6. **NUEVA — Pulse app atleta Q3 2026 (urgente):** Pulse anunció su beta de app atleta para Q3 2026. Estamos dentro de ese Q3 (jul-sep 2026). Verificar si su app atleta ya está disponible antes de usar "sin app atleta" como diferenciador. Si lanzaron, el diferenciador de app nativa pasa a ser paridad, no ventaja.

---

## BLOQUE 9 — Modelos de monetizacion adicionales a explorar

1. **Comision por referido de atletas al coach** — atleta llega via Medaliq, coach lo convierte a cliente, Medaliq recibe credito. Flywheel natural.

2. **Marketplace de planes** — coach empaqueta y vende plan periodizado a atletas externos. Medaliq cobra 15–20%. Revenue sin CAC adicional.

3. **Plan familiar/duo** — 2 personas en un plan a 1.5x el precio individual. Reduce churn por friction social para cancelar.

4. **Contenido formativo para coaches** — cursos de periodizacion y nutricion cientifica dentro de la plataforma. $50–150 USD. Acquisition channel disfrazado de revenue.

---

## BLOQUE 10 — Retos del mercado y de Medaliq

> Este bloque es un espejo hacia adentro. No habla de competidores — habla de los problemas que Medaliq debe resolver para ser competitivo y crecer.
> Actualizar el estado (`pendiente / en progreso / resuelto`) cada vez que un reto avance.
> Última revisión: 2026-07-24

---

### Tabla de retos

| # | Reto | Por qué importa | Estado | Palanca |
|---|------|-----------------|--------|---------|
| R1 | **Cambio de hábito del entrenador** | El 80% usa WhatsApp + Excel + Nequi hoy. El problema no es el precio del software — es convencerlos de cambiar su flujo diario. La barrera de adopción más alta. | Pendiente | Onboarding < 10 min + demo video 90s + 3 meses gratis coaches beta |
| R2 | **Activación en el primer uso** | La industria sin trial convierte 2–5% de free a pago. El reto es hacer que el coach y el atleta lleguen al "momento aha" (crear atleta → asignar plan → ver check-in) dentro del primer uso. Sin ese gancho en la primera sesión, no vuelven. | Pendiente | Medir tiempo al primer atleta activo + primer plan asignado |
| R3 | **Retención del atleta (churn invisible)** | El atleta progresa pero no lo percibe como parte de la experiencia. Sin racha de adherencia visible, sin evolución mes a mes, sin fotos comparables, cancela cuando pierde motivación. El plan existe — el arraigo no. | **En progreso** | Racha 🔥 done. Módulo nutrición PRO completo (jul-2026): constructores A+B, planned meals 1-tap, water tracking, tip contextual, macro donut — atleta siente que el sistema lo conoce. Pendientes P1: fotos de progreso + vista evolución mes a mes. |
| R4 | **ROI visible para el coach** | El entrenador paga $39–79/mes. Si no siente que le devuelve al menos 3–5x en tiempo ahorrado o clientes retenidos, cancela. El reto es hacer ese ROI tangible y medible dentro de la plataforma. | Pendiente | Panel finanzas exportable + métricas de adherencia de sus atletas |
| R5 | **Monetización sin pasarela** | Sin Stripe o Wompi integrado, el argumento "cobros en COP sin fee" es promesa, no feature. El coach sigue persiguiendo pagos por Nequi. Esto bloquea la propuesta de valor real. | Pendiente | Integrar Wompi/Stripe — P0 en roadmap |
| R6 | **Gaps de producto vs competencia** | Feast Fit, Pulse y Hodara ya tienen fotos de progreso comparables. Feast Fit tiene programación avanzada de fuerza (superseries, dropsets, RIR) que Medaliq no. Estos son table-stakes, no features premium. | En progreso | Matriz de features Bloque 4 — secuencia P1 definida |
| R7 | **Ventanas de oportunidad con fecha de vencimiento** | El fee del 5% de TrueCoach tiene 6–12 meses de impacto máximo. Feast Fit aún no está en Colombia. Pulse es pre-PMF. Estas ventanas se cierran sin aviso. | Pendiente | Ejecutar plan de acción Bloque 6 — urgente dentro de 2 semanas |
| R8 | **Pricing opaco como norma** | Todos los competidores LatAm ocultan su precio. Ser transparente es ventaja de confianza — pero también expone el precio al ataque. El reto es aprovechar la transparencia sin quedar atrapados en guerra de precios. | **Resuelto (2026-07-24)** | Pricing publicado en landing. Diferenciador 0% fee en hero. Sin página comparativa — comunicado por valor propio. |
| R9 | **Onboarding del coach < 10 minutos** | Si el coach no ve valor en la primera sesión, no vuelve la semana 2. El tiempo al "primer atleta activo + plan asignado" es el KPI más crítico de la etapa Launch. | Pendiente | Medir y optimizar — meta: < 10 min desde registro hasta primer plan enviado |
| R10 | **Distribución orgánica** | El coach llega por referido o por contenido. Sin motor de contenido (IG/LinkedIn) y sin sistema de referidos, el CAC escala con gasto publicitario. Feast Fit tiene 3,198 seguidores — el espacio de contenido coach-tech está vacío en Colombia. | Pendiente | Sistema de referidos coach→coach + contenido educativo IG/LinkedIn |
| R11 | **Experiencia del atleta — el diferenciador invisible** | La filosofía "el sistema se siente vivo" está más construida en el backend que en la UX. El atleta hoy no *siente* que el sistema lo conoce, aunque el sistema en realidad lo conoce. Racha, fotos de progreso y evolución mes a mes son las features que hacen ese diferenciador tangible. | **Parcialmente resuelto** | Racha + módulo nutrición PRO (jul-2026) resuelven ~60% del diferenciador tangible. Pendiente: fotos de progreso + vista evolución mes a mes para el 40% restante. |

---

### Prioridad de retos en etapa Launch (hoy)

```
P0 — Bloquean conversión:        R5 (pasarela) · R9 (onboarding)
P1 — Bloquean retención:         R3 (arraigo atleta) · R4 (ROI coach) · R7 (ventanas)
P2 — Bloquean crecimiento:       R1 (cambio de hábito) · R2 (activación trial) · R10 (distribución)
P3 — Bloquean competitividad:    R6 (gaps producto) · R8 (pricing opaco)
```

---

### Cómo usar este bloque

- Al resolver un reto → cambiar estado a `Resuelto` + agregar fecha + nota de qué se hizo
- Al descubrir un reto nuevo → agregar fila con estado `Pendiente` y su palanca
- Al preparar una revisión de producto o estrategia → leer este bloque primero para no resolver lo de menor impacto

---

## BLOQUE 11 — Fuentes

- [Strava Pricing](https://www.strava.com/pricing)
- [TrueCoach Pricing 2026 | Coachbox](https://coachbox.app/en/compare/truecoach-pricing/)
- [TrueCoach Hidden Fees 2026](https://assistantcoach.fit/blog/hidden-fees-fitness-coaching-software/)
- [PT Distinction Pricing](https://www.ptdistinction.com/pricing)
- [Trainerize Coach Report 2025](https://www.trainerize.com/blog/the-coach-report-2025-fitness-nutrition-and-coaching-trends-powered-by-abc-trainerize/)
- [TrainHeroic Pricing | Coachbox](https://coachbox.app/en/compare/trainheroic-pricing/)
- [Final Surge Pricing](https://www.finalsurge.com/pricing)
- [Feast Fit](https://www.feast-fit.com/)
- [Feast Fit — ADN40](https://www.adn40.mx/ciencia/2026-04-13/que-es-feast-fit-y-como-funciona-la-app-activacion-fisica-para-entrenadores)
- [Pulse — LATAM](https://www.pulsefit.app/en)
- [AI Client Evaluation — Pulse](https://www.pulsefit.app/en/features/ai-evaluation)
- [Freemium Conversion Rates | Meegle](https://www.meegle.com/en_us/topics/monetization-models/freemium-conversion-rates)
- [Cuanto cobra entrenador Colombia 2026 | KruxFit](https://kruxfit.ai/blog/cuanto-cuesta-entrenador-personal-colombia)
- [The Founder's Playbook — Anthropic 2026](https://claude.com/blog/the-founders-playbook)
- [MyFitCoach App Review 2025 | Autonomous](https://www.autonomous.ai/ourblog/myfitcoach-app-review)
- [MyFitCoach Pricing | Intercom Help](https://intercom.help/myfitcoach/en/articles/5432890-how-does-the-subscription-payment-work)
- [MyFitCoach Company Profile 2026 | Tracxn](https://tracxn.com/d/companies/myfitcoach/__1lK5yJ96vTqJHdlpSdbYkhFXhqcNEhJN0GrntId6Oik)


## Ideas del CO - (claude no tengas en cuenta este bloque)
tenemos que dirigir a esta app como uso de ventas de servicios de especialistas de la salud ejemplo
Nutricionista / Dietista
Entrenador personal / Fisiólogo del ejercicio
Fisioterapeuta
Terapeuta ocupacional - enfocadas a empresas
Instructor de yoga / Pilates

estas que vienen toca pensarlas mejor pero si son validas
Psicólogo clínico
Psicólogo / Coach de hábitos
Terapeuta de mindfulness / meditación
Terapeuta del lenguaje / Fonoaudiólogo