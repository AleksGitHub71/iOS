import CallKit
import ChatRepo
import Combine
import MEGADomain
import MEGAPresentation

protocol CallsCoordinatorFactoryProtocol {
    func makeCallsCoordinator(
        callUseCase: some CallUseCaseProtocol,
        chatRoomUseCase: some ChatRoomUseCaseProtocol,
        chatUseCase: some ChatUseCaseProtocol,
        callSessionUseCase: some CallSessionUseCaseProtocol,
        scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol,
        callManager: some CallManagerProtocol,
        passcodeManager: some PasscodeManagerProtocol,
        uuidFactory: @escaping () -> UUID,
        callUpdateFactory: CXCallUpdateFactory,
        featureFlagProvider: some FeatureFlagProviderProtocol
    ) -> CallsCoordinator
}

@objc class CallsCoordinatorFactory: NSObject, CallsCoordinatorFactoryProtocol {
    func makeCallsCoordinator(callUseCase: some CallUseCaseProtocol, chatRoomUseCase: some ChatRoomUseCaseProtocol, chatUseCase: some ChatUseCaseProtocol, callSessionUseCase: some CallSessionUseCaseProtocol, scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol, callManager: some CallManagerProtocol, passcodeManager: some PasscodeManagerProtocol, uuidFactory: @escaping () -> UUID, callUpdateFactory: CXCallUpdateFactory, featureFlagProvider: some FeatureFlagProviderProtocol) -> CallsCoordinator {
        CallsCoordinator(
            callUseCase: callUseCase,
            chatRoomUseCase: chatRoomUseCase,
            chatUseCase: chatUseCase,
            callSessionUseCase: callSessionUseCase,
            scheduledMeetingUseCase: scheduledMeetingUseCase,
            callManager: callManager,
            passcodeManager: passcodeManager,
            uuidFactory: uuidFactory,
            callUpdateFactory: callUpdateFactory,
            featureFlagProvider: featureFlagProvider
        )
    }
}

@objc final class CallsCoordinator: NSObject {
    private let callUseCase: any CallUseCaseProtocol
    private let chatRoomUseCase: any ChatRoomUseCaseProtocol
    private let chatUseCase: any ChatUseCaseProtocol
    private var callSessionUseCase: any CallSessionUseCaseProtocol
    private var scheduledMeetingUseCase: any ScheduledMeetingUseCaseProtocol

    private let callManager: any CallManagerProtocol
    private var providerDelegate: CallKitProviderDelegate?
    
    private let passcodeManager: any PasscodeManagerProtocol

    private let uuidFactory: () -> UUID
    private let callUpdateFactory: CXCallUpdateFactory
    
    private let featureFlagProvider: any FeatureFlagProviderProtocol

    private var callUpdateSubscription: AnyCancellable?
    private(set) var callSessionUpdateSubscription: AnyCancellable?

    @PreferenceWrapper(key: .presentPasscodeLater, defaultValue: false, useCase: PreferenceUseCase.default)
    var presentPasscodeLater: Bool
    
    init(callUseCase: some CallUseCaseProtocol,
         chatRoomUseCase: some ChatRoomUseCaseProtocol,
         chatUseCase: some ChatUseCaseProtocol,
         callSessionUseCase: some CallSessionUseCaseProtocol,
         scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol,
         callManager: some CallManagerProtocol,
         passcodeManager: some PasscodeManagerProtocol,
         uuidFactory: @escaping () -> UUID,
         callUpdateFactory: CXCallUpdateFactory,
         featureFlagProvider: some FeatureFlagProviderProtocol
    ) {
        self.callUseCase = callUseCase
        self.chatRoomUseCase = chatRoomUseCase
        self.chatUseCase = chatUseCase
        self.callSessionUseCase = callSessionUseCase
        self.scheduledMeetingUseCase = scheduledMeetingUseCase
        self.callManager = callManager
        self.passcodeManager = passcodeManager
        self.uuidFactory = uuidFactory
        self.callUpdateFactory = callUpdateFactory
        self.featureFlagProvider = featureFlagProvider
        
        super.init()

        self.providerDelegate = CallKitProviderDelegate(callCoordinator: self, callManager: callManager)

        onCallUpdateListener()
    }
    
    // MARK: - Private

