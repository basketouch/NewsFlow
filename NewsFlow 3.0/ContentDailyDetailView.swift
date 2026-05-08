import SwiftUI

struct ContentDailyDetailView: View {
    @State var post: ContentDailyPost
    @ObservedObject var viewModel: ContentDailyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlatform = 0
    @State private var isEditingText = false          // único flag de edición
    @State private var showDeleteConfirm = false
    @State private var copiedPlatform: String? = nil

    private let platforms = ["LinkedIn", "Instagram", "Twitter", "TikTok"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                platformPicker
                platformContent
                Divider().padding(.horizontal)
                if !post.hashtags.isEmpty { hashtagsSection }
                deleteButton
            }
            .padding(.top, 16)
        }
        .navigationTitle("Post IA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") {
                    Task { await viewModel.updatePost(post) }
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onChange(of: selectedPlatform) { _ in
            // Al cambiar de plataforma salimos del modo edición
            isEditingText = false
        }
        .confirmationDialog("¿Eliminar este post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.deletePost(post); dismiss() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("IA", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
                Text(post.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(post.topic)
                .font(.title3.weight(.bold))

            if let url = post.sourceUrl, !url.isEmpty {
                Link(destination: URL(string: url) ?? URL(string: "https://")!) {
                    Label("Ver fuente", systemImage: "link")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(statusSwiftColor)
                    .frame(width: 7, height: 7)
                Text(post.statusLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !post.publishedTo.isEmpty {
                    Text("· Publicado en: \(post.publishedTo.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Platform picker

    private var platformPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(platforms.enumerated()), id: \.offset) { index, name in
                    let available = platformAvailable(name)
                    let published = platformPublished(name)
                    Button {
                        if available { selectedPlatform = index }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: platformIcon(name)).font(.caption)
                            Text(name).font(.callout)
                            if published {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2).foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selectedPlatform == index ? platformColor(name) : Color.gray.opacity(0.15))
                        .foregroundColor(selectedPlatform == index ? .white : (available ? .primary : .secondary))
                        .cornerRadius(16)
                        .opacity(available ? 1 : 0.4)
                    }
                    .disabled(!available)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Platform content

    @ViewBuilder
    private var platformContent: some View {
        let name = platforms[selectedPlatform]
        VStack(alignment: .leading, spacing: 14) {

            // Score — tarjeta prominente
            if let score = platformScore(name) {
                scoreCard(score)
                    .padding(.horizontal)
            }

            // Texto: modo lectura o edición
            VStack(alignment: .leading, spacing: 6) {
                // Cabecera de sección con toggle edición
                HStack {
                    Text(name == "TikTok" ? "Script" : "Texto")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingText.toggle()
                        }
                    } label: {
                        Label(
                            isEditingText ? "Listo" : "Editar",
                            systemImage: isEditingText ? "checkmark.circle.fill" : "pencil"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isEditingText ? .green : .secondary)
                    }
                }
                .padding(.horizontal)

                if isEditingText {
                    // Modo edición — TextEditor
                    TextEditor(text: bindingForPlatform(name))
                        .font(.body)
                        .frame(minHeight: name == "TikTok" ? 200 : 150)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    // Modo lectura — Text seleccionable
                    Text(textForPlatform(name))
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // Contador de caracteres (solo cuando edita o en Twitter)
                if isEditingText || name == "Twitter" {
                    HStack {
                        Spacer()
                        Text("\(textForPlatform(name).count) chars")
                            .font(.caption2)
                            .foregroundColor(charLimitExceeded(name) ? .red : .secondary)
                        if name == "Twitter" {
                            Text("/ 280 max")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Instagram image prompt
            if name == "Instagram", let prompt = post.instagramImagePrompt, !prompt.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Prompt imagen sugerida", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            // Acciones — patrón unificado
            actionButtons(for: name)
                .padding(.horizontal)
        }
    }

    // MARK: - Action buttons (patrón unificado)

    @ViewBuilder
    private func actionButtons(for name: String) -> some View {
        let alreadyPublished = platformPublished(name)

        VStack(spacing: 10) {
            // Copiar texto — siempre disponible
            Button {
                UIPasteboard.general.string = textForPlatform(name)
                withAnimation { copiedPlatform = name }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedPlatform = nil }
                }
            } label: {
                Label(
                    copiedPlatform == name ? "¡Copiado!" : "Copiar texto",
                    systemImage: copiedPlatform == name ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(copiedPlatform == name ? .green : .primary)
            .controlSize(.large)

            // Marcar publicado — mismo patrón en todas las plataformas
            Button {
                // Para todas las plataformas: marcar como publicado
                // (LinkedIn además enviará via n8n cuando esté implementado)
                Task {
                    await viewModel.markPublished(post, platform: name.lowercased())
                    if let updated = viewModel.posts.first(where: { $0.id == post.id }) {
                        post = updated
                    }
                }
            } label: {
                Label(
                    alreadyPublished ? "Publicado en \(name)" : "Marcar como publicado",
                    systemImage: alreadyPublished ? "checkmark.circle.fill" : "arrow.up.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(alreadyPublished ? .green : platformColor(name))
            .controlSize(.large)
            .disabled(alreadyPublished)
        }
    }

    // MARK: - Score card

    private func scoreCard(_ score: Int) -> some View {
        let color = scoreSwiftColor(score)
        return HStack(spacing: 16) {
            // Número grande
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("/ 10")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            // Barra + etiqueta
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(score) / 10)
                    }
                }
                .frame(height: 8)

                Text("Score IA")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Hashtags

    private var hashtagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hashtags")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(post.hashtags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Eliminar post", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func platformAvailable(_ name: String) -> Bool {
        switch name {
        case "LinkedIn":  return !(post.linkedinPost ?? "").isEmpty
        case "Instagram": return !(post.instagramPost ?? "").isEmpty
        case "Twitter":   return !(post.twitterPost ?? "").isEmpty
        case "TikTok":    return !(post.tiktokScript ?? "").isEmpty
        default:          return false
        }
    }

    private func platformPublished(_ name: String) -> Bool {
        post.publishedTo.contains(name.lowercased())
    }

    private func platformScore(_ name: String) -> Int? {
        switch name {
        case "LinkedIn":  return post.linkedinScore
        case "Instagram": return post.instagramScore
        case "Twitter":   return post.twitterScore
        case "TikTok":    return post.tiktokScore
        default:          return nil
        }
    }

    private func textForPlatform(_ name: String) -> String {
        switch name {
        case "LinkedIn":  return post.linkedinPost ?? ""
        case "Instagram": return post.instagramPost ?? ""
        case "Twitter":   return post.twitterPost ?? ""
        case "TikTok":    return post.tiktokScript ?? ""
        default:          return ""
        }
    }

    private func bindingForPlatform(_ name: String) -> Binding<String> {
        switch name {
        case "LinkedIn":  return Binding(get: { post.linkedinPost ?? "" }, set: { post.linkedinPost = $0 })
        case "Instagram": return Binding(get: { post.instagramPost ?? "" }, set: { post.instagramPost = $0 })
        case "Twitter":   return Binding(get: { post.twitterPost ?? "" }, set: { post.twitterPost = $0 })
        case "TikTok":    return Binding(get: { post.tiktokScript ?? "" }, set: { post.tiktokScript = $0 })
        default:          return .constant("")
        }
    }

    private func charLimitExceeded(_ name: String) -> Bool {
        name == "Twitter" && textForPlatform(name).count > 280
    }

    private func platformIcon(_ name: String) -> String {
        switch name {
        case "LinkedIn":  return "link.circle.fill"
        case "Instagram": return "camera.fill"
        case "Twitter":   return "quote.bubble.fill"
        case "TikTok":    return "music.note"
        default:          return "square"
        }
    }

    private func platformColor(_ name: String) -> Color {
        switch name {
        case "LinkedIn":  return Color(red: 0.04, green: 0.4, blue: 0.76)
        case "Instagram": return .pink
        case "Twitter":   return Color.primary
        case "TikTok":    return .purple
        default:          return .gray
        }
    }

    private var statusSwiftColor: Color {
        switch post.status {
        case "pending_review":    return .orange
        case "published_partial": return .blue
        case "published_all":     return .green
        default:                  return .gray
        }
    }

    private func scoreSwiftColor(_ score: Int) -> Color {
        score >= 8 ? .green : score >= 6 ? .orange : .red
    }
}
