import SwiftUI

struct PostReviewView: View {
    @ObservedObject var viewModel: SocialPostsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Cargando publicaciones...")
                        .padding()
                } else if viewModel.postsForReview.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No hay publicaciones pendientes de revisión")
                            .font(.headline)
                        
                        Text("Todas las publicaciones han sido revisadas")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Cerrar") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.postsForReview) { post in
                            Button {
                                // Al tocar el item, abrimos la vista de detalle
                                viewModel.selectedPost = post
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Cabecera con red social
                                    HStack {
                                        Label(post.redSocial, systemImage: "network")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(post.formattedPublishDate)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                                        .font(.body)
                                        .lineLimit(4)
                                        .foregroundColor(.primary)

                                    if !post.hashtags.isEmpty {
                                        Text(post.hashtags)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .lineLimit(1)
                                    }
                                    
                                    // Botón para ver detalle
                                    HStack {
                                        Spacer()
                                        
                                        Text("Toca para revisar")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Publicaciones pendientes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            // Utilizamos una sola sheet para ambos casos
            // Si isEditingPost es true, tiene prioridad sobre selectedPost
            .sheet(isPresented: $viewModel.isEditingPost) {
                EditPostView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedPost) { post in
                // Cuando el usuario selecciona editar desde DetailView, 
                // se cerrará este sheet y se abrirá el de edición
                NavigationStack {
                    SocialPostDetailView(post: post, viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Cerrar") {
                                    // Cuando se cierra la vista de detalle
                                    // nos aseguramos de limpiar todos los estados
                                    viewModel.isEditingPost = false
                                    viewModel.currentEditPost = nil
                                    viewModel.selectedPost = nil
                                }
                            }
                        }
                }
                .interactiveDismissDisabled(viewModel.isEditingPost)
            }
        }
    }
}

#Preview {
            let viewModel = SocialPostsViewModel.shared
    return PostReviewView(viewModel: viewModel)
} 