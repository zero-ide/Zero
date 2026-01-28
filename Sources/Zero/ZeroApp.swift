import SwiftUI

@main
struct ZeroApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    RepoListView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
        }
    }
}
