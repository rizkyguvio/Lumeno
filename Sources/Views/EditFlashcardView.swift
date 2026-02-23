import SwiftUI
import SwiftData

struct EditFlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let flashcard: Flashcard
    
    @State private var word: String
    @State private var translation: String
    @State private var notes: String
    @State private var sentenceContext: String
    
    init(flashcard: Flashcard) {
        self.flashcard = flashcard
        _word = State(initialValue: flashcard.word)
        _translation = State(initialValue: flashcard.translation)
        _notes = State(initialValue: flashcard.notes)
        _sentenceContext = State(initialValue: flashcard.sentenceContext)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Source Badge
                    if let source = flashcard.sourceTitle {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(LumeñoPastel.accent)
                            Text("From \(source)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(LumeñoPastel.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(LumeñoPastel.accent.opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.top, 16)
                    }
                    
                    // Core Info Card
                    CustomCard {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WORD")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(1.5)
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                
                                TextField("Enter word", text: $word)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(LumeñoPastel.primaryText)
                                
                                Divider()
                                    .background(LumeñoPastel.primaryText.opacity(0.1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TRANSLATION")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(1.5)
                                    .foregroundColor(LumeñoPastel.secondaryText)
                                
                                TextField("Enter translation", text: $translation)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(LumeñoPastel.primaryText)
                            }
                        }
                    }
                    
                    // Context Card
                    CustomCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SENTENCE CONTEXT")
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1.5)
                                .foregroundColor(LumeñoPastel.secondaryText)
                            
                            TextEditor(text: $sentenceContext)
                                .font(.system(size: 16))
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LumeñoPastel.primaryText.opacity(0.03))
                                )
                                .scrollContentBackground(.hidden)
                                .foregroundColor(LumeñoPastel.primaryText)
                        }
                    }
                    
                    // Notes Card
                    CustomCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1.5)
                                .foregroundColor(LumeñoPastel.secondaryText)
                            
                            TextEditor(text: $notes)
                                .font(.system(size: 16))
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LumeñoPastel.primaryText.opacity(0.03))
                                )
                                .scrollContentBackground(.hidden)
                                .foregroundColor(LumeñoPastel.primaryText)
                        }
                    }
                    
                    // Stats Summary Footer
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("REVIEWS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(LumeñoPastel.secondaryText)
                            Text("\(flashcard.reviewCount)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(LumeñoPastel.primaryText)
                        }
                        
                        VStack(spacing: 4) {
                            Text("ACCURACY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(LumeñoPastel.secondaryText)
                            let accuracy = flashcard.reviewCount > 0 ? (Double(flashcard.correctReviews) / Double(flashcard.reviewCount)) * 100 : 0
                            Text("\(Int(accuracy))%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(accuracy > 80 ? .green : (accuracy > 50 ? .yellow : .orange))
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(LumeñoPastel.immersiveBackground)
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(LumeñoPastel.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(LumeñoPastel.accent)
                }
            }
        }
    }
    
    private func saveChanges() {
        flashcard.word = word
        flashcard.translation = translation
        flashcard.notes = notes
        flashcard.sentenceContext = sentenceContext
        
        try? modelContext.save()
    }
}

// Local helper view to replicate the app's premium card aesthetic
struct CustomCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LumeñoPastel.primaryText.opacity(0.05), lineWidth: 1)
            )
    }
}
