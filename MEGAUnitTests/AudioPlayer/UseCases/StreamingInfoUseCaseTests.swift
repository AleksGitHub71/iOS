@testable import MEGA
import MEGADomain
import XCTest

final class StreamingInfoUseCaseTests: XCTestCase {
    let nodeStreamingInfoSuccessRepository = MockStreamingInfoRepository(result: .success(()))
    let nodeStreamingInfoFailureRepository = MockStreamingInfoRepository(result: .failure(.generic))
    
    func testGetInfoFromFolderLinkNode() throws {
        let folderLinkItem = try XCTUnwrap(nodeStreamingInfoSuccessRepository.info(fromFolderLinkNode: MEGANode()))
        let mockItem = try XCTUnwrap(AudioPlayerItem.mockItem)
        
        XCTAssertEqual(folderLinkItem.url, mockItem.url)
        XCTAssertNil(nodeStreamingInfoFailureRepository.info(fromFolderLinkNode: MEGANode()))
    }
    
    func testGetPathFromNode() throws {
        let nodePath = try XCTUnwrap(nodeStreamingInfoSuccessRepository.path(fromNode: MEGANode()))
        let mockNodePath = try XCTUnwrap(AudioPlayerItem.mockItem.url)
        
        XCTAssertEqual(nodePath, mockNodePath)
        XCTAssertNil(nodeStreamingInfoFailureRepository.path(fromNode: MEGANode()))
    }
}
