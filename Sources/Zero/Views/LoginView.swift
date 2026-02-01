import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenInput: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showGuide: Bool = false
    @FocusState private var isTokenFocused: Bool
    
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
            
            // Token Input Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("GitHub Personal Access Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("토큰 발급 가이드")
                }
                
                SecureField("ghp_xxxx...", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .focused($isTokenFocused)
                    .disabled(isLoading)
                
                // Helper text
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("토큰은 Keychain에 안전하게 저장됩니다")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            
            // Sign In Button
            Button {
                signIn()
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(tokenInput.isEmpty || isLoading)
            .frame(width: 120)
            
            // Error Message
            if showError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(errorMessage)
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
        .frame(minWidth: 400, minHeight: 380)
        .sheet(isPresented: $showGuide) {
            TokenGuideView()
        }
        .onAppear {
            isTokenFocused = true
        }
    }
    
    private func signIn() {
        isLoading = true
        showError = false
        
        Task {
            do {
                try appState.login(with: tokenInput)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Token Guide View

struct TokenGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GitHub Personal Access Token")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Zero는 GitHub 저장소에 접근하기 위해 Personal Access Token이 필요합니다.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 16) {
                        StepView(number: 1, title: "GitHub 설정 페이지 이동") {
                            Link("https://github.com/settings/tokens", destination: URL(string: "https://github.com/settings/tokens")!)
                                .font(.body)
                        }
                        
                        StepView(number: 2, title: "Generate new token (classic)") {
                            Text("右上의 \"Generate new token\" 버튼을 클릭하고 \"Generate new token (classic)\"를 선택합니다.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        
                        StepView(number: 3, title: "토큰 설정") {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Note:", value: "Zero IDE")
                                LabeledContent("Expiration:", value: "90 days (또는 No expiration)")
                            }
                            .font(.body)
                        }
                        
                        StepView(number: 4, title: "권한 선택") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("필수 권한:")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    PermissionRow(name: "repo", description: "저장소 접근 (clone, pull, push)")
                                }
                                .padding(.leading)
                            }
                        }
                        
                        StepView(number: 5, title: "토큰 복사") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generate token을 클릭하고 토큰을 복사합니다.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("토큰은 한 번만 표시됩니다. 꼭 복사하세요!")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        
                        StepView(number: 6, title: "Zero에 붙여넣기") {
                            Text("복사한 토큰을 Zero 로그인 창에 붙여넣습니다.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Security Note
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("보안 정보")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("토큰은 macOS Keychain에 안전하게 저장되며, 다른 앱과 공유되지 않습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("토큰 발급 가이드")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 600)
        }
    }
}

// MARK: - Supporting Views

struct StepView<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                
                content
            }
        }
    }
}

struct PermissionRow: View {
    let name: String
    let description: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            
            Text(name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            
            Text("-")
                .foregroundStyle(.secondary)
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LoginView()
        .frame(width: 400, height: 400)
}
