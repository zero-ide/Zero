import AppKit
import SwiftUI

struct OutputView: View {
    @ObservedObject var executionService: ExecutionService
    @State private var isWrapped = true
    @State private var showErrorsOnly = false

    private var allOutputLines: [OutputLogLine] {
        OutputLogHighlighter.lines(from: executionService.output)
    }

    private var displayedLines: [OutputLogLine] {
        if executionService.output.isEmpty {
            return [OutputLogLine(text: "Ready to run.", isError: false)]
        }

        let filtered = OutputLogHighlighter.filteredLines(from: executionService.output, errorsOnly: showErrorsOnly)
        if filtered.isEmpty && showErrorsOnly {
            return [OutputLogLine(text: "No error lines detected.", isError: false)]
        }

        return filtered
    }

    private var hasErrorLines: Bool {
        allOutputLines.contains(where: \.isError)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Output", systemImage: "terminal.fill")
                    .font(.headline)
                
                Spacer()
                
                if executionService.status == .running {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }
                
                // Status Text
                switch executionService.status {
                case .success:
                    Text("Succeeded")
                        .font(.caption2)
                        .foregroundColor(.green)
                case .failed:
                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.red)
                case .running:
                    Text("Running...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                case .idle:
                    EmptyView()
                }

                HStack(spacing: 8) {
                    Button {
                        showErrorsOnly.toggle()
                    } label: {
                        Image(systemName: showErrorsOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(showErrorsOnly ? Color.red : Color.primary)
                    .disabled(!hasErrorLines && !showErrorsOnly)
                    .help(showErrorsOnly ? "Show all output" : "Show errors only")
                    .accessibilityLabel(showErrorsOnly ? "Show all output lines" : "Show error output lines")

                    Button {
                        isWrapped.toggle()
                    } label: {
                        Image(systemName: isWrapped ? "text.line.first.and.arrowtriangle.forward" : "text.justify")
                    }
                    .buttonStyle(.borderless)
                    .help(isWrapped ? "Disable wrap" : "Enable wrap")
                    .accessibilityLabel(isWrapped ? "Disable output wrap" : "Enable output wrap")

                    Button {
                        copyOutput()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .disabled(executionService.output.isEmpty)
                    .help("Copy output")
                    .accessibilityLabel("Copy output")

                    Button {
                        executionService.clearOutput()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(executionService.output.isEmpty)
                    .help("Clear output")
                    .accessibilityLabel("Clear output")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Output Log
            ScrollViewReader { proxy in
                ScrollView(isWrapped ? .vertical : [.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(displayedLines.enumerated()), id: \.offset) { _, line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(line.isError ? Color.red : Color.primary)
                                .frame(maxWidth: isWrapped ? .infinity : nil, alignment: .leading)
                                .fixedSize(horizontal: !isWrapped, vertical: true)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(8)
                    .textSelection(.enabled)
                }
                .onChange(of: executionService.output) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(executionService.output, forType: .string)
    }
}
