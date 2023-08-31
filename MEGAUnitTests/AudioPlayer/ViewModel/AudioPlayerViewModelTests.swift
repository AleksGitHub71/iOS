@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGASDKRepoMock
import XCTest

final class AudioPlayerViewModelTests: XCTestCase {
    
    func testPlaybackActions() {
        let (onlineSUT, _, playerHandler, _, _, _) = makeOnlineSUT()
        
        test(viewModel: onlineSUT, action: .onViewDidLoad, expectedCommands: [.showLoading(true),
                                                                              .configureFileLinkPlayer(title: "Track 5", subtitle: Strings.Localizable.fileLink),
                                                                              .updateShuffle(status: playerHandler.isShuffleEnabled()),
                                                                              .updateSpeed(mode: .normal)], timeout: 0.5)
        
        test(viewModel: onlineSUT, action: .updateCurrentTime(percentage: 0.2), expectedCommands: [])
        XCTAssertEqual(playerHandler.updateProgressCompleted_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .progressDragEventBegan, expectedCommands: [])
        XCTAssertEqual(playerHandler.progressDragEventBeganCalledTimes, 1)
        
        test(viewModel: onlineSUT, action: .progressDragEventEnded, expectedCommands: [])
        XCTAssertEqual(playerHandler.progressDragEventEndedCalledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onShuffle(active: true), expectedCommands: [])
        XCTAssertEqual(playerHandler.onShuffle_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onPlayPause, expectedCommands: [])
        XCTAssertEqual(playerHandler.togglePlay_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onGoBackward, expectedCommands: [])
        XCTAssertEqual(playerHandler.goBackward_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onPrevious, expectedCommands: [])
        XCTAssertEqual(playerHandler.playPrevious_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onNext, expectedCommands: [])
        XCTAssertEqual(playerHandler.playNext_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onGoForward, expectedCommands: [])
        XCTAssertEqual(playerHandler.goForward_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onRepeatPressed, expectedCommands: [.updateRepeat(status: .loop)])
        XCTAssertEqual(playerHandler.onRepeatAll_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onRepeatPressed, expectedCommands: [.updateRepeat(status: .repeatOne)])
        XCTAssertEqual(playerHandler.onRepeatOne_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onRepeatPressed, expectedCommands: [.updateRepeat(status: .none)])
        XCTAssertEqual(playerHandler.onRepeatDisabled_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .deinit, expectedCommands: [])
        XCTAssertEqual(playerHandler.removePlayerListener_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onChangeSpeedModePressed, expectedCommands: [.updateSpeed(mode: .oneAndAHalf)])
        XCTAssertEqual(playerHandler.changePlayerRate_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .onChangeSpeedModePressed, expectedCommands: [.updateSpeed(mode: .double)])
        XCTAssertEqual(playerHandler.changePlayerRate_calledTimes, 2)
        
        test(viewModel: onlineSUT, action: .onChangeSpeedModePressed, expectedCommands: [.updateSpeed(mode: .half)])
        XCTAssertEqual(playerHandler.changePlayerRate_calledTimes, 3)
        
        test(viewModel: onlineSUT, action: .onChangeSpeedModePressed, expectedCommands: [.updateSpeed(mode: .normal)])
        XCTAssertEqual(playerHandler.changePlayerRate_calledTimes, 4)
    }
    
    func testRouterActions() {
        let router = MockAudioPlayerViewRouter()
        let (onlineSUT, _, _, _, _, _) = makeOnlineSUT(router: router)
        let (offlineSUT, _) = makeOfflineSUT(router: router)
        
        test(viewModel: onlineSUT, action: .dismiss, expectedCommands: [])
        XCTAssertEqual(router.dismiss_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .showPlaylist, expectedCommands: [])
        XCTAssertEqual(router.goToPlaylist_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .initMiniPlayer, expectedCommands: [])
        XCTAssertEqual(router.showMiniPlayer_calledTimes, 1)
        
        test(viewModel: offlineSUT, action: .initMiniPlayer, expectedCommands: [])
        XCTAssertEqual(router.showMiniPlayer_calledTimes, 2)
        
        test(viewModel: onlineSUT, action: .`import`, expectedCommands: [])
        XCTAssertEqual(router.importNode_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .share(sender: nil), expectedCommands: [])
        XCTAssertEqual(router.share_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .sendToChat, expectedCommands: [])
        XCTAssertEqual(router.sendToContact_calledTimes, 1)
        
        test(viewModel: onlineSUT, action: .showActionsforCurrentNode(sender: UIButton()), expectedCommands: [])
        XCTAssertEqual(router.showAction_calledTimes, 1)
    }
    
