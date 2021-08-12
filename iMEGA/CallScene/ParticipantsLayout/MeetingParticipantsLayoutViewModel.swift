
protocol MeetingParticipantsLayoutRouting: Routing {
    func dismissAndShowPasscodeIfNeeded()
    func showRenameChatAlert()
    func didAddFirstParticipant()
}

enum CallViewAction: ActionType {
    case onViewLoaded
    case onViewReady
    case tapOnView(onParticipantsView: Bool)
    case tapOnLayoutModeButton
    case tapOnOptionsMenuButton(presenter: UIViewController, sender: UIBarButtonItem)
    case tapOnBackButton
    case switchIphoneOrientation(_ orientation: DeviceOrientation)
    case showRenameChatAlert
    case didAddFirstParticipant
    case setNewTitle(String)
    case discardChangeTitle
    case renameTitleDidChange(String)
    case tapParticipantToPinAsSpeaker(CallParticipantEntity, IndexPath)
    case fetchAvatar(participant: CallParticipantEntity)
    case fetchSpeakerAvatar
}

enum CallLayoutMode {
    case grid
    case speaker
}

enum DeviceOrientation {
    case landscape
    case portrait
}

private enum CallViewModelConstant {
    static let maxParticipantsCountForHighResolution = 5
}

final class MeetingParticipantsLayoutViewModel: NSObject, ViewModelType {
    enum Command: CommandType, Equatable {
        case configView(title: String, subtitle: String, isUserAGuest: Bool, isOneToOne: Bool)
        case configLocalUserView(position: CameraPositionEntity)
        case switchMenusVisibility
        case toggleLayoutButton
        case switchLayoutMode(layout: CallLayoutMode, participantsCount: Int)
        case switchLocalVideo
        case updateName(String)
        case updateDuration(String)
        case updatePageControl(Int)
        case insertParticipant([CallParticipantEntity])
        case deleteParticipantAt(Int, [CallParticipantEntity])
        case updateParticipantAt(Int, [CallParticipantEntity])
        case updateSpeakerViewFor(CallParticipantEntity?)
        case localVideoFrame(Int, Int, Data)
        case participantAdded(String)
        case participantRemoved(String)
        case reconnecting
        case reconnected
        case updateCameraPositionTo(position: CameraPositionEntity)
        case updatedCameraPosition
        case showRenameAlert(title: String, isMeeting: Bool)
        case enableRenameButton(Bool)
        case showNoOneElseHereMessage
        case showWaitingForOthersMessage
        case hideEmptyRoomMessage
        case startCompatibilityWarningViewTimer
        case removeCompatibilityWarningView
        case updateHasLocalAudio(Bool)
        case selectPinnedCellAt(IndexPath?)
        case shouldHideSpeakerView(Bool)
        case ownPrivilegeChangedToModerator
        case lowNetworkQuality
        case updateAvatar(UIImage, CallParticipantEntity)
        case updateSpeakerAvatar(UIImage)
        case updateMyAvatar(UIImage)
    }
    
    private let router: MeetingParticipantsLayoutRouting
    private var chatRoom: ChatRoomEntity
    private var call: CallEntity
    private var timer: Timer?
    private var callDurationInfo: CallDurationInfo?
    private var callParticipants = [CallParticipantEntity]()
    private var speakerParticipant: CallParticipantEntity? {
        didSet(newValue) {
            invokeCommand?(.updateSpeakerViewFor(speakerParticipant))
        }
    }
    private var isSpeakerParticipantPinned: Bool = false
    internal var layoutMode: CallLayoutMode = .grid
    private var localVideoEnabled: Bool = false
    private var reconnecting: Bool = false
    private var switchingCamera: Bool = false
    private weak var containerViewModel: MeetingContainerViewModel?

