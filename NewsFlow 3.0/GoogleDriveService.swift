import Foundation
import GoogleSignIn

// MARK: - Modelos Drive API v3

struct DriveFile: Identifiable, Codable {
    let id: String
    let name: String
    let mimeType: String
    let thumbnailLink: String?
    let size: String?
    let modifiedTime: String?

    var isFolder: Bool { mimeType == "application/vnd.google-apps.folder" }
    var isVideo: Bool  { mimeType.hasPrefix("video/") }

    var sizeFormatted: String? {
        guard let s = size, let bytes = Int64(s) else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct DriveFilesResponse: Codable {
    let files: [DriveFile]
    let nextPageToken: String?
}

// MARK: - Errores

enum DriveError: LocalizedError {
    case notSignedIn
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notSignedIn:        return "No has iniciado sesión en Google"
        case .serverError(let c): return "Error del servidor (\(c))"
        case .decodingError:      return "No se pudo leer la respuesta de Drive"
        }
    }
}

// MARK: - Servicio

@MainActor
class GoogleDriveService: ObservableObject {
    static let shared = GoogleDriveService()

    @Published var isSignedIn = false

    private init() {
        isSignedIn = GIDSignIn.sharedInstance.currentUser != nil
    }

    // MARK: - Auth

    func restoreSession() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
            Task { @MainActor in
                self.isSignedIn = user != nil
            }
        }
    }

    func signIn() async throws {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw DriveError.notSignedIn
        }

        // Configurar el Client ID explícitamente (respaldo al Info.plist)
        let config = GIDConfiguration(
            clientID: "44411976341-gkq0phmqi5trkql1db8eqsos5gbfjmsh.apps.googleusercontent.com"
        )
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: root,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/drive.readonly"]
        )
        _ = result.user
        isSignedIn = true
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
    }

    // MARK: - Descargar archivo

    func downloadFile(id: String) async throws -> Data {
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw DriveError.notSignedIn }
        try await user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString

        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(id)?alt=media")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DriveError.serverError(0) }
        guard (200..<300).contains(http.statusCode) else { throw DriveError.serverError(http.statusCode) }
        return data
    }

    // MARK: - Listar archivos

    func listFiles(inFolder folderId: String = "root") async throws -> [DriveFile] {
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw DriveError.notSignedIn }

        try await user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString

        let q = "'\(folderId)' in parents and trashed = false and (mimeType = 'application/vnd.google-apps.folder' or mimeType contains 'video/')"
        var comps = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        comps.queryItems = [
            URLQueryItem(name: "q",        value: q),
            URLQueryItem(name: "fields",   value: "files(id,name,mimeType,thumbnailLink,size,modifiedTime),nextPageToken"),
            URLQueryItem(name: "orderBy",  value: "folder,name"),
            URLQueryItem(name: "pageSize", value: "200")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DriveError.serverError(0) }
        guard (200..<300).contains(http.statusCode) else { throw DriveError.serverError(http.statusCode) }

        guard let decoded = try? JSONDecoder().decode(DriveFilesResponse.self, from: data) else {
            throw DriveError.decodingError
        }
        return decoded.files
    }
}
