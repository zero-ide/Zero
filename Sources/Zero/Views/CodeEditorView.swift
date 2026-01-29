import SwiftUI
import AppKit
import Highlightr

struct CodeEditorView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?  // (line, column)
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.scrollerStyle = .overlay  // 얇은 오버레이 스크롤바
        scrollView.autohidesScrollers = true
        
        // 줄 번호 뷰를 포함한 컨테이너
        let containerView = EditorContainerView(frame: .zero)
        containerView.setup(language: language)
        containerView.onTextChange = { newText in
            context.coordinator.isEditing = true
            context.coordinator.parent.content = newText
            context.coordinator.isEditing = false
        }
        containerView.onCursorChange = { line, column in
            context.coordinator.parent.onCursorChange?(line, column)
        }
        
        scrollView.documentView = containerView
        context.coordinator.containerView = containerView
        
        DispatchQueue.main.async {
            containerView.setText(content, language: language)
            onReady?()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let containerView = context.coordinator.containerView else { return }
        
        if !context.coordinator.isEditing && containerView.textView.string != content {
            containerView.setText(content, language: language)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator {
        var parent: CodeEditorView
        var containerView: EditorContainerView?
        var isEditing = false
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
    }
}

// MARK: - Editor Container (줄 번호 + 텍스트 뷰)
class EditorContainerView: NSView {
    let lineNumberView = LineNumberView()
    let textView = HighlightedTextView(frame: .zero)
    
    var onTextChange: ((String) -> Void)? {
        didSet { textView.onTextChange = onTextChange }
    }
    var onCursorChange: ((Int, Int) -> Void)?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 줄 번호 뷰
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lineNumberView)
        
        // 텍스트 뷰
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        
        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: 50),
            
            textView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        textView.lineNumberView = lineNumberView
        textView.onSelectionChange = { [weak self] in
            self?.updateCursorPosition()
        }
    }
    
    func setup(language: String) {
        textView.setup(language: language)
    }
    
    func setText(_ text: String, language: String) {
        textView.setText(text, language: language)
        lineNumberView.updateLineNumbers(for: text)
    }
    
    private func updateCursorPosition() {
        let selectedRange = textView.selectedRange()
        let text = textView.string as NSString
        
        var line = 1
        var column = 1
        
        let location = min(selectedRange.location, text.length)
        let textUpToCursor = text.substring(to: location)
        
        for char in textUpToCursor {
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        
        onCursorChange?(line, column)
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: max(textView.intrinsicContentSize.height, 500))
    }
}

// MARK: - Line Number View
class LineNumberView: NSView {
    private var lineCount = 1
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0).cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func updateLineNumbers(for text: String) {
        lineCount = max(1, text.components(separatedBy: "\n").count)
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let lineHeight: CGFloat = 18.5  // 텍스트 뷰와 맞춤
        var y: CGFloat = 12  // 상단 패딩
        
        for i in 1...lineCount {
            let lineString = "\(i)"
            let rect = NSRect(x: 4, y: bounds.height - y - lineHeight, width: bounds.width - 12, height: lineHeight)
            lineString.draw(in: rect, withAttributes: attributes)
            y += lineHeight
        }
    }
}

// MARK: - Syntax Highlighting TextView
class HighlightedTextView: NSTextView {
    private var highlightr: Highlightr?
    private var currentLanguage: String = "plaintext"
    var onTextChange: ((String) -> Void)?
    var onSelectionChange: (() -> Void)?
    weak var lineNumberView: LineNumberView?
    
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
        
        textContainerInset = NSSize(width: 8, height: 12)
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
        
        lineNumberView?.updateLineNumbers(for: text)
    }
    
    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
        lineNumberView?.updateLineNumbers(for: string)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if !stillSelectingFlag {
            onSelectionChange?()
        }
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
