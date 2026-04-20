import SwiftUI

// MARK: - Color tokens

extension Color {
    static let somiaBackground   = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let somiaAccent       = Color(red: 0.294, green: 0.871, blue: 0.502)
    static let somiaBodyText     = Color(red: 0.541, green: 0.541, blue: 0.557)
    static let somiaCard         = Color(red: 0.11,  green: 0.11,  blue: 0.12)
    static let somiaCardBorder   = Color(red: 0.20,  green: 0.20,  blue: 0.22)
    static let somiaWarn         = Color(red: 1.0,   green: 0.51,  blue: 0.31)
    static let somiaGreenStrong  = Color(red: 0.290, green: 0.871, blue: 0.502)
    static let somiaGreenSoft    = Color(red: 0.525, green: 0.937, blue: 0.675)
    static let somiaDrift        = Color(red: 0.910, green: 0.467, blue: 0.290)
}

// MARK: - Typography tokens

extension Font {
    static let somiaLargeTitle = Font.system(size: 34, weight: .bold,     design: .rounded)
    static let somiaTitle      = Font.system(size: 22, weight: .bold,     design: .rounded)
    static let somiaHeadline   = Font.system(size: 17, weight: .semibold, design: .default)
    static let somiaBody       = Font.system(size: 15, weight: .regular,  design: .default)
    static let somiaCaption    = Font.system(size: 11, weight: .medium,   design: .default)
}

// MARK: - Spacing tokens

enum SomiaSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Corner radius tokens

enum SomiaRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let pill: CGFloat = 100
}
