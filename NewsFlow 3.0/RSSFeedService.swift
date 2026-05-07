import Foundation
import Combine

// Modelo para fuentes RSS personalizables
struct RSSFeed: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var urlString: String
    var isActive: Bool
    
    var url: URL? {
        URL(string: urlString)
    }
    
    init(id: UUID = UUID(), name: String, urlString: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.isActive = isActive
    }
    
    static func == (lhs: RSSFeed, rhs: RSSFeed) -> Bool {
        lhs.id == rhs.id
    }
}

// Gestor de fuentes RSS que maneja la persistencia
class RSSFeedManager: ObservableObject {
    static let shared = RSSFeedManager()
    
    @Published private(set) var feeds: [RSSFeed] = []
    private let userDefaultsKey = "rssFeeds"
    
    private init() {
        loadFeeds()
    }
    
    // Carga las fuentes RSS desde UserDefaults o usa las predeterminadas si no hay guardadas
    private func loadFeeds() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedFeeds = try? JSONDecoder().decode([RSSFeed].self, from: data) {
            self.feeds = savedFeeds
        } else {
            // Usar las fuentes predeterminadas si no hay guardadas
            self.feeds = defaultFeeds
            saveFeeds()
        }
    }
    
    // Guarda las fuentes RSS en UserDefaults
    private func saveFeeds() {
        if let data = try? JSONEncoder().encode(feeds) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Notificar a los observadores que los datos han cambiado
            objectWillChange.send()
        }
    }
    
    // Agrega una nueva fuente RSS
    func addFeed(_ feed: RSSFeed) {
        feeds.append(feed)
        saveFeeds()
    }
    
    // Actualiza una fuente RSS existente
    func updateFeed(_ feed: RSSFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
            saveFeeds()
        }
    }
    
    // Elimina una fuente RSS
    func deleteFeed(id: UUID) {
        feeds.removeAll { $0.id == id }
        saveFeeds()
    }
    
    // Restablece a las fuentes predeterminadas
    func resetToDefaults() {
        feeds = defaultFeeds
        saveFeeds()
    }
    
    // Fuentes predeterminadas
    var defaultFeeds: [RSSFeed] = [
        RSSFeed(name: "Medios de Asia", urlString: "https://rss.app/feeds/_XEPanRzHmJRKNmiF.xml"),
        RSSFeed(name: "Medios de USA", urlString: "https://rss.app/feeds/_wMjku6F4wfp1kUzN.xml"),
        RSSFeed(name: "IA", urlString: "https://rss.app/feeds/_PkaQRQxhUKUcDCik.xml"),
        RSSFeed(name: "INSIDE Life", urlString: "https://rss.app/feeds/_MnE8vyYAeJVtNJ6r.xml"),
        RSSFeed(name: "Basketball", urlString: "https://rss.app/feeds/_Yyd7iCnVy121sx57.xml")
    ]
    
    // Obtenemos solo las fuentes activas
    var activeFeeds: [RSSFeed] {
        feeds.filter { $0.isActive }
    }
}

// Mantener compatibilidad con código existente (será eliminado después)
enum FeedSource: String, CaseIterable, Identifiable {
    case mediosAsia = "Medios de Asia"
    case mediosUSA = "Medios de USA"
    case ia = "IA"
    case insideLife = "INSIDE Life"
    case basketball = "Basketball"
    
    var id: String { self.rawValue }
    
    var url: URL {
        switch self {
        case .mediosAsia:
            return URL(string: "https://rss.app/feeds/_XEPanRzHmJRKNmiF.xml")!
        case .mediosUSA:
            return URL(string: "https://rss.app/feeds/_wMjku6F4wfp1kUzN.xml")!
        case .ia:
            return URL(string: "https://rss.app/feeds/_PkaQRQxhUKUcDCik.xml")!
        case .insideLife:
            return URL(string: "https://rss.app/feeds/_MnE8vyYAeJVtNJ6r.xml")!
        case .basketball:
            return URL(string: "https://rss.app/feeds/_Yyd7iCnVy121sx57.xml")!
        }
    }
}

class RSSFeedService {
    // Usar actor para proteger el estado compartido
    private actor TaskManager {
        private var tasks = [String: Task<[NewsArticle], Error>]()
        
        func add(task: Task<[NewsArticle], Error>, for key: String) {
            cancel(for: key)
            tasks[key] = task
        }
        
        func cancel(for key: String) {
            tasks[key]?.cancel()
            tasks[key] = nil
        }
        
        func remove(for key: String) {
            tasks[key] = nil
        }
        
        func cancelAll() {
            for (_, task) in tasks {
                task.cancel()
            }
            tasks.removeAll()
        }
    }
    
    private let taskManager = TaskManager()
    private let maxRetries = 3
    private let session = URLSession.shared
    private let feedManager = RSSFeedManager.shared
    
    // Lista de dominios que suelen requerir suscripción
    private let subscriptionDomains = [
        "scmp.com",
        "nytimes.com",
        "wsj.com",
        "ft.com",
        "bloomberg.com",
        "economist.com",
        "washingtonpost.com"
    ]
    
    // Verificar si una URL es de un sitio con suscripción
    private func requiresSubscription(url: URL) -> Bool {
        let host = url.host ?? ""
        return subscriptionDomains.contains { host.contains($0) }
    }
    
