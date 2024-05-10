import Combine
import Foundation
import MEGADomain
import MEGAL10n
import MEGAPresentation

protocol ChatContentRouting: Routing {
    func startCallUI(chatRoom: ChatRoomEntity, call: CallEntity, isSpeakerEnabled: Bool)
    func openWaitingRoom(scheduledMeeting: ScheduledMeetingEntity)
    func showCallAlreadyInProgress(endAndJoinAlertHandler: (() -> Void)?)
    func showEndCallDialog(stayOnCallCompletion: @escaping () -> Void, endCallCompletion: @escaping () -> Void)
    func removeEndCallDialogIfNeeded()
}

enum ChatContentAction: ActionType {
    case startOrJoinCallCleanUp
    case updateCallNavigationBarButtons(_ disableCalling: Bool, _ isVoiceRecordingInProgress: Bool)
    case updateContent
    case updateChatRoom(_ chatRoom: ChatRoomEntity)
    case inviteParticipants(_ userHandles: [HandleEntity])
    case startCallBarButtonTapped(isVideoEnabled: Bool)
    case startOrJoinFloatingButtonTapped
    case returnToCallBannerButtonTapped
}

final class ChatContentViewModel: ViewModelType {
    
    enum Command: CommandType, Equatable {
        case configNavigationBar
        case tapToReturnToCallCleanUp
        case showStartOrJoinCallButton
        case showTapToReturnToCall(_ title: String)
        case enableAudioVideoButtons(_ enable: Bool)
        case hideStartOrJoinCallButton(_ hide: Bool)
        case updateNavigationBarButtonsWithAudioVideo(_ enabled: Bool)
    }
    
    struct NavBarRightItems: OptionSet {
        let rawValue: Int
        static let addParticipant = NavBarRightItems(rawValue: 1 << 0)
        static let audioCall = NavBarRightItems(rawValue: 1 << 1)
        static let videoCall = NavBarRightItems(rawValue: 1 << 2)
        static let cancel = NavBarRightItems(rawValue: 1 << 3)
        
        static let videoAndAudioCall: NavBarRightItems = [.videoCall, .audioCall]
        static let addParticipantAndAudioCall: NavBarRightItems = [.addParticipant, .audioCall]
    }
    
    var invokeCommand: ((Command) -> Void)?
        
    private var chatRoom: ChatRoomEntity
    private let chatUseCase: any ChatUseCaseProtocol
    private let chatRoomUseCase: any ChatRoomUseCaseProtocol
    private let callUseCase: any CallUseCaseProtocol
    private let scheduledMeetingUseCase: any ScheduledMeetingUseCaseProtocol
    private let audioSessionUseCase: any AudioSessionUseCaseProtocol
    private let analyticsEventUseCase: any AnalyticsEventUseCaseProtocol
    private let meetingNoUserJoinedUseCase: any MeetingNoUserJoinedUseCaseProtocol
    private let handleUseCase: any MEGAHandleUseCaseProtocol
    private let callManager: any CallManagerProtocol

    private let router: any ChatContentRouting
    private let permissionRouter: any PermissionAlertRouting
    
    private let featureFlagProvider: any FeatureFlagProviderProtocol

    private var invitedUserIdsToBypassWaitingRoom = Set<HandleEntity>()

    var timer: Timer?
    var initDuration: TimeInterval?

    private var callUpdateSubscription: AnyCancellable?
    private var endCallSubscription: AnyCancellable?
    private var noUserJoinedSubscription: AnyCancellable?

    private(set) lazy var tonePlayer = TonePlayer()

