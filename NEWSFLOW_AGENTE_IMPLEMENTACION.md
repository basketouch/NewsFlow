# IMPLEMENTACIÓN DEL AGENTE EN NEWSFLOW
## Documento técnico para el dev

---

## RESUMEN EJECUTIVO

El agente Claude genera automáticamente **drafts de contenido** (newsletters, posts RRSS, descripciones vídeo) que aparecen en una **nueva sección "AI Drafts"** en tu app iOS. 

**No reemplaza nada existente.** Es paralelo a tu flujo actual.

---

## STACK A USAR

```
Componente          | Tecnología actual    | Agente usa
────────────────────|──────────────────────|─────────────
App iOS             | SwiftUI + MVVM       | (sin cambios)
Backend             | Supabase PostgreSQL  | (reutiliza)
Automatización      | n8n (basketouch.com) | Webhooks
IA Generación       | Gemini Flash         | Claude API (agente)
IA Copywriting      | GPT-4o-mini          | Claude API (agente)
Horarios            | GitHub Actions       | (nuevo)
Publicación web     | GitHub + Vercel      | (sin cambios)
Email               | Brevo                | (reutiliza)
```

---

## ARQUITECTURA: AGENTE + NEWSFLOW

```
┌──────────────────────────────────────────────────────────┐
│                    AGENTE CLAUDE                          │
│                  (Node.js + Express)                      │
│                                                          │
│  Ejecutado: GitHub Actions (lunes 9 AM)                 │
│  O manual: Webhook desde iOS app                         │
│                                                          │
│  Genera:                                                  │
│  ├─ Newsletter drafts (JSON + HTML)                      │
│  ├─ Posts RRSS (LinkedIn, Instagram, X)                  │
│  ├─ Descripciones video (YouTube)                        │
│  └─ Inserta en tabla: ai_drafts (Supabase)              │
└──────────────────────────────────────────────────────────┘
                           ↓
        ┌────────────────────────────────────┐
        │    SUPABASE (Nueva tabla)           │
        │                                    │
        │    ai_drafts                       │
        │    ├─ id, type, content            │
        │    ├─ quality_score, status        │
        │    ├─ metadata (platforms, etc)    │
        │    └─ created_at, enriched_at      │
        │                                    │
        │    (otras tablas sin cambios)      │
        └────────────────────────────────────┘
                           ↓
        ┌────────────────────────────────────┐
        │      NEWSFLOW iOS APP (Actual)      │
        │                                    │
        │  Home (Grid 6 opciones)            │
        │  ├─ Noticias (sin cambios)         │
        │  ├─ Newsletter (sin cambios)       │
        │  ├─ RRSS (sin cambios)             │
        │  ├─ Videos (sin cambios)           │
        │  ├─ Archivo (sin cambios)          │
        │  └─ [NUEVA] AI Drafts ← AQUÍ       │
        │                                    │
        │  + API endpoints nuevos:           │
        │    GET /api/ai-drafts              │
        │    POST /api/ai-drafts/:id/enrich  │
        │    POST /api/ai-drafts/:id/publish │
        └────────────────────────────────────┘
```

---

## FASE 1: MVP (2 semanas)

### 1.1 Base de datos: Nueva tabla `ai_drafts`

```sql
CREATE TABLE ai_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Tipo de contenido
  type TEXT NOT NULL,
  -- "newsletter" | "linkedin_post" | "instagram_post" | "youtube_description"
  
  -- Contenido generado
  title TEXT,
  content TEXT NOT NULL,
  
  -- Metadatos
  metadata JSONB DEFAULT '{}',
  -- {
  --   "hashtags": ["#AI", "#Leadership"],
  --   "cta": "Leer artículo →",
  --   "platform": "linkedin",
  --   "source_articles": [id1, id2, id3],
  --   "topics": ["AI", "Leadership"]
  -- }
  
  -- Calidad (asignada por agente)
  quality_score INT,
  quality_details JSONB,
  -- {
  --   "relevancia": 88,
  --   "coherencia": 85,
  --   "tono": 86,
  --   "engagement_potential": 82
  -- }
  
  -- Estado del draft
  status TEXT DEFAULT 'pending_review',
  -- "pending_review" | "enriched" | "rejected" | "published"
  
  -- Enriquecimiento (si tú lo editas)
  enriched_content TEXT,
  enriched_metadata JSONB,
  enriched_by_user_at TIMESTAMP,
  
  -- Rechazo (si no te gusta)
  rejection_reason TEXT,
  rejection_feedback TEXT,
  rejected_at TIMESTAMP,
  
  -- Publicación
  published_at TIMESTAMP,
  published_to TEXT[], -- ["linkedin", "instagram"]
  publish_results JSONB, -- {linkedin: {status, url}, instagram: {...}}
  
  -- Tracking
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Índices
CREATE INDEX idx_ai_drafts_status ON ai_drafts(status);
CREATE INDEX idx_ai_drafts_type ON ai_drafts(type);
CREATE INDEX idx_ai_drafts_created ON ai_drafts(created_at DESC);
```

