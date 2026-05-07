import Foundation
import SwiftUI
import UserNotifications

@MainActor
class NewsletterViewModel: ObservableObject {
    static let shared = NewsletterViewModel()

    // MARK: - Estado

    @Published var draft: NewsletterDraft? = nil
    @Published var selectedItems: [NewsletterItem] = []   // artículos seleccionados y ordenados
    @Published var hero = NewsletterHero.empty
    @Published var edicionEditada: String = ""
    @Published var fechaEditada: String = ""
    @Published var extraBlocks: [NewsletterBlock] = []
    @Published var isLoading = false
    @Published var isRegeneratingDraft = false
    @Published var publishState: PublishState = .idle
    @Published var n8nStatus: N8nStatus = .idle

    enum N8nStatus: Equatable {
        case idle
        case connecting
        case processing(secondsLeft: Int)
        case done(count: Int)
        case failed(String)

        var message: String {
            switch self {
            case .idle:                    return ""
            case .connecting:             return "Conectando con n8n..."
            case .processing(let s):      return s > 0 ? "Procesando noticias... ~\(s)s" : "Cargando noticias..."
            case .done(let n):            return n > 0 ? "✅ \(n) noticias nuevas cargadas" : "✅ Noticias actualizadas"
            case .failed(let msg):        return "❌ \(msg)"
            }
        }

        var isActive: Bool {
            switch self { case .idle: return false; default: return true }
        }

        var color: Color {
            switch self {
            case .done:   return .green
            case .failed: return .red
            default:      return .orange
            }
        }
    }
    @Published var generatedHTML: String = ""
    @Published var error: String? = nil
    @Published var aiLoadingItemId: String? = nil    // ID del artículo procesando IA
    @Published var aiLoadingBlockId: UUID?  = nil    // UUID del bloque procesando IA

    private let service = NewsletterService.shared
    private let ai      = OpenAIService.shared
    let savedVM = SupabaseArticlesViewModel.shared

    private init() {}

    // MARK: - Cargar draft desde GitHub

