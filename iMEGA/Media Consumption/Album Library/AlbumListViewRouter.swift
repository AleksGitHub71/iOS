import Combine
import ContentLibraries
import MEGADomain
import MEGAL10n
import MEGAPresentation
import MEGASDKRepo
import MEGASwiftUI
import SwiftUI

@MainActor
protocol AlbumListViewRouting {
    func cell(album: AlbumEntity, selectedAlbum: Binding<AlbumEntity?>, selection: AlbumSelection) -> AlbumCell
    func albumContainer(album: AlbumEntity, newAlbumPhotosToAdd: [NodeEntity]?, existingAlbumNames: @escaping () -> [String]) -> AlbumContainerWrapper
}

struct AlbumListViewRouter: AlbumListViewRouting, Routing {
    weak var photoAlbumContainerViewModel: PhotoAlbumContainerViewModel?
    
    func cell(album: AlbumEntity, selectedAlbum: Binding<AlbumEntity?>, selection: AlbumSelection) -> AlbumCell {
        let nodeRepository = NodeRepository.newRepo
        let accountUseCase = AccountUseCase(
            repository: AccountRepository.newRepo)
        let vm = AlbumCellViewModel(
            thumbnailLoader: ThumbnailLoaderFactory.makeThumbnailLoader(),
            monitorUserAlbumPhotosUseCase: makeMonitorUserAlbumPhotosUseCase(),
            nodeUseCase: NodeUseCase(
                nodeDataRepository: NodeDataRepository.newRepo,
                nodeValidationRepository: NodeValidationRepository.newRepo,
                nodeRepository: NodeRepository.newRepo),
            sensitiveNodeUseCase: SensitiveNodeUseCase(
                nodeRepository: nodeRepository,
                accountUseCase: accountUseCase),
            sensitiveDisplayPreferenceUseCase: SensitiveDisplayPreferenceUseCase(
                sensitiveNodeUseCase: SensitiveNodeUseCase(
                    nodeRepository: NodeRepository.newRepo,
                    accountUseCase: accountUseCase),
                contentConsumptionUserAttributeUseCase: ContentConsumptionUserAttributeUseCase(
                    repo: UserAttributeRepository.newRepo),
                hiddenNodesFeatureFlagEnabled: { DIContainer.remoteFeatureFlagUseCase.isFeatureFlagEnabled(for: .hiddenNodes) }),
            albumCoverUseCase: AlbumCoverUseCase(nodeRepository: nodeRepository),
            album: album,
            selection: selection,
            selectedAlbum: selectedAlbum
        )
        return AlbumCell(viewModel: vm)
    }
    
    func albumContainer(album: AlbumEntity, newAlbumPhotosToAdd: [NodeEntity]?, existingAlbumNames: @escaping () -> [String]) -> AlbumContainerWrapper {
        return AlbumContainerWrapper(album: album, newAlbumPhotos: newAlbumPhotosToAdd, existingAlbumNames: existingAlbumNames)
    }
    
