import SwiftUI
import AppKit
import CodeEditTextView
import Highlightr

struct CodeEditorView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        
        // Highlightr 기반 TextView 사용
        let textView = HighlightedTextView(frame: .zero)
        textView.setup(language: language, theme: "atom-one-dark")
        textView.text = content
        textView.onTextChange = { newText in
            context.coordinator.parent.content = newText
        }
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        DispatchQueue.main.async {
            onReady?()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        if textView.text != content && !context.coordinator.isEditing {
            textView.text = content
            textView.applyHighlighting(language: language)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator {
        var parent: CodeEditorView
        var textView: HighlightedTextView?
        var isEditing = false
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
    }
}

// MARK: - Highlightr 기반 TextView
class HighlightedTextView: NSTextView {
    private var highlightr: Highlightr?
    private var currentLanguage: String = "plaintext"
    var onTextChange: ((String) -> Void)?
    
    var text: String {
        get { string }
        set {
            string = newValue
            applyHighlighting(language: currentLanguage)
        }
    }
    
    func setup(language: String, theme: String) {
        self.currentLanguage = language
        
        // Highlightr 초기화
        highlightr = Highlightr()
        highlightr?.setTheme(to: theme)
        
        // TextView 설정
        isEditable = true
        isSelectable = true
        allowsUndo = true
        isRichText = false
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        insertionPointColor = .white
        textColor = .white
        
        // 여백 설정
        textContainerInset = NSSize(width: 8, height: 8)
    }
    
    func applyHighlighting(language: String) {
        currentLanguage = language
        guard let highlightr = highlightr,
              let attributed = highlightr.highlight(string, as: mapLanguage(language)) else {
            return
        }
        
        // 커서 위치 저장
        let selectedRanges = self.selectedRanges
        
        // Highlighting 적용
        textStorage?.setAttributedString(attributed)
        
        // 폰트 재적용 (Highlightr가 폰트를 바꿀 수 있음)
        textStorage?.addAttribute(.font, 
                                   value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                                   range: NSRange(location: 0, length: textStorage?.length ?? 0))
        
        // 커서 위치 복원
        self.selectedRanges = selectedRanges
    }
    
    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
        
        // 타이핑 중 실시간 highlighting (debounce 필요할 수 있음)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyHighlighting(language: self?.currentLanguage ?? "plaintext")
        }
    }
    
    private func mapLanguage(_ lang: String) -> String {
        // Zero 언어명 -> Highlightr 언어명 매핑
        switch lang {
        case "swift": return "swift"
        case "java": return "java"
        case "javascript": return "javascript"
        case "typescript": return "typescript"
        case "python": return "python"
        case "json": return "json"
        case "html": return "xml"
        case "css": return "css"
        case "markdown": return "markdown"
        case "yaml": return "yaml"
        case "xml": return "xml"
        case "shell": return "bash"
        case "c": return "c"
        case "cpp": return "cpp"
        case "go": return "go"
        case "rust": return "rust"
        case "ruby": return "ruby"
        case "php": return "php"
        case "sql": return "sql"
        case "dockerfile": return "dockerfile"
        case "kotlin": return "kotlin"
        case "gradle": return "gradle"
        default: return "plaintext"
        }
    }
}
