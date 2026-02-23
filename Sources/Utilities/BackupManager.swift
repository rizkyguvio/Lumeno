import Foundation
import SwiftData

/// Manages exporting and importing Decks to/from TSV (Tab-Separated Values) files
/// for Anki compatibility and simple plain text backups.
@MainActor
class BackupManager {
    static let shared = BackupManager()
    
    private init() {}
    
    /// The Documents directory where files will be stored and accessible via the Files app
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Automatically backups all decks in the given context to TSV files
    func autoBackupAllDecks(context: ModelContext) {
        let descriptor = FetchDescriptor<Deck>()
        do {
            let decks = try context.fetch(descriptor)
            for deck in decks {
                try exportDeckToTSV(deck: deck)
            }
        } catch {
            print("Failed to auto-backup decks: \(error.localizedDescription)")
        }
    }
    
    /// Exports a specific deck to a TSV file in the Documents directory
    func exportDeckToTSV(deck: Deck) throws {
        // Build the TSV content
        var tsvContent = "Word\tTranslation\tContext\tNotes\n"
        
        for card in deck.flashcards {
            // Escape any newlines or tabs that might be in the user's strings to preserve TSV format
            let word = card.word.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            let translation = card.translation.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            let context = card.sentenceContext.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            let notes = card.notes.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            
            tsvContent += "\(word)\t\(translation)\t\(context)\t\(notes)\n"
        }
        
        // Sanitize the deck name for a filename
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let fileURL = documentsURL.appendingPathComponent("\(safeName).tsv")
        
        try tsvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        print("Successfully exported deck \(deck.name) to \(fileURL.path)")
    }
    
    /// Imports a TSV file and creates/updates a deck with its contents
    func importDeckFromTSV(url: URL, context: ModelContext) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "BackupManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied to read the selected file."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        
        // Extract deck name from filename
        let filename = url.deletingPathExtension().lastPathComponent
        
        // Look for an existing deck or create a new one
        let fetchDescriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.name == filename })
        let existingDecks = try context.fetch(fetchDescriptor)
        
        let targetDeck: Deck
        if let existing = existingDecks.first {
            targetDeck = existing
        } else {
            targetDeck = Deck(name: filename)
            context.insert(targetDeck)
        }
        
        // Parse TSV
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return }
        
        // Skip header
        let dataLines = lines.dropFirst()
        
        // Quick way to avoid duplicating identical cards during import
        let existingSignature = Set(targetDeck.flashcards.map { "\($0.word)-\($0.translation)" })
        
        for line in dataLines {
            let row = line.components(separatedBy: "\t")
            guard row.count >= 2 else { continue } // At minimum, we need a word and translation
            
            let word = row[0]
            let translation = row[1]
            let contextText = row.count > 2 ? row[2] : ""
            let notes = row.count > 3 ? row[3] : ""
            
            // Skip empty words or duplicates
            if word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if existingSignature.contains("\(word)-\(translation)") { continue }
            
            let card = Flashcard(
                word: word,
                translation: translation,
                sentenceContext: contextText,
                notes: notes
            )
            context.insert(card)
            targetDeck.flashcards.append(card)
        }
        
        try context.save()
        print("Successfully imported TSV into deck: \(targetDeck.name)")
    }
}
