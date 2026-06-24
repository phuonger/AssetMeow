import SwiftUI

// ============================================================
// AssetMeow - Dark Purple Theme
// ============================================================

struct AppTheme {
    // MARK: - Primary Colors
    static let primaryPurple = Color(red: 0.55, green: 0.27, blue: 0.98)       // #8C45FA
    static let primaryPurpleLight = Color(red: 0.67, green: 0.42, blue: 1.0)    // #AB6BFF
    static let primaryPurpleDark = Color(red: 0.38, green: 0.15, blue: 0.75)    // #6126BF
    
    // MARK: - Accent Colors
    static let accentCyan = Color(red: 0.0, green: 0.85, blue: 0.95)            // #00D9F2
    static let accentPink = Color(red: 0.95, green: 0.30, blue: 0.65)           // #F24DA6
    static let accentGreen = Color(red: 0.20, green: 0.90, blue: 0.50)          // #33E680
    static let accentOrange = Color(red: 1.0, green: 0.60, blue: 0.20)          // #FF9933
    
    // MARK: - Background Colors
    static let backgroundDark = Color(red: 0.07, green: 0.06, blue: 0.13)       // #120F21
    static let backgroundMedium = Color(red: 0.10, green: 0.09, blue: 0.18)     // #1A172E
    static let backgroundLight = Color(red: 0.14, green: 0.12, blue: 0.24)      // #241F3D
    static let backgroundCard = Color(red: 0.16, green: 0.14, blue: 0.27)       // #292445
    
    // MARK: - Surface Colors
    static let surfaceDark = Color(red: 0.14, green: 0.12, blue: 0.24)          // #241F3D
    static let surfaceLight = Color(red: 0.22, green: 0.19, blue: 0.35)         // #383159
    static let surfaceDefault = Color(red: 0.18, green: 0.16, blue: 0.30)       // #2E294D
    static let surfaceHover = Color(red: 0.22, green: 0.19, blue: 0.35)         // #383159
    static let surfaceBorder = Color(red: 0.28, green: 0.24, blue: 0.42)        // #473D6B
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.70, green: 0.65, blue: 0.82)        // #B3A6D1
    static let textMuted = Color(red: 0.50, green: 0.45, blue: 0.65)            // #8073A6
    
    // MARK: - Status Colors
    static let statusAvailable = Color(red: 0.20, green: 0.90, blue: 0.50)      // Green
    static let statusCheckedOut = Color(red: 1.0, green: 0.60, blue: 0.20)      // Orange
    static let statusMissing = Color(red: 0.95, green: 0.30, blue: 0.35)        // Red
    static let statusDamaged = Color(red: 0.95, green: 0.30, blue: 0.65)        // Pink
    
    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [primaryPurple, primaryPurpleLight],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [backgroundDark, backgroundMedium],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let sidebarGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.08, blue: 0.20),
            Color(red: 0.07, green: 0.06, blue: 0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [backgroundCard, surfaceDefault],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glowGradient = LinearGradient(
        colors: [primaryPurple.opacity(0.6), accentCyan.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let buttonGradient = LinearGradient(
        colors: [primaryPurple, Color(red: 0.45, green: 0.20, blue: 0.90)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Fonts
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headingFont = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let subheadingFont = Font.system(size: 16, weight: .medium, design: .rounded)
    static let bodyFont = Font.system(size: 14, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 12, weight: .regular, design: .default)
    static let monoFont = Font.system(size: 13, weight: .medium, design: .monospaced)
    
    // MARK: - Dimensions
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 10
    static let sidebarWidth: CGFloat = 240
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12
}

// ============================================================
// Custom View Modifiers
// ============================================================

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(AppTheme.backgroundCard)
            .cornerRadius(AppTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.surfaceBorder.opacity(0.5), lineWidth: 1)
            )
    }
}

struct GlowCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardGradient)
            .cornerRadius(AppTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.primaryPurple.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: AppTheme.primaryPurple.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(AppTheme.buttonGradient)
            .cornerRadius(AppTheme.buttonCornerRadius)
            .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(AppTheme.primaryPurpleLight)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceDefault)
            .cornerRadius(AppTheme.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                    .stroke(AppTheme.primaryPurple.opacity(0.4), lineWidth: 1)
            )
    }
}

struct DarkTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(AppTheme.bodyFont)
            .foregroundColor(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundDark)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            )
    }
}

// ============================================================
// View Extensions
// ============================================================

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func glowCardStyle() -> some View {
        modifier(GlowCardStyle())
    }
    
    func primaryButton() -> some View {
        modifier(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        modifier(SecondaryButtonStyle())
    }
    
    func darkTextField() -> some View {
        modifier(DarkTextFieldStyle())
    }
}

// ============================================================
// Status Color Helper
// ============================================================

extension AppTheme {
    static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "available":
            return statusAvailable
        case "checked out":
            return statusCheckedOut
        case "missing":
            return statusMissing
        case "damaged":
            return statusDamaged
        default:
            return textSecondary
        }
    }
    
    static func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "available":
            return "checkmark.circle.fill"
        case "checked out":
            return "arrow.right.circle.fill"
        case "missing":
            return "exclamationmark.triangle.fill"
        case "damaged":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle"
        }
    }
}
