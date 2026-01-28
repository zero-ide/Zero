import SwiftUI
import AppKit
import Highlightr

struct CodeEditorView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        
        let textView = HighlightedTextView(frame: .zero)
        textView.setup(language: language)
        textView.onTextChange = { newText in
            context.coordinator.isEditing = true
            context.coordinator.parent.content = newText
            context.coordinator.isEditing = false
        }
        textView.onCursorChange = { line, column in
            context.coordinator.parent.onCursorChange?(line, column)
        }
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        DispatchQueue.main.async {
            textView.setText(content, language: language)
            textView.window?.makeFirstResponder(textView)
            onReady?()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
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
    var onCursorChange: ((Int, Int) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        return result
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    
    func setup(language: String) {
        self.currentLanguage = language
        
        highlightr = Highlightr()
        highlightr?.setTheme(to: "xcode")
        
        isEditable = true
        isSelectable = true
        allowsUndo = true
        isRichText = true
        usesFontPanel = false
        usesRuler = false
        
        drawsBackground = true
        backgroundColor = .white
        insertionPointColor = .black
        
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        textContainerInset = NSSize(width: 16, height: 16)
        textContainer?.lineFragmentPadding = 0
        
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
    }
    
    func setText(_ text: String, language: String) {
        currentLanguage = language
        
        if let highlightr = highlightr,
           let highlighted = highlightr.highlight(text, as: mapLanguage(language)) {
            
            let mutableAttr = NSMutableAttributedString(attributedString: highlighted)
            let fullRange = NSRange(location: 0, length: mutableAttr.length)
            mutableAttr.addAttribute(.font, 
                                     value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), 
                                     range: fullRange)
            
            textStorage?.setAttributedString(mutableAttr)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.black
            ]
            let plainAttr = NSAttributedString(string: text, attributes: attrs)
            textStorage?.setAttributedString(plainAttr)
        }
        
        updateCursorPosition()
    }
    
    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if !stillSelectingFlag {
            updateCursorPosition()
        }
    }
    
    private func updateCursorPosition() {
        let selectedRange = selectedRange()
        let text = string as NSString
        
        var line = 1
        var column = 1
        
        let location = min(selectedRange.location, text.length)
        if location > 0 {
            let textUpToCursor = text.substring(to: location)
            for char in textUpToCursor {
                if char == "\n" {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
            }
        }
        
        onCursorChange?(line, column)
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
        default: return lang
        }
    }
}
