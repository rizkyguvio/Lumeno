import SwiftUI
import SwiftData
import Translation

enum TabSelection {
    case library, reader, decks, stats
}

struct ContentView: View {
    @State private var selectedTab: TabSelection = .library
    @State private var activeBook: Book?
    @State private var isChromeHidden: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack(alignment: .bottom) {
            LumeñoPastel.immersiveBackground
            
            Group {
                switch selectedTab {
                case .library:
                    LibraryView(selectedTab: $selectedTab, activeBook: $activeBook)
                case .reader:
                    ReaderView(book: activeBook, selectedTab: $selectedTab, isChromeHidden: $isChromeHidden)
                case .decks:
                    DecksView()
                case .stats:
                    StatsView()
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            
            // Custom Floating Tab Bar
            let shouldShowTabBar = selectedTab != .reader || activeBook == nil || !isChromeHidden
            
            if shouldShowTabBar {
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
        .preferredColorScheme(themeManager.currentTheme.id == "matcha" ? .light : (themeManager.currentTheme.id == "classic" ? nil : .dark))
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                BackupManager.shared.autoBackupAllDecks(context: modelContext)
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabSelection
    
    var body: some View {
        HStack {
            tabButton(tab: .library, icon: "books.vertical", label: "Library")
            Spacer()
            tabButton(tab: .reader, icon: "book.pages", label: "Reader")
            Spacer()
            tabButton(tab: .decks, icon: "rectangle.stack", label: "Decks")
            Spacer()
            tabButton(tab: .stats, icon: "chart.bar", label: "Analytics")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func tabButton(tab: TabSelection, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            if !isSelected {
                HapticManager.shared.softTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(isSelected ? LumeñoPastel.accent : LumeñoPastel.primaryText.opacity(0.4))
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}


