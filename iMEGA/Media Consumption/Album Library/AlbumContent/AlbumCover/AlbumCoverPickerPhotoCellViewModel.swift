import Combine
import MEGADomain
import MEGAPresentation
import SwiftUI

final class AlbumCoverPickerPhotoCellViewModel: PhotoCellViewModel {
    
    let photoSelection: AlbumCoverPickerPhotoSelection
    
    private let albumPhoto: AlbumPhotoEntity
    
    init(albumPhoto: AlbumPhotoEntity,
         photoSelection: AlbumCoverPickerPhotoSelection,
         viewModel: PhotoLibraryModeAllViewModel,
         thumbnailLoader: some ThumbnailLoaderProtocol) {
        self.albumPhoto = albumPhoto
        self.photoSelection = photoSelection
        
        super.init(photo: albumPhoto.photo,
                   viewModel: viewModel,
                   thumbnailLoader: thumbnailLoader)
        
        setupSubscription()
    }
    
    func onPhotoSelect() {
        photoSelection.selectedPhoto = albumPhoto
    }
    
    func setupSubscription() {
        photoSelection.$selectedPhoto
            .map { [weak self] in $0 == self?.albumPhoto }
            .assign(to: &$isSelected)
    }
}
