import Foundation
import SwiftData

@Model
final class Book {
    var title: String = ""
    var author: String = "Unknown"
    var dateAdded: Date = Date.now
    var contentDirectoryPath: String?
    @Relationship(deleteRule: .cascade) var cover: BookCover?
    var lastReadPage: Int = 0
    var lastReadChapterIndex: Int = 0
    var totalWordsCount: Int = 0
    @Relationship(deleteRule: .cascade) var chapters: [Chapter] = []
    @Relationship(deleteRule: .nullify) var flashcards: [Flashcard] = []
    
    init(title: String, author: String = "Unknown", dateAdded: Date = .now) {
        self.title = title
        self.author = author
        self.dateAdded = dateAdded
    }
}

@Model
final class BookCover {
    @Attribute(.externalStorage) var data: Data
    
    init(data: Data) {
        self.data = data
    }
}

@Model
final class Chapter {
    var title: String = ""
    var content: String = ""
    var index: Int = 0
    
    var book: Book?
    
    init(title: String, content: String, index: Int) {
        self.title = title
        self.content = content
        self.index = index
    }
}

@Model
final class Deck {
    var name: String = ""
    @Relationship(deleteRule: .cascade) var flashcards: [Flashcard] = []
    
    init(name: String) {
        self.name = name
    }
}

@Model
final class Flashcard {
    var word: String = ""
    var translation: String = ""
    var sentenceContext: String = ""
    var notes: String = ""
    var dateCreated: Date = Date.now
    var nextReviewDate: Date = Date.now
    var reviewCount: Int = 0
    var correctReviews: Int = 0
    var incorrectReviews: Int = 0
    
    // Denormalized flags for fast Predicate filtering
    var lastReviewDate: Date?
    var isStruggling: Bool = false
    
    // SM-2 Properties
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var isLearning: Bool = true
    var practiceFailCount: Int = 0
    
    var sourceTitle: String?
    
    var book: Book?
    var deck: Deck?
    @Relationship(deleteRule: .cascade) var reviewLogs: [ReviewLog] = []
    
    init(word: String, translation: String, sentenceContext: String, notes: String = "", sourceTitle: String? = nil, dateCreated: Date = .now) {
        self.word = word
        self.translation = translation
        self.sentenceContext = sentenceContext
        self.notes = notes
        self.sourceTitle = sourceTitle
        self.dateCreated = dateCreated
        self.nextReviewDate = dateCreated
        self.easeFactor = 2.5
        self.intervalDays = 0
        self.isLearning = true
        self.practiceFailCount = 0
        self.isStruggling = false
    }
}

@Model
final class CachedTranslation {
    var sourceText: String
    var targetLanguage: String
    var translatedText: String
    var dateCached: Date
    
    init(sourceText: String, targetLanguage: String, translatedText: String) {
        self.sourceText = sourceText
        self.targetLanguage = targetLanguage
        self.translatedText = translatedText
        self.dateCached = .now
    }
}

@Model
final class ReviewLog {
    var date: Date = Date.now
    var isCorrect: Bool = false
    
    var flashcard: Flashcard?
    
    init(date: Date = .now, isCorrect: Bool) {
        self.date = date
        self.isCorrect = isCorrect
    }
}

// MARK: - SRS Engines

enum StudyMode {
    case review   // Real SRS, updates scheduling
    case practice // Consequence-free, tracks shadow performance
}

struct SRSEngine {
    
    /// The core SM-2 logic for real Spaced Repetition reviews.
    struct SpacedRepetitionEngine {
        
