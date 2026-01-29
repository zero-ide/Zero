import SwiftUI

struct EditorView: View {
    let session: Session
    @State private var selectedFile: FileItem?
    @State private var fileContent: String = "// Select a file to start editing"
    @State private var currentLanguage: String = "plaintext"
    @State private var isEditorReady = false
    @State private var isLoadingFile = false
    @State private var isSaving = false
    @State private var hasUnsavedChanges = false
    @State private var statusMessage: String = ""
    @State private var cursorLine: Int = 1
    @State private var cursorColumn: Int = 1
    
    private var fileService: FileService {
        FileService(containerName: session.containerName)
    }
    
    var body: some View {
        NavigationSplitView {
            FileExplorerView(
                selectedFile: $selectedFile,
                containerName: session.containerName,
                onFileSelect: loadFile
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            ZStack {
                // 배경
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                
                // 에디터 카드 (모든 모서리 일관되게 둥글게)
                VStack(spacing: 0) {
                    // 헤더 (Breadcrumb)
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Text(session.repoURL.lastPathComponent.replacingOccurrences(of: ".git", with: ""))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        if let file = selectedFile {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                            
                            Image(systemName: iconForFile(file.name))
                                .font(.system(size: 12))
                                .foregroundStyle(colorForFile(file.name))
                            
                            Text(file.name)
                                .font(.system(size: 13, weight: .medium))
                            
                            if hasUnsavedChanges {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        
                        Spacer()
                        
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    // 에디터
                    CodeEditorView(
                        content: $fileContent,
                        language: currentLanguage,
                        onReady: { isEditorReady = true },
                        onCursorChange: { line, column in
                            cursorLine = line
                            cursorColumn = column
                        }
                    )
                    .onChange(of: fileContent) { _, _ in
                        if !isLoadingFile {
                            hasUnsavedChanges = true
                        }
                    }
                    
                    Divider()
                    
                    // 상태 표시줄
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 9))
                            Text(languageDisplayName(currentLanguage))
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("Ln \(cursorLine), Col \(cursorColumn)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("UTF-8")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(12)
            }
        }
        .navigationTitle("Zero")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: saveFile) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(selectedFile == nil || isSaving)
                
                Button(action: {}) {
                    Label("Terminal", systemImage: "terminal")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func iconForFile(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "java", "kt", "kts": return "cup.and.saucer.fill"
        case "js": return "j.square.fill"
        case "ts": return "t.square.fill"
        case "py": return "p.square.fill"
        case "json": return "curlybraces"
        case "md": return "doc.richtext.fill"
        case "html", "css": return "globe"
        case "yml", "yaml": return "list.bullet.rectangle.fill"
        case "sh": return "terminal.fill"
        case "dockerfile": return "shippingbox.fill"
        default: return "doc.text.fill"
        }
    }
    
    private func colorForFile(_ filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "java": return .red
        case "kt", "kts": return .purple
        case "js": return .yellow
        case "ts": return .blue
        case "py": return .cyan
        case "json": return .yellow
        case "md": return .blue
        case "html": return .orange
        case "css": return .pink
        case "yml", "yaml": return .pink
        case "sh": return .green
        default: return .secondary
        }
    }
    
    private func languageDisplayName(_ lang: String) -> String {
        switch lang {
        case "swift": return "Swift"
        case "java": return "Java"
        case "kotlin": return "Kotlin"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "python": return "Python"
        case "json": return "JSON"
        case "html": return "HTML"
        case "css": return "CSS"
        case "markdown": return "Markdown"
        case "yaml": return "YAML"
        case "shell": return "Shell"
        case "dockerfile": return "Dockerfile"
        case "plaintext": return "Plain Text"
        default: return lang.capitalized
        }
    }
    
    private func loadFile(_ file: FileItem) {
        guard !file.isDirectory else { return }
        
        isLoadingFile = true
        currentLanguage = detectLanguage(for: file.name)
        
        Task {
            do {
                let content = try await fileService.readFile(path: file.path)
                await MainActor.run {
                    fileContent = content
                    hasUnsavedChanges = false
                    statusMessage = ""
                    isLoadingFile = false
                }
            } catch {
                await MainActor.run {
                    fileContent = "// Error: \(error.localizedDescription)"
                    statusMessage = "Failed"
                    isLoadingFile = false
                }
            }
        }
    }
    
    private func saveFile() {
        guard let file = selectedFile else { return }
        
        isSaving = true
        statusMessage = "Saving..."
        
        Task {
            do {
                try await fileService.writeFile(path: file.path, content: fileContent)
                await MainActor.run {
                    hasUnsavedChanges = false
                    statusMessage = "Saved"
                    isSaving = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if statusMessage == "Saved" { statusMessage = "" }
                    }
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed"
                    isSaving = false
                }
            }
        }
    }
    
    private func detectLanguage(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "py": return "python"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "json": return "json"
        case "html": return "html"
        case "css": return "css"
        case "md": return "markdown"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "sh": return "shell"
        case "c", "h": return "c"
        case "cpp", "hpp": return "cpp"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "php": return "php"
        case "sql": return "sql"
        case "dockerfile": return "dockerfile"
        default: return "plaintext"
        }
    }
}
