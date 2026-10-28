# Medaliq — Marketing y Distribucion

> Plan de marketing y distribucion 2026-2027. Analisis competitivo + plan de ejecucion 4 fases.
> Contexto producto -> `CLAUDE.md` | Pricing -> `domains/pagos.md` | Coach -> `domains/coach.md` | Mercado -> `MERCADO.md`
> Ultima actualizacion: 2026-10-06

---

## Contexto

Modelo dual B2B (coach paga tier) + B2C (atleta Pro $9.99/mes). Producto construido, billing implementado (Wompi), sin usuarios reales ni revenue aun. Mercado fitness apps LatAm crece al 27.88% CAGR ($1.1B -> $7.87B en 2034). Ventana de oportunidad: 18-36 meses.

---

## INSTRUCTIVO DE LANZAMIENTO — Paso a Paso

> Este es el orden exacto de ejecucion. Cada paso referencia la seccion del documento donde esta el detalle.
> Marcar [x] cuando se complete. No saltar pasos — estan en orden de dependencia.

---

### PRE-REQUISITO: Dogfood Test (Antes de todo lo demas)

Antes de contactar a un solo coach, verificar que el producto funciona end-to-end.

- [ ] **PASO 0.1** — Verificar que la app esta publicada en App Store y Play Store (no Expo dev). Si no esta, submit inmediato — Apple tarda 1-7 dias en revisar.
  → Ver seccion "Dependencias Tecnicas del Lanzamiento"

- [ ] **PASO 0.2** — Registrarse como coach nuevo (cuenta limpia, no seed). Verificar: se puede crear cuenta sin trabas? El panel coach carga bien?

- [ ] **PASO 0.3** — Crear una rutina de gym con 4 ejercicios en el panel coach. Verificar: el flujo es intuitivo? Cuanto tiempo tomo? (meta: <10 min)

- [ ] **PASO 0.4** — Invitar a 2 personas reales como atletas usando el link `/join/[tu-codigo]`. Pedirles que descarguen la app desde el store, se registren, hagan onboarding, y registren un workout.

- [ ] **PASO 0.5** — Verificar en el panel coach que ves los workouts que registraron tus atletas en tiempo real. Este es el "aha moment" — si no funciona, PARAR y arreglar.

- [ ] **PASO 0.6** — Pedir a un atleta que comparta un PR usando la share card. Verificar: la imagen se ve bien? El deep link funciona (lleva al store o abre la app)? El branding Medaliq es visible?

- [ ] **PASO 0.7** — Verificar que la landing medaliq.com tiene CTA claro para coaches ("Empieza gratis con 2 atletas"), no un CTA generico.

- [ ] **PASO 0.8** — Verificar que los emails transaccionales funcionan (verificacion, reset password). Enviar un email de prueba y confirmar que NO cae en spam.

**Si cualquier paso falla**: resolver ANTES de continuar. No tiene sentido traer coaches a un producto que traba.

---

### SEMANA 1: Crear Canales + Lista de Coaches

**Objetivo**: tener los canales de comunicacion listos y 50 coaches identificados y calificados.

- [ ] **PASO 1.1 — Crear WhatsApp Business**
  - Numero nuevo dedicado (no personal)
  - Configurar mensaje de bienvenida: "Hola, soy Miguel de Medaliq. Gracias por escribirnos. Si eres coach, te cuento como gestionar tus atletas gratis. Si eres atleta, te ayudo a empezar."
  - Agregar link a medaliq.com en el catalogo
  → Ver seccion "WhatsApp Business — CANAL DE CONVERSION"

- [ ] **PASO 1.2 — Crear Instagram @medaliq**
  - Bio: "La plataforma de coaching deportivo para LatAm | Gestiona atletas sin Excel | 0% comision | Empieza gratis"
  - Link en bio: medaliq.com?ref=instagram
  - Highlights vacios por ahora (se llenan despues): "Demo", "Pricing", "Coaches"
  → Ver seccion "Instagram @medaliq — CANAL PRINCIPAL"

- [ ] **PASO 1.3 — Actualizar LinkedIn de Miguel**
  - Headline: "Building Medaliq — coaching deportivo para LatAm | 0 a 1"
  - About: historia breve de por que estas construyendo esto
  → Ver seccion "LinkedIn (perfil Miguel) — AUTORIDAD B2B"

- [ ] **PASO 1.4 — Preparar deck de ventas 1-pager (PDF)**
  - Una sola pagina. Estructura: Problema (Excel + WhatsApp) -> Solucion (Medaliq) -> 3 diferenciadores (0% comision, plan adaptativo, precio accesible) -> Pricing (tiers) -> CTA (link registro)
  - Debe poderse enviar por WhatsApp como archivo adjunto
  → Ver seccion "Messaging Framework"

- [ ] **PASO 1.5 — Armar lista de 50 coaches target**
  - Abrir Instagram. Buscar hashtags: #entrenadorpersonal + Medellin, #coachfitness + Bogota, #coachfitness + Cali
  - Para cada coach encontrado, calificar con el scorecard (seccion ICP):
    - Atletas activos (1-5)
    - Cobra por coaching (1-5)
    - Digitalizacion actual (1-5)
    - Disciplina compatible (1-5)
    - Presencia online (1-5)
    - Disposicion a feedback (1-5, estimado)
  - Solo agregar a la lista si score >= 18/30
  - Guardar en Google Sheet: nombre, Instagram, ciudad, disciplina, score, estado (pendiente)
  - Meta por ciudad: Medellin 20, Bogota 20, Cali 10
  → Ver seccion "ICP — Perfil del Coach Ideal" para criterios detallados y red flags

---

### SEMANA 2: Publicar Contenido Inicial + Primer Post LinkedIn

**Objetivo**: que el perfil de Instagram no se vea vacio cuando un coach entre a revisar quien es Medaliq.

- [ ] **PASO 2.1 — Crear y publicar los 9 posts iniciales de Instagram**
  1. Reel: "Asi se ve gestionar atletas sin Excel" (demo app 30s, screen recording)
  2. Carrusel: "Medaliq vs Excel vs WhatsApp — comparativa para coaches" (5-7 slides)
  3. Reel: "0% comision sobre tus cobros. Tu dinero es tuyo." (texto animado)
  4. Carrusel: "5 cosas que todo coach deberia automatizar hoy"
  5. Reel: "Hola, soy Miguel. Estoy construyendo Medaliq" (face-to-camera, 45s)
  6. Imagen: screenshot del dashboard coach con caption de valor
  7. Carrusel: "Cuanto deberia cobrar un coach en Colombia en 2027?" (datos reales)
  8. Reel: "Tu atleta acaba de hacer un PR. Asi se ve en la app" (demo share card)
  9. Imagen: "Buscamos 20 coaches para nuestra beta privada" (CTA claro, link en bio)
  - Publicar todos en 5-7 dias (no todos el mismo dia). 2 por dia maximo.
  → Ver seccion "9 posts iniciales" para detalle de cada uno

- [ ] **PASO 2.2 — Publicar primer post de LinkedIn**
  - Tema: building in public. "Estoy construyendo Medaliq — una plataforma para que coaches deportivos en LatAm gestionen sus atletas sin Excel. Esto es lo que aprendi esta semana..."
  - Sin link en el post (poner link a medaliq.com en primer comentario)
  - Con screenshot del producto
  → Ver seccion "LinkedIn — Miguel"

- [ ] **PASO 2.3 — Verificar GO/NO-GO para Fase 1**
  Antes de contactar coaches, confirmar:
  - Instagram tiene 9 posts publicados? Si / No
  - WhatsApp Business activo con mensaje de bienvenida? Si / No
  - LinkedIn actualizado con primer post? Si / No
  - Landing medaliq.com con CTA claro para coach? Si / No
  - App publicada en stores? Si / No
  - Dogfood test pasado sin errores? Si / No
  → Ver seccion "Criterios GO/NO-GO — Fase 0 -> Fase 1"
  **Si alguno es NO**: resolver antes de seguir.

---

### SEMANAS 3-4: Primeros 10 Coaches — Outreach

**Objetivo**: contactar 10 coaches, agendar 5-8 demos, registrar 3-5 coaches.

- [ ] **PASO 3.1 — Enviar primer lote de mensajes (10 coaches)**
  - Abrir la lista de 50 coaches (Google Sheet)
  - Tomar los 10 con score mas alto
  - Enviar mensaje por WhatsApp (si tienes su numero) o Instagram DM:

  > "Hola [nombre], soy Miguel de Medaliq. Vi que eres coach de [especialidad] en [ciudad]. Estamos lanzando una plataforma gratuita para que coaches como tu gestionen sus atletas sin Excel ni PDFs — planes que se ajustan automaticamente, nutricion integrada, seguimiento en tiempo real. Estamos invitando a 20 coaches en Colombia para la beta privada. Te gustaria probarla? Es 100% gratis, sin compromisos."

  - Actualizar estado en el Sheet: "contactado" + fecha
  → Ver seccion "Plan de Ejecucion — Fase 1" para script completo

