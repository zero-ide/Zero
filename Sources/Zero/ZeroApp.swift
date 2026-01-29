import SwiftUI

@main
struct ZeroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "slash.circle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Zero - Code without footprints.")
                .font(.headline)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
