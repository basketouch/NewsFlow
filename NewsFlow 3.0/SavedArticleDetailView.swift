import SwiftUI

struct SavedArticleDetailView: View {
    let article: SupabaseArticle
    @ObservedObject var viewModel: SupabaseArticlesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSafari = false
    @State private var showingNewPost = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Cabecera
                VStack(alignment: .leading, spacing: 8) {
                    // Fuente + tipo
                    HStack(spacing: 6) {
                        Image(systemName: article.sourceTypeIcon)
                            .font(.caption)
                            .foregroundColor(sourceColor)
                        Text(article.sourceName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(sourceColor)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(article.displaySourceType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(article.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Título
                    Text(article.title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    // Categoría
                    if let category = article.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Resumen IA (si existe)
                if let summary = article.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Resumen IA", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.purple)
                        Text(summary)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Descripción
                if !article.description.isEmpty {
                    Text(article.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                // Contenido
                if !article.content.isEmpty && article.content != article.description {
                    Text(article.content)
                        .font(.body)
                        .padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // Acciones
                VStack(spacing: 12) {
                    // Ver artículo completo
                    if hasRealURL {
                        Button {
                            showSafari = true
                            Task { await viewModel.markAsRead(article) }
                        } label: {
                            Label("Leer artículo completo", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Crear post RRSS
                    Button {
                        showingNewPost = true
                    } label: {
                        Label("Crear post para RRSS", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    // Newsletter toggle
                    Button {
                        Task { await viewModel.toggleNewsletter(article) }
                    } label: {
                        Label(
                            article.selectedForNewsletter ? "Quitar del Newsletter" : "Añadir al Newsletter",
                            systemImage: article.selectedForNewsletter ? "envelope.badge.fill" : "envelope.badge"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(article.selectedForNewsletter ? .purple : .primary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.toggleFavorite(article) }
                } label: {
                    Image(systemName: article.isFavorite ? "star.fill" : "star")
                        .foregroundColor(article.isFavorite ? .yellow : .gray)
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if hasRealURL, let url = URL(string: article.url) {
                SafariView(url: url, showingCreatePost: .constant(false), webURLForPost: .constant(nil), webTitleForPost: .constant(nil))
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .sheet(isPresented: $showingNewPost) {
            NuevaPublicacionView(
                viewModel: SocialPostsViewModel.shared,
                textoInicial: "📰 \(article.title)\n\n\(article.description)",
                webURL: article.url,
                webTitle: article.title,
                isFromWeb: true
            )
        }
        .onAppear {
            Task { await viewModel.markAsRead(article) }
        }
    }

    private var hasRealURL: Bool {
        article.url.hasPrefix("http://") || article.url.hasPrefix("https://")
    }

    var sourceColor: Color {
        switch article.sourceType {
        case "rss":   return .orange
        case "gmail": return .blue
        case "url":   return .green
        default:      return .gray
        }
    }
}

#Preview {
    NavigationStack {
        SavedArticleDetailView(
            article: SupabaseArticle(
                id: UUID().uuidString,
                title: "Artículo de ejemplo",
                description: "Descripción del artículo guardado en Supabase.",
                content: "Contenido completo...",
                url: "https://example.com",
                sourceName: "TechCrunch",
                sourceType: "rss",
                publishedAt: Date(),
                imageUrl: nil,
                category: "IA",
                summary: "Resumen generado por Gemini Flash.",
                isRead: false,
                isFavorite: false,
                selectedForNewsletter: false,
                createdAt: Date()
            ),
            viewModel: SupabaseArticlesViewModel.shared
        )
    }
}