    func loadDraft() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await service.fetchDraft()
            draft = fetched
            edicionEditada = fetched.edicion
            fechaEditada   = fetched.fecha
            // Pre-rellenar hero con valores del draft
            if hero.titular.isEmpty {
                hero.titular = "INSIDE Life #\(fetched.edicion) — \(fetched.fecha)"
                hero.lead    = "Lo más relevante de la semana en IA, liderazgo, deporte y emprendimiento."
            }
        } catch {
            self.error = "No se pudo cargar el draft: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Selección de artículos (draft)

    func isSelected(_ article: DraftArticle) -> Bool {
        selectedItems.contains { $0.id == "draft-\(article.id)" }
    }

    func toggleSelection(_ article: DraftArticle) {
        let itemId = "draft-\(article.id)"
        if let idx = selectedItems.firstIndex(where: { $0.id == itemId }) {
            selectedItems.remove(at: idx)
        } else {
            selectedItems.append(NewsletterItem(from: article))
        }
    }

    // MARK: - Selección de artículos (Supabase)

    func isSelectedSupabase(_ article: SupabaseArticle) -> Bool {
        selectedItems.contains { $0.id == "sb-\(article.id)" }
    }

    func toggleSelectionSupabase(_ article: SupabaseArticle) {
        let itemId = "sb-\(article.id)"
        if let idx = selectedItems.firstIndex(where: { $0.id == itemId }) {
            selectedItems.remove(at: idx)
        } else {
            selectedItems.append(NewsletterItem(from: article))
        }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        selectedItems.move(fromOffsets: source, toOffset: destination)
    }

    func removeItem(at offsets: IndexSet) {
        selectedItems.remove(atOffsets: offsets)
    }

    func updateStyle(for item: NewsletterItem, style: ArticleStyle) {
        if let idx = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems[idx].style = style
        }
    }

    func toggleDestacada(for item: NewsletterItem) {
        let isCurrently = selectedItems.first(where: { $0.id == item.id })?.destacada ?? false
        // Si ya era la destacada, la quita; si no, la pone y quita la anterior
        for idx in selectedItems.indices {
            selectedItems[idx].destacada = (!isCurrently && selectedItems[idx].id == item.id)
        }
    }

    // MARK: - Seleccionar todos / ninguno

    func selectAll() {
        guard let draft else { return }
        selectedItems = draft.noticias.map { NewsletterItem(from: $0) }
    }

    func deselectAll() {
        selectedItems = []
    }

    func selectAllSupabase(sourceTypes: [String]) {
        let toAdd = savedVM.savedArticles.filter {
            $0.selectedForNewsletter && sourceTypes.contains($0.sourceType)
        }
        for article in toAdd {
            if !isSelectedSupabase(article) {
                selectedItems.append(NewsletterItem(from: article))
            }
        }
    }

    func deselectAllSupabase(sourceTypes: [String]) {
        let idsToRemove = savedVM.savedArticles
            .filter { sourceTypes.contains($0.sourceType) }
            .map { "sb-\($0.id)" }
        selectedItems.removeAll { idsToRemove.contains($0.id) }
    }

    // MARK: - IA por artículo

    func expandirTexto(for item: NewsletterItem) async {
        guard let idx = selectedItems.firstIndex(where: { $0.id == item.id }) else { return }
        aiLoadingItemId = item.id
        do {
            let result = try await ai.expandResumen(
                titulo: item.titulo,
                categoria: item.categoria,
                resumen: item.textoFinal
            )
            selectedItems[idx].textoFinal = result
        } catch {
            self.error = "Error al ampliar: \(error.localizedDescription)"
        }
        aiLoadingItemId = nil
    }

    func pulirConOpinion(for item: NewsletterItem) async {
        guard let idx = selectedItems.firstIndex(where: { $0.id == item.id }),
              !selectedItems[idx].opinion.isEmpty else {
            error = "Escribe tu opinión antes de pulir"
            return
        }
        aiLoadingItemId = item.id
        do {
            let result = try await ai.pulirConOpinion(
                titulo: item.titulo,
                resumen: item.textoFinal,
                opinion: item.opinion
            )
            selectedItems[idx].textoFinal = result
        } catch {
            self.error = "Error al pulir: \(error.localizedDescription)"
        }
        aiLoadingItemId = nil
    }

    func resetTexto(for item: NewsletterItem) {
        guard let idx = selectedItems.firstIndex(where: { $0.id == item.id }) else { return }
        selectedItems[idx].textoFinal = selectedItems[idx].resumen
    }

    // MARK: - IA para bloque Columna

    func generarColumna(for block: NewsletterBlock) async {
        guard let idx = extraBlocks.firstIndex(where: { $0.id == block.id }),
              !extraBlocks[idx].columnaPrompt.isEmpty else {
            error = "Escribe tu idea antes de generar"
            return
        }
        aiLoadingBlockId = block.id
        do {
            let result = try await ai.generateColumna(prompt: extraBlocks[idx].columnaPrompt)
            extraBlocks[idx].columnaTexto = result
        } catch {
            self.error = "Error al generar columna: \(error.localizedDescription)"
        }
        aiLoadingBlockId = nil
    }

    // MARK: - Regenerar draft via n8n webhook

    func regenerateDraft() async {
        guard let url = URL(string: NewsletterConfig.n8nDraftWebhook) else {
            n8nStatus = .failed("Webhook no configurado")
            return
        }
        isRegeneratingDraft = true
        n8nStatus = .connecting

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["source": "ios"])
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "(sin cuerpo)"
            print("🪄 n8n webhook → HTTP \(code)")
            print("🪄 n8n body → \(body)")

            // Tratamos cualquier respuesta del servidor como "disparado"
            // (n8n v2.12.3 tiene un bug que devuelve 500 aunque el workflow se ejecute)
            // Solo fallamos si no hay respuesta (timeout) o 404 (no encontrado)
            let triggered = code != 404 && code != 0
            if triggered {
                isRegeneratingDraft = false

                // Countdown 35 segundos
                let total = 35
                for remaining in stride(from: total, through: 1, by: -1) {
                    n8nStatus = .processing(secondsLeft: remaining)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                n8nStatus = .processing(secondsLeft: 0)

                // Recargar y mostrar cuántas noticias nuevas hay
                let antes = savedVM.savedArticles.count
                await savedVM.loadSavedArticles()
                let nuevas = max(0, savedVM.savedArticles.count - antes)
                n8nStatus = .done(count: nuevas)

                // Limpiar después de 4 segundos
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                n8nStatus = .idle
            } else {
                n8nStatus = .failed("Webhook no encontrado (404)")
                isRegeneratingDraft = false
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                n8nStatus = .idle
            }
        } catch {
            print("🪄 n8n error → \(error)")
            n8nStatus = .failed("Sin conexión")
            isRegeneratingDraft = false
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            n8nStatus = .idle
        }
    }

    // MARK: - Generar HTML preview

    func generatePreview() -> String {
        guard let draft else { return "<p>Sin draft cargado</p>" }
        let html = NewsletterHTMLGenerator.generate(
            hero: hero,
            items: selectedItems,
            blocks: extraBlocks,
            edicion: edicionEditada.isEmpty ? draft.edicion : edicionEditada,
            fecha: fechaEditada.isEmpty     ? draft.fecha   : fechaEditada
        )
        generatedHTML = html
        return html
    }

    // MARK: - Publicar

    func publish() async {
        let edicion = edicionEditada.isEmpty ? (draft?.edicion ?? "") : edicionEditada
        let fecha   = fechaEditada.isEmpty   ? (draft?.fecha ?? "")   : fechaEditada
        guard let draft, !selectedItems.isEmpty else {
            publishState = .error("Selecciona al menos un artículo")
            return
        }

        publishState = .loading

        do {
            // 1. Obtener SHA del newsletter.html actual
            let sha = try await service.fetchNewsletterSHA()

            // 2. Generar HTML
            let html = NewsletterHTMLGenerator.generate(
                hero: hero,
                items: selectedItems,
                blocks: extraBlocks,
                edicion: edicion,
                fecha: fecha
            )
            generatedHTML = html

            // 3. Publicar en GitHub (newsletter.html + newsletters/NNN.html + ediciones.json)
            let tags = Array(Set(selectedItems.map { $0.categoria.components(separatedBy: " · ").first ?? $0.categoria }))
            let result = try await service.publish(
                html: html, sha: sha, edicion: edicion,
                titulo: hero.titular.isEmpty ? "INSIDE Life #\(edicion)" : hero.titular,
                fecha: fecha,
                tags: tags
            )

            // 4. Mostrar advertencia si ediciones.json no se actualizó
            if let warning = result.edicionesWarning {
                self.error = "⚠️ \(warning)"
            }

            // 5. Polling: notificar cuando la URL esté disponible en Vercel
            Task { await waitForDeployAndNotify(url: result.url, edicion: edicion) }

            publishState = .success(url: result.url)
        } catch {
            publishState = .error(error.localizedDescription)
        }
    }

    // MARK: - Bloques extra

    func addBlock(_ type: BlockType) {
        extraBlocks.append(NewsletterBlock(type: type))
    }

    func removeBlock(at offsets: IndexSet) {
        extraBlocks.remove(atOffsets: offsets)
    }

    func moveBlock(from source: IndexSet, to destination: Int) {
        extraBlocks.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Notificación local post-publicación

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Hace polling cada 5 segundos durante un máximo de 3 minutos.
    /// Envía la notificación local en cuanto la URL devuelve 200.
    func waitForDeployAndNotify(url: String, edicion: String) async {
        guard let checkURL = URL(string: url) else { return }
        var request = URLRequest(url: checkURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 8

        for _ in 0..<36 { // 36 × 5s = 3 minutos máximo
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 segundos
            if let (_, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200..<300).contains(http.statusCode) {
                sendPublishNotification(edicion: edicion, url: url)
                return
            }
        }
        // Timeout: notificar igualmente para no dejar al usuario sin feedback
        sendPublishNotification(edicion: edicion, url: url)
    }

    private func sendPublishNotification(edicion: String, url: String) {
        let content = UNMutableNotificationContent()
        content.title = "Newsletter #\(edicion) está disponible"
        content.body  = url
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "newsletter-live-\(edicion)",
            content: content,
            trigger: nil  // entregar inmediatamente
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Reset

    func resetPublishState() {
        publishState = .idle
    }
}
