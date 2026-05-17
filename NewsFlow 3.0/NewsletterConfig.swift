import Foundation

enum NewsletterConfig {
    static let apiURL        = "https://insidelife.club/api/github"
    static let adminSecret   = "bpM58914032-*"
    static let draftFile     = "newsletter-draft.json"
    static let publishFile   = "newsletter.html"
    static let siteURL       = "https://insidelife.club"

    /// Webhook de n8n para regenerar el draft manualmente.
    /// Configúralo añadiendo un nodo "Webhook" al flujo de generación en n8n.
    static let n8nDraftWebhook = "https://n8n.basketouch.com/webhook/newsletter-cargar-noticias"

    static var authHeader: String { "Bearer \(adminSecret)" }
}
