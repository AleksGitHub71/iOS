import Combine
@testable import MEGA
import MEGAAnalyticsiOS
import MEGADomain
import MEGADomainMock
import MEGAL10n
import MEGAPresentationMock
import MEGATest
import XCTest

final class WaitingRoomViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()

    func testMeetingTitle_onLoadWaitingRoom_shouldMatch() {
        let meetingTitle = "Test Meeting"
        let scheduledMeeting = ScheduledMeetingEntity(title: meetingTitle)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting)
        
        XCTAssertEqual(sut.meetingTitle, meetingTitle)
    }
    
    func testMeetingDate_givenMeetingStartAndEndDate_shouldMatch() throws {
        let startDate = try XCTUnwrap(sampleDate(from: "21/09/2023 10:30"))
        let endDate = try XCTUnwrap(sampleDate(from: "21/09/2023 10:45"))
        let scheduledMeeting = ScheduledMeetingEntity(startDate: startDate, endDate: endDate)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting)
        
        XCTAssertEqual(sut.createMeetingDate(locale: Locale(identifier: "en_GB")), "Thu, 21 Sep ·10:30-10:45")
    }
    
    func testViewState_onLoadWaitingRoomAndIsGuest_shouldBeGuestJoinState() {
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase)
        XCTAssertEqual(sut.viewState, .guestUserSetup)
    }
    
    func testViewState_onLoadWaitingRoomAndIsNotGuestAndMeetingNotStart_shouldBeWaitForHostToStartState() {
        let callUseCase = MockCallUseCase(call: nil)
        let sut = WaitingRoomViewModel(callUseCase: callUseCase)
        XCTAssertEqual(sut.viewState, .waitForHostToStart)
    }
    
    func testViewState_onLoadWaitingRoomAndIsNotGuestAndMeetingDidStart_shouldBeWaitForHostToStartState() {
        let sut = WaitingRoomViewModel()
        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
    }
    
    func testViewState_onMeetingNotStartTransitsToMeetingDidStart_shouldChangeFromWaitForHostToStartToWaitForHostToLetIn() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let callEntity = CallEntity(status: .connecting, chatId: 100)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(callEntity), callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, callUseCase: callUseCase)
        
        XCTAssertEqual(sut.viewState, .waitForHostToStart)
        
        callUseCase.call = callEntity
        callUpdateSubject.send(callEntity)
        
        evaluate {
            sut.viewState == .waitForHostToLetIn
        }
    }
    
    func testViewState_onMeetingDidStartTransitsToMeetingNotStart_shouldChangeFromWaitForHostToLetInToWaitForHostToStart() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let chatUseCase = MockChatUseCase(isActiveWaitingRoom: true)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, chatUseCase: chatUseCase, callUseCase: callUseCase)
        
        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
        
        callUseCase.call = nil
        callUpdateSubject.send(CallEntity(status: .terminatingUserParticipation, chatId: 100))
        
        evaluate {
            sut.viewState == .waitForHostToStart
        }
    }
    
    func testSpeakerButton_onTapSpeakerButton_shouldDisableSpeakerButton() {
        let audioSessionUseCase = MockAudioSessionUseCase()
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        sut.enableLoudSpeaker(enabled: false)
        
        XCTAssertEqual(audioSessionUseCase.disableLoudSpeaker_calledTimes, 1)
    }
    
    func testCalculateVideoSize_portraitMode_shouldMatch() {
        let screenHeight = 424.0
        let screenWidth = 236.0
        let sut = WaitingRoomViewModel()
        sut.screenSize = CGSize(width: screenWidth, height: screenHeight)
        
        let videoSize = sut.calculateVideoSize()
        
        XCTAssertEqual(videoSize, calculateVideoSize(by: screenHeight, isLandscape: false))
    }
    
    func testCalculateVideoSize_landscapeMode_shouldMatch() {
        let screenHeight = 236.0
        let screenWidth = 424.0
        let sut = WaitingRoomViewModel()
        sut.screenSize = CGSize(width: screenWidth, height: screenHeight)
        
        let videoSize = sut.calculateVideoSize()
        
        XCTAssertEqual(videoSize, calculateVideoSize(by: screenHeight, isLandscape: true))
    }
    
    func testCalculateBottomPanelHeight_portraitModeAndGuestJoin_shouldMatch() {
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase)
        
        XCTAssertEqual(sut.calculateBottomPanelHeight(), 142.0)
    }
    
    func testCalculateBottomPanelHeight_portraitModeAndWaitForHostToLetIn_shouldMatch() {
        let sut = WaitingRoomViewModel()
        
        XCTAssertEqual(sut.calculateBottomPanelHeight(), 100.0)
    }
    
    func testCalculateBottomPanelHeight_landscapeModeAndGuestJoin_shouldMatch() {
        let screenHeight = 236.0
        let screenWidth = 424.0
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase)
        sut.screenSize = CGSize(width: screenWidth, height: screenHeight)
        
        XCTAssertEqual(sut.calculateBottomPanelHeight(), 142.0)
    }
    
    func testCalculateBottomPanelHeight_landscapeModeAndWaitForHostToLetIn_shouldMatch() {
        let screenHeight = 236.0
        let screenWidth = 424.0
        let sut = WaitingRoomViewModel()
        sut.screenSize = CGSize(width: screenWidth, height: screenHeight)
        
        XCTAssertEqual(sut.calculateBottomPanelHeight(), 8.0)
    }
    
    func testShowWaitingRoomMessage_whenGuestLogin_shouldNotShow() {
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase)
        
        XCTAssertFalse(sut.showWaitingRoomMessage)
    }
    
    func testShowWaitingRoomMessage_whenWaitForHostToStart_shouldShow() {
        let chatUseCase = MockChatUseCase(isActiveWaitingRoom: false)
        let sut = WaitingRoomViewModel(chatUseCase: chatUseCase)
        
        XCTAssertTrue(sut.showWaitingRoomMessage)
    }
    
    func testShowWaitingRoomMessage_whenWaitForHostToLetIn_shouldShow() {
        let chatUseCase = MockChatUseCase(isActiveWaitingRoom: true)
        let sut = WaitingRoomViewModel(chatUseCase: chatUseCase)
        
        XCTAssertTrue(sut.showWaitingRoomMessage)
    }
    
    func testWaitingRoomMessage_whenWaitForHostToStart_shouldMatch() {
        let callUseCase = MockCallUseCase(call: nil)
        let sut = WaitingRoomViewModel(callUseCase: callUseCase)
        
        XCTAssertEqual(sut.waitingRoomMessage, Strings.Localizable.Meetings.WaitingRoom.Message.waitForHostToStartTheMeeting)
    }
    
    func testWaitingRoomMessage_whenWaitForHostToLetIn_shouldMatch() {
        let sut = WaitingRoomViewModel()
        
        XCTAssertEqual(sut.waitingRoomMessage, Strings.Localizable.Meetings.WaitingRoom.Message.waitForHostToLetYouIn)
    }
    
    func testTapJoinAction_onCreateEphemeralAccountSuccessAndJoinChatSuccessAndMeetingDidStart_shoudBecomeWaitForHostToLetIn() {
        let callUseCase = MockCallUseCase(call: CallEntity(), answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(createEphemeralAccountCompletion: .success)
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       accountUseCase: accountUseCase,
                                       chatLink: "Test chatLink")
        
        XCTAssertEqual(sut.viewState, .guestUserSetup)
        
        sut.tapJoinAction(firstName: "First", lastName: "Last")
        
        evaluate {
            sut.viewState == .waitForHostToLetIn
        }
    }
    
    func testTapJoinAction_onCreateEphemeralAccountSuccessAndJoinChatSuccessAndMeetingNotStart_shoudBecomeWaitForHostToStart() {
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(createEphemeralAccountCompletion: .success)
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       accountUseCase: accountUseCase,
                                       chatLink: "Test chatLink")
        
        XCTAssertEqual(sut.viewState, .guestUserSetup)
        
        sut.tapJoinAction(firstName: "First", lastName: "Last")
        
        evaluate {
            sut.viewState == .waitForHostToStart
        }
    }
    
    func testTapJoinAction_onCreateEphemeralAccountSuccessAndJoinChatFail_shoudDismiss() {
        let router = MockWaitingRoomViewRouter()
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(createEphemeralAccountCompletion: .success)
        let waitingRoomUseCase = MockWaitingRoomUseCase(joinChatResult: .failure(.generic))
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(router: router,
                                       callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       waitingRoomUseCase: waitingRoomUseCase,
                                       accountUseCase: accountUseCase,
                                       chatLink: "Test chatLink")
        
        XCTAssertEqual(sut.viewState, .guestUserSetup)
        
        sut.tapJoinAction(firstName: "First", lastName: "Last")
        
        evaluate {
            router.dismiss_calledTimes == 1
        }
    }
    
    func testUserAvatar_onLoadWaitingRoomAndIsNotGuest_shouldShowAvatar() {
        let megaHandleUseCase = MockMEGAHandleUseCase(base64Handle: Base64HandleEntity())
        let userImageUseCase = MockUserImageUseCase(fetchAvatarResult: .success("image"))
        let sut = WaitingRoomViewModel(megaHandleUseCase: megaHandleUseCase, userImageUseCase: userImageUseCase)
        
        evaluate {
            sut.userAvatar != nil
        }
    }
    
    func testUserAvatar_onLoadWaitingRoomAndIsGuest_shouldNotShowAvatar() {
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let megaHandleUseCase = MockMEGAHandleUseCase(base64Handle: Base64HandleEntity())
        let userImageUseCase = MockUserImageUseCase()
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase,
                                       megaHandleUseCase: megaHandleUseCase,
                                       userImageUseCase: userImageUseCase)
        
        evaluate {
            sut.userAvatar == nil
        }
    }
    
    func testUserAvatar_onLoadWaitingRoomAndIsGuestAndJoinsTheChat_shouldShowAvatar() {
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(createEphemeralAccountCompletion: .success)
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let megaHandleUseCase = MockMEGAHandleUseCase(base64Handle: Base64HandleEntity())
        let userImageUseCase = MockUserImageUseCase(fetchAvatarResult: .success("image"))
        let sut = WaitingRoomViewModel(callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       accountUseCase: accountUseCase,
                                       megaHandleUseCase: megaHandleUseCase,
                                       userImageUseCase: userImageUseCase,
                                       chatLink: "Test chatLink")
        
        XCTAssertEqual(sut.viewState, .guestUserSetup)
        
        sut.tapJoinAction(firstName: "First", lastName: "Last")
        
        evaluate {
            sut.userAvatar != nil
        }
    }
    
    func testCheckChatLink_whenUserPrivilegeIsRemovedAndJoinChatCallSuccess_shoudBecomeWaitForHostToStart() {
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(checkChatLinkCompletion: .success(ChatRoomEntity(ownPrivilege: .removed)))
        let sut = WaitingRoomViewModel(callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       chatLink: "Test chatLink")
        
        evaluate {
            sut.viewState == .waitForHostToStart
        }
    }
    
    func testCheckChatLink_whenUserPrivilegeIsReadOnlyAndJoinChatCallSuccess_shoudBecomeWaitForHostToStart() {
        let callUseCase = MockCallUseCase(call: nil, answerCallCompletion: .success(CallEntity()))
        let meetingUseCase = MockMeetingCreatingUseCase(checkChatLinkCompletion: .success(ChatRoomEntity(ownPrivilege: .readOnly)))
        let sut = WaitingRoomViewModel(callUseCase: callUseCase,
                                       meetingUseCase: meetingUseCase,
                                       chatLink: "Test chatLink")
        
        evaluate {
            sut.viewState == .waitForHostToStart
        }
    }
    
    // MARK: - Router related tests
    
    func testLeaveButton_didTapLeaveButton_shouldPresentLeaveAlert() {
        let router = MockWaitingRoomViewRouter()
        let sut = WaitingRoomViewModel(router: router)
        
        sut.leaveButtonTapped()
        
        XCTAssertEqual(router.showLeaveAlert_calledTimes, 1)
    }
    
    func testMeetingInfoButton_didTapMeetingInfoButton_shouldPresentMeetingInfo() {
        let router = MockWaitingRoomViewRouter()
        let sut = WaitingRoomViewModel(router: router)
        
        sut.infoButtonTapped()
        
        XCTAssertEqual(router.showMeetingInfo_calledTimes, 1)
    }
    
    func testShowHostDenyAlert_onHostDeny_shouldShowDenyAlert() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let router = MockWaitingRoomViewRouter()
        let callEntity = CallEntity(status: .waitingRoom, chatId: 100, termCodeType: .kicked, waitingRoomStatus: .notAllowed)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, router: router, callUseCase: callUseCase)

        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)

        callUpdateSubject.send(callEntity)
        
        evaluate {
            router.showHostDenyAlert_calledTimes == 1
        }
    }
    
    func testShowHostDidNotRespondAlert_onTimeout_shouldHostDidNotRespondAlert() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let router = MockWaitingRoomViewRouter()
        let callEntity = CallEntity(status: .waitingRoom, chatId: 100, termCodeType: .waitingRoomTimeout, waitingRoomStatus: .notAllowed)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, router: router, callUseCase: callUseCase)

        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
        
        callUpdateSubject.send(callEntity)
        
        evaluate {
            router.showHostDidNotRespondAlert_calledTimes == 1
        }
    }
    
    func testGoToCallUI_onHostAllowToJoinAndChangeTypeIsWaitingRoomAllow_shouldOpenCallUI() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let router = MockWaitingRoomViewRouter()
        let chatRoomUseCase = MockChatRoomUseCase(chatRoomEntity: ChatRoomEntity())
        let callEntity = CallEntity(chatId: 100, changeType: .waitingRoomAllow)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, router: router, chatRoomUseCase: chatRoomUseCase, callUseCase: callUseCase)
        
        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
        
        callUpdateSubject.send(callEntity)
        
        evaluate {
            router.openCallUI_calledTimes == 1
        }
    }
    
    func testGoToCallUI_onHostAllowToJoinAndCallStatusIsInProgress_shouldOpenCallUI() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let router = MockWaitingRoomViewRouter()
        let chatRoomUseCase = MockChatRoomUseCase(chatRoomEntity: ChatRoomEntity())
        let callEntity = CallEntity(status: .inProgress, chatId: 100, changeType: .status)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, router: router, chatRoomUseCase: chatRoomUseCase, callUseCase: callUseCase)
        
        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
        
        callUpdateSubject.send(callEntity)
        
        evaluate {
            router.openCallUI_calledTimes == 1
        }
    }
    
    func testUpdateSpeakerInfo_forCurrentPortBuiltInReceiver_shouldNotEnabledSpeaker() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(currentSelectedAudioPort: .builtInReceiver, onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject)
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.isSpeakerEnabled == false
        }
    }
    
    func testUpdateSpeakerInfo_forCurrentPortBuiltInSpeaker_shouldEnabledSpeaker() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(currentSelectedAudioPort: .builtInSpeaker, onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject)
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.isSpeakerEnabled == true
        }
    }
    
    func testUpdateSpeakerInfo_forCurrentPortOtherAndBluetoothAudioRouteAvailable_shouldEnabledSpeaker() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: true, 
            currentSelectedAudioPort: .other,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.isSpeakerEnabled == true
        }
    }
    
    func testUpdateSpeakerInfo_forCurrentPortOtherAndBluetoothAudioRouteNotAvailable_shouldNotEnabledSpeaker() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: false,
            currentSelectedAudioPort: .other,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.isSpeakerEnabled == false
        }
    }
    
    func testSpeakerOnIcon_forSelectedPortHeadphones_shouldBeSpeakerOnIcon() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: false,
            currentSelectedAudioPort: .headphones,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.speakerOnIcon == .callControlSpeakerEnabled
        }
    }
    
    func testSpeakerOnIcon_forSelectedPortBuiltInSpeaker_shouldBeSpeakerOnIcon() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: false,
            currentSelectedAudioPort: .builtInSpeaker,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.speakerOnIcon == .callControlSpeakerEnabled
        }
    }
    
    func testSpeakerOnIcon_forSelectedPortOhterAndBluetoothAudioRouteAvailable_shouldBeSpeakerOnBluetoothIcon() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: true,
            currentSelectedAudioPort: .other,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.speakerOnIcon == .speakerOnBluetooth
        }
    }
    
    func testSpeakerOnIcon_forSelectedPortOhterAndBluetoothAudioRouteNotAvailable_shouldBeSpeakerOnIcon() {
        let onAudioSessionRouteChangeSubject = PassthroughSubject<AudioSessionRouteChangedReason, Never>()
        let audioSessionUseCase = MockAudioSessionUseCase(
            isBluetoothAudioRouteAvailable: false,
            currentSelectedAudioPort: .other,
            onAudioSessionRouteChangeSubject: onAudioSessionRouteChangeSubject
        )
        let sut = WaitingRoomViewModel(audioSessionUseCase: audioSessionUseCase)
        
        onAudioSessionRouteChangeSubject.send(.categoryChange)
        
        evaluate {
            sut.speakerOnIcon == .callControlSpeakerEnabled
        }
    }
    
    func testTapJoinAction_onGuestUserSetup_shouldTrackerEvent() {
        let tracker = MockTracker()
        let accountUseCase = MockAccountUseCase(isGuest: true)
        let sut = WaitingRoomViewModel(accountUseCase: accountUseCase, tracker: tracker)
        
        sut.tapJoinAction(firstName: "First", lastName: "Last")
        
        assertTrackAnalyticsEventCalled(
            trackedEventIdentifiers: tracker.trackedEventIdentifiers,
            with: [
                ScheduledMeetingJoinGuestButtonEvent()
            ]
        )
    }
    
    func testShowHostDidNotRespondAlert_onTimeout_shouldTrackerEvent() {
        let scheduledMeeting = ScheduledMeetingEntity(chatId: 100)
        let callEntity = CallEntity(status: .waitingRoom, chatId: 100, termCodeType: .waitingRoomTimeout)
        let callUpdateSubject = PassthroughSubject<CallEntity, Never>()
        let callUseCase = MockCallUseCase(callUpdateSubject: callUpdateSubject)
        let tracker = MockTracker()
        let sut = WaitingRoomViewModel(scheduledMeeting: scheduledMeeting, callUseCase: callUseCase, tracker: tracker)

        XCTAssertEqual(sut.viewState, .waitForHostToLetIn)
        
        let exp = expectation(description: "Should receive waiting room timeout change")
        
        callUseCase
            .onCallUpdate()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &subscriptions)
        
        callUpdateSubject.send(callEntity)
        
        wait(for: [exp], timeout: 0.5)
        
        assertTrackAnalyticsEventCalled(
            trackedEventIdentifiers: tracker.trackedEventIdentifiers,
            with: [
                WaitingRoomTimeoutEvent()
            ]
        )
    }
    
    // MARK: - Private methods
    
    private func sampleDate(from string: String = "12/06/2023 09:10") -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        return dateFormatter.date(from: string)
    }
    
    private func calculateVideoSize(by screenHeight: CGFloat, isLandscape: Bool) -> CGSize {
        let videoAspectRatio = isLandscape ? 424.0 / 236.0 : 236.0 / 424.0
        let videoHeight = screenHeight - (isLandscape ? 66.0 : 332.0)
        let videoWidth = videoHeight * videoAspectRatio
        return CGSize(width: videoWidth, height: videoHeight)
    }
}