- [ ] **PASO 3.2 — Agendar y hacer demos (15 min cada una)**
  - Para cada coach que responda "si": agendar Zoom o presencial
  - En la demo mostrar: panel coach (crear rutina) + app atleta (registrar workout) + share card
  - Enfatizar: "0% comision, tu dinero es tuyo" + "empieza gratis con 2 atletas"
  - Si le interesa: crear su cuenta Starter en el momento

- [ ] **PASO 3.3 — Onboarding asistido (para cada coach que se registre)**
  - Ayudarle a crear su primera rutina (por WhatsApp, compartir pantalla o presencial)
  - Ayudarle a invitar 2-3 atletas (darle el link `/join/[su-codigo]` y un mensaje sugerido para sus atletas)
  - Verificar que al menos 1 atleta descarga la app y registra un workout
  - Objetivo: que el coach llegue al "aha moment" en <72 horas
  → Ver seccion "Retencion Post-Registro — Plan de Activacion"

- [ ] **PASO 3.4 — Activar secuencia de retencion (por cada coach registrado)**
  - Dia 1: confirmar que creo rutina, si no → mensaje de ayuda
  - Dia 2: confirmar que invito atletas, si no → mensaje con sugerencia
  - Dia 3: confirmar que un atleta registro workout, si no → ayudar
  - Dia 7: pedir feedback (3 preguntas abiertas por WhatsApp)
  - Los mensajes exactos estan en la seccion "Secuencia de onboarding (WhatsApp)"

---

### SEMANAS 5-6: Siguientes 10 Coaches + Check-in con Activos

**Objetivo**: llegar a 15+ coaches activos. Empezar a detectar patrones de feedback.

- [ ] **PASO 4.1 — Contactar siguientes 10 coaches** de la lista (mismo proceso que paso 3.1)

- [ ] **PASO 4.2 — Check-in semanal con coaches activos**
  - Revisar cada 2-3 dias: quien no ha entrado al panel en 5+ dias? Quien tiene 0 atletas activos?
  - Enviar mensajes de reactivacion (ver seccion "Triggers de alerta")

- [ ] **PASO 4.3 — Abrir Google Sheet de feedback**
  - Columnas: Fecha | Coach | Categoria (BUG/FRICTION/FEATURE/SCOPE/NOISE) | Descripcion | Cuantos lo pidieron | Estado | Respuesta dada
  - Cada vez que un coach diga algo sobre el producto, clasificarlo ahi
  → Ver seccion "Manejo de Feedback — Framework de Clasificacion"

- [ ] **PASO 4.4 — Empezar TikTok @medaliq (opcional, si hay tiempo)**
  - 3-5 videos cortos por semana: demos de la app, antes/despues de workflow coach
  - No esperar conversion — es awareness puro
  → Ver seccion "TikTok"

---

### SEMANAS 7-8: Pedir NPS + Asistir a Grupos Presencial

**Objetivo**: medir satisfaccion real. Contactar coaches en comunidades fisicas.

- [ ] **PASO 5.1 — Pedir NPS a cada coach activo**
  - Mensaje WhatsApp: "[nombre], quiero pedirte un favor. En una escala del 1 al 10, que tan probable es que recomiendes Medaliq a otro coach? Y por que?"
  - Documentar las respuestas en el Sheet de feedback
  - Calcular NPS: (% promotores [9-10] - % detractores [0-6]) x 100
  → Meta: NPS >60

- [ ] **PASO 5.2 — Asistir a 2-3 entrenamientos grupales presenciales**
  - Buscar grupos de running en Medellin/Bogota (Correcaminos, Nike Run Club, Medellin Runners)
  - Ir como participante, no como vendedor
  - Hablar con los coaches organizadores despues del entrenamiento
  - Si hay interes: agendar demo, mismo proceso que paso 3.2
  → Ver seccion "Grupos running/CrossFit presencial" en la matriz de canales

- [ ] **PASO 5.3 — Contactar 2-3 academias CrossFit**
  - Buscar boxes medianos en tu ciudad
  - Contactar al head coach por Instagram DM o presencial
  → Ver seccion "Canales adicionales"

---

### SEMANAS 9-10: Evaluar Resultados + Decision GO/NO-GO

**Objetivo**: decidir si activar billing o extender beta.

- [ ] **PASO 6.1 — Contar metricas**
  Llenar esta tabla con datos reales:

  | Metrica | Tu resultado | GREEN | YELLOW | RED |
  |---------|-------------|-------|--------|-----|
  | Coaches activos | ___ | 18+ | 12-17 | <12 |
  | NPS coach | ___ | >60 | 40-60 | <40 |
  | Retencion atleta sem-4 | ___% | >70% | 50-70% | <50% |
  | Coaches que "pagarian hoy" | ___ | 15+ | 10-14 | <10 |
  | Coaches con 5+ atletas | ___ | 5+ | 3-4 | <3 |
  | Bugs criticos abiertos | ___ | 0 | 1-2 | 3+ |

  → Ver seccion "Criterios GO/NO-GO — Fase 1 -> Fase 2"

- [ ] **PASO 6.2 — Tomar la decision**

  **Si GREEN en 5/6**: ir al PASO 7 (activar billing).
  **Si YELLOW en 3+**: extender beta 4 semanas mas. Resolver los gaps. Volver a paso 6.1.
  **Si RED en 2+**: PARAR. Hacer 10 entrevistas con coaches que abandonaron:
  - Por que dejaron de usar Medaliq?
  - Que les falto?
  - Que tienen en comun los que se quedaron vs los que se fueron?
  - Hay un feature deal-breaker que no tenemos?
  → Ver seccion "Preguntas criticas si RED"

---

### MES 3: Activar Billing + Founding Members (solo si GREEN)

- [ ] **PASO 7.1 — Activar Wompi en produccion**
  - Testear flujo completo: coach selecciona tier -> checkout -> pago exitoso -> tier se activa -> features se abren
  - Testear pago fallido
  - Testear webhook de confirmacion
  → Ver seccion "Dependencias Tecnicas — #9 Wompi"

- [ ] **PASO 7.2 — Comunicar founding member pricing a coaches beta**
  - Mensaje WhatsApp a cada coach:
  > "[nombre], la beta fue gratis y tu feedback fue clave para llegar hasta aca. Ahora lanzamos oficialmente. Como founding member, tienes 50% de descuento por 6 meses: Growth a $29.50/mes, Pro a $69.50/mes. Este precio no se va a repetir."

- [ ] **PASO 7.3 — Activar programa de referidos**
  - Cada coach tiene su link unico (`/join/[code]` con parametro `?ref=COACH_CODE`)
  - Comunicar: "Por cada coach que refieras y active 2+ atletas, ambos reciben 1 mes gratis"
  - Los mensajes de comunicacion estan en seccion "Programa de Referidos — Cuando activar"
  → Ver seccion "Programa de Referidos — Mecanica Detallada" para reglas completas

---

### MESES 3-6: Escalar Colombia + Content Marketing

- [ ] **PASO 8.1 — Activar blog + YouTube**
  - Blog: 2 articulos/semana, keywords de la tabla de la seccion "Blog"
  - YouTube: 1 video/semana (tutoriales, guias, entrevistas con coaches)
  → Ver seccion "Plan de Contenido" para formatos y calendario

- [ ] **PASO 8.2 — Seguir calendario semanal de contenido**
  | Dia | Instagram | LinkedIn | TikTok | YouTube | Blog |
  |-----|-----------|----------|--------|---------|------|
  | Lun | Reel | Post BIP | Video demo | - | Articulo |
  | Mar | Story | - | Video trend | - | - |
  | Mie | Carrusel | Post insight | Video tip | - | - |
  | Jue | Story | - | Video B/A | Video | Articulo |
  | Vie | Reel | Post milestone | Video demo | - | - |
  | Sab | Story repost | - | - | - | - |

- [ ] **PASO 8.3 — Iniciar conversaciones con partnerships**
  - Federacion Colombiana de Atletismo
  - Liga Atletismo de Antioquia
  - Universidades con programas deportivos
  → Ver seccion "Partnerships locales"

- [ ] **PASO 8.4 — Medir mensualmente**
  - Coaches pagos (meta: 50 para mes 6)
  - MRR (meta: $5K para mes 6)
  - Churn mensual (meta: <5%)
  - Referidos activados (meta: 15+ coaches via referido)

---

### MESES 7-12: Mexico + Paid (solo si unit economics validados)

- [ ] **PASO 9.1** — Activar pasarela Mexico (Stripe MXN o MercadoPago)
- [ ] **PASO 9.2** — Outreach a coaches mexicanos (mismo proceso que Colombia)
- [ ] **PASO 9.3** — Paid ads SOLO si CAC:LTV >5:1 (Meta $500-1K, TikTok $300-500, Google $300-500/mes)
- [ ] **PASO 9.4** — Activar marketplace de coaches cuando haya 20+ activos
- [ ] **PASO 9.5** — Activar sync Strava
→ Ver seccion "Plan de Ejecucion — Fase 3"

---

### MESES 13-24: Brasil + Employer Wellness (solo si $15K+ MRR)

