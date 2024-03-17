import MEGADomain
import MEGADomainMock
import MEGASwift
import XCTest

final class MonitorPhotosUseCaseTests: XCTestCase {
    
    func testMonitorPhotos_noFiltersProvided_shouldReturnAllPhotos() async throws {
        let photos = [NodeEntity(name: "test1.jpg", handle: 4, hasThumbnail: true),
                      NodeEntity(name: "test4.mp4", handle: 5, hasThumbnail: false)]
        let photosRepository = MockPhotosRepository(photos: photos)
        let sut = makeSUT(photosRepository: photosRepository)
        
        var iterator = try await sut.monitorPhotos(filterOptions: []).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertEqual(Set(initialPhotos ?? []), Set(photos))
    }
    
    func testMonitorPhotos_onPhotoUpdateWithNoFilters_shouldReturnAllPhotosWithThumbnails() async throws {
        let photos = [NodeEntity(name: "test1.jpg", handle: 4, hasThumbnail: true),
                      NodeEntity(name: "test4.mp4", handle: 5, hasThumbnail: false)]
        let photosRepository = MockPhotosRepository(photosUpdated: makePhotosUpdatedSequenceWithItems(),
                                                    allPhotosCallOrderResult: [.success([]),
                                                                               .success(photos)])
        let sut = makeSUT(photosRepository: photosRepository)
        
        var iterator = try await sut.monitorPhotos(filterOptions: []).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertTrue(initialPhotos?.isEmpty ?? false)
        
        let firstUpdate = await iterator.next()
        XCTAssertEqual(Set(firstUpdate ?? []), Set(photos))
    }
    
