import Combine
import MEGADomain
import MEGAL10n
import MEGAPresentation

enum MeetingContainerAction: ActionType {
    case onViewReady
    case hangCall(presenter: UIViewController?, sender: UIButton?)
    case tapOnBackButton
    case changeMenuVisibility
    case showOptionsMenu(presenter: UIViewController, sender: UIBarButtonItem, isMyselfModerator: Bool)
    case hideOptionsMenu
    case shareLink(presenter: UIViewController?, sender: AnyObject, completion: UIActivityViewController.CompletionWithItemsHandler?)
    case renameChat
    case dismissCall(completion: (() -> Void)?)
    case endGuestUserCall(completion: (() -> Void)?)
    case speakerEnabled(_ enabled: Bool)
    case displayParticipantInMainView(_ participant: CallParticipantEntity)
    case didDisplayParticipantInMainView(_ participant: CallParticipantEntity)
    case didSwitchToGridView
    case participantAdded
    case participantRemoved
    case showEndCallDialogIfNeeded
    case removeEndCallAlertAndEndCall
    case showJoinMegaScreen
    case showHangOrEndCallDialog
    case endCallForAll
    case participantJoinedWaitingRoom
    case showScreenShareWarning
    case leaveCallFromRecordingAlert
}

final class MeetingContainerViewModel: ViewModelType {
    enum Command: CommandType, Equatable {
    }
    
    private enum Constants {
        static let muteMicTimerDuration = 60 // 1 minute
    }
    
    private let router: any MeetingContainerRouting
    private let chatRoom: ChatRoomEntity
    private let callUseCase: any CallUseCaseProtocol
    private let callCoordinatorUseCase: any CallCoordinatorUseCaseProtocol
    private let accountUseCase: any AccountUseCaseProtocol
    private let chatRoomUseCase: any ChatRoomUseCaseProtocol
    private let chatUseCase: any ChatUseCaseProtocol
    private let scheduledMeetingUseCase: any ScheduledMeetingUseCaseProtocol
    private let authUseCase: any AuthUseCaseProtocol
    private let noUserJoinedUseCase: any MeetingNoUserJoinedUseCaseProtocol
    private let analyticsEventUseCase: any AnalyticsEventUseCaseProtocol
    private let megaHandleUseCase: any MEGAHandleUseCaseProtocol
    private var noUserJoinedSubscription: AnyCancellable?
    private var muteMicSubscription: AnyCancellable?
    private var muteUnmuteFailedNotificationsSubscription: AnyCancellable?
    private var seeWaitingRoomListEventSubscription: AnyCancellable?

    private var call: CallEntity? {
        callUseCase.call(for: chatRoom.chatId)
    }
    
    private var isOneToOneChat: Bool {
        chatRoomUseCase.chatRoom(forChatId: chatRoom.chatId)?.chatType == .oneToOne
    }

    init(router: some MeetingContainerRouting,
         chatRoom: ChatRoomEntity,
         callUseCase: some CallUseCaseProtocol,
         chatRoomUseCase: some ChatRoomUseCaseProtocol,
         chatUseCase: some ChatUseCaseProtocol,
         scheduledMeetingUseCase: some ScheduledMeetingUseCaseProtocol,
         callCoordinatorUseCase: some CallCoordinatorUseCaseProtocol,
         accountUseCase: some AccountUseCaseProtocol,
         authUseCase: some AuthUseCaseProtocol,
         noUserJoinedUseCase: some MeetingNoUserJoinedUseCaseProtocol,
         analyticsEventUseCase: some AnalyticsEventUseCaseProtocol,
         megaHandleUseCase: some MEGAHandleUseCaseProtocol) {
        self.router = router
        self.chatRoom = chatRoom
        self.callUseCase = callUseCase
        self.chatRoomUseCase = chatRoomUseCase
        self.chatUseCase = chatUseCase
        self.scheduledMeetingUseCase = scheduledMeetingUseCase
        self.callCoordinatorUseCase = callCoordinatorUseCase
        self.accountUseCase = accountUseCase
        self.authUseCase = authUseCase
        self.noUserJoinedUseCase = noUserJoinedUseCase
        self.analyticsEventUseCase = analyticsEventUseCase
        self.megaHandleUseCase = megaHandleUseCase
        
        let callUUID = callUseCase.call(for: chatRoom.chatId)?.uuid
        self.callCoordinatorUseCase.addCallRemoved { [weak self] uuid in
            guard let uuid = uuid, let self = self, callUUID == uuid else { return }
            self.callCoordinatorUseCase.removeCallRemovedHandler()
            router.dismiss(animated: false, completion: nil)
        }
        
        listenToMuteUnmuteFailedNotifications()
        subscribeToSeeWaitingRoomListNotification()
    }
    
    var invokeCommand: ((Command) -> Void)?
    
