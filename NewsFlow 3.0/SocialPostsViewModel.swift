import Foundation
import Combine

@MainActor
class SocialPostsViewModel: ObservableObject {
    static let shared = SocialPostsViewModel()

    @Published var posts: [SocialPost] = []
    @Published var postsForReview: [SocialPost] = []
    @Published var postsForPublishing: [SocialPost] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var selectedPost: SocialPost? = nil
    @Published var currentEditPost: SocialPost? = nil
    @Published var isEditingPost = false
    @Published var isCreatingPost = false
    @Published var isCreatingPostLoading = false
    @Published var creationStatus: String = ""    // mensaje de progreso para la UI
    @Published var creationError: String? = nil

    private let db = SupabaseService.shared
    private let ai = OpenAIService.shared

    // URL del webhook de n8n para "Publicar ahora" (Production URL — workflow debe estar activo)
    private let publishWebhookURL = "https://n8n.basketouch.com/webhook/newsflow-publicar-ahora"
    private let table = "social_posts"

    private init() {
        Task { await loadData() }
    }

    // MARK: - Load

    func loadData(completion: ((Bool) -> Void)? = nil) async {
        isLoading = true
        error = nil
        do {
            let fetched: [SocialPost] = try await db.fetch(table, order: "fecha.asc")
            posts = fetched
            filterPosts()
            isLoading = false
            completion?(true)
        } catch {
            self.error = "No se pudieron cargar los posts: \(error.localizedDescription)"
            isLoading = false
            completion?(false)
        }
    }

    // MARK: - Filter

    func filterPosts() {
        postsForReview = posts.filter { !$0.aprobado && $0.isEnriched }
        postsForPublishing = posts.filter { $0.aprobado && !$0.publicado && $0.fecha <= Date() }
    }

    // MARK: - Create

    func crearPublicacion(texto: String, tematica: String, objetivo: String, redSocial: SocialNetwork, fecha: Date, urlEdicion: String? = nil, mediaUrl: String? = nil, mediaType: MediaType = .texto) async -> Bool {
        isCreatingPostLoading = true
        creationError = nil
        creationStatus = "Guardando..."

        let nuevo = SocialPost.nuevo(
            texto: texto,
            redSocial: redSocial,
            fecha: fecha,
            tematica: tematica,
            objetivo: objetivo,
            urlEdicion: urlEdicion,
            mediaUrl: mediaUrl,
            mediaType: mediaType
        )

        do {
            // 1. Guardar en Supabase
            var saved: SocialPost = try await db.insert(table, record: nuevo)
            posts.append(saved)

            // 2. Enriquecer con IA
            creationStatus = "Generando post con IA..."
            do {
                let enriched = try await ai.generateSocialPost(
                    texto: texto,
                    tematica: tematica,
                    objetivo: objetivo,
                    redSocial: redSocial.rawValue
                )
                // 3. Actualizar Supabase con texto enriquecido
                try await db.patch(table, id: saved.id, fields: [
                    "texto_enriquecido": enriched,
                    "estado": PostStatus.listoParaAprobar.rawValue,
                    "fecha_modificacion": ISO8601DateFormatter().string(from: Date())
                ])
                saved.textoEnriquecido = enriched
                saved.estado = PostStatus.listoParaAprobar.rawValue
            } catch {
                // Si la IA falla, el post queda en borrador — no bloquea
                print("⚠️ Enriquecimiento IA fallido: \(error.localizedDescription)")
            }

            // 4. Actualizar lista local
            if let idx = posts.firstIndex(where: { $0.id == saved.id }) {
                posts[idx] = saved
            }
            filterPosts()
            isCreatingPostLoading = false
            creationStatus = ""
            isCreatingPost = false
            return true
        } catch {
            creationError = "No se pudo crear la publicación: \(error.localizedDescription)"
            isCreatingPostLoading = false
            creationStatus = ""
            return false
        }
    }

    // MARK: - Edit

