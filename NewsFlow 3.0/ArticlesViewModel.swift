import Foundation
import Combine

class ArticlesViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var selectedFeed: RSSFeed?
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    @Published var feedManager = RSSFeedManager.shared
    @Published var showingFeedEditor = false
    
    private let rssService = RSSFeedService()
    private var cancellables = Set<AnyCancellable>()
    private var loadingTask: Task<Void, Never>?
    
    // Tiempo mínimo entre recargas (en segundos)
    private let minRefreshInterval: TimeInterval = 300 // 5 minutos
    private var lastRefreshTime: Date?
    
    // Artículos filtrados según la búsqueda y el filtro de fuente
    var filteredArticles: [NewsArticle] {
        var filtered = articles
        
        // Filtrar por texto de búsqueda
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.lowercased().contains(searchText.lowercased()) || 
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Filtrar por fuente seleccionada
        if let feed = selectedFeed {
            filtered = filtered.filter { $0.source == feed.name }
        }
        
        // Ordenar por fecha, más recientes primero
        return filtered.sorted(by: { $0.publishedDate > $1.publishedDate })
    }
    
    // Artículos favoritos
    var favoriteArticles: [NewsArticle] {
        return articles.filter { $0.isFavorite }.sorted(by: { $0.publishedDate > $1.publishedDate })
    }
    
    init() {
        // Cargar artículos favoritos y leídos desde UserDefaults al iniciar
        loadUserPreferences()
        
        // Observar cambios en las fuentes RSS
        feedManager.$feeds
            .sink { [weak self] _ in
                // En lugar de recargar artículos automáticamente, 
                // aplicamos cambios en la selección de fuentes
                if let self = self {
                    // Si la fuente seleccionada ya no está activa, desactivarla
                    if let selectedFeed = self.selectedFeed, 
                       !self.feedManager.activeFeeds.contains(where: { $0.id == selectedFeed.id }) {
                        self.selectedFeed = nil
                    }
                }
            }
            .store(in: &cancellables)
        
        // Cargar artículos inmediatamente al iniciar
        Task {
            await loadArticles()
        }
    }
    
    deinit {
        loadingTask?.cancel()
        rssService.cancelAllTasks()
    }
    
    // Verificar si debemos recargar basado en el tiempo transcurrido desde la última recarga
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) >= minRefreshInterval
    }
    
    // Versión simplificada para cargar artículos
    func loadArticles() async {
        // Evitar recarga frecuente
        if !shouldRefresh() && !articles.isEmpty {
            print("Recarga ignorada: última actualización hace menos de 5 minutos")
            return
        }
        
        await loadArticlesForced()
    }
    
    // Versión forzada que siempre recarga, independientemente del tiempo transcurrido
    func loadArticlesForced() async {
        // Cancelar tarea previa si existe
        loadingTask?.cancel()
        
        // Evitar iniciar una nueva carga si ya está en proceso
        if isLoading { return }
        
        // Crear nueva tarea
        loadingTask = Task {
            do {
                // Actualizar UI a estado de carga
                await MainActor.run {
                    self.isLoading = true
                    self.errorMessage = nil
                }
                
                // Obtener artículos
                let fetchedArticles = try await rssService.fetchAllArticles()
                
                // Verificar si la tarea ha sido cancelada
                try Task.checkCancellation()
                
                // Registrar tiempo de actualización
                self.lastRefreshTime = Date()
                
                // Actualizar UI con los resultados
                await MainActor.run {
                    // Mantener estado de favoritos para artículos existentes
                    let updatedArticles = self.mergeArticles(fetchedArticles)
                    self.articles = updatedArticles
                    self.isLoading = false
                    self.saveUserPreferences()
                }
            } catch is CancellationError {
                // Gestionar cancelación
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                // Gestionar otros errores
                print("Error al cargar artículos: \(error)")
                
                await MainActor.run {
                    let errorMessage: String
                    if let nsError = error as NSError? {
                        if nsError.domain == NSURLErrorDomain {
                            errorMessage = "Error de conexión. Por favor, verifica tu conexión a Internet y vuelve a intentarlo."
                        } else {
                            errorMessage = nsError.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    self.errorMessage = "Error al cargar los artículos: \(errorMessage)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Helper para combinar artículos nuevos con existentes
    private func mergeArticles(_ newArticles: [NewsArticle]) -> [NewsArticle] {
        var result = newArticles
        
        // Mantener estado de favoritos y leídos
        for i in 0..<result.count {
            // Buscar por URL en lugar de ID para mantener estado entre recargas
            if let existingIndex = articles.firstIndex(where: { $0.url == result[i].url }) {
                result[i].isRead = articles[existingIndex].isRead
                result[i].isFavorite = articles[existingIndex].isFavorite
                // Mantener el ID para evitar redibujados innecesarios de SwiftUI
                result[i].id = articles[existingIndex].id
            }
        }
        
        // También aplicar favoritos desde UserDefaults por si hay nuevos artículos
        // que coincidan con URLs guardadas pero que no existían en la carga anterior
        let favoritesUrls = UserDefaults.standard.stringArray(forKey: "favoriteArticles") ?? []
        let readUrls = UserDefaults.standard.stringArray(forKey: "readArticles") ?? []
        
        let favoritesSet = Set(favoritesUrls)
        let readSet = Set(readUrls)
        
        for i in 0..<result.count {
            let urlString = result[i].url.absoluteString
            if favoritesSet.contains(urlString) {
                result[i].isFavorite = true
            }
            if readSet.contains(urlString) {
                result[i].isRead = true
            }
        }
        
        return result
    }
    
    // Cargar artículos con reintentos automáticos
    func loadArticlesWithRetry(maxRetries: Int = 3) async {
        // Evitar recarga frecuente
        if !shouldRefresh() && !articles.isEmpty {
            return
        }
        
        // Cancelar tarea previa si existe
        loadingTask?.cancel()
        
        // Evitar iniciar una nueva carga si ya está en proceso
        if isLoading { return }
        
        loadingTask = Task {
            var retryCount = 0
            
            while retryCount < maxRetries {
                do {
                    await MainActor.run {
                        self.isLoading = true
                        self.errorMessage = nil
                    }
                    
                    let fetchedArticles = try await rssService.fetchAllArticles()
                    
                    try Task.checkCancellation()
                    
                    // Registrar tiempo de actualización
                    self.lastRefreshTime = Date()
                    
                    await MainActor.run {
                        let updatedArticles = self.mergeArticles(fetchedArticles)
                        self.articles = updatedArticles
                        self.isLoading = false
                        self.saveUserPreferences()
                    }
                    
                    // Éxito, salir del bucle
                    break
                } catch is CancellationError {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                } catch {
                    retryCount += 1
                    
                    if retryCount >= maxRetries {
                        await MainActor.run {
                            let errorMessage: String
                            if let nsError = error as NSError? {
                                if nsError.domain == NSURLErrorDomain {
                                    errorMessage = "Error de conexión. Por favor, verifica tu conexión a Internet."
                                } else {
                                    errorMessage = nsError.localizedDescription
                                }
                            } else {
                                errorMessage = error.localizedDescription
                            }
                            
                            self.errorMessage = "Error al cargar los artículos después de varios intentos: \(errorMessage)"
                            self.isLoading = false
                        }
                        break
                    }
                    
                    // Esperar antes de reintentar
                    let delaySeconds = pow(2.0, Double(retryCount))
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
    }
    
    // Marcar artículo como favorito
    func toggleFavorite(for article: NewsArticle) {
        // Buscar el artículo por ID y actualizar su estado de favorito
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            // Cambiar el estado de favorito
            articles[index].isFavorite.toggle()
            
            // Guardar en UserDefaults
            saveUserPreferences()
        }
    }
    
    // Marcar artículo como leído
    func markAsRead(_ article: NewsArticle) {
        // Buscar el artículo por ID y marcarlo como leído
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            // Si ya está marcado como leído, no hacer nada
            if articles[index].isRead { return }
            
            // Marcar como leído
            articles[index].isRead = true
            
            // Guardar en UserDefaults
            saveUserPreferences()
        }
    }
    
    // Guardar preferencias en UserDefaults
    private func saveUserPreferences() {
        // Guardar URLs de artículos favoritos
        let favoriteUrls = articles.filter { $0.isFavorite }.map { $0.url.absoluteString }
        UserDefaults.standard.set(favoriteUrls, forKey: "favoriteArticles")
        
        // Guardar URLs de artículos leídos
        let readUrls = articles.filter { $0.isRead }.map { $0.url.absoluteString }
        UserDefaults.standard.set(readUrls, forKey: "readArticles")
    }
    
    // Cargar preferencias desde UserDefaults
    private func loadUserPreferences() {
        // No necesitamos implementar nada aquí, ya que se aplica
        // en mergeArticles durante la carga de artículos
    }
    
    // Agregar una nueva fuente RSS
    func addFeed(name: String, urlString: String) {
        let newFeed = RSSFeed(name: name, urlString: urlString)
        feedManager.addFeed(newFeed)
    }
    
    // Actualizar una fuente RSS existente
    func updateFeed(_ feed: RSSFeed) {
        feedManager.updateFeed(feed)
        
        // Forzar una recarga de artículos si se cambia el estado de una fuente
        Task {
            await loadArticlesForced()
        }
    }
    
    // Eliminar una fuente RSS
    func deleteFeed(with id: UUID) {
        feedManager.deleteFeed(id: id)
        
        // Si la fuente eliminada era la seleccionada, quitar la selección
        if selectedFeed?.id == id {
            selectedFeed = nil
        }
        
        // Forzar una recarga de artículos
        Task {
            await loadArticlesForced()
        }
    }
    
    // Restablecer a fuentes predeterminadas
    func resetToDefaultFeeds() {
        feedManager.resetToDefaults()
        selectedFeed = nil
        
        // Forzar una recarga de artículos
        Task {
            await loadArticlesForced()
        }
    }
    
    // MARK: - Funciones para integración con publicaciones
    
    /// Convierte una noticia RSS en formato para crear una publicación
    /// - Parameter article: La noticia RSS a convertir
    /// - Returns: Tupla con texto inicial y temática sugerida
    func prepararNoticiaParaPublicacion(_ article: NewsArticle) -> (textoInicial: String, tematicaSugerida: String) {
        // Mapeo de categorías RSS a temáticas de Supabase
        let mapeoCategorias: [String: String] = [
            "Tecnología": "Tecnología",
            "IA": "IA",
            "Inteligencia Artificial": "IA",
            "Deportes": "Deporte",
            "Basketball": "Deporte",
            "Negocios": "Negocios",
            "Internacional": "Negocios",
            "Ciencia": "IA",
            "Life": "Innovación",
            "Entretenimiento": "Innovación",
            "Política": "Negocios",
            "Economía": "Negocios",
            "Salud": "IA",
            "Educación": "IA",
            "Emprendimiento": "Emprendimiento",
            "Liderazgo": "Liderazgo",
            "Innovación": "Innovación",
            "Marketing": "Marketing"
        ]
        
        // Buscar la categoría en el mapeo
        let tematicaSugerida = mapeoCategorias[article.category ?? ""] ?? "Tecnología"
        
        // Crear el texto inicial estructurado
        let textoInicial = """
        📰 NOTICIA: \(article.title)
        
        \(article.description)
        
        🔗 Fuente: \(article.url)
        📊 Categoría: \(article.category ?? "Sin categoría")
        📰 Fuente RSS: \(article.source)
        
        [Generar un post atractivo para redes sociales sobre esta noticia, incluyendo insights relevantes, hashtags apropiados y un tono profesional pero accesible. Incluir al final: "🔗 Fuente: \(article.url)"]
        """
        
        return (textoInicial, tematicaSugerida)
    }
    
    /// Obtiene el objetivo sugerido basado en la categoría de la noticia
    /// - Parameter article: La noticia RSS
    /// - Returns: Objetivo sugerido para la publicación
    func obtenerObjetivoSugerido(_ article: NewsArticle) -> String {
        let categoria = article.category ?? ""
        
        // Mapeo de categorías a objetivos de Supabase
        let mapeoObjetivos: [String: String] = [
            "Tecnología": "Interesante",
            "IA": "Educar",
            "Inteligencia Artificial": "Educar",
            "Deportes": "Interesante",
            "Basketball": "Interesante",
            "Negocios": "Interesante",
            "Internacional": "Interesante",
            "Ciencia": "Educar",
            "Life": "Interesante",
            "Entretenimiento": "Divertir",
            "Política": "Reflexión",
            "Economía": "Interesante",
            "Salud": "Educar",
            "Educación": "Educar",
            "Emprendimiento": "Motivar",
            "Liderazgo": "Motivar",
            "Innovación": "Hype"
        ]
        
        // Buscar la categoría en el mapeo
        if let objetivo = mapeoObjetivos[categoria] {
            return objetivo
        }
        
        // Si no se encuentra, usar valores por defecto según el tipo de contenido
        if categoria.lowercased().contains("deporte") || categoria.lowercased().contains("basketball") {
            return "Interesante"
        } else if categoria.lowercased().contains("tecnología") || categoria.lowercased().contains("ia") {
            return "Educar"
        } else if categoria.lowercased().contains("negocio") || categoria.lowercased().contains("economía") {
            return "Interesante"
        } else {
            return "Interesante" // Valor por defecto más seguro
        }
    }
} 