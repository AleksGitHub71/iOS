import MEGADomain
import MEGASDKRepo
import MEGASwiftUI
import SwiftUI

extension ThumbnailUseCaseProtocol {
    func cachedThumbnailContainer(for node: NodeEntity, type: ThumbnailTypeEntity) -> (some ImageContaining)? {
        guard let thumbnail = cachedThumbnail(for: node, type: type) else { return Optional<URLImageContainer>.none }
        return URLImageContainer(imageURL: thumbnail.url, type: type.toImageType())
    }

    func loadThumbnailContainer(for node: NodeEntity, type: ThumbnailTypeEntity) async throws -> some ImageContaining {
        try Task.checkCancellation()
        let thumbnail = try await loadThumbnail(for: node, type: type)
        guard let container = URLImageContainer(imageURL: thumbnail.url, type: type.toImageType()) else {
            throw(ThumbnailErrorEntity.noThumbnail(type))
        }
        return container
    }
}

extension ThumbnailUseCase where T == ThumbnailRepository {
    static func makeThumbnailUseCase(mode: PhotoLibraryContentMode) -> Self {
        let sdk = mode == .mediaDiscoveryFolderLink ? MEGASdk.sharedFolderLink : MEGASdk.shared
        
        let provider: any MEGANodeProviderProtocol = mode == .albumLink ? PublicAlbumNodeProvider.shared : DefaultMEGANodeProvider(sdk: sdk)
        
        return ThumbnailUseCase(repository: ThumbnailRepository(sdk: sdk, fileManager: .default, nodeProvider: provider))
    }
}
