import Foundation

class TavilyAPIService {
    static let shared = TavilyAPIService()
    private let baseURL = "https://api.tavily.com"
    private var apiKey: String {
        return "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"
    }
    
    private init() {}
    
    // MARK: - Métodos de la API
    
    func searchNews(query: String, domains: [String] = [], searchDepth: String = "advanced", includeAnswer: Bool = true) async throws -> [TrendingNewsArticle] {
        print("Entrando en searchNews de TavilyAPIService")
        print("API Key usada: '\(apiKey)'")
        let endpoint = "\(baseURL)/v1/search"
        print("Endpoint: \(endpoint)")
        print("Query: \(query)")
        print("Search Depth: \(searchDepth)")
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("curl/8.0.1", forHTTPHeaderField: "User-Agent")
        let parameters: [String: Any] = [
            "query": query,
            "search_depth": searchDepth
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: parameters)
        request.httpBody = jsonData
        print("JSON enviado: \(String(data: jsonData, encoding: .utf8) ?? "")")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? ""
            print("Error Tavily \(httpResponse.statusCode): \(errorMessage)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        let decoder = JSONDecoder()
        let tavilyResponse = try decoder.decode(TavilyResponse.self, from: data)
        return tavilyResponse.results.map { result in
            TrendingNewsArticle(
                source: NewsSource(id: nil, name: result.source),
                author: nil,
                title: result.title,
                description: result.content,
                url: URL(string: result.url)!,
                urlToImage: nil,
                publishedAt: Date(),
                content: result.content,
                category: nil
            )
        }
    }
}

// MARK: - Modelos de Respuesta

struct TavilyResponse: Codable {
    let results: [TavilyResult]
    let answer: String?
}

struct TavilyResult: Codable {
    let title: String
    let url: String
    let content: String
    let source: String
    let score: Double
}

// MARK: - Errores

enum APIError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError
    case invalidURL
    case unauthorized
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .serverError(let statusCode):
            return "Error del servidor: \(statusCode)"
        case .decodingError:
            return "Error al procesar la respuesta"
        case .invalidURL:
            return "URL inválida"
        case .unauthorized:
            return "No autorizado. Verifica tu API key"
        case .rateLimitExceeded:
            return "Límite de peticiones alcanzado"
        }
    }
} 