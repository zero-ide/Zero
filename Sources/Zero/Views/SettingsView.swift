import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            BuildConfigurationView()
                .tabItem {
                    Label("Build", systemImage: "hammer")
                }
            
            Text("General Settings")
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    SettingsView()
}
