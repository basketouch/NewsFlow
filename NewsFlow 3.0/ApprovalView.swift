import SwiftUI

// MARK: - ApprovalView

struct ApprovalView: View {
    @ObservedObject var viewModel: SupabaseArticlesViewModel
    @State private var actioning: String? = nil
    @State private var showApproveAllConfirm = false
    @State private var showDiscardAllConfirm = false

    var body: some View {
        Group {
            if viewModel.isLoadingPending && viewModel.pendingArticles.isEmpty {
                ProgressView("Cargando noticias...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.pendingArticles.isEmpty {
                emptyState
            } else {
                articlesList
            }
        }
        .navigationTitle("Aprobar noticias")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task { await viewModel.loadPendingArticles() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            if !viewModel.pendingArticles.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showApproveAllConfirm = true
                        } label: {
                            Label("Aprobar todo", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) {
                            showDiscardAllConfirm = true
                        } label: {
                            Label("Descartar todo", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Aprobar \(viewModel.pendingArticles.count) artículos",
            isPresented: $showApproveAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Aprobar todo") {
                Task { await viewModel.approveAll() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog(
            "Descartar \(viewModel.pendingArticles.count) artículos",
            isPresented: $showDiscardAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Descartar todo", role: .destructive) {
                Task { await viewModel.discardAll() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .task {
            await viewModel.loadPendingArticles()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Todo revisado")
                .font(.title2.weight(.semibold))
            Text("No hay noticias pendientes de aprobación")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Articles list

    private var articlesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("\(viewModel.pendingArticles.count) pendientes")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                ForEach(viewModel.pendingArticles) { article in
                    ApprovalCard(article: article, actioning: $actioning) {
                        Task {
                            actioning = article.id
                            await viewModel.approveArticle(article)
                            actioning = nil
                        }
                    } onDiscard: {
                        Task {
                            actioning = article.id
                            await viewModel.discardArticle(article)
                            actioning = nil
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.loadPendingArticles()
        }
    }
}

// MARK: - ApprovalCard

struct ApprovalCard: View {
    let article: SupabaseArticle
    @Binding var actioning: String?
    let onApprove: () -> Void
    let onDiscard: () -> Void

    private var isActioning: Bool { actioning == article.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Content area
            HStack(alignment: .top, spacing: 12) {

                // Score badge
                if let score = article.relevanceScore {
                    ZStack {
                        Circle()
                            .fill(scoreColor(score))
                            .frame(width: 38, height: 38)
                        Text("\(score)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 6) {

                    // Meta row: category + source + date
                    HStack(spacing: 6) {
                        if let category = article.category, !category.isEmpty {
                            Text(category)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(categoryColor(category).opacity(0.15))
                                .foregroundColor(categoryColor(category))
                                .cornerRadius(6)
                        }
                        Text(article.sourceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(article.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Title (tappable link)
                    if let url = URL(string: article.url) {
                        Link(destination: url) {
                            Text(article.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                    } else {
                        Text(article.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(3)
                    }

                    // Summary
                    let displaySummary = article.summary ?? (article.description.isEmpty ? nil : article.description)
                    if let text = displaySummary {
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Relevance reason
                    if let reason = article.relevanceReason, !reason.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(reason)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.purple)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onDiscard) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                        Text("Descartar")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .disabled(actioning != nil)

                Button(action: onApprove) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                        Text("Aprobar")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
                .disabled(actioning != nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .opacity(isActioning ? 0.4 : 1.0)
        .scaleEffect(isActioning ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isActioning)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 6 { return .orange }
        return Color(.systemGray3)
    }

    func categoryColor(_ category: String) -> Color {
        switch category {
        case "IA":                  return .purple
        case "Liderazgo":           return .blue
        case "Empresa", "Negocio":  return .green
        default:                    return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ApprovalView(viewModel: SupabaseArticlesViewModel.shared)
    }
}
