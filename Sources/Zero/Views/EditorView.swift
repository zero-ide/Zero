import SwiftUI

struct EditorView: View {
    let session: Session
    @State private var selectedFile: FileItem?
    @State private var fileContent: String = "// Select a file to start editing"
    @State private var currentLanguage: String = "plaintext"
    @State private var isEditorReady = false
    
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
                        Spacer()
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
            }
            .frame(minWidth: 400)
        }
        .navigationTitle("Zero - \(session.repoURL.lastPathComponent.replacingOccurrences(of: ".git", with: ""))")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(selectedFile == nil)
                
                Button(action: {}) {
                    Label("Terminal", systemImage: "terminal")
                }
            }
        }
    }
    
    private func loadFile(_ file: FileItem) {
        // TODO: docker exec cat {file.path} 실행해서 내용 가져오기
        // 지금은 mock
        currentLanguage = detectLanguage(for: file.name)
        fileContent = """
        // Content of \(file.name)
        // This is a placeholder.
        // Actual content will be loaded from the container.
        
        import Foundation
        
        func hello() {
            print("Hello from Zero IDE!")
        }
        """
    }
    
    private func saveFile() {
        guard let file = selectedFile else { return }
        // TODO: docker exec로 파일 저장
        print("Saving \(file.path)...")
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
        default: return "plaintext"
        }
    }
}