    func testOnReceiveAudioPlayerActions_shouldInvokeCorrectCommands() {
        let (onlineSUT, playbackUseCase, _, _, _, _) = makeOnlineSUT()
        playbackUseCase._status = .startFromBeginning
        
        assert(
            onlineSUT,
            when: { viewModel in
                viewModel.audioDidStartPlayingItem(testItem)
            },
            shouldInvokeCommands: []
        )
    }
    
    func testAudioStartPlayingWithDisplayDialogStatus_shouldDisplayDialog_andPausePlayer_whenAppIsActive() {
        let (onlineSUT, playbackUseCase, playerHandler, _, _, _) = makeOnlineSUT()
        onlineSUT.checkAppIsActive = { true }
        playbackUseCase._status = .displayDialog(playbackTime: 1234.0)
        
        assert(
            onlineSUT,
            when: { viewModel in
                viewModel.audioDidStartPlayingItem(testItem)
            },
            shouldInvokeCommands: [
                .displayPlaybackContinuationDialog(
                    fileName: testItem.name,
                    playbackTime: 1234.0
                )
            ]
        )
        XCTAssertEqual(playerHandler.pause_calledTimes, 1)
    }
    
    func testAudioStartPlayingWithDisplayDialogStatus_shouldNotDisplayDialog_whenAppIsNotActive() {
        let (onlineSUT, playbackUseCase, _, _, _, _) = makeOnlineSUT()
        onlineSUT.checkAppIsActive = { false }
        playbackUseCase._status = .displayDialog(playbackTime: 1234.0)
        
        assert(
            onlineSUT,
            when: { viewModel in
                viewModel.audioDidStartPlayingItem(testItem)
            },
            shouldInvokeCommands: []
        )
    }
    
    func testAudioStartPlayingWithDisplayDialogStatus_shouldResumePlayback_whenAppIsNotActive() {
        let (onlineSUT, playbackUseCase, playerHandler, _, _, _) = makeOnlineSUT()
        onlineSUT.checkAppIsActive = { false }
        playbackUseCase._status = .displayDialog(playbackTime: 1234.0)
        
        onlineSUT.audioDidStartPlayingItem(testItem)
        
        XCTAssertEqual(playerHandler.pause_calledTimes, 0)
        XCTAssertEqual(playerHandler.playerResumePlayback_Calls, [1234.0])
        XCTAssertEqual(
            playbackUseCase.setPreference_Calls,
            [.resumePreviousSession]
        )
    }
    
    func testAudioPlaybackContinuation_resumeSession() {
        let (onlineSUT, playbackUseCase, playerHandler, _, _, _) = makeOnlineSUT()
        playbackUseCase._status = .resumeSession(playbackTime: 1234.0)
        
        onlineSUT.audioDidStartPlayingItem(testItem)
        
        XCTAssertEqual(
            playerHandler.playerResumePlayback_Calls,
            [1234.0]
        )
    }
    
    func testSelectPlaybackContinuationDialog_shouldSetPreference() {
        let (onlineSUT, playbackUseCase, _, _, _, _) = makeOnlineSUT()
        onlineSUT.dispatch(.onSelectResumePlaybackContinuationDialog(playbackTime: 1234.0))
        
        XCTAssertEqual(
            playbackUseCase.setPreference_Calls,
            [.resumePreviousSession]
        )
        
        onlineSUT.dispatch(.onSelectRestartPlaybackContinuationDialog)
        
        XCTAssertEqual(
            playbackUseCase.setPreference_Calls,
            [.resumePreviousSession, .restartFromBeginning]
        )
    }
    
