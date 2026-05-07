import SwiftUI
import PhotosUI

struct EditPostView: View {
    @ObservedObject var viewModel: SocialPostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedContent: String = ""
    @State private var redSocialSeleccionada: SocialNetwork = .linkedin
    @State private var fechaPublicacion: Date = Date()
    @State private var mediaTypeSeleccionado: MediaType = .texto
    @State private var mediaUrlTexto: String = ""
    @State private var mediaFileName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDrivePicker = false
    @State private var isUploadingMedia = false
    @State private var mediaUploadError: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Guardando cambios...")
                        .padding()
                } else if let post = viewModel.currentEditPost {
                    Form {
                        Section(header: Text("Editar publicación")) {
                            TextField("Texto de la publicación", text: $editedContent, axis: .vertical)
                                .lineLimit(5...15)
                                .padding(.vertical, 8)
                        }
                        
                        Section(header: Text("Red social")) {
                            Picker("Red social", selection: $redSocialSeleccionada) {
                                Text("LinkedIn").tag(SocialNetwork.linkedin)
                                Text("X").tag(SocialNetwork.twitter)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Section(header: Text("Media")) {
                            Picker("Tipo", selection: $mediaTypeSeleccionado) {
                                ForEach(MediaType.allCases) { type in
                                    Label(type.label, systemImage: type.iconName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: mediaTypeSeleccionado) { _ in
                                mediaUrlTexto = ""; mediaFileName = ""; mediaUploadError = nil
                            }

                            if mediaTypeSeleccionado != .texto {
                                if isUploadingMedia {
                                    HStack {
                                        ProgressView()
                                        Text("Subiendo archivo…")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                } else if !mediaUrlTexto.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: mediaTypeSeleccionado.iconName)
                                            .foregroundColor(.purple)
                                        Text(mediaFileName.isEmpty ? "Archivo listo" : mediaFileName)
                                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        Spacer()
                                        Button { mediaUrlTexto = ""; mediaFileName = "" } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                        }.buttonStyle(.plain)
                                    }
                                } else {
                                    HStack(spacing: 12) {
                                        PhotosPicker(
                                            selection: $selectedPhotoItem,
                                            matching: mediaTypeSeleccionado == .imagen ? .images : .videos
                                        ) {
                                            Label("Galería", systemImage: "photo.on.rectangle")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)

                                        if mediaTypeSeleccionado == .video {
                                            Button { showDrivePicker = true } label: {
                                                Label("Drive", systemImage: "externaldrive.fill")
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }

                                if let err = mediaUploadError {
                                    Text(err).font(.caption).foregroundColor(.red)
                                }
                            }
                        }

                        Section(header: Text("Fecha programada")) {
                            DatePicker(
                                "Fecha de publicación",
                                selection: $fechaPublicacion,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                        }
                        
                        Section {
                            Button {
                                Task {
                                    await viewModel.saveEdit(
                                        newContent: editedContent,
                                        redSocial: redSocialSeleccionada,
                                        fecha: fechaPublicacion,
                                        mediaUrl: mediaUrlTexto.isEmpty ? nil : mediaUrlTexto,
                                        mediaType: mediaTypeSeleccionado
                                    )
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Guardar cambios")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.vertical, 4)
                            
                            Button {
                                viewModel.cancelEditing()
                                dismiss()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Cancelar")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onAppear {
                        editedContent = post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido
                        redSocialSeleccionada = post.redSocialEnum
                        fechaPublicacion = post.fecha
                        mediaTypeSeleccionado = post.mediaTypeEnum
                        mediaUrlTexto = post.mediaUrl ?? ""
                    }
                } else {
                    Text("No se ha seleccionado ninguna publicación para editar")
                        .padding()
                    
                    Button("Cerrar") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
            .navigationTitle("Editar publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        viewModel.cancelEditing()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDrivePicker) {
                DrivePickerView { file in
                    Task { await uploadFromDrive(file) }
                }
            }
            .onChange(of: selectedPhotoItem) { item in
                guard let item else { return }
                Task { await uploadFromGallery(item) }
            }
        }
    }

    // MARK: - Upload helpers

    private func uploadFromGallery(_ item: PhotosPickerItem) async {
        isUploadingMedia = true
        mediaUploadError = nil
        defer { isUploadingMedia = false; selectedPhotoItem = nil }

        do {
            if mediaTypeSeleccionado == .imagen {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    mediaUploadError = "No se pudo leer la imagen"; return
                }
                let filename = "\(UUID().uuidString).jpg"
                mediaUrlTexto = try await SupabaseService.shared.uploadStorage(
                    bucket: "social-media", path: "images/\(filename)",
                    data: data, contentType: "image/jpeg"
                )
                mediaFileName = filename
            } else {
                guard let video = try await item.loadTransferable(type: VideoTransferable.self) else {
                    mediaUploadError = "No se pudo leer el vídeo"; return
                }
                let filename = "\(UUID().uuidString).mov"
                mediaUrlTexto = try await SupabaseService.shared.uploadStorage(
                    bucket: "social-media", path: "videos/\(filename)",
                    data: video.data, contentType: "video/quicktime"
                )
                mediaFileName = filename
            }
        } catch {
            mediaUploadError = "Error al subir: \(error.localizedDescription)"
        }
    }

    private func uploadFromDrive(_ file: DriveFile) async {
        isUploadingMedia = true
        mediaUploadError = nil
        defer { isUploadingMedia = false }

        do {
            let data = try await GoogleDriveService.shared.downloadFile(id: file.id)
            let ext  = file.name.components(separatedBy: ".").last ?? "mp4"
            let filename = "\(UUID().uuidString).\(ext)"
            mediaUrlTexto = try await SupabaseService.shared.uploadStorage(
                bucket: "social-media", path: "videos/\(filename)",
                data: data, contentType: "video/mp4"
            )
            mediaFileName = file.name
        } catch {
            mediaUploadError = "Error al subir desde Drive: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let viewModel = SocialPostsViewModel.shared
    viewModel.currentEditPost = SocialPost.nuevo(
        texto: "Texto original para editar",
        redSocial: .linkedin,
        fecha: Date().addingTimeInterval(3600),
        tematica: "IA",
        objetivo: "Informar"
    )
    viewModel.isEditingPost = true
    return EditPostView(viewModel: viewModel)
} 