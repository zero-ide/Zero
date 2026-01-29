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
        HSplitView {
            // Left: File Explorer
            FileExplorerView(
                selectedFile: $selectedFile,
                containerName: session.containerName,
                onFileSelect: loadFile
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            
            // Center: Monaco Editor
            VStack(spacing: 0) {
                // Tab bar
                if let file = selectedFile {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(file.name)
                            .font(.system(size: 12))
                        
                        if hasUnsavedChanges {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                }
                
                // Editor
                MonacoWebView(
                    content: $fileContent,
                    language: currentLanguage,
                    onReady: {
                        isEditorReady = true
                    }
                )
                .onChange(of: fileContent) { _, _ in
                    if !isLoadingFile {
                        hasUnsavedChanges = true
                    }
                }
            }
            .frame(minWidth: 400)
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
                    
                    // 2초 후 상태 메시지 제거
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