import SwiftUI

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileItem]?
    var isExpanded: Bool = false
}

struct FileExplorerView: View {
    @Binding var selectedFile: FileItem?
    @State private var files: [FileItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    let containerName: String
    let onFileSelect: (FileItem) -> Void
    
    private var fileService: FileService {
        FileService(containerName: containerName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                Spacer()
                Button(action: refreshFiles) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // File Tree
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        refreshFiles()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                Text("No files")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(files) { file in
                            FileRowView(
                                file: file,
                                selectedFile: $selectedFile,
                                level: 0,
                                onSelect: onFileSelect,
                                onExpand: loadChildren
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 200)
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            await loadFiles()
        }
    }
    
    private func refreshFiles() {
        Task {
            await loadFiles()
        }
    }
    
    private func loadFiles() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            files = try await fileService.listDirectory()
        } catch {
            errorMessage = "Failed to load files: \(error.localizedDescription)"
            // Fallback to mock data for development
            files = [
                FileItem(name: "README.md", path: "/workspace/README.md", isDirectory: false),
                FileItem(name: "src", path: "/workspace/src", isDirectory: true, children: [])
            ]
        }
    }
    
    private func loadChildren(for file: FileItem) async -> [FileItem] {
        guard file.isDirectory else { return [] }
        do {
            return try await fileService.listDirectory(path: file.path)
        } catch {
            return []
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    @Binding var selectedFile: FileItem?
    let level: Int
    let onSelect: (FileItem) -> Void
    let onExpand: (FileItem) async -> [FileItem]
    
    @State private var isExpanded = false
    @State private var children: [FileItem] = []
    @State private var isLoadingChildren = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<level, id: \.self) { _ in
                    Spacer().frame(width: 16)
                }
                
                // Expand/Collapse button for directories
                if file.isDirectory {
                    Button(action: { toggleExpand() }) {
                        if isLoadingChildren {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16)
                } else {
                    Spacer().frame(width: 16)
                }
                
                // Icon
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon(for: file.name))
                    .foregroundStyle(file.isDirectory ? .yellow : .secondary)
                    .font(.system(size: 14))
                
                // Name
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selectedFile?.id == file.id ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if file.isDirectory {
                    toggleExpand()
                } else {
                    selectedFile = file
                    onSelect(file)
                }
            }
            
            // Children
            if file.isDirectory && isExpanded {
                ForEach(children) { child in
                    FileRowView(
                        file: child,
                        selectedFile: $selectedFile,
                        level: level + 1,
                        onSelect: onSelect,
                        onExpand: onExpand
                    )
                }
            }
        }
    }
    
    private func toggleExpand() {
        if isExpanded {
            isExpanded = false
        } else {
            isLoadingChildren = true
            Task {
                children = await onExpand(file)
                isExpanded = true
                isLoadingChildren = false
            }
        }
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts": return "curlybraces"
        case "json": return "doc.text"
        case "md": return "doc.richtext"
        case "html", "css": return "globe"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "java": return "cup.and.saucer"
        case "sh": return "terminal"
        default: return "doc"
        }
    }
}