    init(chatRoom: ChatRoomEntity,
         chatUseCase: some ChatUseCaseProtocol,
         chatRoomUseCase: some ChatRoomUseCaseProtocol,
         callUseCase: some CallUseCaseProtocol,
         scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol,
         audioSessionUseCase: some AudioSessionUseCaseProtocol,
         router: some ChatContentRouting,
         permissionRouter: some PermissionAlertRouting,
         analyticsEventUseCase: some AnalyticsEventUseCaseProtocol,
         meetingNoUserJoinedUseCase: some MeetingNoUserJoinedUseCaseProtocol,
         handleUseCase: some MEGAHandleUseCaseProtocol,
         callManager: some CallManagerProtocol,
         featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider
    ) {
        self.chatRoom = chatRoom
        self.chatUseCase = chatUseCase
        self.chatRoomUseCase = chatRoomUseCase
        self.callUseCase = callUseCase
        self.scheduledMeetingUseCase = scheduledMeetingUseCase
        self.audioSessionUseCase = audioSessionUseCase
        self.router = router
        self.permissionRouter = permissionRouter
        self.analyticsEventUseCase = analyticsEventUseCase
        self.meetingNoUserJoinedUseCase = meetingNoUserJoinedUseCase
        self.handleUseCase = handleUseCase
        self.callManager = callManager
        self.featureFlagProvider = featureFlagProvider
        
        subscribeToOnCallUpdate()
        subscribeToNoUserJoinedNotification()
    }
    
    // MARK: - Dispatch actions
    
    func dispatch(_ action: ChatContentAction) {
        switch action {
        case .startOrJoinCallCleanUp:
            onUpdateStartOrJoinCallButtons()
        case .updateCallNavigationBarButtons(let disableCalling,
                                             let isVoiceRecordingInProgress):
            onUpdateNavigationBarButtonItems(disableCalling, isVoiceRecordingInProgress)
        case .updateContent:
            updateContentIfNeeded()
        case .updateChatRoom(let chatRoom):
            self.chatRoom = chatRoom
        case .inviteParticipants(let userHandles):
            inviteParticipants(userHandles)
        case .startCallBarButtonTapped(let isVideoEnabled):
            checkPermissionsAndStartCall(isVideoEnabled: isVideoEnabled, notRinging: false)
        case .startOrJoinFloatingButtonTapped:
            guard !existsOtherCallInProgress() else { return }
            checkPermissionsAndStartCall(isVideoEnabled: false, notRinging: true)
        case .returnToCallBannerButtonTapped:
            returnToCallUI()
        }
    }
    
    // MARK: - Public
    
    func determineNavBarRightItems(isEditing: Bool = false) -> NavBarRightItems {
        if isEditing {
            return .cancel
        } else if chatRoom.chatType != .oneToOne {
            if chatRoom.ownPrivilege == .moderator || chatRoom.isOpenInviteEnabled {
                return .addParticipantAndAudioCall
            } else {
                return .audioCall
            }
        } else {
            return .videoAndAudioCall
        }
    }
    
    // MARK: - Private
    
    private func updateContentIfNeeded() {
        Task {
            let scheduledMeetings = await scheduledMeetingUseCase.scheduledMeetings(by: chatRoom.chatId)
            
            guard let call = await chatUseCase.chatCall(for: chatRoom.chatId),
                  await chatUseCase.chatConnectionStatus(for: chatRoom.chatId) == .online else {
                await updateReturnToCallCleanUpButton()
                await updateStartOrJoinCallButton(scheduledMeetings)
                
                return
            }
            
            await onUpdate(for: call, with: scheduledMeetings)
        }
    }
    
    private func onChatCallUpdate(for call: CallEntity) {
        Task {
            let scheduledMeetings = await scheduledMeetingUseCase.scheduledMeetings(by: chatRoom.chatId)
            await onUpdate(for: call, with: scheduledMeetings)
        }
    }
    
    private func onUpdateStartOrJoinCallButtons() {
        Task {
            let scheduledMeetings = await scheduledMeetingUseCase.scheduledMeetings(by: chatRoom.chatId)
            await updateStartOrJoinCallButton(scheduledMeetings)
        }
    }
    
    private func onUpdateNavigationBarButtonItems(_ disableCalling: Bool,
                                                  _ isVoiceRecordingInProgress: Bool) {
        Task {
            let shouldEnable = await shouldEnableAudioVideoButtons(disableCalling, isVoiceRecordingInProgress)
            await enableNavigationBarButtonItems(shouldEnable)
        }
    }
    
