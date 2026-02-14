import SwiftUI
import WebKit

struct MonacoWebView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var documentPath: String?
    var enableLSP: Bool = false
    var onReady: (() -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    var onLSPStatusChange: ((String) -> Void)?

    static func escapeForJavaScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    static func fileURI(from path: String?) -> String {
        let defaultPath = "/workspace/Main.java"
        let resolvedPath: String
        if let path, !path.isEmpty {
            resolvedPath = path
        } else {
            resolvedPath = defaultPath
        }
        let normalizedPath = resolvedPath.hasPrefix("/") ? resolvedPath : "/\(resolvedPath)"
        return "file://\(normalizedPath)"
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "editorReady")
        config.userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController.add(context.coordinator, name: "cursorChanged")
        config.userContentController.add(context.coordinator, name: "lspStatus")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let resourceName = enableLSP ? "monaco-lsp" : "monaco"

        // Load Monaco HTML
        if let htmlPath = Bundle.main.path(forResource: resourceName, ofType: "html"),
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
        context.coordinator.parent = self
        context.coordinator.applyCurrentState()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MonacoWebView
        var webView: WKWebView?
        var isReady = false
        private var lastContent = ""
        private var lastLanguage = ""
        private var lastFileURI = ""
        private var lspEnabled = false

        init(_ parent: MonacoWebView) {
            self.parent = parent
        }

        func applyCurrentState(force: Bool = false) {
            guard isReady, let webView else { return }

            if force || parent.content != lastContent {
                let escapedContent = MonacoWebView.escapeForJavaScriptLiteral(parent.content)
                let escapedLanguage = MonacoWebView.escapeForJavaScriptLiteral(parent.language)
                webView.evaluateJavaScript("setContent('\(escapedContent)', '\(escapedLanguage)')")
                lastContent = parent.content
            }

            if force || parent.language != lastLanguage {
                let escapedLanguage = MonacoWebView.escapeForJavaScriptLiteral(parent.language)
                webView.evaluateJavaScript("setLanguage('\(escapedLanguage)')")
                lastLanguage = parent.language
            }

            let fileURI = MonacoWebView.fileURI(from: parent.documentPath)
            if force || fileURI != lastFileURI {
                let escapedURI = MonacoWebView.escapeForJavaScriptLiteral(fileURI)
                webView.evaluateJavaScript("setDocumentPath('\(escapedURI)')")
                lastFileURI = fileURI
            }

            if force || parent.enableLSP != lspEnabled {
                webView.evaluateJavaScript(parent.enableLSP ? "enableLSP()" : "disableLSP()")
                lspEnabled = parent.enableLSP
            }
        }

        private func toInt(_ value: Any?) -> Int? {
            if let intValue = value as? Int {
                return intValue
            }
            if let doubleValue = value as? Double {
                return Int(doubleValue)
            }
            if let stringValue = value as? String {
                return Int(stringValue)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "editorReady" {
                isReady = true
                parent.onReady?()

                applyCurrentState(force: true)
            } else if message.name == "contentChanged", let body = message.body as? String {
                if body != parent.content {
                    lastContent = body
                    parent.content = body
                }
            } else if message.name == "cursorChanged", let body = message.body as? [String: Any] {
                guard let line = toInt(body["line"]), let column = toInt(body["column"]) else { return }
                parent.onCursorChange?(line, column)
            } else if message.name == "lspStatus", let body = message.body as? String {
                parent.onLSPStatusChange?(body)
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

            function postToNative(name, payload) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                        window.webkit.messageHandlers[name].postMessage(payload);
                    }
                } catch (_) {}
            }

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
                    postToNative('contentChanged', editor.getValue());
                });

                editor.onDidChangeCursorPosition((event) => {
                    postToNative('cursorChanged', {
                        line: event.position.lineNumber,
                        column: event.position.column
                    });
                });

                postToNative('editorReady', 'ready');
            });

            function setContent(content, language) {
                if (editor) {
                    const safeLanguage = language || 'plaintext';
                    monaco.editor.setModelLanguage(editor.getModel(), safeLanguage);
                    if (editor.getValue() !== content) {
                        editor.setValue(content);
                    }
                }
            }

            function setLanguage(language) {
                if (editor) {
                    monaco.editor.setModelLanguage(editor.getModel(), language || 'plaintext');
                }
            }

            function setDocumentPath(_) {}
            function enableLSP() { postToNative('lspStatus', 'Unavailable'); }
            function disableLSP() { postToNative('lspStatus', 'Unavailable'); }
            function getContent() { return editor ? editor.getValue() : ''; }
        </script>
    </body>
    </html>
    """
}
