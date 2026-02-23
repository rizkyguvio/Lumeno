import Foundation
import SwiftData
import SwiftUI
import os
import Translation

private let logger = Logger(subsystem: "com.gio.Lumeno", category: "ReaderViewModel")

@Observable
@MainActor
final class ReaderViewModel {
    let book: Book
    var currentChapterIndex: Int
    var isChromeHidden: Bool = false
    
    var chapterPages: [Int: Int] = [:]
    var chapterTotalPages: [Int: Int] = [:]
    
    // Flashcard Creation State
    var selectedWord: String?
    var selectedContext: String = ""
    var translationText: String = ""
    var notesText: String = ""
    var selectedDeck: Deck?
    var newDeckName: String = ""
    
    // Reader Customization State
    var readerSettings = ReaderSettings() {
        didSet {
            saveReaderSettings()
        }
    }
    
    // Translation API State
    var translationConfig: TranslationSession.Configuration?
    var deepLAPIKey: String {
        get {
            if let data = KeychainHelper.shared.read(service: "com.contexto.keys", account: "deepLAPIKey"),
               let stringValue = String(data: data, encoding: .utf8) {
                return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
    }
    
    // Error Handling
    var errorMessage: String?
    var showError = false
    var isSelectionActive = false
    
    init(book: Book) {
        self.book = book
        self.currentChapterIndex = book.lastReadChapterIndex
        self.newDeckName = book.title
        loadReaderSettings()
    }
    
    private func loadReaderSettings() {
        if let data = UserDefaults.standard.data(forKey: "readerSettings"),
           let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            self.readerSettings = decoded
        }
    }
    
    private func saveReaderSettings() {
        if let data = try? JSONEncoder().encode(readerSettings) {
            UserDefaults.standard.set(data, forKey: "readerSettings")
        }
    }
    
    func resetReaderSettings() {
        readerSettings = ReaderSettings()
    }
    
    var validChapters: [Chapter] {
        book.chapters
            .filter { !$0.title.lowercased().contains("also_by") }
            .sorted { $0.index < $1.index }
    }
    
    var baseURL: URL? {
        if let path = book.contentDirectoryPath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    func chapterBinding() -> Binding<Int> {
        Binding<Int>(
            get: { self.currentChapterIndex },
            set: { newValue in
                if !self.isSelectionActive {
                    self.currentChapterIndex = newValue
                }
            }
        )
    }
    
    func isDuplicate(decks: [Deck]) -> Bool {
        guard let deck = selectedDeck, let word = selectedWord else { return false }
        return deck.flashcards.contains { $0.word.lowercased() == word.lowercased() }
    }
    
    func handleLinkTapped(_ url: URL, fromChapterIndex: Int, context: ModelContext) {
        let targetString = url.absoluteString
        let components = targetString.components(separatedBy: "/")
        guard let finalComponent = components.last else { return }
        
        let splitAnchor = finalComponent.components(separatedBy: "#")
        let filenameToMatch = splitAnchor.first ?? finalComponent
        
        if let targetChapterIndex = validChapters.firstIndex(where: { chapter in
            if splitAnchor.count > 1 {
                let anchor = splitAnchor[1]
                return chapter.content.contains("id=\"\(anchor)\"") || chapter.content.contains("name=\"\(anchor)\"")
            }
            return chapter.content.contains(filenameToMatch) || chapter.title.lowercased().contains(filenameToMatch.lowercased())
        }) {
            currentChapterIndex = targetChapterIndex
            book.lastReadPage = 0
            do {
                try context.save()
            } catch {
                errorMessage = "Failed to save reading progress: \(error.localizedDescription)"
                showError = true
            }
        } else {
            logger.error("Could not resolve TOC link natively: \(targetString)")
        }
    }
    
    func onSelection(word: String, contextStr: String, decks: [Deck]) {
        selectedWord = word
        selectedContext = contextStr
        translationText = ""
        notesText = ""
        translationConfig = nil
        if selectedDeck == nil {
            selectedDeck = decks.first
        }
    }
    
    func fetchWordTranslation(word: String, context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<CachedTranslation>(predicate: #Predicate { $0.sourceText == word })
        if let cached = try? context.fetch(fetchDescriptor).first {
            translationText = cached.translatedText
            return
        }
        
        let apiKey = self.deepLAPIKey
        if !apiKey.isEmpty {
            Task {
                do {
                    if let translation = try await translateWithDeepL(text: word, apiKey: apiKey) {
                        await MainActor.run {
                            if self.translationText.isEmpty {
                                self.translationText = translation
                            }
                            let newCache = CachedTranslation(sourceText: word, targetLanguage: "EN", translatedText: translation)
                            context.insert(newCache)
                            try? context.save()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.translationConfig = .init(target: Locale.Language(identifier: "en"))
                        self.errorMessage = "DeepL Translation Failed: \(error.localizedDescription). Falling back to Apple Translation."
                        self.showError = true
                    }
                }
            }
        } else {
            translationConfig = .init(target: Locale.Language(identifier: "en"))
        }
    }
    
    private func translateWithDeepL(text: String, apiKey: String) async throws -> String? {
        let isFreeKey = apiKey.lowercased().hasSuffix(":fx")
        let endpoint = isFreeKey ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
        
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "text": [text],
            "target_lang": "EN"
        ]
        
        let sourceLang = UserDefaults.standard.string(forKey: "deepLSourceLang") ?? ""
        if !sourceLang.isEmpty {
            body["source_lang"] = sourceLang
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 403 {
            throw NSError(domain: "DeepLError", code: 403, userInfo: [NSLocalizedDescriptionKey: "DeepL API Key is invalid or quota exceeded."])
        } else if httpResponse.statusCode != 200 {
            throw NSError(domain: "DeepLError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "DeepL failed with status code \(httpResponse.statusCode)."])
        }
        
        struct DeepLResponse: Decodable {
            let translations: [TranslationItem]
            struct TranslationItem: Decodable { let text: String }
        }
        
        let decoded = try JSONDecoder().decode(DeepLResponse.self, from: data)
        return decoded.translations.first?.text
    }
    
    func saveFlashcard(context: ModelContext, decks: [Deck]) {
        guard let word = selectedWord else { return }
        
        let targetDeck: Deck
        if let existing = selectedDeck {
            targetDeck = existing
        } else if !newDeckName.isEmpty {
            targetDeck = Deck(name: newDeckName)
            context.insert(targetDeck)
            selectedDeck = targetDeck
        } else {
            return
        }
        
        let card = Flashcard(
            word: word,
            translation: translationText,
            sentenceContext: selectedContext,
            notes: notesText,
            sourceTitle: book.title
        )
        card.book = book
        card.deck = targetDeck
        targetDeck.flashcards.append(card)
        book.flashcards.append(card)
        
        do {
            try context.save()
            HapticManager.shared.success()
        } catch {
            errorMessage = "Failed to save flashcard: \(error.localizedDescription)"
            showError = true
            return
        }
        
        selectedWord = nil
        translationText = ""
        notesText = ""
        newDeckName = book.title
    }
    
    func onChapterChanged(newIndex: Int, context: ModelContext) {
        book.lastReadChapterIndex = newIndex
        book.lastReadPage = 0
        try? context.save()
    }
    
    func onPageChanged(newPage: Int?, context: ModelContext) {
        if let page = newPage {
            book.lastReadPage = page
            try? context.save()
        }
    }
}
