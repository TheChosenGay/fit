import SwiftUI

// MARK: - Design System Text Styles

@available(iOS 15.0, *)
enum DSTextStyle: CaseIterable {
    case largeTitle, title1, title2, title3
    case headline, body, callout, subheadline
    case footnote, caption1, caption2

    var font: Font {
        switch self {
        case .largeTitle:  return .system(size: 34, weight: .bold)
        case .title1:      return .system(size: 28, weight: .bold)
        case .title2:      return .system(size: 22, weight: .bold)
        case .title3:      return .system(size: 20, weight: .semibold)
        case .headline:    return .system(size: 17, weight: .semibold)
        case .body:        return .system(size: 17, weight: .regular)
        case .callout:     return .system(size: 16, weight: .regular)
        case .subheadline: return .system(size: 15, weight: .regular)
        case .footnote:    return .system(size: 13, weight: .regular)
        case .caption1:    return .system(size: 12, weight: .regular)
        case .caption2:    return .system(size: 11, weight: .regular)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .largeTitle:  return 7
        case .title1:      return 6
        case .title2:      return 6
        case .title3:      return 5
        case .headline:    return 5
        case .body:        return 5
        case .callout:     return 5
        case .subheadline: return 5
        case .footnote:    return 5
        case .caption1:    return 4
        case .caption2:    return 2
        }
    }

    var name: String {
        switch self {
        case .largeTitle:  return "Large Title"
        case .title1:      return "Title 1"
        case .title2:      return "Title 2"
        case .title3:      return "Title 3"
        case .headline:    return "Headline"
        case .body:        return "Body"
        case .callout:     return "Callout"
        case .subheadline: return "Subheadline"
        case .footnote:    return "Footnote"
        case .caption1:    return "Caption 1"
        case .caption2:    return "Caption 2"
        }
    }
}

// MARK: - View Extension

@available(iOS 15.0, *)
extension View {
    func dsTextStyle(_ style: DSTextStyle) -> some View {
        self.font(style.font)
            .lineSpacing(style.lineSpacing)
    }
}