### 1.2 Políticas RLS

```sql
-- Usuario puede ver sus propios drafts
ALTER TABLE ai_drafts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_can_view_ai_drafts" ON ai_drafts
  FOR SELECT USING (auth.uid() = '2e30c1d3-...'); -- Tu user_id

CREATE POLICY "users_can_update_ai_drafts" ON ai_drafts
  FOR UPDATE USING (auth.uid() = '2e30c1d3-...');
  
-- El agente (con admin secret) puede insert/update
CREATE POLICY "agent_can_manage_ai_drafts" ON ai_drafts
  FOR ALL USING (
    current_setting('app.agent_secret') = 'tu_secret_aqui'
  );
```

---

### 1.3 API Backend: Nuevos endpoints

**Archivo:** `backend/api-agent.js` (nuevo)

```javascript
// GET /api/ai-drafts
// Retorna lista de drafts pendientes
app.get('/api/ai-drafts', authenticateUser, async (req, res) => {
  const { data, error } = await supabase
    .from('ai_drafts')
    .select('*')
    .eq('status', 'pending_review')
    .order('created_at', { ascending: false });
  
  if (error) return res.status(500).json({ error });
  res.json({ drafts: data });
});

// GET /api/ai-drafts/:id
// Detalle de un draft
app.get('/api/ai-drafts/:id', authenticateUser, async (req, res) => {
  const { data, error } = await supabase
    .from('ai_drafts')
    .select('*')
    .eq('id', req.params.id)
    .single();
  
  if (error) return res.status(404).json({ error });
  res.json({ draft: data });
});

// POST /api/ai-drafts/:id/enrich
// Guardar ediciones del usuario
app.post('/api/ai-drafts/:id/enrich', authenticateUser, async (req, res) => {
  const { title, content, hashtags, cta } = req.body;
  
  const { data, error } = await supabase
    .from('ai_drafts')
    .update({
      enriched_content: content,
      enriched_metadata: { hashtags, cta },
      status: 'enriched',
      enriched_by_user_at: new Date()
    })
    .eq('id', req.params.id)
    .select()
    .single();
  
  if (error) return res.status(500).json({ error });
  res.json({ draft: data, message: 'Draft enriquecido' });
});

// POST /api/ai-drafts/:id/publish
// Publicar a plataformas
app.post('/api/ai-drafts/:id/publish', authenticateUser, async (req, res) => {
  const { platforms } = req.body; // ["linkedin", "instagram", "youtube"]
  const { data: draft } = await supabase
    .from('ai_drafts')
    .select('*')
    .eq('id', req.params.id)
    .single();
  
  const publishResults = {};
  
  for (const platform of platforms) {
    try {
      const result = await publishToPlatform(platform, draft);
      publishResults[platform] = result;
    } catch (err) {
      publishResults[platform] = { status: 'error', error: err.message };
    }
  }
  
  // Actualizar estado
  const { data: updated } = await supabase
    .from('ai_drafts')
    .update({
      status: 'published',
      published_at: new Date(),
      published_to: platforms,
      publish_results: publishResults
    })
    .eq('id', req.params.id)
    .select()
    .single();
  
  res.json({ draft: updated, publish_results: publishResults });
});

// POST /api/ai-drafts/:id/reject
// Rechazar draft con feedback
app.post('/api/ai-drafts/:id/reject', authenticateUser, async (req, res) => {
  const { reason, feedback } = req.body;
  
  await supabase
    .from('ai_drafts')
    .update({
      status: 'rejected',
      rejection_reason: reason,
      rejection_feedback: feedback,
      rejected_at: new Date()
    })
    .eq('id', req.params.id);
  
  // [Opcional] Enviar feedback al agente para mejorar
  // await fetch(AGENTE_FEEDBACK_WEBHOOK, { method: 'POST', body: {...} });
  
  res.json({ message: 'Draft rechazado, feedback registrado' });
});
```

