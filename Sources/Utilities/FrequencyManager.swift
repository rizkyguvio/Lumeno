import Foundation

enum WordDifficulty: String, CaseIterable {
    case extremelyCommon = "Very Common"
    case common = "Common"
    case intermediate = "Intermediate"
    case rare = "Rare"
    case extremelyRare = "Very Rare"
}

enum Badge: String {
    case challenging = "🔥 Challenging"
    case mastered = "✅ Mastered"
    case frequencyBased = "Based on Frequency"
    
    // We add computed properties for colors
    var color: String {
        switch self {
        case .challenging: return "red"
        case .mastered: return "green"
        case .frequencyBased: return "gray" // Falls back to difficulty color
        }
    }
}

struct PersonalizedDifficulty {
    let generalFrequencyRank: Int?
    let userReviewCount: Int
    let userAccuracy: Double
    let baselineDifficulty: WordDifficulty
    
    var knownPercentage: Double {
        return userReviewCount > 0 ? userAccuracy : 0.0
    }
    
    var badge: Badge {
        // If user keeps getting it wrong despite many reviews
        if userReviewCount > 5 && userAccuracy < 0.5 {
            return .challenging
        }
        // If user nails it consistently
        if userReviewCount > 3 && userAccuracy > 0.9 {
            return .mastered
        }
        return .frequencyBased // Fallback logic is handled by specific views
    }
    
    var recommendationLevel: String {
        switch badge {
        case .challenging: return "HIGH - Review Often"
        case .mastered: return "LOW - Already Mastered"
        case .frequencyBased:
            switch baselineDifficulty {
            case .extremelyCommon: return "HIGH - Core Vocabulary"
            case .common: return "HIGH - Good to Learn"
            case .intermediate: return "MEDIUM - Useful"
            case .rare: return "LOW - Specialized"
            case .extremelyRare: return "VERY LOW - Negligible"
            }
        }
    }
}

class FrequencyManager {
    static let shared = FrequencyManager()
    
    private var frequencyDict: [String: Int] = [:]
    
    private init() {
        loadDictionary()
    }
    
    private func loadDictionary() {
        guard let url = Bundle.main.url(forResource: "SpanishFrequencyList", withExtension: "json") else {
            print("Warning: SpanishFrequencyList.json not found in Bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            frequencyDict = try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            print("Failed to load frequency dictionary: \(error)")
        }
    }
    
    func getRank(for word: String) -> Int? {
        let cleanedWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return frequencyDict[cleanedWord]
    }
    
    func getDifficulty(for word: String) -> WordDifficulty {
        let rank = getRank(for: word) ?? Int.max
        
        switch rank {
        case 1...1000:
            return .extremelyCommon
        case 1001...3000:
            return .common
        case 3001...8000:
            return .intermediate
        case 8001...15000:
            return .rare
        default:
            return .extremelyRare
        }
    }
}
