import Foundation
import Combine

class NewsAPIService {
    // Singleton para acceso global
    static let shared = NewsAPIService()
    
    // Clave de API para World News API
    private let apiKey = "8782da563e5246c48061307b6fddd189" // Tu clave de World News API
    private let baseURL = "https://api.worldnewsapi.com"
    
    // Tracking de uso de la API
    private let usageKey = "worldnewsapi_usage"
    private var apiUsage: APIUsage
    
    // Caché de resultados
    private let topHeadlinesCacheKey = "topHeadlinesCache"
    private let everythingCacheKey = "everythingCache"
    
    // Tiempo de expiración del caché (en segundos)
    private let cacheExpirationTime: TimeInterval = 6 * 60 * 60 // 6 horas
    
    private init() {
        // Cargar información de uso si existe
        if let data = UserDefaults.standard.data(forKey: usageKey),
           let usage = try? JSONDecoder().decode(APIUsage.self, from: data) {
            self.apiUsage = usage
        } else {
            // Inicializar con valores predeterminados
            self.apiUsage = APIUsage(lastUpdated: Date(), requestCount: 0)
            self.saveUsageData()
        }
        
        // Limpiar todos los datos anteriores al iniciar (solo después de cambiar la API key)
        cleanAllStoredData()
    }
    
