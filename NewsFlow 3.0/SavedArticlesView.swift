import SwiftUI

struct ArchivoView: View {
    @ObservedObject var viewModel: SupabaseArticlesViewModel
    @State private var showAddURL      = false
    @State private var searchText        = ""
    @State private var activeFilter      = "todos"   // "todos" | "newsletter" | "no_newsletter"
    @State private var showCleanupConfirm = false
    @State private var showDeleteAllConfirm = false

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: Date())
    }

    var filtered: [SupabaseArticle] {
        var list: [SupabaseArticle]
        switch activeFilter {
        case "newsletter":    list = viewModel.savedArticles.filter {  $0.selectedForNewsletter }
        case "no_newsletter": list = viewModel.savedArticles.filter { !$0.selectedForNewsletter }
        default:              list = viewModel.savedArticles
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Búsqueda
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Buscar guardados...", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)

            // Filtros
            HStack(spacing: 12) {
                FilterChip(
                    title: "Todos",
                    icon: "tray.full",
                    count: viewModel.savedArticles.count,
                    isSelected: activeFilter == "todos",
                    color: .blue
                ) { activeFilter = "todos" }

                FilterChip(
                    title: "Newsletter",
                    icon: "envelope.fill",
                    count: viewModel.savedArticles.filter { $0.selectedForNewsletter }.count,
                    isSelected: activeFilter == "newsletter",
                    color: .purple
                ) { activeFilter = "newsletter" }

                FilterChip(
                    title: "No Newsletter",
                    icon: "envelope.badge.fill",
                    count: viewModel.savedArticles.filter { !$0.selectedForNewsletter }.count,
                    isSelected: activeFilter == "no_newsletter",
                    color: .gray
                ) { activeFilter = "no_newsletter" }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Error
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text(error).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Lista
            if viewModel.isLoading && viewModel.savedArticles.isEmpty {
                Spacer()
                ProgressView("Cargando guardados...")
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(viewModel.savedArticles.isEmpty ? "Nada guardado aún" : "Sin resultados")
                        .font(.headline).foregroundColor(.secondary)
                    if viewModel.savedArticles.isEmpty {
                        Text("Guarda artículos desde RSS o añade una URL")
                            .font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(filtered) { article in
                        NavigationLink(destination: SavedArticleDetailView(article: article, viewModel: viewModel)) {
                            SavedArticleRow(article: article, viewModel: viewModel)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(article) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.toggleFavorite(article) }
                            } label: {
                                Label(
                                    article.isFavorite ? "Quitar" : "Favorito",
                                    systemImage: article.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.loadSavedArticles() }
            }
        }
        .sheet(isPresented: $showAddURL) {
            AgregarURLView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task { await viewModel.loadSavedArticles() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showDeleteAllConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }

                    if viewModel.canCleanup && viewModel.cleanupArticleCount > 0 {
                        Button {
                            showCleanupConfirm = true
                        } label: {
                            Label("Limpiar", systemImage: "trash.slash")
                                .font(.caption)
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .confirmationDialog(
            "Eliminar \(filtered.count) artículos",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar todo", role: .destructive) {
                Task { await viewModel.deleteAll(filtered) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán todos los artículos visibles (\(activeFilter == "todos" ? "todos" : activeFilter == "newsletter" ? "con newsletter" : "sin newsletter")). Esta acción no se puede deshacer.")
        }
        .confirmationDialog(
            "Eliminar \(viewModel.cleanupArticleCount) artículos del mes anterior",
            isPresented: $showCleanupConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.cleanupOldArticles() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán los artículos guardados antes del \(currentMonthLabel). Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Row

struct SavedArticleRow: View {
    let article: SupabaseArticle
    @ObservedObject var viewModel: SupabaseArticlesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: article.sourceTypeIcon)
                    .font(.caption)
                    .foregroundColor(sourceColor)
                Text(article.sourceName)
                    .font(.caption)
                    .foregroundColor(sourceColor)
                Spacer()
                Text(article.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if article.isFavorite {
                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                }
                if article.selectedForNewsletter {
                    Image(systemName: "envelope.fill").font(.caption2).foregroundColor(.purple)
                }
            }

            Text(article.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(article.isRead ? .secondary : .primary)

            if !article.description.isEmpty {
                Text(article.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .opacity(article.isRead ? 0.8 : 1.0)
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

// MARK: - Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ArchivoView(viewModel: SupabaseArticlesViewModel.shared)
            .navigationTitle("Archivo")
    }
}
