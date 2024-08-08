@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAL10n
import MEGAPresentation
import MEGAPresentationMock
import MEGASwift
import MEGATest
import XCTest

final class GetLinkAlbumInfoCellViewModelTests: XCTestCase {
    
    func testDispatch_onViewReadyWithAlbumCover_shouldSetLabelsAndUpdateThumbnail() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let albumName = "Fruit"
        let albumCount = 45
        let album = AlbumEntity(id: 5, name: albumName, coverNode: NodeEntity(handle: 50), count: albumCount, type: .user)
        let sut = makeSUT(album: album,
                          thumbnailUseCase: MockThumbnailUseCase(loadThumbnailResult: .success(ThumbnailEntity(url: localURL, type: .thumbnail))))
        
        test(viewModel: sut, action: .onViewReady, expectedCommands: [
            .setLabels(title: albumName,
                       subtitle: Strings.Localizable.General.Format.Count.items(albumCount)),
            .setThumbnail(path: localURL.path)
        ])
    }
    
    func testDispatch_onViewReadyWithErrorAlbumCover_shouldSetLabelsAndSetPlaceholderThumbnail() throws {
        let albumName = "Fruit"
        let albumCount = 45
        let album = AlbumEntity(id: 5, name: albumName, coverNode: NodeEntity(handle: 50), count: albumCount, type: .user)
        let sut = makeSUT(album: album,
                          thumbnailUseCase: MockThumbnailUseCase(loadThumbnailResult: .failure(GenericErrorEntity())))
        
        test(viewModel: sut, action: .onViewReady, expectedCommands: [
            .setLabels(title: albumName,
                       subtitle: Strings.Localizable.General.Format.Count.items(albumCount)),
            .setPlaceholderThumbnail
        ])
    }
    
    func testDispatch_onViewReadyWithOutAlbumCover_shouldOnlySetLabels() throws {
        let albumName = "Fruit"
        let albumCount = 45
        let album = AlbumEntity(id: 5, name: albumName, count: albumCount, type: .user)
        let sut = makeSUT(album: album,
                          thumbnailUseCase: MockThumbnailUseCase())
        
        test(viewModel: sut, action: .onViewReady, expectedCommands: [
            .setLabels(title: albumName,
                       subtitle: Strings.Localizable.General.Format.Count.items(albumCount)),
            .setPlaceholderThumbnail
        ])
    }
    
    func testDispatchOnViewReady_photosCoverThumbnailLoaded_shouldSetAlbumCoverAndCount() async throws {
        let testCases: [(isHiddenNodesOn: Bool, excludeSensitives: Bool)] = [
            (isHiddenNodesOn: false, excludeSensitives: false),
            (isHiddenNodesOn: true, excludeSensitives: false),
            (isHiddenNodesOn: true, excludeSensitives: true)
        ]
        for (isHiddenNodesOn, excludeSensitives) in testCases {
            let albumName = "Test"
            let album = AlbumEntity(id: 5, name: albumName, type: .user)
            let coverNode = NodeEntity(handle: 4)
            let albumPhotos = [AlbumPhotoEntity(photo: coverNode)]
            let userAlbumPhotosAsyncSequence = SingleItemAsyncSequence(item: albumPhotos)
            let thumbnailURL = try makeImageURL()
            let thumbnailEntity = ThumbnailEntity(url: thumbnailURL, type: .thumbnail)
            let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(
                monitorUserAlbumPhotosAsyncSequence: userAlbumPhotosAsyncSequence.eraseToAnyAsyncSequence())
            let ccUserAttributesUseCase = MockContentConsumptionUserAttributeUseCase(
                sensitiveNodesUserAttributeEntity: .init(onboarded: false, showHiddenNodes: !excludeSensitives))
            let sut = makeSUT(
                album: album,
                thumbnailUseCase: MockThumbnailUseCase(
                    loadThumbnailResult: .success(thumbnailEntity)),
                monitorAlbumsUseCase: monitorAlbumsUseCase,
                contentConsumptionUserAttributeUseCase: ccUserAttributesUseCase,
                albumCoverUseCase: MockAlbumCoverUseCase(albumCover: coverNode),
                featureFlagProvider: MockFeatureFlagProvider(
                    list: [.albumPhotoCache: true, .hiddenNodes: isHiddenNodesOn]))
            
            test(viewModel: sut, action: .onViewReady, expectedCommands: [
                .setLabels(title: albumName,
                           subtitle: Strings.Localizable.General.Format.Count.items(albumPhotos.count)),
                .setThumbnail(path: thumbnailURL.path)
            ])
            
            await sut.loadingTask?.value
            let messages = await monitorAlbumsUseCase.state.monitorTypes
            XCTAssertEqual(messages, [.userAlbumPhotos(
                excludeSensitives: excludeSensitives, includeSensitiveInherited: false)])
        }
    }
    
    func testDispatchOnViewReady_photosLoaded_shouldSetCountAndPlaceholder() async throws {
        let albumName = "Test"
        let album = AlbumEntity(id: 5, name: albumName, type: .user)
        let monitorAlbumsUseCase = MockMonitorAlbumsUseCase(
            monitorUserAlbumPhotosAsyncSequence: SingleItemAsyncSequence(item: []).eraseToAnyAsyncSequence())
       
        let sut = makeSUT(
            album: album,
            monitorAlbumsUseCase: monitorAlbumsUseCase,
            featureFlagProvider: MockFeatureFlagProvider(
                list: [.albumPhotoCache: true]))
        
        test(viewModel: sut, action: .onViewReady, expectedCommands: [
            .setLabels(title: albumName,
                       subtitle: Strings.Localizable.General.Format.Count.items(0)),
            .setPlaceholderThumbnail
        ])
        
        await sut.loadingTask?.value
    }
    
    func testDispatch_cancelTasks_shouldCancelTasks() {
        let sut = makeSUT()
        
        sut.dispatch(.cancelTasks)
        
        XCTAssertNil(sut.loadingTask)
    }
    
    private func makeSUT(
        album: AlbumEntity = AlbumEntity(id: 1, type: .user),
        thumbnailUseCase: some ThumbnailUseCaseProtocol = MockThumbnailUseCase(),
        monitorAlbumsUseCase: some MonitorAlbumsUseCaseProtocol = MockMonitorAlbumsUseCase(),
        contentConsumptionUserAttributeUseCase: some ContentConsumptionUserAttributeUseCaseProtocol = MockContentConsumptionUserAttributeUseCase(),
        albumCoverUseCase: some AlbumCoverUseCaseProtocol = MockAlbumCoverUseCase(),
        featureFlagProvider: any FeatureFlagProviderProtocol = MockFeatureFlagProvider(list: [:]),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> GetLinkAlbumInfoCellViewModel {
        let sut = GetLinkAlbumInfoCellViewModel(
            album: album,
            thumbnailUseCase: thumbnailUseCase,
            monitorAlbumsUseCase: monitorAlbumsUseCase,
            contentConsumptionUserAttributeUseCase: contentConsumptionUserAttributeUseCase,
            albumCoverUseCase: albumCoverUseCase,
            featureFlagProvider: featureFlagProvider)
        trackForMemoryLeaks(on: sut, file: file, line: line)
        return sut
    }
}
