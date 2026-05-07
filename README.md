# NewsFlow 3.0

Centro de control para la marca personal de Jorge Lorenzo. Gestiona el newsletter INSIDE Life, publicación de vídeos, posts de redes sociales y curación de noticias desde una sola app iOS.

---

## Stack técnico

| Capa | Tecnología |
|------|-----------|
| App iOS | SwiftUI · MVVM · Swift 5.9+ |
| Backend | Supabase (PostgreSQL + Storage + REST API) |
| Automatización | n8n (self-hosted en basketouch.com) |
| IA extracción | Google Gemini Flash 2.5 |
| IA copywriting | OpenAI GPT-4o-mini |
| Web newsletter | GitHub + Vercel (insidelife.club) |
| Email | Brevo (campañas a suscriptores) |
| Vídeos | Google Drive → Supabase Storage → YouTube vía n8n |

---

## Estructura de la app

### Navegación principal (`HomeView.swift`)
5 secciones accesibles desde la pantalla de inicio:
- **Noticias** — curación de artículos RSS + gmail + URLs manuales
- **Newsletter** — editor del newsletter INSIDE Life
- **RRSS** — gestión de posts para LinkedIn y X
- **Videos** — cola de publicación de vídeos
- **Archivo** — artículos guardados en Supabase

---

## Módulos

### 📰 Noticias (`NewsListView.swift`)
Tres fuentes unificadas en una sola vista:

| Fuente | Source type | Origen |
|--------|-------------|--------|
| RSS | `rss` | Feeds configurados por el usuario |
| Email / n8n | `gmail` | Extraídas por Gemini desde Gmail cada lunes |
| URLs manuales | `url` | Añadidas manualmente por el usuario |

**Archivos clave:**
- `NewsListView.swift` — vista principal con secciones colapsables
- `ArticlesViewModel.swift` — gestión de feeds RSS
- `RSSFeedService.swift` — parsing RSS
- `SupabaseArticlesViewModel.swift` — artículos guardados en Supabase
- `SavedArticleDetailView.swift` — detalle de artículos gmail/url
- `NewsArticle.swift` — modelo RSS
- `SupabaseArticle.swift` — modelo Supabase

**Flujo gmail (lunes automático):**
```
n8n: Gmail → Gemini Flash → artículos → Supabase (source_type: gmail)
App: detecta has_new_draft = true → badge en Noticias
Usuario: revisa y marca artículos para el newsletter
```

---

### 📧 Newsletter (`NewsletterView.swift`)
Editor completo del newsletter semanal INSIDE Life.

**Flujo de publicación:**
```
Selección de artículos (Noticias) → Editor newsletter → 
Preview HTML → Publicar en GitHub → Vercel deploy → Brevo email
```

**Archivos clave:**
- `NewsletterView.swift` — editor con 4 secciones (Artículos, Cabecera, Orden, Bloques)
- `NewsletterViewModel.swift` — lógica principal, publicación a GitHub
- `NewsletterHTMLGenerator.swift` — generación HTML local (sin tokens)
- `NewsletterService.swift` — integración GitHub API
- `NewsletterModels.swift` — modelos: DraftArticle, NewsletterItem, NewsletterBlock
- `NewsletterConfig.swift` — configuración GitHub, n8n webhook, URLs
- `NewsletterPreviewView.swift` — previsualización antes de publicar

**Número de edición:** gestionado en Supabase (`newsletter_status.next_edition`). Se pre-rellena en la cabecera y se incrementa al publicar.

---

### 📱 RRSS (`SocialPostsView.swift`)
Gestión de posts para LinkedIn y X (Twitter).

**Archivos clave:**
- `SocialPostsView.swift` — lista de posts con tabs Hoy / Todos
- `SocialPostsViewModel.swift` — singleton, datos desde Supabase
- `SocialPost.swift` — modelo de post
- `NuevaPublicacionView.swift` — creación de nuevo post
- `EditPostView.swift` — edición
- `SocialPostDetailView.swift` — detalle y aprobación
- `SocialPostsCalendarView.swift` — vista calendario
- `OpenAIService.swift` — generación y mejora de textos con GPT-4o-mini

---

### 🎬 Videos (`VideosView.swift`)
Cola de publicación de vídeos a YouTube (y otras plataformas futuras).

**Flujo:**
```
Subir desde Drive o Galería → Supabase publish_queue → 
n8n procesa → YouTube API → estado: published
```

**Archivos clave:**
- `VideosView.swift` — lista de vídeos pendientes/publicados + formulario nuevo
- `VideoDetailView.swift` — detalle, edición metadatos, publicar/programar, borrar Storage
- `VideosViewModel.swift` — singleton, CRUD contra Supabase
- `VideoItem.swift` — modelo: VideoItem, VideoType, VideoPlatform, VideoStatus
- `GoogleDriveService.swift` — autenticación y exploración Drive
- `DrivePickerView.swift` — selector de archivos Drive