    func build() -> UIViewController {
        let filesSearchRepo = FilesSearchRepository.newRepo
        let albumContentsUpdatesRepo = AlbumContentsUpdateNotifierRepository.newRepo
        let mediaUseCase = MediaUseCase(fileSearchRepo: filesSearchRepo)
        let userAlbumRepo = UserAlbumRepository.newRepo
        let photoLibraryUseCase = makePhotoLibraryUseCase()
        let sensitiveDisplayPreferenceUseCase = makeSensitiveDisplayPreferenceUseCase()
        
        let vm = AlbumListViewModel(
            usecase: AlbumListUseCase(
                photoLibraryUseCase: photoLibraryUseCase,
                mediaUseCase: mediaUseCase,
                userAlbumRepository: userAlbumRepo,
                albumContentsUpdateRepository: albumContentsUpdatesRepo,
                albumContentsUseCase: AlbumContentsUseCase(
                    albumContentsRepo: albumContentsUpdatesRepo,
                    mediaUseCase: mediaUseCase,
                    fileSearchRepo: filesSearchRepo,
                    userAlbumRepo: userAlbumRepo,
                    sensitiveDisplayPreferenceUseCase: sensitiveDisplayPreferenceUseCase,
                    photoLibraryUseCase: photoLibraryUseCase,
                    sensitiveNodeUseCase: SensitiveNodeUseCase(
                        nodeRepository: NodeRepository.newRepo,
                        accountUseCase: AccountUseCase(
                            repository: AccountRepository.newRepo))),
                sensitiveDisplayPreferenceUseCase: sensitiveDisplayPreferenceUseCase
            ),
            albumModificationUseCase: AlbumModificationUseCase(userAlbumRepo: userAlbumRepo),
            shareCollectionUseCase: ShareCollectionUseCase(
                shareAlbumRepository: ShareCollectionRepository.newRepo,
                userAlbumRepository: UserAlbumRepository.newRepo,
                nodeRepository: NodeRepository.newRepo
            ),
            tracker: DIContainer.tracker,
            monitorAlbumsUseCase: makeMonitorAlbumsUseCase(),
            sensitiveDisplayPreferenceUseCase: SensitiveDisplayPreferenceUseCase(
                sensitiveNodeUseCase: SensitiveNodeUseCase(
                    nodeRepository: NodeRepository.newRepo,
                    accountUseCase: AccountUseCase(repository: AccountRepository.newRepo)),
                contentConsumptionUserAttributeUseCase: ContentConsumptionUserAttributeUseCase(
                    repo: UserAttributeRepository.newRepo),
                hiddenNodesFeatureFlagEnabled: { DIContainer.remoteFeatureFlagUseCase.isFeatureFlagEnabled(for: .hiddenNodes) }),
            alertViewModel: TextFieldAlertViewModel(title: Strings.Localizable.CameraUploads.Albums.Create.Alert.title,
                                                    placeholderText: Strings.Localizable.CameraUploads.Albums.Create.Alert.placeholder,
                                                    affirmativeButtonTitle: Strings.Localizable.createFolderButton,
                                                    destructiveButtonTitle: Strings.Localizable.cancel,
                                                    message: nil),
            photoAlbumContainerViewModel: photoAlbumContainerViewModel
        )
        
        let content = AlbumListView(viewModel: vm,
                                    router: self)
        
        return UIHostingController(rootView: content)
    }
    
    func start() {}
    
    private func makeMonitorAlbumsUseCase() -> MonitorAlbumsUseCase {
        let sensitiveNodeUseCase = SensitiveNodeUseCase(
            nodeRepository: NodeRepository.newRepo,
            accountUseCase: AccountUseCase(
                repository: AccountRepository.newRepo))
        return MonitorAlbumsUseCase(
            monitorPhotosUseCase: MonitorPhotosUseCase(
                photosRepository: PhotosRepository.sharedRepo,
                photoLibraryUseCase: makePhotoLibraryUseCase(),
                sensitiveNodeUseCase: sensitiveNodeUseCase),
            mediaUseCase: MediaUseCase(fileSearchRepo: FilesSearchRepository.newRepo),
            userAlbumRepository: UserAlbumCacheRepository.newRepo,
            photosRepository: PhotosRepository.sharedRepo,
            sensitiveNodeUseCase: sensitiveNodeUseCase)
    }
    
    private func makeMonitorUserAlbumPhotosUseCase() -> some MonitorUserAlbumPhotosUseCaseProtocol {
        MonitorUserAlbumPhotosUseCase(
            userAlbumRepository: UserAlbumCacheRepository.newRepo,
            photosRepository: PhotosRepository.sharedRepo,
            sensitiveNodeUseCase: SensitiveNodeUseCase(
                nodeRepository: NodeRepository.newRepo,
                accountUseCase: AccountUseCase(
                    repository: AccountRepository.newRepo))
        )
    }
    
    private func makePhotoLibraryUseCase() -> some PhotoLibraryUseCaseProtocol {
        let photoLibraryRepository = PhotoLibraryRepository(
            cameraUploadNodeAccess: CameraUploadNodeAccess.shared)
        return PhotoLibraryUseCase(photosRepository: photoLibraryRepository,
                                   searchRepository: FilesSearchRepository.newRepo,
                                   sensitiveDisplayPreferenceUseCase: makeSensitiveDisplayPreferenceUseCase(),
                                   hiddenNodesFeatureFlagEnabled: { DIContainer.remoteFeatureFlagUseCase.isFeatureFlagEnabled(for: .hiddenNodes) })
    }
    
    private func makeSensitiveDisplayPreferenceUseCase() -> some SensitiveDisplayPreferenceUseCaseProtocol {
        SensitiveDisplayPreferenceUseCase(
            sensitiveNodeUseCase: SensitiveNodeUseCase(
                nodeRepository: NodeRepository.newRepo,
                accountUseCase: AccountUseCase(repository: AccountRepository.newRepo)),
            contentConsumptionUserAttributeUseCase: ContentConsumptionUserAttributeUseCase(
                repo: UserAttributeRepository.newRepo),
            hiddenNodesFeatureFlagEnabled: { DIContainer.remoteFeatureFlagUseCase.isFeatureFlagEnabled(for: .hiddenNodes) })
    }
}
