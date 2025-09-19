//
//  ThemeManager.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import UIKit

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "#1E90FF") // Dodger Blue
        static let secondary = Color(hex: "#FFFFFF") // White
        static let background = Color(hex: "#F8F9FA") // Light Gray
        static let surface = Color(hex: "#FFFFFF") // White
        static let textPrimary = Color(hex: "#212529") // Dark Gray
        static let textSecondary = Color(hex: "#6C757D") // Medium Gray
        static let accent = Color(hex: "#1E90FF") // Dodger Blue
        static let success = Color(hex: "#28A745") // Green
        static let warning = Color(hex: "#FFC107") // Yellow
        static let error = Color(hex: "#DC3545") // Red
        static let border = Color(hex: "#DEE2E6") // Light Border
        static let shadow = Color(hex: "#000000").opacity(0.1) // Subtle Shadow
    }
    
    // MARK: - Typography
    struct Typography {
        // Headers
        static let largeTitle = Font.custom("SF Pro Display", size: 34).weight(.bold)
        static let title1 = Font.custom("SF Pro Display", size: 28).weight(.bold)
        static let title2 = Font.custom("SF Pro Display", size: 22).weight(.bold)
        static let title3 = Font.custom("SF Pro Display", size: 20).weight(.semibold)
        
        // Body Text
        static let headline = Font.custom("SF Pro Text", size: 17).weight(.semibold)
        static let body = Font.custom("SF Pro Text", size: 17).weight(.regular)
        static let callout = Font.custom("SF Pro Text", size: 16).weight(.regular)
        static let subheadline = Font.custom("SF Pro Text", size: 15).weight(.regular)
        static let footnote = Font.custom("SF Pro Text", size: 13).weight(.regular)
        static let caption = Font.custom("SF Pro Text", size: 12).weight(.regular)
        
        // Dynamic Type Support
        static func dynamicLargeTitle() -> Font {
            return Font.custom("SF Pro Display", size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize).weight(.bold)
        }
        
        static func dynamicTitle1() -> Font {
            return Font.custom("SF Pro Display", size: UIFont.preferredFont(forTextStyle: .title1).pointSize).weight(.bold)
        }
        
        static func dynamicTitle2() -> Font {
            return Font.custom("SF Pro Display", size: UIFont.preferredFont(forTextStyle: .title2).pointSize).weight(.bold)
        }
        
        static func dynamicTitle3() -> Font {
            return Font.custom("SF Pro Display", size: UIFont.preferredFont(forTextStyle: .title3).pointSize).weight(.semibold)
        }
        
        static func dynamicHeadline() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .headline).pointSize).weight(.semibold)
        }
        
        static func dynamicBody() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .body).pointSize).weight(.regular)
        }
        
        static func dynamicCallout() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .callout).pointSize).weight(.regular)
        }
        
        static func dynamicSubheadline() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .subheadline).pointSize).weight(.regular)
        }
        
        static func dynamicFootnote() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .footnote).pointSize).weight(.regular)
        }
        
        static func dynamicCaption() -> Font {
            return Font.custom("SF Pro Text", size: UIFont.preferredFont(forTextStyle: .caption1).pointSize).weight(.regular)
        }
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let sm = Shadow(color: Colors.shadow, radius: 2, x: 0, y: 1)
        static let md = Shadow(color: Colors.shadow, radius: 4, x: 0, y: 2)
        static let lg = Shadow(color: Colors.shadow, radius: 8, x: 0, y: 4)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    private init() {}
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
extension View {
    func themedCard() -> some View {
        self
            .background(ThemeManager.Colors.surface)
            .cornerRadius(ThemeManager.CornerRadius.lg)
            .shadow(
                color: ThemeManager.Shadows.md.color,
                radius: ThemeManager.Shadows.md.radius,
                x: ThemeManager.Shadows.md.x,
                y: ThemeManager.Shadows.md.y
            )
    }
    
    func themedButton(style: ButtonStyle = .primary) -> some View {
        self
            .font(ThemeManager.Typography.dynamicHeadline())
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, ThemeManager.Spacing.lg)
            .padding(.vertical, ThemeManager.Spacing.md)
            .background(style.backgroundColor)
            .cornerRadius(ThemeManager.CornerRadius.md)
            .shadow(
                color: ThemeManager.Shadows.sm.color,
                radius: ThemeManager.Shadows.sm.radius,
                x: ThemeManager.Shadows.sm.x,
                y: ThemeManager.Shadows.sm.y
            )
    }
    
}

enum ButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return ThemeManager.Colors.primary
        case .secondary:
            return ThemeManager.Colors.background
        case .outline:
            return Color.clear
        case .ghost:
            return Color.clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary:
            return ThemeManager.Colors.secondary
        case .secondary:
            return ThemeManager.Colors.textPrimary
        case .outline:
            return ThemeManager.Colors.primary
        case .ghost:
            return ThemeManager.Colors.primary
        }
    }
}
