import Combine
import Foundation

public protocol AlbumListUseCaseProtocol {
    var albumsUpdatedPublisher: AnyPublisher<Void, Never> { get }
    func systemAlbums() async throws -> [AlbumEntity]
    func userAlbums() async -> [AlbumEntity]
    func createUserAlbum(with name: String?) async throws -> AlbumEntity
    func hasNoPhotosAndVideos() async -> Bool
}

public struct AlbumListUseCase: AlbumListUseCaseProtocol {
    
    private let fileSearchRepository: any FilesSearchRepositoryProtocol
    private let mediaUseCase: any MediaUseCaseProtocol
    private let userAlbumRepository: any UserAlbumRepositoryProtocol
    private let albumContentsUpdateRepository: any AlbumContentsUpdateNotifierRepositoryProtocol
    private let albumContentsUseCase: any AlbumContentsUseCaseProtocol
    private let contentConsumptionUserAttributeUseCase: any ContentConsumptionUserAttributeUseCaseProtocol
    private let hiddenNodesFeatureFlagEnabled: @Sendable () -> Bool
    
    public var albumsUpdatedPublisher: AnyPublisher<Void, Never> {
        userAlbumUpdates
            .merge(with: albumContentsUpdateRepository.albumReloadPublisher)
            .eraseToAnyPublisher()
    }
    
    private var userAlbumUpdates: AnyPublisher<Void, Never> {
        userAlbumRepository.setsUpdatedPublisher
            .filter { $0.isNotEmpty }
            .map { _ in () }
            .eraseToAnyPublisher()
            .merge(with: userAlbumRepository.setElementsUpdatedPublisher
                .filter { $0.isNotEmpty }
                .map { _ in () }
                .eraseToAnyPublisher())
            .eraseToAnyPublisher()
    }
    
    public init(
        fileSearchRepository: some FilesSearchRepositoryProtocol,
        mediaUseCase: some MediaUseCaseProtocol,
        userAlbumRepository: some UserAlbumRepositoryProtocol,
        albumContentsUpdateRepository: some AlbumContentsUpdateNotifierRepositoryProtocol,
        albumContentsUseCase: some AlbumContentsUseCaseProtocol,
        contentConsumptionUserAttributeUseCase: some ContentConsumptionUserAttributeUseCaseProtocol,
        hiddenNodesFeatureFlagEnabled: @escaping @Sendable () -> Bool
    ) {
        self.fileSearchRepository = fileSearchRepository
        self.mediaUseCase = mediaUseCase
        self.userAlbumRepository = userAlbumRepository
        self.albumContentsUpdateRepository = albumContentsUpdateRepository
        self.albumContentsUseCase = albumContentsUseCase
        self.contentConsumptionUserAttributeUseCase = contentConsumptionUserAttributeUseCase
        self.hiddenNodesFeatureFlagEnabled = hiddenNodesFeatureFlagEnabled
    }
    
    public func systemAlbums() async throws -> [AlbumEntity] {
        let allPhotos = try await allSortedThumbnailPhotosAndVideos()
        return await createSystemAlbums(allPhotos)
    }
    
    public func userAlbums() async -> [AlbumEntity] {
        let albums = await userAlbumRepository.albums()
        let showHiddenPhotos = await showHiddenPhotos()
        
        return await withTaskGroup(of: AlbumEntity.self,
                                   returning: [AlbumEntity].self) { group in
            albums.forEach { setEntity in
                group.addTask {
                    let userAlbumContent = await albumContentsUseCase.userAlbumPhotos(by: setEntity.handle,
                                                                                      showHidden: showHiddenPhotos)
                    let coverNode = await albumCoverNode(forAlbum: setEntity,
                                                         albumContent: userAlbumContent)
                    return AlbumEntity(id: setEntity.handle,
                                       name: setEntity.name,
                                       coverNode: coverNode,
                                       count: userAlbumContent.count,
                                       type: .user,
                                       creationTime: setEntity.creationTime,
                                       modificationTime: setEntity.modificationTime,
                                       sharedLinkStatus: .exported(setEntity.isExported),
                                       metaData: makeAlbumMetaData(albumContent: userAlbumContent))
                }
            }
            return await group.reduce(into: [AlbumEntity]()) {
                $0.append($1)
            }
        }
    }
    
    public func createUserAlbum(with name: String?) async throws -> AlbumEntity {
        let setEntity = try await userAlbumRepository.createAlbum(name)
        return AlbumEntity(id: setEntity.handle,
                           name: setEntity.name,
                           coverNode: nil,
                           count: 0,
                           type: .user,
                           creationTime: setEntity.creationTime,
                           modificationTime: setEntity.modificationTime,
                           sharedLinkStatus: .exported(false))
    }
    
