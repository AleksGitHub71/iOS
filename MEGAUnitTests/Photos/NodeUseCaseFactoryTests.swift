@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGASDKRepo
import XCTest

final class NodeUseCaseFactoryTests: XCTestCase {

    func testMakeNodeUseCase_hiddenNodesOff_shouldReturnNil() {
        let remoteFeatureFlagUseCase = MockRemoteFeatureFlagUseCase(list: [.hiddenNodes: false])
        let nodeUseCase = NodeUseCaseFactory.makeNodeUseCase(for: .library, remoteFeatureFlagUseCase: remoteFeatureFlagUseCase)
        
        XCTAssertNil(nodeUseCase)
    }
    
    func testMakeNodeUseCase_albumAndMediaLinkContentModes_shouldReturnNil() {
        [PhotoLibraryContentMode.albumLink, .mediaDiscoveryFolderLink].enumerated().forEach {
            let remoteFeatureFlagUseCase = MockRemoteFeatureFlagUseCase(list: [.hiddenNodes: true])
            let nodeUseCase = NodeUseCaseFactory.makeNodeUseCase(for: $1,
                                                                 remoteFeatureFlagUseCase: remoteFeatureFlagUseCase)
            
            XCTAssertNil(nodeUseCase, "Failed at index: \($0) for value: \($1)")
        }
    }
    
    func testMakeNodeUseCase_nonLinkContentModes_shouldReturnNodeUseCase() {
        [PhotoLibraryContentMode.library, .album, .mediaDiscovery].enumerated().forEach {
            let remoteFeatureFlagUseCase = MockRemoteFeatureFlagUseCase(list: [.hiddenNodes: true])
            let nodeUseCase = NodeUseCaseFactory.makeNodeUseCase(for: $1,
                                                                 remoteFeatureFlagUseCase: remoteFeatureFlagUseCase)
             
             XCTAssertTrue(nodeUseCase is NodeUseCase<NodeDataRepository, NodeValidationRepository, NodeRepository>,
                           "Failed at index: \($0) for value: \($1)")
         }
    }
}
