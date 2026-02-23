import SwiftUI
import SwiftData
import Translation

struct ReaderView: View {
    let book: Book?
    @Binding var selectedTab: TabSelection
    @Binding var isChromeHidden: Bool
    
    var body: some View {
        Group {
            if let book = book {
                ChapterReaderView(book: book, selectedTab: $selectedTab, isChromeHidden: $isChromeHidden)
            } else {
                ContentUnavailableView("Reader", systemImage: "book.pages", description: Text("Select a book from the Library to start reading."))
            }
        }
        .onAppear {
            if book == nil {
                isChromeHidden = false
            }
        }
    }
}

struct ChapterReaderView: View {
    let book: Book
    @Binding var selectedTab: TabSelection
    @Binding var isChromeHidden: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    
    @State private var viewModel: ReaderViewModel
    @State private var showAppearanceMenu = false
    
    init(book: Book, selectedTab: Binding<TabSelection>, isChromeHidden: Binding<Bool>) {
        self.book = book
        self._selectedTab = selectedTab
        self._isChromeHidden = isChromeHidden
        self._viewModel = State(wrappedValue: ReaderViewModel(book: book))
    }
    
    private var chapterBinding: Binding<Int> {
        viewModel.chapterBinding()
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: chapterBinding) {
                ForEach(Array(viewModel.validChapters.enumerated()), id: \.element.id) { index, chapter in
                    ChapterPageView(
                        chapter: chapter,
                        index: index,
                        book: book,
                        chapterPages: Binding(
                            get: { viewModel.chapterPages },
                            set: { viewModel.chapterPages = $0 }
                        ),
                        chapterTotalPages: Binding(
                            get: { viewModel.chapterTotalPages },
                            set: { viewModel.chapterTotalPages = $0 }
                        ),
                        currentChapterIndex: viewModel.currentChapterIndex,
                        onSelection: { word, context in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isChromeHidden = true
                            }
                            viewModel.onSelection(word: word, contextStr: context, decks: decks)
                        },
                        onSelectionStateChange: { active in
                            viewModel.isSelectionActive = active
                        },
                        handleLinkTapped: { url in
                            viewModel.handleLinkTapped(url, fromChapterIndex: index, context: modelContext)
                        },
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isChromeHidden.toggle()
                            }
                        },
                        isSelectionActive: viewModel.isSelectionActive,
                        selectedWord: viewModel.selectedWord,
                        readerSettings: viewModel.readerSettings
                    )
                    .blur(radius: viewModel.selectedWord != nil ? 10 : 0)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            // Chrome toggling is now handled by EPUBReaderWebView's internal UITapGestureRecognizer
            
            // Premium Header (Chrome)
            if !isChromeHidden {
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            HapticManager.shared.softTap()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .library
                                isChromeHidden = false
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(LumeñoPastel.primaryText)
                                .padding(12)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        
                        Text(book.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(LumeñoPastel.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button {
                            HapticManager.shared.softTap()
                            showAppearanceMenu.toggle()
                        } label: {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(LumeñoPastel.primaryText)
                                .padding(12)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .popover(isPresented: $showAppearanceMenu) {
                            ReaderAppearanceMenu(settings: $viewModel.readerSettings) {
                                viewModel.resetReaderSettings()
                            }
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .top)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                }
            }
            
            // Dimming overlay for focus when word is selected
            if viewModel.selectedWord != nil {
                Color.black.opacity(0.15)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Small delay to prevent current selection gesture 
                        // from accidentally triggering the close
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedWord = nil
                        }
                    }
                    .transition(.opacity)
            }
            
            if let word = viewModel.selectedWord, !word.isEmpty {
                flashcardPopover(word: word)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedWord)
        .onChange(of: viewModel.selectedWord) { _, newWord in
            if let word = newWord, !word.isEmpty {
                // FORCE: When a word is selected, ensure chrome is hidden
                // This correctly hides the TabBar in ContentView
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isChromeHidden = true
                }
                viewModel.fetchWordTranslation(word: word, context: modelContext)
            }
        }
        .translationTask(viewModel.translationConfig) { session in
            if let word = viewModel.selectedWord, !word.isEmpty {
                do {
                    let response = try await session.translate(word)
                    // If the user hasn't already typed something, auto-fill it
                    if viewModel.translationText.isEmpty {
                        viewModel.translationText = response.targetText
                    }
                } catch {
                    print("Translation failed: \(error.localizedDescription)")
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { msg in
            Text(msg)
        }
        .onChange(of: viewModel.currentChapterIndex) { _, newIndex in
            viewModel.onChapterChanged(newIndex: newIndex, context: modelContext)
        }
        .onChange(of: viewModel.chapterPages[viewModel.currentChapterIndex]) { _, newPage in
            viewModel.onPageChanged(newPage: newPage, context: modelContext)
        }
    }
    
    private func difficultyColor(for difficulty: WordDifficulty) -> Color {
        switch difficulty {
        case .extremelyCommon: return .blue
        case .common: return .green
        case .intermediate: return .yellow
        case .rare: return .orange
        case .extremelyRare: return .red
        }
    }
    
    // MARK: - Navigation Handling
    @ViewBuilder
    private func flashcardPopover(word: String) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(word)
                        .font(.title3).bold()
                        .foregroundColor(LumeñoPastel.primaryText)
                    
                    Spacer()
                    Button {
                        viewModel.selectedWord = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(LumeñoPastel.secondaryText)
                            .imageScale(.large)
                    }
                }
                
                // Analytics UI Enhancements
                let rank = FrequencyManager.shared.getRank(for: word)
                let baseDifficulty = FrequencyManager.shared.getDifficulty(for: word)
                
                let matchingCards = book.flashcards.filter { $0.word.lowercased() == word.lowercased() }
                let reviewCount = matchingCards.reduce(0) { $0 + $1.reviewCount }
                let correctCount = matchingCards.reduce(0) { $0 + $1.correctReviews }
                let accuracy = reviewCount > 0 ? Double(correctCount) / Double(reviewCount) : 0.0
                
                let occurrences = book.chapters.reduce(0) { total, chapter in
                    let cleanedContent = chapter.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    let components = cleanedContent.components(separatedBy: .whitespacesAndNewlines)
                    return total + components.filter { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) == word.lowercased() }.count
                }
                
                let personalizedData = PersonalizedDifficulty(
                    generalFrequencyRank: rank,
                    userReviewCount: reviewCount,
                    userAccuracy: accuracy,
                    baselineDifficulty: baseDifficulty
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(personalizedData.badge.rawValue)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(personalizedData.badge.color).opacity(0.2))
                            .foregroundColor(Color(personalizedData.badge.color))
                            .clipShape(Capsule())
                        
                        Spacer()
                        if let r = rank {
                            Text("[\(r)th]")
                                .font(.caption)
                                .foregroundColor(LumeñoPastel.secondaryText)
                        }
                    }
                    
                    if reviewCount > 0 {
                        HStack {
                            ProgressView(value: accuracy)
                                .progressViewStyle(.linear)
                                .tint(accuracy > 0.8 ? .green : (accuracy > 0.5 ? .yellow : .red))
                            Text("\(Int(accuracy * 100))% Known")
                                .font(.caption2)
                                .foregroundColor(LumeñoPastel.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(LumeñoPastel.accent)
                        Text("\(baseDifficulty.rawValue) in Spanish")
                            .font(.caption)
                            .foregroundColor(LumeñoPastel.secondaryText)
                    }
                    
                    HStack {
                        Image(systemName: "book.pages.fill")
                            .foregroundColor(LumeñoPastel.accent.opacity(0.8))
                        Text("Appears \(occurrences)× in this book")
                            .font(.caption)
                            .foregroundColor(LumeñoPastel.secondaryText)
                    }
                    
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(LumeñoPastel.accent.opacity(0.9))
                        Text("Worth learning: \(personalizedData.recommendationLevel)")
                            .font(.caption)
                            .foregroundColor(LumeñoPastel.primaryText)
                    }
                }
                .padding()
                .background(LumeñoPastel.secondaryText.opacity(0.1))
                .cornerRadius(12)
                
                if !viewModel.selectedContext.isEmpty && viewModel.selectedContext != word {
                    Text(viewModel.selectedContext)
                        .font(.caption)
                        .foregroundColor(LumeñoPastel.secondaryText)
                        .italic()
                        .lineLimit(3)
                }
                
                if viewModel.isDuplicate(decks: decks) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This word is already in the selected deck.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 2)
                }
                    
                TextField("Translation...", text: $viewModel.translationText)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                    .foregroundColor(LumeñoPastel.primaryText)
                    
                TextField("Notes (Optional)...", text: $viewModel.notesText)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                    .foregroundColor(LumeñoPastel.primaryText)
                
                Divider()
                    .overlay(LumeñoPastel.primaryText.opacity(0.1))
                    .padding(.vertical, 4)
                    
                HStack {
                    if decks.isEmpty {
                        TextField("New Deck Name", text: $viewModel.newDeckName)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                            .foregroundColor(LumeñoPastel.primaryText)
                    } else {
                        Picker("Deck", selection: $viewModel.selectedDeck) {
                            ForEach(decks) { deck in
                                Text(deck.name).tag(deck as Deck?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticManager.shared.softTap()
                        viewModel.saveFlashcard(context: modelContext, decks: decks)
                    } label: {
                        Text("Save Card")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(viewModel.translationText.isEmpty || (decks.isEmpty && viewModel.newDeckName.isEmpty) ? Color.gray.opacity(0.5) : LumeñoPastel.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.translationText.isEmpty || (decks.isEmpty && viewModel.newDeckName.isEmpty))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LumeñoPastel.primaryText.opacity(0.08), lineWidth: 1)
            )
            .padding(16)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedWord)
    }
}

