import SwiftUI
import SwiftData

struct SettingsView: View {
    @SecureStorage(key: "deepLAPIKey") private var deepLAPIKey: String
    @AppStorage("deepLSourceLang") private var deepLSourceLang: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var isImporting = false
    @State private var importError: Error?
    @State private var showImportError = false
    @State private var showImportSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Theme Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APPEARANCE")
                            .font(.system(size: 12, weight: .black))
                            .kerning(2)
                            .foregroundColor(LumeñoPastel.secondaryText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(themeManager.allThemes, id: \.id) { theme in
                                ThemeOptionView(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme.id == theme.id
                                ) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        themeManager.currentTheme = theme
                                    }
                                }
                            }
                        }
                    }
                    
                    // Translation Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRANSLATION")
                            .font(.system(size: 12, weight: .black))
                            .kerning(2)
                            .foregroundColor(LumeñoPastel.secondaryText)
                        
                        SecureField("DeepL API Key (Free Tier)", text: $deepLAPIKey)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                        
                        Text("If an API key is provided and you have internet access, Lumeño will use DeepL to automatically translate words inline. Otherwise, it defaults to the iOS 18 native translation popover offline.")
                            .font(.system(size: 12))
                            .foregroundColor(LumeñoPastel.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Source Language")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(LumeñoPastel.primaryText)
                            
                            Picker("Source Language", selection: $deepLSourceLang) {
                                Text("Auto-Detect (Recommended)").tag("")
                                Text("Spanish (ES)").tag("ES")
                                Text("French (FR)").tag("FR")
                                Text("German (DE)").tag("DE")
                                Text("Italian (IT)").tag("IT")
                                Text("Portuguese (PT)").tag("PT")
                                Text("Dutch (NL)").tag("NL")
                                Text("Russian (RU)").tag("RU")
                                Text("Japanese (JA)").tag("JA")
                                Text("Chinese (ZH)").tag("ZH")
                            }
                            .tint(LumeñoPastel.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                        }
                        
                        Link("Get DeepL API Free Key", destination: URL(string: "https://www.deepl.com/en/pro-api?cta=header-pro-api/")!)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(LumeñoPastel.accent)
                    }
                    
                    // Backup Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ANKI & BACKUP")
                            .font(.system(size: 12, weight: .black))
                            .kerning(2)
                            .foregroundColor(LumeñoPastel.secondaryText)
                        
                        Button {
                            isImporting = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Restore from TSV/CSV Backup")
                                Spacer()
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(LumeñoPastel.primaryText.opacity(0.05)))
                        }
                        .foregroundColor(LumeñoPastel.primaryText)
                        
                        Text("Your decks are automatically backed up as TSV files to the iOS Files app (On My iPhone > Contexto) every time you close the app. You can drag and drop these directly into Anki.")
                            .font(.system(size: 12))
                            .foregroundColor(LumeñoPastel.secondaryText)
                    }
                }
                .padding(24)
            }
            .background(LumeñoPastel.immersiveBackground)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.tabSeparatedText, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try BackupManager.shared.importDeckFromTSV(url: url, context: modelContext)
                        showImportSuccess = true
                    } catch {
                        importError = error
                        showImportError = true
                    }
                case .failure(let error):
                    importError = error
                    showImportError = true
                }
            }
            .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Deck restored successfully from your backup file.")
            }
        }
    }
}
