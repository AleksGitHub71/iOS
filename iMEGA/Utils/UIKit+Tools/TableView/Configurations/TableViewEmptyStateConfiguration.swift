import Foundation

struct EmptyStateConfiguration {

    let emptyStateView: () -> UIView
}

extension EmptyStateConfiguration {

    static var searchHints: Self {
        Self.init {
            EmptyStateView(
                image: UIImage(named: "searchEmptyState")!,
                title: NSLocalizedString("noResults", comment: ""),
                description: nil,
                buttonTitle: nil
            )
        }
    }

    static var searchResult: Self {
        Self.init {
            EmptyStateView(
                image: UIImage(named: "searchEmptyState")!,
                title: NSLocalizedString("noResults", comment: ""),
                description: nil,
                buttonTitle: nil
            )
        }
    }
}