private struct ChapterPageView: View {
    let chapter: Chapter
    let index: Int
    let book: Book
    @Binding var chapterPages: [Int: Int]
    @Binding var chapterTotalPages: [Int: Int]
    let currentChapterIndex: Int
    let onSelection: (String, String) -> Void
    let onSelectionStateChange: (Bool) -> Void
    let handleLinkTapped: (URL) -> Void
    let onTap: () -> Void
    let isSelectionActive: Bool
    let selectedWord: String?
    let readerSettings: ReaderSettings
    
    var baseURL: URL? {
        if let path = book.contentDirectoryPath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if abs(index - currentChapterIndex) <= 1 {
                EPUBReaderWebView(
                    htmlContent: chapter.content,
                    baseURL: baseURL,
                    currentPage: Binding(
                        get: { chapterPages[index] ?? 0 },
                        set: { chapterPages[index] = $0 }
                    ),
                    totalPages: Binding(
                        get: { chapterTotalPages[index] ?? 1 },
                        set: { chapterTotalPages[index] = $0 }
                    ),
                    initialPage: (index == currentChapterIndex && book.lastReadPage > 0) ? book.lastReadPage : 0,
                    onSelection: onSelection,
                    onNavigation: handleLinkTapped,
                    onSelectionStateChange: onSelectionStateChange,
                    onTap: onTap,
                    isScrollLocked: isSelectionActive,
                    selectedWord: selectedWord,
                    readerSettings: readerSettings
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Page indicator for current chapter
            HStack {
                Text("Ch. \(index + 1)  •  Page \((chapterPages[index] ?? 0) + 1) of \(chapterTotalPages[index] ?? 1)")
                    .font(.caption)
                    .foregroundColor(LumeñoPastel.secondaryText)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }
}
