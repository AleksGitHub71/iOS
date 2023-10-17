import Combine
@testable import MEGA
import MEGADomain
import MEGADomainMock
import XCTest

final class MeetingContainerViewModelTests: XCTestCase {
    
    var viewModel: MeetingContainerViewModel!

    func testAction_onViewReady() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .moderator, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let callCoordinatorUseCase = MockCallCoordinatorUseCase()
        viewModel = MeetingContainerViewModel(
            router: router,
            chatRoom: chatRoom,
            callCoordinatorUseCase: callCoordinatorUseCase
        )
        test(viewModel: viewModel, action: .onViewReady, expectedCommands: [])
        XCTAssert(router.showMeetingUI_calledTimes == 1)
        XCTAssert(callCoordinatorUseCase.addCallRemoved_CalledTimes == 1)
    }
    
    func testAction_hangCall_attendeeIsGuest() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .moderator, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let callEntity = CallEntity(chatId: 1, callId: 1, duration: 1, initialTimestamp: 1, finalTimestamp: 1, numberOfParticipants: 1)
        let callUseCase = MockCallUseCase(call: callEntity)
        viewModel = MeetingContainerViewModel(router: router,
                                                  chatRoom: chatRoom,
                                                  callUseCase: callUseCase,
                                                  accountUseCase: MockAccountUseCase(currentUser: UserEntity(handle: 100), isGuest: true, isLoggedIn: false))
        test(viewModel: viewModel, action: .hangCall(presenter: UIViewController(), sender: UIButton()), expectedCommands: [])
        XCTAssert(router.showEndMeetingOptions_calledTimes == 1)
    }
    
    func testAction_hangCall_attendeeIsParticipantOrModerator() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .moderator, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let callEntity = CallEntity(chatId: 1, callId: 1, duration: 1, initialTimestamp: 1, finalTimestamp: 1, numberOfParticipants: 1)
        let callUseCase = MockCallUseCase(call: callEntity)
        let callManagerUserCase = MockCallCoordinatorUseCase()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom, callUseCase: callUseCase, callCoordinatorUseCase: callManagerUserCase)
        test(viewModel: viewModel, action: .hangCall(presenter: UIViewController(), sender: UIButton()), expectedCommands: [])
        XCTAssert(router.dismiss_calledTimes == 1)
        XCTAssert(callManagerUserCase.endCall_calledTimes == 1)
        XCTAssert(callUseCase.hangCall_CalledTimes == 1)
    }
    
    func testAction_backButtonTap() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .moderator, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .tapOnBackButton, expectedCommands: [])
        XCTAssert(router.dismiss_calledTimes == 1)
    }
    
    func testAction_ChangeMenuVisibility() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .moderator, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .changeMenuVisibility, expectedCommands: [])
        XCTAssert(router.toggleFloatingPanel_CalledTimes == 1)
    }

    func testAction_shareLink_Success() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let chatRoomUseCase = MockChatRoomUseCase(publicLinkCompletion: .success(""))
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom, chatRoomUseCase: chatRoomUseCase)
        test(viewModel: viewModel, action: .shareLink(presenter: UIViewController(), sender: UIButton(), completion: nil), expectedCommands: [])
        XCTAssert(router.shareLink_calledTimes == 1)
    }
    
    func testAction_shareLink_Failure() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .shareLink(presenter: UIViewController(), sender: UIButton(), completion: nil), expectedCommands: [])
        XCTAssert(router.shareLink_calledTimes == 0)
    }
    
    func testAction_displayParticipantInMainView() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        let particpant = CallParticipantEntity(chatId: 100, participantId: 100, clientId: 100, isModerator: false, isInContactList: false, canReceiveVideoHiRes: true)
        test(viewModel: viewModel, action: .displayParticipantInMainView(particpant), expectedCommands: [])
        XCTAssert(router.displayParticipantInMainView_calledTimes == 1)
    }
    
    func testAction_didDisplayParticipantInMainView() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        let particpant = CallParticipantEntity(chatId: 100, participantId: 100, clientId: 100, isModerator: false, isInContactList: false, canReceiveVideoHiRes: true)
        test(viewModel: viewModel, action: .didDisplayParticipantInMainView(particpant), expectedCommands: [])
        XCTAssert(router.didDisplayParticipantInMainView_calledTimes == 1)
    }
    
    func testAction_didSwitchToGridView() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .didSwitchToGridView, expectedCommands: [])
        XCTAssert(router.didSwitchToGridView_calledTimes == 1)
    }
    
    func testAction_showEndCallDialog() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let callEntity = CallEntity(numberOfParticipants: 1, participants: [100])
        let callUseCase = MockCallUseCase(call: callEntity)
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom, callUseCase: callUseCase)
        test(viewModel: viewModel, action: .showEndCallDialogIfNeeded, expectedCommands: [])
        XCTAssert(router.didShowEndDialog_calledTimes == 1)
    }
    
    func testAction_removeEndCallDialogWhenParticipantAdded() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()

        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .participantJoinedCallOrWaitingRoom, expectedCommands: [])
        XCTAssert(router.removeEndDialog_calledTimes == 1)
    }
    
    func testAction_removeEndCallDialogAndEndCall() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .removeEndCallAlertAndEndCall, expectedCommands: [])
        XCTAssert(router.removeEndDialog_calledTimes == 1)
    }
    
    func testAction_showJoinMegaScreen() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)
        test(viewModel: viewModel, action: .showJoinMegaScreen, expectedCommands: [])
        XCTAssert(router.showJoinMegaScreen_calledTimes == 1)
    }
    
    func testAction_OnViewReady_NoUserJoined() {
        let chatRoom = ChatRoomEntity(ownPrivilege: .standard, chatType: .meeting)
        let router = MockMeetingContainerRouter()
        let callUseCase = MockCallUseCase(call: CallEntity(numberOfParticipants: 1, participants: [100]))
        let noUserJoinedUseCase = MockMeetingNoUserJoinedUseCase()
        let expectation = expectation(description: "testAction_OnViewReady_NoUserJoined")
        let chatRoomUseCase = MockChatRoomUseCase(chatRoomEntity: chatRoom)
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom, callUseCase: callUseCase, chatRoomUseCase: chatRoomUseCase, noUserJoinedUseCase: noUserJoinedUseCase)
        test(viewModel: viewModel, action: .onViewReady, expectedCommands: [])
        
        var subscription: AnyCancellable? = noUserJoinedUseCase
            .monitor
            .receive(on: DispatchQueue.main)
            .sink { _ in
            expectation.fulfill()
        }
        
        _ = subscription // suppress never used warning
        
        noUserJoinedUseCase.start(timerDuration: 1, chatId: 101)
        waitForExpectations(timeout: 10)
        XCTAssert(router.didShowEndDialog_calledTimes == 1)
        subscription = nil
    }
    
    func testAction_muteMicrophoneForMeetingsWhenLastParticipantLeft() {
        let chatRoom = ChatRoomEntity(chatType: .meeting)
        let chatRoomUsecase = MockChatRoomUseCase(chatRoomEntity: chatRoom)

        let call = CallEntity(hasLocalAudio: true, numberOfParticipants: 1, participants: [100])
        let callUseCase = MockCallUseCase(call: call)
        let callCoordinatorUseCase = MockCallCoordinatorUseCase()
        viewModel = MeetingContainerViewModel(callUseCase: callUseCase,
                                                  chatRoomUseCase: chatRoomUsecase,
                                                  callCoordinatorUseCase: callCoordinatorUseCase,
                                                  accountUseCase: MockAccountUseCase(currentUser: UserEntity(handle: 100), isGuest: false, isLoggedIn: true))
        
        test(viewModel: viewModel, action: .participantRemoved, expectedCommands: [])
        XCTAssertEqual(callCoordinatorUseCase.muteUnmute_Calls, [true])
    }
    
    func testAction_muteMicrophoneForGroupWhenLastParticipantLeft() {
        let chatRoom = ChatRoomEntity(chatType: .group)
        let chatRoomUsecase = MockChatRoomUseCase(chatRoomEntity: chatRoom)

        let call = CallEntity(hasLocalAudio: true, numberOfParticipants: 1, participants: [100])
        let callUseCase = MockCallUseCase(call: call)
        
        let callCoordinatorUseCase = MockCallCoordinatorUseCase()
        
        viewModel = MeetingContainerViewModel(callUseCase: callUseCase,
                                                  chatRoomUseCase: chatRoomUsecase,
                                                  callCoordinatorUseCase: callCoordinatorUseCase,
                                                  accountUseCase: MockAccountUseCase(currentUser: UserEntity(handle: 100), isGuest: false, isLoggedIn: true))
        
        test(viewModel: viewModel, action: .participantRemoved, expectedCommands: [])
        XCTAssertEqual(callCoordinatorUseCase.muteUnmute_Calls, [true])
    }
    
    func testAction_donotMuteMicrophoneForOneToOneWhenLastParticipantLeft() {
        let chatRoom = ChatRoomEntity(chatType: .oneToOne)
        let chatRoomUsecase = MockChatRoomUseCase(chatRoomEntity: chatRoom)

        let call = CallEntity(hasLocalAudio: true, numberOfParticipants: 1, participants: [100])
        let callUseCase = MockCallUseCase(call: call)
        
        let callCoordinatorUseCase = MockCallCoordinatorUseCase()
        
        viewModel = MeetingContainerViewModel(callUseCase: callUseCase,
                                                  chatRoomUseCase: chatRoomUsecase,
                                                  callCoordinatorUseCase: callCoordinatorUseCase,
                                                  accountUseCase: MockAccountUseCase(currentUser: UserEntity(handle: 100), isGuest: false, isLoggedIn: true))
        
        test(viewModel: viewModel, action: .participantRemoved, expectedCommands: [])
        XCTAssertEqual(callCoordinatorUseCase.muteUnmute_Calls, [])
    }
    
    func testAction_showHangOrEndCallDialog() {
        let chatRoom = ChatRoomEntity(chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)

        test(viewModel: viewModel, action: .showHangOrEndCallDialog, expectedCommands: [])
        XCTAssert(router.showHangOrEndCallDialog_calledTimes == 1)
    }
    
    func testAction_endCallForAll() {
        let chatRoom = ChatRoomEntity(chatType: .meeting)
        let router = MockMeetingContainerRouter()
        viewModel = MeetingContainerViewModel(router: router, chatRoom: chatRoom)

        test(viewModel: viewModel, action: .endCallForAll, expectedCommands: [])
        XCTAssert(router.dismiss_calledTimes == 1)
    }
    
    func testMuteUnmuteOperationFailedNotification_withCallStateMutedAndPreviousMuteOperationFailure_shouldMatch() {
        assertWhenMuteUnmuteOperationFailed(withMutedValue: true, hasLocalAudio: false, expectsMuteUnmuteCalls: [true])
    }
    
    func testMuteUnmuteOperationFailedNotification_withCallStateUnmutedAndPreviousUnmuteOperationFailure_shouldMatch() {
        assertWhenMuteUnmuteOperationFailed(withMutedValue: false, hasLocalAudio: true, expectsMuteUnmuteCalls: [false])
    }
    
    func testMuteUnmuteOperationFailedNotification_withCallStateMutedAndPreviousUnmuteOperationFailure_shouldMatch() {
        assertWhenMuteUnmuteOperationFailed(withMutedValue: false, hasLocalAudio: false, expectsMuteUnmuteCalls: [true])
    }
    
    func testMuteUnmuteOperationFailedNotification_withCallStateUnmutedAndPreviousMuteOperationFailure_shouldMatch() {
        assertWhenMuteUnmuteOperationFailed(withMutedValue: true, hasLocalAudio: true, expectsMuteUnmuteCalls: [false])
    }
    
    // MARK: - Private methods
    
    private func assertWhenMuteUnmuteOperationFailed(
        withMutedValue muted: Bool,
        hasLocalAudio: Bool,
        expectsMuteUnmuteCalls expectedCalls: [Bool],
        line: UInt = #line
    ) {
        let callCoordinatorUseCase = MockCallCoordinatorUseCase()
        let callUseCase = MockCallUseCase(call: CallEntity(hasLocalAudio: hasLocalAudio))
        viewModel = MeetingContainerViewModel(
            callUseCase: callUseCase,
            callCoordinatorUseCase: callCoordinatorUseCase
        )

        NotificationCenter.default.post(
            name: .MEGACallMuteUnmuteOperationFailed,
            object: nil,
            userInfo: ["muted": muted]
        )
        
        XCTAssertEqual(callCoordinatorUseCase.muteUnmute_Calls, expectedCalls, line: line)
    }

}