- [ ] **PASO 10.1** — Completar traducciones portugues
- [ ] **PASO 10.2** — Pasarela Brasil (PIX)
- [ ] **PASO 10.3** — Piloto B2B Employer Wellness
- [ ] **PASO 10.4** — Evaluar seed round si ARR >$200K
→ Ver seccion "Plan de Ejecucion — Fase 4"

---

### MONITOREO CONTINUO (desde semana 1, siempre activo)

- [ ] **Cada 2-3 dias**: revisar triggers de alerta de coaches inactivos → Ver "Triggers de alerta"
- [ ] **Cada semana**: revisar Sheet de feedback, buscar patrones (3+ coaches piden lo mismo = urgente) → Ver "Manejo de Feedback"
- [ ] **Cada 2 semanas**: monitoreo competitivo (App Store, blogs competidores, preguntar a coaches) → Ver "Plan de Competencia Reactiva"
- [ ] **Cada mes**: medir KPIs de la fase actual → Ver "KPIs por Fase"

---

> **Nota**: las secciones debajo de este instructivo contienen el detalle de CADA tema (ICP, canales, contenido, retencion, feedback, referidos, competencia, etc.). El instructivo de arriba dice QUE hacer y CUANDO. Las secciones de abajo dicen COMO y POR QUE.

---

## Analisis Competitivo

### Trainerize (400K coaches, $20M+ ARR)
- Entrada 2008 BlackBerry, pivot B2B 2012. Freemium (1 cliente gratis).
- Pricing: Free(1) -> $9(2) -> $25(5) -> $79(30) -> $225(100). Add-ons ocultos: nutricion $20-45/mes, pagos Stripe $10/mes, white-label $169 setup. Costo real 50 clientes: ~$200/mes.
- Marketing: Content SEO, conferencias fitness (IHRSA, CanFitPro), partnerships (Mindbody). Zero influencer.
- COVID +300%. Adquirida por ABC Financial (Thoma Bravo) 2020 con 150K trainers.
- Debilidad vs Medaliq: pricing opaco, sin plan adaptativo, UI compleja, sin foco LatAm, cobra comision.

### TrueCoach (16K coaches, $1.3M ARR)
- 2015 Boulder. Paid acquisition Facebook/Google (~$200/semana), luego content.
- Pricing: $29.98(5) -> $69.98(20) -> $164.98(50). Sin gratis. Trial 14d.
- Coach Profiles publicos. Guias referral marketing.
- 10K coaches 2019, 15K 2020. Adquirida por Xplor/TSG. Bootstrapped.
- Debilidad: solo ingles, sin LatAm, sin nutricion, sin plan adaptativo, sin B2C.

### Hevy (9M+ usuarios, $2M ARR)
- 2019 Berlin. 2M descargas con $15K en ads. 100% viral loop via features sociales.
- Free (con ads) -> Pro $2.99/mes o $74.99 lifetime.
- Cero paid marketing significativo. Word-of-mouth + ASO.
- De 0 a 2M descargas organico. $240K ARR (2023) -> $2M ARR (2024). Bootstrapped.
- Debilidad: solo B2C gym tracking, sin coach, sin nutricion, sin planes.

### Gravl (70K+ suscriptores, $500K+/mes)
- Fundador argentino. MVP 2 meses, Reddit (300K+ impresiones). LatAm como mercado de lanzamiento (CPMs baratos).
- Free(3 workouts, 5 en Sudamerica) -> $14.99/mes o $59.99-89.99/ano.
- Paid ads Meta/TikTok (~1/3 revenue en ad spend). LatAm para testear creativos, luego USA.
- De $0 a $500K+/mes bootstrapped.
- Leccion: LatAm como laboratorio barato — CPMs 5-10x menores que USA.

### TrainingPeaks (adquirida por Garmin, Jul 2026)
- 1999 bootstrapped. Fundada por Joe Friel. Dolor real: coach con papel y fax.
- Atleta Premium $19.95/mes. Coach $21.99/mes(4) -> $54.99(ilimitado) + $4.50-9/atleta.
- Partnerships federaciones. TrainingPeaks University (certificaciones, tambien espanol). Marketplace planes (70K+).
- ~80 empleados. Adquirida Garmin 2026.
- Leccion: federaciones como canal B2B. Marketplace de planes como revenue futuro.

### Freeletics (54M usuarios, ~$80-100M revenue)
- 2013 Munich. PDF bodyweight -> videos virales. 1M usuarios primer ano.
- Free -> AI Coach $34.99/mes o $99.99/ano.
- Performance marketing agresivo (68% short-form video). Localizacion espanol desde 2013. Retention via Braze.
- Serie A $45M (2018). 54M+ usuarios, 160 paises.
- Debilidad: solo B2C, sin coach humano, sin nutricion real, alto precio.

---

## Patrones de Exito (5)

1. **Coach = canal de distribucion**: 1 coach = 5-30 atletas cautivos. CAC coach $50-100, LTV $1,125 = ratio 11:1.
2. **Freemium con limite claro**: Starter 2 atletas gratis -> upgrade natural. El coach prueba sin riesgo.
3. **LatAm como laboratorio barato**: CPI $0.34-2.00 vs $3-6 USA. Ya nativo en espanol, precio COP.
4. **Social features = motor viral**: Share cards (8 variantes) = anuncio gratuito por cada PR/racha compartida.
5. **Content marketing para coaches**: Educar coaches LatAm sobre coaching digital.

---

## Benchmarks

| Metrica | LatAm | Global |
|---------|-------|--------|
| CPI fitness apps | $0.34-2.00 | $2.50-6.00 |
| Conversion freemium | 0.2-1% | 2-5% |
| Conversion trial 14d | 12-15% | 12-15% |
| Conversion B2B demo | 25-40% | 25-40% |
| Churn B2B coach | 2-5%/mes | 2-5%/mes |
| Churn B2C | 9-12%/mes | 9-12%/mes |
| ARPU B2B coach | $45/mes | $45/mes |
| LTV B2B coach | $400-1,200 | $400-1,200 |
| CAC via referido | $10-35 | $40-100 |
| WhatsApp conversion LatAm | 45-60% | N/A |
| Retencion dia 30 | 25% | 25% |

---

## Stack de Social Media — Que Crear y Para Que

Prioridad: coach (B2B) primero. El atleta llega via el coach.

### Plataformas a crear (orden de prioridad)

| # | Plataforma | Audiencia principal | Rol en el funnel | Prioridad | Crear en |
|---|-----------|---------------------|------------------|-----------|----------|
| 1 | **Instagram @medaliq** | Coaches + atletas | Descubrimiento + prueba social + educacion | CRITICA | Semana 1 |
| 2 | **WhatsApp Business** | Coaches (1:1) | Conversion + soporte + onboarding | CRITICA | Semana 1 |
| 3 | **LinkedIn (perfil Miguel)** | Coaches + industria fitness | Autoridad + networking B2B | ALTA | Semana 1 |
| 4 | **TikTok @medaliq** | Atletas + coaches jovenes | Awareness + viralidad organica | MEDIA | Semana 3 |
| 5 | **YouTube @medaliq** | Coaches (educacion larga) | SEO + tutoriales + confianza | MEDIA | Mes 2 |
| 6 | **Blog medaliq.com/blog** | Coaches (SEO) | Trafico organico + autoridad | MEDIA | Mes 2 |
| 7 | **Pagina Facebook Medaliq** | Coaches 35+ | Presencia + grupos comunidad | BAJA | Mes 3 |

**NO crear por ahora**: Twitter/X (bajo trafico fitness LatAm), Threads (audiencia no definida), Pinterest (no relevante B2B).

### Descripcion por plataforma

**Instagram @medaliq** — CANAL PRINCIPAL
- Bio: "La plataforma de coaching deportivo para LatAm | Gestiona atletas sin Excel | 0% comision | Empieza gratis"
- Link en bio: medaliq.com (con UTM ?ref=instagram)
- Highlights: "Demo", "Pricing", "Coaches", "Testimonios"
- Uso: reels educativos, carruseles de valor, stories behind-the-scenes, DMs para outreach
- Donde esta el trafico: 78% de coaches fitness colombianos tienen Instagram como canal principal. El 65% de entrenadores personales en LatAm usan Instagram para captar clientes (fuente: IHRSA LatAm 2025). Los hashtags #entrenadorpersonal (4.2M posts), #coachfitness (1.8M), #entrenamientopersonalizado (890K) tienen volumen alto y competencia media.

**WhatsApp Business** — CANAL DE CONVERSION
- Numero dedicado (no personal de Miguel)
- Mensaje automatico de bienvenida: "Hola, soy Miguel de Medaliq. Gracias por escribirnos. Si eres coach, te cuento como gestionar tus atletas gratis. Si eres atleta, te ayudo a empezar."
- Catalogos: link a demo, link a registro, pricing
- Uso: outreach directo a coaches, soporte post-registro, check-ins semanales beta
- Donde esta el trafico: WhatsApp tiene 96% de penetracion en Colombia, 93% en Mexico, 99% en Brasil. Tasa de apertura mensajes business: 98% (vs 20% email). Tasa de respuesta: 45-60%. Es el canal con mayor conversion en LatAm para B2B de ticket bajo.

