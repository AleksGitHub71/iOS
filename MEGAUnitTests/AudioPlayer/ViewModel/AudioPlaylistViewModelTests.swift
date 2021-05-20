import XCTest
@testable import MEGA

final class AudioPlaylistViewModelTests: XCTestCase {
    let router = MockAudioPlaylistViewRouter()
    let playerHandler = MockAudioPlayerHandler()
    
    lazy var viewModel = AudioPlaylistViewModel(router: router,
                                                parentNode: MEGANode(),
                                                nodeInfoUseCase: NodeInfoUseCase(nodeInfoRepository: MockNodeInfoRepository()),
                                                playerHandler: playerHandler)
    
    func testAudioPlayerActions() {
        test(viewModel: viewModel, action: .onViewDidLoad, expectedCommands: [.reloadTracks(currentItem: AudioPlayerItem.mockItem, queue: nil), .title(title: "")])
        XCTAssertEqual(playerHandler.addPlayerListener_calledTimes, 1)
        
        test(viewModel: viewModel, action: .move(AudioPlayerItem.mockItem, IndexPath(row: 1, section: 0), MovementDirection.up), expectedCommands: [])
        XCTAssertEqual(playerHandler.onMoveItem_calledTimes, 1)
        
        test(viewModel: viewModel, action: .didSelect(AudioPlayerItem.mockItem), expectedCommands: [.showToolbar])
        
        test(viewModel: viewModel, action: .removeSelectedItems, expectedCommands: [.deselectAll, .hideToolbar])
        XCTAssertEqual(playerHandler.onDeleteItems_calledTimes, 1)
        
        test(viewModel: viewModel, action: .didDeselect(AudioPlayerItem.mockItem), expectedCommands: [.hideToolbar])
        
        test(viewModel: viewModel, action: .deinit, expectedCommands: [])
        XCTAssertEqual(playerHandler.removePlayerListener_calledTimes, 1)
    }
    
    func testRouterActions() {
        test(viewModel: viewModel, action: .dismiss, expectedCommands: [])
        XCTAssertEqual(router.dismiss_calledTimes, 1)
    }
}
