import Foundation

// MARK: - Model

struct ContentDailyPost: Identifiable, Codable {
    var id: String
    var date: String                        // "2026-04-21"
    var topic: String
    var sourceUrl: String?
    var sourceArticleId: String?

    var linkedinPost: String?
    var linkedinScore: Int?

    var instagramPost: String?
    var instagramImagePrompt: String?
    var instagramScore: Int?

    var twitterPost: String?
    var twitterScore: Int?

    var tiktokScript: String?
    var tiktokScore: Int?

    var hashtags: [String]
    var status: String                      // pending_review | published_partial | published_all
    var publishedTo: [String]
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case topic
        case sourceUrl          = "source_url"
        case sourceArticleId    = "source_article_id"
        case linkedinPost       = "linkedin_post"
        case linkedinScore      = "linkedin_score"
        case instagramPost      = "instagram_post"
        case instagramImagePrompt = "instagram_image_prompt"
        case instagramScore     = "instagram_score"
        case twitterPost        = "twitter_post"
        case twitterScore       = "twitter_score"
        case tiktokScript       = "tiktok_script"
        case tiktokScore        = "tiktok_score"
        case hashtags
        case status
        case publishedTo        = "published_to"
        case createdAt          = "created_at"
    }

    // MARK: - Computed

    var isPendingReview: Bool { status == "pending_review" }

    var isPublishedTo: (linkedin: Bool, instagram: Bool, twitter: Bool, tiktok: Bool) {
        (
            publishedTo.contains("linkedin"),
            publishedTo.contains("instagram"),
            publishedTo.contains("twitter"),
            publishedTo.contains("tiktok")
        )
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: date) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.locale = Locale(identifier: "es_ES")
            return display.string(from: d)
        }
        return date
    }

    var platformCount: Int {
        [linkedinPost, instagramPost, twitterPost, tiktokScript]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .count
    }

    var statusLabel: String {
        switch status {
        case "pending_review":   return "Pendiente"
        case "published_partial": return "Parcial"
        case "published_all":    return "Publicado"
        default:                 return status
        }
    }

    var statusColor: String {
        switch status {
        case "pending_review":   return "orange"
        case "published_partial": return "blue"
        case "published_all":    return "green"
        default:                 return "gray"
        }
    }
}