**LinkedIn (perfil Miguel)** — AUTORIDAD B2B
- Headline: "Building Medaliq — coaching deportivo para LatAm | 0 a 1"
- Uso: posts building-in-public (2-3/semana), networking con coaches, conectar con federaciones/empresas
- Donde esta el trafico: 40M+ usuarios LatAm. Los coaches con negocio establecido (target de Medaliq: coaches con 5-30 atletas) estan en LinkedIn. Decision makers de empresas (para B2B Employer Wellness futuro) tambien. Engagement rate organico LinkedIn 2026: 3.8% (vs 1.2% Instagram, 0.07% Facebook).

**TikTok @medaliq** — AWARENESS + VIRALIDAD
- Bio: "Tu entrenamiento con ciencia | App gratuita"
- Uso: videos cortos de la app en accion, tips de entrenamiento, antes/despues de workflow coach
- Donde esta el trafico: 35M+ usuarios en Colombia. Pero el coach target (25-45 anos, con negocio) no es el usuario tipico de TikTok. Sirve para awareness de marca y para llegar a atletas jovenes que luego conecten con coaches en la plataforma. No es canal de conversion B2B.

**YouTube @medaliq** — EDUCACION + SEO
- Uso: tutoriales producto (5-10min), entrevistas coaches, "como montar tu negocio de coaching online"
- Donde esta el trafico: 2do buscador del mundo. Videos de "como ser entrenador personal" tienen 500K-2M views en espanol. Contenido largo genera confianza y es evergreen (sigue trayendo trafico meses despues). Un coach que ve un tutorial de 8min y entiende el producto tiene 3x mas probabilidad de registrarse que uno que ve un reel de 30s.

**Blog medaliq.com/blog** — SEO LONG TAIL
- Uso: articulos para coaches (1,500-2,500 palabras), optimizados para keywords long tail
- Donde esta el trafico: "como gestionar clientes como entrenador personal" tiene ~2,400 busquedas/mes en espanol con competencia baja (KD <20). "app para entrenadores personales" ~1,900/mes. "software coaching deportivo" ~800/mes. El blog atrae coaches que buscan activamente una solucion — intent de compra alto.

---

## Canales de Distribucion — Priorizados por Trafico y Conversion

### Matriz de canales (organico, coach-first)

| # | Canal | Volumen potencial | Conversion esperada | Esfuerzo | Cuando activar |
|---|-------|-------------------|---------------------|----------|----------------|
| 1 | **Outreach WhatsApp directo** | Bajo (50-100 coaches) | MUY ALTA (25-40% demo, 60% registro post-demo) | Alto (manual, 1:1) | Semana 1 |
| 2 | **Instagram DMs a coaches** | Medio (200-500 coaches/mes) | ALTA (10-15% respuesta, 30% demo) | Alto (manual) | Semana 1 |
| 3 | **Instagram contenido organico** | Alto (5K-50K impresiones/mes) | BAJA (0.5-2% click, 5-10% registro) | Medio (3-5 posts/sem) | Semana 1 |
| 4 | **LinkedIn organico (Miguel)** | Medio (2K-10K impresiones/mes) | MEDIA (2-5% click, 15% registro) | Bajo (2-3 posts/sem) | Semana 1 |
| 5 | **Grupos running/CrossFit presencial** | Bajo (5-20 coaches) | MUY ALTA (50%+ interes en persona) | Alto (ir fisicamente) | Semana 3 |
| 6 | **SEO blog** | Alto (1K-5K visitas/mes a 6 meses) | MEDIA (3-8% registro) | Medio (2 posts/sem) | Mes 2 |
| 7 | **YouTube tutoriales** | Medio (500-5K views/video) | ALTA (5-15% click CTA) | Alto (1 video/sem) | Mes 2 |
| 8 | **TikTok organico** | MUY ALTO (10K-100K views) | MUY BAJA (0.1-0.5% conversion) | Medio (3-5 videos/sem) | Mes 1 |
| 9 | **Referidos coach-a-coach** | Bajo-medio (2-5 referidos/coach/ano) | MUY ALTA (70%+ conversion referido) | Bajo (automatico) | Mes 3 |
| 10 | **Partnerships federaciones** | Alto (audiencia cautiva) | MEDIA (depende del acuerdo) | Alto (relaciones) | Mes 4 |

### Estrategia por fase

**Semanas 1-10 (Beta)**: Canales 1-5. Todo es manual y 1:1. El objetivo no es escala, es encontrar 20 coaches que amen el producto. WhatsApp + Instagram DMs son los canales principales de conversion.

**Meses 3-6 (Escalar Colombia)**: Agregar canales 6-9. El content marketing empieza a generar trafico organico. Los referidos se activan. El 1:1 sigue pero ahora complementado con contenido que trabaja 24/7.

**Meses 7-12 (Mexico)**: Todos los canales activos. El blog y YouTube empiezan a generar leads sin esfuerzo adicional. Los partnerships con federaciones abren puertas a audiencias grandes.

---

## Plan de Contenido — Que Publicar, Donde y Cuando

### Tipos de contenido por formato

#### Instagram (3-5 posts/semana)

**Reels (60-70% del contenido)** — el algoritmo favorece video corto
| Tipo | Ejemplo | Funnel stage | Frecuencia |
|------|---------|-------------|------------|
| Demo rapida de feature | "Asi se ve cuando tu atleta registra un PR en Medaliq" (30s pantalla app) | Awareness | 2/sem |
| Pain point del coach | "Sigues mandando rutinas por WhatsApp? Esto es lo que tu atleta ve vs lo que podria ver" (antes/despues) | Consideracion | 1/sem |
| Behind-the-scenes | "Hoy un coach en Medellin empezo a usar Medaliq. Esta es su reaccion" (pantalla + cara) | Confianza | 1/sem |

**Carruseles (20-25% del contenido)** — mayor save rate, bueno para SEO de Instagram
| Tipo | Ejemplo | Funnel stage | Frecuencia |
|------|---------|-------------|------------|
| Tips para coaches | "5 senales de que tu atleta va a abandonar (y como prevenirlo)" | Educacion | 1/sem |
| Comparativa | "Excel vs Medaliq: que pierde tu negocio de coaching con hojas de calculo" | Consideracion | 1/cada 2 sem |
| Data/stats | "El mercado de coaching deportivo en LatAm crece 28% anual. Asi puedes aprovecharlo." | Autoridad | 1/cada 2 sem |

**Stories (diario)** — engagement + humanizar la marca
| Tipo | Ejemplo | Frecuencia |
|------|---------|------------|
| Polls/preguntas | "Coaches: cual es su mayor dolor de cabeza? A) Adherencia B) Cobros C) Seguimiento" | 3/sem |
| Behind-the-scenes | "Hoy estoy trabajando en [feature]. Que les gustaria ver?" | 2/sem |
| Repost share cards de atletas | Compartir stories donde atletas publican sus PRs/rachas via Medaliq | Cuando lleguen |
| Testimonios coaches beta | Screenshot de chat con feedback positivo (con permiso) | 1/sem |

**9 posts iniciales (antes de contactar coaches)**:
1. Reel: "Asi se ve gestionar atletas sin Excel" (demo app 30s)
2. Carrusel: "Medaliq vs Excel vs WhatsApp — comparativa para coaches"
3. Reel: "0% comision sobre tus cobros. Tu dinero es tuyo." (texto animado)
4. Carrusel: "5 cosas que todo coach deberia automatizar hoy"
5. Reel: "Hola, soy Miguel. Estoy construyendo Medaliq" (face-to-camera, 45s)
6. Imagen: screenshot del dashboard coach con caption de valor
7. Carrusel: "Cuanto deberia cobrar un coach en Colombia en 2027?" (datos reales)
8. Reel: "Tu atleta acaba de hacer un PR. Asi se ve en la app" (demo share card)
9. Imagen: "Buscamos 20 coaches para nuestra beta privada" (CTA claro)

#### LinkedIn — Miguel (2-3 posts/semana)

| Tipo | Ejemplo | Frecuencia |
|------|---------|------------|
| Building in public | "Semana 3 de Medaliq: ya tenemos 5 coaches en beta. Esto aprendimos..." | 1/sem |
| Insight de industria | "El 73% de coaches en LatAm aun usan WhatsApp para gestionar clientes. Esto es un problema de $X billones." | 1/sem |
| Historia personal | "Deje [contexto] para construir software para coaches. Esta es la historia." | 1/cada 2 sem |
| Milestone | "20 coaches activos. 0 pesos en marketing. Asi lo hicimos." | Cuando aplique |

Formato que funciona en LinkedIn: texto largo (1,000-1,500 caracteres), con hook en primera linea, sin links en el post (poner link en primer comentario), con imagen o screenshot del producto.

#### TikTok (3-5 videos/semana, empezar semana 3)

| Tipo | Ejemplo | Duracion |
|------|---------|----------|
| App demo satisfying | Registrar workout, ver grafico subir, PR animation | 15-30s |
| Trend + fitness twist | Trend de audio popular + "POV: eres coach y tu atleta registro todo" | 15-30s |
| Before/after workflow | "Como mi coach me mandaba la rutina vs como la recibo ahora" | 30-45s |
| Tips rapidos | "3 apps que todo atleta necesita en 2027" (Medaliq como una de ellas) | 30s |