    func startEditing(post: SocialPost) {
        currentEditPost = post
        if selectedPost != nil {
            selectedPost = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isEditingPost = true
            }
        } else {
            isEditingPost = true
        }
    }

    func cancelEditing() {
        currentEditPost = nil
        isEditingPost = false
    }

    func saveEdit(newContent: String, redSocial: SocialNetwork? = nil, fecha: Date? = nil, mediaUrl: String? = nil, mediaType: MediaType? = nil) async {
        guard var post = currentEditPost else { return }
        isLoading = true

        post.textoEnriquecido = newContent
        post.fechaModificacion = Date()
        if let redSocial = redSocial { post.redSocial = redSocial.rawValue }
        if let fecha = fecha { post.fecha = fecha }
        post.mediaUrl = mediaUrl
        if let mediaType = mediaType { post.mediaType = mediaType.rawValue }

        do {
            let updated: SocialPost = try await db.update(table, id: post.id, record: post)
            applyUpdate(updated)
        } catch {
            // Actualización local si falla la red
            applyUpdate(post)
            self.error = "No se pudo guardar en Supabase. Cambios guardados localmente."
        }

        isLoading = false
        currentEditPost = nil
        isEditingPost = false
        selectedPost = nil
    }

    // MARK: - Approve / Reject

    func approvePost(post: SocialPost) async {
        isLoading = true
        isEditingPost = false
        currentEditPost = nil

        do {
            try await db.patch(table, id: post.id, fields: [
                "aprobado": true,
                "estado": PostStatus.listoParaPublicar.rawValue,
                "fecha_modificacion": ISO8601DateFormatter().string(from: Date())
            ])
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].aprobado = true
                posts[idx].estado = PostStatus.listoParaPublicar.rawValue
                posts[idx].fechaModificacion = Date()
            }
            filterPosts()
        } catch {
            // Actualización local
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].aprobado = true
                filterPosts()
            }
            self.error = "No se pudo actualizar en Supabase. Cambio guardado localmente."
        }
        isLoading = false
    }

    func rejectPost(post: SocialPost) async {
        isLoading = true
        isEditingPost = false
        currentEditPost = nil

        do {
            try await db.delete(table, id: post.id)
            if selectedPost?.id == post.id { selectedPost = nil }
            posts.removeAll { $0.id == post.id }
            filterPosts()
        } catch {
            self.error = "No se pudo eliminar el post: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Publicar ahora (llama al webhook de n8n y espera respuesta)

    func publishNow(post: SocialPost) async -> Bool {
        isLoading = true
        error = nil

        guard let url = URL(string: publishWebhookURL) else {
            error = "URL del webhook no válida"
            isLoading = false
            return false
        }

        // 1. Llamar al webhook de n8n y esperar respuesta (máx. 30s)
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try JSONSerialization.data(withJSONObject: ["post_id": post.id])

            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200..<300).contains(statusCode) else {
                error = "n8n devolvió error \(statusCode). El post NO se publicó en LinkedIn."
                isLoading = false
                return false
            }

            // 2. Solo si n8n respondió OK → marcar como publicado en Supabase
            try await db.patch(table, id: post.id, fields: [
                "publicado": true,
                "estado": PostStatus.publicado.rawValue,
                "fecha_modificacion": ISO8601DateFormatter().string(from: Date())
            ])

            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].publicado = true
                posts[idx].estado = PostStatus.publicado.rawValue
            }
            filterPosts()
            isLoading = false
            return true

        } catch let urlError as URLError where urlError.code == .timedOut {
            error = "Tiempo de espera agotado. Comprueba que n8n está activo."
            isLoading = false
            return false
        } catch {
            self.error = "No se pudo publicar: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Mark as published

    func markAsPublished(post: SocialPost) async {
        do {
            try await db.patch(table, id: post.id, fields: [
                "publicado": true,
                "estado": PostStatus.publicado.rawValue,
                "fecha_modificacion": ISO8601DateFormatter().string(from: Date())
            ])
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].publicado = true
                posts[idx].estado = PostStatus.publicado.rawValue
            }
            filterPosts()
        } catch {
            self.error = "No se pudo marcar como publicado: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func applyUpdate(_ post: SocialPost) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
        }
        filterPosts()
    }
}
