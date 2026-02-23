import SwiftUI
import SwiftData

struct StudyView: View {
    let deck: Deck
    let mode: StudyMode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // State for the quiz session
    @State private var dueCards: [Flashcard] = []
    @State private var currentCardIndex = 0
    @State private var isShowingAnswer = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = true
    
    var currentCard: Flashcard? {
        guard currentCardIndex < dueCards.count else { return nil }
        return dueCards[currentCardIndex]
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(LumeñoPastel.accent)
                        Text("Preparing your session...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LumeñoPastel.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else if let card = currentCard {
                    // Card Content
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Front of card
                        VStack(spacing: 16) {
                            Text(card.word)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(LumeñoPastel.primaryText)
                                .multilineTextAlignment(.center)
                            
                            if !card.sentenceContext.isEmpty && card.sentenceContext != card.word {
                                Text(card.sentenceContext)
                                    .font(.title3)
                                    .italic()
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        
                        Divider().padding(.vertical)
                        
                        // Back of card
                        if isShowingAnswer {
                            VStack(spacing: 12) {
                                Text(card.translation)
                                    .font(.title2)
                                    .foregroundColor(LumeñoPastel.accent)
                                    .multilineTextAlignment(.center)
                                
                                if !card.notes.isEmpty {
                                    Text(card.notes)
                                        .font(.body)
                                        .foregroundColor(LumeñoPastel.primaryText)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            // Placeholder to keep layout stable
                            Text("Tap to reveal")
                                .font(.title2)
                                .foregroundColor(.clear)
                        }
                        
                        Spacer()
                        
                        // Controls
                        if isShowingAnswer {
                            HStack(spacing: 12) {
                                AnswerButton(title: "Again", color: .red) {
                                    if mode == .review { HapticManager.shared.studyAgain() }
                                    processAnswer(quality: 0)
                                }
                                AnswerButton(title: "Hard", color: .orange) {
                                    if mode == .review { HapticManager.shared.studyHard() }
                                    processAnswer(quality: 1)
                                }
                                AnswerButton(title: "Good", color: .green) {
                                    if mode == .review { HapticManager.shared.studyGood() }
                                    processAnswer(quality: 2)
                                }
                                AnswerButton(title: "Easy", color: .blue) {
                                    if mode == .review { HapticManager.shared.studyEasy() }
                                    processAnswer(quality: 3)
                                }
                            }
                            .padding(.bottom, 30)
                        } else {
                            Button {
                                withAnimation {
                                    isShowingAnswer = true
                                }
                            } label: {
                                Text("Show Answer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LumeñoPastel.accent)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                    }
                } else {
                    // Session Complete - Immersive Overhaul
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // Icon & Celebration
                        ZStack {
                            Circle()
                                .fill(LumeñoPastel.accent.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .scaleEffect(1.2)
                            
                            Image(systemName: mode == .review ? "sparkles" : "bolt.shield.fill")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [LumeñoPastel.accent, LumeñoPastel.accent.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: LumeñoPastel.accent.opacity(0.3), radius: 15, y: 10)
                        }
                        
                        VStack(spacing: 16) {
                            Text(mode == .review ? "Review Complete!" : "Practice Session Finished")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(LumeñoPastel.primaryText)
                                .multilineTextAlignment(.center)
                            
                            Text(mode == .review ? "You've mastered these cards for now. Your progress has been scientifically updated." : "Great work! These shadow reviews helped reinforce your memory without affecting your formal schedule.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(LumeñoPastel.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .lineSpacing(4)
                        }
                        
                        // Summary Card (Placeholder for future stats)
                        HStack(spacing: 20) {
                            StatSummaryView(title: "CARDS", value: "\(dueCards.count)", icon: "rectangle.stack")
                            StatSummaryView(title: "SUCCESS", value: "100%", icon: "checkmark.circle")
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                        
                        Button {
                            HapticManager.shared.softTap()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(LumeñoPastel.accent)
                                .clipShape(Capsule())
                                .shadow(color: LumeñoPastel.accent.opacity(0.4), radius: 10, y: 5)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                    .onAppear {
                        HapticManager.shared.success()
                    }
                }
            }
            .background(LumeñoPastel.immersiveBackground.ignoresSafeArea())
            .navigationTitle(mode == .review ? "Review: \(deck.name)" : "Practice: \(deck.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(LumeñoPastel.primaryText)
                }
            }
            .onAppear(perform: loadCards)
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    private func loadCards() {
        isLoading = true
        
        // Use a slight delay to ensure SwiftData context is settled and provide visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if mode == .review {
                dueCards = SRSEngine.SpacedRepetitionEngine.pullReviewCards(for: deck, context: modelContext)
            } else {
                dueCards = SRSEngine.PracticeSessionEngine.pullPracticeCards(for: deck, context: modelContext)
            }
            
            withAnimation {
                isLoading = false
            }
        }
    }
    
    /// Quality: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy
    private func processAnswer(quality: Int) {
        guard let card = currentCard else { return }
        
        if mode == .review {
            SRSEngine.SpacedRepetitionEngine.processRealReview(card: card, quality: quality, context: modelContext)
            
            // For real reviews, re-trigger "Again" cards in the current session
            if quality == 0 {
                dueCards.append(card)
            }
        } else {
            SRSEngine.PracticeSessionEngine.processPracticeResult(card: card, quality: quality)
            
            // For practice, we can always re-re-trigger failed cards if we want immersion
            if quality == 0 {
                dueCards.append(card)
            }
            
            // Save context for shadow stats (practiceFailCount)
            try? modelContext.save()
        }
        
        // Move UI forward
        withAnimation {
            isShowingAnswer = false
            currentCardIndex += 1
        }
    }
}

struct AnswerButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(10)
        }
    }
}

struct StatSummaryView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(LumeñoPastel.secondaryText)
            
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(LumeñoPastel.primaryText)
            
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .kerning(1)
                .foregroundColor(LumeñoPastel.secondaryText.opacity(0.8))
        }
        .frame(width: 100, height: 100)
        .background(LumeñoPastel.primaryText.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(LumeñoPastel.primaryText.opacity(0.06), lineWidth: 1)
        )
    }
}