No esperar conversion directa de TikTok. El objetivo es brand awareness y que la marca aparezca cuando el coach o atleta busque "medaliq" en Google o App Store despues de verlo.

#### YouTube (1 video/semana, empezar mes 2)

| Tipo | Ejemplo | Duracion |
|------|---------|----------|
| Tutorial producto | "Como crear tu primera rutina en Medaliq (paso a paso)" | 5-8min |
| Guia para coaches | "Como montar tu negocio de coaching online desde cero en 2027" | 8-12min |
| Entrevista coach | "Coach [nombre]: como gestiona 15 atletas con Medaliq" | 10-15min |
| Comparativa | "Medaliq vs Trainerize vs TrueCoach — cual te conviene si eres coach en LatAm?" | 8-10min |

Cada video debe tener: titulo SEO optimizado, descripcion con keywords, CTA a registro, timestamps, thumbnail con texto grande.

#### Blog (2 posts/semana, empezar mes 2)

**Keywords target (long tail, baja competencia)**:
| Keyword | Busquedas/mes | KD | Tipo de articulo |
|---------|--------------|-----|-----------------|
| "app para entrenadores personales" | 1,900 | 15 | Listicle + posicionar Medaliq |
| "como gestionar clientes como entrenador" | 2,400 | 12 | Guia completa |
| "software coaching deportivo" | 800 | 8 | Comparativa |
| "cuanto cobrar como entrenador personal colombia" | 3,100 | 10 | Articulo con datos |
| "como hacer seguimiento a mis atletas" | 1,200 | 6 | Guia practica |
| "plan de entrenamiento personalizado app" | 1,600 | 18 | Review + CTA |
| "negocio de coaching deportivo online" | 900 | 11 | Guia paso a paso |
| "app nutricion para entrenadores" | 700 | 7 | Listicle |

**Estructura de cada post**: titulo SEO + intro con dolor + cuerpo (H2s con keywords) + CTA a Medaliq + meta description. 1,500-2,500 palabras. Interno linking entre posts.

### Calendario semanal tipo (despues de mes 2)

| Dia | Instagram | LinkedIn | TikTok | YouTube | Blog |
|-----|-----------|----------|--------|---------|------|
| Lun | Reel (demo) | Post building-in-public | Video demo | - | Publicar articulo |
| Mar | Story (poll) | - | Video trend | - | - |
| Mie | Carrusel (tips) | Post insight industria | Video tip rapido | - | - |
| Jue | Story (BTS) | - | Video before/after | Publicar video | Publicar articulo |
| Vie | Reel (pain point) | Post milestone/historia | Video demo | - | - |
| Sab | Story (repost atletas) | - | - | - | - |
| Dom | - | - | - | - | - |

---

## Funnel de Conversion — Camino del Coach

```
DESCUBRIMIENTO                    CONSIDERACION                 CONVERSION                    RETENCION
(sabe que Medaliq existe)         (evalua si le sirve)          (se registra y usa)           (paga y refiere)

Instagram reel/carrusel ───┐
TikTok video ──────────────┤
LinkedIn post ─────────────┼──> Visita medaliq.com ──────> CTA "Empieza gratis" ──────> Registro Starter
Blog SEO ──────────────────┤    o perfil Instagram           o "Agenda demo"              (2 atletas)
YouTube tutorial ──────────┤                                       |                           |
Referido de otro coach ────┘                                       v                           v
                                                            WhatsApp (Miguel)          Onboarding asistido
                                                            Demo 15min                  (primera rutina)
                                                                   |                           |
                                                                   v                           v
                                                            Registro + setup           Check-in semanal
                                                                                              |
                                                                                              v
                                                                                       Necesita mas atletas
                                                                                       -> Upgrade Growth/Pro
                                                                                              |
                                                                                              v
                                                                                       Refiere a otro coach
                                                                                       (1 mes gratis)
```

**Metricas por etapa del funnel**:
- Descubrimiento -> Consideracion: 2-5% CTR (impresion a click)
- Consideracion -> Demo/Registro: 10-20% (visita a registro)
- Demo -> Registro: 60%+ (post-demo conversion)
- Registro -> Activo (usa 2+ semanas): 70%+ target
- Activo -> Pago: depende de cuando llega al limite de 2 atletas
- Pago -> Referido: 20-30% de coaches pagos refieren al menos 1

---

## ICP — Perfil del Coach Ideal

### Coach que SI queremos (Tier 1 — prioridad maxima)

| Atributo | Valor ideal | Por que |
|----------|------------|---------|
| **Atletas activos** | 5-15 | Suficientes para sentir el dolor de Excel/WhatsApp, pero no tantos que ya tengan sistema. Dispuesto a probar algo nuevo. |
| **Precio por atleta** | $100K-300K COP/mes ($25-75 USD) | Tiene negocio real, no hobby. Puede pagar Growth ($59) porque el ROI es inmediato. |
| **Disciplina** | Gym (entrenamiento de fuerza) o hibrido (gym + running) | Gym esta completo en Medaliq. Running esta en desarrollo. Coaches de gym puro obtienen valor inmediato. |
| **Digitalizacion actual** | WhatsApp + Excel/Google Sheets | Conoce la tecnologia pero usa herramientas no diseñadas para coaching. Dolor alto, barrera de adopcion baja. |
| **Presencia Instagram** | 1K-15K seguidores | Suficiente presencia para que sus atletas lo busquen, no tan grande que ignore mensajes de startups. |
| **Edad** | 25-40 anos | Nativo digital, dispuesto a adoptar herramientas nuevas, con vision de negocio. |
| **Ciudad** | Medellin, Bogota, Cali (Colombia) | Mercado de lanzamiento. Presencial posible para Miguel. |
| **Modelo de coaching** | Online o hibrido (presencial + online) | El coach 100% presencial sin componente online no obtiene tanto valor de Medaliq. |

### Coach que SI queremos (Tier 2 — secundario)

| Atributo | Valor | Por que |
|----------|-------|---------|
| **Atletas activos** | 15-30 | Ya tiene sistema (probablemente una app o Excel avanzado). Mas dificil de convertir pero mayor LTV. |
| **Precio por atleta** | $300K-500K COP/mes ($75-125 USD) | Coach premium. Si lo conviertes, refiere a otros coaches de alto valor. |
| **Disciplina** | Running puro, triatlon, CrossFit | Running esta pendiente en Medaliq. CrossFit puede funcionar con gym existente. |
| **Presencia Instagram** | 15K-50K seguidores | Micro-influencer en nicho fitness. Si lo conviertes, su contenido vale mas que ads. |

### Red flags — Coach que NO queremos (no invertir tiempo)

| Senal | Por que no |
|-------|-----------|
| 0-2 atletas y no cobra | No tiene negocio. Nunca va a pagar. Ocupa soporte sin generar valor. |
| Busca app gratis "para siempre" | No valora herramientas. Va a pedir features gratis y nunca convertir. |
| Solo quiere "ver como funciona" sin comprometerse a probar con atletas | Tourist. No genera datos, no da feedback util, no convierte. |
| Coach de disciplina no soportada (natacion, futbol, ciclismo puro) | El producto no le sirve hoy. Frustración garantizada. |
| Mas de 50 atletas con sistema existente (Trainerize, TrainingPeaks) | Costo de cambio demasiado alto. No vale el esfuerzo en esta etapa. |
| Quiere white-label o marca propia | Medaliq no ofrece white-label. Este coach necesita otra solucion. |

### Calificacion rapida (scorecard para outreach)

Antes de contactar a un coach, puntuar 1-5 en cada criterio:

| Criterio | 1 (malo) | 3 (ok) | 5 (ideal) |
|----------|----------|--------|-----------|
| Atletas activos | 0-2 | 3-5 | 5-15 |
| Cobra por coaching | No cobra | Cobra inconsistente | Cobra mensual fijo |
| Digitalizacion | Solo presencial, sin herramientas | WhatsApp basico | WhatsApp + Excel/Sheets |
| Disciplina compatible | No soportada | Running (parcial) | Gym o hibrido |
| Presencia online | Sin redes | <1K seguidores | 1K-15K seguidores |
| Disposicion a feedback | No responde | Responde pero poco | Activo, da opiniones |

**Score minimo para contactar**: 18/30. Ideal: 24+/30.

---

## Retencion Post-Registro — Plan de Activacion

### "Aha moment" del coach

El coach siente el valor de Medaliq cuando: **su primer atleta registra un workout y el coach lo ve en tiempo real en su panel**. Ese es el momento donde pasa de "herramienta interesante" a "esto me sirve".

Para llegar ahi, el coach necesita completar 3 pasos:
1. Crear su primera rutina/plan en el panel
2. Invitar al menos 1 atleta (idealmente 2-3)
3. El atleta descarga la app, se registra, y registra su primer workout

**Tiempo objetivo para llegar al aha moment: <72 horas desde registro.**

### Secuencia de onboarding (WhatsApp — no email)

En LatAm, WhatsApp tiene 98% de apertura vs 20% de email. Todo el onboarding se hace por WhatsApp.

