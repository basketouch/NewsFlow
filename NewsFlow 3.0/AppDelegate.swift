import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("📱 App iniciada: NewsFlow 3.0")
        // Restaurar sesión de Google si ya había iniciado sesión antes
        GoogleDriveService.shared.restoreSession()
        return true
    }

    // Necesario para el callback OAuth de Google Sign-In
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
