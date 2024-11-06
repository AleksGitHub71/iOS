import ContentLibraries
import MEGADomain
import MEGADomainMock
@testable import MEGAPhotos
import MEGAPresentation
import MEGAPresentationMock
import SwiftUI
import Testing

struct AlbumSearchResultViewModelTests {
    @Suite("Values set init")
    struct Constructor {
        @Test("Correct values are set in constructor")
        @MainActor
        func constructor() {
            let albumsCellViewModels = [
                AlbumCellViewModel(album: AlbumEntity(id: 1, name: "Album 1", coverNode: .init(handle: 1), type: .user))
            ]
            
            let searchText = Binding.constant("album")
            let sut = AlbumSearchResultViewModelTests
                .makeSUT(albums: albumsCellViewModels,
                         searchText: searchText)
            
            #expect(sut.albums == albumsCellViewModels)
        }
    }
    
    @MainActor
    private static func makeSUT(
        albums: [AlbumCellViewModel] = [],
        searchText: Binding<String> = .constant("")
    ) -> AlbumSearchResultViewModel {
        .init(albums: albums,
              searchText: searchText)
    }
}

private extension AlbumCellViewModel {
    convenience init(album: AlbumEntity) {
        self.init(
            thumbnailLoader: MockThumbnailLoader(initialImage: ImageContainer(image: Image(systemName: "square"), type: .thumbnail)),
            monitorUserAlbumPhotosUseCase: MockMonitorUserAlbumPhotosUseCase(),
            nodeUseCase: MockNodeDataUseCase(),
            sensitiveNodeUseCase: MockSensitiveNodeUseCase(),
            sensitiveDisplayPreferenceUseCase: MockSensitiveDisplayPreferenceUseCase(),
            albumCoverUseCase: MockAlbumCoverUseCase(),
            album: album,
            selection: AlbumSelection(),
            tracker: MockTracker(),
            selectedAlbum: .constant(nil),
            remoteFeatureFlagUseCase: MockRemoteFeatureFlagUseCase(),
            configuration: .init(sensitiveNodeUseCase: MockSensitiveNodeUseCase(),
                                 nodeUseCase: MockNodeUseCase(),
                                 isAlbumPerformanceImprovementsEnabled: { false })
        )
    }
}