    private let callUseCase: CallUseCaseProtocol
    private let captureDeviceUseCase: CaptureDeviceUseCaseProtocol
    private let localVideoUseCase: CallLocalVideoUseCaseProtocol
    private let remoteVideoUseCase: CallRemoteVideoUseCaseProtocol
    private let chatRoomUseCase: ChatRoomUseCaseProtocol
    private let userUseCase: UserUseCaseProtocol
    private let userImageUseCase: UserImageUseCaseProtocol

    // MARK: - Internal properties
    var invokeCommand: ((Command) -> Void)?
    
    init(router: MeetingParticipantsLayoutRouting,
         containerViewModel: MeetingContainerViewModel,
         callUseCase: CallUseCaseProtocol,
         captureDeviceUseCase: CaptureDeviceUseCaseProtocol,
         localVideoUseCase: CallLocalVideoUseCaseProtocol,
         remoteVideoUseCase: CallRemoteVideoUseCaseProtocol,
         chatRoomUseCase: ChatRoomUseCaseProtocol,
         userUseCase: UserUseCaseProtocol,
         userImageUseCase: UserImageUseCaseProtocol,
         chatRoom: ChatRoomEntity,
         call: CallEntity) {
        
        self.router = router
        self.containerViewModel = containerViewModel
        self.callUseCase = callUseCase
        self.captureDeviceUseCase = captureDeviceUseCase
        self.localVideoUseCase = localVideoUseCase
        self.remoteVideoUseCase = remoteVideoUseCase
        self.chatRoomUseCase = chatRoomUseCase
        self.userUseCase = userUseCase
        self.userImageUseCase = userImageUseCase
        self.chatRoom = chatRoom
        self.call = call

        super.init()
    }
    
    deinit {
        callUseCase.stopListeningForCall()
    }
    
