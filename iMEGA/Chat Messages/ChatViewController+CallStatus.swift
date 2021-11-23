import UIKit

extension ChatViewController {
    var joinCallString: String {
        return NSLocalizedString("Join Call", comment: "")
    }
    
    func checkIfChatHasActiveCall() {
        guard chatRoom.ownPrivilege == .standard
                || chatRoom.ownPrivilege == .moderator
                || !MEGAReachabilityManager.isReachable(),
              let call = MEGASdkManager.sharedMEGAChatSdk().chatCall(forChatId: chatRoom.chatId),
              call.status != .destroyed,
              call.status != .terminatingUserParticipation else {
            joinCallCleanup()
            return
        }
        
        onCallUpdate(call)
    }

    private func initTimerForCall(_ call: MEGAChatCall) {
        initDuration = TimeInterval(call.duration)
        if !(timer?.isValid ?? false) {
            let startTime = Date().timeIntervalSince1970
            updateJoinCallLabel(withStartTime: startTime)
            
            timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self, self.chatCall?.status != .connecting else { return }
                self.updateJoinCallLabel(withStartTime: startTime)
            }
            
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
        }
    }
    
    private func showJoinCall(withTitle title: String) {
        let spacePadding = "   "
        joinCallButton.setTitle(spacePadding + title + spacePadding, for: .normal)
        joinCallButton.isHidden = false
    }
    
    private func updateJoinCallLabel(withStartTime startTime: TimeInterval) {
        guard let initDuration = initDuration else { return }
        
        let time = Date().timeIntervalSince1970 - startTime + initDuration
        let title = String(format: NSLocalizedString("Touch to return to call %@", comment: ""), NSString.mnz_string(fromTimeInterval: time))
        showJoinCall(withTitle: title)
    }
    
    private func joinCallCleanup() {
        timer?.invalidate()
        joinCallButton.isHidden = true
    }
        
    @objc func didTapJoinCall() {
        guard !MEGASdkManager.sharedMEGAChatSdk().mnz_existsActiveCall ||
                MEGASdkManager.sharedMEGAChatSdk().isCallActive(forChatRoomId: chatRoom.chatId) else {
            MeetingAlreadyExistsAlert.show(presenter: self) { [weak self] in
                guard let self = self else { return }
                self.endActiveCallAndJoinCurrentChatroomCall()
            }
            return
        }
        
        joinCall()
    }
    
    private func endActiveCallAndJoinCurrentChatroomCall() {
        if let activeCall = MEGASdkManager.sharedMEGAChatSdk().firstActiveCall {
            let callRepository = CallRepository(chatSdk: MEGASdkManager.sharedMEGAChatSdk(), callActionManager: CallActionManager.shared)
            CallUseCase(repository: callRepository).hangCall(for: activeCall.callId)
            CallManagerUseCase().endCall(CallEntity(with: activeCall))
        }
        
        joinCall()
    }
    
    private func joinCall() {
        DevicePermissionsHelper.audioPermissionModal(true, forIncomingCall: false) { granted in
            if granted {
                self.timer?.invalidate()
                self.openCallViewWithVideo(videoCall: false)
            } else {
                DevicePermissionsHelper.alertAudioPermission(forIncomingCall: false)
            }
        }
    }
    
    private func onCallUpdate(_ call: MEGAChatCall) {
        guard call.chatId == chatRoom.chatId else {
            return
        }
        
        configureNavigationBar()

        switch call.status {
        case .initial, .joining, .userNoPresent:
            showJoinCall(withTitle: joinCallString)
        case .inProgress:
            initTimerForCall(call)
        case .connecting:
            showJoinCall(withTitle: NSLocalizedString("Reconnecting...", comment: ""))
        case .destroyed, .terminatingUserParticipation:
            joinCallCleanup()
        default:
            return
        }
        
        chatCall = call
    }
}

extension ChatViewController: MEGAChatCallDelegate {
    func onChatCallUpdate(_: MEGAChatSdk!, call: MEGAChatCall!) {
        onCallUpdate(call)
    }
}