final class MockMeetingContainerRouter: MeetingContainerRouting {
    var showMeetingUI_calledTimes = 0
    var dismiss_calledTimes = 0
    var toggleFloatingPanel_CalledTimes = 0
    var showEndMeetingOptions_calledTimes = 0
    var showOptionsMenu_calledTimes = 0
    var shareLink_calledTimes = 0
    var renameChat_calledTimes = 0
    var showMeetingError_calledTimes = 0
    var enableSpeaker_calledTimes = 0
    var displayParticipantInMainView_calledTimes = 0
    var didDisplayParticipantInMainView_calledTimes = 0
    var didSwitchToGridView_calledTimes = 0
    var didShowEndDialog_calledTimes = 0
    var removeEndDialog_calledTimes = 0
    var showJoinMegaScreen_calledTimes = 0
    var showHangOrEndCallDialog_calledTimes = 0
    var selectWaitingRoomList_calledTimes = 0
    func showMeetingUI(containerViewModel: MeetingContainerViewModel) {
        showMeetingUI_calledTimes += 1
    }
    
    func toggleFloatingPanel(containerViewModel: MeetingContainerViewModel) {
        toggleFloatingPanel_CalledTimes += 1
    }
    
    func dismiss(animated: Bool, completion: (() -> Void)?) {
        dismiss_calledTimes += 1
        completion?()
    }
    
