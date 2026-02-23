import Foundation
import SwiftData
import EPUBKit
import os

private let logger = Logger(subsystem: "com.gio.Lumeno", category: "BookImporter")

@MainActor
class BookImporter {
    
    enum ImportError: LocalizedError {
        case fileAccessFailed
        case epubParsingFailed
        
        var errorDescription: String? {
            switch self {
            case .fileAccessFailed:
                return "Could not access the EPUB file."
            case .epubParsingFailed:
                return "Could not parse the EPUB file. It may be corrupted."
            }
        }
    }
    
    static func importEPUB(from url: URL, container: ModelContainer, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        return try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            logger.info("Importing EPUB from: \(url.path)")
        
        // If the URL is a security-scoped resource (e.g. from fileImporter),
        // try to access it. If it fails, the file might already be local (asCopy),
        // so we just continue.
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Verify the file actually exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("File does not exist at path: \(url.path)")
            throw ImportError.fileAccessFailed
        }
        
        // Check that the file is a valid zip/epub (EPUBs are ZIP archives)
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        logger.info("File size: \(fileData.count) bytes")
        
        guard fileData.count > 100 else {
            logger.error("File too small to be a valid EPUB (\(fileData.count) bytes)")
            throw ImportError.epubParsingFailed
        }

        // Parse EPUB using EPUBKit
        guard let document = EPUBDocument(url: url) else {
            logger.error("EPUBKit failed to parse the document")
            throw ImportError.epubParsingFailed
        }
        
        // Extract basic metadata
        let title = document.title ?? "Unknown Title"
        let author = document.author ?? "Unknown Author"
        logger.info("Parsed: \(title) by \(author)")
        
        let newBook = Book(title: title, author: author)
        var bookWordCount = 0
        
        // Extract text chapters
        var chapterIndex = 0
        let totalItems = document.spine.items.count
        logger.info("Spine has \(totalItems) items")
        
        for item in document.spine.items {
            if totalItems > 0 {
                onProgress(Double(chapterIndex) / Double(totalItems))
            }
            
            guard let manifestItem = document.manifest.items[item.idref] else {
                logger.warning("Missing manifest item for idref: \(item.idref)")
                continue
            }
            
            let htmlURL = document.contentDirectory.appendingPathComponent(manifestItem.path)
            
            do {
                let htmlString = try String(contentsOf: htmlURL, encoding: .utf8)
                
                // Quick check: skip empty HTML files
                let stripped = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !stripped.isEmpty else {
                    logger.debug("Skipping empty chapter: \(manifestItem.path)")
                    continue
                }
                
                let chapterTitle = manifestItem.id
                logger.info("Chapter \(chapterIndex): \(chapterTitle) (\(stripped.count) chars)")
                
                // Store the raw HTML so WKWebView can render it with full formatting
                let chapter = Chapter(title: chapterTitle, content: htmlString, index: chapterIndex)
                newBook.chapters.append(chapter)
                chapterIndex += 1
                
                // Count words (rough estimate by splitting on whitespace)
                let words = stripped.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                bookWordCount += words.count
            } catch {
                logger.error("Failed to read chapter \(manifestItem.path): \(error.localizedDescription)")
            }
        }
        
        // Save the content directory path so we can load images/CSS later
        newBook.contentDirectoryPath = document.contentDirectory.path
        newBook.totalWordsCount = bookWordCount
        
        // Extract cover image if available
        if let coverURL = document.cover {
            if let coverData = try? Data(contentsOf: coverURL) {
                let bookCover = BookCover(data: coverData)
                context.insert(bookCover)
                newBook.cover = bookCover
                logger.info("Cover image extracted: \(coverURL.lastPathComponent)")
            }
        }
        
        logger.info("Saving book with \(newBook.chapters.count) chapters and \(bookWordCount) total words")
        context.insert(newBook)
        try context.save()
        }.value
    }
}
