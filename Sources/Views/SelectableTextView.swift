import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    var text: String
    var onSelection: (String, CGRect) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textColor = .label
        
        // Readable typography
        textView.font = .systemFont(ofSize: 18, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 4, bottom: 16, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        
        // CRITICAL: Allow word wrapping within the available width
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        
        // Allow the text view to properly calculate its intrinsic size
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Build an attributed string with proper line spacing
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacing = 12
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: style
        ]
        
        uiView.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        
        init(_ parent: SelectableTextView) {
            self.parent = parent
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0, let text = textView.text, let swiftRange = Range(range, in: text) else {
                return
            }
            
            let selectedString = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selectedString.isEmpty else { return }
            
            if let startPos = textView.position(from: textView.beginningOfDocument, offset: range.location),
               let endPos = textView.position(from: startPos, offset: range.length),
               let textRange = textView.textRange(from: startPos, to: endPos) {
                
                let firstRect = textView.firstRect(for: textRange)
                let convertedRect = textView.convert(firstRect, to: nil)
                parent.onSelection(selectedString, convertedRect)
            }
        }
    }
}
