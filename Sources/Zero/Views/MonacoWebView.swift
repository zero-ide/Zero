import SwiftUI
import WebKit

struct MonacoWebView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    var enableLSP: Bool = false
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "editorReady")
        config.userContentController.add(context.coordinator, name: "contentChanged")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        // Load Monaco HTML (LSP or standard)
        let htmlResource = enableLSP ? "monaco-lsp" : "monaco"
        if let htmlPath = Bundle.main.path(forResource: htmlResource, ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath) {
            webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://cdnjs.cloudflare.com"))
        } else {
            // Fallback: Load from embedded string
            let html = enableLSP ? Self.monacoLSPHTML : Self.monacoHTML
            webView.loadHTMLString(html, baseURL: URL(string: "https://cdnjs.cloudflare.com"))
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update content when binding changes
        if context.coordinator.isReady {
            let escaped = content.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            webView.evaluateJavaScript("setContent('\(escaped)', '\(language)')")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MonacoWebView
        var webView: WKWebView?
        var isReady = false
        
        init(_ parent: MonacoWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "editorReady" {
                isReady = true
                parent.onReady?()
                
                // Set initial content
                let escaped = parent.content.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                webView?.evaluateJavaScript("setContent('\(escaped)', '\(parent.language)')")
            } else if message.name == "contentChanged", let body = message.body as? String {
                parent.content = body
            }
        }
    }
    
    // Embedded Monaco LSP HTML as fallback
    static let monacoLSPHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body { height: 100%; overflow: hidden; background: #ffffff; }
            #editor { width: 100%; height: 100%; }
            #status { 
                position: fixed; 
                bottom: 0; 
                right: 0; 
                padding: 4px 8px; 
                background: #007acc; 
                color: white; 
                font-size: 12px;
                display: none;
            }
            #status.connected { display: block; background: #4caf50; }
            #status.disconnected { display: block; background: #f44336; }
        </style>
    </head>
    <body>
        <div id="editor"></div>
        <div id="status">LSP</div>
        
        <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs/loader.min.js"></script>
        <script>
            let editor;
            let lspSocket;
            let lspEnabled = false;
            
            require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('editor'), {
                    value: '',
                    language: 'java',
                    theme: 'vs',
                    fontSize: 14,
                    minimap: { enabled: true },
                    automaticLayout: true,
                    quickSuggestions: true,
                    suggestOnTriggerCharacters: true
                });
                
                window.webkit.messageHandlers.editorReady.postMessage('ready');
                
                let changeTimeout;
                editor.onDidChangeModelContent(() => {
                    clearTimeout(changeTimeout);
                    changeTimeout = setTimeout(() => {
                        window.webkit.messageHandlers.contentChanged.postMessage(editor.getValue());
                    }, 100);
                });
                
                editor.focus();
            });
            
            function connectLSP() {
                const statusEl = document.getElementById('status');
                statusEl.className = 'disconnected';
                statusEl.textContent = 'LSP Connecting...';
                
                lspSocket = new WebSocket('ws://localhost:8080');
                
                lspSocket.onopen = () => {
                    lspEnabled = true;
                    statusEl.className = 'connected';
                    statusEl.textContent = 'LSP Connected';
                    
                    lspSocket.send(JSON.stringify({
                        jsonrpc: '2.0',
                        id: 1,
                        method: 'initialize',
                        params: {
                            processId: null,
                            rootUri: 'file:///workspace',
                            capabilities: {}
                        }
                    }));
                };
                
                lspSocket.onclose = () => {
                    lspEnabled = false;
                    statusEl.className = 'disconnected';
                    statusEl.textContent = 'LSP Disconnected';
                };
                
                lspSocket.onerror = () => {
                    statusEl.className = 'disconnected';
                    statusEl.textContent = 'LSP Error';
                };
            }
            
            function setContent(content, language) {
                if (editor) {
                    monaco.editor.setModelLanguage(editor.getModel(), language || 'java');
                    editor.setValue(content);
                }
            }
            
            function enableLSP() {
                connectLSP();
            }
        </script>
    </body>
    </html>
    """
    
    // Embedded Monaco HTML as fallback
    static let monacoHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body { height: 100%; overflow: hidden; background: #1e1e1e; }
            #editor { width: 100%; height: 100%; }
        </style>
    </head>
    <body>
        <div id="editor"></div>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs/loader.min.js"></script>
        <script>
            let editor;
            require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('editor'), {
                    value: '',
                    language: 'plaintext',
                    theme: 'vs-dark',
                    fontSize: 14,
                    minimap: { enabled: true },
                    automaticLayout: true
                });
                
                // Add change listener
                editor.onDidChangeModelContent(() => {
                    window.webkit.messageHandlers.contentChanged.postMessage(editor.getValue());
                });
                
                window.webkit.messageHandlers.editorReady.postMessage('ready');
            });
            function setContent(content, language) {
                if (editor) {
                    monaco.editor.setModelLanguage(editor.getModel(), language || 'plaintext');
                    editor.setValue(content);
                }
            }
            function getContent() { return editor ? editor.getValue() : ''; }
        </script>
    </body>
    </html>
    """
}