    private func onCallUpdateListener() {
        callUpdateSubscription = callUseCase.onCallUpdate()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in
                self?.onCallUpdate(call)
            }
    }

    private func onCallUpdate(_ call: CallEntity) {
        switch call.changeType {
        case .status:
            manageCallStatusChange(for: call)
        case .localAVFlags:
            updateVideoForCall(call)
        default:
            break
        }
    }
    
    private func configureCallSessionsListener(forCall call: CallEntity) {
        guard callSessionUpdateSubscription == nil else { return }
        callSessionUpdateSubscription = callSessionUseCase.onCallSessionUpdate()
            .sink { [weak self] session, call in
                guard let self else { return }
                switch session.changeType {
                case .remoteAvFlags:
                    updateVideoForCall(call)
                default:
                    break
                }
            }
    }
    
    private func manageCallStatusChange(for call: CallEntity) {
        switch call.status {
        case .userNoPresent:
            if call.isRinging {
                sendAudioPlayerInterruptDidStartNotificationIfNeeded()
            }
        case .joining:
            updateChatTitleForCall(call)
            reportCallStartedConnectingIfNeeded(call)
            callUseCase.enableAudioMonitor(forCall: call)
            configureCallSessionsListener(forCall: call)
        case .inProgress:
            reportCallConnectedIfNeeded(call)
        case .terminatingUserParticipation:
            reportEndCall(call)
            callUseCase.disableAudioMonitor(forCall: call)
            removeCallListeners()
        case .destroyed:
            reportEndCall(call)
        default:
            break
        }
    }
    
    private func removeCallListeners() {
        callSessionUpdateSubscription?.cancel()
        callSessionUpdateSubscription = nil
    }
    
    private func reportCallStartedConnectingIfNeeded(_ call: CallEntity) {
        guard let providerDelegate,
              let callUUID = uuidToReportCallConnectChanges(for: call)
        else { return }
        
        guard (callManager.call(forUUID: callUUID)?.isJoiningActiveCall ?? false) || call.isOwnClientCaller
        else { return }
        
        providerDelegate.provider.reportOutgoingCall(with: callUUID, startedConnectingAt: nil)
    }
    
    private func reportCallConnectedIfNeeded(_ call: CallEntity) {
        guard let providerDelegate,
              let callUUID = uuidToReportCallConnectChanges(for: call)
        else { return }
        
        guard (callManager.call(forUUID: callUUID)?.isJoiningActiveCall ?? false) || call.isOwnClientCaller
        else { return }
        
        providerDelegate.provider.reportOutgoingCall(with: callUUID, connectedAt: nil)
    }
    
    private func uuidToReportCallConnectChanges(for call: CallEntity) -> UUID? {
        guard let chatRoom = chatRoomUseCase.chatRoom(forChatId: call.chatId),
              let callUUID = callManager.callUUID(forChatRoom: chatRoom) else { return nil }
        return callUUID
    }
    
    private func updateChatTitleForCall(_ call: CallEntity) {
        guard let chatRoom = chatRoomUseCase.chatRoom(forChatId: call.chatId),
              let chatTitle = chatRoom.title,
              let callUUID = callManager.callUUID(forChatRoom: chatRoom) else { return }
        
        providerDelegate?.provider.reportCall(with: callUUID, updated: callUpdateFactory.callUpdate(withChatTitle: chatTitle))
    }
    
    private func updateVideoForCall(_ call: CallEntity) {
        guard let chatRoom = chatRoomUseCase.chatRoom(forChatId: call.chatId),
              let callUUID = callManager.callUUID(forChatRoom: chatRoom) else { return }
        
        var video = call.hasLocalVideo
    
        for session in call.clientSessions where session.hasVideo == true {
            video = true
            break
        }
        
        providerDelegate?.provider.reportCall(with: callUUID, updated: callUpdateFactory.callUpdate(withVideo: video))
    }
    
    private func sendAudioPlayerInterruptDidStartNotificationIfNeeded() {
        guard AudioPlayerManager.shared.isPlayerAlive() else { return }
        AudioPlayerManager.shared.audioInterruptionDidStart()
    }
    
    private func sendAudioPlayerInterruptDidEndNotificationIfNeeded() {
        guard AudioPlayerManager.shared.isPlayerAlive() else { return }
        AudioPlayerManager.shared.audioInterruptionDidEndNeedToResume(true)
    }
    
    private func startCallUI(chatRoom: ChatRoomEntity, call: CallEntity, isSpeakerEnabled: Bool) {
        Task { @MainActor in
            MeetingContainerRouter(presenter: UIApplication.mnz_presentingViewController(),
                                   chatRoom: chatRoom,
                                   call: call,
                                   isSpeakerEnabled: isSpeakerEnabled).start()
        }
    }
    
    private func isWaitingRoomOpened(inChatRoom chatRoom: ChatRoomEntity) -> Bool {
        guard chatRoom.isWaitingRoomEnabled else { return false }
        return chatRoom.ownPrivilege != .moderator
    }
}

extension CallsCoordinator: CallsCoordinatorProtocol {
    func startCall(_ callActionSync: CallActionSync) async -> Bool {
        let isSpeakerEnabled = callActionSync.videoEnabled || callActionSync.chatRoom.isMeeting
        do {
            let call = try await callUseCase.startCall(for: callActionSync.chatRoom.chatId, enableVideo: callActionSync.videoEnabled, enableAudio: callActionSync.audioEnabled, notRinging: callActionSync.notRinging)
            if !isWaitingRoomOpened(inChatRoom: callActionSync.chatRoom) {
                startCallUI(chatRoom: callActionSync.chatRoom, call: call, isSpeakerEnabled: isSpeakerEnabled)
            }
            return true
        } catch {
            MEGALogError("[CallsCoordinator] Cannot start call in chat room \(callActionSync.chatRoom.chatId)")
            return false
        }
    }
    