    private func shouldEnableAudioVideoButtons(_ disableCalling: Bool,
                                               _ isVoiceRecordingInProgress: Bool) async -> Bool {
        let connectionStatus = await chatUseCase.chatConnectionStatus(for: chatRoom.chatId)
        let call = await chatUseCase.chatCall(for: chatRoom.chatId)
        let privilege = chatRoom.ownPrivilege
        let ownPrivilegeSmallerThanStandard = [.unknown, .removed, .readOnly].contains(privilege)
        let existsActiveCall = chatUseCase.existsActiveCall()
        let isWaitingRoomNonHost = chatRoom.isWaitingRoomEnabled && privilege != .moderator
        let shouldEnable = !(disableCalling || ownPrivilegeSmallerThanStandard || connectionStatus != .online ||
                             !MEGAReachabilityManager.isReachable() || existsActiveCall || call != nil || isVoiceRecordingInProgress || isWaitingRoomNonHost)
        
        return shouldEnable
    }
    
    @MainActor
    private func enableNavigationBarButtonItems(_ enable: Bool) {
        invokeCommand?(.enableAudioVideoButtons(enable))
    }
    
    private func startCall(enableVideo: Bool, notRinging: Bool) {
        prepareAudioForCall()
        invokeCommand?(.updateNavigationBarButtonsWithAudioVideo(true))
        let isSpeakerEnabled = enableVideo || chatRoom.isMeeting
        Task {
            do {
                let call = try await callUseCase.startCall(for: chatRoom.chatId, enableVideo: enableVideo, enableAudio: true, notRinging: notRinging)
                invokeCommand?(.updateNavigationBarButtonsWithAudioVideo(false))
                router.startCallUI(chatRoom: chatRoom, call: call, isSpeakerEnabled: isSpeakerEnabled)
            } catch {
                MEGALogDebug("Cannot start call")
            }
        }
    }
    
