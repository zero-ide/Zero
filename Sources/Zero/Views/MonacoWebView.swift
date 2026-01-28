import SwiftUI
import WebKit

struct MonacoWebView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "editorReady")
        config.userContentController.add(context.coordinator, name: "contentChanged")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        // Load Monaco HTML
        if let htmlPath = Bundle.main.path(forResource: "monaco", ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath) {
            webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://cdnjs.cloudflare.com"))
        } else {
            // Fallback: Load from embedded string
            let html = Self.monacoHTML
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
            }
        }
    }
    
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