        /// Processes a real review, updating interval, ease, and next review date.
        static func processRealReview(card: Flashcard, quality: Int, context: ModelContext) {
            let now = Date()
            let isCorrect = quality > 0
            
            card.reviewCount += 1
            if isCorrect {
                card.correctReviews += 1
            } else {
                card.incorrectReviews += 1
            }
            
            card.lastReviewDate = now
            if card.reviewCount > 0 {
                let accuracy = Double(card.correctReviews) / Double(card.reviewCount)
                card.isStruggling = accuracy < 0.8
            }
            
            if quality == 0 {
                card.isStruggling = true
                card.easeFactor = max(1.3, card.easeFactor - 0.2)
                card.intervalDays = 0
                card.isLearning = true
                card.nextReviewDate = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now
            } else {
                if card.isLearning {
                    if quality >= 2 {
                        card.isLearning = false
                        card.intervalDays = (quality == 3) ? 4 : 1
                    } else {
                        card.nextReviewDate = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now
                    }
                } else {
                    var easePenalty: Double = 0.0
                    if card.practiceFailCount > 0 {
                        easePenalty = min(0.15, Double(card.practiceFailCount) * 0.05)
                    }
                    
                    switch quality {
                    case 1:
                        card.easeFactor = max(1.3, card.easeFactor - 0.15 - easePenalty)
                        card.intervalDays = max(1, Int(Double(card.intervalDays) * 1.2))
                    case 2:
                        card.easeFactor = max(1.3, card.easeFactor - easePenalty)
                        card.intervalDays = max(1, Int(Double(card.intervalDays) * card.easeFactor))
                    case 3:
                        card.easeFactor += 0.15 - easePenalty
                        card.intervalDays = max(1, Int(Double(card.intervalDays) * card.easeFactor * 1.3))
                    default: break
                    }
                }
                
                card.practiceFailCount = 0
                if !card.isLearning {
                    card.nextReviewDate = Calendar.current.date(byAdding: .day, value: card.intervalDays, to: now) ?? now
                }
            }
            
            let log = ReviewLog(date: now, isCorrect: isCorrect)
            log.flashcard = card
            context.insert(log)
            try? context.save()
        }
        
        /// Pulls due cards for a real review session using a database predicate.
        static func pullReviewCards(for deck: Deck, context: ModelContext) -> [Flashcard] {
            let deckId = deck.persistentModelID
            let now = Date()
            
            let predicate = #Predicate<Flashcard> { card in
                card.deck?.persistentModelID == deckId && card.nextReviewDate <= now
            }
            
            var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.nextReviewDate)])
            descriptor.fetchLimit = 100 // Prevent memory exhaustion on massive overdue backlogs
            
            do {
                let cards = try context.fetch(descriptor)
                return cards.shuffled()
            } catch {
                return []
            }
        }
    }
    
    /// The engine for Practice Mode sessions.
    struct PracticeSessionEngine {
        
        static func pullPracticeCards(for deck: Deck, context: ModelContext) -> [Flashcard] {
            let deckId = deck.persistentModelID
            let calendar = Calendar.current
            let now = Date()
            let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
            
            // Tier 1: Struggling cards
            let strugglingPredicate = #Predicate<Flashcard> { card in
                card.deck?.persistentModelID == deckId && card.isStruggling
            }
            var strugglingDesc = FetchDescriptor(predicate: strugglingPredicate)
            strugglingDesc.fetchLimit = 20
            
            // Tier 2: Recent reviews
            let recentPredicate = #Predicate<Flashcard> { card in
                card.deck?.persistentModelID == deckId && card.lastReviewDate != nil && card.lastReviewDate! >= threeDaysAgo
            }
            var recentDesc = FetchDescriptor(predicate: recentPredicate)
            recentDesc.fetchLimit = 20
            
            do {
                let struggling = try context.fetch(strugglingDesc)
                let recent = try context.fetch(recentDesc)
                
                var combined = Array(Set(struggling + recent))
                
                // Tier 3: Absolute Fallback (if no reviews yet or everything is perfect)
                if combined.isEmpty {
                    var fallbackDesc = FetchDescriptor<Flashcard>(
                        predicate: #Predicate { $0.deck?.persistentModelID == deckId },
                        sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
                    )
                    fallbackDesc.fetchLimit = 20
                    combined = try context.fetch(fallbackDesc)
                }
                
                return combined.shuffled()
            } catch {
                return []
            }
        }
        
        static func processPracticeResult(card: Flashcard, quality: Int) {
            if quality == 0 {
                card.practiceFailCount += 1
            }
        }
    }
}
