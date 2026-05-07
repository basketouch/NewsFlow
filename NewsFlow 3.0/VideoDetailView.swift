import SwiftUI
import SafariServices

struct VideoDetailView: View {
    @State var item: VideoItem
    @ObservedObject var vm: VideosViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving              = false
    @State private var showPublishConfirm    = false
    @State private var showPublished         = false
    @State private var publishError: String? = nil
    @State private var safariURL: URL?       = nil
    @State private var showDeleteStorage     = false
    @State private var isDeletingStorage     = false
    @State private var isExpandingAI         = false
    @State private var aiError: String?      = nil
    @State private var videoType: VideoType  = .motivacional

    private var isPublished: Bool { item.status == "published" }

    var body: some View {
        Form {
            // Status
            Section {
                HStack {
                    Text("Estado")
                    Spacer()
                    StatusBadge(status: item.videoStatus)
                }
                if item.status == "error", let msg = item.errorMsg {
                    Text(msg).font(.caption).foregroundColor(.red)
                }
                if isPublished {
                    ForEach(item.selectedPlatforms, id: \.self) { platform in
                        if let urlStr = item.publishedUrls?[platform.rawValue],
                           let link = URL(string: urlStr) {
                            Button {
                                safariURL = link
                            } label: {
                                Label("Ver en \(platform.displayName)", systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }

            // Origen
            Section("Origen") {
                HStack {
                    Image(systemName: item.source == "drive" ? "externaldrive" : "photo")
                        .foregroundColor(.secondary)
                    Text(item.source == "drive" ? "Google Drive" : "Galería")
                    Spacer()
                    Text(item.displayName)
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }

            // Metadatos (solo lectura si está publicado)
            Section("Metadatos") {
                if isPublished {
                    LabeledContent("Título", value: item.title)
                    if !item.description.isEmpty {
                        LabeledContent("Descripción", value: item.description)
                    }
                    if let cat = item.category { LabeledContent("Categoría", value: cat) }
                } else {
                    TextField("Título", text: $item.title)
                    TextField("Descripción", text: $item.description, axis: .vertical)
                        .lineLimit(3...8)
                    Picker("Tipo de vídeo", selection: $videoType) {
                        ForEach(VideoType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    Button {
                        Task {
                            isExpandingAI = true
                            do {
                                item.description = try await OpenAIService.shared
                                    .mejorarDescripcionVideo(
                                        titulo: item.title,
                                        tipo: videoType,
                                        descripcion: item.description
                                    )
                            } catch {
                                aiError = error.localizedDescription
                            }
                            isExpandingAI = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isExpandingAI {
                                ProgressView().scaleEffect(0.75)
                                Text("Generando...").font(.caption)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Ampliar con IA").font(.caption)
                            }
                        }
                        .foregroundColor(.purple)
                    }
                    .disabled(isExpandingAI || item.title.isEmpty)
                    TextField("Categoría (ej: Education)", text: Binding(
                        get: { item.category ?? "" },
                        set: { item.category = $0.isEmpty ? nil : $0 }
                    ))
                }
            }

            // Hashtags
            if !item.hashtags.isEmpty || !isPublished {
                Section("Hashtags") {
                    if isPublished {
                        Text(item.hashtags.map { "#\($0)" }.joined(separator: " "))
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        TextField("#hashtag1 #hashtag2 ...", text: Binding(
                            get: { item.hashtags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " ") },
                            set: { item.hashtags = $0.components(separatedBy: " ").compactMap {
                                let h = $0.trimmingCharacters(in: .whitespaces)
                                return h.isEmpty ? nil : (h.hasPrefix("#") ? String(h.dropFirst()) : h)
                            }}
                        ))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                }
            }

            // Plataformas
            Section("Plataformas") {
                if isPublished {
                    ForEach(item.selectedPlatforms, id: \.self) { platform in
                        Label(platform.displayName, systemImage: platform.icon)
                            .foregroundColor(.secondary)
                    }
                } else {
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

            // Programación (solo para no publicados)
            if !isPublished {
                Section("Publicación") {
                    Toggle("Programar", isOn: Binding(
                        get: { item.scheduledAt != nil },
                        set: { item.scheduledAt = $0 ? Date().addingTimeInterval(3600) : nil }
                    ))
                    if let scheduled = item.scheduledAt {
                        DatePicker("Fecha", selection: Binding(
                            get: { scheduled },
                            set: { item.scheduledAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }

            // Borrar de Storage (solo galería publicada con archivo aún guardado)
            if isPublished && item.source == "gallery", let storageUrl = item.storageUrl {
                Section {
                    Button(role: .destructive) {
                        showDeleteStorage = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletingStorage {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Label("Borrar archivo de Storage", systemImage: "externaldrive.badge.minus")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeletingStorage)
                } footer: {
                    Text("El vídeo en YouTube no se verá afectado. Solo se libera el espacio en Supabase.")
                        .font(.caption)
                }
                .confirmationDialog("Borrar archivo de Storage", isPresented: $showDeleteStorage, titleVisibility: .visible) {
                    Button("Borrar", role: .destructive) {
                        Task {
                            isDeletingStorage = true
                            let path = storageUrl
                                .components(separatedBy: "/storage/v1/object/public/Videos/")
                                .last ?? ""
                            try? await SupabaseService.shared.deleteStorage(bucket: "Videos", path: path)
                            try? await SupabaseService.shared.patch("publish_queue", id: item.id, fields: ["storage_url": NSNull()])
                            item.storageUrl = nil
                            isDeletingStorage = false
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Se eliminará el archivo de Supabase Storage. El vídeo seguirá disponible en YouTube.")
                }
            }

            // Acciones
            if item.status == "pending" || item.status == "error" {
                Section {
                    Button {
                        isSaving = true
                        Task {
                            _ = await vm.update(item)
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving { ProgressView().scaleEffect(0.8) }
                            else { Text("Guardar cambios") }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)

                    Button {
                        showPublishConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isPublishing {
                                ProgressView().scaleEffect(0.8).tint(.white)
                            } else {
                                Label(
                                    item.scheduledAt != nil ? "Programar publicación" : "Publicar ahora",
                                    systemImage: item.scheduledAt != nil ? "calendar.badge.clock" : "paperplane.fill"
                                )
                                .font(.headline)
                                .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(item.platforms.isEmpty ? Color.gray : (item.scheduledAt != nil ? Color.orange : Color.blue))
                        .cornerRadius(8)
                    }
                    .disabled(item.platforms.isEmpty || vm.isPublishing || isSaving)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .navigationTitle(item.title.isEmpty ? "Vídeo" : item.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            item.scheduledAt != nil ? "Programar publicación" : "Publicar ahora",
            isPresented: $showPublishConfirm,
            titleVisibility: .visible
        ) {
            Button(item.scheduledAt != nil ? "Programar" : "Publicar") {
                Task {
                    isSaving = true
                    let ok = await vm.update(item)
                    if ok {
                        await vm.markReady(item)
                        if vm.error == nil {
                            showPublished = true
                        } else {
                            publishError = vm.error
                        }
                    } else {
                        publishError = vm.error ?? "No se pudo guardar el vídeo"
                    }
                    isSaving = false
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .alert(item.scheduledAt != nil ? "Publicación programada" : "Enviado a publicar",
               isPresented: $showPublished) {
            Button("OK") { dismiss() }
        } message: {
            Text(successMessage)
        }
        .alert("Error al publicar", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("OK") { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        .alert("Error IA", isPresented: Binding(
            get: { aiError != nil },
            set: { if !$0 { aiError = nil } }
        )) {
            Button("OK") { aiError = nil }
        } message: {
            Text(aiError ?? "")
        }
        .sheet(item: $safariURL) { url in
            SFSafariViewControllerWrapper(url: url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Computed messages

    private var confirmMessage: String {
        if let scheduled = item.scheduledAt {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = Locale(identifier: "es_ES")
            return "Se publicará el \(f.string(from: scheduled))"
        }
        return "n8n procesará la publicación en los próximos minutos."
    }

    private var successMessage: String {
        if let scheduled = item.scheduledAt {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = Locale(identifier: "es_ES")
            return "«\(item.title)» se publicará el \(f.string(from: scheduled))"
        }
        return "n8n publicará «\(item.title)» en los próximos minutos."
    }
}

// MARK: - Safari in-app

struct SFSafariViewControllerWrapper: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor.systemBlue
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