---

### 1.4 Agente: Node.js + Express

**Archivo:** `backend/agente.js` (nuevo)

```javascript
const Anthropic = require("@anthropic-ai/sdk");
const express = require("express");
const { createClient } = require("@supabase/supabase-js");

const app = express();
app.use(express.json());

const client = new Anthropic();
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// Herramientas del agente
const tools = [
  {
    name: "buscar_contenido",
    description: "Busca artículos y noticias sobre temas específicos",
    input_schema: {
      type: "object",
      properties: {
        temas: { type: "array", items: { type: "string" } },
        idioma: { type: "string", enum: ["es", "en"] }
      },
      required: ["temas"]
    }
  },
  {
    name: "generar_newsletter",
    description: "Genera draft de newsletter INSIDE Life",
    input_schema: {
      type: "object",
      properties: {
        articulos_ids: { type: "array", items: { type: "string" } },
        tema_central: { type: "string" }
      },
      required: ["articulos_ids", "tema_central"]
    }
  },
  {
    name: "generar_post_rrss",
    description: "Genera posts para LinkedIn, Instagram, X",
    input_schema: {
      type: "object",
      properties: {
        tema: { type: "string" },
        plataforma: { type: "string", enum: ["linkedin", "instagram", "x"] },
        tono: { type: "string" }
      },
      required: ["tema", "plataforma"]
    }
  },
  {
    name: "validar_calidad",
    description: "Valida y asigna score de calidad al contenido",
    input_schema: {
      type: "object",
      properties: {
        contenido: { type: "string" },
        tipo: { type: "string" },
        audiencia: { type: "string" }
      },
      required: ["contenido", "tipo"]
    }
  },
  {
    name: "insertar_draft_supabase",
    description: "Inserta el draft en tabla ai_drafts",
    input_schema: {
      type: "object",
      properties: {
        type: { type: "string" },
        content: { type: "string" },
        title: { type: "string" },
        metadata: { type: "object" },
        quality_score: { type: "number" }
      },
      required: ["type", "content", "title", "quality_score"]
    }
  }
];

// Procesar herramientas (mock)
async function procesarHerramienta(nombre, parametros) {
  console.log(`[Herramienta] ${nombre}`, parametros);
  
  switch(nombre) {
    case "buscar_contenido":
      // Buscar en web o en articles de Supabase
      return { articulos: [...] };
    
    case "generar_newsletter":
      // Generar con Claude
      return { newsletter_content: "..." };
    
    case "generar_post_rrss":
      // Generar post
      return { post: "..." };
    
    case "validar_calidad":
      // Evaluar
      return { score: 82, detalles: {...} };
    
    case "insertar_draft_supabase":
      // Insertar en BD
      const { data } = await supabase
        .from('ai_drafts')
        .insert([{
          type: parametros.type,
          content: parametros.content,
          title: parametros.title,
          metadata: parametros.metadata,
          quality_score: parametros.quality_score,
          status: 'pending_review'
        }])
        .select()
        .single();
      return { draft_id: data.id, status: 'inserted' };
  }
}

// Loop agentico
async function runAgent(topicos = ["AI", "Leadership", "Automation"]) {
  const systemPrompt = `Eres el agente de INSIDE Life.
  Tu job: generar drafts de contenido (newsletter, posts, videos).
  
  Flujo:
  1. Busca contenido relevante
  2. Genera drafts (newsletter + posts RRSS + video descriptions)
  3. Valida calidad (score >= 75 para publicar)
  4. Inserta en Supabase (tabla ai_drafts)
  5. Avisa a la app iOS
  
  Tópicos: ${topicos.join(", ")}
  
  IMPORTANTE:
  - The Athletic, NYT = fuentes de inspiración, no reproducir
  - Tu análisis debe ser original
  - Cita correctamente
  - Tono: coaching + liderazgo
  `;
  
  const messages = [
    { role: "user", content: `Genera 3 drafts para esta semana: newsletter, post LinkedIn, descripción video.` }
  ];
  
  let continuar = true;
  let iteraciones = 0;
  
  while(continuar && iteraciones < 15) {
    iteraciones++;
    
    const response = await client.messages.create({
      model: "claude-opus-4-20250805",
      max_tokens: 4096,
      system: systemPrompt,
      tools: tools,
      messages: messages
    });
    
    console.log(`[${iteraciones}] Stop reason: ${response.stop_reason}`);
    
    for (const block of response.content) {
      if (block.type === "text") {
        console.log(`💬 ${block.text}`);
      } else if (block.type === "tool_use") {
        // Ejecutar herramienta
        const result = await procesarHerramienta(block.name, block.input);
        console.log(`✅ ${block.name}:`, result);
        
        // Agregar a conversación
        messages.push({ role: "assistant", content: response.content });
        messages.push({
          role: "user",
          content: [{
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify(result)
          }]
        });
        
        break; // Una herramienta a la vez
      }
    }
    
    if (response.stop_reason === "end_turn") {
      continuar = false;
      console.log("\n✅ Agente completado");
    }
  }
}

// Endpoints
app.post("/webhook/run-agent", async (req, res) => {
  const { secret, topicos } = req.body;
  
  if (secret !== process.env.AGENT_SECRET) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  
  try {
    await runAgent(topicos || ["AI", "Leadership"]);
    res.json({ status: "success", message: "Agent completed" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3001, () => {
  console.log("Agente escuchando en puerto 3001");
});
```

