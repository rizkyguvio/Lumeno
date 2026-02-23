import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var flashcards: [Flashcard]
    @Query private var books: [Book]
    @Query(sort: \ReviewLog.date, order: .forward) private var reviewLogs: [ReviewLog]
    @Environment(ThemeManager.self) private var themeManager

    // Group reviews by Day for retention curve
    private var dailyReviews: [(Date, Int, Int)] {
        let calendar = Calendar.current
        var dict: [Date: (correct: Int, incorrect: Int)] = [:]
        
        for log in reviewLogs {
            let startOfDay = calendar.startOfDay(for: log.date)
            let current = dict[startOfDay] ?? (0, 0)
            dict[startOfDay] = (
                current.correct + (log.isCorrect ? 1 : 0),
                current.incorrect + (!log.isCorrect ? 1 : 0)
            )
        }
        
        return dict.map { ($0.key, $0.value.correct, $0.value.incorrect) }
            .sorted { $0.0 < $1.0 }
    }
    
    // Overall Accuracy
    private var overallAccuracy: Double {
        let totalCorrect = flashcards.reduce(0) { $0 + $1.correctReviews }
        let totalReviews = flashcards.reduce(0) { $0 + $1.reviewCount }
        guard totalReviews > 0 else { return 0.0 }
        return Double(totalCorrect) / Double(totalReviews)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // High-level KPIs
                    HStack(spacing: 16) {
                        StatCard(title: "TOTAL WORDS", value: "\(flashcards.count)", icon: "text.book.closed")
                        StatCard(title: "ACCURACY", value: String(format: "%.1f%%", overallAccuracy * 100), icon: "target")
                    }
                    .padding(.horizontal)
                    
                    // Retention Curve Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Review Activity")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(LumeñoPastel.primaryText)
                            .padding(.horizontal)
                        
                        if dailyReviews.isEmpty {
                            ContentUnavailableView("No Data Yet", systemImage: "chart.xyaxis.line", description: Text("Review some flashcards to see your retention curve."))
                                .frame(height: 200)
                        } else {
                            Chart {
                                ForEach(dailyReviews, id: \.0) { day, correct, incorrect in
                                    BarMark(
                                        x: .value("Day", day, unit: .day),
                                        y: .value("Correct", correct)
                                    )
                                    .foregroundStyle(Color.green.opacity(0.7))
                                    
                                    BarMark(
                                        x: .value("Day", day, unit: .day),
                                        y: .value("Incorrect", incorrect)
                                    )
                                    .foregroundStyle(Color.red.opacity(0.7))
                                }
                            }
                            .frame(height: 250)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(LumeñoPastel.primaryText.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .strokeBorder(LumeñoPastel.primaryText.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Book breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vocabulary by Book")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(LumeñoPastel.primaryText)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(books) { book in
                                BookStatRow(book: book)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 140) // Space for floating tab bar
            }
            .navigationTitle("Analytics")
            .background(LumeñoPastel.immersiveBackground)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(LumeñoPastel.accent)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1)
                    .foregroundColor(LumeñoPastel.secondaryText)
            }
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(LumeñoPastel.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LumeñoPastel.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LumeñoPastel.primaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct BookStatRow: View {
    let book: Book
    
    var flashcardCount: Int {
        book.flashcards.count
    }
    
    var knownPercentage: Double {
        guard book.totalWordsCount > 0 else { return 0 }
        let unknown = min(flashcardCount, book.totalWordsCount)
        let known = book.totalWordsCount - unknown
        return Double(known) / Double(book.totalWordsCount)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(LumeñoPastel.primaryText)
                Text("Words saved: \(flashcardCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(LumeñoPastel.secondaryText)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", knownPercentage * 100))
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(LumeñoPastel.accent)
                Text("Known Vocab")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(LumeñoPastel.secondaryText.opacity(0.6))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LumeñoPastel.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LumeñoPastel.primaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
