import SwiftUI
import WebKit

/// A WKWebView-based EPUB reader with CSS column pagination and text selection.
struct EPUBReaderWebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    var initialPage: Int
    var onSelection: (String, String) -> Void
    var onNavigation: ((URL) -> Void)? = nil
    var onSelectionStateChange: ((Bool) -> Void)? = nil
    var onTap: (() -> Void)? = nil
    var isScrollLocked: Bool
    var selectedWord: String?
    var readerSettings: ReaderSettings
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "textSelected")
        contentController.add(context.coordinator, name: "pageInfo")
        contentController.add(context.coordinator, name: "selectionState")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        
        // Horizontal paging — the key to Apple Books-like page turns
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.delegate = context.coordinator
        
        // No zoom
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        
        // Tap gesture for toggling chrome
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if !context.coordinator.hasLoaded {
            context.coordinator.hasLoaded = true
            context.coordinator.webView = webView
            context.coordinator.initialPage = initialPage
            
            let wrappedHTML = buildPaginatedHTML(htmlContent)
            
            if let baseURL = baseURL {
                // Write HTML to the content directory so relative assets work natively
                let tempHTMLURL = baseURL.appendingPathComponent("chapter_render_\(UUID().uuidString).html")
                do {
                    try wrappedHTML.write(to: tempHTMLURL, atomically: true, encoding: .utf8)
                    // Grant read access to the entire EPUB unzipped directory
                    webView.loadFileURL(tempHTMLURL, allowingReadAccessTo: baseURL)
                } catch {
                    // Fallback if write fails
                    webView.loadHTMLString(wrappedHTML, baseURL: baseURL)
                }
            } else {
                webView.loadHTMLString(wrappedHTML, baseURL: baseURL)
            }
        }
        
        // Handle changes to reader settings by updating CSS variables live
        if context.coordinator.lastSettings != readerSettings {
            context.coordinator.lastSettings = readerSettings
            
            let fontStack = readerSettings.fontFamily == "San Francisco" ? "-apple-system" : 
                           (readerSettings.fontFamily == "Original" ? "inherit" : "'\(readerSettings.fontFamily)'")
            
            let css = """
                #content * {
                    font-family: \(fontStack) !important;
                    font-size: \(readerSettings.fontSize)px !important;
                    line-height: \(readerSettings.lineSpacing) !important;
                    letter-spacing: \(readerSettings.letterSpacing)em !important;
                    word-spacing: \(readerSettings.wordSpacing)em !important;
                    text-align: \(readerSettings.isJustified ? "justify" : "left") !important;
                    font-weight: \(readerSettings.isBold ? "700" : "normal") !important;
                }
                #content {
                    padding: 20px \(readerSettings.horizontalPadding)px 40px \(readerSettings.horizontalPadding)px !important;
                    column-width: calc(100vw - \(readerSettings.horizontalPadding * 2)px) !important;
                    column-gap: \(readerSettings.horizontalPadding * 2)px !important;
                    box-sizing: border-box !important;
                }
                #content h1 { font-size: \(readerSettings.fontSize * 1.4)px !important; }
                #content h2 { font-size: \(readerSettings.fontSize * 1.2)px !important; }
                #content h3 { font-size: \(readerSettings.fontSize * 1.1)px !important; }
            """
            
            let js = """
                (function() {
                    var styleEl = document.getElementById('lumeno-dynamic-styles');
                    if (styleEl) {
                        styleEl.innerHTML = `\(css)`;
                        setTimeout(function() {
                            if (typeof window.lumenoUpdate === 'function') { window.lumenoUpdate(); }
                        }, 100);
                    }
                })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Surgical fix for TabView swipe conflict:
        // Find the ancestor scroll view (the TabView's paging scroll view) 
        // and disable its scrolling while selection is active.
        DispatchQueue.main.async {
            if let ancestor = self.findAncestorScrollView(of: webView) {
                ancestor.isScrollEnabled = !isScrollLocked
                if isScrollLocked {
                    ancestor.panGestureRecognizer.isEnabled = false
                    ancestor.panGestureRecognizer.isEnabled = true
                }
            }
            
            webView.scrollView.isScrollEnabled = !isScrollLocked
            if isScrollLocked {
                webView.scrollView.panGestureRecognizer.isEnabled = false
                webView.scrollView.panGestureRecognizer.isEnabled = true
            }
            
            if selectedWord == nil {
                webView.evaluateJavaScript("if(window.clearLumenoSelection) window.clearLumenoSelection();", completionHandler: nil)
            }
        }
    }
    
    private func findAncestorScrollView(of view: UIView) -> UIScrollView? {
        var parent = view.superview
        while parent != nil {
            // TabView uses a UIScrollView (often a UICollectionView or similar) for paging
            if let scrollView = parent as? UIScrollView {
                return scrollView
            }
            parent = parent?.superview
        }
        return nil
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func buildPaginatedHTML(_ bodyHTML: String) -> String {
        // The trick: CSS columns create a wide horizontal layout.
        // WKWebView's UIScrollView (isPagingEnabled=true) handles the paging.
        // We must NOT set overflow:hidden on body — that kills scrolling.
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            * { 
                box-sizing: border-box; 
                margin: 0; 
                padding: 0; 
                -webkit-touch-callout: none; /* Suppress native menu */
            }
            
            html {
                height: 100%;
                /* CRITICAL: allow horizontal scroll so WKWebView paging works */
                overflow-x: auto;
                overflow-y: hidden;
            }
            
            body {
                height: 100%;
                overflow: visible;
                background: #FFFFFF;
                color: #1C1C1E;
                -webkit-user-select: text;
                user-select: text;
            }
            
            @media (prefers-color-scheme: dark) {
                body { background: #1C1C1E; color: #F5F5F7; }
                a { color: #64D2FF; }
            }
            
            #content {
                height: calc(100vh - 8px);
                padding: 20px \(readerSettings.horizontalPadding)px 40px \(readerSettings.horizontalPadding)px;
                
                /* Column-based pagination */
                column-fill: auto;
                column-gap: 48px;
                
                /* Each column = viewport width minus container padding & gap */
                column-width: calc(100vw - \(readerSettings.horizontalPadding * 2)px);
            }
            
            #content p, #content div, #content li, #content span, #content h1, #content h2, #content h3 {
                orphans: 2;
                widows: 2;
                break-inside: avoid-column;
                -webkit-hyphens: auto;
                hyphens: auto;
            }
            
            #content h1, #content h2, #content h3, #content h4 {
                font-family: -apple-system, 'Helvetica Neue', sans-serif;
                line-height: 1.3;
                margin: 1.2em 0 0.4em 0;
                break-after: avoid-column;
                break-inside: avoid-column;
                font-weight: 700;
            }
            
            #content img { max-width: 100%; height: auto; break-inside: avoid-column; }
            
            #content blockquote {
                border-left: 3px solid #888;
                padding: 0.4em 1em;
                margin: 0.8em 0;
                font-style: italic;
                break-inside: avoid-column;
            }
            
            /* Custom selection highlight */
            ::selection {
                background: rgba(100, 210, 255, 0.3);
                color: inherit;
            }
            @media (prefers-color-scheme: dark) {
                ::selection {
                    background: rgba(100, 210, 255, 0.35);
                }
            }
            
            #content table { break-inside: avoid-column; margin: 0.8em 0; }
        </style>
        <style id="lumeno-dynamic-styles">
            #content * {
                font-family: \(readerSettings.fontFamily == "San Francisco" ? "-apple-system" : (readerSettings.fontFamily == "Original" ? "inherit" : "'\(readerSettings.fontFamily)'")), serif !important;
                font-size: \(readerSettings.fontSize)px !important;
                line-height: \(readerSettings.lineSpacing) !important;
                letter-spacing: \(readerSettings.letterSpacing)em !important;
                word-spacing: \(readerSettings.wordSpacing)em !important;
                text-align: \(readerSettings.isJustified ? "justify" : "left") !important;
                font-weight: \(readerSettings.isBold ? "700" : "normal") !important;
                max-width: 100% !important;
                overflow-wrap: break-word !important;
                word-wrap: break-word !important;
            }
            #content {
                padding: 20px \(readerSettings.horizontalPadding)px 40px \(readerSettings.horizontalPadding)px !important;
                column-width: calc(100vw - \(readerSettings.horizontalPadding * 2)px) !important;
                column-gap: \(readerSettings.horizontalPadding * 2)px !important;
                box-sizing: border-box !important;
            }
            #content h1 { font-size: \(readerSettings.fontSize * 1.4)px !important; }
            #content h2 { font-size: \(readerSettings.fontSize * 1.2)px !important; }
            #content h3 { font-size: \(readerSettings.fontSize * 1.1)px !important; }
        </style>
        </head>
        <body>
            <div id="content">
                \(bodyHTML)
            </div>
            <script>
            (function() {
                window.lumenoUpdate = function() {
                    var pw = window.innerWidth;
                    document.body.style.width = 'auto'; // Reset before measure
                    var sw = document.getElementById('content').scrollWidth;
                    var total = Math.max(1, Math.ceil(sw / pw));
                    
                    // Force exact bounds so UIScrollView paging snapping works perfectly
                    document.body.style.width = (total * pw) + 'px';
                    
                    var current = Math.round(window.scrollX / pw);
                    window.webkit.messageHandlers.pageInfo.postMessage({
                        total: total,
                        current: current
                    });
                }
                
                function setScrollEnabled(enabled) {
                    window.webkit.messageHandlers.selectionState.postMessage({ active: !enabled });
                }
                
                var isClearing = false;
                
                document.addEventListener('selectionchange', function() {
                    if (isClearing) return;
                    var sel = window.getSelection();
                    var hasSelection = sel && sel.rangeCount > 0 && sel.toString().trim().length > 0;
                    window.webkit.messageHandlers.selectionState.postMessage({ active: hasSelection });
                });
                
                function handleSelectionClear() {
                    if (isClearing) return;
                    var sel = window.getSelection();
                    if (!sel || sel.rangeCount === 0) return;
                    
                    var text = sel.toString().trim();
                    if (text.length === 0) return;
                    
                    var range = sel.getRangeAt(0);
                    // Find containing sentence for context
                    var container = range.commonAncestorContainer;
                    while(container && container.nodeType !== 1) container = container.parentNode;
                    var fullText = (container ? (container.innerText || container.textContent) : "") || "";
                    
                    // Extract sentence context
                    var sentences = fullText.match(/[^.!?]+[.!?]+/g) || [fullText];
                    var context = text;
                    for (var i = 0; i < sentences.length; i++) {
                        if (sentences[i].includes(text)) {
                            context = sentences[i].trim();
                            break;
                        }
                    }

                    // Send to Swift
                    window.webkit.messageHandlers.textSelected.postMessage({
                        text: text,
                        context: context
                    });

                    // Clear to suppress native menu
                    isClearing = true;
                    sel.removeAllRanges();
                    window.webkit.messageHandlers.selectionState.postMessage({ active: false });
                    setTimeout(function() { isClearing = false; }, 300);
                }

                document.addEventListener('touchend', function() {
                    setTimeout(handleSelectionClear, 10); // Tiny delay to let selection finalize
                });
                
                document.addEventListener('touchcancel', function() {
                    setTimeout(handleSelectionClear, 10);
                });
                
                window.clearLumenoSelection = function() {
                    isClearing = true;
                    window.getSelection().removeAllRanges();
                    setTimeout(function() { isClearing = false; }, 200);
                };
                
                window.addEventListener('scroll', window.lumenoUpdate);
                window.addEventListener('load', function() { setTimeout(window.lumenoUpdate, 200); });
                window.addEventListener('resize', function() { setTimeout(window.lumenoUpdate, 200); });
            })();
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: EPUBReaderWebView
        var hasLoaded = false
        var initialPage = 0
        weak var webView: WKWebView?
        var lastSettings: ReaderSettings?
        
        init(_ parent: EPUBReaderWebView) {
            self.parent = parent
            self.lastSettings = parent.readerSettings
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Only trigger tap if there's no active text selection
            if !self.parent.isScrollLocked {
                DispatchQueue.main.async {
                    self.parent.onTap?()
                }
            }
        }
        
        // Ensure tap gesture doesn't prevent scrolling/paging
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "textSelected", let dict = message.body as? [String: Any] {
                let text = dict["text"] as? String ?? ""
                let context = dict["context"] as? String ?? ""
                DispatchQueue.main.async { self.parent.onSelection(text, context) }
            } else if message.name == "pageInfo", let dict = message.body as? [String: Any] {
                DispatchQueue.main.async {
                    if let total = dict["total"] as? Int { self.parent.totalPages = total }
                    if let current = dict["current"] as? Int { self.parent.currentPage = current }
                }
            } else if message.name == "selectionState", let dict = message.body as? [String: Any] {
                let isActive = dict["active"] as? Bool ?? false
                let isAtEnd = dict["isAtEnd"] as? Bool ?? false
                
                DispatchQueue.main.async {
                    // Lock scrolling if selecting, unless we've reached the end of the page
                    // This allows the user to still swipe-turn if they are at the last word
                    self.webView?.scrollView.isScrollEnabled = !isActive || isAtEnd
                    self.parent.onSelectionStateChange?(isActive && !isAtEnd)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Disable vertical scrolling after content loads
            webView.scrollView.contentSize.height = webView.scrollView.frame.height
            
            // Jump to saved page and report page count
            let page = initialPage
            webView.evaluateJavaScript("""
                (function() {
                    var pw = window.innerWidth;
                    var sw = document.getElementById('content').scrollWidth;
                    var total = Math.max(1, Math.round(sw / pw));
                    var target = Math.min(\(page), total - 1);
                    if (target > 0) { window.scrollTo(target * pw, 0); }
                    window.webkit.messageHandlers.pageInfo.postMessage({ total: total, current: target });
                })();
            """) { _, _ in }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // Intercept the navigation and pass it up instead of letting WebKit load it
                    DispatchQueue.main.async {
                        self.parent.onNavigation?(url)
                    }
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let pageWidth = scrollView.frame.width
            guard pageWidth > 0 else { return }
            let page = Int(round(scrollView.contentOffset.x / pageWidth))
            if page != parent.currentPage {
                DispatchQueue.main.async { self.parent.currentPage = page }
            }
        }
    }
}