    private func initTimerIfNeeded(with duration: Int) {
        if timer == nil {
            let callDurationInfo = CallDurationInfo(initDuration: duration, baseDate: Date())
            let timer = Timer(timeInterval: 1, repeats: true, block: { [weak self] (timer) in
                let duration = Int(Date().timeIntervalSince1970) - Int(callDurationInfo.baseDate.timeIntervalSince1970) + callDurationInfo.initDuration
                self?.invokeCommand?(.updateDuration(NSString.mnz_string(fromTimeInterval: TimeInterval(duration))))
            })
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }
    
    private func forceGridLayout() {
        if layoutMode == .grid {
            return
        }
        layoutMode = .grid
        invokeCommand?(.switchLayoutMode(layout: layoutMode, participantsCount: callParticipants.count))
    }
    
    private func switchLayout() {
        callParticipants.forEach { $0.videoDataDelegate = nil }
        if layoutMode == .grid {
            layoutMode = .speaker
            let participantsWithHighResolutionNoSpeaker = callParticipants.filter { $0.canReceiveVideoHiRes && $0.video == .on && $0.speakerVideoDataDelegate == nil }.map { $0.clientId }
            switchVideoResolutionHighToLow(for: participantsWithHighResolutionNoSpeaker, in: chatRoom.chatId)
        } else {
            layoutMode = .grid
            switchVideoResolutionBasedOnParticipantsCount()
        }
        invokeCommand?(.switchLayoutMode(layout: layoutMode, participantsCount: callParticipants.count))
        
        if speakerParticipant == nil {
            speakerParticipant = callParticipants.first
        }
    }
    
    private func updateParticipant(_ participant: CallParticipantEntity) {
        guard let index = callParticipants.firstIndex(of: participant) else { return }
        invokeCommand?(.updateParticipantAt(index, callParticipants))
        
        guard let currentSpeaker = speakerParticipant, currentSpeaker == participant else {
            return
        }
        speakerParticipant = participant
    }
    
    private func enableRemoteVideo(for participant: CallParticipantEntity) {
        switch layoutMode {
        case .grid:
            if callParticipants.count <= CallViewModelConstant.maxParticipantsCountForHighResolution {
                if participant.isVideoHiRes && participant.canReceiveVideoHiRes {
                    MEGALogDebug("Enable remote video grid view high resolution")
                    remoteVideoUseCase.enableRemoteVideo(for: participant)
                } else {
                    switchVideoResolutionLowToHigh(for: [participant.clientId], in: chatRoom.chatId)
                }
            } else {
                if participant.isVideoLowRes && participant.canReceiveVideoLowRes {
                    MEGALogDebug("Enable remote video grid view low resolution")
                    remoteVideoUseCase.enableRemoteVideo(for: participant)
                } else {
                    switchVideoResolutionHighToLow(for: [participant.clientId], in: chatRoom.chatId)
                }
            }
        case .speaker:
            if participant.speakerVideoDataDelegate == nil {
                if participant.isVideoLowRes && participant.canReceiveVideoLowRes {
                    MEGALogDebug("Enable remote video speaker view low resolution for no speaker")
                    remoteVideoUseCase.enableRemoteVideo(for: participant)
                } else {
                    switchVideoResolutionHighToLow(for: [participant.clientId], in: chatRoom.chatId)
                }
            } else {
                if participant.isVideoHiRes && participant.canReceiveVideoHiRes {
                    MEGALogDebug("Enable remote video speaker view high resolution for speaker")
                    remoteVideoUseCase.enableRemoteVideo(for: participant)
                } else {
                    switchVideoResolutionLowToHigh(for: [participant.clientId], in: chatRoom.chatId)
                }
            }
        }
    }
    
    private func disableRemoteVideo(for participant: CallParticipantEntity) {
        MEGALogDebug("Disable remote video")
        remoteVideoUseCase.disableRemoteVideo(for: participant)
    }
    
    private func fetchAvatar(for participant: CallParticipantEntity, name: String, completion: @escaping ((UIImage) -> Void)) {
        userImageUseCase.fetchUserAvatar(withUserHandle: participant.participantId, name: name) { result in
            switch result {
            case .success(let image):
                completion(image)
            case .failure(_):
                MEGALogError("Error fetching avatar for participant \(MEGASdk.base64Handle(forUserHandle: participant.participantId) ?? "No name")")
            }
        }
    }
    
    private func participantName(for userHandle: MEGAHandle, completion: @escaping (String?) -> Void) {
        chatRoomUseCase.userDisplayName(forPeerId: userHandle, chatId: chatRoom.chatId) { result in
            switch result {
            case .success(let displayName):
                completion(displayName)
            case .failure(let error):
                MEGALogDebug("ParticipantViewModel: failed to get the user display name for \(MEGASdk.base64Handle(forUserHandle: userHandle) ?? "No name") - \(error)")
                completion(nil)
            }
        }
    }
    
    private func isBackCameraSelected() -> Bool {
        guard let selectCameraLocalizedString = captureDeviceUseCase.wideAngleCameraLocalizedName(postion: .back),
              localVideoUseCase.videoDeviceSelected() == selectCameraLocalizedString else {
            return false
        }
        
        return true
    }
    
    private func initialSubtitle() -> String {
        if call.isRinging || call.status == .joining {
            return NSLocalizedString("connecting", comment: "")
        } else {
            return NSLocalizedString("calling...", comment: "")
        }
    }
    
    private func isActiveCall() -> Bool {
        callParticipants.isEmpty && !call.clientSessions.isEmpty
    }
    
    // MARK: - Dispatch action
    func dispatch(_ action: CallViewAction) {
        switch action {
        case .onViewLoaded:
            if let updatedCall = callUseCase.call(for: chatRoom.chatId) {
                call = updatedCall
            }
            if chatRoom.chatType == .meeting {
                invokeCommand?(
                    .configView(title: chatRoom.title ?? "",
                                subtitle: "",
                                isUserAGuest: userUseCase.isGuest,
                                isOneToOne: false)
                )
                initTimerIfNeeded(with: Int(call.duration))
            } else {
                invokeCommand?(
                    .configView(title: chatRoom.title ?? "",
                                subtitle: initialSubtitle(),
                                isUserAGuest: userUseCase.isGuest,
                                isOneToOne: chatRoom.chatType == .oneToOne)
                )
            }
            callUseCase.startListeningForCallInChat(chatRoom.chatId, callbacksDelegate: self)
            remoteVideoUseCase.addRemoteVideoListener(self)
            if isActiveCall() {
                callUseCase.createActiveSessions()
            } else {
                if chatRoom.chatType == .meeting {
                    invokeCommand?(.showWaitingForOthersMessage)
                }
                
                if call.numberOfParticipants < 2 {
                    invokeCommand?(.startCompatibilityWarningViewTimer)
                }
            }
            localAvFlagsUpdated(video: call.hasLocalVideo, audio: call.hasLocalAudio)
        case .onViewReady:
            if let myself = CallParticipantEntity.myself(chatId: call.chatId) {
                fetchAvatar(for: myself, name: myself.name ?? "Unknown") { [weak self] image in
                    self?.invokeCommand?(.updateMyAvatar(image))
                }
            }
            invokeCommand?(.configLocalUserView(position: isBackCameraSelected() ? .back : .front))
        case .tapOnView(let onParticipantsView):
            if onParticipantsView && layoutMode == .speaker && !callParticipants.isEmpty {
                return
            }
            invokeCommand?(.switchMenusVisibility)
            containerViewModel?.dispatch(.changeMenuVisibility)
        case .tapOnLayoutModeButton:
            switchLayout()
        case .tapOnOptionsMenuButton(let presenter, let sender):
            containerViewModel?.dispatch(.showOptionsMenu(presenter: presenter, sender: sender, isMyselfModerator: chatRoom.ownPrivilege == .moderator))
        case .tapOnBackButton:
            callUseCase.stopListeningForCall()
            timer?.invalidate()
            remoteVideoUseCase.disableAllRemoteVideos()
            containerViewModel?.dispatch(.tapOnBackButton)
        case .switchIphoneOrientation(let orientation):
            switch orientation {
            case .landscape:
                forceGridLayout()
                invokeCommand?(.toggleLayoutButton)
            case .portrait:
                invokeCommand?(.toggleLayoutButton)
            }
        case .showRenameChatAlert:
            invokeCommand?(.showRenameAlert(title: chatRoom.title ?? "", isMeeting: chatRoom.chatType == .meeting))
        case .setNewTitle(let newTitle):
            chatRoomUseCase.renameChatRoom(chatId: chatRoom.chatId, title: newTitle) { [weak self] result in
                switch result {
                case .success(let title):
                    self?.invokeCommand?(.updateName(title))
                case .failure(_):
                    MEGALogDebug("Could not change the chat title")
                }
                self?.containerViewModel?.dispatch(.changeMenuVisibility)
            }
        case .discardChangeTitle:
            containerViewModel?.dispatch(.changeMenuVisibility)
        case .renameTitleDidChange(let newTitle):
            invokeCommand?(.enableRenameButton(chatRoom.title != newTitle && !newTitle.isEmpty))
        case .tapParticipantToPinAsSpeaker(let participant, let indexPath):
            tappedParticipant(participant, at: indexPath)
        case .didAddFirstParticipant:
            invokeCommand?(.startCompatibilityWarningViewTimer)
        case .fetchAvatar(let participant):
            participantName(for: participant.participantId) { [weak self] name in
                guard let name = name else { return }
                self?.fetchAvatar(for: participant, name: name) { [weak self] image in
                    self?.invokeCommand?(.updateAvatar(image, participant))
                }
            }
        case .fetchSpeakerAvatar:
            guard let speakerParticipant = speakerParticipant else { return }
            participantName(for: speakerParticipant.participantId) { [weak self] name in
                guard let name = name else { return }
                self?.fetchAvatar(for: speakerParticipant, name: name) { image in
                    self?.invokeCommand?(.updateSpeakerAvatar(image))
                }
            }
        }
    }
    
    private func tappedParticipant(_ participant: CallParticipantEntity, at indexPath: IndexPath) {
        if !isSpeakerParticipantPinned || (isSpeakerParticipantPinned && speakerParticipant != participant) {
            speakerParticipant?.speakerVideoDataDelegate = nil
            speakerParticipant?.isSpeakerPinned = false
            isSpeakerParticipantPinned = true
            participant.isSpeakerPinned = true
            speakerParticipant = participant
            invokeCommand?(.selectPinnedCellAt(indexPath))
        } else {
            participant.isSpeakerPinned = false
            isSpeakerParticipantPinned = false
            invokeCommand?(.selectPinnedCellAt(nil))
        }
    }
    
    private func switchVideoResolutionHighToLow(for clientIds: [MEGAHandle], in chatId: MEGAHandle) {
        if clientIds.count == 0 {
            return
        }
        remoteVideoUseCase.stopHighResolutionVideo(for: chatRoom.chatId, clientIds: clientIds) {  [weak self] result in
            switch result {
            case .success:
                self?.remoteVideoUseCase.requestLowResolutionVideos(for: chatId, clientIds: clientIds) { result in
                    switch result {
                    case .success:
                        MEGALogDebug("Success to request low resolution video")
                    case .failure(_):
                        MEGALogError("Fail to request low resolution video")
                    }
                }
            case .failure(_):
                MEGALogError("Fail to stop high resolution video")
            }
        }
    }
    
    private func switchVideoResolutionLowToHigh(for clientIds: [MEGAHandle], in chatId: MEGAHandle) {
        if clientIds.count == 0 {
            return
        }
        remoteVideoUseCase.stopLowResolutionVideo(for: chatRoom.chatId, clientIds: clientIds) { [weak self] result in
            switch result {
            case .success:
                clientIds.forEach { clientId in
                    self?.remoteVideoUseCase.requestHighResolutionVideo(for: chatId, clientId: clientId) { result in
                        switch result {
                        case .success:
                            MEGALogDebug("Success to request high resolution video")
                        case .failure(_):
                            MEGALogError("Fail to request high resolution video")
                        }
                    }
                }
            case .failure(_):
                MEGALogError("Fail to stop low resolution video")
            }
        }
    }
    
    private func switchVideoResolutionBasedOnParticipantsCount() {
        if callParticipants.count <= CallViewModelConstant.maxParticipantsCountForHighResolution {
            let participantsWithLowResolution = callParticipants.filter { $0.canReceiveVideoLowRes && $0.video == .on }.map { $0.clientId }
            switchVideoResolutionLowToHigh(for: participantsWithLowResolution, in: chatRoom.chatId)
        } else {
            let participantsWithHighResolution = callParticipants.filter { $0.canReceiveVideoHiRes && $0.video == .on }.map { $0.clientId }
            switchVideoResolutionHighToLow(for: participantsWithHighResolution, in: chatRoom.chatId)
        }
    }
}

struct CallDurationInfo {
    let initDuration: Int
    let baseDate: Date
}

extension MeetingParticipantsLayoutViewModel: CallCallbacksUseCaseProtocol {
    func attendeeJoined(attendee: CallParticipantEntity) {
        initTimerIfNeeded(with: Int(call.duration))
        invokeCommand?(.removeCompatibilityWarningView)
        participantName(for: attendee.participantId) { [weak self] in
            attendee.name = $0
            if attendee.video == .on {
                self?.enableRemoteVideo(for: attendee)
            }
            self?.callParticipants.append(attendee)
            self?.invokeCommand?(.insertParticipant(self?.callParticipants ?? []))
            if self?.callParticipants.count == 1 && self?.layoutMode == .speaker {
                self?.invokeCommand?(.shouldHideSpeakerView(false))
                self?.speakerParticipant = self?.callParticipants.first
            }
            if self?.layoutMode == .grid {
                self?.invokeCommand?(.updatePageControl(self?.callParticipants.count ?? 0))
            }
            self?.invokeCommand?(.hideEmptyRoomMessage)
        }
    }
    
