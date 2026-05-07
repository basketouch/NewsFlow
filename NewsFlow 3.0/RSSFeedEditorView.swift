import SwiftUI

struct RSSFeedEditorView: View {
    @ObservedObject var viewModel: ArticlesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var newFeedName = ""
    @State private var newFeedURL = ""
    @State private var showAddFeedSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var editingFeed: RSSFeed?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Fuentes RSS")) {
                    ForEach(viewModel.feedManager.feeds) { feed in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feed.name)
                                    .font(.headline)
                                Text(feed.urlString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Círculo con check verde para fuentes activas
                            Button(action: {
                                // Toggle del estado de la fuente
                                var updatedFeed = feed
                                updatedFeed.isActive.toggle()
                                viewModel.updateFeed(updatedFeed)
                            }) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(feed.isActive ? Color.green : Color.gray.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                    
                                    if feed.isActive {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingFeed = feed
                            newFeedName = feed.name
                            newFeedURL = feed.urlString
                            showAddFeedSheet = true
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteFeed(with: feed.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        newFeedName = ""
                        newFeedURL = ""
                        editingFeed = nil
                        showAddFeedSheet = true
                    }) {
                        Label("Añadir nueva fuente RSS", systemImage: "plus")
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        alertTitle = "¿Restablecer fuentes predeterminadas?"
                        alertMessage = "Esto eliminará todas las fuentes personalizadas y restaurará las predeterminadas."
                        showAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Restablecer fuentes predeterminadas")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Editar fuentes RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddFeedSheet) {
                addFeedSheet
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Restablecer", role: .destructive) {
                    viewModel.resetToDefaultFeeds()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var addFeedSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Detalles de la fuente")) {
                    TextField("Nombre", text: $newFeedName)
                        .autocapitalization(.words)
                    
                    TextField("URL del feed RSS", text: $newFeedURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button(action: saveFeed) {
                        HStack {
                            Spacer()
                            Text(editingFeed == nil ? "Añadir feed" : "Guardar cambios")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newFeedName.isEmpty || newFeedURL.isEmpty || !isValidURL(newFeedURL))
                }
            }
            .navigationTitle(editingFeed == nil ? "Añadir fuente RSS" : "Editar fuente RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") {
                        showAddFeedSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveFeed() {
        if let editingFeed = editingFeed {
            // Actualizar feed existente
            var updatedFeed = editingFeed
            updatedFeed.name = newFeedName
            updatedFeed.urlString = newFeedURL
            viewModel.updateFeed(updatedFeed)
        } else {
            // Añadir nuevo feed
            viewModel.addFeed(name: newFeedName, urlString: newFeedURL)
        }
        showAddFeedSheet = false
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

#Preview {
    RSSFeedEditorView(viewModel: ArticlesViewModel())
} 