import Foundation
import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.gio.Lumeno", category: "DecksViewModel")

@Observable
@MainActor
final class DecksViewModel {
    var decks: [Deck] = []
    var isLoading = false
    var hasMoreDecks = true
    
    var showingAddDeck = false
    var newDeckName = ""
    
    var showingEditDeck = false
    var deckToEdit: Deck?
    var editDeckName = ""
    
    var errorMessage: String?
    var showError = false
    
    func loadDecks(context: ModelContext, reset: Bool = false) {
        if reset {
            decks = .init()
            hasMoreDecks = true
        }
        guard hasMoreDecks && !isLoading else { return }
        isLoading = true
        
        let offset = decks.count
        var descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchLimit = 20
        descriptor.fetchOffset = offset
        
        Task {
            do {
                let fetchedDecks = try context.fetch(descriptor)
                await MainActor.run {
                    decks.append(contentsOf: fetchedDecks)
                    hasMoreDecks = fetchedDecks.count == 20
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    func addDeck(context: ModelContext) {
        guard !newDeckName.isEmpty else { return }
        let deck = Deck(name: newDeckName)
        context.insert(deck)
        do {
            try context.save()
            loadDecks(context: context, reset: true)
        } catch {
            errorMessage = "Failed to create deck: \(error.localizedDescription)"
            showError = true
        }
        newDeckName = ""
    }
    
    func saveEditedDeck(context: ModelContext) {
        if let deck = deckToEdit, !editDeckName.isEmpty {
            deck.name = editDeckName
            do {
                try context.save()
                loadDecks(context: context, reset: true)
            } catch {
                errorMessage = "Failed to update deck: \(error.localizedDescription)"
                showError = true
            }
        }
        editDeckName = ""
        deckToEdit = nil
    }
    
    func deleteDecks(at offsets: IndexSet, context: ModelContext) {
        for index in offsets {
            context.delete(decks[index])
        }
        do {
            try context.save()
            loadDecks(context: context, reset: true)
        } catch {
            errorMessage = "Failed to delete deck: \(error.localizedDescription)"
            showError = true
        }
    }
}

@Observable
@MainActor
final class DeckDetailViewModel {
    let deck: Deck
    
    var studySession: StudySession?
    var errorMessage: String?
    var showError = false
    var cardToEdit: Flashcard?
    
    var deckCardCount: Int = 0
    var loadedCards: [Flashcard] = []
    
    init(deck: Deck) {
        self.deck = deck
    }
    
    func loadCards(context: ModelContext) {
        let deckId = deck.persistentModelID
        let count = try? context.fetchCount(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.deck?.persistentModelID == deckId }))
        deckCardCount = count ?? 0
        
        var descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.deck?.persistentModelID == deckId },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        if let cards = try? context.fetch(descriptor) {
            loadedCards = cards
        }
    }
    
    func deleteCards(at offsets: IndexSet, context: ModelContext) {
        for index in offsets {
            let card = loadedCards[index]
            context.delete(card)
        }
        do {
            try context.save()
            loadCards(context: context)
        } catch {
            errorMessage = "Failed to delete card: \(error.localizedDescription)"
            showError = true
        }
    }
}
