import SwiftUI
import UIKit

/// A `UIViewRepresentable` that wraps `CodeEditorContainer` — a custom `UIView`
/// combining a gutter (line numbers) and a `UITextView` — to provide a
/// monospaced, syntax-highlighted code editor with synchronised scrolling.
struct LineNumberedTextView: UIViewRepresentable {
    /// The text binding that is kept in sync with the underlying `UITextView`.
    @Binding var text: String
    
    func makeUIView(context: Context) -> CodeEditorContainer {
        let container = CodeEditorContainer()
        container.delegate = context.coordinator
        container.text = text
        return container
    }
    
    /// Pushes external text changes (e.g. from store updates) into the view,
    /// guarded by an equality check to avoid triggering a redundant highlight pass.
    func updateUIView(_ uiView: CodeEditorContainer, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Bridges `UITextView` change events back to the SwiftUI binding.
    class Coordinator: NSObject, CodeEditorContainerDelegate {
        var parent: LineNumberedTextView
        
        init(_ parent: LineNumberedTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ text: String) {
            self.parent.text = text
        }
    }
}

/// Callback protocol through which `CodeEditorContainer` notifies its owner of
/// text changes without retaining the owner (weak reference in the container).
protocol CodeEditorContainerDelegate: AnyObject {
    /// Called on every keystroke after line numbers and syntax highlighting have
    /// been updated.
    func textDidChange(_ text: String)
}

/// A `UIView` subclass that pairs a non-interactive gutter (`UITextView` displaying
/// line numbers) with an editable `UITextView` for the actual code. The two scroll
/// views are kept in sync so line numbers always align with their corresponding
/// lines. Syntax highlighting is applied after every edit using a set of
/// pre-compiled `NSRegularExpression` objects stored in `RegexCache`.
class CodeEditorContainer: UIView, UITextViewDelegate {
    weak var delegate: CodeEditorContainerDelegate?
    
    /// The read-only gutter that displays line numbers, coloured dark-gray.
    private let gutterView = UITextView()
    /// The main editable text view where the user types code.
    private let textView = UITextView()
    
    /// Shared monospaced font used by both the gutter and the editor to keep
    /// line heights identical.
    private let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    /// Width reserved for the gutter column in points.
    private let gutterWidth: CGFloat = 45
    
    /// Gets or sets the editor's text, triggering a line-number refresh and
    /// a syntax-highlight pass whenever the value changes.
    var text: String {
        get { textView.text }
        set {
            if textView.text != newValue {
                textView.text = newValue
                updateLineNumbers()
                highlightSyntax()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) // VS Code Dark+ Background
        semanticContentAttribute = .forceLeftToRight
        
        // Setup Gutter
        gutterView.isEditable = false
        gutterView.isSelectable = false
        gutterView.showsVerticalScrollIndicator = false
        gutterView.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        gutterView.textColor = UIColor.darkGray
        gutterView.font = font
        gutterView.textAlignment = .right
        gutterView.textContainerInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 8)
        gutterView.semanticContentAttribute = .forceLeftToRight
        
        // Setup Main Text View
        textView.delegate = self
        textView.font = font
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.backgroundColor = .clear
        textView.textColor = UIColor(white: 0.9, alpha: 1.0)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 16)
        textView.keyboardAppearance = .dark
        textView.textAlignment = .left
        textView.semanticContentAttribute = .forceLeftToRight
        
        addSubview(gutterView)
        addSubview(textView)
        
        updateLineNumbers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gutterView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        textView.frame = CGRect(x: gutterWidth, y: 0, width: bounds.width - gutterWidth, height: bounds.height)
    }
    
    // MARK: - Sync Scrolling
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == textView {
            gutterView.contentOffset = textView.contentOffset
        }
    }
    
    // MARK: - Text Change
    func textViewDidChange(_ textView: UITextView) {
        delegate?.textDidChange(textView.text)
        updateLineNumbers()
        highlightSyntax()
    }
    
    private func updateLineNumbers() {
        // Calculate number of lines based on newline characters
        let components = textView.text.components(separatedBy: .newlines)
        let lineCount = max(components.count, 1)
        
        var numbers = ""
        for i in 1...lineCount {
            numbers += "\(i)\n"
        }
        gutterView.text = numbers
    }
    
    // MARK: - Regex Cache
    private struct RegexCache {
        static let multiLineComment = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/")
        static let singleLineComment = try? NSRegularExpression(pattern: "//.*")
        static let htmlTag = try? NSRegularExpression(pattern: "</?[a-zA-Z0-9]+[^>]*>")
        static let stringLiteral = try? NSRegularExpression(pattern: "(\"[^\"]*\")|('[^']*')")
        static let keyword: NSRegularExpression? = {
            let keywords = ["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export", "true", "false", "new", "document", "window", "=>"]
            let keywordPattern = "\\b(\(keywords.joined(separator: "|")))\\b"
            return try? NSRegularExpression(pattern: keywordPattern)
        }()
        static let cssProperty = try? NSRegularExpression(pattern: "\\b[a-zA-Z-]+:")
    }
    
    // MARK: - Syntax Highlighting
    private func highlightSyntax() {
        let textStorage = textView.textStorage
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: string.utf16.count)
        
        textStorage.beginEditing()
        
        // Reset base style
        textStorage.setAttributes([
            .font: font,
            .foregroundColor: UIColor(white: 0.9, alpha: 1.0)
        ], range: fullRange)
        
        // Multi-line Comments: /* ... */
        if let regex = RegexCache.multiLineComment {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: match.range) }
        }
        
        // Single-line Comments: // ...
        if let regex = RegexCache.singleLineComment {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: match.range) }
        }
        
        // HTML Tags: <...>
        if let regex = RegexCache.htmlTag {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1.0), range: match.range) }
        }
        
        // Strings: "..." or '...'
        if let regex = RegexCache.stringLiteral {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor(red: 0.81, green: 0.57, blue: 0.40, alpha: 1.0), range: match.range) }
        }
        
        // Keywords
        if let regex = RegexCache.keyword {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor(red: 0.77, green: 0.52, blue: 0.75, alpha: 1.0), range: match.range) }
        }
        
        // CSS Properties (e.g. background-color:, margin:)
        if let regex = RegexCache.cssProperty {
            let matches = regex.matches(in: string, range: fullRange)
            for match in matches { textStorage.addAttribute(.foregroundColor, value: UIColor(red: 0.61, green: 0.86, blue: 0.99, alpha: 1.0), range: match.range) }
        }
        
        textStorage.endEditing()
    }
}
