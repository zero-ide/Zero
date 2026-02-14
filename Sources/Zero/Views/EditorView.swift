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
    @State private var showGitPanel: Bool = false
    @State private var lspStatusMessage: String = ""
    @State private var isRecoveringLSP: Bool = false
    @State private var terminalHeight: CGFloat = 180
    @State private var terminalDragStartHeight: CGFloat = 180
    
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
                    
                    Group {
                        if currentLanguage == "java" {
                            MonacoWebView(
                                content: $fileContent,
                                language: currentLanguage,
                                documentPath: selectedFile?.path,
                                enableLSP: true,
                                onReady: {
                                    isEditorReady = true
                                    if lspStatusMessage.isEmpty || lspStatusMessage == "Starting..." || lspStatusMessage == "LSP ready" {
                                        lspStatusMessage = "Initializing..."
                                    }
                                },
                                onCursorChange: { line, column in
                                    cursorLine = line
                                    cursorColumn = column
                                },
                                onLSPStatusChange: { status in
                                    lspStatusMessage = status

                                    if (status == "Disconnected" || status == "Error" || status == "Init Failed" || status == "Init Delayed") && !isRecoveringLSP {
                                        isRecoveringLSP = true

                                        Task {
                                            let isReady = await appState.ensureJavaLSPReady()

                                            await MainActor.run {
                                                if currentLanguage == "java" {
                                                    lspStatusMessage = isReady ? "Initializing..." : appState.javaLSPBootstrapMessage()
                                                }

                                                isRecoveringLSP = false
                                            }
                                        }
                                    }
                                }
                            )
                        } else {
                            CodeEditorView(
                                content: $fileContent,
                                language: currentLanguage,
                                onReady: { isEditorReady = true },
                                onCursorChange: { line, column in
                                    cursorLine = line
                                    cursorColumn = column
                                }
                            )
                        }
                    }
                    .onChange(of: fileContent) { _, _ in
                        if !isLoadingFile {
                            hasUnsavedChanges = true
                        }
                    }
                    
                    if showTerminal {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(height: 12)
                                .overlay {
                                    Capsule()
                                        .fill(Color(nsColor: .tertiaryLabelColor))
                                        .frame(width: 44, height: 4)
                                }
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let proposedHeight = terminalDragStartHeight - value.translation.height
                                            terminalHeight = min(max(120, proposedHeight), 500)
                                        }
                                        .onEnded { _ in
                                            terminalDragStartHeight = terminalHeight
                                        }
                                )

                            OutputView(executionService: appState.executionService)
                                .frame(height: terminalHeight)
                        }
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

                        if currentLanguage == "java" {
                            Text("LSP: \(lspStatusMessage.isEmpty ? "Starting..." : lspStatusMessage)")
                                .font(.system(size: 11))
                                .foregroundStyle(
                                    (lspStatusMessage == "Ready" || lspStatusMessage == "Connected") ? Color.green : Color.secondary
                                )
                        }

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
                .background(Color(nsColor: .windowBackgroundColor))
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

                Button(action: stopCode) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(appState.executionService.status != .running)
                
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
                    if showTerminal {
                        terminalDragStartHeight = terminalHeight
                    }
                }) {
                    Label("Terminal", systemImage: "terminal")
                        .foregroundStyle(showTerminal ? Color.accentColor : Color.primary)
                }
                
                Button(action: {
                    withAnimation { showGitPanel.toggle() }
                }) {
                    Label("Git", systemImage: "branch")
                        .foregroundStyle(showGitPanel ? Color.accentColor : Color.primary)
                }
            }
        }
        .sheet(isPresented: $showGitPanel) {
            GitPanelSheet(session: session)
        }
    }
    
    // MARK: - Helpers
    
    private func runCode() {
        withAnimation { showTerminal = true }
        terminalDragStartHeight = terminalHeight
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

    private func stopCode() {
        appState.executionService.stopRunning()
    }
    
    private func loadFile(_ file: FileItem) {
        guard !file.isDirectory else { return }
        
        isLoadingFile = true
        currentLanguage = FileIconHelper.languageName(for: file.name)
        lspStatusMessage = currentLanguage == "java" ? "Starting..." : ""

        if currentLanguage == "java" {
            Task {
                let isReady = await appState.ensureJavaLSPReady()

                await MainActor.run {
                    if currentLanguage == "java" {
                        lspStatusMessage = isReady ? "Initializing..." : appState.javaLSPBootstrapMessage()
                    }
                }
            }
        }
        
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

// MARK: - Git Panel Sheet

struct GitPanelSheet: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    private var gitService: GitService {
        GitService(runner: DockerService())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Changes").tag(0)
                    Text("History").tag(1)
                    Text("Stash").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Content
                switch selectedTab {
                case 0:
                    GitPanelView(gitService: gitService, containerName: session.containerName)
                case 1:
                    GitHistoryView(gitService: gitService, containerName: session.containerName, showsHeader: false)
                case 2:
                    GitStashView(gitService: gitService, containerName: session.containerName, showsHeader: false)
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Git")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