**Tipos de vídeo (VideoType):** Motivacional, Educativo/Sistema, Promocional, Inside Life, Baloncesto/Deporte, Entrevista

---

### 🗄 Servicios compartidos

| Archivo | Descripción |
|---------|-------------|
| `SupabaseService.swift` | Cliente REST genérico (fetch, insert, update, patch, delete, Storage) |
| `SupabaseConfig.swift` | URL del proyecto y anon key |
| `OpenAIService.swift` | GPT-4o-mini: posts RRSS, descripciones vídeo, newsletter copywriting |
| `SafariView.swift` | WKWebView wrapper para abrir URLs in-app |

---

## Base de datos Supabase

### Tablas principales

```
articles
├── id, title, description, content, url (UNIQUE)
├── source_type: "rss" | "gmail" | "url"
├── source_name, category, summary
├── is_read, is_favorite, selected_for_newsletter
└── published_at, created_at

social_posts
├── id, texto, hashtags
├── red_social: "LinkedIn" | "X"
├── estado, aprobado, publicado
└── tematica, objetivo, fecha

publish_queue (vídeos)
├── id, title, description, hashtags, category
├── source: "drive" | "gallery"
├── drive_file_id, storage_url
├── platforms[], scheduled_at
├── status: "pending" | "ready" | "publishing" | "published" | "error"
└── published_urls (JSONB), error_msg

newsletter_status
├── id (siempre 1)
├── has_new_draft (bool) — avisa a la app que hay noticias nuevas
├── next_edition (int) — contador de ediciones, empieza en 43
└── updated_at
```

---

## Automatización n8n

### Workflow: INSIDE Life Newsletter Semanal
**ID:** QCD3WWMrl83D9N7S  
**URL:** https://n8n.basketouch.com/workflow/QCD3WWMrl83D9N7S

**Flujo del lunes (8:00 Madrid):**
```
Lunes 8h
 └── Get many messages (Gmail Label_5, 25 emails)
      └── Get a message (contenido completo)
           └── Combinar Emails (extrae texto + URLs del HTML)
                └── Gemini Flash (extrae 20-30 noticias como JSON)
                     └── Extraer Resúmenes (parsea JSON)
                          ├── Limpiar Gmail (DELETE artículos no seleccionados)
                          └── Split Out (una noticia por item)
                               └── HTTP Request (POST a Supabase articles)
                                    └── Actualizar Estado (PATCH newsletter_status.has_new_draft = true)
```

**Flujo de publicación (webhook manual):**
```
Webhook Publicar (/inside-life-publish)
 └── Verificar Secret
      └── Leer Draft (GitHub newsletter-draft.html)
           └── Decodificar Draft
                └── Obtener SHA Live → Combinar → Publicar en GitHub
                     └── Esperar Vercel 45s
                          └── Crear Campaña Brevo → Enviar → Confirmar Telegram
```

### Workflow: Video Publisher
Gestiona la cola de vídeos de Supabase → YouTube.

---

## Configuración

### NewsletterConfig.swift
```swift
gh_api_base     = "https://insidelife.club/api/github"
admin_secret    = "Bearer ..."
draft_file      = "newsletter-draft.json"
publish_file    = "newsletter.html"
site_url        = "https://insidelife.club"
n8n_webhook     = "https://n8n.basketouch.com/webhook/newsletter-draft"
```

### SupabaseConfig.swift
```swift
projectURL = "https://iajrttxaxutvwubjcaxc.supabase.co"
anonKey    = "eyJ..."
```

---

## Decisiones de arquitectura

- **Un solo backend:** Supabase para todo (artículos, posts, vídeos, estado newsletter)
- **IA dual:** Gemini Flash para extracción/resumen (barato, rápido) · GPT-4o-mini para copywriting (mejor calidad)
- **HTML local:** El newsletter se genera en la app con `NewsletterHTMLGenerator` sin gastar tokens
- **Sin Telegram:** Las notificaciones se gestionan via `newsletter_status` en Supabase
- **Vídeos:** Drive y Galería → Supabase Storage → n8n → YouTube

---

## Pendiente / En desarrollo

- [ ] Verificar extracción de URLs por Gemini con nuevo prompt
- [ ] Notificación in-app cuando `has_new_draft = true` (badge en Noticias)
- [ ] Publicación de newsletter desde app (reemplaza panel web admin)
- [ ] Instagram: token Meta pendiente de configurar
- [ ] TikTok: pausado (revisión de app pendiente en Developer Portal)
- [ ] Brevo desde app (actualmente solo desde n8n webhook)
