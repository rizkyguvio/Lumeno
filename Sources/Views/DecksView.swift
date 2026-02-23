import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel = DecksViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.decks.isEmpty {
                    ContentUnavailableView(
                        "No Decks",
                        systemImage: "rectangle.stack",
                        description: Text("Create a deck here or while saving a flashcard in the reader.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.decks) { deck in
                                DeckCard(deck: deck) {
                                    viewModel.deckToEdit = deck
                                    viewModel.editDeckName = deck.name
                                    viewModel.showingEditDeck = true
                                } onDelete: {
                                    if let index = viewModel.decks.firstIndex(where: { $0.id == deck.id }) {
                                        viewModel.deleteDecks(at: IndexSet(integer: index), context: modelContext)
                                    }
                                }
                                .onAppear {
                                    if deck.id == viewModel.decks.last?.id && viewModel.hasMoreDecks {
                                        viewModel.loadDecks(context: modelContext)
                                    }
                                }
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(LumeñoPastel.accent)
                                    .padding(.vertical)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 120) // Space for floating tab bar
                    }
                }
            }
            .background(LumeñoPastel.immersiveBackground)
            .navigationTitle("Decks")
            .onAppear {
                if viewModel.decks.isEmpty { viewModel.loadDecks(context: modelContext, reset: true) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.showingAddDeck = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Deck", isPresented: $viewModel.showingAddDeck) {
                TextField("Deck Name", text: $viewModel.newDeckName)
                Button("Cancel", role: .cancel) {
                    viewModel.newDeckName = ""
                }
                Button("Create") {
                    viewModel.addDeck(context: modelContext)
                }
            }
            .alert("Edit Deck", isPresented: $viewModel.showingEditDeck) {
                TextField("Deck Name", text: $viewModel.editDeckName)
                Button("Cancel", role: .cancel) {
                    viewModel.editDeckName = ""
                    viewModel.deckToEdit = nil
                }
                Button("Save") {
                    viewModel.saveEditedDeck(context: modelContext)
                }
            }
            .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
                Button("OK", role: .cancel) { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    // Moved to DecksViewModel
}

struct StudySession: Identifiable {
    let id = UUID()
    let deck: Deck
    let mode: StudyMode
}

struct DeckDetailView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel: DeckDetailViewModel
    
    init(deck: Deck) {
        self.deck = deck
        self._viewModel = State(wrappedValue: DeckDetailViewModel(deck: deck))
    }
    
    var body: some View {
        ZStack {
            LumeñoPastel.immersiveBackground.ignoresSafeArea()
            
            List {
                // 1. Two-Engine Dashboard (Side-by-Side Cards)
                if viewModel.deckCardCount > 0 {
                    Section {
                        HStack(spacing: 16) {
                            // Review Card (SM-2)
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(LumeñoPastel.accent)
                                
                                Text("Review")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(LumeñoPastel.primaryText)
                                
                                Text("Build your long-term memory.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 8)
                                
                                Button {
                                    HapticManager.shared.success()
                                    viewModel.studySession = StudySession(deck: deck, mode: .review)
                                } label: {
                                    Text("Start")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(LumeñoPastel.accent))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(LumeñoPastel.primaryText.opacity(0.05), lineWidth: 1)
                                    )
                            )
                            
                            // Practice Card (Cram)
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(LumeñoPastel.accent)
                                
                                Text("Practice")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(LumeñoPastel.primaryText)
                                
                                Text("Consequence-free cramming.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 8)
                                
                                Button {
                                    HapticManager.shared.softTap()
                                    viewModel.studySession = StudySession(deck: deck, mode: .practice)
                                } label: {
                                    Text("Cram")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(LumeñoPastel.accent))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(LumeñoPastel.primaryText.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if viewModel.deckCardCount == 0 {
                    Text("No cards in this deck yet.")
                        .foregroundColor(LumeñoPastel.secondaryText)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.loadedCards) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.word)
                                .font(.headline)
                                .foregroundColor(LumeñoPastel.primaryText)
                            if !card.translation.isEmpty {
                                Text(card.translation)
                                    .font(.subheadline)
                                    .foregroundColor(LumeñoPastel.accent)
                            }
                            if !card.notes.isEmpty {
                                Text(card.notes)
                                    .font(.subheadline)
                                    .foregroundColor(LumeñoPastel.primaryText)
                            }
                            if !card.sentenceContext.isEmpty {
                                Text(card.sentenceContext)
                                    .font(.caption)
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(LumeñoPastel.primaryText.opacity(0.03))
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.cardToEdit = card
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete { viewModel.deleteCards(at: $0, context: modelContext) }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .navigationTitle(deck.name)
        .onAppear {
            viewModel.loadCards(context: modelContext)
        }
        .fullScreenCover(item: $viewModel.studySession) { session in
            StudyView(deck: session.deck, mode: session.mode)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.cardToEdit != nil },
            set: { if !$0 { viewModel.cardToEdit = nil } }
        )) {
            if let card = viewModel.cardToEdit {
                EditFlashcardView(flashcard: card)
            }
        }
        .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { msg in
            Text(msg)
        }
    }
}



struct DeckCard: View {
    let deck: Deck
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    @State private var cardCount: Int = 0
    
    var body: some View {
        NavigationLink(destination: DeckDetailView(deck: deck)) {
            HStack(spacing: 16) {
                // Deck Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LumeñoPastel.accent.opacity(0.1))
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundColor(LumeñoPastel.accent)
                }
                .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(LumeñoPastel.primaryText)
                    
                    Text("\(cardCount) cards")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LumeñoPastel.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LumeñoPastel.secondaryText.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LumeñoPastel.primaryText.opacity(0.04))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(LumeñoPastel.primaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            let deckId = deck.persistentModelID
            let count = try? modelContext.fetchCount(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.deck?.persistentModelID == deckId }))
            cardCount = count ?? 0
        }
        .swipeActions(edge: .leading) {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
