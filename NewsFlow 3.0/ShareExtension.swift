import SwiftUI
import UIKit

// MARK: - Actividad personalizada para crear publicaciones
class CreatePostActivity: UIActivity {
    var url: URL?
    var completion: ((URL) -> Void)?
    
    override var activityTitle: String? {
        return "Crear Publicación"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "plus.circle.fill")
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.newsflow.createpost")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.contains { item in
            if let url = item as? URL {
                return url.scheme == "http" || url.scheme == "https"
            }
            return false
        }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        url = activityItems.first { item in
            if let url = item as? URL {
                return url.scheme == "http" || url.scheme == "https"
            }
            return false
        } as? URL
    }
    
    override func perform() {
        guard let url = url else {
            activityDidFinish(false)
            return
        }
        
        // Ejecutar en el hilo principal
        DispatchQueue.main.async {
            self.completion?(url)
            self.activityDidFinish(true)
        }
    }
}

// MARK: - Vista para manejar la actividad de compartir
struct ShareHandlerView: View {
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    let url: URL
    
    var body: some View {
        VStack {
            Text("Crear publicación desde:")
                .font(.headline)
                .padding()
            
            Text(url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .multilineTextAlignment(.center)
            
            Button("Continuar") {
                webURLForPost = url.absoluteString
                webTitleForPost = "Página web compartida"
                showingCreatePost = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            // Automáticamente preparar los datos
            webURLForPost = url.absoluteString
            webTitleForPost = "Página web compartida"
        }
    }
}

// MARK: - Helper para mostrar la actividad de compartir
struct ShareButton: View {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    
    var body: some View {
        Button(action: {
            showShareSheet()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Compartir")
            }
            .foregroundColor(.blue)
        }
    }
    
    private func showShareSheet() {
        let createPostActivity = CreatePostActivity()
        createPostActivity.completion = { sharedURL in
            webURLForPost = sharedURL.absoluteString
            webTitleForPost = "Página web compartida"
            showingCreatePost = true
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: [createPostActivity]
        )
        
        // Presentar el controlador de actividad
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Vista de Safari con botón de compartir
struct SafariViewWithShareButton: View {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    
    var body: some View {
        NavigationView {
            SafariView(
                url: url,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            .navigationBarHidden(true)
            .overlay(
                // Botón de compartir flotante
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ShareButton(
                            url: url,
                            showingCreatePost: $showingCreatePost,
                            webURLForPost: $webURLForPost,
                            webTitleForPost: $webTitleForPost
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white)
                                .shadow(radius: 4)
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
                }
            )
        }
    }
} 