    func testMonitorPhotos_allLocationsAndAllMedia_shouldReturnAllPhotosWithThumbnails() async throws {
        let thumbnailPhoto = NodeEntity(name: "test.jpg", handle: 1, hasThumbnail: true)
        let photos = [thumbnailPhoto,
                      NodeEntity(name: "test2.jpg", handle: 4, hasThumbnail: false)]
        let photosRepository = MockPhotosRepository(photos: photos)
        let sut = makeSUT(photosRepository: photosRepository)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.allLocations, .allMedia]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertEqual(initialPhotos, [thumbnailPhoto])
    }
    
    func testMonitorPhotos_onPhotoUpdateWithAllLocations_shouldReturnAllPhotosWithThumbnails() async throws {
        let thumbnailPhoto = NodeEntity(name: "test.jpg", handle: 1, hasThumbnail: true)
        let photosRepository = MockPhotosRepository(photosUpdated: makePhotosUpdatedSequenceWithItems(),
                                                    allPhotosCallOrderResult: [.success([]),
                                                                               .success([thumbnailPhoto])])
                                                          
        let sut = makeSUT(photosRepository: photosRepository)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.allLocations,
                                                                   .allMedia]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertTrue(initialPhotos?.isEmpty ?? false)
        
        let firstUpdate = await iterator.next()
        XCTAssertEqual(firstUpdate, [thumbnailPhoto])
    }
    
    func testMonitorPhotos_cloudDriveAndVideos_shouldReturnOnlyVideosFromCloudDrive() async throws {
        let cameraUploadNode = NodeEntity(handle: 5)
        let thumbnailVideo = NodeEntity(name: "test.mp4", handle: 1, parentHandle: 34, hasThumbnail: true)
        let photos = [thumbnailVideo,
                      NodeEntity(name: "test2.mp4", handle: 4, hasThumbnail: false),
                      NodeEntity(name: "test3.mp4", handle: 4, parentHandle: cameraUploadNode.handle, hasThumbnail: true)
        ]
        let photosRepository = MockPhotosRepository(photos: photos)
        let photoLibraryContainer = PhotoLibraryContainerEntity(
            cameraUploadNode: cameraUploadNode, mediaUploadNode: nil)
        let photoLibraryUseCase = MockPhotoLibraryUseCase(photoLibraryContainer: photoLibraryContainer)
        let sut = makeSUT(photosRepository: photosRepository,
                          photoLibraryUseCase: photoLibraryUseCase)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.cloudDrive,
                                                                   .videos]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertEqual(initialPhotos, [thumbnailVideo])
    }
    
    func testMonitorPhotos_onPhotoUpdateWithCloudDriveAndVideos_shouldReturnOnlyVideosFromCloudDrive() async throws {
        let cameraUploadNode = NodeEntity(handle: 5)
        let thumbnailVideo = NodeEntity(name: "test.mp4", handle: 1, parentHandle: 34, hasThumbnail: true)
        let photosRepository = MockPhotosRepository(photosUpdated: makePhotosUpdatedSequenceWithItems(),
                                                    allPhotosCallOrderResult: [.success([]),
                                                                               .success([thumbnailVideo])])
        let photoLibraryContainer = PhotoLibraryContainerEntity(
            cameraUploadNode: cameraUploadNode, mediaUploadNode: nil)
        let photoLibraryUseCase = MockPhotoLibraryUseCase(photoLibraryContainer: photoLibraryContainer)
        let sut = makeSUT(photosRepository: photosRepository,
                          photoLibraryUseCase: photoLibraryUseCase)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.cloudDrive,
                                                                   .videos]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertTrue(initialPhotos?.isEmpty ?? false)
        
        let firstUpdate = await iterator.next()
        XCTAssertEqual(firstUpdate, [thumbnailVideo])
    }
    
    func testMonitorPhotos_cameraUploadAndImages_shouldReturnOnlyImagesFromCameraUploadAndMediaUploadNode() async throws {
        let cameraUploadNode = NodeEntity(handle: 5)
        let mediaUploadNode = NodeEntity(handle: 66)
        let cameraUploadImage = NodeEntity(name: "test.jpg", handle: 1,
                                           parentHandle: cameraUploadNode.handle, hasThumbnail: true)
        let mediaUploadImage = NodeEntity(name: "test2.png", handle: 87,
                                          parentHandle: mediaUploadNode.handle, hasThumbnail: true)
        let photos = [cameraUploadImage,
                      mediaUploadImage,
                      NodeEntity(name: "test1.mp4", handle: 4, hasThumbnail: false),
                      NodeEntity(name: "test3.jpg", handle: 6, parentHandle: 8, hasThumbnail: true)
        ]
        let photosRepository = MockPhotosRepository(photos: photos)
        let photoLibraryContainer = PhotoLibraryContainerEntity(
            cameraUploadNode: cameraUploadNode, mediaUploadNode: mediaUploadNode)
        let photoLibraryUseCase = MockPhotoLibraryUseCase(photoLibraryContainer: photoLibraryContainer)
        let sut = makeSUT(photosRepository: photosRepository,
                          photoLibraryUseCase: photoLibraryUseCase)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.cameraUploads,
                                                                   .images]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertEqual(Set(initialPhotos ?? []),
                       Set([cameraUploadImage, mediaUploadImage]))
    }
    
    func testMonitorPhotos_onPhotoUpdateWithCameraUploadAndImages_shouldReturnOnlyImagesFromCameraUploadAndMediaUploadNode() async throws {
        let cameraUploadNode = NodeEntity(handle: 5)
        let mediaUploadNode = NodeEntity(handle: 66)
        let cameraUploadImage = NodeEntity(name: "test.jpg", handle: 1,
                                           parentHandle: cameraUploadNode.handle, hasThumbnail: true)
        let mediaUploadImage = NodeEntity(name: "test2.png", handle: 87,
                                          parentHandle: mediaUploadNode.handle, hasThumbnail: true)
        let photosRepository = MockPhotosRepository(photosUpdated: makePhotosUpdatedSequenceWithItems(),
                                                    allPhotosCallOrderResult: [.success([]),
                                                                               .success([cameraUploadImage, mediaUploadImage])])
        let photoLibraryContainer = PhotoLibraryContainerEntity(
            cameraUploadNode: cameraUploadNode, mediaUploadNode: mediaUploadNode)
        let photoLibraryUseCase = MockPhotoLibraryUseCase(photoLibraryContainer: photoLibraryContainer)
        let sut = makeSUT(photosRepository: photosRepository,
                          photoLibraryUseCase: photoLibraryUseCase)
        
        var iterator = try await sut.monitorPhotos(filterOptions: [.cameraUploads,
                                                                   .images]).makeAsyncIterator()
        
        let initialPhotos = await iterator.next()
        XCTAssertTrue(initialPhotos?.isEmpty ?? false)
        
        let firstUpdate = await iterator.next()
        XCTAssertEqual(Set(firstUpdate ?? []),
                       Set([cameraUploadImage, mediaUploadImage]))
    }
    
    // MARK: Private
    
    private func makeSUT(
        photosRepository: some PhotosRepositoryProtocol = MockPhotosRepository(),
        photoLibraryUseCase: some PhotoLibraryUseCaseProtocol = MockPhotoLibraryUseCase()
    ) -> MonitorPhotosUseCase {
        MonitorPhotosUseCase(photosRepository: photosRepository,
                             photoLibraryUseCase: photoLibraryUseCase)
    }
    
    private func makePhotosUpdatedSequenceWithItems() -> AnyAsyncSequence<[NodeEntity]> {
        SingleItemAsyncSequence(item: [NodeEntity(name: "test99.jpg", handle: 999, hasThumbnail: true)])
            .eraseToAnyAsyncSequence()
    }
}
