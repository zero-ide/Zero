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
    
    let containerName: String
    let onFileSelect: (FileItem) -> Void
    
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
                ProgressView()
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
                                onSelect: onFileSelect
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
        defer { isLoading = false }
        
        // TODO: docker exec ls -la /workspace 실행해서 파일 목록 가져오기
        // 지금은 mock 데이터
        files = [
            FileItem(name: "src", path: "/workspace/src", isDirectory: true, children: [
                FileItem(name: "main.swift", path: "/workspace/src/main.swift", isDirectory: false),
                FileItem(name: "utils.swift", path: "/workspace/src/utils.swift", isDirectory: false)
            ]),
            FileItem(name: "README.md", path: "/workspace/README.md", isDirectory: false),
            FileItem(name: "Package.swift", path: "/workspace/Package.swift", isDirectory: false)
        ]
    }
}

struct FileRowView: View {
    let file: FileItem
    @Binding var selectedFile: FileItem?
    let level: Int
    let onSelect: (FileItem) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<level, id: \.self) { _ in
                    Spacer().frame(width: 16)
                }
                
                // Expand/Collapse button for directories
                if file.isDirectory {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                    isExpanded.toggle()
                } else {
                    selectedFile = file
                    onSelect(file)
                }
            }
            
            // Children
            if file.isDirectory && isExpanded, let children = file.children {
                ForEach(children) { child in
                    FileRowView(
                        file: child,
                        selectedFile: $selectedFile,
                        level: level + 1,
                        onSelect: onSelect
                    )
                }
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
        default: return "doc"
        }
    }
}