---

### 1.5 GitHub Actions: Scheduler

**Archivo:** `.github/workflows/agente-semanal.yml` (nuevo)

```yaml
name: Agente INSIDE Life Semanal

on:
  schedule:
    - cron: "0 9 * * MON" # Lunes 9 AM UTC (10 AM Madrid)

jobs:
  run-agent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: "18"
      
      - run: npm install
      
      - run: npm run agente:run
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_KEY }}
          AGENT_SECRET: ${{ secrets.AGENT_SECRET }}
```

---

### 1.6 iOS: Nueva pantalla "AI Drafts"

**Archivo:** `NewsFlow/ios/Views/AIDraftsView.swift` (nuevo)

```swift
import SwiftUI

struct AIDraftsView: View {
    @StateObject private var viewModel = AIDraftsViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("AI DRAFTS")
                    .font(.headline)
                    .padding()
                
                List {
                    ForEach(viewModel.drafts) { draft in
                        NavigationLink(destination: AIDraftDetailView(draft: draft)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(draft.title ?? "Sin título")
                                    .font(.headline)
                                
                                Text(draft.content?.prefix(100) ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    Text("Score: \(draft.quality_score ?? 0)/100")
                                        .font(.caption2)
                                    
                                    Spacer()
                                    
                                    Text(draft.type)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                Button("🔄 Ejecutar Agente Ahora") {
                    viewModel.runAgentManually()
                }
                .padding()
            }
            .navigationTitle("AI Drafts")
        }
        .onAppear {
            viewModel.loadDrafts()
        }
    }
}

// ViewModel
@MainActor
class AIDraftsViewModel: ObservableObject {
    @Published var drafts: [AIDraft] = []
    @Published var isLoading = false
    
    func loadDrafts() {
        Task {
            isLoading = true
            let response = await SupabaseService.shared.fetch(
                table: "ai_drafts",
                query: "status.eq.pending_review"
            )
            drafts = response as? [AIDraft] ?? []
            isLoading = false
        }
    }
    
    func runAgentManually() {
        Task {
            isLoading = true
            // Llamar a webhook del agente
            let result = await callAgentWebhook()
            loadDrafts()
            isLoading = false
        }
    }
    
    private func callAgentWebhook() async -> Bool {
        // Llamar a tu backend
        return true
    }
}

struct AIDraft: Identifiable, Codable {
    var id: UUID
    var type: String // "newsletter" | "linkedin_post" | ...
    var title: String?
    var content: String
    var quality_score: Int?
    var quality_details: [String: Int]?
    var status: String
    var metadata: [String: AnyCodable]?
}
```

---

### 1.7 Configuración: Secrets y env vars

**Archivo:** `.env.example` (nuevo)

```bash
# Claude API
ANTHROPIC_API_KEY=sk-ant-...

# Supabase
SUPABASE_URL=https://iajrttxaxutvwubjcaxc.supabase.co
SUPABASE_KEY=eyJ...

# Agente
AGENT_SECRET=tu_secret_aqui

# GitHub (para publicar newsletter)
GITHUB_TOKEN=ghp_...

# Brevo (para email)
BREVO_API_KEY=xkeysib_...
```

