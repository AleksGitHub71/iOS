import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAFoundation
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
    
    func testInit_defaultValue() throws {
        let sut = PhotoCellViewModel(photo: NodeEntity(name: "0.jpg", handle: 0),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image(FileTypes().fileType(forFileName: "0.jpg")), type: .placeholder)))
        XCTAssertEqual(sut.duration, "00:00")
        XCTAssertEqual(sut.isVideo, false)
        XCTAssertEqual(sut.currentZoomScaleFactor, .three)
        XCTAssertEqual(sut.isSelected, false)
    }
    
    func testInit_videoNode_isVideoIsTrueAndDurationIsApplied() {
        let duration = 120
        let sut = PhotoCellViewModel(photo: NodeEntity(name: "0.jpg", handle: 0, duration: duration, mediaType: .video),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        XCTAssertEqual(sut.isVideo, true)
        XCTAssertEqual(sut.duration, "02:00")
    }
    
    func testLoadThumbnail_zoomInAndHasCachedThumbnail_onlyLoadPreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remoteURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remoteURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(URLImageContainer(imageURL: remoteURL, type: .preview)))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: remoteURL, type: .preview)))
        
        task.cancel()
    }
    
    func testLoadThumbnail_zoomOut_noLoadLocalThumbnailAndRemotePreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remoteURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remoteURL, type: .preview)))
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
    
    func testLoadThumbnail_hasCachedThumbnail_showThumbnailUponInit() async throws {
        let image = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isFileCreated = FileManager.default.createFile(atPath: url.path, contents: image.pngData())
        XCTAssertTrue(isFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: url, type: .thumbnail)])
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: url, type: .thumbnail)))
    }
    
    func testLoadThumbnail_hasDifferentThumbnailAndLoadThumbnail_noLoading() async throws {
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remoteURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(loadThumbnailResult: .success(ThumbnailEntity(url: remoteURL, type: .thumbnail)))
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
    
    func testLoadThumbnail_noThumbnails_showPlaceholder() async throws {
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image("image"), type: .placeholder)))
        
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
    
    func testLoadThumbnail_noCachedThumbnailAndNonSingleColumn_loadThumbnail() throws {
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image("image"), type: .placeholder)))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(URLImageContainer(imageURL: remoteThumbnailURL, type: .thumbnail)))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        XCTAssertEqual(sut.currentZoomScaleFactor, .three)
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: remoteThumbnailURL, type: .thumbnail)))
        task.cancel()
    }
    
    func testLoadThumbnail_noCachedThumbnailAndZoomInToSingleColumn_loadBothThumbnailAndPreview() throws {
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )

        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(ImageContainer(image: Image("image"), type: .placeholder)))
        
        let exp = expectation(description: "thumbnail is changed")
        exp.expectedFulfillmentCount = 2
        var expectedContainers = [URLImageContainer(imageURL: remoteThumbnailURL, type: .thumbnail),
                                  URLImageContainer(imageURL: remotePreviewURL, type: .preview)]
        
        sut.$thumbnailContainer
            .dropFirst(1)
            .sink { container in
                XCTAssertTrue(container.isEqual(expectedContainers.removeFirst()))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: remotePreviewURL, type: .preview)))
        XCTAssertTrue(expectedContainers.isEmpty)
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndNonSingleColumnAndSameRemoteThumbnail_noLoading() async throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: localURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
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
    
    func testLoadThumbnail_hasCachedThumbnailAndNonSingleColumnAndDifferentRemoteThumbnail_noLoading() async throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
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
    
    func testLoadThumbnail_hasCachedThumbnailAndZoomInToSingleColumnAndSameRemoteThumbnail_onlyLoadPreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: localURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(URLImageContainer(imageURL: remotePreviewURL, type: .preview)))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: remotePreviewURL, type: .preview)))
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndZoomInToSingleColumnAndDifferentRemoteThumbnail_loadBothThumbnailAndPreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
        let exp = expectation(description: "thumbnail is changed")
        exp.expectedFulfillmentCount = 2
        var expectedContainers = [URLImageContainer(imageURL: remoteThumbnailURL, type: .thumbnail),
                                  URLImageContainer(imageURL: remotePreviewURL, type: .preview)]
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(expectedContainers.removeFirst()))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: remotePreviewURL, type: .preview)))
        XCTAssertTrue(expectedContainers.isEmpty)
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndPreviewAndZoomInToSingleColumnAndSameRemoteThumbnailAndPreview_onlyLoadCachedPreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let previewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: previewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail),
                                                                      ThumbnailEntity(url: previewURL, type: .preview)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: localURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: previewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(URLImageContainer(imageURL: previewURL, type: .preview)))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: previewURL, type: .preview)))
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedThumbnailAndPreviewAndZoomInToSingleColumnAndDifferentRemoteThumbnailAndPreview_onlyLoadCachedPreview() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let localPreviewImage = try XCTUnwrap(UIImage(systemName: "doc"))
        let localPreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalPreviewFileCreated = FileManager.default.createFile(atPath: localPreviewURL.path, contents: localPreviewImage.pngData())
        XCTAssertTrue(isLocalPreviewFileCreated)
        
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .thumbnail),
                                                                      ThumbnailEntity(url: localPreviewURL, type: .preview)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .thumbnail)))
        
        let exp = expectation(description: "thumbnail is changed")
        sut.$thumbnailContainer
            .dropFirst()
            .sink { container in
                XCTAssertTrue(container.isEqual(URLImageContainer(imageURL: localPreviewURL, type: .preview)))
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        allViewModel.zoomState.zoom(.in)
        
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sut.currentZoomScaleFactor, .one)
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localPreviewURL, type: .preview)))
        task.cancel()
    }
    
    func testLoadThumbnail_hasCachedPreviewAndSingleColumn_showPreviewAndNoLoading() async throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        allViewModel.zoomState.zoom(.in)
        XCTAssertTrue(allViewModel.zoomState.isSingleColumn)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localURL, type: .preview)],
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localURL, type: .preview)))
        
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
    
    func testLoadThumbnail_hasCachedPreviewAndSingleColumnAndHasDifferentCachedPreview_noLoading() async throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let newLocalImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let newLocalURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isNewLocalFileCreated = FileManager.default.createFile(atPath: newLocalURL.path, contents: newLocalImage.pngData())
        XCTAssertTrue(isNewLocalFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.circle"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        allViewModel.zoomState.zoom(.in)
        XCTAssertTrue(allViewModel.zoomState.isSingleColumn)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: newLocalURL, type: .preview)],
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        sut.thumbnailContainer = try XCTUnwrap(URLImageContainer(imageURL: localURL, type: .preview))
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
    
    func testLoadThumbnail_hasCachedThumbnailAndPreviewAndSingleColumn_showPreviewAndNoLoading() throws {
        let localImage = try XCTUnwrap(UIImage(systemName: "folder"))
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalFileCreated = FileManager.default.createFile(atPath: localURL.path, contents: localImage.pngData())
        XCTAssertTrue(isLocalFileCreated)
        
        let localPreviewImage = try XCTUnwrap(UIImage(systemName: "doc"))
        let localPreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isLocalPreviewFileCreated = FileManager.default.createFile(atPath: localPreviewURL.path, contents: localPreviewImage.pngData())
        XCTAssertTrue(isLocalPreviewFileCreated)
        
        let remoteThumbnailImage = try XCTUnwrap(UIImage(systemName: "eraser"))
        let remoteThumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteThumbnailFileCreated = FileManager.default.createFile(atPath: remoteThumbnailURL.path, contents: remoteThumbnailImage.pngData())
        XCTAssertTrue(isRemoteThumbnailFileCreated)
        
        let remoteImage = try XCTUnwrap(UIImage(systemName: "folder.fill"))
        let remotePreviewURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        let isRemoteFileCreated = FileManager.default.createFile(atPath: remotePreviewURL.path, contents: remoteImage.pngData())
        XCTAssertTrue(isRemoteFileCreated)
        
        allViewModel.zoomState.zoom(.in)
        XCTAssertTrue(allViewModel.zoomState.isSingleColumn)
        
        let sut = PhotoCellViewModel(
            photo: NodeEntity(name: "0.jpg", handle: 0),
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase(cachedThumbnails: [ThumbnailEntity(url: localPreviewURL, type: .preview),
                                                                      ThumbnailEntity(url: localURL, type: .thumbnail)],
                                                   loadThumbnailResult: .success(ThumbnailEntity(url: remoteThumbnailURL, type: .thumbnail)),
                                                   loadPreviewResult: .success(ThumbnailEntity(url: remotePreviewURL, type: .preview)))
        )
        
        let task = Task { await sut.startLoadingThumbnail() }

        XCTAssertTrue(sut.thumbnailContainer.isEqual(URLImageContainer(imageURL: localPreviewURL, type: .preview)))
        
        let exp = expectation(description: "thumbnail should not be changed")
        exp.isInverted = true

        sut.$thumbnailContainer
            .dropFirst()
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        wait(for: [exp], timeout: 1.0)
        task.cancel()
    }
    
    func testIsSelected_notSelectedAndSelect_selected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
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
        
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
        )
        XCTAssertFalse(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndIsEditingDuringInit_selected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        allViewModel.libraryViewModel.selection.editMode = .active
        allViewModel.libraryViewModel.selection.photos[0] = photo
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
        )
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_selectedAndDeselect_deselected() {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        allViewModel.libraryViewModel.selection.editMode = .active
        allViewModel.libraryViewModel.selection.photos[0] = photo
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
        )
        XCTAssertTrue(sut.isSelected)
        XCTAssertTrue(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
        
        sut.isSelected = false
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testIsSelected_noSelectedAndSelectAll_selected() throws {
        let photo = NodeEntity(name: "0.jpg", handle: 0)
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
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
        
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: allViewModel,
            thumbnailUseCase: MockThumbnailUseCase()
        )
        
        allViewModel.libraryViewModel.selection.allSelected = false
        XCTAssertFalse(sut.isSelected)
        XCTAssertFalse(allViewModel.libraryViewModel.selection.isPhotoSelected(photo))
    }
    
    func testShouldShowEditState_editing() {
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        sut.editMode = .active
        
        for scaleFactor in PhotoLibraryZoomState.ScaleFactor.allCases {
            sut.currentZoomScaleFactor = scaleFactor
            XCTAssertEqual(sut.shouldShowEditState, scaleFactor != .thirteen)
        }
    }
    
    func testShouldShowEditState_notEditing() {
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        sut.editMode = .inactive
        
        for scaleFactor in PhotoLibraryZoomState.ScaleFactor.allCases {
            sut.currentZoomScaleFactor = scaleFactor
            XCTAssertFalse(sut.shouldShowEditState)
        }
    }
    
    func testShouldShowFavorite_whenFavouriteIsTrueAndIncrementalZoomLevelChange_shouldEmitTrueThenFalse() {
        // Arrange
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1, isFavourite: true),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        
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
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1, isFavourite: true),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        
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
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1, isFavourite: false),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
        
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
        let sut = PhotoCellViewModel(photo: NodeEntity(handle: 1),
                                     viewModel: allViewModel,
                                     thumbnailUseCase: MockThumbnailUseCase())
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
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel),
            thumbnailUseCase: MockThumbnailUseCase()
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
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel),
            thumbnailUseCase: MockThumbnailUseCase()
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
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel),
            thumbnailUseCase: MockThumbnailUseCase()
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
        let sut = PhotoCellViewModel(
            photo: photo,
            viewModel: PhotoLibraryModeAllGridViewModel(libraryViewModel: libraryViewModel),
            thumbnailUseCase: MockThumbnailUseCase()
        )
        XCTAssertFalse(sut.shouldApplyContentOpacity)
        sut.editMode = .active
        sut.isSelected = false
        libraryViewModel.selection.setSelectedPhotos(Array(try testNodes.suffix(selectionLimit)))
        XCTAssertTrue(sut.shouldApplyContentOpacity)
        sut.editMode = .inactive
        XCTAssertFalse(sut.shouldApplyContentOpacity)
    }
}
