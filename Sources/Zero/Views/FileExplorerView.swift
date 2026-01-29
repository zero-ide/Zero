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
    let onFileSelect: (FileItem) -> Void
    
    private var fileService: FileService {
        FileService(containerName: containerName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (글래스모피즘)
            HStack {
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: refreshFiles) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
            
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
        let (iconName, iconColor) = fileIconInfo(for: file)
        
        if file.isDirectory {
            Image(systemName: isExpanded ? "folder.fill" : "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.yellow)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
        }
    }
    
    private func fileIconInfo(for file: FileItem) -> (String, Color) {
        let ext = (file.name as NSString).pathExtension.lowercased()
        let name = file.name.lowercased()
        
        // Special files
        if name == "dockerfile" { return ("shippingbox.fill", .blue) }
        if name == "readme.md" { return ("book.fill", .blue) }
        if name == ".gitignore" { return ("eye.slash", .orange) }
        if name.contains("license") { return ("doc.text.fill", .green) }
        
        switch ext {
        case "swift": return ("swift", .orange)
        case "java": return ("cup.and.saucer.fill", .red)
        case "kt", "kts": return ("k.square.fill", .purple)
        case "js": return ("j.square.fill", .yellow)
        case "ts": return ("t.square.fill", .blue)
        case "py": return ("p.square.fill", .cyan)
        case "rb": return ("r.square.fill", .red)
        case "go": return ("g.square.fill", .cyan)
        case "rs": return ("r.square.fill", .orange)
        case "json": return ("curlybraces", .yellow)
        case "xml", "plist": return ("chevron.left.forwardslash.chevron.right", .orange)
        case "html": return ("globe", .orange)
        case "css", "scss", "sass": return ("paintbrush.fill", .pink)
        case "md", "markdown": return ("doc.richtext.fill", .blue)
        case "yml", "yaml": return ("list.bullet.rectangle.fill", .pink)
        case "sh", "bash", "zsh": return ("terminal.fill", .green)
        case "sql": return ("cylinder.fill", .blue)
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return ("photo.fill", .purple)
        case "pdf": return ("doc.fill", .red)
        case "zip", "tar", "gz", "rar": return ("doc.zipper", .gray)
        case "gradle": return ("g.square.fill", .green)
        case "properties": return ("gearshape.fill", .gray)
        case "env": return ("key.fill", .yellow)
        case "lock": return ("lock.fill", .gray)
        default: return ("doc.fill", .secondary)
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
}
