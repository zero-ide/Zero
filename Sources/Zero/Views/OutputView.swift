import SwiftUI

struct OutputView: View {
    @ObservedObject var executionService: ExecutionService
    
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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Output Log
            ScrollViewReader { proxy in
                ScrollView {
                    Text(executionService.output.isEmpty ? "Ready to run." : executionService.output)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: executionService.output) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(height: 150)
    }
}
