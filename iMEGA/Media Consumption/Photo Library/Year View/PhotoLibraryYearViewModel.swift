import Foundation

@available(iOS 14.0, *)
@MainActor
final class PhotoLibraryYearViewModel: PhotoLibraryModeCardViewModel<PhotoByYear> {
    init(libraryViewModel: PhotoLibraryContentViewModel) {
        super.init(libraryViewModel: libraryViewModel) {
            $0.removeMonth()
        } categoryListTransformation: {
            $0.allphotoByYearList
        }
    }
    
    override func didTapCategory(_ category: PhotoByYear) {
        super.didTapCategory(category)
        libraryViewModel.selectedMode = .month
    }
}