    func testViewDidLoad_whenViewDidLoadAfterDeinit_shouldProperlyPrepareCleanPlayerWithSingleTrack() throws {
        let firstAudioNode = MockNode(handle: 1, name: "first-audio", nodeType: .file)
        let latestAudioNode = MockNode(handle: 2, name: "latest-audio", nodeType: .file)
        let (firstSUT, _, firstPlayerHandler, _) = simulateUserViewDidLoadWithNewInstane(audioNode: firstAudioNode)
        
        _ = try XCTUnwrap(firstPlayerHandler.currentPlayer())
        
        firstSUT.dispatch(.deinit)
        XCTAssertNotNil(firstPlayerHandler.currentPlayer())
        
        let (differentSUT, _, differentPlayerHandler, _) = simulateUserViewDidLoadWithNewInstane(audioNode: latestAudioNode)
        differentPlayerHandler.setCurrent(player: AudioPlayer(), autoPlayEnabled: false, tracks: [])
        
        XCTAssertEqual(differentPlayerHandler.setCurrent_callTimes, 0)
        try assertThatCleanPlayerStateForReuse(on: differentPlayerHandler, sut: differentSUT)
        XCTAssertTrue(differentSUT.isSingleTrackPlayer, "expect single track.")
        differentSUT.invokeCommand = {
            XCTAssertEqual($0, .configureDefaultPlayer)
            XCTAssertEqual($0, .shuffleAction(enabled: false))
            XCTAssertEqual($0, .goToPlaylistAction(enabled: false))
            XCTAssertEqual($0, .nextTrackAction(enabled: false))
        }
    }
    
    func testOnNodesUpdate_whenHasUpdatedItemButNotFoundNodeInList_ShouldNotRefresh() {
        let firstAudioNode = MockNode(handle: 1, name: "first-audio", nodeType: .file)
        let latestAudioNode = MockNode(handle: 2, name: "latest-audio", nodeType: .file)
        let updatedNode = MockNode(handle: 3, name: "New name")
        let updatedItem: AudioPlayerItem = .mockItem(node: updatedNode)
        let (onlineSUT, _, _, _, audioPlayerUseCase, sdk) = makeOnlineSUT(
            node: firstAudioNode,
            allNodes: [firstAudioNode, latestAudioNode]
        )
        var invokedCommands = [AudioPlayerViewModel.Command]()
        onlineSUT.invokeCommand = { invokedCommands.append($0) }
        let exp = expectation(description: "wait")
        
        audioPlayerUseCase.simulateOnNodesUpdate(MockNodeList(nodes: [updatedNode]), sdk: sdk)
        exp.fulfill()
        wait(for: [exp], timeout: 0.1)
        
        assertThatRefreshItemUIIsNotUpdatedOnRefreshItem(on: onlineSUT, updatedItem: updatedItem, invokedCommands: invokedCommands)
        assertThatRefreshItemDataSourceIsNotUpdated(on: onlineSUT, updatedNode: updatedNode, latestAudioNode: latestAudioNode)
    }
    
    func testOnNodesUpdate_whenHasUpdatedItem_refresh() {
        let firstAudioNode = MockNode(handle: 1, name: "first-audio", nodeType: .file)
        let latestAudioNode = MockNode(handle: 2, name: "latest-audio", nodeType: .file)
        let updatedNode = MockNode(handle: 1, name: "New name")
        let (onlineSUT, _, _, _, audioPlayerUseCase, sdk) = makeOnlineSUT(
            node: firstAudioNode,
            allNodes: [firstAudioNode, latestAudioNode]
        )
        
        assertThatRefreshItemUIUpdatedOnRefreshItem(on: onlineSUT, updatedNode: updatedNode, audioPlayerUseCase: audioPlayerUseCase, sdk: sdk)
        assertThatRefreshItemDataSourceUpdated(on: onlineSUT, updatedNode: updatedNode, latestAudioNode: latestAudioNode)
    }
    
    // MARK: - Helpers
    
    private func makeOnlineSUT(
        router: MockAudioPlayerViewRouter = MockAudioPlayerViewRouter(),
        node: MEGANode? = MEGANode(),
        allNodes: [MEGANode]? = nil
    ) -> (
        sut: AudioPlayerViewModel,
        playbackUseCase: MockPlaybackContinuationUseCase,
        playerHandler: MockAudioPlayerHandler,
        router: MockAudioPlayerViewRouter,
        audioPlayerUseCase: MockAudioPlayerUseCase,
        sdk: MockSdk
    ) {
        let playerHandler = MockAudioPlayerHandler()
        let (sut, playbackUseCase, audioPlayerUseCase, sdk) = makeSUT(
            configEntity: AudioPlayerConfigEntity(
                node: node,
                isFolderLink: false,
                fileLink: "",
                allNodes: allNodes,
                playerHandler: playerHandler
            ),
            nodeInfoUseCase: NodeInfoUseCase(nodeInfoRepository: MockNodeInfoRepository()),
            streamingInfoUseCase: StreamingInfoUseCase(streamingInfoRepository: MockStreamingInfoRepository()),
            router: router
        )
        return (sut, playbackUseCase, playerHandler, router, audioPlayerUseCase, sdk)
    }
    
