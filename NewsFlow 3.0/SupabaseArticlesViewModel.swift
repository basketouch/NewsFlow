import Foundation
import SwiftUI

@MainActor
class SupabaseArticlesViewModel: ObservableObject {
    static let shared = SupabaseArticlesViewModel()

    @Published var savedArticles: [SupabaseArticle] = []
    @Published var pendingArticles: [SupabaseArticle] = []
    @Published var isLoading = false
    @Published var isLoadingPending = false
    @Published var error: String? = nil
    @Published var saveSuccess = false

    /// Artículos sin revisar (approved = null) — para el badge del Home y el ApprovalView
    var pendingCount: Int { savedArticles.filter { $0.approved == nil }.count }

    private let db = SupabaseService.shared
    private let table = "articles"

    private init() {
        Task { await loadSavedArticles() }
    }

    // MARK: - Load

    func loadSavedArticles() async {
        isLoading = true
        error = nil
        do {
            let fetched: [SupabaseArticle] = try await db.fetch(
                table,
                order: "created_at.desc"
            )
            savedArticles = fetched
        } catch {
            self.error = "Error cargando artículos: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Pendientes de aprobación

    func loadPendingArticles() async {
        isLoadingPending = true
        error = nil
        do {
            let fetched: [SupabaseArticle] = try await db.fetch(
                table,
                filters: ["approved": "is.null"],
                order: "relevance_score.desc.nullslast,created_at.desc"
            )
            pendingArticles = fetched
        } catch {
            self.error = "Error cargando pendientes: \(error.localizedDescription)"
        }
        isLoadingPending = false
    }

    func approveArticle(_ article: SupabaseArticle) async {
        do {
            try await db.patch(table, id: article.id, fields: ["approved": true])
            updateInAllLists(id: article.id) { $0.approved = true }
            pendingArticles.removeAll { $0.id == article.id }
        } catch {
            self.error = "No se pudo aprobar"
        }
    }

    func discardArticle(_ article: SupabaseArticle) async {
        do {
            try await db.patch(table, id: article.id, fields: ["approved": false])
            updateInAllLists(id: article.id) { $0.approved = false }
            pendingArticles.removeAll { $0.id == article.id }
        } catch {
            self.error = "No se pudo descartar"
        }
    }

    func approveAll() async {
        let articles = pendingArticles
        for article in articles {
            await approveArticle(article)
        }
    }

    func discardAll() async {
        let articles = pendingArticles
        for article in articles {
            await discardArticle(article)
        }
    }

    // MARK: - Guardar desde RSS

    /// Guarda un artículo RSS en Supabase. Devuelve true si se guardó, false si ya existía.
    func save(rssArticle: NewsArticle) async -> Bool {
        isLoading = true
        error = nil

        if isInSystem(url: rssArticle.url.absoluteString) {
            isLoading = false
            error = "Este artículo ya está guardado"
            return false
        }

        let article = SupabaseArticle.from(rssArticle: rssArticle)
        do {
            let saved: SupabaseArticle = try await db.insert(table, record: article)
            savedArticles.insert(saved, at: 0)
            isLoading = false
            return true
        } catch {
            self.error = "No se pudo guardar: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Guardar desde URL manual

    /// Obtiene metadatos de una URL y guarda en Supabase.
    func save(urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            error = "URL no válida"
            return false
        }

        if isInSystem(url: urlString) {
            error = "Esta URL ya está guardada"
            return false
        }

        isLoading = true
        error = nil

        do {
            let metadata = try await fetchURLMetadata(url: url)
            let article = SupabaseArticle.from(
                urlString: urlString,
                title: metadata.title,
                description: metadata.description,
                imageUrl: metadata.imageUrl
            )
            let saved: SupabaseArticle = try await db.insert(table, record: article)
            savedArticles.insert(saved, at: 0)
            isLoading = false
            return true
        } catch {
            self.error = "No se pudo guardar la URL: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Favorito

    func toggleFavorite(_ article: SupabaseArticle) async {
        let newValue = !article.isFavorite
        do {
            try await db.patch(table, id: article.id, fields: ["is_favorite": newValue])
            updateInAllLists(id: article.id) { $0.isFavorite = newValue }
        } catch {
            self.error = "No se pudo actualizar favorito"
        }
    }

    // MARK: - Marcar leído

    func markAsRead(_ article: SupabaseArticle) async {
        guard !article.isRead else { return }
        do {
            try await db.patch(table, id: article.id, fields: ["is_read": true])
            updateInAllLists(id: article.id) { $0.isRead = true }
        } catch {}
    }

    // MARK: - Seleccionar para newsletter

    func toggleNewsletter(_ article: SupabaseArticle) async {
        let newValue = !article.selectedForNewsletter
        do {
            try await db.patch(table, id: article.id, fields: ["selected_for_newsletter": newValue])
            updateInAllLists(id: article.id) { $0.selectedForNewsletter = newValue }
        } catch {
            self.error = "No se pudo actualizar selección de newsletter"
        }
    }

    // MARK: - Eliminar

    func delete(_ article: SupabaseArticle) async {
        do {
            try await db.delete(table, id: article.id)
            savedArticles.removeAll  { $0.id == article.id }
            pendingArticles.removeAll { $0.id == article.id }
        } catch {
            self.error = "No se pudo eliminar: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper interno

    private func updateInAllLists(id: String, update: (inout SupabaseArticle) -> Void) {
        if let idx = savedArticles.firstIndex(where: { $0.id == id }) {
            update(&savedArticles[idx])
        }
        if let idx = pendingArticles.firstIndex(where: { $0.id == id }) {
            update(&pendingArticles[idx])
        }
    }

    func deleteAll(_ articles: [SupabaseArticle]) async {
        for article in articles {
            await delete(article)
        }
    }

    // MARK: - Verificar si ya está en el sistema

    func isInSystem(url: String) -> Bool {
        savedArticles.contains { $0.url == url }
    }

    func isSaved(url: String) -> Bool { isInSystem(url: url) }

    // MARK: - Filtros

    var favoriteSavedArticles: [SupabaseArticle] {
        savedArticles.filter { $0.isFavorite }
    }

    var newsletterArticles: [SupabaseArticle] {
        savedArticles.filter { $0.selectedForNewsletter }
    }

    // MARK: - Fetch URL metadata

    private func fetchURLMetadata(url: URL) async throws -> (title: String, description: String, imageUrl: String?) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return (url.host ?? url.absoluteString, "", nil)
        }

        let title = extractMeta(html: html, tags: [
            "og:title", "twitter:title"
        ]) ?? extractTagContent(html: html, tag: "title") ?? url.host ?? url.absoluteString

        let description = extractMeta(html: html, tags: [
            "og:description", "twitter:description", "description"
        ]) ?? ""

        let imageUrl = extractMeta(html: html, tags: [
            "og:image", "twitter:image"
        ])

        return (title, description, imageUrl)
    }

    private func extractMeta(html: String, tags: [String]) -> String? {
        for tag in tags {
            // og: tags: <meta property="og:title" content="...">
            let patterns = [
                "property=\"\(tag)\"[^>]*content=\"([^\"]+)\"",
                "content=\"([^\"]+)\"[^>]*property=\"\(tag)\"",
                "name=\"\(tag)\"[^>]*content=\"([^\"]+)\"",
                "content=\"([^\"]+)\"[^>]*name=\"\(tag)\""
            ]
            for pattern in patterns {
                if let range = html.range(of: pattern, options: .regularExpression, range: nil, locale: nil) {
                    let match = String(html[range])
                    if let contentRange = match.range(of: "content=\"([^\"]+)\"", options: .regularExpression) {
                        var value = String(match[contentRange])
                            .replacingOccurrences(of: "content=\"", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty { return value }
                    }
                }
            }
        }
        return nil
    }

    private func extractTagContent(html: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]+)<"
        guard let range = html.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(html[range])
        let inner = match
            .replacingOccurrences(of: "<\(tag)[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return inner.isEmpty ? nil : inner
    }

    // MARK: - Guardar draft n8n si no existe

    /// Guarda silenciosamente un artículo del draft de n8n (sourceType: "gmail")
    func saveDraftIfNeeded(article: DraftArticle) async {
        guard let urlStr = article.url, !urlStr.isEmpty, !isSaved(url: urlStr) else { return }
        let supaArticle = SupabaseArticle(
            id: UUID().uuidString,
            title: article.titulo,
            description: article.resumen,
            content: "",
            url: urlStr,
            sourceName: "n8n",
            sourceType: "gmail",
            publishedAt: Date(),
            imageUrl: nil,
            category: article.categoria,
            summary: nil,
            isRead: false,
            isFavorite: false,
            selectedForNewsletter: true,
            createdAt: Date(),
            relevanceScore: nil,
            relevanceReason: nil,
            approved: nil
        )
        do {
            let saved: SupabaseArticle = try await db.insert(table, record: supaArticle)
            savedArticles.insert(saved, at: 0)
        } catch {}
    }

    // MARK: - Limpieza de archivo

    /// Número de artículos anteriores al mes en curso
    var cleanupArticleCount: Int {
        let startOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: Date())
        )!
        return savedArticles.filter { $0.createdAt < startOfMonth }.count
    }

    /// Fecha a partir de la cual se permite limpiar:
    /// último domingo del mes; si el último día cae en lunes/martes, espera al siguiente domingo.
    var cleanupAvailableDate: Date {
        let cal = Calendar.current
        let nextMonth = cal.date(byAdding: .month, value: 1, to: Date())!
        let firstOfNext = cal.date(from: cal.dateComponents([.year, .month], from: nextMonth))!
        let lastDay = cal.date(byAdding: .day, value: -1, to: firstOfNext)!
        let weekday = cal.component(.weekday, from: lastDay) // 1=Dom 2=Lun … 7=Sáb
        switch weekday {
        case 2: return cal.date(byAdding: .day, value:  6, to: lastDay)! // Lun → sig. Dom
        case 3: return cal.date(byAdding: .day, value:  5, to: lastDay)! // Mar → sig. Dom
        default:
            let daysBack = (weekday == 1) ? 0 : (weekday - 1)           // atrás hasta Dom
            return cal.date(byAdding: .day, value: -daysBack, to: lastDay)!
        }
    }

    var canCleanup: Bool { Date() >= cleanupAvailableDate }

    /// Elimina todos los artículos guardados antes del inicio del mes actual
    func cleanupOldArticles() async {
        let startOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: Date())
        )!
        let toDelete = savedArticles.filter { $0.createdAt < startOfMonth }
        for article in toDelete {
            do {
                try await db.delete(table, id: article.id)
                savedArticles.removeAll { $0.id == article.id }
            } catch {}
        }
    }
}