| Momento | Mensaje WhatsApp | Objetivo |
|---------|-----------------|----------|
| **Registro (hora 0)** | "Bienvenido a Medaliq, [nombre]. Soy Miguel, el fundador. Voy a ayudarte a configurar tu cuenta. Primer paso: crear tu primera rutina. Aqui te muestro como [link a video Loom 2min]. Si tienes dudas me escribes aca." | Activar primer paso |
| **Hora 12 (si no creo rutina)** | "Hey [nombre], como vas? Vi que aun no has creado tu primera rutina. Te grabo un video rapido con tu caso especifico?" | Desbloquear friccion |
| **Dia 1 (si creo rutina)** | "Genial, ya tienes tu primera rutina. Ahora el paso clave: invitar a tus primeros 2 atletas. Les envias este link [link /join/code] y ellos se registran directo. Quieres que te ayude a escribirles el mensaje?" | Activar atletas |
| **Dia 2 (si no invito atletas)** | "Tip: los coaches que mas valor sacan de Medaliq invitan a 2-3 atletas en la primera semana. Te sugiero empezar con los mas activos — los que mas te escriben por WhatsApp. Les puedes mandar esto: [mensaje sugerido para el coach]" | Reducir friccion de invitacion |
| **Dia 3 (si atleta registro workout)** | "Tu atleta [nombre] acaba de registrar su primer workout. Revisa su progreso en tu panel. Esto es lo que tus atletas van a ver cada dia. Que te parece?" | Reforzar aha moment |
| **Dia 7** | "Llevas una semana con Medaliq. Como te ha ido? 3 preguntas rapidas: (1) Que es lo que mas te ha gustado? (2) Que te ha costado mas? (3) Que feature te falta? Responde por aca, no es encuesta formal." | Feedback temprano |
| **Dia 14** | "2 semanas. [X] atletas activos, [Y] workouts registrados. Estas por encima del promedio de coaches en beta. Algun coach colega que creas que le serviria Medaliq? Si me pasas su contacto yo le escribo." | Primer intento referido |
| **Dia 21** | "[nombre], quiero pedirte un favor. En una escala del 1 al 10, que tan probable es que recomiendes Medaliq a otro coach? Y por que? Tu feedback me ayuda mucho." | NPS |
| **Dia 30** | "Un mes. Resumen: [X] atletas, [Y] workouts, [Z] planes creados. Gracias por ser parte de la beta. [Si NPS >8]: Te gustaria ser founding member? Los primeros 20 coaches tienen 50% de descuento de por vida cuando lancemos el pricing." | Conversion / lock-in |

### Triggers de alerta (deteccion de churn temprano)

| Senal | Accion | Responsable |
|-------|--------|-------------|
| Coach no entra al panel en 5 dias | WhatsApp: "Hey [nombre], todo bien? Vi que no has entrado al panel. Necesitas ayuda con algo?" | Miguel (manual en beta, automatizar post-Fase 2) |
| Coach tiene 0 atletas activos despues de 7 dias | WhatsApp: "El mayor valor de Medaliq es ver a tus atletas en tiempo real. Te ayudo a invitar a tus primeros 2?" | Miguel |
| Atleta no registra workout en 7 dias | Notificar al coach: "Tu atleta [nombre] no ha registrado en 7 dias. Quieres enviarle un recordatorio?" | Push notification (automatico, ya implementado) |
| Coach creo rutina pero no asigno a ningun atleta | WhatsApp: "Vi que creaste una rutina excelente. Falta asignarla a un atleta. Te muestro como?" | Miguel |
| Coach cancela o no renueva | Llamada directa (no WhatsApp): "Que paso? Que nos falto?" — documentar razon exacta. | Miguel |

### Metricas de activacion

| Metrica | Target | Frecuencia |
|---------|--------|------------|
| Tiempo a primera rutina creada | <24h | Por coach |
| Tiempo a primer atleta invitado | <48h | Por coach |
| Tiempo a aha moment (atleta registra workout) | <72h | Por coach |
| Coaches que llegan al aha moment en semana 1 | >80% | Semanal |
| Coaches activos semana 2 (entran al panel) | >85% | Semanal |
| Coaches activos semana 4 | >70% | Semanal |

---

## Criterios GO/NO-GO Entre Fases

### Fase 0 -> Fase 1 (Pre-lanzamiento -> Beta)

| Criterio | GREEN (go) | YELLOW (go con ajustes) | RED (no go) |
|----------|-----------|------------------------|-------------|
| Lista de coaches | 50+ coaches identificados y calificados (score 18+/30) | 30-49 coaches | <30 coaches |
| Social media | Instagram con 9 posts + WhatsApp Business activo | Instagram con <9 posts | Sin Instagram |
| Landing page | CTA claro + video demo | CTA sin video | Landing no actualizada |
| App publicada en stores | Si, con ASO basico | En revision de Apple/Google | No enviada a stores |

**Si RED en cualquiera**: no iniciar outreach. Resolver primero.
**Si YELLOW**: iniciar outreach pero con expectativa menor (15 coaches vs 20).

### Fase 1 -> Fase 2 (Beta -> Billing) — DECISION CRITICA

| Criterio | GREEN (activar billing) | YELLOW (extender beta 4 sem) | RED (pivotar o repensar) |
|----------|------------------------|------------------------------|--------------------------|
| Coaches activos | 18-20+ | 12-17 | <12 |
| NPS coach | >60 | 40-60 | <40 |
| Retencion atleta sem-4 | >70% | 50-70% | <50% |
| Coaches que dirian "pagaria hoy" | 15+ (75%+) | 10-14 (50-70%) | <10 (<50%) |
| Coaches con 5+ atletas activos | 5+ coaches | 3-4 coaches | <3 coaches |
| Bugs criticos abiertos | 0 | 1-2 no-blocking | 3+ o 1 blocking |

**Si GREEN en 5/6**: activar billing con confianza.
**Si YELLOW en 3+**: extender beta 4 semanas, resolver los gaps, re-evaluar.
**Si RED en 2+**: STOP. Hacer 10 entrevistas profundas con coaches que abandonaron. Identificar si es problema de producto, ICP, o messaging. No activar billing hasta resolver.

**Preguntas criticas si RED**:
- Los coaches que abandonaron, por que? (producto no sirve vs no tuvieron tiempo vs no entendieron)
- Los que se quedaron, que tienen en comun? (redefinir ICP)
- Hay un feature que todos piden y no tenemos?
- El dolor de WhatsApp/Excel es real o estamos inventando un problema?

### Fase 2 -> Fase 3 (Colombia -> Mexico)

| Criterio | GREEN (expandir) | YELLOW (optimizar Colombia) | RED (no expandir) |
|----------|-----------------|-----------------------------|--------------------|
| Coaches pagos | 40-50+ | 25-39 | <25 |
| MRR | $4K+ | $2K-4K | <$2K |
| Churn mensual coach | <5% | 5-8% | >8% |
| CAC:LTV ratio | >5:1 | 3:1-5:1 | <3:1 |
| Referidos funcionando | 10+ coaches via referido | 5-9 | <5 |
| Razon #1 de churn identificada y resuelta | Si | Identificada, no resuelta | No identificada |

**Si RED en MRR o churn**: no expandir. Arreglar retencion primero. Expandir con churn >8% es quemar dinero.

### Fase 3 -> Fase 4 (Mexico -> Brasil)

| Criterio | GREEN | YELLOW | RED |
|----------|-------|--------|-----|
| Coaches totales CO+MX | 150+ | 100-149 | <100 |
| MRR | $12K+ | $8K-12K | <$8K |
| Mexico funciona | 30+ coaches pagos MX | 15-29 | <15 |
| Unit economics validados | CAC:LTV >5:1 en ambos paises | >5:1 en uno, 3:1 en otro | <3:1 en ambos |

---

## Manejo de Feedback — Framework de Clasificacion

### Categorias de feedback

| Categoria | Definicion | Accion | Tiempo de respuesta |
|-----------|-----------|--------|---------------------|
| **BUG** | Algo no funciona como deberia | Corregir en <24h (critico) o <72h (menor) | Inmediato |
| **FRICTION** | Funciona pero es confuso/dificil | Evaluar UX, resolver en sprint actual si afecta activacion | <1 semana |
| **FEATURE REQUEST — Core** | Feature que multiples coaches piden Y esta alineado con la vision | Agregar al roadmap, comunicar timeline al coach | Comunicar en <48h |
| **FEATURE REQUEST — Nice-to-have** | Un coach lo pide, no es patron | Documentar, no priorizar. Revisar si se repite en 3+ coaches | Agradecer, no prometer |
| **FUERA DE SCOPE** | No se alineae con la vision del producto | Explicar por que no, sugerir alternativa si existe | Comunicar honestamente |
| **NOISE** | Preferencias personales, "yo haria X diferente" | Agradecer, no actuar | Agradecer |

### Como decir "no" sin perder al coach

**Template para feature fuera de scope**:
> "Gracias por la sugerencia, [nombre]. Entiendo por que lo necesitas. Hoy Medaliq no hace [X] porque estamos enfocados en [Y] — que es donde creemos que podemos darte mas valor. Si esto cambia te aviso. Mientras tanto, [alternativa si existe]."

