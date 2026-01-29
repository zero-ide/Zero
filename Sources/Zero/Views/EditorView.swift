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
    
    private var fileService: FileService {
        FileService(containerName: session.containerName)
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar: File Explorer (플로팅 스타일)
            FileExplorerView(
                selectedFile: $selectedFile,
                containerName: session.containerName,
                onFileSelect: loadFile
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            // Main: Editor Area
            VStack(spacing: 0) {
                // Tab bar
                HStack {
                    if let file = selectedFile {
                        Image(systemName: iconForFile(file.name))
                            .foregroundStyle(.secondary)
                        Text(file.name)
                            .font(.system(size: 13, weight: .medium))
                        
                        if hasUnsavedChanges {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                        }
                    } else {
                        Text("No file selected")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isLoadingFile {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
                
                Divider()
                
                // Editor (플로팅 카드 스타일)
                CodeEditorView(
                    content: $fileContent,
                    language: currentLanguage,
                    onReady: {
                        isEditorReady = true
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(12)
                .onChange(of: fileContent) { _, _ in
                    if !isLoadingFile {
                        hasUnsavedChanges = true
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle("Zero - \(session.repoURL.lastPathComponent.replacingOccurrences(of: ".git", with: ""))")
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
    
    private func iconForFile(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "java", "kt", "kts": return "cup.and.saucer.fill"
        case "js", "ts": return "j.square.fill"
        case "py": return "p.square.fill"
        case "json": return "curlybraces"
        case "md": return "doc.richtext"
        case "html", "css": return "globe"
        case "yml", "yaml": return "list.bullet.rectangle"
        case "sh": return "terminal"
        case "dockerfile": return "shippingbox"
        default: return "doc.text"
        }
    }
    
    private func loadFile(_ file: FileItem) {
        guard !file.isDirectory else { return }
        
        isLoadingFile = true
        statusMessage = "Loading..."
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
                    fileContent = "// Error loading file: \(error.localizedDescription)"
                    statusMessage = "Load failed"
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
                        if statusMessage == "Saved" {
                            statusMessage = ""
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Save failed"
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
        case "cpp", "hpp", "cc": return "cpp"
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