// MARK: - MockWaitingRoomViewRouter

final class MockWaitingRoomViewRouter: WaitingRoomViewRouting {
    var dismiss_calledTimes = 0
    var showLeaveAlert_calledTimes = 0
    var showMeetingInfo_calledTimes = 0
    var showVideoPermissionError_calledTimes = 0
    var showAudioPermissionError_calledTimes = 0
    var showHostDenyAlert_calledTimes = 0
    var showHostDidNotRespondAlert_calledTimes = 0
    var openCallUI_calledTimes = 0
    
    func dismiss(completion: (() -> Void)?) {
        dismiss_calledTimes += 1
    }
    
    func showLeaveAlert(leaveAction: @escaping () -> Void) {
        showLeaveAlert_calledTimes += 1
    }
    
    func showMeetingInfo() {
        showMeetingInfo_calledTimes += 1
    }
    
    func showVideoPermissionError() {
        showVideoPermissionError_calledTimes += 1
    }
    
    func showAudioPermissionError() {
        showAudioPermissionError_calledTimes += 1
    }
    
    func showHostDenyAlert(leaveAction: @escaping () -> Void) {
        showHostDenyAlert_calledTimes += 1
    }
    
    func showHostDidNotRespondAlert(leaveAction: @escaping () -> Void) {
        showHostDidNotRespondAlert_calledTimes += 1
    }
    
    func openCallUI(for call: CallEntity, in chatRoom: ChatRoomEntity, isSpeakerEnabled: Bool) {
        openCallUI_calledTimes += 1
    }
}
