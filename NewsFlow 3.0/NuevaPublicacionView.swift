import SwiftUI
import PhotosUI

struct NuevaPublicacionView: View {
    @ObservedObject var viewModel: SocialPostsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Nuevo: texto inicial opcional para rellenar el campo
    var textoInicial: String? = nil
    var tematicaSugerida: String? = nil
    var objetivoSugerido: String? = nil
    
    // Nuevo: datos de web externa
    var webURL: String? = nil
    var webTitle: String? = nil
    var isFromWeb: Bool = false
    
    // Opciones predefinidas
    let tematicas = ["IA", "Emprendimiento", "Marketing", "Deporte", "Tecnología", "Negocios", "Liderazgo", "Innovación"]
    let objetivos = ["Interesante", "Venta", "Hype", "Educar", "Reflexión", "Motivar", "Informar", "Divertir", "Promocionar"]
    
    // Campos del formulario
    @State private var textoSinFormato: String = ""
    @State private var tematicaSeleccionada: String = "IA"
    @State private var objetivoSeleccionado: String = "Interesante"
    @State private var redSocialSeleccionada: SocialNetwork = .linkedin
    @State private var fechaPublicacion: Date = Date().addingTimeInterval(24 * 60 * 60) // 24 horas desde ahora
    @State private var mediaTypeSeleccionado: MediaType = .texto
    @State private var mediaUrlTexto: String = ""
    @State private var mediaFileName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDrivePicker = false
    @State private var isUploadingMedia = false
    @State private var mediaUploadError: String? = nil
    
    init(viewModel: SocialPostsViewModel, 
         textoInicial: String? = nil, 
         tematicaSugerida: String? = nil, 
         objetivoSugerido: String? = nil,
         webURL: String? = nil,
         webTitle: String? = nil,
         isFromWeb: Bool = false) {
        self.viewModel = viewModel
        self.textoInicial = textoInicial
        self.tematicaSugerida = tematicaSugerida
        self.objetivoSugerido = objetivoSugerido
        self.webURL = webURL
        self.webTitle = webTitle
        self.isFromWeb = isFromWeb
        
        // Inicializar el campo de texto si se proporciona textoInicial
        _textoSinFormato = State(initialValue: textoInicial ?? "")
        
        // Inicializar temática sugerida si se proporciona y es válida
        let tematicaInicial = tematicaSugerida ?? "IA"
        _tematicaSeleccionada = State(initialValue: tematicas.contains(tematicaInicial) ? tematicaInicial : "IA")
        
        // Inicializar objetivo sugerido si se proporciona y es válido
        let objetivoInicial = objetivoSugerido ?? "Interesante"
        _objetivoSeleccionado = State(initialValue: objetivos.contains(objetivoInicial) ? objetivoInicial : "Interesante")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Sección informativa si los datos provienen de RSS o Web
                if textoInicial != nil || isFromWeb {
                    Section {
                        HStack {
                            Image(systemName: isFromWeb ? "globe" : "dot.radiowaves.up.forward")
                                .foregroundColor(isFromWeb ? .blue : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isFromWeb ? "Datos de web externa" : "Datos de noticia RSS")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(isFromWeb ? 
                                     "Los campos han sido pre-rellenados con información de la web visitada. Puedes editarlos antes de guardar." :
                                     "Los campos han sido pre-rellenados con información de la noticia seleccionada. Puedes editarlos antes de guardar.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Sección de información de web (solo si viene de web)
                if isFromWeb, let webTitle = webTitle, let webURL = webURL {
                    Section(header: Text("Información de la Web")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Título:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(webTitle)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("URL:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(webURL)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                    }
                }
                
                // Sección de texto
                Section(header: Text("Contenido")) {
                    TextEditor(text: $textoSinFormato)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if textoSinFormato.isEmpty {
                                    Text("Escribe aquí el contenido de tu publicación...")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                }
                
                // Sección de categorización
                Section(header: Text("Categoría")) {
                    // Picker para temática - Solo opciones predefinidas
                        Picker("Temática", selection: $tematicaSeleccionada) {
                            ForEach(tematicas, id: \.self) { tematica in
                                Text(tematica).tag(tematica)
                            }
                    }
                    
                    // Picker para objetivo - Solo opciones predefinidas
                        Picker("Objetivo", selection: $objetivoSeleccionado) {
                            ForEach(objetivos, id: \.self) { objetivo in
                                Text(objetivo).tag(objetivo)
                        }
                    }
                }
                
                // Sección de media
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
                            // Archivo ya cargado
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
                            // Botones de selección
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

                // Sección de publicación
                Section(header: Text("Publicación")) {
                    // Picker para red social
                    Picker("Red Social", selection: $redSocialSeleccionada) {
                        Text("LinkedIn").tag(SocialNetwork.linkedin)
                        Text("X").tag(SocialNetwork.twitter)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // DatePicker para fecha y hora
                    DatePicker(
                        "Fecha de publicación",
                        selection: $fechaPublicacion,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
                
                // Mensajes de error
                if let error = viewModel.creationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
                
                // Botón de guardar
                Section {
                    Button(action: {
                        Task {
                            let exito = await viewModel.crearPublicacion(
                                texto: textoSinFormato,
                                tematica: tematicaSeleccionada,
                                objetivo: objetivoSeleccionado,
                                redSocial: redSocialSeleccionada,
                                fecha: fechaPublicacion,
                                urlEdicion: webURL,
                                mediaUrl: mediaUrlTexto.isEmpty ? nil : mediaUrlTexto,
                                mediaType: mediaTypeSeleccionado
                            )
                            if exito {
                                dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            if viewModel.isCreatingPostLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                                Text(viewModel.creationStatus.isEmpty ? "Guardando..." : viewModel.creationStatus)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("Guardar publicación")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .disabled(textoSinFormato.isEmpty || viewModel.isCreatingPostLoading)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Nueva publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
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
    NuevaPublicacionView(viewModel: SocialPostsViewModel.shared)
} 