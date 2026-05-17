import Foundation

// MARK: - Modelo Supabase Articles

struct SupabaseArticle: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var content: String
    var url: String
    var sourceName: String
    var sourceType: String          // "rss" | "gmail" | "url"
    var publishedAt: Date?
    var imageUrl: String?
    var category: String?
    var summary: String?
    var isRead: Bool
    var isFavorite: Bool
    var selectedForNewsletter: Bool
    var createdAt: Date
    var relevanceScore: Int?
    var relevanceReason: String?
    var approved: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case content
        case url
        case sourceName             = "source_name"
        case sourceType             = "source_type"
        case publishedAt            = "published_at"
        case imageUrl               = "image_url"
        case category
        case summary
        case isRead                 = "is_read"
        case isFavorite             = "is_favorite"
        case selectedForNewsletter  = "selected_for_newsletter"
        case createdAt              = "created_at"
        case relevanceScore         = "relevance_score"
        case relevanceReason        = "relevance_reason"
        case approved
    }

    // MARK: - Computed

    var publishedDate: Date {
        publishedAt ?? createdAt
    }

    var displaySourceType: String {
        switch sourceType {
        case "rss":   return "RSS"
        case "gmail": return "Email"
        case "url":   return "URL"
        default:      return sourceType
        }
    }

    var sourceTypeIcon: String {
        switch sourceType {
        case "rss":   return "dot.radiowaves.up.forward"
        case "gmail": return "envelope"
        case "url":   return "link"
        default:      return "doc.text"
        }
    }

    var formattedDate: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.localizedString(for: publishedDate, relativeTo: Date())
    }

    // MARK: - Factory desde NewsArticle (RSS)

    static func from(rssArticle: NewsArticle) -> SupabaseArticle {
        SupabaseArticle(
            id: UUID().uuidString,
            title: rssArticle.title,
            description: rssArticle.description,
            content: rssArticle.content ?? "",
            url: rssArticle.url.absoluteString,
            sourceName: rssArticle.source,
            sourceType: "rss",
            publishedAt: rssArticle.publishedDate,
            imageUrl: rssArticle.imageUrl?.absoluteString,
            category: rssArticle.category,
            summary: nil,
            isRead: rssArticle.isRead,
            isFavorite: false,
            selectedForNewsletter: false,
            createdAt: Date(),
            relevanceScore: nil,
            relevanceReason: nil,
            approved: nil
        )
    }

    // Factory desde URL manual
    static func from(urlString: String, title: String, description: String, imageUrl: String? = nil) -> SupabaseArticle {
        SupabaseArticle(
            id: UUID().uuidString,
            title: title,
            description: description,
            content: "",
            url: urlString,
            sourceName: URL(string: urlString)?.host ?? "Web",
            sourceType: "url",
            publishedAt: Date(),
            imageUrl: imageUrl,
            category: nil,
            summary: nil,
            isRead: false,
            isFavorite: false,
            selectedForNewsletter: false,
            createdAt: Date(),
            relevanceScore: nil,
            relevanceReason: nil,
            approved: nil
        )
    }
}
