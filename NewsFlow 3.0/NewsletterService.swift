import Foundation

class NewsletterService {
    static let shared = NewsletterService()
    private init() {}

    // MARK: - GET archivo desde GitHub (via api/github.js)

    func fetchDraft() async throws -> NewsletterDraft {
        let data = try await getFile(NewsletterConfig.draftFile)
        return try JSONDecoder().decode(NewsletterDraft.self, from: data)
    }

    /// Devuelve el SHA del newsletter.html actual (necesario para el PUT)
    func fetchNewsletterSHA() async throws -> String {
        let (_, sha) = try await getFileWithSHA(NewsletterConfig.publishFile)
        return sha
    }

    // MARK: - Publicar: escribe newsletter.html (latest) + newsletters/NNN.html (archivo)

    func publish(html: String, sha: String, edicion: String, titulo: String, fecha: String, tags: [String]) async throws -> (url: String, edicionesWarning: String?) {
        // 1. Sobreescribir newsletter.html — OBLIGATORIO
        try await putFile(
            file: NewsletterConfig.publishFile,
            html: html,
            sha: sha,
            message: "Newsletter #\(edicion) publicado desde NewsFlow iOS"
        )

        // 2. Crear/actualizar newsletters/NNN.html
        let archiveFile = "newsletters/\(edicion).html"
        let archiveSHA = (try? await getFileWithSHA(archiveFile).1) ?? ""
        try? await putFile(
            file: archiveFile,
            html: html,
            sha: archiveSHA,
            message: "Archivo newsletter #\(edicion)"
        )

        // 3. Actualizar ediciones.json para que aparezca en /archivo
        var edicionesWarning: String? = nil
        do {
            try await updateEdiciones(edicion: edicion, titulo: titulo, fecha: fecha, tags: tags)
        } catch {
            edicionesWarning = "ediciones.json no actualizado: \(error.localizedDescription)"
        }

        let url = "\(NewsletterConfig.siteURL)/newsletters/\(edicion)"
        return (url: url, edicionesWarning: edicionesWarning)
    }

    // MARK: - Actualizar ediciones.json

    private func updateEdiciones(edicion: String, titulo: String, fecha: String, tags: [String]) async throws {
        let (data, sha) = try await getFileWithSHA("ediciones.json")

        guard let parsedJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NewsletterError.httpError(0, "ediciones.json no es un objeto JSON válido. Data: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "??")")
        }
        var json = parsedJSON
        guard var ediciones = json["ediciones"] as? [[String: Any]] else {
            throw NewsletterError.httpError(0, "ediciones.json no tiene campo 'ediciones'. Claves: \(parsedJSON.keys.joined(separator: ", "))")
        }

        let numEdicion = Int(edicion) ?? 0
        let href = "/newsletters/\(edicion)"

        // Eliminar entrada anterior con el mismo num o href
        ediciones.removeAll { ($0["num"] as? Int) == numEdicion || ($0["href"] as? String) == href }

        // Añadir nueva entrada
        let nueva: [String: Any] = [
            "num":    numEdicion,
            "titulo": titulo,
            "fecha":  fechaISO(from: fecha),
            "tags":   tags,
            "href":   href
        ]
        ediciones.append(nueva)

        // Ordenar por num descendente
        ediciones.sort { ($0["num"] as? Int ?? 0) > ($1["num"] as? Int ?? 0) }

        json["ediciones"] = ediciones

        guard let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let newContent = String(data: newData, encoding: .utf8) else {
            throw NewsletterError.httpError(0, "No se pudo serializar el JSON de ediciones")
        }

        try await putFile(file: "ediciones.json", html: newContent, sha: sha,
                          message: "Añadir edición #\(edicion) al archivo")
    }

    /// Convierte "16 Abril 2026" → "2026-04-16"
    private func fechaISO(from fecha: String) -> String {
        let meses = ["enero":1,"febrero":2,"marzo":3,"abril":4,"mayo":5,"junio":6,
                     "julio":7,"agosto":8,"septiembre":9,"octubre":10,"noviembre":11,"diciembre":12]
        let parts = fecha.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
        guard parts.count == 3,
              let dia = Int(parts[0]),
              let mes = meses[parts[1]],
              let anyo = Int(parts[2]) else { return fecha }
        return String(format: "%04d-%02d-%02d", anyo, mes, dia)
    }

    // MARK: - Helpers privados

    private func putFile(file: String, html: String, sha: String, message: String) async throws {
        guard let url = URL(string: NewsletterConfig.apiURL) else {
            throw NewsletterError.invalidURL
        }

        // api/github.js espera el contenido en texto plano — él mismo hace la codificación base64
        var body: [String: Any] = [
            "file":    file,
            "content": html,
            "message": message
        ]
        if !sha.isEmpty { body["sha"] = sha }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.setValue(NewsletterConfig.authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("https://insidelife.club", forHTTPHeaderField: "Origin")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw NewsletterError.httpError(statusCode, "PUT \(file) → \(detail)")
        }
    }

    private func getFile(_ file: String) async throws -> Data {
        let (data, _) = try await getFileWithSHA(file)
        return data
    }

    private func getFileWithSHA(_ file: String) async throws -> (Data, String) {
        var components = URLComponents(string: NewsletterConfig.apiURL)!
        components.queryItems = [URLQueryItem(name: "file", value: file)]

        var request = URLRequest(url: components.url!)
        request.setValue(NewsletterConfig.authHeader,   forHTTPHeaderField: "Authorization")
        request.setValue("https://insidelife.club",     forHTTPHeaderField: "Origin")
        request.setValue("application/json",            forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NewsletterError.httpError(statusCode, "GET \(file) → \(body)")
        }

        let raw = String(data: data, encoding: .utf8) ?? "sin datos"

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NewsletterError.httpError(0, "No es JSON válido. Respuesta: \(raw.prefix(300))")
        }

        guard let b64 = json["content"] as? String else {
            let keys = json.keys.joined(separator: ", ")
            throw NewsletterError.httpError(0, "Sin campo 'content'. Claves: \(keys). Body: \(raw.prefix(300))")
        }

        guard let sha = json["sha"] as? String else {
            throw NewsletterError.httpError(0, "Sin campo 'sha'. Body: \(raw.prefix(300))")
        }

        // api/github.js puede devolver el contenido ya decodificado (string) o en base64
        let decoded: Data
        let cleanB64 = b64.replacingOccurrences(of: "\n", with: "")
        if let b64Data = Data(base64Encoded: cleanB64) {
            decoded = b64Data
        } else if let plainData = b64.data(using: .utf8) {
            decoded = plainData
        } else {
            throw NewsletterError.httpError(0, "No se pudo procesar el contenido del servidor")
        }

        return (decoded, sha)
    }
}

// MARK: - Errores

enum NewsletterError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "URL inválida"
        case .invalidResponse:          return "Respuesta no válida del servidor"
        case .httpError(let c, let d):  return "Error \(c): \(d)"
        }
    }
}
