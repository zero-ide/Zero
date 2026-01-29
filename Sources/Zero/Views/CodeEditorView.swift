import SwiftUI
import AppKit
import CodeEditTextView

struct CodeEditorView: NSViewRepresentable {
    @Binding var content: String
    var language: String
    var onReady: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = TextView(
            string: content,
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            textColor: .textColor,
            lineHeightMultiplier: 1.2,
            wrapLines: true,
            isEditable: true,
            isSelectable: true,
            letterSpacing: 1.0,
            delegate: context.coordinator
        )
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        
        context.coordinator.textView = textView
        
        DispatchQueue.main.async {
            textView.updateFrameIfNeeded()
            onReady?()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // 외부에서 content가 변경되었을 때만 업데이트
        if textView.string != content && !context.coordinator.isEditing {
            textView.setText(content)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, TextViewDelegate {
        var parent: CodeEditorView
        var textView: TextView?
        var isEditing = false
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textView(_ textView: TextView, didReplaceContentsIn range: NSRange, with string: String) {
            isEditing = true
            parent.content = textView.string
            isEditing = false
        }
    }
}
