import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import XCTest

final class NodeTableViewCellViewModelTests: XCTestCase {
    
    func testHasThumbnail_whenNodeCountIsOne_shouldReturnNodeHasThumbnailValue() {
        for hasThumbnail in [true, false] {
            let nodes = [
                NodeEntity(handle: 1, hasThumbnail: hasThumbnail)
            ]
            
            let viewModel = sut(nodes: nodes)
            
            XCTAssertEqual(viewModel.hasThumbnail, hasThumbnail)
        }
    }
    
    func testHasThumbnail_whenNodeCountIsGreaterThanOne_shouldReturnFalse() {
        let nodes = [
            NodeEntity(handle: 1, hasThumbnail: true),
            NodeEntity(handle: 2, hasThumbnail: true)
        ]
        let viewModel = sut(nodes: nodes)
        
        XCTAssertFalse(viewModel.hasThumbnail)
    }
    
    func testConfigureCell_whenFeatureFlagOnAndNodeIsSensitive_shouldSetIsSensitiveTrue() async {
        let nodes = [
            NodeEntity(handle: 1, isMarkedSensitive: true)
        ]
        let viewModel = sut(
            nodes: nodes,
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(false)),
            featureFlags: [.hiddenNodes: true]
            )
        
        await viewModel.configureCell().value

        let expectation = expectation(description: "viewModel.isSensitive should return value")
        let subscription = viewModel.$isSensitive
            .first { $0 }
            .sink { isSensitive in
                XCTAssertTrue(isSensitive)
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 1)
        
