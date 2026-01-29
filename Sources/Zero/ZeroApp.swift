import SwiftUI

@main
struct ZeroApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // 앱을 regular 앱으로 등록 (Dock 아이콘, 메뉴바, 키보드 입력 활성화)
        NSApp.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !appState.isLoggedIn {
                    LoginView()
                } else if appState.isEditing, let session = appState.activeSession {
                    EditorView(session: session)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button(action: { appState.closeEditor() }) {
                                    Label("Back", systemImage: "chevron.left")
                                }
                            }
                        }
                } else {
                    RepoListView()
                }
            }
            .environmentObject(appState)
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