    func attendeeLeft(attendee: CallParticipantEntity) {
        if callUseCase.call(for: call.chatId) == nil {
            callTerminated()
        } else if let index = callParticipants.firstIndex(of: attendee) {
            if attendee.video == .on {
                remoteVideoUseCase.disableRemoteVideo(for: callParticipants[index])
            }
            callParticipants.remove(at: index)
            invokeCommand?(.deleteParticipantAt(index, callParticipants))
            
            if callParticipants.isEmpty {
                if chatRoom.chatType == .meeting && !reconnecting {
                    invokeCommand?(.showNoOneElseHereMessage)
                }
                if layoutMode == .speaker {
                    invokeCommand?(.shouldHideSpeakerView(true))
                }
            }
            
            if layoutMode == .grid {
                invokeCommand?(.updatePageControl(callParticipants.count))
            }
            
            guard let currentSpeaker = speakerParticipant, currentSpeaker == attendee else {
                return
            }
            isSpeakerParticipantPinned = false
            speakerParticipant = callParticipants.first
        } else {
            MEGALogError("Error removing participant from call")
        }
    }
    
    func updateAttendee(_ attendee: CallParticipantEntity) {
        guard let participantUpdated = callParticipants.filter({$0 == attendee}).first else {
            MEGALogError("Error getting participant updated")
            return
        }
        if participantUpdated.video == .off && attendee.video == .on {
            participantUpdated.video = .on
            enableRemoteVideo(for: participantUpdated)
        } else if participantUpdated.video == .on && attendee.video == .off {
            participantUpdated.video = .off
            disableRemoteVideo(for: participantUpdated)
        }

        participantUpdated.audio = attendee.audio
        updateParticipant(participantUpdated)
    }
    