        subscription.cancel()
    }
        
    func testConfigureCell_whenFeatureFlagOffAndNodeIsSensitive_shouldSetIsSensitiveFalse() async {
        let nodes = [
            NodeEntity(handle: 1, isMarkedSensitive: true)
        ]
        let viewModel = sut(
            nodes: nodes,
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(false)),
            featureFlags: [.hiddenNodes: false]
        )
        
        await viewModel.configureCell().value

        let expectation = expectation(description: "viewModel.isSensitive should return value")
        let subscription = viewModel.$isSensitive
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .first { !$0 }
            .sink { isSensitive in
                XCTAssertFalse(isSensitive)
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 1)
        
        subscription.cancel()
    }
    
    func testConfigureCell_whenFeatureFlagOnAndNodeInheritedSensitivity_shouldSetIsSensitiveTrue() async {
        let nodes = [
            NodeEntity(handle: 1, isMarkedSensitive: false)
        ]
        let viewModel = sut(
            nodes: nodes,
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            featureFlags: [.hiddenNodes: true]
            )
        
        await viewModel.configureCell().value

        let expectation = expectation(description: "viewModel.isSensitive should return value")
        let subscription = viewModel.$isSensitive
            .first { $0 }
            .sink { isSensitive in
                XCTAssertTrue(isSensitive)
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 1)
        
        subscription.cancel()
    }
        
    func testConfigureCell_whenFeatureFlagOffAndNodeInheritedSensitivity_shouldSetIsSensitiveFalse() async {
        let nodes = [
            NodeEntity(handle: 1, isMarkedSensitive: false)
        ]
        let viewModel = sut(
            nodes: nodes,
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            featureFlags: [.hiddenNodes: false]
        )

        await viewModel.configureCell().value
        
        let expectation = expectation(description: "viewModel.isSensitive should return value")
        let subscription = viewModel.$isSensitive
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .first { !$0 }
            .sink { isSensitive in
                XCTAssertFalse(isSensitive)
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 1)
        
        subscription.cancel()
    }
    
    func testConfigureCell_whenFeatureFlagOnAndNodesCountGreaterOne_shouldSetIsSensitiveFalse() async {
        let nodes = [
            NodeEntity(handle: 1, isMarkedSensitive: true),
            NodeEntity(handle: 2, isMarkedSensitive: true)
        ]
        let viewModel = sut(
            nodes: nodes,
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            featureFlags: [.hiddenNodes: true]
            )
        
        await viewModel.configureCell().value

        let expectation = expectation(description: "viewModel.isSensitive should return value")
        let subscription = viewModel.$isSensitive
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .first { !$0 }
            .sink { isSensitive in
                XCTAssertFalse(isSensitive)
                expectation.fulfill()
            }
        
        await fulfillment(of: [expectation], timeout: 1)
        
        subscription.cancel()
    }
        
    func testConfigureCell_withAllVariationsOfShouldApplySensitiveBehaviour_shouldSetExpectedResult() async {
        for await shouldApplySensitiveBehaviour in [true, false].async {
            
            let viewModel = sut(
                nodes: [.init(handle: 1, isMarkedSensitive: true)],
                shouldApplySensitiveBehaviour: shouldApplySensitiveBehaviour,
                nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
                featureFlags: [.hiddenNodes: true]
            )
            
            await viewModel.configureCell().value

            let expectation = expectation(description: "viewModel.isSensitive should return value")
            let subscription = viewModel.$isSensitive
                .debounce(for: 0.5, scheduler: DispatchQueue.main)
                .sink { isSensitive in
                    XCTAssertEqual(isSensitive, shouldApplySensitiveBehaviour, "\(shouldApplySensitiveBehaviour ? "should" : "shouldn't") support isSensitive")
                    expectation.fulfill()
                }
            
            await fulfillment(of: [expectation], timeout: 1)
            
            subscription.cancel()
        }
    }
    
    func testThumbnailLoading_whenNodeHasValidThumbnail_shouldReturnCachedImage() async throws {
        let imageUrl = try makeImageURL()
        let node = NodeEntity(handle: 1, hasThumbnail: true, isMarkedSensitive: true)

        let viewModel = sut(
            nodes: [node],
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            thumbnailUseCase: MockThumbnailUseCase(
                loadThumbnailResult: .success(.init(url: imageUrl, type: .thumbnail))))
        
        await viewModel.configureCell().value
        
        let result = viewModel.thumbnail?.pngData()
        let expected = UIImage(contentsOfFile: imageUrl.path())?.pngData()
        
        XCTAssertEqual(result, expected)
    }
    
    func testThumbnailLoading_whenNodeHasThumbnailAndFailsToLoad_shouldReturnFileTypeImage() async throws {
        let imageData = try XCTUnwrap(UIImage(systemName: "heart.fill")?.pngData())
        let node = NodeEntity(nodeType: .file, name: "test.txt", handle: 1, hasThumbnail: true, isMarkedSensitive: true)
        
        let nodeIconUseCase = MockNodeIconUsecase(stubbedIconData: imageData)
        let viewModel = sut(
            nodes: [node],
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            nodeIconUseCase: nodeIconUseCase)
        
        await viewModel.configureCell().value
        
        let result = viewModel.thumbnail?.pngData()
        
        XCTAssertEqual(result?.hashValue, imageData.hashValue)
    }
    
    func testThumbnailLoading_whenNodeHasThumbnailAndIsRecentsFlavour_shouldReturnFileTypeImageOnly() async throws {
        let imageData = try XCTUnwrap(UIImage(systemName: "heart.fill")?.pngData())
        let node = NodeEntity(nodeType: .file, name: "test.txt", handle: 1, hasThumbnail: true)
        
        let nodeIconUseCase = MockNodeIconUsecase(stubbedIconData: imageData)
        let viewModel = sut(
            nodes: [node],
            shouldApplySensitiveBehaviour: true,
            nodeUseCase: MockNodeDataUseCase(isInheritingSensitivityResult: .success(true)),
            nodeIconUseCase: nodeIconUseCase)
        
        await viewModel.configureCell().value
        
        let result = viewModel.thumbnail?.pngData()
        
        XCTAssertEqual(result?.hashValue, imageData.hashValue)
    }
}

extension NodeTableViewCellViewModelTests {
    func sut(nodes: [NodeEntity] = [],
             shouldApplySensitiveBehaviour: Bool = true,
             nodeUseCase: some NodeUseCaseProtocol = MockNodeDataUseCase(),
             nodeIconUseCase: some NodeIconUsecaseProtocol = MockNodeIconUsecase(stubbedIconData: Data()),
             thumbnailUseCase: some ThumbnailUseCaseProtocol = MockThumbnailUseCase(),
             featureFlags: [FeatureFlagKey: Bool] = [.hiddenNodes: false]) -> NodeTableViewCellViewModel {
        NodeTableViewCellViewModel(
            nodes: nodes,
            shouldApplySensitiveBehaviour: shouldApplySensitiveBehaviour,
            nodeUseCase: nodeUseCase,
            thumbnailUseCase: thumbnailUseCase,
            nodeIconUseCase: nodeIconUseCase,
            featureFlagProvider: MockFeatureFlagProvider(list: featureFlags))
    }
}
