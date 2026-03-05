import SwiftUI

// MARK: - Theme Token System

enum CopyraTheme {
  // MARK: - Colors

  enum Colors {
    // Surfaces — layered depth on dark vibrancy backdrop
    static let surfaceOverlay = Color.white.opacity(0.04)
    static let surfaceElevated = Color.white.opacity(0.07)
    static let surfaceCard = Color.white.opacity(0.05)

    // Text
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let textMuted = Color.white.opacity(0.35)

    // Accent — cool blue with depth
    static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let accentSubtle = Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.25)

    // Selection / State
    static let selected = Color(red: 0.30, green: 0.50, blue: 0.95).opacity(0.75)
    static let selectedText = Color.white.opacity(0.97)
    static let hover = Color.white.opacity(0.06)
    static let active = Color.white.opacity(0.10)
    static let focus = Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.50)

    // Border / Divider
    static let border = Color.white.opacity(0.10)
    static let borderSubtle = Color.white.opacity(0.05)
    static let divider = Color.white.opacity(0.08)

    // Semantic
    static let pinned = Color(red: 1.0, green: 0.78, blue: 0.28).opacity(0.85)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.30)

    // Badges / Indicators
    static let badge = Color.white.opacity(0.15)
    static let badgeText = Color.white.opacity(0.85)

    // Placeholder / empty state
    static let placeholder = Color.white.opacity(0.08)
  }

  // MARK: - Spacing

  enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
  }

  // MARK: - Radius

  enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 12
  }

  // MARK: - Typography

  enum Typography {
    static let caption = Font.system(size: 10, weight: .regular)
    static let captionMedium = Font.system(size: 10, weight: .medium)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let title = Font.system(size: 14, weight: .semibold)
    static let shortcut = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let metadata = Font.system(size: 11, weight: .regular)
  }

  // MARK: - Animation

  enum Motion {
    static let quick = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.2)
    static let gentle = Animation.easeInOut(duration: 0.3)
  }
}

// MARK: - Reusable View Modifiers

struct ThemedCardModifier: ViewModifier {
  var isSelected: Bool = false
  var cornerRadius: CGFloat = CopyraTheme.Radius.md

  func body(content: Content) -> some View {
    content
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(isSelected ? CopyraTheme.Colors.selected : CopyraTheme.Colors.surfaceCard)
      )
  }
}

struct ThemedDivider: View {
  var body: some View {
    Rectangle()
      .fill(CopyraTheme.Colors.divider)
      .frame(height: 1)
  }
}

extension View {
  func themedCard(isSelected: Bool = false, cornerRadius: CGFloat = CopyraTheme.Radius.md) -> some View {
    modifier(ThemedCardModifier(isSelected: isSelected, cornerRadius: cornerRadius))
  }
}
