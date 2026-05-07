import SwiftUI

// MARK: - Drive Picker

struct DrivePickerView: View {
    @StateObject private var drive = GoogleDriveService.shared
    @Environment(\.dismiss) private var dismiss

    let onSelect: (DriveFile) -> Void

    @State private var folderStack: [(id: String, name: String)] = DrivePickerView.loadFolderStack()
    @State private var files:     [DriveFile] = []
    @State private var isLoading  = false
    @State private var errorMsg:  String?

    private var currentFolderId:   String { folderStack.last?.id   ?? "root"     }
    private var currentFolderName: String { folderStack.last?.name ?? "Mi Drive" }

    // MARK: - Persistencia de la última carpeta

    private static let stackKey = "drive_picker_folder_stack"

    private static func loadFolderStack() -> [(id: String, name: String)] {
        guard let saved = UserDefaults.standard.array(forKey: stackKey) as? [[String: String]] else {
            return [("root", "Mi Drive")]
        }
        let stack = saved.compactMap { dict -> (id: String, name: String)? in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return (id: id, name: name)
        }
        return stack.isEmpty ? [("root", "Mi Drive")] : stack
    }

    private func saveFolderStack() {
        let encoded = folderStack.map { ["id": $0.id, "name": $0.name] }
        UserDefaults.standard.set(encoded, forKey: Self.stackKey)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !drive.isSignedIn {
                    signInView
                } else if isLoading && files.isEmpty {
                    ProgressView("Cargando Drive…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMsg {
                    errorView(err)
                } else if files.isEmpty {
                    emptyView
                } else {
                    fileList
                }
            }
            .navigationTitle(currentFolderName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onAppear {
            if drive.isSignedIn { Task { await load() } }
        }
    }

    // MARK: Sign-In

    private var signInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.fill.badge.person.crop")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("Conectar Google Drive")
                .font(.title2.weight(.bold))
            Text("Inicia sesión para explorar tus vídeos guardados en Drive")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await signIn() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                    Text("Iniciar sesión con Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(msg)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Reintentar") { Task { await load() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Carpeta vacía")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: File List

    private var fileList: some View {
        List(files) { file in
            Button {
                if file.isFolder {
                    folderStack.append((id: file.id, name: file.name))
                    saveFolderStack()
                    files = []
                    Task { await load() }
                } else {
                    onSelect(file)
                    dismiss()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: file.isFolder ? "folder.fill" : "video.fill")
                        .font(.title3)
                        .foregroundColor(file.isFolder ? .yellow : .blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        if let sz = file.sizeFormatted {
                            Text(sz).font(.caption).foregroundColor(.secondary)
                        }
                    }

                    if file.isFolder {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if folderStack.count > 1 {
                Button {
                    folderStack.removeLast()
                    saveFolderStack()
                    files = []
                    Task { await load() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(folderStack.dropLast().last?.name ?? "Mi Drive")
                    }
                }
            } else {
                Button("Cancelar") { dismiss() }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if drive.isSignedIn {
                Menu {
                    Button {
                        drive.signOut()
                        Task { await signIn() }
                    } label: {
                        Label("Cambiar cuenta", systemImage: "person.2.circle")
                    }
                    Button(role: .destructive) {
                        drive.signOut()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
    }

    // MARK: Helpers

    private func load() async {
        isLoading = true
        errorMsg  = nil
        do {
            files = try await drive.listFiles(inFolder: currentFolderId)
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func signIn() async {
        do {
            try await drive.signIn()
            await load()
        } catch {
            errorMsg = "No se pudo iniciar sesión: \(error.localizedDescription)"
        }
    }
}