---

## FASE 2: Expansión (1-2 semanas)

### 2.1 Integración con tab RRSS

En lugar de solo "Publicaciones pendientes manuales", mostrar también:
```
📌 2 publicaciones del Agente listas para revisar

[Agente] LinkedIn: "39 puntos, Cade..."
[Agente] Instagram: "¿Qué son agentes..."
```

### 2.2 Integración con Newsletter

Opción: "Usar propuesta del agente" en `NewsletterView`
```
[Artículos seleccionados manualmente]
+ [Importar sugerencias del agente]
```

### 2.3 Analytics

`AIDraftsAnalyticsView`: Ver cuántos drafts → publicados, engagement, etc.

---

## INTEGRACIÓN CON FLUJO ACTUAL

### Newsletter (sin cambios)
```
Tu flujo actual:
  Home → Newsletter
    ├─ Selecciona artículos (Noticias)
    ├─ Edita cabecera, orden, bloques
    ├─ Preview
    └─ Publica (GitHub → Vercel → Brevo)

Con agente (Fase 1):
  Home → AI Drafts
    └─ Ve propuesta de newsletter
       └─ [Add to Newsletter #043]
          └─ Añade a tu newsletter actual
             (Ahora tienes 1 draft + lo que seleccionaste)

O publicar directamente sin pasar por Newsletter tab.
```

### RRSS (sin cambios)
```
Tu flujo actual:
  Home → RRSS
    ├─ Publicaciones pendientes
    └─ Crear nueva

Con agente (Fase 1):
  Home → AI Drafts
    └─ Ve posts LinkedIn/Instagram/X
       └─ [Publish to LinkedIn]
          (Va directamente a plataforma)

O [Add to RRSS tab] para revisar antes (Fase 2).
```

---

## DEPLOYMENT

### Backend (Agente)

**Opción A: Vercel (recomendado)**
```
1. Deploy agente_inside_life.js a Vercel
2. GitHub Actions llama a Vercel function
3. Agente se ejecuta en background
```

**Opción B: Heroku o tu servidor**
```
npm start agente.js
```

### Base de datos
```
1. Crear tabla ai_drafts (SQL arriba)
2. Crear índices
3. Aplicar RLS policies
```

### iOS app
```
1. Añadir nueva view (AIDraftsView.swift)
2. Actualizar HomeView.swift para incluir "AI Drafts" en grid
3. Añadir endpoints en SupabaseService
4. Build + test en simulador
5. Deploy a App Store
```

---

## TESTING

```javascript
// Test agente local
npm run agente:dev

// Test API
curl -X GET http://localhost:3000/api/ai-drafts \
  -H "Authorization: Bearer <user_token>"

// Test GitHub Actions
- Trigger manual workflow desde GitHub UI
- Verificar que inserta en Supabase
- Abrir app iOS, ver new drafts
```

---

## ROADMAP

```
SEMANA 1-2:
✅ Tabla Supabase + RLS
✅ API endpoints CRUD
✅ Agente básico (CLI)
✅ Nueva pantalla iOS
✅ GitHub Actions scheduler

SEMANA 3:
✅ Publicación a LinkedIn/Instagram/X
✅ Integración con tab RRSS
✅ Webhook manual desde app

SEMANA 4:
✅ Integración con Newsletter tab
✅ Analytics
✅ Polish + testing
```

---

## DUDAS MÁS COMUNES

**P: ¿El agente rompe algo existente?**
A: No. Nueva tabla, nuevos endpoints, nueva pantalla. Tu flujo actual sin cambios.

**P: ¿Cuánto cuesta correr el agente?**
A: ~$0.40 USD por ejecución (Claude API). $21/mes si se ejecuta 52 veces (semanal).

**P: ¿Qué pasa si el agente falla?**
A: Usa GitHub Actions retry. Si sigue fallando, notificación en Supabase + badge en app.

**P: ¿El usuario puede ejecutar el agente manualmente?**
A: Sí. Botón en AIDraftsView + webhook desde app a backend.

**P: ¿Cómo sabe el agente qué escribir?**
A: System prompt lo indica. Busca The Athletic, ESPN, etc. Genera análisis original.

---

**Este documento es específico para tu stack.**
**Comparte con tu dev y que empiece por Fase 1.**
