import Foundation

// MARK: - Tipo de vídeo (local, no persiste en Supabase)

enum VideoType: String, CaseIterable {
    case motivacional  = "motivacional"
    case educativo     = "educativo"
    case promocional   = "promocional"
    case insideLife    = "inside_life"
    case deporte       = "deporte"
    case entrevista    = "entrevista"

    var displayName: String {
        switch self {
        case .motivacional: return "Motivacional"
        case .educativo:    return "Educativo / Sistema"
        case .promocional:  return "Promocional"
        case .insideLife:   return "Inside Life"
        case .deporte:      return "Baloncesto / Deporte"
        case .entrevista:   return "Entrevista"
        }
    }

    var tema: String {
        switch self {
        case .motivacional: return "liderazgo y desarrollo personal"
        case .educativo:    return "sistemas y productividad"
        case .promocional:  return "emprendimiento y negocio digital"
        case .insideLife:   return "Inside Life y estilo de vida"
        case .deporte:      return "baloncesto y deporte"
        case .entrevista:   return "entrevistas y conversaciones"
        }
    }

    var icon: String {
        switch self {
        case .motivacional: return "flame.fill"
        case .educativo:    return "brain.head.profile"
        case .promocional:  return "megaphone.fill"
        case .insideLife:   return "newspaper.fill"
        case .deporte:      return "basketball.fill"
        case .entrevista:   return "mic.fill"
        }
    }
}

// MARK: - Plataformas

enum VideoPlatform: String, CaseIterable, Codable {
    case youtube   = "youtube"
    case tiktok    = "tiktok"
    case instagram = "instagram"
    case threads   = "threads"

    var displayName: String {
        switch self {
        case .youtube:   return "YouTube"
        case .tiktok:    return "TikTok"
        case .instagram: return "Instagram"
        case .threads:   return "Threads"
        }
    }

    var icon: String {
        switch self {
        case .youtube:   return "play.rectangle.fill"
        case .tiktok:    return "music.note"
        case .instagram: return "camera.fill"
        case .threads:   return "at.circle.fill"
        }
    }
}

// MARK: - Status

enum VideoStatus: String, Codable {
    case pending    = "pending"
    case ready      = "ready"
    case publishing = "publishing"
    case published  = "published"
    case error      = "error"

    var displayName: String {
        switch self {
        case .pending:    return "Pendiente"
        case .ready:      return "Listo"
        case .publishing: return "Publicando..."
        case .published:  return "Publicado"
        case .error:      return "Error"
        }
    }

    var color: String {
        switch self {
        case .pending:    return "gray"
        case .ready:      return "blue"
        case .publishing: return "orange"
        case .published:  return "green"
        case .error:      return "red"
        }
    }
}

// MARK: - Modelo principal

struct VideoItem: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var hashtags: [String]
    var category: String?
    var thumbnailUrl: String?

    var source: String              // "drive" | "gallery"
    var driveFileId: String?
    var driveFileName: String?
    var storageUrl: String?

    var platforms: [String]
    var scheduledAt: Date?
    var status: String
    var publishedUrls: [String: String]?
    var errorMsg: String?

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, hashtags, category
        case thumbnailUrl   = "thumbnail_url"
        case source
        case driveFileId    = "drive_file_id"
        case driveFileName  = "drive_file_name"
        case storageUrl     = "storage_url"
        case platforms
        case scheduledAt    = "scheduled_at"
        case status
        case publishedUrls  = "published_urls"
        case errorMsg       = "error_msg"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    // MARK: - Computed

    var videoStatus: VideoStatus {
        VideoStatus(rawValue: status) ?? .pending
    }

    var selectedPlatforms: [VideoPlatform] {
        platforms.compactMap { VideoPlatform(rawValue: $0) }
    }

    var displayName: String {
        driveFileName ?? storageUrl?.components(separatedBy: "/").last ?? "Vídeo"
    }

    var hashtagsString: String {
        hashtags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " ")
    }

    var formattedDate: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.localizedString(for: createdAt, relativeTo: Date())
    }

    // MARK: - Custom decoder (resiliente a formatos de Supabase)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        title         = (try? c.decode(String.self, forKey: .title)) ?? ""
        description   = (try? c.decode(String.self, forKey: .description)) ?? ""
        hashtags      = (try? c.decode([String].self, forKey: .hashtags)) ?? []
        category      = try? c.decode(String.self, forKey: .category)
        thumbnailUrl  = try? c.decode(String.self, forKey: .thumbnailUrl)
        source        = (try? c.decode(String.self, forKey: .source)) ?? "drive"
        driveFileId   = try? c.decode(String.self, forKey: .driveFileId)
        driveFileName = try? c.decode(String.self, forKey: .driveFileName)
        storageUrl    = try? c.decode(String.self, forKey: .storageUrl)
        platforms     = (try? c.decode([String].self, forKey: .platforms)) ?? []
        scheduledAt   = try? c.decode(Date.self, forKey: .scheduledAt)
        status        = (try? c.decode(String.self, forKey: .status)) ?? "pending"
        errorMsg      = try? c.decode(String.self, forKey: .errorMsg)
        createdAt     = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt     = (try? c.decode(Date.self, forKey: .updatedAt)) ?? Date()

        // published_urls puede llegar como JSONB {"youtube":"url"}, {"youtube":null}
        // o como string codificada "{\"youtube\":null}" según cómo lo escriba n8n
        if let dict = try? c.decode([String: String].self, forKey: .publishedUrls) {
            publishedUrls = dict
        } else if let str = try? c.decode(String.self, forKey: .publishedUrls),
                  let data = str.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            publishedUrls = raw.compactMapValues { $0 as? String }
        } else {
            publishedUrls = nil
        }
    }

    // MARK: - Memberwise init (necesario al definir init(from:) personalizado)

    init(id: String, title: String, description: String, hashtags: [String],
         category: String?, thumbnailUrl: String?, source: String,
         driveFileId: String?, driveFileName: String?, storageUrl: String?,
         platforms: [String], scheduledAt: Date?, status: String,
         publishedUrls: [String: String]?, errorMsg: String?,
         createdAt: Date, updatedAt: Date) {
        self.id            = id
        self.title         = title
        self.description   = description
        self.hashtags      = hashtags
        self.category      = category
        self.thumbnailUrl  = thumbnailUrl
        self.source        = source
        self.driveFileId   = driveFileId
        self.driveFileName = driveFileName
        self.storageUrl    = storageUrl
        self.platforms     = platforms
        self.scheduledAt   = scheduledAt
        self.status        = status
        self.publishedUrls = publishedUrls
        self.errorMsg      = errorMsg
        self.createdAt     = createdAt
        self.updatedAt     = updatedAt
    }

    // MARK: - Factory

    static func empty(source: String = "drive") -> VideoItem {
        VideoItem(
            id: UUID().uuidString,
            title: "",
            description: "",
            hashtags: [],
            category: nil,
            thumbnailUrl: nil,
            source: source,
            driveFileId: nil,
            driveFileName: nil,
            storageUrl: nil,
            platforms: ["youtube"],
            scheduledAt: nil,
            status: "pending",
            publishedUrls: nil,
            errorMsg: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