    func remoteVideoResolutionChanged(for attendee: CallParticipantEntity) {
        guard let participantUpdated = callParticipants.filter({$0 == attendee}).first else {
            MEGALogError("Error getting participant updated with video resolution")
            return
        }
        if (participantUpdated.canReceiveVideoLowRes != attendee.canReceiveVideoLowRes || participantUpdated.canReceiveVideoHiRes != attendee.canReceiveVideoHiRes) && participantUpdated.video == .on {
            disableRemoteVideo(for: participantUpdated)
            participantUpdated.isVideoLowRes = attendee.isVideoLowRes
            participantUpdated.isVideoHiRes = attendee.isVideoHiRes
            participantUpdated.canReceiveVideoLowRes = attendee.canReceiveVideoLowRes
            participantUpdated.canReceiveVideoHiRes = attendee.canReceiveVideoHiRes
            enableRemoteVideo(for: participantUpdated)
        }
    }
    
    func audioLevel(for attendee: CallParticipantEntity) {
        if isSpeakerParticipantPinned {
            return
        }
        guard let participantWithAudio = callParticipants.filter({$0 == attendee}).first else {
            MEGALogError("Error getting participant with audio")
            return
        }
        if let currentSpeaker = speakerParticipant {
            if currentSpeaker != participantWithAudio {
                currentSpeaker.speakerVideoDataDelegate = nil
                speakerParticipant = participantWithAudio
                if layoutMode == .speaker {
                    if currentSpeaker.video == .on && currentSpeaker.canReceiveVideoHiRes {
                        switchVideoResolutionHighToLow(for: [currentSpeaker.clientId], in: chatRoom.chatId)
                    }
                    if participantWithAudio.video == .on && participantWithAudio.canReceiveVideoLowRes {
                        switchVideoResolutionLowToHigh(for: [participantWithAudio.clientId], in: chatRoom.chatId)
                    }
                }
            }
        } else {
            speakerParticipant = participantWithAudio
            if layoutMode == .speaker && participantWithAudio.video == .on && participantWithAudio.canReceiveVideoLowRes {
                switchVideoResolutionLowToHigh(for: [participantWithAudio.clientId], in: chatRoom.chatId)
            }
        }
    }
    