**Template para feature que vamos a hacer pero no ahora**:
> "[nombre], varios coaches nos han pedido esto. Esta en nuestro roadmap para [mes/fase]. Te aviso cuando este listo. Mientras tanto, [workaround temporal si existe]."

**Template para feedback negativo sobre UX**:
> "Tienes razon, eso puede ser mejor. Lo estoy arreglando esta semana. Te mando un video cuando este listo para que me digas si quedo bien."

### Reglas de priorizacion

1. Si 3+ coaches piden lo mismo en la misma semana -> es urgente, evaluar esta semana
2. Si 1 coach lo pide pero es un deal-breaker para el (amenaza con irse) -> evaluar si el ICP tiene el mismo problema
3. Si mejora la activacion (reduce tiempo al aha moment) -> prioridad alta aunque solo 1 coach lo pida
4. Si es cosmético o preferencia personal -> no priorizar
5. **Nunca construir una feature porque UN coach grande lo pida**. Validar contra el ICP primero.

### Documentacion de feedback

Spreadsheet simple (Google Sheets) con columnas:
- Fecha
- Coach (nombre)
- Categoria (BUG/FRICTION/FEATURE/SCOPE/NOISE)
- Descripcion textual
- Cuantos coaches lo pidieron (counter)
- Estado (pendiente/en progreso/resuelto/rechazado)
- Respuesta dada al coach

Revisar semanalmente. Patterns que aparecen en 3+ coaches en la misma semana van directo al sprint.

---

## Dependencias Tecnicas del Lanzamiento — Checklist

### Criticas (bloqueantes — sin esto no se lanza)

| # | Dependencia | Estado | Accion requerida |
|---|-----------|--------|-----------------|
| 1 | **App publicada en App Store (iOS)** | Verificar | Si no esta publicada: submit con 2+ semanas de anticipacion (review Apple toma 1-7 dias, puede rechazar). Necesita: screenshots, descripcion, privacy policy, categoria correcta (Health & Fitness). |
| 2 | **App publicada en Play Store (Android)** | Verificar | Si no esta publicada: submit. Review Google toma 1-3 dias. Mismos assets que iOS. |
| 3 | **Landing medaliq.com optimizada para messaging del plan** | Verificar | CTA principal debe ser "Empieza gratis con 2 atletas" (no generico). Hero debe hablarle al coach, no al atleta. Seccion de pricing visible. Video demo embebido. |
| 4 | **Perfil publico coach (`/join/[code]`) funcional y optimizado** | Verificar | Esta pagina es la landing de cada coach para sus atletas. Debe: cargar rapido, tener CTA claro "Registrate con [coach]", mostrar info del coach, funcionar en mobile. |
| 5 | **Onboarding coach panel web fluido** | Verificar | Un coach nuevo puede crear su primera rutina sin ayuda? Testear el flujo completo: registro -> panel -> crear rutina -> invitar atleta. Cada paso donde se trabe = atleta perdido. |
| 6 | **Flujo atleta mobile end-to-end** | Verificar | Atleta recibe link /join/[code] -> descarga app -> se registra -> ve plan del coach -> registra primer workout. Testear en iOS Y Android. |
| 7 | **Emails transaccionales funcionando (Resend)** | Verificar | Verificacion de email, reset password, invitacion de atleta. Verificar que no caigan en spam. |

### Importantes (no bloqueantes pero afectan calidad del lanzamiento)

| # | Dependencia | Estado | Accion requerida |
|---|-----------|--------|-----------------|
| 8 | **Share cards con deep links funcionales** | Verificar | Las 8 variantes deben tener deep link que abra la app (si instalada) o lleve al store (si no). Testear en iOS y Android. Si solo son imagenes sin link, el efecto viral se reduce 80%. |
| 9 | **Wompi sandbox testeado end-to-end** | Verificar | Flujo completo: coach selecciona tier -> checkout Wompi -> pago exitoso -> tier se activa -> feature gates se abren. Testear con tarjeta de prueba. Testear pago fallido. Testear webhook de confirmacion. |
| 10 | **ASO: app indexada con keywords correctas** | Verificar | Buscar "app entrenamiento personalizado" y "coach fitness" en App Store y Play Store. Medaliq aparece? Si no, optimizar titulo + subtitulo + keywords. |
| 11 | **Analytics basico implementado** | Verificar | Necesitamos medir: registros, activacion (aha moment), retencion dia 7/14/30, share cards compartidas. Sin analytics volamos ciegos. Minimo: Vercel Analytics (web) + un evento custom de registro. |
| 12 | **Rate limiting en endpoints publicos** | Verificar | Un coach en beta puede descubrir un bug y pegarle repetidamente a un endpoint. Los endpoints de registro, login, y forgot-password deben tener rate limiting. |

### Verificacion pre-lanzamiento (ejecutar semana 1)

Hacer un "dogfood test" completo:
1. Miguel se registra como coach nuevo (cuenta limpia, no seed)
2. Crea una rutina de gym con 4 ejercicios
3. Invita a 2 personas reales (amigos) como atletas
4. Cada atleta descarga la app, se registra via /join/[code], hace onboarding
5. Cada atleta registra 1 workout
6. Miguel ve los workouts en su panel coach
7. Un atleta comparte su PR via share card en Instagram Stories
8. Verificar que el deep link de la share card funcione

**Si cualquier paso falla o tiene friccion alta**: resolver ANTES de contactar coaches.

---

## Plan de Competencia Reactiva

### Escenarios y respuestas

| Escenario | Probabilidad | Senal de alerta | Respuesta |
|-----------|-------------|-----------------|-----------|
| **Trainerize lanza pricing LatAm** (descuento agresivo para LATAM) | Media | Anuncio en blog/redes de Trainerize, coaches mencionan descuentos | Reforzar messaging de 0% comision (Trainerize cobra por pagos y add-ons). Crear comparativa directa: "Costo real de Trainerize vs Medaliq". No competir en precio — competir en simplicidad y que el dinero del coach es suyo. |
| **Hevy agrega coaching B2B** | Media-Baja | Feature announcement, beta B2B | Hevy es B2C puro (9M usuarios gym tracking). Si agregan B2B sera generico. Medaliq tiene ventaja en: nutricion integrada, plan adaptativo, espanol nativo. Acelerar features diferenciadoras. |
| **Competidor local colombiano aparece** | Media | App nueva en store con keywords similares, coaches mencionan alternativa | Velocidad de iteracion. Si ya tenemos 20+ coaches activos, el lock-in de datos y habito es la barrera. Ofrecer migracion de datos si un coach esta considerando cambiar desde el competidor. |
| **App global (Freeletics, Nike Training) agrega coaching humano** | Baja | Anuncio en prensa tech | Estos jugadores van a hacer algo generico y caro. No es amenaza real para coaching personalizado 1:1 en LatAm. Ignorar y seguir ejecutando. |
| **Coach influyente habla mal de Medaliq publicamente** | Baja | Post negativo en redes con alcance | Contactar directamente (WhatsApp, no publico). Entender el problema. Resolver si es legitimo. Si es injusto, responder con datos en privado. Nunca pelear en publico. |

### Ventajas competitivas permanentes (moat)

Estas ventajas se profundizan con el tiempo y son dificiles de replicar:

1. **Datos del coach**: cada rutina, plan, y progreso de atleta que se registra en Medaliq es data que el coach no quiere perder. A los 6 meses de uso, cambiar de plataforma implica perder 6 meses de historial. Lock-in natural.
2. **0% comision**: decision de negocio, no de tecnologia. Competidores que ya cobran comision no pueden quitarla sin afectar su revenue.
3. **Espanol nativo + pricing local**: no es traduccion — es producto pensado desde cero para LatAm. UX, copy, metodos de pago, moneda local. Un competidor anglofono necesita equipo local para replicar esto.
4. **Relacion directa con coaches (en beta)**: Miguel conoce personalmente a los primeros 20 coaches. Esa relacion se convierte en loyalty y advocacy que ningun competidor puede comprar.

### Monitoreo competitivo (quincenal)

- Revisar App Store/Play Store: buscar "coach fitness", "entrenamiento personalizado" — nuevas apps?
- Revisar blogs/newsletters de Trainerize, TrueCoach, Hevy — anuncios de LatAm o espanol?
- Preguntar a coaches beta: "Has visto alguna alternativa que te llame la atencion?"
- Google Alerts: "app coaching deportivo LatAm", "entrenador personal app Colombia"

---

## Programa de Referidos — Mecanica Detallada

### Mecanica

**Propuesta de valor**: "Refiere a un coach. Si se registra y activa 2+ atletas, ambos reciben 1 mes gratis de su tier actual."

### Flujo completo

