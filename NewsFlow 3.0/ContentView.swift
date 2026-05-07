import SwiftUI

struct ContentView: View {
    @StateObject var articlesViewModel = ArticlesViewModel()
    @StateObject var socialViewModel = SocialPostsViewModel.shared
    
    var body: some View {
        HomeView()
            .environmentObject(articlesViewModel)
            .environmentObject(socialViewModel)
    }
}

#Preview {
    ContentView()
} 