    func answerCall(_ callActionSync: CallActionSync) async -> Bool {
        do {
            let call = try await callUseCase.answerCall(for: callActionSync.chatRoom.chatId, enableVideo: callActionSync.videoEnabled, enableAudio: callActionSync.audioEnabled)
            if !isWaitingRoomOpened(inChatRoom: callActionSync.chatRoom) {
                startCallUI(chatRoom: callActionSync.chatRoom, call: call, isSpeakerEnabled: callActionSync.chatRoom.isMeeting)
            }
            return true
        } catch {
            MEGALogError("[CallsCoordinator] Cannot answer call in chat room \(callActionSync.chatRoom.chatId)")
            return false
        }
    }
    
    func endCall(_ callActionSync: CallActionSync) async -> Bool {
        guard let call = callUseCase.call(for: callActionSync.chatRoom.chatId) else { return false }
        
        // If call is reported but user ignored CallKit notification or the call was missed, we need to report end call and remove the it from our calls dictionary
        if call.status == .userNoPresent {
            reportEndCall(call)
        } else {
            if callActionSync.endForAll {
                callUseCase.endCall(for: call.callId)
            } else {
                callUseCase.hangCall(for: call.callId)
            }
        }
        return true
    }
    
    func muteCall(_ callActionSync: CallActionSync) async -> Bool {
        do {
            if callActionSync.audioEnabled {
                try await callUseCase.enableAudioForCall(in: callActionSync.chatRoom)
            } else {
                try await callUseCase.disableAudioForCall(in: callActionSync.chatRoom)
            }
            return true
        } catch {
            MEGALogDebug("[CallsCoordinator] muteCall failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func reportIncomingCall(in chatId: ChatIdEntity, completion: @escaping () -> Void) {
        guard let chatRoom = chatRoomUseCase.chatRoom(forChatId: chatId) else {
            return
        }
        
        let incomingCallUUID = uuidFactory()
        
        callManager.addIncomingCall(
            withUUID: incomingCallUUID,
            chatRoom: chatRoom
        )

        let update = callUpdateFactory.createCallUpdate(title: chatRoom.title ?? "Unknown")
        
        MEGALogDebug("[CallKit] Provider report new incoming call")
        providerDelegate?.provider.reportNewIncomingCall(with: incomingCallUUID, update: update) { error in
            guard error == nil else {
                MEGALogError("[CallKit] Provider Error reporting incoming call: \(String(describing: error))")
                return
            }
            completion()
        }
    }
    
    func reportEndCall(_ call: CallEntity) {
        MEGALogDebug("[CallKit] Report end call \(call)")

        guard let chatRoom = chatRoomUseCase.chatRoom(forChatId: call.chatId),
              let callUUID = callManager.callUUID(forChatRoom: chatRoom) else { return }
        
        var callEndedReason: CXCallEndedReason?
        switch call.termCodeType {
        case .invalid, .error, .tooManyParticipants, .tooManyClients, .protocolVersion:
            callEndedReason = .failed
        case .reject, .userHangup, .noParticipate, .kicked, .callDurationLimit, .callUsersLimit:
            callEndedReason = .remoteEnded
        case .waitingRoomTimeout:
            callEndedReason = .unanswered
        default:
            for handle in call.participants where chatUseCase.myUserHandle() == handle {
                callEndedReason = .answeredElsewhere
                break
            }
        }
        
        callManager.removeCall(withUUID: callUUID)
        guard let callEndedReason else { return }
        MEGALogDebug("[CallKit] Report end call reason \(callEndedReason.rawValue)")
        providerDelegate?.provider.reportCall(with: callUUID, endedAt: nil, reason: callEndedReason)
        
        sendAudioPlayerInterruptDidEndNotificationIfNeeded()
    }
    
    @MainActor func disablePassCodeIfNeeded() {
        if passcodeManager.shouldPresentPasscodeViewLater() {
            presentPasscodeLater = true
            passcodeManager.closePasscodeView()
        }
        passcodeManager.disablePasscodeWhenApplicationEntersBackground()
    }
    
    // Callkit abnormal behaviour when trying to enable loudspeaker from the lock screen.
    // Solution provided in the below link.
    // https://stackoverflow.com/questions/48023629/abnormal-behavior-of-speaker-button-on-system-provided-call-screen?rq=1
    func configureWebRTCAudioSession() {
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            let audioSession = RTCAudioSession.sharedInstance()
            audioSession.lockForConfiguration()
            let configuration = RTCAudioSessionConfiguration.webRTC()
            configuration.categoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
            try? audioSession.setConfiguration(configuration)
            audioSession.unlockForConfiguration()
        }
    }
}