    func dispatch(_ action: MeetingContainerAction) {
        switch action {
        case .onViewReady:
            router.showMeetingUI(containerViewModel: self)
            if isOneToOneChat == false {
                muteMicSubscription = Just(Void.self)
                    .delay(for: .seconds(Constants.muteMicTimerDuration), scheduler: RunLoop.main)
                    .sink { [weak self] _ in
                        guard let self else { return }

                        muteMicrophoneIfNoOtherParticipantsArePresent()
                        muteMicSubscription = nil
                    }
                
                noUserJoinedSubscription = noUserJoinedUseCase
                    .monitor
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] in
                        guard let self else { return }
                        
                        showEndCallDialogIfNeeded {
                            self.cancelNoUserJoinedSubscription()
                        }
                        noUserJoinedSubscription = nil
                }
            }
        case .hangCall(let presenter, let sender):
            hangCall(presenter: presenter, sender: sender)
        case .tapOnBackButton:
            router.dismiss(animated: true, completion: nil)
        case .changeMenuVisibility:
            router.toggleFloatingPanel(containerViewModel: self)
        case .showOptionsMenu(let presenter, let sender, let isMyselfModerator):
            router.toggleFloatingPanel(containerViewModel: self)
            router.showOptionsMenu(presenter: presenter, sender: sender, isMyselfModerator: isMyselfModerator, containerViewModel: self)
        case .hideOptionsMenu:
            router.toggleFloatingPanel(containerViewModel: self)
        case .shareLink(let presenter, let sender, let completion):
            shareLink(presenter, sender, completion)
        case .renameChat:
            router.renameChat()
        case .dismissCall(let completion):
            dismissCall(completion: completion)
        case .endGuestUserCall(let completion):
            dismissCall {
                if self.accountUseCase.isGuest {
                    self.authUseCase.logout()
                }
                
                guard let completion = completion else { return }
                completion()
            }
        case .speakerEnabled(let speakerEnabled):
            router.enableSpeaker(speakerEnabled)
        case .displayParticipantInMainView(let participant):
            router.displayParticipantInMainView(participant)
        case .didDisplayParticipantInMainView(let participant):
            router.didDisplayParticipantInMainView(participant)
        case .didSwitchToGridView:
            router.didSwitchToGridView()
        case .participantAdded:
            cancelMuteMicrophoneSubscription()
            cancelNoUserJoinedSubscription()
            router.removeEndCallDialog(finishCountDown: true, completion: nil)
        case .participantRemoved:
            muteMicrophoneIfNoOtherParticipantsArePresent()
        case .showEndCallDialogIfNeeded:
            showEndCallDialogIfNeeded()
        case .removeEndCallAlertAndEndCall:
            removeEndCallAlertAndEndCall()
        case .showJoinMegaScreen:
            router.showJoinMegaScreen()
        case .showHangOrEndCallDialog:
            router.showHangOrEndCallDialog(containerViewModel: self)
        case .endCallForAll:
            endCallForAll()
        case .participantJoinedWaitingRoom:
            router.removeEndCallDialog(finishCountDown: false, completion: nil)
        case .showScreenShareWarning:
            router.showScreenShareWarning()
        case .leaveCallFromRecordingAlert:
            endCall()
        }
    }
    
    // MARK: - Private
    private func hangCall(presenter: UIViewController?, sender: UIButton?) {
        if !accountUseCase.isGuest {
            dismissCall(completion: nil)
        } else {
            guard let presenter = presenter, let sender = sender else {
                return
            }
            router.showEndMeetingOptions(presenter: presenter,
                                         meetingContainerViewModel: self,
                                         sender: sender)
        }
    }
    
    private func endCallForAll() {
        if let call = call {
            if let callId = megaHandleUseCase.base64Handle(forUserHandle: call.callId),
               let chatId = megaHandleUseCase.base64Handle(forUserHandle: call.chatId) {
                MEGALogDebug("Meeting: Container view model - End call for all - for call id \(callId) and chat id \(chatId)")
            } else {
                MEGALogDebug("Meeting: Container view model - End call for all - cannot get the call id and chat id string")
            }
            
            callCoordinatorUseCase.removeCallRemovedHandler()
            callUseCase.endCall(for: call.callId)
            callCoordinatorUseCase.endCall(call)
        }
        
        router.dismiss(animated: true, completion: nil)
    }
    
    private func dismissCall(completion: (() -> Void)?) {
        if let call {
            if let callId = megaHandleUseCase.base64Handle(forUserHandle: call.callId),
               let chatId = megaHandleUseCase.base64Handle(forUserHandle: call.chatId) {
                MEGALogDebug("Meeting: Container view model - Hang call for call id \(callId) and chat id \(chatId)")
            } else {
                MEGALogDebug("Meeting: Container view model -Hang call - cannot get the call id and chat id string")
            }
            callCoordinatorUseCase.muteUnmuteCall(call, muted: false)
            callCoordinatorUseCase.removeCallRemovedHandler()
            callUseCase.hangCall(for: call.callId)
            callCoordinatorUseCase.endCall(call)
        }
       
        router.dismiss(animated: true, completion: completion)
    }
    
    private func muteMicrophoneIfNoOtherParticipantsArePresent() {
        if let call = call,
           call.hasLocalAudio,
           isOneToOneChat == false,
           isOnlyMyselfInTheMeeting() {
            callCoordinatorUseCase.muteUnmuteCall(call, muted: true)
        }
    }
    
    private func isOnlyMyselfInTheMeeting() -> Bool {
        guard let call = call,
              call.numberOfParticipants == 1,
              call.participants.first == accountUseCase.currentUserHandle else {
            return false
        }
        
        return true
    }
    
    private func showEndCallDialogIfNeeded(stayOnCallCompletion: (() -> Void)? = nil) {
        guard isOnlyMyselfInTheMeeting() else { return }
        router.showEndCallDialog { [weak self] in
            guard let self else { return }
            self.analyticsEventUseCase.sendAnalyticsEvent(.meetings(.endCallInNoParticipantsPopup))
            self.endCall()
        } stayOnCallCompletion: { [weak self] in
            guard let self else { return }
            self.analyticsEventUseCase.sendAnalyticsEvent(.meetings(.stayOnCallInNoParticipantsPopup))
            stayOnCallCompletion?()
        }
    }
    
    private func cancelMuteMicrophoneSubscription() {
        muteMicSubscription?.cancel()
        muteMicSubscription = nil
    }
    
    private func cancelNoUserJoinedSubscription() {
        noUserJoinedSubscription?.cancel()
        noUserJoinedSubscription = nil
    }
    
    private func removeEndCallAlertAndEndCall() {
        router.removeEndCallDialog(finishCountDown: true) { [weak self] in
            guard let self else { return }
            self.endCall()
        }
    }
    
    private func endCall() {
        if accountUseCase.isGuest {
            self.dispatch(.endGuestUserCall {
                self.dispatch(.showJoinMegaScreen)
            })
        } else {
            self.dismissCall(completion: nil)
        }
    }
    
    private func listenToMuteUnmuteFailedNotifications() {
        muteUnmuteFailedNotificationsSubscription = NotificationCenter
            .default
            .publisher(for: .MEGACallMuteUnmuteOperationFailed)
            .sink { [weak self] notification in
                guard let self,
                        let userInfo = notification.userInfo,
                        let muted = userInfo["muted"] as? Bool,
                        let call else {
                    return
                }
                
                MEGALogError("mute unmute callkit action failure\n failure to set it as muted: \(muted)\n retrying it again with muted: \(!call.hasLocalAudio)")
                callCoordinatorUseCase.muteUnmuteCall(call, muted: !call.hasLocalAudio)
            }
    }
    
    private func subscribeToSeeWaitingRoomListNotification() {
        seeWaitingRoomListEventSubscription = NotificationCenter
            .default
            .publisher(for: .seeWaitingRoomListEvent)
            .sink { [weak self] _ in
                guard let self else { return }
                router.selectWaitingRoomList(containerViewModel: self)
            }
    }
    
    private func shareLink(_ presenter: UIViewController?, _ sender: AnyObject, _ completion: UIActivityViewController.CompletionWithItemsHandler?) {
        chatRoomUseCase.fetchPublicLink(forChatRoom: chatRoom) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let link):
                guard let url = URL(string: link) else {
                    router.showShareMeetingError()
                    return
                }
                var title = (chatRoom.title ?? "") + "\n" + link
                var subject = ""
                var message = ""
                if chatRoom.isMeeting {
                    subject = Strings.Localizable.Meetings.Info.ShareMeetingLink.subject
                    message =
                    Strings.Localizable.Meetings.Info.ShareMeetingLink.invitation((chatUseCase.myFullName() ?? "")) + "\n" +
                    Strings.Localizable.Meetings.Info.ShareMeetingLink.meetingName(chatRoom.title ?? "")
                    if let scheduledMeeting = scheduledMeetingUseCase.scheduledMeetingsByChat(chatId: chatRoom.chatId).first {
                        let meetingDate = ScheduledMeetingDateBuilder(scheduledMeeting: scheduledMeeting, chatRoom: chatRoom).buildDateDescriptionString()
                        title = scheduledMeeting.title + "\n" + meetingDate
                        message += "\n" +
                        Strings.Localizable.Meetings.Info.ShareMeetingLink.meetingTime(meetingDate)
                    }
                    message += "\n" + Strings.Localizable.Meetings.Info.ShareMeetingLink.meetingLink(link)
                } else {
                    title = chatRoom.title ?? ""
                    message = title + "\n" + link
                }
                router.showShareChatLinkActivity(
                    presenter: presenter,
                    sender: sender,
                    link: link,
                    metadataItemSource: ChatLinkPresentationItemSource(
                        title: title,
                        subject: subject,
                        message: message,
                        url: url
                    ),
                    isGuestAccount: accountUseCase.isGuest,
                    completion: completion
                )
            case .failure:
                router.showShareMeetingError()
            }
        }
    }
    
    deinit {
        cancelMuteMicrophoneSubscription()
        cancelNoUserJoinedSubscription()
        self.callCoordinatorUseCase.removeCallRemovedHandler()
    }
}
