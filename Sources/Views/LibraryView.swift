import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @State private var showSettings = false
    @State private var isShowingDocumentPicker = false
    @Binding var selectedTab: TabSelection
    @Binding var activeBook: Book?
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.books.isEmpty {
                    ContentUnavailableView(
                        "No Books",
                        systemImage: "books.vertical",
                        description: Text("Drop an EPUB to start reading.")
                    )
                } else if viewModel.filteredBooks.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    List {
                        // Search bar as a special non-deletable row
                        SearchBar(text: $viewModel.searchText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 4, trailing: 20))
                        
                        ForEach(viewModel.filteredBooks) { book in
                            LibraryCard(book: book) {
                                activeBook = book
                                selectedTab = .reader
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.confirmDeletion(book: book, context: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onAppear {
                                if book.id == viewModel.books.last?.id && viewModel.hasMoreBooks && viewModel.searchText.isEmpty {
                                    viewModel.loadBooks(context: modelContext)
                                }
                            }
                        }
                        
                        // Loading indicator at bottom
                        if viewModel.isLoading && viewModel.searchText.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(LumeñoPastel.accent)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        
                        // Bottom spacer row for tab bar
                        Color.clear
                            .frame(height: 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .overlay {
                if case .importing(let progress) = viewModel.importState {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(LumeñoPastel.accent)
                            Text("Unpacking EPUB...")
                                .font(.headline)
                                .foregroundColor(LumeñoPastel.primaryText)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(LumeñoPastel.secondaryText)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(40)
                    }
                    .transition(.opacity)
                } else if viewModel.importState == .success {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("Import Complete")
                                .font(.headline)
                                .foregroundColor(LumeñoPastel.primaryText)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(40)
                    }
                    .transition(.opacity)
                }
            }
            .background(LumeñoPastel.immersiveBackground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        Button(action: { isShowingDocumentPicker = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear {
                if viewModel.books.isEmpty { viewModel.loadBooks(context: modelContext, reset: true) }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if !newValue.isEmpty {
                    viewModel.searchBooks(context: modelContext, query: newValue)
                } else {
                    viewModel.loadBooks(context: modelContext, reset: true)
                }
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPicker { url in
                    Task {
                        await viewModel.importEPUB(url: url, container: modelContext.container, context: modelContext)
                    }
                }
            }
            .animation(.easeInOut, value: viewModel.importState)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Import Failed", isPresented: $viewModel.showImportError, presenting: viewModel.importError) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert("Delete Book?", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.bookToDelete) { book in
                Button("Delete", role: .destructive) {
                    viewModel.deleteConfirmedBook(context: modelContext)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDeletion()
                }
            } message: { book in
                Text("This book has \(viewModel.bookFlashcardCount) flashcards. Deleting it will not remove your flashcards.")
            }
        }
    }
}

struct LibraryCard: View {
    let book: Book
    let onOpen: () -> Void
    
    
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 16) {
                // Book Cover / Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LumeñoPastel.accent.opacity(0.15))
                    
                    if let coverData = book.cover?.data, let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(LumeñoPastel.accent)
                            .font(.system(size: 22))
                    }
                }
                .frame(width: 52, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(LumeñoPastel.primaryText)
                        .lineLimit(2)
                    
                    Text(book.author)
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
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(LumeñoPastel.secondaryText)
                .font(.system(size: 16, weight: .bold))
            
            TextField("Find books or authors", text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LumeñoPastel.primaryText)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LumeñoPastel.secondaryText)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LumeñoPastel.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(LumeñoPastel.primaryText.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
