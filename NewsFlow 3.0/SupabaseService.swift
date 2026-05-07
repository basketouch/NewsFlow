import Foundation

/// Cliente REST genérico para Supabase (PostgREST)
class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: String
    private let anonKey: String

    private var headers: [String: String] {
        [
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            var str = try container.decode(String.self)

            // Normalizar formato PostgreSQL: "2026-04-17 08:59:02.571158+00"
            // 1. Espacio → T
            str = str.replacingOccurrences(of: " ", with: "T")
            // 2. Truncar microsegundos (6 dígitos) a milisegundos (3 dígitos)
            if let dotIdx = str.firstIndex(of: ".") {
                let afterDot = str.index(dotIdx, offsetBy: 1)
                if let tzIdx = str[afterDot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
                    let fracRange = afterDot..<tzIdx
                    let frac = String(str[fracRange])
                    if frac.count > 3 {
                        str = str.replacingCharacters(in: fracRange, with: String(frac.prefix(3)))
                    }
                }
            }
            // 3. Timezone corto "+00" → "+00:00"
            if str.hasSuffix("+00") { str += ":00" }

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd"
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Formato de fecha no reconocido: \(str)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        e.dateEncodingStrategy = .formatted(formatter)
        return e
    }()

    private init() {
        self.baseURL = "\(SupabaseConfig.projectURL)/rest/v1"
        self.anonKey = SupabaseConfig.anonKey
    }

    // MARK: - Fetch

    /// Obtiene todos los registros de una tabla con filtros opcionales.
    /// Filtros en formato PostgREST: ["aprobado": "eq.true", "publicado": "eq.false"]
    func fetch<T: Decodable>(_ table: String, filters: [String: String] = [:], order: String? = nil) async throws -> [T] {
        var components = URLComponents(string: "\(baseURL)/\(table)")!
        var queryItems: [URLQueryItem] = []

        for (key, value) in filters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        if let order = order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        let (data, response) = try await makeRequest(url: components.url!, method: "GET")
        try validateResponse(response, data: data)
        return try decoder.decode([T].self, from: data)
    }

    // MARK: - Insert

    func insert<T: Codable>(_ table: String, record: T) async throws -> T {
        let body = try encoder.encode(record)
        let (data, response) = try await makeRequest(url: URL(string: "\(baseURL)/\(table)")!, method: "POST", body: body)
        try validateResponse(response, data: data)
        let results = try decoder.decode([T].self, from: data)
        guard let first = results.first else { throw SupabaseError.emptyResponse }
        return first
    }

    // MARK: - Update

    func update<T: Codable>(_ table: String, id: String, record: T) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/\(table)")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let body = try encoder.encode(record)
        let (data, response) = try await makeRequest(url: components.url!, method: "PATCH", body: body)
        try validateResponse(response, data: data)
        let results = try decoder.decode([T].self, from: data)
        guard let first = results.first else { throw SupabaseError.emptyResponse }
        return first
    }

    /// Actualiza campos específicos sin requerir el objeto completo
    func patch(_ table: String, id: String, fields: [String: Any]) async throws {
        var components = URLComponents(string: "\(baseURL)/\(table)")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let body = try JSONSerialization.data(withJSONObject: fields)
        let (data, response) = try await makeRequest(url: components.url!, method: "PATCH", body: body)
        try validateResponse(response, data: data)
    }

    // MARK: - Storage upload

    func uploadStorage(bucket: String, path: String, data: Data, contentType: String = "video/mp4") async throws -> String {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(bucket)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: responseData)
        return "\(SupabaseConfig.projectURL)/storage/v1/object/public/\(bucket)/\(path)"
    }

    // MARK: - Storage delete

    func deleteStorage(bucket: String, path: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(bucket)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Delete

    func delete(_ table: String, id: String) async throws {
        var components = URLComponents(string: "\(baseURL)/\(table)")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let (data, response) = try await makeRequest(url: components.url!, method: "DELETE")
        try validateResponse(response, data: data)
    }

    // MARK: - Test connection

    func testConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/social_posts?limit=1") else { return false }
        do {
            let (_, response) = try await makeRequest(url: url, method: "GET")
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(status)
        } catch {
            return false
        }
    }

    // MARK: - Private helpers

    private func makeRequest(url: URL, method: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body
        return try await URLSession.shared.data(for: request)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "sin detalle"
            throw SupabaseError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Errores

enum SupabaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "URL inválida"
        case .invalidResponse:  return "Respuesta no válida"
        case .emptyResponse:    return "Respuesta vacía"
        case .httpError(let code, let detail): return "Error HTTP \(code): \(detail)"
        }
    }
}
