import SwiftUI
import UIKit

/// A paginated text reader that splits content into screen-sized pages,
/// similar to Apple Books. Supports text selection for word lookup.
struct PaginatedReaderView: UIViewControllerRepresentable {
    let pages: [String]
    @Binding var currentPage: Int
    var onSelection: (String, CGRect) -> Void
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        )
        pageVC.delegate = context.coordinator
        pageVC.dataSource = context.coordinator
        pageVC.view.backgroundColor = .systemBackground
        
        if !pages.isEmpty {
            let initial = makeTextPage(for: 0, context: context)
            pageVC.setViewControllers([initial], direction: .forward, animated: false)
        }
        
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // Only update if the page changed externally (e.g. from the page indicator)
        guard let current = pageVC.viewControllers?.first as? TextPageViewController,
              current.pageIndex != currentPage,
              currentPage >= 0 && currentPage < pages.count else { return }
        
        let direction: UIPageViewController.NavigationDirection = currentPage > current.pageIndex ? .forward : .reverse
        let newVC = makeTextPage(for: currentPage, context: context)
        pageVC.setViewControllers([newVC], direction: direction, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func makeTextPage(for index: Int, context: Context) -> TextPageViewController {
        let vc = TextPageViewController()
        vc.pageIndex = index
        vc.text = pages[index]
        vc.onSelection = onSelection
        return vc
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PaginatedReaderView
        
        init(_ parent: PaginatedReaderView) {
            self.parent = parent
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? TextPageViewController else { return nil }
            let prevIndex = vc.pageIndex - 1
            guard prevIndex >= 0 else { return nil }
            
            let prevVC = TextPageViewController()
            prevVC.pageIndex = prevIndex
            prevVC.text = parent.pages[prevIndex]
            prevVC.onSelection = parent.onSelection
            return prevVC
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? TextPageViewController else { return nil }
            let nextIndex = vc.pageIndex + 1
            guard nextIndex < parent.pages.count else { return nil }
            
            let nextVC = TextPageViewController()
            nextVC.pageIndex = nextIndex
            nextVC.text = parent.pages[nextIndex]
            nextVC.onSelection = parent.onSelection
            return nextVC
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first as? TextPageViewController else { return }
            parent.currentPage = currentVC.pageIndex
        }
    }
}

/// A single page of text content
class TextPageViewController: UIViewController, UITextViewDelegate {
    var pageIndex: Int = 0
    var text: String = ""
    var onSelection: ((String, CGRect) -> Void)?
    
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.delegate = self
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacing = 14
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: style
        ]
        
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        let range = textView.selectedRange
        guard range.length > 0,
              let text = textView.text,
              let swiftRange = Range(range, in: text) else { return }
        
        let selectedString = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedString.isEmpty else { return }
        
        if let startPos = textView.position(from: textView.beginningOfDocument, offset: range.location),
           let endPos = textView.position(from: startPos, offset: range.length),
           let textRange = textView.textRange(from: startPos, to: endPos) {
            let rect = textView.firstRect(for: textRange)
            let converted = textView.convert(rect, to: nil)
            onSelection?(selectedString, converted)
        }
    }
}


// MARK: - Text Pagination Engine

/// Splits a long string into screen-sized chunks using TextKit layout.
struct TextPaginator {
    
    static func paginate(text: String, size: CGSize, insets: UIEdgeInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)) -> [String] {
        guard !text.isEmpty, size.width > 0, size.height > 0 else { return [text] }
        
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacing = 14
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .paragraphStyle: style
        ]
        
        let attrString = NSAttributedString(string: text, attributes: attributes)
        
        let textStorage = NSTextStorage(attributedString: attrString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let usableWidth = size.width - insets.left - insets.right
        let usableHeight = size.height - insets.top - insets.bottom
        
        var pages: [String] = []
        var glyphIndex = 0
        let totalGlyphs = layoutManager.numberOfGlyphs
        
        while glyphIndex < totalGlyphs {
            let textContainer = NSTextContainer(size: CGSize(width: usableWidth, height: usableHeight))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            
            if glyphRange.length == 0 { break }
            
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let pageText = (text as NSString).substring(with: charRange)
            pages.append(pageText.trimmingCharacters(in: .whitespacesAndNewlines))
            
            glyphIndex = glyphRange.location + glyphRange.length
        }
        
        return pages.isEmpty ? [text] : pages
    }
}
