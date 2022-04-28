import Foundation
import Combine

@available(iOS 14.0, *)
@MainActor
final class PhotoYearCardViewModel: PhotoCardViewModel {
    private let photoByYear: PhotoByYear
    
    let title: String
    
    init(photoByYear: PhotoByYear,
         thumbnailUseCase: ThumbnailUseCaseProtocol) {
        self.photoByYear = photoByYear
        
        if #available(iOS 15.0, *) {
            title = photoByYear.categoryDate.formatted(.dateTime.year().locale(.current))
        } else {
            title = DateFormatter.yearTemplate().localisedString(from: photoByYear.categoryDate)
        }
        
        super.init(coverPhoto: photoByYear.coverPhoto, thumbnailUseCase: thumbnailUseCase)
    }
}