    func callTerminated() {
        callUseCase.stopListeningForCall()
        timer?.invalidate()
        router.dismissAndShowPasscodeIfNeeded()
    }
    
    func participantAdded(with handle: MEGAHandle) {
        participantName(for: handle) { [weak self] displayName in
            guard let displayName = displayName else { return }
            self?.invokeCommand?(.participantAdded(displayName))
        }
        switchVideoResolutionBasedOnParticipantsCount()
    }
    
    func participantRemoved(with handle: MEGAHandle) {
        participantName(for: handle) { [weak self] displayName in
            guard let displayName = displayName else { return }
            self?.invokeCommand?(.participantRemoved(displayName))
        }
        switchVideoResolutionBasedOnParticipantsCount()
    }
    
    func connecting() {
        if !reconnecting {
            reconnecting = true
            invokeCommand?(.reconnecting)
            invokeCommand?(.hideEmptyRoomMessage)
        }
    }
    
    func inProgress() {
        if reconnecting {
            invokeCommand?(.reconnected)
            reconnecting = false
            if callParticipants.isEmpty {
                invokeCommand?(.showNoOneElseHereMessage)
            }
        }
    }
    
    func localAvFlagsUpdated(video: Bool, audio: Bool) {
        if localVideoEnabled != video {
            if localVideoEnabled {
                localVideoUseCase.removeLocalVideo(for: chatRoom.chatId, callbacksDelegate: self)
            } else {
                localVideoUseCase.addLocalVideo(for: chatRoom.chatId, callbacksDelegate: self)
            }
            localVideoEnabled = video
            invokeCommand?(.switchLocalVideo)
        }
        invokeCommand?(.updateHasLocalAudio(audio))
    }
    
