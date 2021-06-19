import Foundation

extension InterfaceStyle {

    var textStyleFactory: TextStyleFactory {
        TextStyleFactoryImpl()
    }
}

enum MEGATextStyle: Hashable {
    case headline //Semi-bold by default
    case headlineBold
    
    case subheadline //Regular by default
    case subheadlineMedium
    case subheadlineBold
    
    case footnoteBold
    case footnoteSemibold
    
    case caption //Regular by default
    case captionSemibold
    
    case caption2 //Regular by default
    
    case body //Regular by default
    case bodySemibold
}

protocol TextStyleFactory {

    func textStyle(of textStyle: MEGATextStyle) -> TextStyle
}

private struct TextStyleFactoryImpl: TextStyleFactory {

    func textStyle(of textStyle: MEGATextStyle) -> TextStyle {
        switch textStyle {
        case .headline: return TextStyle(font: Font(style: .headline))
        case .headlineBold: return TextStyle(font: Font(style: .headline, weight: .bold))
            
        case .subheadline: return TextStyle(font: Font(style: .subheadline))
        case .subheadlineBold: return TextStyle(font: Font(style: .subheadline, weight: .bold))
        case .subheadlineMedium: return TextStyle(font: Font(style: .headline, weight: .medium))
            
        case .footnoteBold: return TextStyle(font: Font(style: .footnote, weight: .bold))
        case .footnoteSemibold: return TextStyle(font: Font(style: .footnote, weight: .semibold))
            
        case .caption: return TextStyle(font: Font(style: .caption1))
        case .captionSemibold: return TextStyle(font: Font(style: .caption1, weight: .semibold))
            
        case .caption2: return TextStyle(font: Font(style: .caption2))
            
        case .body: return TextStyle(font: Font(style: .body))
        case .bodySemibold: return TextStyle(font: Font(style: .body, weight: .semibold))
        }
    }
}
