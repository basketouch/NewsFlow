import Foundation

// MARK: - Draft JSON (generado por n8n/Claude)

struct NewsletterDraft: Codable {
    let edicion: String
    let fecha: String
    let noticias: [DraftArticle]
}

struct DraftArticle: Codable, Identifiable {
    let id: Int
    let categoria: String
    let titulo: String
    let resumen: String
    let destacada: Bool     // puede faltar en algunos artículos de n8n
    let url: String?        // puede estar presente o ausente según n8n

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try  c.decode(Int.self,    forKey: .id)
        categoria = try  c.decode(String.self, forKey: .categoria)
        titulo    = try  c.decode(String.self, forKey: .titulo)
        resumen   = try  c.decode(String.self, forKey: .resumen)
        destacada = (try? c.decode(Bool.self,  forKey: .destacada)) ?? false
        url       = try? c.decode(String.self, forKey: .url)
    }
}

// MARK: - Estado de edición en la app

struct NewsletterHero {
    var titular: String
    var lead: String

    static var empty: NewsletterHero {
        NewsletterHero(titular: "", lead: "")
    }
}

enum ArticleStyle: String, CaseIterable, Identifiable {
    case normal = "normal"
    case dark   = "dark"
    case blue   = "blue"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .dark:   return "Oscuro"
        case .blue:   return "Azul"
        }
    }

    var cssClass: String {
        switch self {
        case .normal: return "nl-art"
        case .dark:   return "nl-art nl-art-dark"
        case .blue:   return "nl-art nl-art-blue"
        }
    }
}

struct NewsletterItem: Identifiable {
    let id: String
    var categoria: String
    var titulo: String
    var resumen: String         // texto original de n8n (referencia)
    var textoFinal: String      // lo que se publica — editable, puede ser pulido por IA
    var opinion: String         // punto de vista de Jorge (input para IA)
    var style: ArticleStyle
    var destacada: Bool

    init(from draft: DraftArticle) {
        self.id         = "draft-\(draft.id)"
        self.categoria  = draft.categoria
        self.titulo     = draft.titulo
        self.resumen    = draft.resumen
        self.textoFinal = draft.resumen
        self.opinion    = ""
        self.style      = .normal
        self.destacada  = draft.destacada
    }

    init(from article: SupabaseArticle) {
        self.id         = "sb-\(article.id)"
        self.categoria  = article.category ?? article.sourceName
        self.titulo     = article.title
        self.resumen    = article.summary ?? article.description
        self.textoFinal = article.summary ?? article.description
        self.opinion    = ""
        self.style      = .normal
        self.destacada  = false
    }
}

enum PublishState: Equatable {
    case idle
    case loading
    case success(url: String)
    case error(String)
}

// MARK: - Bloques extra (Texto, Callout, Promo, Imagen)

enum BlockType: String, CaseIterable, Identifiable {
    case texto   = "texto"
    case callout = "callout"
    case promo   = "promo"
    case imagen  = "imagen"
    case columna = "columna"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .texto:   return "Texto"
        case .callout: return "Callout"
        case .promo:   return "Promo"
        case .imagen:  return "Imagen"
        case .columna: return "Columna IA"
        }
    }

    var icon: String {
        switch self {
        case .texto:   return "text.alignleft"
        case .callout: return "exclamationmark.bubble.fill"
        case .promo:   return "megaphone.fill"
        case .imagen:  return "photo"
        case .columna: return "pencil.and.sparkles"
        }
    }
}

enum BlockPosition: String, CaseIterable {
    case top    = "top"
    case bottom = "bottom"

    var label: String {
        switch self {
        case .top:    return "Antes de artículos"
        case .bottom: return "Después de artículos"
        }
    }
}

struct NewsletterBlock: Identifiable {
    let id: UUID = UUID()
    var type: BlockType
    var position: BlockPosition = .bottom

    // TEXTO
    var textoTitle: String = ""
    var textoBody:  String = ""

    // CALLOUT
    var calloutLabel: String = "📌 Por qué importa"
    var calloutBody:  String = ""

    // PROMO
    var promoTitle: String = ""
    var promoBody:  String = ""
    var promoLink:  String = ""
    var promoBtn:   String = "Ver más →"

    // IMAGEN
    var imagenURL:     String = ""
    var imagenCaption: String = ""

    // COLUMNA IA
    var columnaTitulo: String = ""   // titular de la columna
    var columnaPrompt: String = ""   // semilla/idea que escribe Jorge
    var columnaTexto:  String = ""   // texto generado + editable
}
