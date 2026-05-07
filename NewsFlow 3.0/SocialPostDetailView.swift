import SwiftUI

struct SocialPostDetailView: View {
    let post: SocialPost
    @ObservedObject var viewModel: SocialPostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showRejectConfirm = false
    @State private var showPublishConfirm = false
    @State private var publishSuccess = false
    @State private var publishError: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Cabecera: red social + fecha + slot
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        NetworkBadge(network: post.redSocialEnum)
                        Spacer()
                        PostStatusBadge(post: post)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Publicación:")
                            .foregroundColor(.secondary)
                        Text(post.formattedPublishDate)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)

                    if let slot = post.slotProgramado {
                        HStack(spacing: 6) {
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

                // Previsualización
                SocialMediaPreview(post: post)

                // Zona de acciones
                if isProcessing {
                    ProgressView("Procesando…")
                        .padding(.vertical, 24)
                } else {
                    actionButtons
                }
            }
            .padding()
        }
        .navigationTitle("Detalle de publicación")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isEditingPost) {
            EditPostView(viewModel: viewModel)
        }
        // Confirmación de rechazo — destructiva, explica que elimina
        .confirmationDialog(
            "Rechazar esta publicación",
            isPresented: $showRejectConfirm,
            titleVisibility: .visible
        ) {
            Button("Rechazar y eliminar", role: .destructive) {
                Task {
                    isProcessing = true
                    viewModel.isEditingPost = false
                    viewModel.currentEditPost = nil
                    await viewModel.rejectPost(post: post)
                    isProcessing = false
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El post se eliminará de Airtable y no se podrá recuperar.")
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
                    if ok { publishSuccess = true }
                    else  { publishError = viewModel.error ?? "Error desconocido al publicar" }
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
        // Overlay de éxito
        .overlay {
            if publishSuccess {
                PublishSuccessOverlay(redSocial: post.redSocial) {
                    publishSuccess = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Botones de acción

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {

            // Acción principal: Aprobar (solo si no está aprobado)
            if !post.aprobado {
                Button {
                    Task {
                        isProcessing = true
                        viewModel.isEditingPost = false
                        viewModel.currentEditPost = nil
                        await viewModel.approvePost(post: post)
                        isProcessing = false
                        dismiss()
                    }
                } label: {
                    Label("Aprobar publicación", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }

            // Publicar ahora (aprobado pero no publicado)
            if post.aprobado && !post.publicado {
                Button { showPublishConfirm = true } label: {
                    Label("Publicar ahora", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(post.redSocialEnum == .linkedin
                      ? Color(red: 0.04, green: 0.4, blue: 0.76)
                      : Color.primary)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }

            // Acciones secundarias: Editar | Rechazar
            HStack(spacing: 12) {
                Button {
                    guard !isProcessing else { return }
                    isProcessing = true
                    viewModel.startEditing(post: post)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isProcessing = false
                    }
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isLoading)

                Button(role: .destructive) {
                    showRejectConfirm = true
                } label: {
                    Label("Rechazar", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - SocialMediaPreview

struct SocialMediaPreview: View {
    let post: SocialPost

    private var isLinkedIn: Bool { post.redSocialEnum == .linkedin }

    private var networkColor: Color {
        isLinkedIn
            ? Color(red: 0.04, green: 0.4, blue: 0.76)   // #0A66C2
            : Color.primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Cabecera: avatar + nombre + logo de plataforma
            HStack(alignment: .top, spacing: 10) {
                // Avatar con iniciales
                ZStack {
                    Circle()
                        .fill(networkColor)
                        .frame(width: 46, height: 46)
                    Text("JL")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                // Nombre y fecha
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jorge Lorenzo")
                        .font(.subheadline.weight(.semibold))
                    Text(post.formattedPublishDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Logo de la plataforma
                platformLogo
            }

            Divider()

            // Texto del post
            Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

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
                            mediaPlaceholder(icon: "photo", label: "No se pudo cargar la imagen")
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity).padding()
                        @unknown default:
                            EmptyView()
                        }
                    }
                case .video:
                    mediaPlaceholder(icon: "video.fill", label: "Vídeo adjunto")
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
                    .foregroundColor(networkColor)
                    .font(.subheadline)
            }

            Divider()

            // Botonera simulada de la red social
            HStack(spacing: 24) {
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
            .font(.callout)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(networkColor.opacity(0.35), lineWidth: 1.5)
        )
    }

    // Logo propio de cada plataforma
    @ViewBuilder
    private var platformLogo: some View {
        if isLinkedIn {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.04, green: 0.4, blue: 0.76))
                    .frame(width: 34, height: 34)
                Text("in")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .italic()
                    .foregroundColor(.white)
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 34, height: 34)
                Text("𝕏")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(.systemBackground))
            }
        }
    }

    @ViewBuilder
    private func mediaPlaceholder(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary)
            Text(label).font(.caption).foregroundColor(.secondary)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        SocialPostDetailView(
            post: SocialPost.nuevo(
                texto: "El liderazgo en la era digital exige claridad, velocidad y la capacidad de adaptarse sin perder el foco en lo esencial.",
                redSocial: .linkedin,
                fecha: Date().addingTimeInterval(86400),
                tematica: "Liderazgo",
                objetivo: "Reflexión"
            ),
            viewModel: SocialPostsViewModel.shared
        )
    }
}