    private func answerCall() {
        prepareAudioForCall()
        invokeCommand?(.updateNavigationBarButtonsWithAudioVideo(true))
        callUseCase.answerCall(for: chatRoom.chatId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let call):
                invokeCommand?(.updateNavigationBarButtonsWithAudioVideo(false))
                router.startCallUI(chatRoom: chatRoom, call: call, isSpeakerEnabled: false)
            case .failure:
                MEGALogDebug("Cannot answer call")
            }
        }
    }
    
    private func prepareAudioForCall() {
        audioSessionUseCase.configureCallAudioSession()
        if chatRoom.isMeeting {
            audioSessionUseCase.enableLoudSpeaker()
        } else {
            audioSessionUseCase.disableLoudSpeaker()
        }
    }
    
    @MainActor
    private func updateStartOrJoinCallButton( _ scheduledMeetings: [ScheduledMeetingEntity]) {
        timer?.invalidate()
        invokeCommand?(.hideStartOrJoinCallButton(shouldHideStartOrJoinCallButton(scheduledMeetings: scheduledMeetings)))
    }
    
    @MainActor
    private func updateReturnToCallCleanUpButton() {
        timer?.invalidate()
        invokeCommand?(.tapToReturnToCallCleanUp)
    }
    
    @MainActor
    private func onUpdate(for call: CallEntity?, with scheduledMeetings: [ScheduledMeetingEntity]) {
        guard let call, call.chatId == chatRoom.chatId else { return }
        
        invokeCommand?(.configNavigationBar)
                
        if call.changeType == .waitingRoomUsersAllow {
            waitingRoomUsersAllow(userHandles: call.waitingRoomHandleList)
        }
        
        switch call.status {
        case .initial, .joining, .userNoPresent:
            updateStartOrJoinCallButton(scheduledMeetings)
            updateReturnToCallCleanUpButton()
            invokeCommand?(.showStartOrJoinCallButton)
        case .inProgress:
            updateStartOrJoinCallButton(scheduledMeetings)
            initTimerForCall(call)
            showCallEndTimerIfNeeded(call: call)
        case .connecting:
            invokeCommand?(.showTapToReturnToCall(Strings.Localizable.reconnecting))
        case .destroyed, .terminatingUserParticipation, .undefined:
            updateStartOrJoinCallButton(scheduledMeetings)
            updateReturnToCallCleanUpButton()
        default:
            return
        }
    }
    
    private func initTimerForCall(_ call: CallEntity) {
        initDuration = TimeInterval(call.duration)
        if !(timer?.isValid ?? false) {
            let startTime = Date().timeIntervalSince1970
            updateTapToReturnToCallLabel(withStartTime: startTime)
            
            timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                guard let self, callUseCase.call(for: chatRoom.chatId)?.status != .connecting else { return }
                updateTapToReturnToCallLabel(withStartTime: startTime)
            }
            
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
        }
    }
    
    private func updateTapToReturnToCallLabel(withStartTime startTime: TimeInterval) {
        guard let initDuration = initDuration else { return }
        
        let time = Date().timeIntervalSince1970 - startTime + initDuration
        let title = Strings.Localizable.Chat.CallInProgress.tapToReturnToCall(time.timeString)
        invokeCommand?(.showTapToReturnToCall(title))
    }
    
    private func shouldHideStartOrJoinCallButton(scheduledMeetings: [ScheduledMeetingEntity]) -> Bool {
        chatRoom.isArchived
        || chatRoom.chatType != .meeting
        || scheduledMeetings.isEmpty
        || chatUseCase.isCallInProgress(for: chatRoom.chatId)
        || !chatRoom.ownPrivilege.isUserInChat
    }
    
    private func inviteParticipants(_ userHandles: [HandleEntity]) {
        if let call = callUseCase.call(for: chatRoom.chatId),
           shouldInvitedParticipantsBypassWaitingRoom() {
            userHandles.forEach {
                invitedUserIdsToBypassWaitingRoom.insert($0)
            }
            callUseCase.allowUsersJoinCall(call, users: userHandles)
        } else {
            userHandles.forEach {
                chatRoomUseCase.invite(toChat: chatRoom, userId: $0)
            }
        }
    }
    
    private func shouldInvitedParticipantsBypassWaitingRoom() -> Bool {
        guard chatRoom.isWaitingRoomEnabled else { return false }
        let isModerator = chatRoom.ownPrivilege == .moderator
        let isOpenInviteEnabled = chatRoom.isOpenInviteEnabled
        return isModerator || isOpenInviteEnabled
    }
    
    private func waitingRoomUsersAllow(userHandles: [HandleEntity]) {
        guard let call = callUseCase.call(for: chatRoom.chatId) else { return }
        for userId in userHandles where invitedUserIdsToBypassWaitingRoom.contains(userId) {
            callUseCase.addPeer(toCall: call, peerId: userId)
            invitedUserIdsToBypassWaitingRoom.remove(userId)
        }
    }
    
    private func existsOtherCallInProgress() -> Bool {
        if chatUseCase.existsActiveCall() {
            guard let call = callUseCase.call(for: chatRoom.chatId), call.isActiveCall else {
                router.showCallAlreadyInProgress {[weak self] in
                    guard let self else { return }
                    endActiveCallAndJoinCurrentChatroomCall()
                }
                return true
            }
            return false
        } else {
            return false
        }
    }
    
    private func endActiveCallAndJoinCurrentChatroomCall() {
        if let activeCall = chatUseCase.activeCall() {
            endCall(activeCall)
        }
        checkPermissionsAndStartCall(isVideoEnabled: false, notRinging: false)
    }
    
    private func endCall(_ call: CallEntity) {
        if featureFlagProvider.isFeatureFlagEnabled(for: .callKitRefactor) {
            callManager.endCall(in: chatRoom, endForAll: false)
        } else {
            callUseCase.hangCall(for: call.callId)
            CallKitManager().endCall(call)
        }
    }
    
    private func manageStartOrJoinCall(videoCall: Bool, notRinging: Bool) {
        if shouldOpenWaitingRoom() {
            openWaitingRoom()
        } else {
            if callUseCase.call(for: chatRoom.chatId) != nil {
                answerCall()
            } else {
                if featureFlagProvider.isFeatureFlagEnabled(for: .callKitRefactor) {
                    let chatIdBase64Handle = handleUseCase.base64Handle(forUserHandle: chatRoom.chatId) ?? "Unknown"
                    callManager.startCall(in: chatRoom, chatIdBase64Handle: chatIdBase64Handle, hasVideo: videoCall, notRinging: notRinging)
                } else {
                    startCall(enableVideo: videoCall, notRinging: notRinging)
                }
            }
        }
    }
    
    private func checkPermissionsAndStartCall(isVideoEnabled: Bool, notRinging: Bool) {
        permissionRouter.requestPermissionsFor(videoCall: isVideoEnabled) { [weak self] in
            guard let self else { return }
            timer?.invalidate()
            manageStartOrJoinCall(videoCall: isVideoEnabled, notRinging: notRinging)
        }
    }
    
    private func returnToCallUI() {
        guard let call = callUseCase.call(for: chatRoom.chatId) else { return }
        let isSpeakerEnabled = AVAudioSession.sharedInstance().isOutputEqualToPortType(.builtInSpeaker)
        router.startCallUI(chatRoom: chatRoom, call: call, isSpeakerEnabled: isSpeakerEnabled)
    }
    
    private func openWaitingRoom() {
        guard let scheduledMeeting = scheduledMeetingUseCase.scheduledMeetingsByChat(chatId: chatRoom.chatId).first else { return }
        router.openWaitingRoom(scheduledMeeting: scheduledMeeting)
    }
    
    private func shouldOpenWaitingRoom() -> Bool {
        guard chatRoom.isWaitingRoomEnabled else { return false }
        return chatRoom.ownPrivilege != .moderator
    }
    
    private func showCallEndDialog(withCall call: CallEntity) {   
        router.showEndCallDialog {  [weak self] in
            self?.analyticsEventUseCase.sendAnalyticsEvent(.meetings(.stayOnCallInNoParticipantsPopup))
            self?.cancelEndCallSubscription()
        } endCallCompletion: {[weak self] in
            self?.analyticsEventUseCase.sendAnalyticsEvent(.meetings(.endCallInNoParticipantsPopup))
            self?.endCall(call)
            self?.cancelEndCallSubscription()
        }
        
        endCallSubscription = Just(Void.self)
            .delay(for: .seconds(120), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                tonePlayer.play(tone: .callEnded)
                analyticsEventUseCase.sendAnalyticsEvent(.meetings(.endCallWhenEmptyCallTimeout))
                
                // When ending call, CallKit decativation will interupt playing of tone.
                // Adding a delay of 0.7 seconds so there is enough time to play the tone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    guard let self else { return }
                    router.removeEndCallDialogIfNeeded()
                    endCall(call)
                    endCallSubscription = nil
                }
            }
    }
    
    private func cancelEndCallSubscription() {
        endCallSubscription?.cancel()
        endCallSubscription = nil
    }
    
    private func showCallEndTimerIfNeeded(call: CallEntity) {
        guard MeetingContainerRouter.isAlreadyPresented == false,
              call.changeType == .callComposition,
              call.numberOfParticipants == 1,
              call.participants.first == chatUseCase.myUserHandle() else {
            
            if call.changeType == .callComposition, call.numberOfParticipants > 1 {
                router.removeEndCallDialogIfNeeded()
                cancelEndCallSubscription()
            }
            
            return
        }
        
        showCallEndDialog(withCall: call)
    }
    
    private func subscribeToNoUserJoinedNotification() {
        noUserJoinedSubscription = meetingNoUserJoinedUseCase
            .monitor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                Task { @MainActor in 
                    guard MeetingContainerRouter.isAlreadyPresented == false,
                          let call = await self.chatUseCase.chatCall(for: self.chatRoom.chatId) else { return }
                    self.showCallEndDialog(withCall: call)
                }
            }
    }
    
    private func subscribeToOnCallUpdate() {
        callUpdateSubscription = callUseCase.onCallUpdate()
            .sink { [weak self] call in
                self?.onChatCallUpdate(for: call)
            }
    }
}