    private func makeOfflineSUT(router: MockAudioPlayerViewRouter = MockAudioPlayerViewRouter()) -> (sut: AudioPlayerViewModel, router: MockAudioPlayerViewRouter) {
        let playerHandler = MockAudioPlayerHandler()
        let (sut, _, _, _) = makeSUT(
            configEntity: AudioPlayerConfigEntity(
                fileLink: "file_path",
                playerHandler: playerHandler
            ),
            offlineInfoUseCase: OfflineFileInfoUseCase(offlineInfoRepository: MockOfflineInfoRepository()),
            router: router
        )
        return (sut, router)
    }
    
    private func makeSUT(
        configEntity: AudioPlayerConfigEntity,
        nodeInfoUseCase: (any NodeInfoUseCaseProtocol)? = nil,
        streamingInfoUseCase: (any StreamingInfoUseCaseProtocol)? = nil,
        offlineInfoUseCase: (any OfflineFileInfoUseCaseProtocol)? = nil,
        router: MockAudioPlayerViewRouter
    ) -> (
        sut: AudioPlayerViewModel,
        playbackContinuationUseCase: MockPlaybackContinuationUseCase,
        audioPlayerUseCase: MockAudioPlayerUseCase,
        sdk: MockSdk
    ) {
        let mockPlaybackContinuationUseCase = MockPlaybackContinuationUseCase()
        let audioPlayerUseCase = MockAudioPlayerUseCase()
        let sdk = MockSdk()
        let sut = AudioPlayerViewModel(
            configEntity: configEntity,
            router: router,
            nodeInfoUseCase: nodeInfoUseCase,
            streamingInfoUseCase: streamingInfoUseCase,
            offlineInfoUseCase: offlineInfoUseCase,
            playbackContinuationUseCase: mockPlaybackContinuationUseCase,
            audioPlayerUseCase: audioPlayerUseCase,
            dispatchQueue: MockDispatchQueue(),
            sdk: sdk
        )
        return (sut, mockPlaybackContinuationUseCase, audioPlayerUseCase, sdk)
    }
    
    private func simulateUserViewDidLoadWithNewInstane(audioNode: MockNode) -> (sut: AudioPlayerViewModel, playbackUseCase: MockPlaybackContinuationUseCase, playerHandler: MockAudioPlayerHandler, router: MockAudioPlayerViewRouter) {
        let router = MockAudioPlayerViewRouter()
        let configEntity = audioPlayerConfigEntity(node: audioNode)
        let (sut, playbackUseCase, _, _) = makeSUT(
            configEntity: configEntity,
            nodeInfoUseCase: NodeInfoUseCase(nodeInfoRepository: MockNodeInfoRepository()),
            streamingInfoUseCase: StreamingInfoUseCase(streamingInfoRepository: MockStreamingInfoRepository()),
            router: router
        )
        sut.dispatch(.onViewDidLoad)
        return (sut, playbackUseCase, configEntity.playerHandler as! MockAudioPlayerHandler, router)
    }
    
    private func assert(
        _ viewModel: AudioPlayerViewModel,
        when action: (AudioPlayerViewModel) -> Void,
        shouldInvokeCommands expectedCommands: [AudioPlayerViewModel.Command],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var invokedCommands =  [AudioPlayerViewModel.Command]()
        viewModel.invokeCommand = { invokedCommands.append($0) }
        
        action(viewModel)
        
        XCTAssertEqual(invokedCommands, expectedCommands, file: file, line: line)
    }
    
    private var testItem: AudioPlayerItem {
        AudioPlayerItem(
            name: "test-name",
            url: URL(string: "any-url")!,
            node: MockNode(handle: 1, fingerprint: "test-fingerprint")
        )
    }
    
