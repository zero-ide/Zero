import SwiftUI

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileItem]?
    var isExpanded: Bool = false
    
    var isHidden: Bool {
        name.hasPrefix(".")
    }
}

struct FileExplorerView: View {
    @Binding var selectedFile: FileItem?
    @State private var files: [FileItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    let containerName: String
    let projectName: String
    let onFileSelect: (FileItem) -> Void
    
    private var fileService: FileService {
        FileService(containerName: containerName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project Title
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 12)
            
            // File Tree
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { refreshFiles() }
                        .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No files")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(minWidth: 200)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .task {
            await loadFiles()
        }
    }
    
    private func refreshFiles() {
        Task { await loadFiles() }
    }
    
    private func loadFiles() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            files = try await fileService.listDirectory()
        } catch {
            errorMessage = "Failed to load files: \(error.localizedDescription)"
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
    @State private var isHovered = false
    
    private var isSelected: Bool {
        selectedFile?.id == file.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indentation
                if level > 0 {
                    Spacer().frame(width: CGFloat(level) * 16)
                }
                
                // Expand/Collapse button
                if file.isDirectory {
                    Button(action: { toggleExpand() }) {
                        if isLoadingChildren {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 14)
                }
                
                // Icon (컬러)
                fileIconView
                    .frame(width: 16, height: 16)
                
                // Name
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(file.isHidden ? .tertiary : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
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
        .opacity(file.isHidden ? 0.6 : 1.0)
    }
    
    @ViewBuilder
    private var fileIconView: some View {
        let info = FileIconHelper.iconInfo(for: file.name, isDirectory: file.isDirectory)
        Image(systemName: info.name)
            .font(.system(size: file.isDirectory ? 14 : 13))
            .foregroundStyle(info.color)
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
}
