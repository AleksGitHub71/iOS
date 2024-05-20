import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAFoundation
import MEGAPresentation
import MEGAPresentationMock
import MEGASwift
import MEGASwiftUI
import SwiftUI
import XCTest

final class PhotoCellViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()
    private var allViewModel: PhotoLibraryModeAllGridViewModel!
    
    private var testNodes: [NodeEntity] {
        get throws {
            [
                NodeEntity(name: "00.jpg", handle: 100, modificationTime: try "2022-09-03T22:01:04Z".date),
                NodeEntity(name: "0.jpg", handle: 0, modificationTime: try "2022-09-01T22:01:04Z".date),
                NodeEntity(name: "a.jpg", handle: 1, modificationTime: try "2022-08-18T22:01:04Z".date),
                NodeEntity(name: "a.jpg", handle: 2, modificationTime: try "2022-08-10T22:01:04Z".date),
                NodeEntity(name: "b.jpg", handle: 3, modificationTime: try "2020-04-18T20:01:04Z".date),
                NodeEntity(name: "c.mov", handle: 4, modificationTime: try "2020-04-18T12:01:04Z".date),
                NodeEntity(name: "d.mp4", handle: 5, modificationTime: try "2020-04-18T01:01:04Z".date),
                NodeEntity(name: "e.mp4", handle: 6, modificationTime: try "2019-10-18T01:01:04Z".date),
                NodeEntity(name: "f.mp4", handle: 7, modificationTime: try "2018-01-23T01:01:04Z".date),
                NodeEntity(name: "g.mp4", handle: 8, modificationTime: try "2017-12-31T01:01:04Z".date)
            ]
        }
    }
    
    override func setUpWithError() throws {
        let library = try testNodes.toPhotoLibrary(withSortType: .newest, in: .GMT)
        let libraryViewModel = PhotoLibraryContentViewModel(library: library)
        libraryViewModel.selectedMode = .all
        allViewModel = PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel)
    }
    
    func testInit_defaultValue() {
        let initialContainer = ImageContainer(image: Image(FileTypes().fileTypeResource(forFileName: "0.jpg")), type: .placeholder)
        let sut = makeSUT(photo: NodeEntity(name: "0.jpg", handle: 0),
                                     viewModel: allViewModel,
                          thumbnailLoader: MockThumbnailLoader(initialImage: initialContainer))
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(initialContainer))
        XCTAssertEqual(sut.duration, "00:00")
        XCTAssertEqual(sut.isVideo, false)
        XCTAssertEqual(sut.currentZoomScaleFactor, .three)
        XCTAssertEqual(sut.isSelected, false)
    }
    
    func testInit_videoNode_isVideoIsTrueAndDurationIsApplied() {
        let duration = 120
        let sut = makeSUT(photo: NodeEntity(name: "0.jpg", handle: 0, duration: duration, mediaType: .video),
                                     viewModel: allViewModel)
        XCTAssertEqual(sut.isVideo, true)
        XCTAssertEqual(sut.duration, "02:00")
    }
    
    func testLoadThumbnail_zoomInAndHasCachedThumbnail_onlyLoadPreview() {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let previewContainer = ImageContainer(image: Image("folder"), type: .preview)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: previewContainer)
            .eraseToAnyAsyncSequence()
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        let task = Task { await sut.startLoadingThumbnail() }
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(previewContainer))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(previewContainer))
        
        task.cancel()
    }
    
    func testLoadThumbnail_zoomOut_noLoadLocalThumbnailAndRemotePreview() {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let previewContainer = ImageContainer(image: Image("folder.fill"), type: .preview)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: previewContainer)
            .eraseToAnyAsyncSequence()
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true
        
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.out)
        
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(sut.currentZoomScaleFactor, .five)
        
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnail_showThumbnailUponInit() async {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer)
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
    }
    
    func testLoadThumbnail_hasDifferentThumbnailAndLoadThumbnail_noLoading() async {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer)
        )
        
        sut.thumbnailContainer = ImageContainer(image: Image(systemName: "heart"), type: .thumbnail)
        
        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true
        
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
                
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image(systemName: "heart"), type: .thumbnail)))
    }
    
    func testLoadThumbnail_noThumbnails_showPlaceholder() async {
        let placeholder = ImageContainer(image: Image(.filetypeImages), type: .placeholder)
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: placeholder)
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(placeholder))
        
        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true
        
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func testLoadThumbnail_noCachedThumbnailAndNonSingleColumn_loadThumbnail() {
        let placeholder = ImageContainer(image: Image(.filetypeImages), type: .placeholder)
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: thumbnailContainer)
            .eraseToAnyAsyncSequence()
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: placeholder,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(placeholder))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(thumbnailContainer))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        XCTAssertEqual(sut.currentZoomScaleFactor, .three)
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        task.cancel()
    }
    
    func testLoadThumbnail_noCachedThumbnailAndZoomInToSingleColumn_loadBothThumbnailAndPreview() {
        let placeholder = ImageContainer(image: Image(.filetypeImages), type: .placeholder)
        let remoteThumbnail = ImageContainer(image: Image("folder.fill"), type: .thumbnail)
        let previewContainer = ImageContainer(image: Image("folder"), type: .preview)
        
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: (any ImageContaining).self)
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: placeholder,
                                                 loadImage: stream.eraseToAnyAsyncSequence())
        )

        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(placeholder))
        
        let exp = expectation(description: "thumbnail is changed")
        exp.expectedFulfillmentCount = 2
        
        var expectedContainers = [remoteThumbnail,
                                  previewContainer]
        
        sut.$thumbnailContainer
            .dropFirst(1)
            .sink { container in
                XCTAssertTrue(container.isEqual(expectedContainers.removeFirst()))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        
        [remoteThumbnail, previewContainer].forEach {
            continuation.yield($0)
        }
        continuation.finish()
        
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(previewContainer))
        XCTAssertTrue(expectedContainers.isEmpty)
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndNonSingleColumnAndSameRemoteThumbnail_noLoading() async {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: thumbnailContainer)
            .eraseToAnyAsyncSequence()
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        
        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true
        
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        XCTAssertEqual(sut.currentZoomScaleFactor, .three)
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndZoomInToSingleColumnAndSameRemoteThumbnail_onlyLoadPreview() {
        let thumbnailContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let previewContainer = ImageContainer(image: Image("folder.fill"), type: .preview)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: previewContainer)
            .eraseToAnyAsyncSequence()
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: thumbnailContainer,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(thumbnailContainer))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(previewContainer))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(previewContainer))
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndZoomInToSingleColumnAndDifferentRemoteThumbnail_loadBothThumbnailAndPreview() {
        let initialThumbnail = ImageContainer(image: Image("folder"), type: .thumbnail)
        let remoteThumbnail = ImageContainer(image: Image("heart"), type: .thumbnail)
        let loadedPreview = ImageContainer(image: Image("folder.fill"), type: .preview)
        
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: (any ImageContaining).self)
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: initialThumbnail,
                                                 loadImage: stream.eraseToAnyAsyncSequence())
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(initialThumbnail))
        
        let exp = expectation(description: "thumbnail is changed")
        exp.expectedFulfillmentCount = 2
        var expectedContainers = [remoteThumbnail,
                                  loadedPreview]
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(expectedContainers.removeFirst()))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        
        [remoteThumbnail,
         loadedPreview].forEach {
            continuation.yield($0)
        }
        continuation.finish()
        
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(loadedPreview))
        XCTAssertTrue(expectedContainers.isEmpty)
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedPreviewAndSingleColumn_showPreviewAndNoLoading() async throws {
        let initialPreview = ImageContainer(image: Image("folder"), type: .preview)
        let previewContainer = ImageContainer(image: Image("folder.fill"), type: .preview)
        let loadImageAsyncSequence = SingleItemAsyncSequence<any ImageContaining>(item: previewContainer)
            .eraseToAnyAsyncSequence()
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        allViewModel.zoomState.zoom(.in)
        XCTAssertTrue(allViewModel.zoomState.isSingleColumn)
        
        let sut = makeSUT(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailLoader: MockThumbnailLoader(initialImage: initialPreview,
                                                 loadImage: loadImageAsyncSequence)
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(initialPreview))
        
        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true
        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func testIsSelected_notSelectedAndSelect_selected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        sut.isSelected = true
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndNonEditingDuringInit_isNotSelected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        allViewModel.libraryViewModel.selection.photos[0] = photo
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        XCTAssertFalse(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndIsEditingDuringInit_selected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        allViewModel.libraryViewModel.selection.editMode = .active
        allViewModel.libraryViewModel.selection.photos[0] = photo
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndDeselect_deselected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        allViewModel.libraryViewModel.selection.editMode = .active
        allViewModel.libraryViewModel.selection.photos[0] = photo
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        sut.isSelected = false
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_noSelectedAndSelectAll_selected() throws {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        XCTAssertFalse(allViewModel.libraryViewModel.selection.allSelected)
        
        allViewModel.libraryViewModel.selection.allSelected = true
        allViewModel.libraryViewModel.selection.setSelectedPhotos(try testNodes)
        
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndDeselectAll_notSelected() throws {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        
        allViewModel.libraryViewModel.selection.editMode = .active
        allViewModel.libraryViewModel.selection.allSelected = true
        allViewModel.libraryViewModel.selection.setSelectedPhotos(try testNodes)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        XCTAssertTrue(allViewModel.libraryViewModel.selection.allSelected)
        
        let sut = makeSUT(
            photo: photo,
            viewModel: allViewModel
        )
        
        allViewModel.libraryViewModel.selection.allSelected = false
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testShouldShowEditState_editing() {
        let sut = makeSUT(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel)
        sut.editMode = .active
        
        for scaleFactor in PhotoLibraryZoomState.ScaleFactor.allCases {
            sut.currentZoomScaleFactor = scaleFactor
            XCTAssertEqual(sut.shouldShowEditState, scaleFactor != .thirteen)
        }
    }
    
    func testShouldShowEditState_notEditing() {
        let sut = makeSUT(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel)
        sut.editMode = .inactive
        
        for scaleFactor in PhotoLibraryZoomState.ScaleFactor.allCases {
            sut.currentZoomScaleFactor = scaleFactor
            XCTAssertFalse(sut.shouldShowEditState)
        }
    }
    
    func testShouldShowFavorite_whenFavouriteIsTrueAndIncrementalZoomLevelChange_shouldEmitTrueThenFalse() {
        // Arrange
        let sut = makeSUT(photo: NodeEntity(handle: 1, isFavourite: true),
                                     viewModel: allViewModel)
        
        let exp = expectation(description: "Should emit shouldShowFavorite events")
        
        allViewModel.zoomState = PhotoLibraryZoomState(scaleFactor: .one, maximumScaleFactor: .thirteen)
        
        let zoomActions: [ZoomType] = [.out, .out, .out]
        
        var events: [Bool] = []
        let subscription = sut
            .$shouldShowFavorite
            .dropFirst(1)
            .sink(receiveValue: { events.append($0) })
        
        // Act
        zoomActions.forEach { allViewModel.zoomState.zoom($0) }
        
        _  = XCTWaiter.wait(for: [exp], timeout: 2)
        
        subscription.cancel()
        
        // Assert
        let expectedResults = [true, false]
        XCTAssertEqual(events, expectedResults)
    }
    
    func testShouldShowFavorite_whenFavouriteIsTrueAndDecrementalZoomLevelChange_shouldEmitFalseThenTrueThenFalse() {
        // Arrange
        let sut = makeSUT(photo: NodeEntity(handle: 1, isFavourite: true),
                                     viewModel: allViewModel)
        
        let exp = expectation(description: "Should emit 2 shouldShowFavorite events")
        allViewModel.zoomState = PhotoLibraryZoomState(scaleFactor: .thirteen, maximumScaleFactor: .thirteen)

        let zoomActions: [ZoomType] = [.in, .in, .in]
        
        var events: [Bool] = []
        let subscription = sut
            .$shouldShowFavorite
            .dropFirst(2)
            .sink(receiveValue: { events.append($0) })
        
        // Act
        zoomActions.forEach { allViewModel.zoomState.zoom($0) }
        
        _  = XCTWaiter.wait(for: [exp], timeout: 1)

        subscription.cancel()
        
        // Assert"
        let expectedResults = [false, true]
        XCTAssertEqual(events, expectedResults)
    }
    
    func testShouldShowFavorite_whenFavouriteIsFalse_shouldEmitFalse() {
        // Arrange
        let sut = makeSUT(photo: NodeEntity(handle: 1, isFavourite: false),
                                     viewModel: allViewModel)
        
        let exp = expectation(description: "Should emit 1 shouldShowFavorite events")
        
        var events: [Bool] = []
        let subscription = sut
            .$shouldShowFavorite
            .dropFirst()
            .sink(receiveValue: { events.append($0) })
        
        // Act
        _  = XCTWaiter.wait(for: [exp], timeout: 1)
        subscription.cancel()
        
        // Assert"
        let expectedResults = [false]
        XCTAssertEqual(events, expectedResults)
    }
    
    func testSelect_onEditModeNoLimitConfigured_shouldChangeIsSelectedOnCellTap() throws {
        let sut = makeSUT(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel)
        allViewModel.libraryViewModel.selection.editMode = .active
        XCTAssertFalse(sut.isSelected)
        sut.select()
        XCTAssertTrue(sut.isSelected)
    }
    
    func testSelect_onEditModeAndLimitConfigured_shouldChangeIsSelectedOnCellTap() throws {
        let library = try testNodes.toPhotoLibrary(withSortType: .newest, in: .GMT)
        let libraryViewModel = PhotoLibraryContentViewModel(library: library, configuration: PhotoLibraryContentConfiguration(selectLimit: 3))
        libraryViewModel.selectedMode = .all
        
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel)
        )
        libraryViewModel.selection.editMode = .active
        XCTAssertFalse(sut.isSelected)
        sut.select()
        XCTAssertTrue(sut.isSelected)
    }
    
    func testSelect_onEditModeItemNotSelectedAndLimitReached_shouldNotChangeIsSelectedOnCellTap() throws {
        let selectionLimit = 3
        let library = try testNodes.toPhotoLibrary(withSortType: .newest, in: .GMT)
        let libraryViewModel = PhotoLibraryContentViewModel(library: library, configuration: PhotoLibraryContentConfiguration(selectLimit: selectionLimit))
        libraryViewModel.selectedMode = .all
        
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel)
        )
        libraryViewModel.selection.editMode = .active
        XCTAssertFalse(sut.isSelected)
        let photosToSelect = Array(library.allPhotos.filter { $0 != photo }.prefix(selectionLimit))
        libraryViewModel.selection.setSelectedPhotos(photosToSelect)
        sut.select()
        XCTAssertFalse(sut.isSelected)
    }
    
    func testSelect_onIsSelectionDisabled_shouldDisableSelection() throws {
        let library = try testNodes.toPhotoLibrary(withSortType: .newest, in: .GMT)
        let libraryViewModel = PhotoLibraryContentViewModel(library: library)
        libraryViewModel.selectedMode = .all
        libraryViewModel.selection.editMode = .active
        libraryViewModel.selection.isSelectionDisabled = true
        
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel)
        )
        XCTAssertFalse(sut.isSelected)
        sut.select()
        XCTAssertFalse(sut.isSelected)
    }
    
    func testShouldApplyContentOpacity_onEditModeItemIsNotSelectedAndLimitReached_shouldChangeContentOpacity() throws {
        let selectionLimit = 3
        let library = try testNodes.toPhotoLibrary(withSortType: .newest, in: .GMT)
        let libraryViewModel = PhotoLibraryContentViewModel(library: library, configuration: PhotoLibraryContentConfiguration(selectLimit: selectionLimit))
        libraryViewModel.selectedMode = .all
        
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = makeSUT(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel)
        )
        XCTAssertFalse(sut.shouldApplyContentOpacity)
        sut.editMode = .active
        sut.isSelected = false
        libraryViewModel.selection.setSelectedPhotos(Array(try testNodes.suffix(selectionLimit)))
        XCTAssertTrue(sut.shouldApplyContentOpacity)
        sut.editMode = .inactive
        XCTAssertFalse(sut.shouldApplyContentOpacity)
    }
    
    func testMonitorPhotoSensitivityChanges_photoAndNodeUseCaseProvided_shouldUpdateImageContainerWithInitialResultFirst() async throws {
        let photo = NodeEntity(handle: 65, isMarkedSensitive: true)
       
        let imageContainer = ImageContainer(image: Image("folder"), type: .thumbnail)
        let isInheritedSensitivity = false
        let isInheritedSensitivityUpdate = true
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: isInheritedSensitivityUpdate)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockNodeDataUseCase(
            isInheritingSensitivityResult: .success(isInheritedSensitivity),
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        let sut = makeSUT(
            photo: photo,
            thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
            nodeUseCase: nodeUseCase,
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: true])
        )
        
        var expectedImageContainer = [
            imageContainer.toSensitiveImageContaining(isSensitive: isInheritedSensitivity),
            imageContainer.toSensitiveImageContaining(isSensitive: isInheritedSensitivityUpdate)
        ]
        
        let exp = expectation(description: "Should update photo with initial then from monitor")
        exp.expectedFulfillmentCount = expectedImageContainer.count
        
        let subscription = thumbnailContainerUpdates(on: sut) {
            XCTAssertTrue($0.isEqual(expectedImageContainer.removeFirst()))
            exp.fulfill()
        }
        
        let task = Task { await sut.monitorSensitivityChanges() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorPhotoSensitivityChanges_inheritedSensitivityChange_shouldNotUpdateIfImageContainerTheSame() async throws {
        let photo = NodeEntity(handle: 65, isMarkedSensitive: true)
        let imageContainer = SensitiveImageContainer(image: Image("folder"), type: .thumbnail, isSensitive: photo.isMarkedSensitive)
        
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: photo.isMarkedSensitive)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockNodeDataUseCase(
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        
        let sut = makeSUT(photo: photo,
                          thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
                          nodeUseCase: nodeUseCase,
                          featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: true]))
        
        let exp = expectation(description: "Should not update image container")
        exp.isInverted = true
        
        let subscription = thumbnailContainerUpdates(on: sut) { _ in
            exp.fulfill()
        }
        
        let task = Task { await sut.monitorSensitivityChanges() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    func testMonitorPhotoSensitivityChanges_thumbnailContainerPlaceholder_shouldNotUpdateImageContainer() async throws {
        let photo = NodeEntity(handle: 65, isMarkedSensitive: true)
        let imageContainer = ImageContainer(image: Image("folder"), type: .placeholder)
        
        let monitorInheritedSensitivityForNode = SingleItemAsyncSequence(item: photo.isMarkedSensitive)
            .eraseToAnyAsyncThrowingSequence()
        let nodeUseCase = MockNodeDataUseCase(
            monitorInheritedSensitivityForNode: monitorInheritedSensitivityForNode)
        
        let sut = makeSUT(photo: photo,
                          thumbnailLoader: MockThumbnailLoader(initialImage: imageContainer),
                          nodeUseCase: nodeUseCase,
                          featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: true]))
        
        let exp = expectation(description: "Should not update image container")
        exp.isInverted = true
        
        let subscription = thumbnailContainerUpdates(on: sut) { _ in
            exp.fulfill()
        }
        
        let task = Task { await sut.monitorSensitivityChanges() }
        
        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()
        subscription.cancel()
    }
    
    private func makeSUT(
        photo: NodeEntity,
        viewModel: PhotoLibraryModeAllViewModel = PhotoLibraryModeAllViewModel(libraryViewModel: PhotoLibraryContentViewModel(library: PhotoLibrary(photoByYearList: []))),
        thumbnailLoader: some ThumbnailLoaderProtocol = MockThumbnailLoader(),
        nodeUseCase: some NodeUseCaseProtocol = MockNodeDataUseCase(),
        featureFlagProvider: some FeatureFlagProviderProtocol = MockFeatureFlagProvider(list: [:])
    ) -> PhotoCellViewModel {
        PhotoCellViewModel(
            photo: photo,
            viewModel: viewModel,
            thumbnailLoader: thumbnailLoader,
            nodeUseCase: nodeUseCase,
            featureFlagProvider: featureFlagProvider)
    }
    
    private func thumbnailContainerUpdates(on sut: PhotoCellViewModel, action: @escaping (any ImageContaining) -> Void) -> AnyCancellable {
        sut.$thumbnailContainer
            .dropFirst()
            .sink(receiveValue: action)
    }
}