    // Analizar datos XML de RSS para convertirlos en artículos
    private func parseRSS(data: Data, source: String) -> [NewsArticle] {
        // Implementación básica para extraer artículos del RSS
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        
        // Crear artículos a partir del contenido XML
        var articles = [NewsArticle]()
        
        // Extraer items del XML
        let itemPattern = "<item>(.+?)</item>"
        let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .dotMatchesLineSeparators)
        let itemMatches = itemRegex?.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)) ?? []
        
        for match in itemMatches {
            if let range = Range(match.range, in: xmlString) {
                let itemContent = String(xmlString[range])
                
                // Extraer título
                let title = extractContent(from: itemContent, tag: "title") ?? "Sin título"
                
                // Extraer descripción
                let description = extractContent(from: itemContent, tag: "description") ?? "Sin descripción"
                
                // Extraer link
                guard let linkStr = extractContent(from: itemContent, tag: "link"),
                      let url = URL(string: linkStr) else {
                    continue
                }
                
                // Extraer fecha de publicación
                let pubDateStr = extractContent(from: itemContent, tag: "pubDate") ?? ""
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                let publishedDate = dateFormatter.date(from: pubDateStr) ?? Date()
                
                // Extraer contenido si existe
                var finalContent: String
                if let contentEncoded = extractContent(from: itemContent, tag: "content:encoded") {
                    finalContent = contentEncoded
                } else if let contentTag = extractContent(from: itemContent, tag: "content") {
                    finalContent = contentTag
                } else {
                    finalContent = description
                }
                
                // Crear artículo
                let article = NewsArticle(
                    title: cleanHtmlContent(title),
                    description: cleanHtmlContent(description),
                    content: cleanHtmlContent(finalContent),
                    source: source,
                    publishedDate: publishedDate,
                    url: url,
                    category: extractContent(from: itemContent, tag: "category")
                )
                
                articles.append(article)
            }
        }
        
        // Si no se pudieron extraer artículos (por ejemplo, si el formato es diferente),
        // usar datos de ejemplo como fallback
        if articles.isEmpty {
            print("No se pudieron extraer artículos del RSS de \(source), usando datos de ejemplo")
            return generateSampleArticlesForFallback(source: source)
        }
        
        return articles
    }
    
    // Helper para extraer contenido entre etiquetas XML
    private func extractContent(from text: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let contentRange = Range(match.range(at: 1), in: text) {
            return cleanHtmlContent(String(text[contentRange]))
        }
        return nil
    }
    
    // Función para limpiar el contenido HTML
    private func cleanHtmlContent(_ html: String) -> String {
        var result = html
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
        
        // Convertir entidades HTML comunes
        let htmlEntities: [String: String] = [
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\"",
            "&rdquo;": "\"",
            "&bull;": "•",
            "&hellip;": "…"
        ]
        
        // Reemplazar entidades HTML
        for (entity, character) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        
        // Eliminar todas las etiquetas HTML
        let tagPattern = "<[^>]+>"
        let tagRegex = try? NSRegularExpression(pattern: tagPattern)
        if let regex = tagRegex {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.count),
                withTemplate: ""
            )
        }
        
        return result
    }
    
    // Artículos de ejemplo como fallback
    private func generateSampleArticlesForFallback(source: String) -> [NewsArticle] {
        // Configuración básica
        let count = Int.random(in: 3...7)
        var articles = [NewsArticle]()
        
        for i in 0..<count {
            let title = "Noticia de \(source) - \(i + 1)"
            let description = "Esta es una noticia de ejemplo para \(source)"
            
            // Fechas con distribución temporal amplia
            let dayOffset = Double(i * 86400)
            let randomVariation = Double.random(in: 0...43200)
            let date = Date().addingTimeInterval(-(dayOffset + randomVariation))
            
            // URL segura que no requiere suscripción
            let url = URL(string: "https://example.com/\(source)/article\(i)")!
            
            let article = NewsArticle(
                title: title,
                description: description,
                content: "Contenido detallado de la noticia de ejemplo número \(i+1) para \(source).",
                source: source,
                publishedDate: date,
                url: url,
                category: "General"
            )
            
            articles.append(article)
        }
        
        return articles
    }
    
    // Obtener datos reales desde la URL de RSS
    private func fetchRSSData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "RSSFeedService", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Error al obtener datos RSS"
            ])
        }
        
        return data
    }
    
    // Obtener artículos de una fuente específica
    func fetchArticles(from feed: RSSFeed) async throws -> [NewsArticle] {
        guard let url = feed.url else {
            throw NSError(domain: "RSSFeedService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "URL inválida para \(feed.name)"
            ])
        }
        
        let data = try await fetchRSSData(from: url)
        return parseRSS(data: data, source: feed.name)
    }
    
    // Obtener todos los artículos de todas las fuentes activas
    func fetchAllArticles() async throws -> [NewsArticle] {
        var allArticles = [NewsArticle]()
        
        // Usar fuentes del gestor en lugar del enum
        let activeFeeds = feedManager.activeFeeds
        
        // Si no hay fuentes activas, devolver array vacío
        if activeFeeds.isEmpty {
            return []
        }
        
        // Obtener artículos de cada fuente
        try await withThrowingTaskGroup(of: (String, [NewsArticle]).self) { group in
            for feed in activeFeeds {
                guard let url = feed.url else { continue }
                
                group.addTask {
                    let feedId = feed.id.uuidString
                    do {
                        let data = try await self.fetchRSSData(from: url)
                        let articles = self.parseRSS(data: data, source: feed.name)
                        return (feedId, articles)
                    } catch {
                        // Si falla una fuente, continuar con las demás
                        // Solo mostrar errores que no sean de cancelación
                        if !error.localizedDescription.contains("cancelled") {
                            print("⚠️ RSS \(feed.name): Error - \(error.localizedDescription)")
                        }
                        return (feedId, [])
                    }
                }
            }
            
            // Recopilar resultados
            for try await (_, articles) in group {
                allArticles.append(contentsOf: articles)
            }
        }
        
        return allArticles
    }
    
    // Cancelar todas las tareas
    func cancelAllTasks() {
        Task {
            await taskManager.cancelAll()
        }
    }
} 