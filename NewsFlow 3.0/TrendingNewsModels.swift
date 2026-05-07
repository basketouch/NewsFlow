import Foundation
import SwiftUI

// Modelo para las noticias en tendencia
struct TrendingNewsArticle: Identifiable, Codable, Equatable {
    let id: UUID
    let source: NewsSource
    let author: String?
    let title: String
    let description: String?
    let url: URL
    let urlToImage: URL?
    let publishedAt: Date
    let content: String?
    var category: String?
    
    // Para la identificación y comparación
    static func == (lhs: TrendingNewsArticle, rhs: TrendingNewsArticle) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Inicializador personalizado para manejar la falta de ID en la API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // La API no proporciona un id único, así que generamos uno basado en la URL
        if let url = try? container.decode(URL.self, forKey: .url) {
            // Convertir la URL a un UUID determinista basado en su string
            _ = url.absoluteString
            let uuid = UUID(uuidString: UUID().uuidString) ?? UUID()
            self.id = uuid
            self.url = url
        } else {
            self.id = UUID()
            self.url = URL(string: "https://example.com")!
        }
        
        self.source = try container.decode(NewsSource.self, forKey: .source)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.urlToImage = try container.decodeIfPresent(URL.self, forKey: .urlToImage)
        
        // Parseo de fecha
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: dateString) {
            self.publishedAt = date
        } else {
            self.publishedAt = Date()
        }
        
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
    }
    
    // Inicializador para crear instancias manualmente
    init(id: UUID = UUID(), source: NewsSource, author: String? = nil, title: String, 
         description: String? = nil, url: URL, urlToImage: URL? = nil, 
         publishedAt: Date, content: String? = nil, category: String? = nil) {
        self.id = id
        self.source = source
        self.author = author
        self.title = title
        self.description = description
        self.url = url
        self.urlToImage = urlToImage
        self.publishedAt = publishedAt
        self.content = content
        self.category = category
    }
}

// Modelo para el origen de la noticia
struct NewsSource: Codable {
    let id: String?
    let name: String
}

// Modelos para la respuesta de la API
struct NewsAPIResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [TrendingNewsArticle]
    let code: String?
    let message: String?
}

// Modelo para categorías disponibles en la API
enum NewsCategory: String, CaseIterable, Identifiable {
    case business = "business"
    case entertainment = "entertainment"
    case general = "general"
    case health = "health"
    case science = "science"
    case sports = "sports"
    case technology = "technology"
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .business: return "Negocios"
        case .entertainment: return "Entretenimiento"
        case .general: return "General"
        case .health: return "Salud"
        case .science: return "Ciencia"
        case .sports: return "Deportes"
        case .technology: return "Tecnología"
        }
    }
}

// Modelo para categorías personalizadas por el usuario
struct CustomNewsCategory: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var keywords: [String]
    var isActive: Bool
    var colorHex: String // Color personalizado para la categoría
    var lastResultCount: Int? // Último conteo de resultados
    var lastUpdated: Date? // Última vez que se actualizó
    
    init(id: UUID = UUID(), name: String, keywords: [String] = [], isActive: Bool = true, 
         colorHex: String = "#4CAF50", lastResultCount: Int? = nil, lastUpdated: Date? = nil) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.isActive = isActive
        self.colorHex = colorHex
        self.lastResultCount = lastResultCount
        self.lastUpdated = lastUpdated
    }
    
    static func == (lhs: CustomNewsCategory, rhs: CustomNewsCategory) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Obtener el Color SwiftUI desde el hex string
    var color: Color {
        Color(hex: colorHex) ?? Color.green
    }
    
    // Lista de colores predefinidos para elegir
    static let predefinedColors = [
        "#4CAF50", // Verde
        "#2196F3", // Azul
        "#F44336", // Rojo
        "#FF9800", // Naranja
        "#9C27B0", // Púrpura
        "#795548", // Marrón
        "#607D8B", // Gris azulado
        "#E91E63", // Rosa
        "#009688", // Verde azulado
        "#673AB7"  // Violeta
    ]
}

// Extension para convertir hex a Color de SwiftUI
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}

// Modelo para rastrear el uso de la API y límites
struct APIUsage: Codable {
    var lastUpdated: Date
    var requestCount: Int
    var dailyLimit: Int = 50
    
    var canMakeRequest: Bool {
        return requestCount < dailyLimit
    }
    
    var isNewDay: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(lastUpdated, inSameDayAs: Date())
    }
    
    mutating func incrementRequestCount() {
        if isNewDay {
            // Resetear contador si es un nuevo día
            requestCount = 1
            lastUpdated = Date()
        } else {
            requestCount += 1
        }
    }
} 