    // MARK: - Private
    
    private func allPhotos() async throws -> [NodeEntity] {
        try await fileSearchRepository.search(string: "",
                                              parent: nil,
                                              recursive: true,
                                              supportCancel: false,
                                              sortOrderType: .defaultDesc,
                                              formatType: .photo)
    }
    
    private func allVideos() async throws -> [NodeEntity] {
        try await fileSearchRepository.search(string: "",
                                              parent: nil,
                                              recursive: true,
                                              supportCancel: false,
                                              sortOrderType: .defaultDesc,
                                              formatType: .video)
    }
    
    private func allSortedThumbnailPhotosAndVideos() async throws -> [NodeEntity] {
        let allPhotos = try await allPhotos()
        let allVideos = try await allVideos()
        
        var allThumbnailPhotosAndVideos = [allPhotos, allVideos]
            .flatMap { $0 }
            .filter { $0.hasThumbnail && $0.mediaType != nil }
        allThumbnailPhotosAndVideos.sort {
            if $0.modificationTime == $1.modificationTime {
                return $0.handle > $1.handle
            }
            return $0.modificationTime > $1.modificationTime
        }
        return allThumbnailPhotosAndVideos
    }
    
    private func createSystemAlbums(_ photos: [NodeEntity]) async -> [AlbumEntity] {
        var coverOfFavouritePhoto: NodeEntity?
        var coverOfGifPhoto: NodeEntity?
        var coverOfRawPhoto: NodeEntity?
        var numOfFavouritePhotos = 0
        var numOfGifPhotos = 0
        var numOfRawPhotos = 0
        
        photos.forEach { photo in
            if photo.isFavourite {
                numOfFavouritePhotos += 1
                if coverOfFavouritePhoto == nil { coverOfFavouritePhoto = photo }
            }
            if mediaUseCase.isRawImage(photo.name) {
                numOfRawPhotos += 1
                if coverOfRawPhoto == nil { coverOfRawPhoto = photo }
            } else if mediaUseCase.isGifImage(photo.name) {
                numOfGifPhotos += 1
                if coverOfGifPhoto == nil { coverOfGifPhoto = photo }
            }
        }
        
        var albums = [AlbumEntity]()
        albums.append(AlbumEntity(id: AlbumIdEntity.favourite.value, name: "", coverNode: coverOfFavouritePhoto, count: numOfFavouritePhotos, type: .favourite))
        
        if let coverOfGifPhoto {
            albums.append(AlbumEntity(id: AlbumIdEntity.gif.value, name: "", coverNode: coverOfGifPhoto, count: numOfGifPhotos, type: .gif))
        }
        
        if let coverOfRawPhoto {
            albums.append(AlbumEntity(id: AlbumIdEntity.raw.value, name: "", coverNode: coverOfRawPhoto, count: numOfRawPhotos, type: .raw))
        }
        
        return albums
    }
    
    private func albumCoverNode(forAlbum entity: SetEntity, albumContent: [AlbumPhotoEntity]) async -> NodeEntity? {
        if entity.coverId != .invalid,
           let albumCoverSetElement = await userAlbumRepository.albumElement(by: entity.handle,
                                                                             elementId: entity.coverId),
           let albumCover = albumContent.first(where: { $0.id == albumCoverSetElement.nodeId }) {
            return albumCover.photo
        }
        return albumContent.latestModifiedPhoto()
    }
    
    private func makeAlbumMetaData(albumContent: [AlbumPhotoEntity]) -> AlbumMetaDataEntity {
        let counts = albumContent
            .reduce(into: (image: 0, video: 0)) { (result, content) in
                guard let mediaType = content.photo.mediaType else { return }
                switch mediaType {
                case .image:
                    result.image += 1
                case .video:
                    result.video += 1
                }
            }
        
        return AlbumMetaDataEntity(imageCount: counts.image,
                                   videoCount: counts.video)
    }
    
    public func hasNoPhotosAndVideos() async -> Bool {
        let allPhotos = try? await allPhotos()
        let allVideos = try? await allVideos()
        
        let allPhotosAndVideos = [allPhotos, allVideos]
            .flatMap { $0 ?? [] }
            .filter { $0.hasThumbnail }
        
        return allPhotosAndVideos.isEmpty
    }
    
    private func showHiddenPhotos() async -> Bool {
        guard hiddenNodesFeatureFlagEnabled() else { return true }
        
        return await contentConsumptionUserAttributeUseCase.fetchSensitiveAttribute()
            .showHiddenNodes
    }
}
