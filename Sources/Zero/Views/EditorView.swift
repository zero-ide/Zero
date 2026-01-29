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
    @State private var showTerminal: Bool = false
    
    @EnvironmentObject var appState: AppState
    
    private var fileService: FileService {
        FileService(containerName: session.containerName)
    }
    
    var body: some View {
        NavigationSplitView {
            FileExplorerView(
                selectedFile: $selectedFile,
                containerName: session.containerName,
                projectName: session.repoURL.lastPathComponent.replacingOccurrences(of: ".git", with: ""),
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
                            let iconInfo = FileIconHelper.iconInfo(for: file.name, isDirectory: false)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                            
                            Image(systemName: iconInfo.name)
                                .font(.system(size: 12))
                                .foregroundStyle(iconInfo.color)
                            
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
                    
                    if showTerminal {
                        Divider()
                        OutputView(executionService: appState.executionService)
                            .transition(.move(edge: .bottom))
                    }
                    
                    Divider()
                    
                    // 상태 표시줄
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 9))
                            Text(FileIconHelper.languageDisplayName(currentLanguage))
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
                .background(Color.white)
            }
        }
        .navigationTitle("Zero")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: runCode) {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.executionService.status == .running)
                
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
                
                Button(action: { 
                    withAnimation { showTerminal.toggle() }
                }) {
                    Label("Terminal", systemImage: "terminal")
                        .foregroundStyle(showTerminal ? Color.accentColor : Color.primary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func runCode() {
        withAnimation { showTerminal = true }
        Task {
            // UI 즉시 업데이트
            await MainActor.run {
                appState.executionService.status = .running
                appState.executionService.output = "🔍 Detecting project type..."
            }
            
            do {
                // 1. 프로젝트 타입 감지
                let command = try await appState.executionService.detectRunCommand(container: session.containerName)
                
                await MainActor.run {
                    appState.executionService.output += "\n✅ Detected: \(command)\n🚀 Running...\n"
                }
                
                // 2. 실행
                await appState.executionService.run(container: session.containerName, command: command)
            } catch {
                await MainActor.run {
                    appState.executionService.status = .failed(error.localizedDescription)
                    appState.executionService.output = "❌ Error: \(error.localizedDescription)\n\nMake sure your project has a Package.swift, package.json, or main file."
                }
            }
        }
    }
    
    private func loadFile(_ file: FileItem) {
        guard !file.isDirectory else { return }
        
        isLoadingFile = true
        currentLanguage = FileIconHelper.languageName(for: file.name)
        
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
}
