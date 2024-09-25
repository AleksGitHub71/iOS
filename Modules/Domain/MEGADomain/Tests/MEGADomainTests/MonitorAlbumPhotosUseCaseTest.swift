import MEGADomain
import MEGADomainMock
import MEGASwift
import XCTest

final class MonitorAlbumPhotosUseCaseTests: XCTestCase {
    func testMonitorPhotos_userAlbum_shouldReturnUserAlbumPhotos() async throws {
        let photos = [AlbumPhotoEntity(photo: .init(handle: 3)), AlbumPhotoEntity(photo: .init(handle: 7))]
        let monitorSystemAlbumPhotosUseCase = MockMonitorSystemAlbumPhotosUseCase()
        let sequence = SingleItemAsyncSequence(item: photos)
        let testCases = [
            (isHiddenEnabled: false, showHiddenNodes: false, excludeSensitives: false),
            (isHiddenEnabled: false, showHiddenNodes: true, excludeSensitives: false),
            (isHiddenEnabled: true, showHiddenNodes: false, excludeSensitives: true),
            (isHiddenEnabled: true, showHiddenNodes: true, excludeSensitives: false)
        ]
       
        for (isHiddenEnabled, showHiddenNodes, excludeSensitives) in testCases {
            let monitorUserAlbumPhotosUseCase = MockMonitorUserAlbumPhotosUseCase(
                monitorUserAlbumPhotosAsyncSequence: sequence.eraseToAnyAsyncSequence())
            let contentConsumptionUserAttributeUseCase = MockContentConsumptionUserAttributeUseCase(
                sensitiveNodesUserAttributeEntity: .init(onboarded: false, showHiddenNodes: showHiddenNodes))
            let sut = makeSUT(
                monitorSystemAlbumPhotosUseCase: monitorSystemAlbumPhotosUseCase,
                monitorUserAlbumPhotosUseCase: monitorUserAlbumPhotosUseCase,
                contentConsumptionUserAttributeUseCase: contentConsumptionUserAttributeUseCase,
                hiddenNodesFeatureFlagEnabled: isHiddenEnabled)
            
            var iterator = await sut.monitorPhotos(for: AlbumEntity(id: 1, type: .user))
                .makeAsyncIterator()
            
            let result = try await iterator.next()?.get()
            
            XCTAssertEqual(result, photos)
            XCTAssertTrue(monitorSystemAlbumPhotosUseCase.invocations.isEmpty)
            XCTAssertEqual(monitorUserAlbumPhotosUseCase.invocations,
                           [.userAlbumPhotos(excludeSensitives: excludeSensitives)])
        }
    }
    
    func testMonitorPhotos_systemAlbum_shouldReturnAlbumPhotos() async throws {
        let photos = [NodeEntity(handle: 1), NodeEntity(handle: 2)]
        let monitorUserAlbumPhotosUseCase = MockMonitorUserAlbumPhotosUseCase()
        let sequence = SingleItemAsyncSequence<Result<[NodeEntity], any Error>>(item: .success(photos))
        let testCases = [
            (albumType: AlbumEntityType.favourite, isHiddenEnabled: false, showHiddenNodes: false, excludeSensitives: false),
            (albumType: AlbumEntityType.raw, isHiddenEnabled: false, showHiddenNodes: true, excludeSensitives: false),
            (albumType: AlbumEntityType.gif, isHiddenEnabled: true, showHiddenNodes: false, excludeSensitives: true),
            (albumType: AlbumEntityType.favourite, isHiddenEnabled: true, showHiddenNodes: true, excludeSensitives: false)
        ]
       
        for (albumType, isHiddenEnabled, showHiddenNodes, excludeSensitives) in testCases {
            let monitorSystemAlbumPhotosUseCase = MockMonitorSystemAlbumPhotosUseCase(
                monitorPhotosAsyncSequence: sequence.eraseToAnyAsyncSequence())
            let contentConsumptionUserAttributeUseCase = MockContentConsumptionUserAttributeUseCase(
                sensitiveNodesUserAttributeEntity: .init(onboarded: false, showHiddenNodes: showHiddenNodes))
            let sut = makeSUT(
                monitorSystemAlbumPhotosUseCase: monitorSystemAlbumPhotosUseCase,
                monitorUserAlbumPhotosUseCase: monitorUserAlbumPhotosUseCase,
                contentConsumptionUserAttributeUseCase: contentConsumptionUserAttributeUseCase,
                hiddenNodesFeatureFlagEnabled: isHiddenEnabled)
            
            var iterator = await sut.monitorPhotos(for: AlbumEntity(id: 1, type: albumType))
                .makeAsyncIterator()
            
            let result = try await iterator.next()?.get().map(\.photo)
            
            XCTAssertEqual(result, photos)
            XCTAssertEqual(monitorSystemAlbumPhotosUseCase.invocations,
                           [.monitorPhotos(albumType: albumType, excludeSensitive: excludeSensitives)])
            XCTAssertTrue(monitorUserAlbumPhotosUseCase.invocations.isEmpty)
        }
    }
    
    func testMonitorPhotos_systemAlbumThrows_shouldSetFailure() async throws {
        let failure = NodeErrorEntity.nodeNotFound
        let sequence = SingleItemAsyncSequence<Result<[NodeEntity], any Error>>(
            item: .failure(failure))
       
        let monitorSystemAlbumPhotosUseCase = MockMonitorSystemAlbumPhotosUseCase(
            monitorPhotosAsyncSequence: sequence.eraseToAnyAsyncSequence())
        let sut = makeSUT(
            monitorSystemAlbumPhotosUseCase: monitorSystemAlbumPhotosUseCase)
        
        var iterator = await sut.monitorPhotos(for: AlbumEntity(id: 1, type: .favourite))
            .makeAsyncIterator()
        
        await XCTAsyncAssertThrowsError(try await iterator.next()?.get()) { errorThrown in
            XCTAssertEqual(errorThrown as? NodeErrorEntity, failure)
        }
    }
    
    private func makeSUT(
        monitorSystemAlbumPhotosUseCase: some MonitorSystemAlbumPhotosUseCaseProtocol = MockMonitorSystemAlbumPhotosUseCase(),
        monitorUserAlbumPhotosUseCase: some MonitorUserAlbumPhotosUseCaseProtocol = MockMonitorUserAlbumPhotosUseCase(),
        contentConsumptionUserAttributeUseCase: some ContentConsumptionUserAttributeUseCaseProtocol = MockContentConsumptionUserAttributeUseCase(),
        hiddenNodesFeatureFlagEnabled: Bool = false
    ) -> MonitorAlbumPhotosUseCase {
        MonitorAlbumPhotosUseCase(
            monitorSystemAlbumPhotosUseCase: monitorSystemAlbumPhotosUseCase,
            monitorUserAlbumPhotosUseCase: monitorUserAlbumPhotosUseCase,
            contentConsumptionUserAttributeUseCase: contentConsumptionUserAttributeUseCase,
            hiddenNodesFeatureFlagEnabled: { hiddenNodesFeatureFlagEnabled })
    }
}