    func ownPrivilegeChanged(to privilege: ChatRoomEntity.Privilege, in chatRoom: ChatRoomEntity) {
        if self.chatRoom.ownPrivilege != chatRoom.ownPrivilege && privilege == .moderator {
            invokeCommand?(.ownPrivilegeChangedToModerator)
        }
        self.chatRoom = chatRoom
    }
    
    func chatTitleChanged(chatRoom: ChatRoomEntity) {
        self.chatRoom = chatRoom
        guard let title = chatRoom.title else { return }
        invokeCommand?(.updateName(title))
    }
    
    func networkQuality() {
        invokeCommand?(.lowNetworkQuality)
    }
}

extension MeetingParticipantsLayoutViewModel: CallLocalVideoCallbacksUseCaseProtocol {
    func localVideoFrameData(width: Int, height: Int, buffer: Data) {
        invokeCommand?(.localVideoFrame(width, height, buffer))
        
        if switchingCamera {
            switchingCamera = false
            invokeCommand?(.updatedCameraPosition)
        }
    }
    
    func localVideoChangedCameraPosition() {
        switchingCamera = true
        invokeCommand?(.updateCameraPositionTo(position: isBackCameraSelected() ? .back : .front))
    }
}

extension MeetingParticipantsLayoutViewModel: CallRemoteVideoListenerUseCaseProtocol {
    func remoteVideoFrameData(clientId: MEGAHandle, width: Int, height: Int, buffer: Data) {
        guard let participant = callParticipants.filter({ $0.clientId == clientId }).first else {
            MEGALogError("Error getting participant from remote video frame")
            return
        }
        if participant.videoDataDelegate == nil {
            guard let index = callParticipants.firstIndex(of: participant) else { return }
            invokeCommand?(.updateParticipantAt(index, callParticipants))
        }
        participant.remoteVideoFrame(width: width, height: height, buffer: buffer)
    }
}
