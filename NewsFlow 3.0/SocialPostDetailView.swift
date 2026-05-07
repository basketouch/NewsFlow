import SwiftUI

struct SocialPostDetailView: View {
    let post: SocialPost
    @ObservedObject var viewModel: SocialPostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showPublishConfirm = false
    @State private var publishSuccess = false
    @State private var publishError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cabecera con información general
                VStack(alignment: .leading, spacing: 10) {
                    // Red social y estado
                    HStack {
                        Label(post.redSocial, systemImage: "network")
                            .font(.headline)
                        
                        Spacer()
                        
                        PostStatusBadge(post: post)
                    }
                    
                    // Fecha programada
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        
                        Text("Fecha de publicación:")
                            .foregroundColor(.secondary)
                        
                        Text(post.formattedPublishDate)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    // Slot programado si existe
                    if let slot = post.slotProgramado {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            
                            Text("Slot:")
                                .foregroundColor(.secondary)
                            
                            Text(slot)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    
                    Divider()
                }
                .padding(.bottom, 10)
                
                // Previsualización de la publicación (como se verá en la red social)
                SocialMediaPreview(post: post)
                
                // Botones de acción
                VStack(spacing: 12) {
                    if isProcessing {
                        // Indicador de carga
                        ProgressView("Procesando...")
                            .padding()
                    } else {
                        // Nuevo diseño de botones más visual
                        HStack(spacing: 30) {
                            // Botón para rechazar - aspa roja
                            Button {
                                Task {
                                    // Evitar múltiples acciones
                                    isProcessing = true
                                    
                                    // Limpiar estados
                                    viewModel.isEditingPost = false
                                    viewModel.currentEditPost = nil
                                    
                                    // Ejecutar la acción
                                    await viewModel.rejectPost(post: post)
                                    
                                    // Completado
                                    isProcessing = false
                                    dismiss()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.1))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "xmark")
                                            .font(.title)
                                            .foregroundColor(.red)
                                    }
                                    
                                    Text("Rechazar")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .disabled(viewModel.isLoading || isProcessing)
                            
                            // Botón para editar - lápiz
                            Button {
                                // Evitar múltiples acciones
                                guard !isProcessing else { return }
                                
                                isProcessing = true
                                
                                // Configurar edición - esto utilizará el mejor flujo en el ViewModel
                                viewModel.startEditing(post: post)
                                
                                // Restaurar el estado después de un momento
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isProcessing = false
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.1))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "pencil")
                                            .font(.title)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("Editar")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .disabled(viewModel.isLoading || isProcessing)
                            
                            // Botón Publicar ahora (aprobado pero no publicado)
                            if post.aprobado && !post.publicado {
                                Button {
                                    showPublishConfirm = true
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                            Image(systemName: "paperplane.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                        Text("Publicar\nahora")
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(viewModel.isLoading || isProcessing)
                            }

                        // Botón para aprobar - check verde (solo mostrar si no está aprobado)
                            if !post.aprobado {
                                Button {
                                    Task {
                                        // Evitar múltiples acciones
                                        isProcessing = true
                                        
                                        // Limpiar estados
                                        viewModel.isEditingPost = false
                                        viewModel.currentEditPost = nil
                                        
                                        // Ejecutar la acción
                                        await viewModel.approvePost(post: post)
                                        
                                        // Completado
                                        isProcessing = false
                                        dismiss()
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.title)
                                                .foregroundColor(.green)
                                        }
                                        
                                        Text("Aprobar")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .disabled(viewModel.isLoading || isProcessing)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Detalle de publicación")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isEditingPost) {
            EditPostView(viewModel: viewModel)
        }
        // Confirmación antes de publicar
        .confirmationDialog(
            "Publicar en \(post.redSocial)",
            isPresented: $showPublishConfirm,
            titleVisibility: .visible
        ) {
            Button("Publicar ahora", role: .none) {
                Task {
                    isProcessing = true
                    publishError = nil
                    let ok = await viewModel.publishNow(post: post)
                    isProcessing = false
                    if ok {
                        publishSuccess = true
                    } else {
                        publishError = viewModel.error ?? "Error desconocido al publicar"
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Este post se publicará inmediatamente en \(post.redSocial).")
        }
        // Alerta de error al publicar
        .alert("No se pudo publicar", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("OK", role: .cancel) { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        // Feedback de éxito
        .overlay {
            if publishSuccess {
                PublishSuccessOverlay(redSocial: post.redSocial) {
                    publishSuccess = false
                    dismiss()
                }
            }
        }
    }
}

// Vista para previsualizar cómo se verá la publicación en la red social
struct SocialMediaPreview: View {
    let post: SocialPost
    
    var networkIcon: String {
        switch post.redSocialEnum {
        case .linkedin: return "link.circle.fill"
        case .twitter:  return "quote.bubble.fill"
        }
    }

    var networkColor: Color {
        switch post.redSocialEnum {
        case .linkedin: return .blue
        case .twitter:  return .cyan
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabecera que simula la red social
            HStack {
                // Avatar de usuario
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    Text("Jorge Lorenzo")
                        .font(.headline)
                    Text("\(post.formattedPublishDate) • \(post.redSocial)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Logo de la red social
                Image(systemName: networkIcon)
                    .foregroundColor(networkColor)
            }
            
            // Contenido de la publicación
            Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                .padding(.vertical, 10)

            // Media adjunta
            if post.hasMedia, let urlString = post.mediaUrl, let url = URL(string: urlString) {
                switch post.mediaTypeEnum {
                case .imagen:
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                        case .failure:
                            mediaErrorPlaceholder(icon: "photo", label: "No se pudo cargar la imagen")
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity).padding()
                        @unknown default:
                            EmptyView()
                        }
                    }
                case .video:
                    mediaErrorPlaceholder(icon: "video.fill", label: "Vídeo adjunto")
                        .overlay(alignment: .topTrailing) {
                            Link(destination: url) {
                                Label("Abrir", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                                    .padding(6)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(6)
                        }
                case .texto:
                    EmptyView()
                }
            }

            // Hashtags
            if !post.hashtags.isEmpty {
                Text(post.hashtags)
                    .foregroundColor(.blue)
                    .font(.subheadline)
            }
            
            // Botonera simulada de la red social
            HStack(spacing: 20) {
                Image(systemName: "hand.thumbsup")
                    .foregroundColor(.secondary)
                
                Image(systemName: "bubble.right")
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.2.squarepath")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(networkColor.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func mediaErrorPlaceholder(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Overlay de publicación exitosa

struct PublishSuccessOverlay: View {
    let redSocial: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("¡Publicado!")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("Tu post ya está en \(redSocial)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                Button("Cerrar") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
                    .padding(.top, 4)
            }
            .padding(36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(duration: 0.3), value: true)
    }
}

#Preview {
    NavigationStack {
        SocialPostDetailView(
            post: SocialPost.nuevo(
                texto: "Post de ejemplo para previsualización en pantalla de detalle",
                redSocial: .linkedin,
                fecha: Date().addingTimeInterval(86400),
                tematica: "IA",
                objetivo: "Interesante"
            ),
            viewModel: SocialPostsViewModel.shared
        )
    }
} 