import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var content: String?
    var source: String
    var publishedDate: Date
    var url: URL
    var imageUrl: URL?
    var category: String?
    var isRead: Bool = false
    var isFavorite: Bool = false
    
    // Para poder usar Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NewsArticle, rhs: NewsArticle) -> Bool {
        lhs.id == rhs.id
    }
    
    // Método para crear artículos de ejemplo
    static func mockArticles() -> [NewsArticle] {
        return [
            NewsArticle(
                title: "China woos neighbours, smartest coal mine ever built",
                description: "From Xi Jinping's expected Southeast Asia tour to China performance-testing its aircraft carrier, here's a round-up from today's China coverage.",
                content: "China is actively improving relations with its Southeast Asian neighbours while also advancing its technological capabilities in mining and defense sectors, signaling a comprehensive strategy for regional influence.",
                source: "Medios de Asia",
                publishedDate: Date().addingTimeInterval(-3600),
                url: URL(string: "https://www.scmp.com/news/china/article/3304618/china-woos-neighbours-worlds-brightest-x-ray-light-source-scmp-daily-highlights")!,
                category: "Internacional"
            ),
            NewsArticle(
                title: "iOS 18.4 is out now with Apple Intelligence-powered priority notifications",
                description: "Apple's AI will help you see what's most important.",
                content: "Apple has released iOS 18.4, featuring new AI-powered priority notifications that help users focus on the most important messages and alerts, reducing distractions while ensuring critical communications are not missed.",
                source: "Medios de USA",
                publishedDate: Date().addingTimeInterval(-7200),
                url: URL(string: "https://www.theverge.com/news/639849/apple-ios-18-4-intelligence-priority-notifications")!,
                category: "Tecnología"
            ),
            NewsArticle(
                title: "Stroke survivor speaks again with help of an experimental brain-computer implant",
                description: "Scientists develop a real-time brain-computer interface translating thoughts into speech, offering hope for voice restoration in non-verbal individuals.",
                content: "A groundbreaking brain-computer interface has enabled a stroke survivor to communicate verbally again by translating neural activity directly into speech. The experimental technology maps brain signals to intended words, potentially revolutionizing treatment for those who have lost speaking ability.",
                source: "IA",
                publishedDate: Date().addingTimeInterval(-10800),
                url: URL(string: "https://www.scmp.com/news/world/united-states-canada/article/3304634/stroke-survivor-speaks-again-help-experimental-brain-computer-implant")!,
                category: "Ciencia"
            ),
            NewsArticle(
                title: "Fleet of 200 new premium taxis hit the streets of Hong Kong",
                description: "Company confident a higher level of service for its targeted customer base will be worth the longer wait times.",
                content: "Hong Kong has introduced a fleet of 200 premium taxis offering enhanced service quality and features. Despite potential longer wait times, the operating company believes customers will appreciate the superior experience, comfortable interiors, and additional amenities available in these new vehicles.",
                source: "INSIDE Life",
                publishedDate: Date().addingTimeInterval(-14400),
                url: URL(string: "https://www.scmp.com/news/hong-kong/transport/article/3304623/fleet-200-new-premium-taxis-hit-streets-hong-kong")!,
                category: "Lifestyle"
            ),
            NewsArticle(
                title: "Arsenal v Tottenham in Hong Kong matters to players and fans",
                description: "North London rivals set for July match at new Kai Tak Stadium, after AC Milan and Liverpool contest venue's first marquee football fixture.",
                content: "The upcoming North London derby between Arsenal and Tottenham in Hong Kong is generating significant excitement among both players and fans. The match, scheduled for July at the new Kai Tak Stadium, follows another high-profile contest between AC Milan and Liverpool, establishing the venue as a premier destination for international football events.",
                source: "Basketball",
                publishedDate: Date().addingTimeInterval(-18000),
                url: URL(string: "https://www.scmp.com/sport/football/article/3304626/arsenal-v-tottenham-hong-kong-matters-players-and-fans-sagna-and-king-say")!,
                category: "Deportes"
            )
        ]
    }
} 