import SwiftUI
import AppKit

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .cornerRadius(16)

            Text("Zero")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Code without footprints.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical)

            Text("Sign in with GitHub to browse repositories and start isolated sessions.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)

            Button {
                startOAuthLogin()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Sign In with GitHub")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .frame(width: 200)

            if showError || appState.userFacingError != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(errorMessage.isEmpty ? (appState.userFacingError ?? "Unknown error") : errorMessage)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(40)
        .frame(minWidth: 420, minHeight: 360)
    }

    private func startOAuthLogin() {
        isLoading = true
        showError = false

        do {
            let loginURL = try appState.beginOAuthLogin()
            NSWorkspace.shared.open(loginURL)
            errorMessage = ""
        } catch {
            showError = true
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
        .frame(width: 420, height: 380)
}
