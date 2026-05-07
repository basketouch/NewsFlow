import Foundation
import SwiftUI

// MARK: - Payload para INSERT (sin campos auto-generados)

private struct VideoItemCreate: Codable {
    var title: String
    var description: String
    var hashtags: [String]
    var category: String?
    var source: String
    var driveFileId: String?
    var driveFileName: String?
    var storageUrl: String?
    var platforms: [String]
    var scheduledAt: Date?
    var status: String

    enum CodingKeys: String, CodingKey {
        case title, description, hashtags, category, source, platforms, status
        case driveFileId   = "drive_file_id"
        case driveFileName = "drive_file_name"
        case storageUrl    = "storage_url"
        case scheduledAt   = "scheduled_at"
    }
}

// MARK: - ViewModel

@MainActor
class VideosViewModel: ObservableObject {
    static let shared = VideosViewModel()

    @Published var videos: [VideoItem] = []
    @Published var isLoading    = false
    @Published var isPublishing = false
    @Published var error: String? = nil

    private let db    = SupabaseService.shared
    private let table = "publish_queue"
    private var pollingTask: Task<Void, Never>?

    private init() {
        startPolling()
    }

    // MARK: - Polling de estado

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                let hasActive = videos.contains { $0.status == "ready" || $0.status == "publishing" }
                if hasActive {
                    await loadVideos()
                }
            }
        }
    }

    // MARK: - Carga

    func loadVideos() async {
        isLoading = true
        error = nil
        do {
            let fetched: [VideoItem] = try await db.fetch(table, order: "created_at.desc")
            videos = fetched
        } catch {
            self.error = "No se pudieron cargar los vídeos: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Crear

    func create(_ item: VideoItem) async -> Bool {
        do {
            let payload = VideoItemCreate(
                title:         item.title,
                description:   item.description,
                hashtags:      item.hashtags,
                category:      item.category,
                source:        item.source,
                driveFileId:   item.driveFileId,
                driveFileName: item.driveFileName,
                storageUrl:    item.storageUrl,
                platforms:     item.platforms,
                scheduledAt:   item.scheduledAt,
                status:        "pending"
            )
            let _: VideoItemCreate = try await db.insert(table, record: payload)
            await loadVideos()
            return true
        } catch {
            self.error = "No se pudo crear el vídeo: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Actualizar metadatos

    func update(_ item: VideoItem) async -> Bool {
        do {
            var fields: [String: Any] = [
                "title":       item.title,
                "description": item.description,
                "hashtags":    item.hashtags,
                "platforms":   item.platforms
            ]
            if let cat   = item.category    { fields["category"]     = cat  }
            if let sched = item.scheduledAt { fields["scheduled_at"] = ISO8601DateFormatter().string(from: sched) }

            try await db.patch(table, id: item.id, fields: fields)
            if let idx = videos.firstIndex(where: { $0.id == item.id }) {
                videos[idx] = item
            }
            return true
        } catch {
            self.error = "No se pudo actualizar: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Marcar como listo → n8n publica

    func markReady(_ item: VideoItem) async {
        isPublishing = true
        error = nil
        do {
            try await db.patch(table, id: item.id, fields: ["status": "ready"])
            if let idx = videos.firstIndex(where: { $0.id == item.id }) {
                videos[idx].status = "ready"
            }
        } catch {
            self.error = "No se pudo marcar como listo: \(error.localizedDescription)"
        }
        isPublishing = false
    }

    // MARK: - Eliminar

    func delete(_ item: VideoItem) async {
        do {
            try await db.delete(table, id: item.id)
            videos.removeAll { $0.id == item.id }
        } catch {
            self.error = "No se pudo eliminar: \(error.localizedDescription)"
        }
    }

    // MARK: - Filtros

    var pending: [VideoItem] {
        videos.filter { $0.status == "pending" || $0.status == "ready" || $0.status == "publishing" }
    }

    var published: [VideoItem] {
        videos.filter { $0.status == "published" }
    }

    var withErrors: [VideoItem] {
        videos.filter { $0.status == "error" }
    }
}
