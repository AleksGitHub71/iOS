import Foundation

extension InterfaceStyle {

    var labelStyleFactory: LabelStyleFactory {
        LabelStyleFactoryImpl(
            colorFactory: colorFactory,
            textStyleFactory: textStyleFactory,
            paragraphStyleFactory: paragraphStyleFactory,
            cornerStyleFactory: cornerStyleFactory
        )
    }
}

typealias LabelStyler = (UILabel) -> Void

enum MEGALabelStyle {

    case headline

    // MARK: - Paragraph

    case multiline

    case note1
    case note2

    // MARK: - Notification Badge

    case badge
}

// MARK: - Themed Label Style Factory

protocol LabelStyleFactory {

    func styler(of style: MEGALabelStyle) -> LabelStyler
}

private struct LabelStyleFactoryImpl: LabelStyleFactory {

    let colorFactory: ColorFactory
    let textStyleFactory: TextStyleFactory
    let paragraphStyleFactory: ParagraphStyleFactory
    let cornerStyleFactory: CornerStyleFactory

    func styler(of style: MEGALabelStyle) -> LabelStyler {
        switch style {
        case .headline: return headlineStyler()
        case .note1: return mainNoteStyler()
        case .note2: return subNoteStyler()
        case .multiline: return multilineStyler()
        case .badge: return badgeStyler()
        }
    }

    private func multilineStyler() -> LabelStyler {
        let paragraphStyleFactory = self.paragraphStyleFactory
        return { label in
            paragraphStyleFactory.paragraphStyle(of: .naturalAlignedWordWrapping).applied(on: label)
        }
    }

    private func headlineStyler() -> LabelStyler {
        let textColorStyler = colorFactory.textColor(.primary).asTextColorStyle
        let headlineTextStyler = textStyleFactory.textStyle(of: .headline)
        return { label in
            headlineTextStyler
                .applied(on: textColorStyler
                    .applied(on: label))
        }
    }

    private func mainNoteStyler() -> LabelStyler {
        let textColorStyler = colorFactory.textColor(.primary).asTextColorStyle
        let mainNoteTextStyler = textStyleFactory.textStyle(of: .caption1)
        let paragraphStyleFactory = self.paragraphStyleFactory
        return { label in
            paragraphStyleFactory.paragraphStyle(of: .naturalAlignedWordWrapping)
                .applied(on: mainNoteTextStyler
                    .applied(on: textColorStyler
                        .applied(on: label)))
        }
    }

    private func subNoteStyler() -> LabelStyler {
        let textColorStyler = colorFactory.textColor(.primary).asTextColorStyle
        let subNoteTextStyler = textStyleFactory.textStyle(of: .caption2)
        let paragraphStyleFactory = self.paragraphStyleFactory
        return { label in
            paragraphStyleFactory.paragraphStyle(of: .naturalAlignedWordWrapping)
                .applied(on: subNoteTextStyler
                    .applied(on: textColorStyler
                        .applied(on: label)))
        }
    }

    private func badgeStyler() -> LabelStyler {
        let textColorStyler = colorFactory.independent(.bright).asTextColorStyle
        let backgroundColorStyler = colorFactory.independent(.warning).asBackgroundColorStyle
        let captionTextStyler = textStyleFactory.textStyle(of: .caption1)
        let cornerStyler = cornerStyleFactory.cornerStyle(of: .ten)
        let paragraphStyler = paragraphStyleFactory.paragraphStyle(of: .centered)
        return { label in
            captionTextStyler
                .applied(on: textColorStyler
                    .applied(on: backgroundColorStyler
                        .applied(on: cornerStyler
                            .applied(on: paragraphStyler
                                .applied(on: label)))))
        }
    }
}

// MARK: - Theme Independent Label Style Factory

extension InterfaceStyle {

    var alwyasBrightLabelStyleFactory: LabelStyleFactory {
        AlwaysBrightLabelStyleFactoryImpl(
            colorFactory: colorFactory,
            textStyleFactory: textStyleFactory
        )
    }
}

private struct AlwaysBrightLabelStyleFactoryImpl: LabelStyleFactory {

    let colorFactory: ColorFactory
    let textStyleFactory: TextStyleFactory

    func styler(of style: MEGALabelStyle) -> LabelStyler {
        switch style {
        case .headline: return headlineStyler()
        default: fatalError("Styles other than headline are not defined for always bright")
        }
    }

    private func headlineStyler() -> LabelStyler {
        let textColorStyler = colorFactory.independent(.bright).asTextColorStyle
        let headlineTextStyler = textStyleFactory.textStyle(of: .headline)
        return { label in
            headlineTextStyler
                .applied(on: textColorStyler
                    .applied(on: label))
        }
    }
}