    // Método para limpiar todos los datos almacenados
    private func cleanAllStoredData() {
        // Eliminar datos de uso
        UserDefaults.standard.removeObject(forKey: usageKey)
        
        // Eliminar todas las cachés de topHeadlines
        for category in NewsCategory.allCases {
            let key = "\(topHeadlinesCacheKey)_\(category.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: "\(topHeadlinesCacheKey)_all")
        
        // Eliminar todas las cachés de búsquedas (no podemos saber todas las claves,
        // pero podemos eliminar algunas comunes)
        let commonSearches = ["tecnología", "deportes", "negocios", "política", "ciencia", "economía"]
        for search in commonSearches {
            let key = "\(everythingCacheKey)_\(search.lowercased())"
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        print("Todos los datos de caché y uso han sido eliminados")
    }
    
    // MARK: - Métodos públicos
    
    /// Obtiene las noticias destacadas (top news) por categoría
    func fetchTopHeadlines(category: NewsCategory? = nil, country: String = "es", pageSize: Int = 30) async throws -> [TrendingNewsArticle] {
        // Verificar si podemos usar datos en caché
        if let cachedArticles = getCachedTopHeadlinesPrivate(category: category) {
            return cachedArticles
        }
        
        // Verificar límites de API
        guard canMakeAPIRequest() else {
            throw NewsAPIError.rateLimitExceeded
        }
        
        // Construir URL - World News API usa diferente endpoint
        var urlComponents = URLComponents(string: "\(baseURL)/search-news")!
        var queryItems = [
            URLQueryItem(name: "source-countries", value: country),
            URLQueryItem(name: "number", value: "\(pageSize)"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        
        // Añadir categoría si está especificada - adaptamos las categorías a World News API
        if let category = category {
            let worldNewsCategory = mapCategoryToWorldNews(category)
            queryItems.append(URLQueryItem(name: "text", value: worldNewsCategory))
        }
        
        // Añadir preferencia por noticias en español
        queryItems.append(URLQueryItem(name: "language", value: "es"))
        
        urlComponents.queryItems = queryItems
        
        // Realizar petición
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        incrementRequestCount()
        
        // Verificar respuesta HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }
        
        // Manejar errores HTTP
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw NewsAPIError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 {
                throw NewsAPIError.unauthorized
            } else {
                throw NewsAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Decodificar respuesta - adaptar al formato de World News API
        do {
            let worldNewsResponse = try JSONDecoder().decode(WorldNewsSearchResponse.self, from: data)
            let articles = worldNewsResponse.news.map { convertToTrendingArticle($0, category: category?.displayName) }
            
            // Guardar en caché
            cacheTopHeadlines(articles: articles, category: category)
            
            return articles
        } catch {
            print("Error decodificando respuesta de la API: \(error)")
            throw NewsAPIError.decodingError(error)
        }
    }
    
    /// Busca noticias con filtros avanzados definidos por el usuario
    func searchNewsWithFilters(query: String? = nil, 
                           country: String? = "es", 
                           language: String = "es", 
                           sortBy: String = "publish-time",
                           fromDate: Date? = nil,
                           toDate: Date? = nil,
                           sources: [String]? = nil,
                           pageSize: Int = 30) async throws -> [TrendingNewsArticle] {
        
        // Verificar límites de API
        guard canMakeAPIRequest() else {
            throw NewsAPIError.rateLimitExceeded
        }
        
        // Construir URL
        var urlComponents = URLComponents(string: "\(baseURL)/search-news")!
        var queryItems = [
            URLQueryItem(name: "number", value: "\(pageSize)"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        
        // Añadir parámetros opcionales si están disponibles
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "text", value: query))
        }
        
        if let country = country, !country.isEmpty {
            queryItems.append(URLQueryItem(name: "source-countries", value: country))
        }
        
        if !language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        
        // Formato de fecha para la API: yyyy-MM-dd
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let fromDate = fromDate {
            let dateString = dateFormatter.string(from: fromDate)
            queryItems.append(URLQueryItem(name: "earliest-publish-date", value: dateString))
        }
        
        if let toDate = toDate {
            let dateString = dateFormatter.string(from: toDate)
            queryItems.append(URLQueryItem(name: "latest-publish-date", value: dateString))
        }
        
        if let sources = sources, !sources.isEmpty {
            let sourcesString = sources.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "news-sources", value: sourcesString))
        }
        
        // Ordenación
        queryItems.append(URLQueryItem(name: "sort", value: sortBy))
        
        urlComponents.queryItems = queryItems
        
        // Realizar petición
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        incrementRequestCount()
        
        // Verificar respuesta HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }
        
        // Manejar errores HTTP
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw NewsAPIError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 {
                throw NewsAPIError.unauthorized
            } else {
                throw NewsAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Decodificar respuesta
        do {
            let worldNewsResponse = try JSONDecoder().decode(WorldNewsSearchResponse.self, from: data)
            let articles = worldNewsResponse.news.map { 
                var article = convertToTrendingArticle($0)
                if let q = query {
                    article.category = "search: \(q)"
                }
                return article
            }
            
            return articles
        } catch {
            print("Error decodificando respuesta de la API: \(error)")
            throw NewsAPIError.decodingError(error)
        }
    }
    
    /// Busca noticias por palabras clave
    func searchEverything(query: String, language: String = "es", sortBy: String = "publishedAt", pageSize: Int = 30) async throws -> [TrendingNewsArticle] {
        // Verificar si podemos usar datos en caché
        if let cachedArticles = getCachedEverythingPrivate(query: query) {
            return cachedArticles
        }
        
        // Usar la nueva función de búsqueda avanzada
        let articles = try await searchNewsWithFilters(
            query: query,
            country: "es",
            language: language,
            sortBy: "publish-time",
            pageSize: pageSize
        )
        
        // Guardar en caché
        cacheEverything(articles: articles, query: query)
        
        return articles
    }
    
    // Obtiene estadísticas de uso de la API
    func getAPIUsage() -> APIUsage {
        return apiUsage
    }
    
    // Verifica si se puede hacer una nueva solicitud
    func canMakeAPIRequest() -> Bool {
        // Verificar si es un nuevo día
        if apiUsage.isNewDay {
            resetUsageCounters()
            return true
        }
        
        // Verificar si se ha alcanzado el límite diario
        return apiUsage.canMakeRequest
    }
    
    // MARK: - Métodos públicos para acceso a caché
    
    /// Obtiene artículos de top-headlines desde caché sin hacer petición a la API
    func getCachedTopHeadlines(category: NewsCategory?) async throws -> [TrendingNewsArticle]? {
        // Acceder directamente al método privado para evitar recursión
        let cachedArticles = self.getCachedTopHeadlinesPrivate(category: category)
        return cachedArticles
    }
    
    /// Obtiene resultados de búsqueda desde caché sin hacer petición a la API
    func getCachedEverything(query: String) async throws -> [TrendingNewsArticle]? {
        // Acceder directamente al método privado para evitar recursión
        let cachedArticles = self.getCachedEverythingPrivate(query: query)
        return cachedArticles
    }
    
    // MARK: - Métodos para mapear y convertir respuestas de la API
    
    // Mapea categorías de nuestra app a términos útiles para World News API
    private func mapCategoryToWorldNews(_ category: NewsCategory) -> String {
        switch category {
        case .business:
            return "business OR finance OR economy OR empresa OR economía OR financiera OR mercado OR bolsa OR negocio"
        case .entertainment:
            return "entertainment OR movie OR cinema OR television OR celebrity OR entretenimiento OR película OR cine OR televisión OR famosos OR música OR espectáculo"
        case .general:
            return "actualidad OR noticias OR headlines OR general OR world OR mundo"
        case .health:
            return "health OR medicine OR healthcare OR salud OR medicina OR hospitalario OR médico OR enfermedad OR bienestar"
        case .science:
            return "science OR research OR discovery OR ciencia OR investigación OR descubrimiento OR científico OR espacio OR tecnología"
        case .sports:
            return "sports OR football OR soccer OR basketball OR baseball OR tennis OR deportes OR fútbol OR baloncesto OR tenis OR atleta OR liga OR competición"
        case .technology:
            return "technology OR tech OR innovation OR digital OR software OR hardware OR tecnología OR innovación OR digital OR aplicación OR dispositivo OR móvil OR gadget"
        }
    }
    
    // Convierte un artículo de World News API a nuestro modelo TrendingNewsArticle
    private func convertToTrendingArticle(_ worldNewsArticle: WorldNewsArticle, category: String? = nil) -> TrendingNewsArticle {
        // Mapear campos de World News API a nuestro modelo
        var sourceName = "Fuente Desconocida"
        
        // Intentar extraer el nombre de la fuente de la URL
        if let url = URL(string: worldNewsArticle.url) {
            sourceName = url.host?.replacingOccurrences(of: "www.", with: "") ?? sourceName
            
            // Intentar formatear el nombre del dominio para que se vea mejor
            // Por ejemplo: "elpais.com" -> "El País"
            if sourceName == "elpais.com" {
                sourceName = "El País"
            } else if sourceName == "elmundo.es" {
                sourceName = "El Mundo"
            } else if sourceName == "lavanguardia.com" {
                sourceName = "La Vanguardia"
            } else if sourceName == "abc.es" {
                sourceName = "ABC"
            } else if sourceName == "20minutos.es" {
                sourceName = "20 Minutos"
            } else if sourceName.contains("rtve") {
                sourceName = "RTVE"
            } else if sourceName.contains("bbc") {
                sourceName = "BBC"
            } else if sourceName.contains("cnn") {
                sourceName = "CNN"
            } else if sourceName.contains("nytimes") {
                sourceName = "The New York Times"
            } else if let source = worldNewsArticle.source, !source.isEmpty {
                // Si hay una fuente proporcionada por la API, usarla
                sourceName = source
            }
        }
        
        let source = NewsSource(id: worldNewsArticle.id.description, name: sourceName)
        
        // Convertir la fecha de publicación
        let publishedAt: Date
        if let dateString = worldNewsArticle.publishDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            publishedAt = formatter.date(from: dateString) ?? Date()
        } else {
            publishedAt = Date()
        }
        
        // Crear URL para la imagen
        let imageURL: URL?
        if let imageStr = worldNewsArticle.image {
            imageURL = URL(string: imageStr)
        } else {
            imageURL = nil
        }
        
        // Crear URL para el artículo
        let articleURL = URL(string: worldNewsArticle.url) ?? URL(string: "https://example.com")!
        
        // Determinar categoría si no se proporcionó una
        var finalCategory = category
        
        if finalCategory == nil {
            // Intentar determinar categoría basada en palabras clave en el título/texto
            let text = (worldNewsArticle.title + " " + (worldNewsArticle.text ?? "")).lowercased()
            
            if text.contains("econom") || text.contains("financ") || text.contains("mercado") || text.contains("empres") {
                finalCategory = "Negocios"
            } else if text.contains("deport") || text.contains("fútbol") || text.contains("liga") {
                finalCategory = "Deportes"
            } else if text.contains("salud") || text.contains("medic") || text.contains("hospital") {
                finalCategory = "Salud"
            } else if text.contains("tecnolog") || text.contains("digital") || text.contains("software") {
                finalCategory = "Tecnología"
            } else if text.contains("cien") || text.contains("investig") || text.contains("descubr") {
                finalCategory = "Ciencia"
            } else if text.contains("entreten") || text.contains("cine") || text.contains("música") || text.contains("espectácul") {
                finalCategory = "Entretenimiento"
            } else {
                finalCategory = "General"
            }
        }
        
        return TrendingNewsArticle(
            source: source,
            author: worldNewsArticle.author,
            title: worldNewsArticle.title,
            description: worldNewsArticle.text,
            url: articleURL,
            urlToImage: imageURL,
            publishedAt: publishedAt,
            content: worldNewsArticle.text,
            category: finalCategory
        )
    }
    
    // MARK: - Métodos privados para caché
    
    // Estructura para almacenar datos en caché con timestamp
    private struct CachedData<T: Codable>: Codable {
        let timestamp: Date
        let data: T
    }
    
    // Guardar artículos de top-headlines en caché
    private func cacheTopHeadlines(articles: [TrendingNewsArticle], category: NewsCategory?) {
        let key = "\(topHeadlinesCacheKey)_\(category?.rawValue ?? "all")"
        let cachedData = CachedData(timestamp: Date(), data: articles)
        
        if let encoded = try? JSONEncoder().encode(cachedData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    // Obtener artículos de top-headlines desde caché
    private func getCachedTopHeadlinesPrivate(category: NewsCategory?) -> [TrendingNewsArticle]? {
        let key = "\(topHeadlinesCacheKey)_\(category?.rawValue ?? "all")"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedData = try? JSONDecoder().decode(CachedData<[TrendingNewsArticle]>.self, from: data) else {
            return nil
        }
        
        // Verificar si el caché ha expirado
        if Date().timeIntervalSince(cachedData.timestamp) > cacheExpirationTime {
            return nil
        }
        
        return cachedData.data
    }
    
    // Guardar resultados de búsqueda en caché
    private func cacheEverything(articles: [TrendingNewsArticle], query: String) {
        let key = "\(everythingCacheKey)_\(query.lowercased())"
        let cachedData = CachedData(timestamp: Date(), data: articles)
        
        if let encoded = try? JSONEncoder().encode(cachedData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    // Obtener resultados de búsqueda desde caché
    private func getCachedEverythingPrivate(query: String) -> [TrendingNewsArticle]? {
        let key = "\(everythingCacheKey)_\(query.lowercased())"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedData = try? JSONDecoder().decode(CachedData<[TrendingNewsArticle]>.self, from: data) else {
            return nil
        }
        
        // Verificar si el caché ha expirado
        if Date().timeIntervalSince(cachedData.timestamp) > cacheExpirationTime {
            return nil
        }
        
        return cachedData.data
    }
    
    // MARK: - Gestión de límites de API
    
    // Incrementar contador de peticiones
    private func incrementRequestCount() {
        apiUsage.incrementRequestCount()
        saveUsageData()
    }
    
    // Resetear contadores de uso
    private func resetUsageCounters() {
        apiUsage = APIUsage(lastUpdated: Date(), requestCount: 0)
        saveUsageData()
    }
    
    // Guardar datos de uso
    private func saveUsageData() {
        if let encoded = try? JSONEncoder().encode(apiUsage) {
            UserDefaults.standard.set(encoded, forKey: usageKey)
        }
    }
    
    // MARK: - Datos de ejemplo para cuando la API falla
    
    /// Genera artículos de ejemplo para proporcionar una interfaz funcional cuando la API falla
    func generateSampleHeadlines(category: NewsCategory? = nil) -> [TrendingNewsArticle] {
        let categories = ["Tecnología", "Negocios", "Deportes", "Política", "Ciencia"]
        let sources = ["El País", "El Mundo", "BBC", "CNN", "Reuters"]
        let headlines = [
            "Nuevos avances en inteligencia artificial sorprenden a expertos",
            "Mercados financieros muestran señales de recuperación económica",
            "Descubren planeta habitable a solo 40 años luz de la Tierra",
            "Nuevas tecnologías prometen revolucionar la medicina preventiva",
            "Resultados de la liga de fútbol traen sorpresas inesperadas",
            "Científicos logran avance significativo contra el cambio climático",
            "Presentan nueva generación de dispositivos móviles con mejor rendimiento",
            "Acuerdo histórico entre países para reducir emisiones contaminantes",
            "Investigadores encuentran posible cura para enfermedad degenerativa",
            "Nuevo estudio revela beneficios inesperados del ejercicio moderado"
        ]
        
        var sampleArticles: [TrendingNewsArticle] = []
        let currentDate = Date()
        
        for i in 0..<10 {
            let categoryName = category?.displayName ?? categories[i % categories.count]
            let sourceName = sources[i % sources.count]
            let title = headlines[i]
            let hoursAgo = Double(i * 3)
            
            let article = TrendingNewsArticle(
                source: NewsSource(id: "sample-\(i)", name: sourceName),
                author: "Autor de Ejemplo",
                title: title,
                description: "Esta es una descripción de ejemplo para mostrar cuando la API no está disponible. Este artículo pertenece a la categoría \(categoryName).",
                url: URL(string: "https://ejemplo.com/articulo\(i)")!,
                urlToImage: URL(string: "https://placehold.co/600x400/\(i % 2 == 0 ? "0088cc" : "cc8800")/FFFFFF?text=\(categoryName)")!,
                publishedAt: currentDate.addingTimeInterval(-3600 * hoursAgo),
                content: "Este es un contenido de ejemplo generado cuando no es posible conectar con la API de noticias. Los datos reales estarán disponibles cuando se resuelvan los problemas de conexión con la API.",
                category: categoryName
            )
            
            sampleArticles.append(article)
        }
        
        return sampleArticles
    }
    
    /// Genera artículos de muestra para búsquedas cuando la API falla
    func generateSampleSearchResults(query: String) -> [TrendingNewsArticle] {
        let sources = ["El País", "El Mundo", "BBC", "CNN", "Reuters"]
        let currentDate = Date()
        
        var sampleArticles: [TrendingNewsArticle] = []
        
        for i in 0..<5 {
            let sourceName = sources[i % sources.count]
            let hoursAgo = Double(i * 2)
            
            let article = TrendingNewsArticle(
                source: NewsSource(id: "sample-search-\(i)", name: sourceName),
                author: "Autor de Ejemplo",
                title: "Resultado de búsqueda para '\(query)': Artículo \(i+1)",
                description: "Resultado de ejemplo para la búsqueda '\(query)'. Mostrando datos simulados mientras la API no está disponible.",
                url: URL(string: "https://ejemplo.com/busqueda/\(query.replacingOccurrences(of: " ", with: "-"))/\(i)")!,
                urlToImage: URL(string: "https://placehold.co/600x400/9933cc/FFFFFF?text=\(query.prefix(10))")!,
                publishedAt: currentDate.addingTimeInterval(-3600 * hoursAgo),
                content: "Este es un contenido de ejemplo generado para la búsqueda '\(query)' mientras la API no está disponible. Los resultados reales se mostrarán cuando se resuelvan los problemas de conexión.",
                category: "search: \(query)"
            )
            
            sampleArticles.append(article)
        }
        
        return sampleArticles
    }
}

// MARK: - Errores de la API

enum NewsAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(code: String, message: String)
    case decodingError(Error)
    case rateLimitExceeded
    case dataNotAvailable
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida."
        case .invalidResponse:
            return "Respuesta inválida del servidor."
        case .httpError(let statusCode):
            return "Error HTTP: \(statusCode)"
        case .apiError(let code, let message):
            return "Error de API (\(code)): \(message)"
        case .decodingError(let error):
            return "Error al procesar los datos: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Se ha alcanzado el límite de peticiones diarias. Intenta mañana."
        case .dataNotAvailable:
            return "No hay datos disponibles en este momento."
        case .unauthorized:
            return "Acceso no autorizado. Verifica tu autenticación."
        }
    }
}

// MARK: - Modelos para World News API

// Modelo para la respuesta de búsqueda de World News API
struct WorldNewsSearchResponse: Codable {
    let news: [WorldNewsArticle]
    let offset: Int
    let number: Int
    let available: Int
}

// Modelo para un artículo de World News API
struct WorldNewsArticle: Codable {
    let id: Int
    let title: String
    let text: String?
    let url: String
    let image: String?
    let author: String?
    let language: String?
    let sourceCountry: String?
    let sentiment: Double?
    let publishDate: String?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, text, url, image, author, language
        case sourceCountry = "source_country"
        case sentiment
        case publishDate = "publish_date"
        case source
    }
} 