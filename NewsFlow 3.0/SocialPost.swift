import Foundation

struct SocialPost: Identifiable, Codable {
    var id: String
    var texto: String
    var textoEnriquecido: String
    var hashtags: String
    var redSocial: String           // "LinkedIn" | "X"
    var fecha: Date
    var estado: String              // PostStatus.rawValue
    var aprobado: Bool
    var publicado: Bool
    var tematica: String
    var objetivo: String
    var urlEdicion: String?
    var slotProgramado: String?
    var fechaCreacion: Date
    var fechaModificacion: Date
    var mediaUrl: String?           // URL de imagen o vídeo adjunto
    var mediaType: String           // MediaType.rawValue — default "texto"

    enum CodingKeys: String, CodingKey {
        case id
        case texto
        case textoEnriquecido   = "texto_enriquecido"
        case hashtags
        case redSocial          = "red_social"
        case fecha
        case estado
        case aprobado
        case publicado
        case tematica
        case objetivo
        case urlEdicion         = "url_edicion"
        case slotProgramado     = "slot_programado"
        case fechaCreacion      = "fecha_creacion"
        case fechaModificacion  = "fecha_modificacion"
        case mediaUrl           = "media_url"
        case mediaType          = "media_type"
    }

    // MARK: - Computed

    var mediaTypeEnum: MediaType {
        MediaType(rawValue: mediaType) ?? .texto
    }

    var hasMedia: Bool {
        mediaTypeEnum != .texto && !(mediaUrl ?? "").isEmpty
    }

    var redSocialEnum: SocialNetwork {
        SocialNetwork(rawValue: redSocial) ?? .linkedin
    }

    var estadoEnum: PostStatus {
        PostStatus(rawValue: estado) ?? .borrador
    }

    var isEnriched: Bool {
        !textoEnriquecido.isEmpty && textoEnriquecido != texto
    }

    var isScheduledForToday: Bool {
        Calendar.current.isDateInToday(fecha)
    }

    var isReadyForPublishing: Bool {
        aprobado && !publicado && fecha <= Date()
    }

    var formattedPublishDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: fecha)
    }

    // MARK: - Factory

    static func nuevo(texto: String, redSocial: SocialNetwork, fecha: Date, tematica: String, objetivo: String, urlEdicion: String? = nil, mediaUrl: String? = nil, mediaType: MediaType = .texto) -> SocialPost {
        let now = Date()
        return SocialPost(
            id: UUID().uuidString,
            texto: texto,
            textoEnriquecido: "",
            hashtags: "",
            redSocial: redSocial.rawValue,
            fecha: fecha,
            estado: PostStatus.borrador.rawValue,
            aprobado: false,
            publicado: false,
            tematica: tematica,
            objetivo: objetivo,
            urlEdicion: urlEdicion,
            slotProgramado: nil,
            fechaCreacion: now,
            fechaModificacion: now,
            mediaUrl: mediaUrl,
            mediaType: mediaType.rawValue
        )
    }
}

// MARK: - Enums

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case texto   = "texto"
    case imagen  = "imagen"
    case video   = "video"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .texto:  return "text.alignleft"
        case .imagen: return "photo"
        case .video:  return "video"
        }
    }

    var label: String {
        switch self {
        case .texto:  return "Texto"
        case .imagen: return "Imagen"
        case .video:  return "Vídeo"
        }
    }
}

enum SocialNetwork: String, Codable, CaseIterable, Identifiable {
    case linkedin = "LinkedIn"
    case twitter  = "X"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .linkedin: return "linkedin"
        case .twitter:  return "twitter"
        }
    }
}

enum PostStatus: String, Codable, CaseIterable, Identifiable {
    case borrador          = "Borrador"
    case listoParaAprobar  = "Listo para aprobar"
    case listoParaPublicar = "Listo para publicar"
    case publicado         = "Publicado"

    var id: String { rawValue }
}

extension Date {
    var relativeDateString: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.localizedString(for: self, relativeTo: Date())
    }
}