    func showEndMeetingOptions(presenter: UIViewController, meetingContainerViewModel: MeetingContainerViewModel, sender: UIButton) {
        showEndMeetingOptions_calledTimes += 1
    }
    
    func showOptionsMenu(presenter: UIViewController, sender: UIBarButtonItem, isMyselfModerator: Bool, containerViewModel: MeetingContainerViewModel) {
        showEndMeetingOptions_calledTimes += 1
    }
    
    func shareLink(presenter: UIViewController?, sender: AnyObject, link: String, isGuestAccount: Bool, completion: UIActivityViewController.CompletionWithItemsHandler?) {
        shareLink_calledTimes += 1
    }
    
    func renameChat() {
        renameChat_calledTimes += 1
    }
    
    func showShareMeetingError() {
        showMeetingError_calledTimes += 1
    }
    
    func enableSpeaker(_ enable: Bool) {
        enableSpeaker_calledTimes += 1
    }
    
    func displayParticipantInMainView(_ participant: CallParticipantEntity) {
        displayParticipantInMainView_calledTimes += 1
    }
    
    func didDisplayParticipantInMainView(_ participant: CallParticipantEntity) {
        didDisplayParticipantInMainView_calledTimes += 1
    }
    
    func didSwitchToGridView() {
        didSwitchToGridView_calledTimes += 1
    }
    
    func showEndCallDialog(endCallCompletion: @escaping () -> Void, stayOnCallCompletion: (() -> Void)?) {
        didShowEndDialog_calledTimes += 1
    }
    
    func removeEndCallDialog(completion: (() -> Void)?) {
        removeEndDialog_calledTimes += 1
    }
    
    func showJoinMegaScreen() {
        showJoinMegaScreen_calledTimes += 1
    }
    
    func showHangOrEndCallDialog(containerViewModel: MeetingContainerViewModel) {
        showHangOrEndCallDialog_calledTimes += 1
    }
    
    func selectWaitingRoomList(containerViewModel: MeetingContainerViewModel) {
        selectWaitingRoomList_calledTimes += 1
    }
}
