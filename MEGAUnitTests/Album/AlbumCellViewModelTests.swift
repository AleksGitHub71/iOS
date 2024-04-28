import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import MEGASwift
import MEGASwiftUI
import MEGATest
import SwiftUI
import XCTest

final class AlbumCellViewModelTests: XCTestCase {
    private let album = AlbumEntity(id: 1, name: "Test", coverNode: NodeEntity(handle: 1), count: 15, type: .favourite)
    private var subscriptions = Set<AnyCancellable>()
    
    func testInit_setTitleNodesAndTitlePublishers() throws {
        let sut = makeAlbumCellViewModel(album: album)
        
        XCTAssertEqual(sut.title, album.name)
        XCTAssertEqual(sut.numberOfNodes, album.count)
        XCTAssertTrue(sut.thumbnailContainer.type == .placeholder)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testInit_album_noCover_shouldSetCorrectThumbnail() {
        let sut = makeAlbumCellViewModel(album: AlbumEntity(id: 5, type: .user))
        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image(.placeholder), type: .placeholder)))
    }
    
    func testLoadAlbumThumbnail_onThumbnailLoaded_loadingStateIsCorrect() async throws {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailLoader = MockThumbnailLoader(loadImage: makeThumbnailAsyncSequence(container: thumbnailContainer))
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader)
        
        let exp = expectation(description: "loading should change during loading of albums")
        exp.expectedFulfillmentCount = 2
        
        var results = [Bool]()
        sut.$isLoading
            .dropFirst()
            .sink {
                results.append($0)
                exp.fulfill()
            }.store(in: &subscriptions)
        
        await sut.loadAlbumThumbnail()
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(results, [true, false])
    }
    
    func testLoadAlbumThumbnail_onLoadThumbnail_thumbnailContainerIsUpdatedWithLoadedImageIfContainerIsCurrentlyPlaceholder() async throws {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailLoader = MockThumbnailLoader(loadImage: makeThumbnailAsyncSequence(container: thumbnailContainer))
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader)
        
        await sut.loadAlbumThumbnail()
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
    }
    
    func testLoadAlbumThumbnail_onLoadThumbnailFailed_thumbnailIsNotUpdatedAndLoadedIsFalse() async throws {
        let sut = makeAlbumCellViewModel(album: album)
        let exp = expectation(description: "thumbnail should not change")
        exp.isInverted = true
        
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }.store(in: &subscriptions)
        
        await sut.loadAlbumThumbnail()
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testThumbnailContainer_cachedThumbnail_setThumbnailContainerWithoutPlaceholder() async throws {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailLoader = MockThumbnailLoader(initialImage: thumbnailContainer)
        
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader)
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        
        let exp = expectation(description: "thumbnail should not update again")
        exp.isInverted = true
        sut.$thumbnailContainer
            .dropFirst()
            .sink {_ in
                exp.fulfill()
            }.store(in: &subscriptions)
        
        await sut.loadAlbumThumbnail()
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
    }
    
    func testLoadAlbumThumbnail_cachedThumbnail_shouldNotLoadThumbnailAgain() async throws {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailLoader = MockThumbnailLoader(initialImage: thumbnailContainer)
        
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        
        let exp = expectation(description: "loading flag should not change")
        exp.isInverted = true
        sut.$isLoading
            .dropFirst()
            .sink {_ in
                exp.fulfill()
            }.store(in: &subscriptions)
        
        await sut.loadAlbumThumbnail()
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testIsSelected_whenUserTapOnAlbum_shouldBeSelected() {
        let selection = AlbumSelection()
        let sut = makeAlbumCellViewModel(album: album,
                                         selection: selection)
        
        sut.isSelected = true
        
        XCTAssertTrue(selection.isAlbumSelected(album))
    }
    
    func testShouldShowEditStateOpacity_whenAlbumListEditingAndonUserAlbum_shouldReturnRightValue() {
        let selection = AlbumSelection()
        let userAlbum1 = AlbumEntity(id: 4, name: "Album 1", coverNode: NodeEntity(handle: 3),
                                     count: 1, type: .user, modificationTime: nil)
        let sut = makeAlbumCellViewModel(album: userAlbum1,
                                         selection: selection )
        
        let exp = expectation(description: "Should set shouldShowEditStateOpacity to 1.0")
        exp.expectedFulfillmentCount = 2
        
        var result = [Double]()
        
        sut.$shouldShowEditStateOpacity
            .dropFirst()
            .sink {
                result.append($0)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        selection.editMode = .active
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(result, [0.0, 1.0])
    }
    
    func testShouldShowEditStateOpacity_whenAlbumListEditingAndonSystemAlbum_shouldReturnRightValue() {
        let selection = AlbumSelection()
        let systemAlbum = AlbumEntity(id: 4, name: "Gif", coverNode: NodeEntity(handle: 3),
                                      count: 1, type: .gif, modificationTime: nil)
        let sut = makeAlbumCellViewModel(album: systemAlbum,
                                         selection: selection)
        
        let exp = expectation(description: "Should set shouldShowEditStateOpaicity to 0.0")
        exp.expectedFulfillmentCount = 2
        
        var result = [Double]()
        
        sut.$shouldShowEditStateOpacity
            .dropFirst()
            .sink {
                result.append($0)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        selection.editMode = .active
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(result, [0.0, 0.0])
    }
    
    func testOpacity_whenAlbumListEditingAndUserAlbum_shouldReturnRightValue() {
        let selection = AlbumSelection()
        let userAlbum1 = AlbumEntity(id: 4, name: "Album 1", coverNode: NodeEntity(handle: 3),
                                     count: 1, type: .user, modificationTime: nil)
        let sut = makeAlbumCellViewModel(album: userAlbum1,
                                         selection: selection)
        
        let exp = expectation(description: "Should set shouldShowEditStateOpacity to 1.0")
        exp.expectedFulfillmentCount = 2
        
        var result = [Double]()
        
        sut.$opacity
            .dropFirst()
            .sink {
                result.append($0)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        selection.editMode = .active
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(result, [1.0, 1.0])
    }
    
    func testOpacity_whenAlbumListEditingAndSystemAlbum_shouldReturnRightValue() {
        let selection = AlbumSelection()
        let systemAlbum = AlbumEntity(id: 4, name: "Gif", coverNode: NodeEntity(handle: 3),
                                      count: 1, type: .gif, modificationTime: nil)
        let sut = makeAlbumCellViewModel(album: systemAlbum, selection: selection)
        
        let exp = expectation(description: "Should set shouldShowEditStateOpacity to 0.5")
        exp.expectedFulfillmentCount = 2
        
        var result = [Double]()
        
        sut.$opacity
            .dropFirst()
            .sink {
                result.append($0)
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        selection.editMode = .active
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(result, [1.0, 0.5])
    }
    
    func testOnAlbumTap_onUserAlbum_shouldToggleSelectionAndTrackEvent() {
        let album = AlbumEntity(id: 4, type: .user)
        let tracker = MockTracker()
        let sut = makeAlbumCellViewModel(
            album: album,
            tracker: tracker)
        
        XCTAssertFalse(sut.isSelected)
        
        sut.onAlbumTap()
        
        XCTAssertTrue(sut.isSelected)
        
        sut.onAlbumTap()
        
        XCTAssertFalse(sut.isSelected)
        
        assertTrackAnalyticsEventCalled(
            trackedEventIdentifiers: tracker.trackedEventIdentifiers,
            with: [
                album.makeAlbumSelectedEvent(selectionType: .multiadd),
                album.makeAlbumSelectedEvent(selectionType: .multiremove)
            ]
        )
    }
    
    func testOnAlbumTap_whenUserTapOnAlbumCell_ShouldNotToggleForSystemAlbums() {
        let sut = makeAlbumCellViewModel(
            album: AlbumEntity(id: 4, name: "Gif", coverNode: NodeEntity(handle: 3),
                               count: 1, type: .gif, modificationTime: nil))
        
        XCTAssertFalse(sut.isSelected)
        sut.onAlbumTap()
        XCTAssertFalse(sut.isSelected)
    }
    
    func testFeatureFlagForShowingShareIconOnAlbum_whenTurnedOff_shouldNotShowShareLink() {
        
        let sut = makeAlbumCellViewModel(
            album: AlbumEntity(id: 4, name: "User", coverNode: NodeEntity(handle: 3), count: 1, type: .user, modificationTime: nil, sharedLinkStatus: .exported(true)))
        
        XCTAssertTrue(sut.isLinkShared)
    }
    
    func testMonitorAlbumPhotos_onPhotosReturned_shouldUpdateNodeCount() async {
        let albumId = HandleEntity(65)
        let albumPhotos = (1...15).map {
            AlbumPhotoEntity(photo: NodeEntity(handle: $0),
                             albumPhotoId: albumId)
        }
        let monitorUserAlbumPhotos = SingleItemAsyncSequence(item: albumPhotos)
            .eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
        let album = AlbumEntity(id: albumId, type: .user)
        
        let sut = makeAlbumCellViewModel(album: album,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let exp = expectation(description: "Should update count")
        
        let subscription = sut.$numberOfNodes
            .dropFirst()
            .sink {
                XCTAssertEqual($0, albumPhotos.count)
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorAlbumPhotos_userAlbumCoverNil_shouldSetLatestPhotoAsCover() async throws {
        let latestCoverHandle = HandleEntity(76)
        let album = AlbumEntity(id: 65, name: "User",
                                coverNode: nil, count: 0, type: .user)
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailAsyncSequence = makeThumbnailAsyncSequence(container: thumbnailContainer)
        let thumbnailLoader = MockThumbnailLoader(loadImages: [latestCoverHandle: thumbnailAsyncSequence])
        
        let albumPhotos = [
            AlbumPhotoEntity(photo: NodeEntity(handle: 1, modificationTime: try "2024-04-08T22:01:04Z".date),
                             albumPhotoId: album.id),
            AlbumPhotoEntity(photo: NodeEntity(handle: latestCoverHandle, modificationTime: try "2024-04-09T10:01:04Z".date),
                             albumPhotoId: album.id),
            AlbumPhotoEntity(photo: NodeEntity(handle: 3, modificationTime: try "2024-04-02T22:01:04Z".date),
                             albumPhotoId: album.id)
        ]
        let monitorUserAlbumPhotos = SingleItemAsyncSequence(item: albumPhotos)
            .eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
       
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let exp = expectation(description: "Should update thumbnail with latest photo")
        
        let subscription = sut.$thumbnailContainer
            .dropFirst()
            .sink {
                XCTAssertTrue($0.isEqual(thumbnailContainer))
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorAlbumPhotos_userAlbumCoverNilNoPhotos_shouldNotUpdateAlbumCover() async throws {
        let album = AlbumEntity(id: 65, name: "User",
                                coverNode: nil, count: 0, type: .user)
        
        let monitorUserAlbumPhotos = SingleItemAsyncSequence<[AlbumPhotoEntity]>(item: [])
            .eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
        
        let sut = makeAlbumCellViewModel(album: album,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let exp = expectation(description: "Should not update thumbnail with latest photo")
        exp.isInverted = true
        
        let subscription = sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 0.5)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorAlbumPhotos_userAlbumCoverIsInRubbishBin_shouldUseDefaultCover() async {
        let cover = NodeEntity(handle: 54)
        let album = AlbumEntity(id: 65, name: "User",
                                coverNode: cover, count: 0, type: .user)
        let defaultCover = NodeEntity(handle: 87)
        let coverImageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailAsyncSequence = makeThumbnailAsyncSequence(container: coverImageContainer)
        let thumbnailLoader = MockThumbnailLoader(loadImages: [defaultCover.handle: thumbnailAsyncSequence])
        
        let monitorUserAlbumPhotos = SingleItemAsyncSequence(item: [
            AlbumPhotoEntity(photo: defaultCover)
        ]).eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(
            monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let nodeUseCase = MockNodeDataUseCase(isNodeInRubbishBin: { _ in true })
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
        
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         nodeUseCase: nodeUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let exp = expectation(description: "Should update cover with default photo")
        
        let subscription = sut.$thumbnailContainer
            .dropFirst()
            .sink {
                XCTAssertTrue($0.isEqual(coverImageContainer))
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorAlbumPhotos_userAlbumCoverIsRestoredFromRubbish_shouldSetAlbumCover() async {
        let cover = NodeEntity(handle: 54)
        let album = AlbumEntity(id: 65, name: "User",
                                coverNode: cover, count: 0, type: .user)
        let coverImageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailAsyncSequence = makeThumbnailAsyncSequence(container: coverImageContainer)
        let thumbnailLoader = MockThumbnailLoader(loadImages: [cover.handle: thumbnailAsyncSequence])
        
        let monitorUserAlbumPhotos = SingleItemAsyncSequence(item: [
            AlbumPhotoEntity(photo: cover)
        ]).eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(
            monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let nodeUseCase = MockNodeDataUseCase(isNodeInRubbishBin: { _ in false })
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
        
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         nodeUseCase: nodeUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let loadedThumbnail = ImageContainer(image: Image(systemName: "heart"), type: .thumbnail)
        sut.thumbnailContainer = loadedThumbnail
        
        let exp = expectation(description: "Should update cover with album cover photo")
        
        let subscription = sut.$thumbnailContainer
            .dropFirst()
            .sink {
                XCTAssertTrue($0.isEqual(coverImageContainer))
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorAlbumPhotos_userAlbumCoverNotInRubbishButNotInPhotos_shouldUseDefaultCover() async {
        let cover = NodeEntity(handle: 54)
        let album = AlbumEntity(id: 65, name: "User",
                                coverNode: cover, count: 0, type: .user)
        let defaultCover = NodeEntity(handle: 87)
        let coverImageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let thumbnailAsyncSequence = makeThumbnailAsyncSequence(container: coverImageContainer)
        let thumbnailLoader = MockThumbnailLoader(loadImages: [defaultCover.handle: thumbnailAsyncSequence])
        
        let monitorUserAlbumPhotos = SingleItemAsyncSequence(item: [
            AlbumPhotoEntity(photo: defaultCover)
        ]).eraseToAnyAsyncSequence()
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(
            monitorUserAlbumPhotosAsyncSequence: monitorUserAlbumPhotos)
        let nodeUseCase = MockNodeDataUseCase(isNodeInRubbishBin: { _ in false })
        let featureFlagProvider = MockFeatureFlagProvider(list: [.albumPhotoCache: true])
        
        let sut = makeAlbumCellViewModel(album: album,
                                         thumbnailLoader: thumbnailLoader,
                                         monitorAlbumsUseCase: monitorAlbumsUseCase,
                                         nodeUseCase: nodeUseCase,
                                         featureFlagProvider: featureFlagProvider)
        
        let exp = expectation(description: "Should update cover with default photo")
        
        let subscription = sut.$thumbnailContainer
            .dropFirst()
            .sink {
                XCTAssertTrue($0.isEqual(coverImageContainer))
                exp.fulfill()
            }
        
        let task = Task { await sut.monitorAlbumPhotos() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    // MARK: - Helpers
    
    private func makeAlbumCellViewModel(
        album: AlbumEntity,
        thumbnailLoader: some ThumbnailLoaderProtocol = MockThumbnailLoader(),
        monitorAlbumsUseCase: some MonitorAlbumsUseCaseProtocol = MockMonitorAlbumsUseCase(),
        nodeUseCase: some NodeUseCaseProtocol = MockNodeDataUseCase(),
        selection: AlbumSelection = AlbumSelection(),
        tracker: some AnalyticsTracking = MockTracker(),
        featureFlagProvider: some FeatureFlagProviderProtocol = MockFeatureFlagProvider(list: [:]),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> AlbumCellViewModel {
        let sut = AlbumCellViewModel(thumbnailLoader: thumbnailLoader,
                                     monitorAlbumsUseCase: monitorAlbumsUseCase,
                                     nodeUseCase: nodeUseCase,
                                     album: album,
                                     selection: selection,
                                     tracker: tracker,
                                     featureFlagProvider: featureFlagProvider)
        trackForMemoryLeaks(on: sut, file: file, line: line)
        return sut
    }
    
    private func makeThumbnailAsyncSequence(
        container: ImageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
    ) -> AnyAsyncSequence<any ImageContaining> {
        SingleItemAsyncSequence(item: container)
            .eraseToAnyAsyncSequence()
    }
}
