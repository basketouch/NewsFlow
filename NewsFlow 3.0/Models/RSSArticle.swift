import Foundation

struct RSSArticle: Identifiable, Codable {
    let id: UUID
    let title: String
    let link: URL
    let pubDate: Date
    let description: String?    // Contenido corto o resumen
    let content: String?        // Contenido completo si está disponible
    let imageUrl: URL?        // URL de la imagen si está disponible
    
    // Inicializador personalizado para manejar el título y contenido
    init(id: UUID = UUID(), title: String, link: URL, pubDate: Date, description: String? = nil, content: String? = nil, imageUrl: URL? = nil) {
        self.id = id
        // Limpiamos el título de posibles caracteres HTML y normalizamos espacios
        self.title = title
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        self.link = link
        self.pubDate = pubDate
        self.imageUrl = imageUrl
        
        // Procesamos el contenido y la descripción
        self.description = description?.cleanHTML()
        self.content = content?.cleanHTML()
    }
    
    // Obtener el contenido principal para mostrar
    var mainContent: String {
        if let fullContent = content, !fullContent.isEmpty {
            return fullContent
        }
        return description ?? "No hay contenido disponible"
    }
    
    // Extraer imagen del contenido si no hay imageUrl
    func extractImageFromContent() -> URL? {
        if let imageUrl = imageUrl {
            return imageUrl
        }
        
        // Buscar URL de imagen en el contenido si existe
        if let content = content {
            let pattern = "src=[\"'](https?://[^\"']+\\.(jpg|jpeg|png|gif))[\"']"
            if let range = content.range(of: pattern, options: .regularExpression) {
                let urlString = String(content[range])
                    .replacingOccurrences(of: "src=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                return URL(string: urlString)
            }
        }
        return nil
    }
}

// Extensión para funcionalidades adicionales del título
extension RSSArticle {
    // Obtener un título truncado si es necesario
    func truncatedTitle(limit: Int = 100) -> String {
        if title.count <= limit {
            return title
        }
        let index = title.index(title.startIndex, offsetBy: limit)
        return String(title[..<index]) + "..."
    }
    
    // Verificar si el título está en mayúsculas y normalizarlo si es necesario
    var normalizedTitle: String {
        let uppercasePercentage = Double(title.filter { $0.isUppercase }.count) / Double(title.filter { $0.isLetter }.count)
        if uppercasePercentage > 0.8 {
            return title.capitalized
        }
        return title
    }
}

// Extensión para limpieza de HTML
extension String {
    func cleanHTML() -> String {
        // Preservar saltos de línea antes de eliminar HTML
        var text = self.replacingOccurrences(of: "<br>|<br />|<p>|</p>", with: "\n", options: .regularExpression)
        
        // Preservar listas
        text = text.replacingOccurrences(of: "<li>", with: "• ", options: .regularExpression)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .regularExpression)
        
        // Eliminar resto de etiquetas HTML
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decodificar entidades HTML comunes
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        
        // Normalizar espacios y líneas en blanco
        text = text.replacingOccurrences(of: "\\s*\n\\s*", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 