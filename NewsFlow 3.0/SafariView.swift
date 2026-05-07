import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = UIColor(named: "AccentColor")
        safariViewController.delegate = context.coordinator
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No se necesita actualización
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView
        
        init(_ parent: SafariView) {
            self.parent = parent
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            // Se ejecuta cuando la página termina de cargar
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // Se ejecuta cuando se cierra Safari
        }
    }
}

// MARK: - SafariView con Botón Flotante
struct SafariViewWithFloatingButton: View {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    
    var body: some View {
        ZStack {
            SafariView(
                url: url,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            
            // Botón flotante para crear publicación
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // Capturar la URL actual y título
                        webURLForPost = url.absoluteString
                        webTitleForPost = "Tendencia de Google Trends"
                        showingCreatePost = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Crear Publicación")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.blue)
                                .shadow(radius: 4)
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Evitar que se superponga con la barra de herramientas de Safari
                }
            }
        }
    }
} 