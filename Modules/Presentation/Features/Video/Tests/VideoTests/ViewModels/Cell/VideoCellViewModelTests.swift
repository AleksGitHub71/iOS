import Combine
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import MEGASwift
import MEGATest
import SwiftUI
@testable import Video
import XCTest

final class VideoCellViewModelTests: XCTestCase {
        
    func testAttemptLoadThumbnail_whenNoThumbnailLoaded_deliverPlaceholderImage() async throws {
        let node = nodeEntity(name: "name", handle: 1, hasThumbnail: true, isFavorite: true, label: .blue, size: 12, duration: 12)
        
        let thumbnailLoader = MockThumbnailLoader(initialImage: nil)
        let (sut, _) = makeSUT(thumbnailLoader: thumbnailLoader, nodeEntity: node)
        
        try await sut.attemptLoadThumbnail()
        
        let previewEntity = sut.previewEntity
        XCTAssertEqual(previewEntity.imageContainer.image, Image(systemName: "square.fill"))
    }
    
    func testAttemptLoadThumbnail_whenHasThumbnailLoadsImage_deliversImage() async throws {
        let node = nodeEntity(name: "name", handle: 1, hasThumbnail: true, isFavorite: true, label: .blue, size: 12, duration: 12)
        let imageURL = try makeImageURL()
        let imageContainer = try XCTUnwrap(URLImageContainer(imageURL: imageURL, type: .thumbnail))

        let thumbnailLoader = MockThumbnailLoader(loadImage: SingleItemAsyncSequence(item: imageContainer).eraseToAnyAsyncSequence())
        let (sut, _) = makeSUT(thumbnailLoader: thumbnailLoader, nodeEntity: node)
        
        try await sut.attemptLoadThumbnail()
        
        let previewEntity = sut.previewEntity
        
        XCTAssertTrue(previewEntity.imageContainer.isEqual(imageContainer))
    }
    
    func testMonitorInheritedSensitivityChanges_videoNotSensitive_shouldUpdateImageContainerWithInitialResultFirst() async throws {
        let video = NodeEntity(handle: 65, isMarkedSensitive: false)
        
        let imageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let isInheritedSensitivity = false
        let isInheritedSensitivityUpdate = true
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: isInheritedSensitivityUpdate)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockSensitiveNodeUseCase(
            isInheritingSensitivityResult: .success(isInheritedSensitivity),
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        let (sut, _) = makeSUT(
            thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
            sensitiveNodeUseCase: nodeUseCase,
            nodeEntity: video,
            featureFlagHiddenNodes: true
        )
        
        var expectedImageContainer = [
            imageContainer.toSensitiveImageContaining(isSensitive: isInheritedSensitivity),
            imageContainer.toSensitiveImageContaining(isSensitive: isInheritedSensitivityUpdate)
        ]
        
        let exp = expectation(description: "Should update video with initial then from monitor")
        exp.expectedFulfillmentCount = expectedImageContainer.count
        
        let subscription = thumbnailContainerUpdates(on: sut) {
            XCTAssertTrue($0.isEqual(expectedImageContainer.removeFirst()))
            exp.fulfill()
        }
        
        await trackTaskCancellation { await sut.monitorInheritedSensitivityChanges() }

        await fulfillment(of: [exp], timeout: 1.0)
        subscription.cancel()
    }
    
    func testMonitorInheritedSensitivityChanges_inheritedSensitivityChange_shouldNotUpdateIfImageContainerTheSame() async throws {
        let video = NodeEntity(handle: 65, isMarkedSensitive: false)
        let imageContainer = SensitiveImageContainer(image: Image("folder"), type: .thumbnail, isSensitive: video.isMarkedSensitive)
        
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: video.isMarkedSensitive)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockSensitiveNodeUseCase(
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        
        let (sut, _) = makeSUT(
            thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
            sensitiveNodeUseCase: nodeUseCase,
            nodeEntity: video,
            featureFlagHiddenNodes: true
        )
        
        let exp = expectation(description: "Should not update image container")
        exp.isInverted = true
        
        let subscription = thumbnailContainerUpdates(on: sut) { _ in
            exp.fulfill()
        }
        
        await trackTaskCancellation { await sut.monitorInheritedSensitivityChanges() }

        await fulfillment(of: [exp], timeout: 1.0)
        subscription.cancel()
    }
    