```
Coach A (referidor)                    Coach B (referido)
      |                                      |
      v                                      |
Comparte su link unico                       |
(/join/[code] o link con                     |
parametro ?ref=COACH_A_CODE)                 |
      |                                      |
      v                                      v
                                    Coach B recibe el link
                                    (via WhatsApp del Coach A
                                     o via redes sociales)
                                             |
                                             v
                                    Coach B se registra
                                    (el sistema guarda ref=COACH_A_CODE)
                                             |
                                             v
                                    Coach B activa 2+ atletas
                                    (trigger de activacion)
                                             |
                                             v
                                    Sistema notifica a ambos:
                                    - Coach A: "Tu referido [Coach B] ya esta activo.
                                      Tienes 1 mes gratis. Gracias!"
                                    - Coach B: "Bienvenido. Tienes 1 mes gratis
                                      por ser referido de [Coach A]."
```

### Reglas del programa

| Regla | Detalle |
|-------|---------|
| **Que cuenta como "referido activo"** | Coach B se registra Y tiene 2+ atletas que registraron al menos 1 workout cada uno. No basta con registrarse — tiene que activarse. |
| **Recompensa** | 1 mes gratis del tier actual para ambos (referidor y referido). Si el referidor esta en Starter (gratis), recibe 1 mes de Growth gratis. |
| **Limite por coach** | Sin limite. Un coach puede referir 10 coaches y recibir 10 meses gratis. Es el mejor CAC posible ($59-139 vs $0 marginal). |
| **Acumulacion** | Los meses gratis se acumulan. Si un coach refiere 3 coaches en el mismo mes, tiene 3 meses gratis a partir del siguiente ciclo de billing. |
| **Expiracion del link** | Sin expiracion. El link de referido del coach funciona siempre. |
| **Atribucion** | First-touch. Si Coach B recibio links de Coach A y Coach C, el primero que le llego gana la atribucion. |
| **Coaches Starter (gratis)** | Tambien pueden referir. Su recompensa es 1 mes de Growth gratis (upgrade temporal). Esto incentiva que coaches gratis evangelicen. |
| **Autoregistro** | Un coach no puede referirse a si mismo (validar por email/dispositivo). |

### Tracking tecnico

**Opcion 1 (MVP — Fase 2)**: parametro `?ref=CODE` en la URL de registro. El `CODE` es el mismo codigo del perfil publico del coach (`/join/[code]`). Al registrarse, el sistema guarda `referredBy: coachId` en la tabla User. Cuando el referido activa 2 atletas, un cron o trigger otorga el mes gratis a ambos.

**Opcion 2 (post-Fase 2)**: dashboard de referidos en el panel coach. El coach ve: cuantos referidos envio, cuantos se registraron, cuantos se activaron, cuantos meses gratis acumulo.

### Comunicacion al coach (cuando activar)

**Momento 1 — Al llegar a semana 2 activo** (WhatsApp):
> "[nombre], ya llevas 2 semanas con Medaliq. Si conoces a algun coach que le pueda servir, compartele tu link: [link]. Si se registra y activa 2 atletas, ambos reciben 1 mes gratis."

**Momento 2 — Al hacer upgrade a Growth/Pro** (WhatsApp):
> "Gracias por hacer upgrade, [nombre]. Recuerda que por cada coach que refieras con tu link, ambos reciben 1 mes gratis. Tu link: [link]"

**Momento 3 — Al cumplir 1 mes activo** (WhatsApp):
> "1 mes con Medaliq. [X] atletas, [Y] workouts. Si quisieras tener el siguiente mes gratis, solo necesitas que un colega se registre con tu link: [link]"

### Proyeccion

- Benchmark referral rate SaaS B2B: 15-25% de usuarios activos refieren al menos 1
- Si tenemos 50 coaches pagos y 20% refiere: 10 referidos
- Conversion de referido: 70%+ (viene con recomendacion directa)
- CAC via referido: $59-139 (1 mes gratis) vs CAC directo: $50-150
- Pero el referido viene pre-calificado y con intencion alta -> LTV mayor

---

## Plan de Ejecucion — 4 Fases

### Fase 0: Pre-lanzamiento (Semanas 1-2) — $0
- Crear Instagram @medaliq + publicar 9 posts iniciales
- Crear WhatsApp Business con mensaje automatico
- Actualizar LinkedIn de Miguel (headline, about, posts)
- ASO basico (keywords espanol, screenshots, descripcion App Store + Play Store)
- Landing optimizada (CTA coach "2 atletas gratis" + video demo Loom 2min)
- Deck ventas 1-pager PDF (problema -> solucion -> pricing -> 0% comision)
- Lista 50 coaches target (Medellin/Bogota/Cali, Instagram 1K-50K)

### Fase 1: Beta Cerrada Colombia (Semanas 3-10) — $200
**Objetivo**: 20 coaches activos, NPS >60, retencion semana-4 >70%

**Outreach directo** (primer contacto WhatsApp):
> "Hola [nombre], soy Miguel de Medaliq. Vi que eres coach de [especialidad] en [ciudad]. Estamos lanzando una plataforma gratuita para que coaches como tu gestionen sus atletas sin Excel ni PDFs — planes que se ajustan automaticamente, nutricion integrada, seguimiento en tiempo real. Estamos invitando a 20 coaches en Colombia para la beta privada. Te gustaria probarla? Es 100% gratis, sin compromisos."

**Proceso**: WhatsApp -> demo 15min -> cuenta Starter -> onboarding asistido -> check-in semanal 4 sem -> NPS + feedback.

**Target**: Medellin 8, Bogota 7, Cali 3, otras 2.

**Canales activos**: WhatsApp DM, Instagram DMs, Instagram contenido, LinkedIn Miguel, TikTok (empezar sem 3).
**Canales adicionales**: grupos running Colombia presencial, academias CrossFit, Instagram DMs coaches.

**Share cards** como growth loop (8 variantes con branding + deep link/QR).

### Fase 2: Billing + Escalar Colombia (Meses 3-6) — $500-1,000/mes
**Objetivo**: 50 coaches pagos, $5K MRR

- Activar Wompi produccion + enforcement tiers
- Founding member: 50% off 6 meses (Growth $29.50, Pro $69.50)
- Programa referidos: coach refiere coach -> ambos 1 mes gratis (via `/join/[code]`)
- Activar blog + YouTube (content marketing)
- Canales activos: todos los de Fase 1 + Blog SEO + YouTube + Referidos + Facebook page
- Partnerships: FCA, Liga Atletismo Antioquia, universidades

### Fase 3: Escalar + Mexico (Meses 7-12) — $1,500-3,000/mes
**Objetivo**: 200 coaches, $15K MRR

- Pasarela Mexico (Stripe MXN o MercadoPago), pricing MXN
- Paid ads controlado: Meta $500-1K, TikTok $300-500, Google $300-500/mes (solo si CAC:LTV >5:1)
- Activar sync Strava (backend listo)
- Marketplace coaches (activar con 20+ coaches, SEO por perfil)

### Fase 4: Brasil + Employer Wellness (Meses 13-24)
**Objetivo**: 500 coaches, $62K MRR, $744K ARR

- Localizacion portugues (i18n parcialmente implementado)
- Pasarela Brasil: PIX (MercadoPago o Stripe)
- B2B Employer Wellness: empresas pagan Pro de empleados ($10-15/empleado/mes)
- Preparar seed round si numeros lo justifican ($200K-400K ARR base)

---

## Presupuesto Total 12 Meses: ~$19,600

| Concepto | M1-3 | M4-6 | M7-12 | Total |
|----------|------|------|-------|-------|
| Outreach directo | $200 | $200 | $100 | $500 |
| Founding member discounts | $0 | $1,500 | $1,500 | $3,000 |
| Programa referidos | $0 | $500 | $2,000 | $2,500 |
| Contenido | $0 | $300 | $1,800 | $2,100 |
| Paid ads | $0 | $0 | $9,000 | $9,000 |
| Partnerships | $0 | $500 | $2,000 | $2,500 |

Nota: ads solo se activan con unit economics validados (CAC:LTV >5:1).

---

## Messaging Framework

**Para coaches (B2B)**: "Gestiona a tus atletas sin Excel ni WhatsApp. 0% comision sobre tus cobros. Empieza gratis."
- Pilares: ahorro tiempo, 0% comision, plan adaptativo, precio accesible, espanol nativo.

**Para atletas (B2C)**: "Tu entrenamiento con ciencia. Registra, mide, mejora."
- Pilares: simple (30s), inteligente (ajuste semanal), completo (gym+running+nutricion).

---

## KPIs por Fase

| Fase | Metrica norte | Target |
|------|--------------|--------|
| 0 | Coaches contactables | 50 |
| 1 | Coaches activos beta | 20, NPS >60, retencion >70% |
| 2 | Coaches pagos / MRR | 50 / $5K, churn <5% |
| 3 | Coaches CO+MX / MRR | 200 / $15K, CAC:LTV >5:1 |
| 4 | Coaches total / MRR / ARR | 500 / $62K / $744K |

---

## Riesgos

| Riesgo | Mitigacion |
|--------|------------|
| Coaches no dejan WhatsApp/Excel | No reemplazar — complementar. Medaliq = sistema de registro. |
| Atletas no descargan app | Coach los trae. Onboarding asistido. |
| Competidor financiado entra LatAm | Velocidad iteracion + features unicas + lock-in datos. |
| Churn alto primeros meses | Check-in semanal, resolver en <24h. |
| Wompi falla produccion | Testing sandbox completo. Fallback manual founding members. |
