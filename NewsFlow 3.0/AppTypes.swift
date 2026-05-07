import Foundation
import SwiftUI

// Typealias útiles
typealias ArticleID = UUID

// Extensiones útiles
extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: self)
    }
    
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Hace 1 día" : "Hace \(day) días"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "Hace 1 hora" : "Hace \(hour) horas"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "Hace 1 minuto" : "Hace \(minute) minutos"
        } else {
            return "Ahora mismo"
        }
    }
}

extension String {
    func trimHTMLTags() -> String {
        // Limpieza mejorada de etiquetas HTML
        let htmlTagPattern = "<[^>]+>"
        let result = self.replacingOccurrences(of: htmlTagPattern, with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}

extension Color {
    static let primaryBackground = Color("PrimaryBackground", bundle: nil)
    static let secondaryBackground = Color("SecondaryBackground", bundle: nil)
    static let primaryText = Color("PrimaryText", bundle: nil)
    static let secondaryText = Color("SecondaryText", bundle: nil)
    
    // Para uso en ausencia de assets de colores personalizados
    static let defaultBackground = Color(.systemBackground)
    static let defaultSecondary = Color(.secondarySystemBackground)
}

// MARK: - Modificadores de vista personalizados
extension View {
    func articleCardStyle() -> some View {
        self.padding()
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            .shadow(radius: 2)
    }
    
    func headlineStyle() -> some View {
        self.font(.headline)
            .foregroundColor(.primaryText)
            .lineLimit(2)
    }
    
    func subheadlineStyle() -> some View {
        self.font(.subheadline)
            .foregroundColor(.secondaryText)
            .lineLimit(3)
    }
} 