    func testMonitorInheritedSensitivityChanges_thumbnailContainerPlaceholder_shouldNotUpdateImageContainer() async throws {
        let video = NodeEntity(handle: 65, isMarkedSensitive: false)
        let imageContainer = ImageContainer(image: Image("folder"), type: .placeholder)
        
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: !video.isMarkedSensitive)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockSensitiveNodeUseCase(
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        
        let (sut, _) = makeSUT(
            thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
            sensitiveNodeUseCase: nodeUseCase,
            nodeEntity: video,
            featureFlagHiddenNodes: true
        )
        
        let exp = expectation(description: "Should not update image container")
        exp.isInverted = true
        
        let subscription = thumbnailContainerUpdates(on: sut) { _ in
            exp.fulfill()
        }
        
        trackTaskCancellation { await sut.monitorInheritedSensitivityChanges() }

        await fulfillment(of: [exp], timeout: 1.0)
        
        subscription.cancel()
    }
    
    func testMonitorInheritedSensitivityChanges_videoMarkedSensitive_shouldNotUpdateImageContainer() async throws {
        let video = NodeEntity(handle: 65, isMarkedSensitive: true)
        let imageContainer = ImageContainer(image: Image("folder"), type: .placeholder)
        
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: video.isMarkedSensitive)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockSensitiveNodeUseCase(
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        
        let (sut, _) = makeSUT(
            thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
            sensitiveNodeUseCase: nodeUseCase,
            nodeEntity: video,
            featureFlagHiddenNodes: true
        )
        
        let exp = expectation(description: "Should not update image container")
        exp.isInverted = true
        
        let subscription = thumbnailContainerUpdates(on: sut) { _ in
            exp.fulfill()
        }
        
        await trackTaskCancellation { await sut.monitorInheritedSensitivityChanges() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        subscription.cancel()
    }
    
    func testOnTappedMoreOptions_whenCalled_triggerTap() async {
        let video = nodeEntity(name: "name", handle: 1, hasThumbnail: true, isFavorite: true, label: .blue, size: 12, duration: 12)
        let thumbnailLoader = MockThumbnailLoader()
        var tappedNodes = [NodeEntity]()
        let (sut, _) = makeSUT(
            thumbnailLoader: thumbnailLoader,
            nodeEntity: video,
            onTapMoreOptions: { tappedNodes.append($0) }
        )
        
        sut.onTappedMoreOptions()
        
        XCTAssertEqual(tappedNodes, [ video ])
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        thumbnailLoader: some ThumbnailLoaderProtocol = MockThumbnailLoader(),
        sensitiveNodeUseCase: some SensitiveNodeUseCaseProtocol = MockSensitiveNodeUseCase(),
        nodeEntity: NodeEntity,
        onTapMoreOptions: @escaping (_ node: NodeEntity) -> Void = { _ in },
        featureFlagHiddenNodes: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: VideoCellViewModel,
        videoListViewModel: VideoListViewModel
    ) {
        
        let videoListViewModel = VideoListViewModel(
            syncModel: VideoRevampSyncModel(),
            selection: VideoSelection(),
            fileSearchUseCase: MockFilesSearchUseCase(searchResult: .success([nodeEntity])),
            photoLibraryUseCase: MockPhotoLibraryUseCase(),
            thumbnailLoader: thumbnailLoader,
            sensitiveNodeUseCase: sensitiveNodeUseCase
        )
        
        let sut = VideoCellViewModel(
            nodeEntity: nodeEntity,
            thumbnailLoader: thumbnailLoader,
            sensitiveNodeUseCase: sensitiveNodeUseCase,
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: featureFlagHiddenNodes]),
            onTapMoreOptions: onTapMoreOptions
        )
        trackForMemoryLeaks(on: sut, file: file, line: line)
        return (sut, videoListViewModel)
    }
    
    private func nodeEntity(name: String, handle: HandleEntity, hasThumbnail: Bool, isPublic: Bool = false, isShare: Bool = false, isFavorite: Bool, label: NodeLabelTypeEntity, size: UInt64, duration: Int) -> NodeEntity {
        NodeEntity(
            changeTypes: .name,
            nodeType: .folder,
            name: name,
            handle: handle,
            hasThumbnail: hasThumbnail,
            hasPreview: true,
            isPublic: isPublic,
            isShare: isShare,
            isFavourite: isFavorite,
            label: label,
            publicHandle: handle,
            size: size,
            duration: duration,
            mediaType: .video
        )
    }
    
    private func thumbnailContainerUpdates(on sut: VideoCellViewModel, action: @escaping (any ImageContaining) -> Void) -> AnyCancellable {
        sut.$previewEntity
            .dropFirst()
            .map { $0.imageContainer }
            .sink(receiveValue: action)
    }
}
