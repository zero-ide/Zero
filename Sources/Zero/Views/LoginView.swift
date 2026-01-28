import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenInput: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "slash.circle")
                .font(.system(size: 80))
                .foregroundStyle(.primary)
            
            Text("Zero")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Code without footprints.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.vertical)
            
            // Token Input (임시 - 추후 OAuth로 교체)
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Personal Access Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("ghp_xxxx...", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            
            Button("Sign In") {
                signIn()
            }
            .buttonStyle(.borderedProminent)
            .disabled(tokenInput.isEmpty)
            
            if showError {
                Text("Failed to save token")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 350)
    }
    
    private func signIn() {
        do {
            try appState.login(with: tokenInput)
        } catch {
            showError = true
        }
    }
}
