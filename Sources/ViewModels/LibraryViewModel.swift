import Foundation
import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.gio.Lumeno", category: "LibraryViewModel")

@Observable
@MainActor
final class LibraryViewModel {
    var books: [Book] = []
    var isLoading = false
    var hasMoreBooks = true
    
    // Import state
    enum ImportState: Equatable {
        case idle
        case importing(progress: Double)
        case success
        case error
    }
    
    var importState: ImportState = .idle
    var importError: Error?
    var showImportError = false
    
    // Delete state
    var bookToDelete: Book?
    var showDeleteConfirmation = false
    var bookFlashcardCount: Int = 0
    
    // Search
    var searchText = ""
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        } else {
            return books.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.author.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Data Fetching
    
    func loadBooks(context: ModelContext, reset: Bool = false) {
        if reset {
            books = .init()
            hasMoreBooks = true
        }
        guard hasMoreBooks && !isLoading else { return }
        isLoading = true
        
        let offset = books.count
        var descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        descriptor.fetchLimit = 20
        descriptor.fetchOffset = offset
        
        do {
            let fetchedBooks = try context.fetch(descriptor)
            books.append(contentsOf: fetchedBooks)
            hasMoreBooks = fetchedBooks.count == 20
            isLoading = false
        } catch {
            logger.error("Failed to load books: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    func searchBooks(context: ModelContext, query: String) {
        var descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        // Fetch up to 50 results for search
        descriptor.fetchLimit = 50
        
        do {
            let allFetched = try context.fetch(descriptor)
            // Predicate case-insensitive localized comparison is unsupported by SwiftData heavily
            // So we manually filter the results.
            let matched = allFetched.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query) }
            books = matched
            hasMoreBooks = false
        } catch {
            logger.error("Failed to search books: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import
    
    func importEPUB(url: URL, container: ModelContainer, context: ModelContext) async {
        await MainActor.run { importState = .importing(progress: 0.0) }
        do {
            try await BookImporter.importEPUB(from: url, container: container) { progress in
                Task { @MainActor in
                    self.importState = .importing(progress: progress)
                }
            }
            await MainActor.run {
                importState = .success
                loadBooks(context: context, reset: true)
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.importState = .idle
                }
            }
        } catch {
            await MainActor.run {
                importState = .error
                importError = error
                showImportError = true
            }
        }
    }
    
    // MARK: - Deletion
    
    func confirmDeletion(book: Book, context: ModelContext) {
        bookToDelete = book
        let bookId = book.persistentModelID
        let count = try? context.fetchCount(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.book?.persistentModelID == bookId }))
        bookFlashcardCount = count ?? 0
        showDeleteConfirmation = true
    }
    
    func deleteBooks(at offsets: IndexSet, context: ModelContext) {
        for index in offsets {
            let book = books[index]
            
            // Clean up unzipped content if it exists
            if let path = book.contentDirectoryPath {
                let url = URL(fileURLWithPath: path)
                try? FileManager.default.removeItem(at: url)
            }
            
            context.delete(book)
        }
        
        do {
            try context.save()
            loadBooks(context: context, reset: true) // reload to keep UI in sync
        } catch {
            importError = error
            showImportError = true
        }
    }
    
    func deleteConfirmedBook(context: ModelContext) {
        guard let book = bookToDelete else { return }
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            deleteBooks(at: IndexSet(integer: index), context: context)
        }
        bookToDelete = nil
    }
    
    func cancelDeletion() {
        bookToDelete = nil
    }
}
