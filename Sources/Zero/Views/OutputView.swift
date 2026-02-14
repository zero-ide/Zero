import AppKit
import SwiftUI

struct OutputView: View {
    @ObservedObject var executionService: ExecutionService
    @State private var isWrapped = true

    private var displayOutput: String {
        executionService.output.isEmpty ? "Ready to run." : executionService.output
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Output", systemImage: "terminal.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                
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
                    Text(displayOutput)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: isWrapped ? .infinity : nil, alignment: .leading)
                        .fixedSize(horizontal: !isWrapped, vertical: false)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("bottom")
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
