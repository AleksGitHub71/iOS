import Foundation

@available(iOS 14.0, *)
@MainActor
final class PhotoLibraryMonthViewModel: PhotoLibraryModeCardViewModel<PhotoByMonth> {
    init(libraryViewModel: PhotoLibraryContentViewModel) {
        super.init(libraryViewModel: libraryViewModel) {
            $0.removeDay()
        } categoryListTransformation: {
            $0.allPhotosByMonthList
        }
    }
    
    override func didTapCategory(_ category: PhotoByMonth) {
        super.didTapCategory(category)
        libraryViewModel.selectedMode = .day
    }
}
