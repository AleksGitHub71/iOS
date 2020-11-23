import Foundation

extension InterfaceStyle {

    var buttonStyle: ButtonStyleFactory {
        return ButtonStyleFactoryImpl(colorFactory: colorFactory)
    }
}

enum MEGAButtonStyle {
    case segmentTitleButton
    case searchControllerCancel
}

protocol ButtonStyleFactory {

    func styler(of buttonStyle: MEGAButtonStyle) -> ButtonStyler
}

private struct ButtonStyleFactoryImpl: ButtonStyleFactory {

    let colorFactory: ColorFactory

    func styler(of buttonStyle: MEGAButtonStyle) -> ButtonStyler {

        switch buttonStyle {
        case .segmentTitleButton:
            return { button in
                self.buttonTextStyle(of: buttonStyle)
                    .applied(on: self.buttonBackgroundStyle(of: buttonStyle)
                        .applied(on: self.buttonColorStyle(of: buttonStyle)
                            .applied(on: button)))
            }

        case .searchControllerCancel:
            return { button in
                self.buttonTextStyle(of: buttonStyle)
                    .applied(on: self.buttonBackgroundStyle(of: buttonStyle)
                        .applied(on: self.buttonColorStyle(of: buttonStyle)
                            .applied(on: button)))
            }
        }
    }

    func buttonColorStyle(of buttonStyle: MEGAButtonStyle) -> ButtonStatedStyle<ColorStyle> {
        switch buttonStyle {
        case .segmentTitleButton:
            let normalTextColor = colorFactory.textColor(.primary).altering(alpha: 82).asTextColorStyle
            let selectedTextColor = colorFactory.textColor(.primary).asTextColorStyle
            return ButtonStatedStyle<ColorStyle>(stated: [
                .normal: normalTextColor,
                .selected: selectedTextColor,
                .highlighted: selectedTextColor,
            ])
        case .searchControllerCancel:
            let normalTextColor = colorFactory.textColor(.tertiary).asTextColorStyle
            return ButtonStatedStyle<ColorStyle>(stated: [
                .normal: normalTextColor,
            ])
        }
    }

    func buttonTextStyle(of buttonStyle: MEGAButtonStyle) -> ButtonStatedStyle<TextStyle> {
        switch buttonStyle {
        case .segmentTitleButton:
            return ButtonStatedStyle<TextStyle>(stated: [
                .normal: TextStyle(font: .titleSmall),
                .highlighted: TextStyle(font: .title),
                .selected: TextStyle(font: .title),
            ])
        case .searchControllerCancel:
            return ButtonStatedStyle<TextStyle>(stated: [
                .normal: TextStyle(font: .body),
                .selected: TextStyle(font: .body),
            ])
        }
    }

    func buttonBackgroundStyle(of buttonStyle: MEGAButtonStyle) -> ButtonStatedStyle<ColorStyle> {
        switch buttonStyle {
        case .segmentTitleButton:
            let clearColor = colorFactory.independent(.clear).asBackgroundColorStyle
            return ButtonStatedStyle<ColorStyle>(stated: [
                .normal: clearColor,
                .selected: clearColor,
                .highlighted: clearColor,
            ])
        case .searchControllerCancel:
            let clearColor = colorFactory.independent(.clear).asBackgroundColorStyle
            return ButtonStatedStyle<ColorStyle>(stated: [
                .normal: clearColor,
                .selected: clearColor,
                .highlighted: clearColor,
            ])
        }
    }
}
