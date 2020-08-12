import UIKit

/// A protocol that traces application's trait enviroment updating.
protocol TraitEnviromentAware {

    /// Handles TraitCollection updating.
    /// If the update is a `UIInterfaceStyle` updates, then `colorAppearanceDidChang(to:from:)` will be called.
    /// If the update is a `UIContentSizeCategory` updates, then `contentSizeCategoryDidChange(to:)` will be called.
    /// - Parameters:
    ///   - to: The new value of applications's `UITraitCollection`.
    ///   - from: The previous value of applications's `UITraitCollection`.
    func traitCollectionChanged(to: UITraitCollection, from: UITraitCollection?)

    /// Will handle `UITraitCollection` updates.
    /// - Parameters:
    ///   - to: The new value of applications's `UITraitCollection`.
    ///   - from: The previous value of applications's `UITraitCollection`.
    func colorAppearanceDidChang(to currentTrait: UITraitCollection, from previousTrait: UITraitCollection?)
    
    /// Will handle application's `UIContentSizeCategory` updates.
    /// - Parameter contentSizeCategory: New `UIContentSizeCategory` value for the system.
    func contentSizeCategoryDidChange(to contentSizeCategory: UIContentSizeCategory)
}

extension TraitEnviromentAware {

    func traitCollectionChanged(
        to currentTrait: UITraitCollection,
        from previousTrait: UITraitCollection?
    ) {
        if #available(iOS 13, *), currentTrait.hasDifferentColorAppearance(comparedTo: previousTrait) {
            colorAppearanceDidChang(to: currentTrait, from: previousTrait)
        }

        contentSizeCategoryDidChange(to: currentTrait.preferredContentSizeCategory)
    }

    func contentSizeCategoryDidChange(to contentSizeCategory: UIContentSizeCategory) {}
}
