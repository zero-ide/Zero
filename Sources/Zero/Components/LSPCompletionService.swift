import SwiftUI
import Combine

/// LSP 자동완성 서비스 - CodeEditorView와 함께 사용
@MainActor
class LSPCompletionService: ObservableObject {
    @Published var suggestions: [String] = []
    @Published var isLoading = false
    @Published var showSuggestions = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        let url = URL(string: "ws://localhost:8080")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self?.handleLSPMessage(text)
                    }
                case .failure:
                    break
                }
                self?.webSocketTask?.receive { _ in }
            }
        }
        
        webSocketTask?.resume()
        
        // Send initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendInitialize()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    func requestCompletion(fileContent: String, line: Int, column: Int) {
        guard let task = webSocketTask else { return }
        
        isLoading = true
        
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 2,
            "method": "textDocument/completion",
            "params": [
                "textDocument": ["uri": "file:///workspace/Main.java"],
                "position": ["line": line - 1, "character": column - 1]
            ]
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: message),
           let text = String(data: data, encoding: .utf8) {
            task.send(.string(text)) { _ in }
        }
    }
    
    private func sendInitialize() {
        guard let task = webSocketTask else { return }
        
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "processId": nil,
                "rootUri": "file:///workspace",
                "capabilities": [:]
            ]
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: message),
           let text = String(data: data, encoding: .utf8) {
            task.send(.string(text)) { _ in }
        }
        
        // Send didOpen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let didOpen: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "textDocument/didOpen",
                "params": [
                    "textDocument": [
                        "uri": "file:///workspace/Main.java",
                        "languageId": "java",
                        "version": 1,
                        "text": ""
                    ]
                ]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: didOpen),
               let text = String(data: data, encoding: .utf8) {
                task.send(.string(text)) { _ in }
            }
        }
    }
    
    private func handleLSPMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let result = json["result"] as? [String: Any],
           let items = result["items"] as? [[String: Any]] {
            suggestions = items.compactMap { $0["label"] as? String }
            showSuggestions = !suggestions.isEmpty
            isLoading = false
        }
    }
}

/// LSP 자동완성 제안 뷰
struct LSPCompletionView: View {
    @StateObject private var service = LSPCompletionService()
    let language: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if service.isLoading {
                ProgressView()
                    .padding(8)
            } else if service.showSuggestions {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(service.suggestions, id: \.self) { suggestion in
                            Button(action: {
                                onSelect(suggestion)
                                service.showSuggestions = false
                            }) {
                                Text(suggestion)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .onAppear {
            if language == "java" {
                service.connect()
            }
        }
        .onDisappear {
            service.disconnect()
        }
    }
}
