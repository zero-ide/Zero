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
    @State private var operationErrorMessage: String?
    @State private var showCreateFileSheet = false
    @State private var showCreateFolderSheet = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var actionTarget: FileItem?
    @State private var newItemName = ""

    let containerName: String
    let projectName: String
    let onFileSelect: (FileItem) -> Void

    private var fileService: FileService {
        FileService(containerName: containerName)
    }

    private let workspacePath = "/workspace"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button("New File") {
                        prepareCreateFile()
                    }

                    Button("New Folder") {
                        prepareCreateFolder()
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let operationErrorMessage {
                Text(operationErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal, 12)

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
                                onExpand: loadChildren,
                                onCreateFile: { prepareCreateFile(in: $0) },
                                onCreateFolder: { prepareCreateFolder(in: $0) },
                                onRename: { prepareRename($0) },
                                onDelete: { prepareDelete($0) }
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
        .sheet(isPresented: $showCreateFileSheet) {
            fileOperationSheet(
                title: "Create File",
                prompt: "Enter file name",
                actionLabel: "Create"
            ) {
                await createFile()
            }
        }
        .sheet(isPresented: $showCreateFolderSheet) {
            fileOperationSheet(
                title: "Create Folder",
                prompt: "Enter folder name",
                actionLabel: "Create"
            ) {
                await createFolder()
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            fileOperationSheet(
                title: "Rename",
                prompt: "Enter new name",
                actionLabel: "Rename"
            ) {
                await renameItem()
            }
        }
        .confirmationDialog("Delete Item", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteItem() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(actionTarget?.name ?? "this item")?")
        }
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

    private func prepareCreateFile(in parent: FileItem? = nil) {
        actionTarget = parent
        newItemName = ""
        operationErrorMessage = nil
        showCreateFileSheet = true
    }

    private func prepareCreateFolder(in parent: FileItem? = nil) {
        actionTarget = parent
        newItemName = ""
        operationErrorMessage = nil
        showCreateFolderSheet = true
    }

    private func prepareRename(_ item: FileItem) {
        actionTarget = item
        newItemName = item.name
        operationErrorMessage = nil
        showRenameSheet = true
    }

    private func prepareDelete(_ item: FileItem) {
        actionTarget = item
        operationErrorMessage = nil
        showDeleteConfirmation = true
    }

    private func createFile() async {
        do {
            let directoryPath = targetDirectoryPath()
            let path = ((directoryPath as NSString).appendingPathComponent(newItemName) as NSString).standardizingPath
            try await fileService.createFile(path: path)
            showCreateFileSheet = false
            await loadFiles()
        } catch {
            operationErrorMessage = "Failed to create file: \(error.localizedDescription)"
        }
    }

    private func createFolder() async {
        do {
            let directoryPath = targetDirectoryPath()
            let path = ((directoryPath as NSString).appendingPathComponent(newItemName) as NSString).standardizingPath
            try await fileService.createDirectory(path: path)
            showCreateFolderSheet = false
            await loadFiles()
        } catch {
            operationErrorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    private func renameItem() async {
        guard let actionTarget else { return }
        do {
            let parentDirectory = (actionTarget.path as NSString).deletingLastPathComponent
            let destinationPath = ((parentDirectory as NSString).appendingPathComponent(newItemName) as NSString).standardizingPath
            try await fileService.renameItem(at: actionTarget.path, to: destinationPath)
            showRenameSheet = false
            await loadFiles()
        } catch {
            operationErrorMessage = "Failed to rename item: \(error.localizedDescription)"
        }
    }

    private func deleteItem() async {
        guard let actionTarget else { return }
        do {
            try await fileService.deleteItem(at: actionTarget.path, recursive: actionTarget.isDirectory)
            if selectedFile?.path == actionTarget.path {
                selectedFile = nil
            }
            await loadFiles()
        } catch {
            operationErrorMessage = "Failed to delete item: \(error.localizedDescription)"
        }
    }

    private func targetDirectoryPath() -> String {
        if let actionTarget {
            if actionTarget.isDirectory {
                return actionTarget.path
            }
            return (actionTarget.path as NSString).deletingLastPathComponent
        }

        if let selectedFile {
            if selectedFile.isDirectory {
                return selectedFile.path
            }
            return (selectedFile.path as NSString).deletingLastPathComponent
        }

        return workspacePath
    }

    @ViewBuilder
    private func fileOperationSheet(
        title: String,
        prompt: String,
        actionLabel: String,
        onSubmit: @escaping () async -> Void
    ) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                TextField(prompt, text: $newItemName)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                HStack {
                    Button("Cancel") {
                        showCreateFileSheet = false
                        showCreateFolderSheet = false
                        showRenameSheet = false
                    }

                    Spacer()

                    Button(actionLabel) {
                        Task { await onSubmit() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 420, minHeight: 180)
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    @Binding var selectedFile: FileItem?
    let level: Int
    let onSelect: (FileItem) -> Void
    let onExpand: (FileItem) async -> [FileItem]
    let onCreateFile: (FileItem) -> Void
    let onCreateFolder: (FileItem) -> Void
    let onRename: (FileItem) -> Void
    let onDelete: (FileItem) -> Void

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
                if level > 0 {
                    Spacer().frame(width: CGFloat(level) * 16)
                }

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

                fileIconView
                    .frame(width: 16, height: 16)

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
            .contextMenu {
                if file.isDirectory {
                    Button("New File") {
                        onCreateFile(file)
                    }

                    Button("New Folder") {
                        onCreateFolder(file)
                    }
                }

                Button("Rename") {
                    onRename(file)
                }

                Button("Delete", role: .destructive) {
                    onDelete(file)
                }
            }

            if file.isDirectory && isExpanded {
                ForEach(children) { child in
                    FileRowView(
                        file: child,
                        selectedFile: $selectedFile,
                        level: level + 1,
                        onSelect: onSelect,
                        onExpand: onExpand,
                        onCreateFile: onCreateFile,
                        onCreateFolder: onCreateFolder,
                        onRename: onRename,
                        onDelete: onDelete
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