    private func audioPlayerConfigEntity(node: MockNode, isFolderLink: Bool = false, fileLink: String? = nil) -> AudioPlayerConfigEntity {
        let playerHandler = MockAudioPlayerHandler()
        return AudioPlayerConfigEntity(
            node: node,
            isFolderLink: isFolderLink,
            fileLink: fileLink,
            playerHandler: playerHandler
        )
    }
    
    private func assertThatCleanPlayerStateForReuse(on playerHandler: MockAudioPlayerHandler, sut: AudioPlayerViewModel, file: StaticString = #filePath, line: UInt = #line) throws {
        let player = try XCTUnwrap(playerHandler.currentPlayer(), "Fail to get currentPlayer", file: file, line: line)
        assertThatRemovePreviousQueuedTrackInPlayer(on: player, file: file, line: line)
        assertThatRefreshPlayerListener(on: player, sut: sut, file: file, line: line)
    }
    
    private func assertThatRemovePreviousQueuedTrackInPlayer(on player: AudioPlayer, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(player.queuePlayer, "Expect to remove previous queued track player, but not removed.", file: file, line: line)
        XCTAssertTrue(player.tracks.isEmpty, "Expect track is empty, but not empty instead.", file: file, line: line)
    }
    
    private func assertThatRefreshPlayerListener(on player: AudioPlayer, sut: AudioPlayerViewModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(player.listenerManager.listeners.isEmpty, "Expect listeners empty.", file: file, line: line)
        XCTAssertTrue(player.listenerManager.listeners.notContains(where: { $0 as! AnyHashable == sut as AnyHashable }), "Expect listeners not contains observer.", file: file, line: line)
    }
    
    private func assertThatRefreshItemUIIsNotUpdatedOnRefreshItem(on onlineSUT: AudioPlayerViewModel, updatedItem: AudioPlayerItem, invokedCommands: [AudioPlayerViewModel.Command], file: StaticString = #filePath, line: UInt = #line) {
        var receivedCommands = [AudioPlayerViewModel.Command]()
        invokedCommands.forEach { receivedCommands.append($0) }
        XCTAssertTrue(receivedCommands.isEmpty, file: file, line: line)
    }
    
    private func assertThatRefreshItemUIUpdatedOnRefreshItem(on onlineSUT: AudioPlayerViewModel, updatedNode: MEGANode, audioPlayerUseCase: MockAudioPlayerUseCase, sdk: MockSdk, file: StaticString = #filePath, line: UInt = #line) {
        assert(
            onlineSUT,
            when: { _ in audioPlayerUseCase.simulateOnNodesUpdate(MockNodeList(nodes: [updatedNode]), sdk: sdk) },
            shouldInvokeCommands: [
                .reloadNodeInfo(name: "New name", artist: "", thumbnail: nil, size: Optional("Zero KB")),
                .showLoading(false)
            ],
            file: file,
            line: line
        )
    }
    
    private func assertThatRefreshItemDataSourceIsNotUpdated(on onlineSUT: AudioPlayerViewModel, updatedNode: MEGANode, latestAudioNode: MEGANode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(onlineSUT.configEntity.node, updatedNode, file: file, line: line)
        onlineSUT.configEntity.playerHandler.currentPlayer()?.tracks
            .map { $0.name }
            .enumerated()
            .forEach { (index, name) in
                if index == 1 {
                    XCTAssertEqual(name, updatedNode.name, file: file, line: line)
                }
                if index == 2 {
                    XCTAssertEqual(name, latestAudioNode.name, file: file, line: line)
                }
            }
    }
    
    private func assertThatRefreshItemDataSourceUpdated(on onlineSUT: AudioPlayerViewModel, updatedNode: MEGANode, latestAudioNode: MEGANode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(onlineSUT.configEntity.node, updatedNode, file: file, line: line)
        onlineSUT.configEntity.playerHandler.currentPlayer()?.tracks
            .map { $0.name }
            .enumerated()
            .forEach { (index, name) in
                if index == 1 {
                    XCTAssertEqual(name, updatedNode.name, file: file, line: line)
                }
                if index == 2 {
                    XCTAssertEqual(name, latestAudioNode.name, file: file, line: line)
                }
            }
    }
}
