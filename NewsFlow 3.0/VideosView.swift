import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Vista principal

struct VideosView: View {
    @StateObject private var vm = VideosViewModel.shared
    @State private var showNewVideo     = false
    @State private var showDrivePicker  = false
    @State private var showSourcePicker = false
    @State private var itemToDelete: VideoItem? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.videos.isEmpty {
                    ProgressView("Cargando vídeos...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.error, vm.videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Error al cargar").font(.headline)
                        Text(err).font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                        Button("Reintentar") { Task { await vm.loadVideos() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.videos.isEmpty {
                    emptyState
                } else {
                    videoList
                }
            }
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await vm.loadVideos() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSourcePicker = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Añadir vídeo", isPresented: $showSourcePicker) {
                Button("Desde Google Drive") { showDrivePicker = true }
                Button("Desde Galería")      { showNewVideo = true    }
                Button("Cancelar", role: .cancel) {}
            }
            .confirmationDialog(
                itemToDelete?.status == "published" ? "Eliminar del historial" : "Eliminar vídeo",
                isPresented: Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) {
                    if let item = itemToDelete {
                        Task { await vm.delete(item) }
                    }
                    itemToDelete = nil
                }
                Button("Cancelar", role: .cancel) { itemToDelete = nil }
            } message: {
                if itemToDelete?.status == "published" {
                    Text("Se eliminará del historial de NewsFlow. El vídeo en YouTube no se verá afectado.")
                } else {
                    Text("Se eliminará de la cola de publicación.")
                }
            }
            .sheet(isPresented: $showDrivePicker) {
                VideoNewView(vm: vm, source: "drive")
            }
            .sheet(isPresented: $showNewVideo) {
                VideoNewView(vm: vm, source: "gallery")
            }
        }
        .onAppear {
            if vm.videos.isEmpty { Task { await vm.loadVideos() } }
        }
    }

    // MARK: Lista

    private var videoList: some View {
        List {
            if !vm.withErrors.isEmpty {
                Section {
                    ForEach(vm.withErrors) { item in
                        videoRow(item)
                    }
                } header: {
                    Label("Errores", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }

            if !vm.pending.isEmpty {
                Section {
                    ForEach(vm.pending) { item in
                        videoRow(item)
                    }
                } header: {
                    Label("Pendientes", systemImage: "clock")
                        .foregroundColor(.orange)
                }
            }

            if !vm.published.isEmpty {
                Section {
                    ForEach(vm.published) { item in
                        publishedRow(item)
                    }
                } header: {
                    Label("Publicados", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.loadVideos() }
    }

    // Fila para vídeos pendientes/en proceso
    @ViewBuilder
    private func videoRow(_ item: VideoItem) -> some View {
        NavigationLink {
            VideoDetailView(item: item, vm: vm)
        } label: {
            VideoRow(item: item)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                itemToDelete = item
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // Fila para vídeos publicados (solo lectura + link a plataforma)
    @ViewBuilder
    private func publishedRow(_ item: VideoItem) -> some View {
        NavigationLink {
            VideoDetailView(item: item, vm: vm)
        } label: {
            VideoRow(item: item)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                itemToDelete = item
            } label: {
                Label("Eliminar historial", systemImage: "trash")
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Sin vídeos").font(.headline).foregroundColor(.secondary)
            Text("Añade un vídeo desde Drive o tu Galería")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button { showSourcePicker = true } label: {
                Label("Añadir vídeo", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Fila de vídeo

struct VideoRow: View {
    let item: VideoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                StatusBadge(status: item.videoStatus)
                Spacer()
                Text(item.formattedDate)
                    .font(.caption2).foregroundColor(.secondary)
            }

            Text(item.title.isEmpty ? item.displayName : item.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)

            if !item.description.isEmpty {
                Text(item.description)
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            HStack(spacing: 6) {
                ForEach(item.selectedPlatforms, id: \.self) { platform in
                    Image(systemName: platform.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Badge de status

struct StatusBadge: View {
    let status: VideoStatus

    private var color: Color {
        switch status {
        case .pending:    return .gray
        case .ready:      return .blue
        case .publishing: return .orange
        case .published:  return .green
        case .error:      return .red
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Formulario nuevo vídeo

struct VideoNewView: View {
    @ObservedObject var vm: VideosViewModel
    let source: String
    @Environment(\.dismiss) private var dismiss

    @State private var item = VideoItem.empty()
    @State private var selectedDriveFile: DriveFile? = nil
    @State private var showDrivePicker   = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isSaving    = false
    @State private var uploadStep  = ""
    @State private var errorAlert: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if source == "drive" {
                    Section("Google Drive") {
                        Button {
                            showDrivePicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedDriveFile == nil ? "externaldrive" : "checkmark.circle.fill")
                                    .foregroundColor(selectedDriveFile == nil ? .secondary : .green)
                                Text(selectedDriveFile?.name ?? "Explorar Drive…")
                                    .foregroundColor(selectedDriveFile == nil ? .secondary : .primary)
                                    .lineLimit(1)
                            }
                        }
                        .sheet(isPresented: $showDrivePicker) {
                            DrivePickerView { file in
                                selectedDriveFile  = file
                                if item.title.isEmpty { item.title = file.name }
                            }
                        }
                    }
                } else {
                    Section("Galería") {
                        PhotosPicker(selection: $selectedPhoto, matching: .videos) {
                            Label(
                                selectedPhoto == nil ? "Seleccionar vídeo" : "Vídeo seleccionado ✓",
                                systemImage: selectedPhoto == nil ? "photo.on.rectangle" : "checkmark.circle.fill"
                            )
                        }
                    }
                }

                metadataSection
            }
            .navigationTitle("Nuevo vídeo")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { errorAlert != nil },
                set: { if !$0 { errorAlert = nil } }
            )) {
                Button("OK") { errorAlert = nil }
            } message: {
                Text(errorAlert ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.8)
                            Text(uploadStep).font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        Button("Añadir") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
        }
        .onAppear { item = VideoItem.empty(source: source) }
    }

    private var canSave: Bool {
        if source == "drive" { return selectedDriveFile != nil }
        return selectedPhoto != nil
    }

    @ViewBuilder
    private var metadataSection: some View {
        Section("Metadatos") {
            TextField("Título", text: $item.title)
            TextField("Descripción", text: $item.description, axis: .vertical)
                .lineLimit(3...6)
            TextField("Hashtags (separados por espacios)", text: Binding(
                get: { item.hashtags.joined(separator: " ") },
                set: { item.hashtags = $0.components(separatedBy: " ").filter { !$0.isEmpty } }
            ))
        }

        Section("Plataformas") {
            ForEach(VideoPlatform.allCases, id: \.self) { platform in
                Toggle(platform.displayName, isOn: Binding(
                    get: { item.platforms.contains(platform.rawValue) },
                    set: { on in
                        if on { item.platforms.append(platform.rawValue) }
                        else  { item.platforms.removeAll { $0 == platform.rawValue } }
                    }
                ))
            }
        }
    }

    private func save() async {
        isSaving = true
        item.source        = source
        item.driveFileId   = selectedDriveFile?.id
        item.driveFileName = selectedDriveFile?.name

        // Galería: subir vídeo a Supabase Storage antes de crear el registro
        if source == "gallery", let photo = selectedPhoto {
            uploadStep = "Cargando..."
            do {
                guard let transferable = try await photo.loadTransferable(type: VideoTransferable.self) else {
                    errorAlert = "El vídeo devolvió nil al cargarse"
                    isSaving = false
                    return
                }
                uploadStep = "Subiendo (\(transferable.data.count / 1_048_576) MB)..."
                let filename = "\(item.id).mp4"
                let storageURL = try await SupabaseService.shared.uploadStorage(
                    bucket: "Videos", path: filename, data: transferable.data
                )
                item.storageUrl    = storageURL
                item.driveFileName = filename
            } catch {
                errorAlert = "Error galería: \(error.localizedDescription)"
                isSaving = false
                return
            }
        }

        uploadStep = "Guardando..."
        let ok = await vm.create(item)
        isSaving = false
        uploadStep = ""
        if ok {
            dismiss()
        } else {
            errorAlert = vm.error ?? "Error desconocido al guardar"
        }
    }
}

// MARK: - Transferable para vídeos de galería

struct VideoTransferable: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            VideoTransferable(data: data)
        }
    }
}
