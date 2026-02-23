import SwiftUI

struct ReaderAppearanceMenu: View {
    @Binding var settings: ReaderSettings
    let onReset: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Appearance")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(LumeñoPastel.primaryText)
                    Spacer()
                    Button {
                        HapticManager.shared.softTap()
                        onReset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(LumeñoPastel.accent)
                            .padding(8)
                            .background(Circle().fill(LumeñoPastel.accent.opacity(0.1)))
                    }
                }
                .padding(.bottom, 4)
                
                // Font Size Stepper
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font Size")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(LumeñoPastel.secondaryText)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(Int(settings.fontSize))")
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(LumeñoPastel.accent)
                    }
                    
                    HStack(spacing: 20) {
                        Button {
                            HapticManager.shared.softTap()
                            settings.fontSize = max(12, settings.fontSize - 1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(StepperButtonStyle())
                        
                        Slider(value: $settings.fontSize, in: 12...32, step: 1)
                            .tint(LumeñoPastel.accent)
                        
                        Button {
                            HapticManager.shared.softTap()
                            settings.fontSize = min(32, settings.fontSize + 1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(StepperButtonStyle())
                    }
                }
                
                // Font Family Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("Font")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(LumeñoPastel.secondaryText)
                        .textCase(.uppercase)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(ReaderSettings.fonts, id: \.self) { font in
                            Button {
                                HapticManager.shared.softTap()
                                settings.fontFamily = font
                            } label: {
                                Text(font)
                                    .font(.system(size: 14, weight: settings.fontFamily == font ? .bold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(settings.fontFamily == font ? LumeñoPastel.accent : LumeñoPastel.primaryText.opacity(0.05))
                                    )
                                    .foregroundColor(settings.fontFamily == font ? .white : LumeñoPastel.primaryText)
                            }
                        }
                    }
                }
                
                Divider().opacity(0.3)
                
                // Layout Toggles
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Justify")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(LumeñoPastel.secondaryText)
                            .textCase(.uppercase)
                        Toggle("", isOn: $settings.isJustified)
                            .labelsHidden()
                            .tint(LumeñoPastel.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bold")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(LumeñoPastel.secondaryText)
                            .textCase(.uppercase)
                        Toggle("", isOn: $settings.isBold)
                            .labelsHidden()
                            .tint(LumeñoPastel.accent)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.3)
                
                // Spacing & Margins
                VStack(alignment: .leading, spacing: 20) {
                    SpacingSlider(title: "Line Spacing", value: $settings.lineSpacing, range: 1.2...2.5, step: 0.1)
                    SpacingSlider(title: "Character Spacing", value: $settings.letterSpacing, range: -0.05...0.15, step: 0.01)
                    SpacingSlider(title: "Word Spacing", value: $settings.wordSpacing, range: -0.1...0.3, step: 0.01)
                    
                    // Margins Stepper
                    StepperSlider(title: "Margins", value: $settings.horizontalPadding, range: 8...64, step: 4, unit: "px")
                }
            }
            .padding(24)
        }
        .frame(width: 320, height: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
}

struct StepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .background(Circle().fill(LumeñoPastel.primaryText.opacity(0.05)))
            .foregroundColor(LumeñoPastel.primaryText)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct StepperSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(LumeñoPastel.secondaryText)
                    .textCase(.uppercase)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(LumeñoPastel.accent)
            }
            
            HStack(spacing: 16) {
                Button {
                    HapticManager.shared.softTap()
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(StepperButtonStyle())
                
                Slider(value: $value, in: range, step: step)
                    .tint(LumeñoPastel.accent)
                
                Button {
                    HapticManager.shared.softTap()
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(StepperButtonStyle())
            }
        }
    }
}

struct SpacingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    private var formattedValue: String {
        if title.contains("Line") {
            return String(format: "%.1fx", value)
        } else if title.contains("Margins") {
            return "\(Int(value))px"
        } else {
            return String(format: "%+.2fem", value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(LumeñoPastel.secondaryText)
                    .textCase(.uppercase)
                Spacer()
                Text(formattedValue)
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(LumeñoPastel.accent)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(LumeñoPastel.accent)
        }
    }
}
