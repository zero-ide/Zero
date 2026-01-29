import SwiftUI
import AppKit
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
        scrollView.backgroundColor = .white
        
        let textView = HighlightedTextView(frame: .zero)
        textView.setup(language: language)
        textView.onTextChange = { newText in
            context.coordinator.isEditing = true
            context.coordinator.parent.content = newText
            context.coordinator.isEditing = false
        }
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        // 초기 content 설정
        DispatchQueue.main.async {
            textView.setText(content, language: language)
            onReady?()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // 외부에서 content 변경 시에만 업데이트
        if !context.coordinator.isEditing && textView.string != content {
            textView.setText(content, language: language)
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

// MARK: - Syntax Highlighting TextView
class HighlightedTextView: NSTextView {
    private var highlightr: Highlightr?
    private var currentLanguage: String = "plaintext"
    var onTextChange: ((String) -> Void)?
    
    func setup(language: String) {
        self.currentLanguage = language
        
        // Highlightr 초기화 (라이트 테마)
        highlightr = Highlightr()
        highlightr?.setTheme(to: "xcode")
        
        // TextView 기본 설정
        isEditable = true
        isSelectable = true
        allowsUndo = true
        isRichText = true  // attributed string 지원
        usesFontPanel = false
        usesRuler = false
        
        // 배경 & 색상 (화이트)
        drawsBackground = true
        backgroundColor = .white
        insertionPointColor = .black
        
        // 폰트
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        // 여백
        textContainerInset = NSSize(width: 12, height: 12)
        textContainer?.lineFragmentPadding = 0
        
        // 자동 크기 조절
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
    }
    
    func setText(_ text: String, language: String) {
        currentLanguage = language
        
        // Highlighting 시도
        if let highlightr = highlightr,
           let highlighted = highlightr.highlight(text, as: mapLanguage(language)) {
            
            // 폰트 적용 (Highlightr 기본 폰트 대체)
            let mutableAttr = NSMutableAttributedString(attributedString: highlighted)
            let fullRange = NSRange(location: 0, length: mutableAttr.length)
            mutableAttr.addAttribute(.font, 
                                     value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), 
                                     range: fullRange)
            
            textStorage?.setAttributedString(mutableAttr)
        } else {
            // Fallback: plain text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.black
            ]
            let plainAttr = NSAttributedString(string: text, attributes: attrs)
            textStorage?.setAttributedString(plainAttr)
        }
    }
    
    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
    }
    
    private func mapLanguage(_ lang: String) -> String {
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
        default: return lang  // 그대로 전달
        }
    }
}
