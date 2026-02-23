import SwiftUI

/// Defines the color requirements for any Lumeño theme, ported from ThinkTank.
protocol AppTheme {
    var id: String { get }
    var displayName: String { get }
    
    var background: Color { get }
    var accent: Color { get }
    var secondaryAccent: Color { get }
    
    var primaryText: Color { get }
    var secondaryText: Color { get }
    
    var radialCenter: Color { get }
    var radialEdge: Color { get }
}

struct StudioTheme: AppTheme {
    let id = "studio"
    let displayName = "Studio"
    
    let background = Color(red: 0.17, green: 0.15, blue: 0.13)
    let accent = Color(red: 0.85, green: 0.47, blue: 0.03) // Terracotta Gold
    let secondaryAccent = Color(red: 0.9, green: 0.7, blue: 0.2)
    
    let primaryText = Color.white
    let secondaryText = Color.white.opacity(0.6)
    
    let radialCenter = Color(red: 0.22, green: 0.18, blue: 0.15)
    let radialEdge = Color(red: 0.12, green: 0.10, blue: 0.08)
}

struct MatchaTheme: AppTheme {
    let id = "matcha"
    let displayName = "Matcha"
    
    let background = Color(red: 0.94, green: 0.96, blue: 0.94)
    let accent = Color(red: 0.35, green: 0.5, blue: 0.25)
    let secondaryAccent = Color(red: 0.25, green: 0.55, blue: 0.35)
    
    let primaryText = Color(red: 0.15, green: 0.2, blue: 0.15)
    let secondaryText = Color(red: 0.3, green: 0.35, blue: 0.3).opacity(0.8)
    
    let radialCenter = Color(red: 0.94, green: 0.96, blue: 0.94)
    let radialEdge = Color(red: 0.85, green: 0.88, blue: 0.85)
}

struct NordicTheme: AppTheme {
    let id = "nordic"
    let displayName = "Nordic"
    
    let background = Color(red: 0.18, green: 0.20, blue: 0.25)
    let accent = Color(red: 0.53, green: 0.75, blue: 0.82)
    let secondaryAccent = Color(red: 0.5, green: 0.7, blue: 0.9)
    
    let primaryText = Color(red: 0.92, green: 0.94, blue: 0.96)
    let secondaryText = Color(red: 0.75, green: 0.8, blue: 0.85).opacity(0.9)
    
    let radialCenter = Color(red: 0.25, green: 0.28, blue: 0.35)
    let radialEdge = Color(red: 0.12, green: 0.14, blue: 0.18)
}

struct ClassicTheme: AppTheme {
    let id = "classic"
    let displayName = "Classic"
    
    let background = Color(uiColor: .systemBackground)
    let accent = Color.accentColor
    let secondaryAccent = Color.blue
    
    let primaryText = Color.primary
    let secondaryText = Color.secondary
    
    let radialCenter = Color(uiColor: .systemBackground)
    let radialEdge = Color(uiColor: .systemBackground).opacity(0.95)
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    private let storageKey = "Lumeno_SelectedTheme"
    
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.id, forKey: storageKey)
        }
    }
    
    let allThemes: [AppTheme] = [
        ClassicTheme(),
        StudioTheme(),
        MatchaTheme(),
        NordicTheme()
    ]
    
    private init() {
        let savedId = UserDefaults.standard.string(forKey: storageKey)
        
        switch savedId {
        case "studio":  self.currentTheme = StudioTheme()
        case "matcha":  self.currentTheme = MatchaTheme()
        case "nordic":  self.currentTheme = NordicTheme()
        default:        self.currentTheme = ClassicTheme()
        }
    }
}

/// A dynamic proxy for the current theme, providing easy access to colors.
enum LumeñoPastel {
    static var current: AppTheme {
        ThemeManager.shared.currentTheme
    }

    static var background: Color { current.background }
    static var accent: Color { current.accent }
    static var primaryText: Color { current.primaryText }
    static var secondaryText: Color { current.secondaryText }
    
    static var immersiveBackground: some View {
        ThemeBackgroundView()
            .ignoresSafeArea()
    }
}

struct ThemeBackgroundView: View {
    @State private var manager = ThemeManager.shared
    
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [manager.currentTheme.radialCenter, manager.currentTheme.radialEdge]),
            center: .top,
            startRadius: 0,
            endRadius: 800
        )
    }
}

struct ThemeOptionView: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(theme.background)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(isSelected ? theme.accent : LumeñoPastel.primaryText.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                        )
                    
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 10, height: 10)
                        .shadow(color: theme.accent.opacity(0.4), radius: 4)
                }
                
                Text(theme.displayName.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .kerning(1)
                    .foregroundStyle(isSelected ? LumeñoPastel.accent : LumeñoPastel.primaryText.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

/// A global premium button style for cards that provides a subtle scale down effect when pressed,
/// without breaking native ScrollView or List interactions like `onLongPressGesture` does.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
