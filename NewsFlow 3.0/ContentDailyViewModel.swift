import Foundation
import SwiftUI

@MainActor
class ContentDailyViewModel: ObservableObject {
    static let shared = ContentDailyViewModel()

    @Published var posts: [ContentDailyPost] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var error: String?
    @Published var lastGeneratedId: String?

    private let supabaseURL = SupabaseConfig.projectURL
    private let supabaseKey = SupabaseConfig.anonKey
    private let openAIKey  = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    private let openAIURL  = "https://api.openai.com/v1/chat/completions"

    // MARK: - Load

    func loadPosts() async {
        isLoading = true
        error = nil

        guard let url = URL(string: "\(supabaseURL)/rest/v1/content_daily?order=created_at.desc&limit=50") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            posts = try JSONDecoder().decode([ContentDailyPost].self, from: data)
        } catch {
            self.error = "Error cargando posts: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Generate

    func generateContent(title: String, description: String, url: String, extraText: String) async -> Bool {
        isGenerating = true
        error = nil

        print("🤖 [Agente] Generando con OpenAI para: \(title)")

        let systemPrompt = """
        Eres el copywriter de Jorge Lorenzo, emprendedor de marca personal especializado en liderazgo, inteligencia artificial, baloncesto, desarrollo personal y negocio digital.
        Genera posts para redes sociales basados en el contenido recibido.
        REGLAS: Conecta siempre el tema con liderazgo, alto rendimiento o mentalidad ganadora. Escribe desde la experiencia vivida, no desde la teoria. Voz directa, clara, autentica, sin frases vacias ni adornos.
        NUNCA uses comillas dobles dentro de los textos.
        Devuelve SOLO JSON valido en una sola linea.
        """

        let userPrompt = """
        CONTENIDO:
        Titulo: \(title)
        Descripcion: \(description)
        URL: \(url)
        Texto extra: \(extraText)

        Devuelve exactamente este JSON:
        {"topic":"tema en 5 palabras","linkedin_post":"post completo con leccion liderazgo bullets y hashtags","linkedin_score":8,"instagram_post":"post 100-150 chars hook emojis hashtags","instagram_image_prompt":"image description in english","instagram_score":7,"twitter_post":"tweet max 280 chars hook fuerte","twitter_score":7,"tiktok_script":"guion 60s: hook 0-3s desarrollo CTA","tiktok_score":6,"hashtags":["tag1","tag2","tag3"]}
        """

        let bodyDict: [String: Any] = [
            "model": "gpt-4o-mini",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "max_tokens": 2000
        ]

        guard let openAIEndpoint = URL(string: openAIURL) else {
            isGenerating = false
            return false
        }

        var request = URLRequest(url: openAIEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            print("🤖 [Agente] OpenAI respondió: \(statusCode)")

            guard (200..<300).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                error = "OpenAI error \(statusCode): \(body.prefix(200))"
                isGenerating = false
                return false
            }

            // Parsear respuesta
            guard let json     = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices  = json["choices"] as? [[String: Any]],
                  let message  = choices.first?["message"] as? [String: Any],
                  let content  = message["content"] as? String,
                  let parsed   = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any]
            else {
                error = "No se pudo parsear la respuesta de OpenAI"
                isGenerating = false
                return false
            }

            print("🤖 [Agente] Posts generados: \(parsed["topic"] ?? "")")

            // Guardar en Supabase
            let saved = await saveToSupabase(parsed: parsed, title: title, sourceUrl: url)
            isGenerating = false
            if saved {
                await loadPosts()
                return true
            } else {
                error = "Posts generados pero error al guardar en Supabase"
                return false
            }

        } catch {
            self.error = "Error: \(error.localizedDescription)"
            print("❌ [Agente] \(error.localizedDescription)")
            isGenerating = false
            return false
        }
    }

    private func saveToSupabase(parsed: [String: Any], title: String, sourceUrl: String) async -> Bool {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/content_daily") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey,                forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)",    forHTTPHeaderField: "Authorization")
        request.setValue("application/json",         forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation",    forHTTPHeaderField: "Prefer")

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        var record: [String: Any] = [
            "date":            String(today),
            "topic":           parsed["topic"] ?? title,
            "source_url":      sourceUrl,
            "status":          "pending_review",
            "hashtags":        parsed["hashtags"] ?? [],
            "published_to":    []
        ]

        let fields: [(String, String)] = [
            ("linkedin_post",          "linkedin_post"),
            ("linkedin_score",         "linkedin_score"),
            ("instagram_post",         "instagram_post"),
            ("instagram_image_prompt", "instagram_image_prompt"),
            ("instagram_score",        "instagram_score"),
            ("twitter_post",           "twitter_post"),
            ("twitter_score",          "twitter_score"),
            ("tiktok_script",          "tiktok_script"),
            ("tiktok_score",           "tiktok_score")
        ]
        for (key, parsedKey) in fields {
            if let val = parsed[parsedKey] { record[key] = val }
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: record)
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("🤖 [Supabase] Guardado: \(statusCode)")
            return (200..<300).contains(statusCode)
        } catch {
            print("❌ [Supabase] \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Update

    func updatePost(_ post: ContentDailyPost) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/content_daily?id=eq.\(post.id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var update: [String: Any] = ["status": post.status]
        if let lp = post.linkedinPost   { update["linkedin_post"]   = lp }
        if let ip = post.instagramPost  { update["instagram_post"]  = ip }
        if let tp = post.twitterPost    { update["twitter_post"]    = tp }
        if let tk = post.tiktokScript   { update["tiktok_script"]   = tk }
        update["published_to"] = post.publishedTo

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: update)
            _ = try await URLSession.shared.data(for: request)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx] = post
            }
        } catch { }
    }

    // MARK: - Mark published

    func markPublished(_ post: ContentDailyPost, platform: String) async {
        var updated = post
        if !updated.publishedTo.contains(platform) {
            updated.publishedTo.append(platform)
        }
        let allPlatforms = ["linkedin", "instagram", "twitter", "tiktok"]
        let availablePlatforms = allPlatforms.filter { p in
            switch p {
            case "linkedin":  return post.linkedinPost != nil
            case "instagram": return post.instagramPost != nil
            case "twitter":   return post.twitterPost != nil
            case "tiktok":    return post.tiktokScript != nil
            default:          return false
            }
        }
        let allDone = availablePlatforms.allSatisfy { updated.publishedTo.contains($0) }
        updated.status = allDone ? "published_all" : "published_partial"
        await updatePost(updated)
    }

    // MARK: - Delete

    func deletePost(_ post: ContentDailyPost) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/content_daily?id=eq.\(post.id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            _ = try await URLSession.shared.data(for: request)
            posts.removeAll { $0.id == post.id }
        } catch { }
    }

    // MARK: - Pending count

    var pendingCount: Int {
        posts.filter { $0.isPendingReview }.count
    }
}
