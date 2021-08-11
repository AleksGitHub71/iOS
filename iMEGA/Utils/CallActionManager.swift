
@objc final class CallActionManager: NSObject {
    @objc static let shared = CallActionManager()
    private let chatSdk = MEGASdkManager.sharedMEGAChatSdk()
    private var callAvailabilityListener: CallAvailabilityListener?
    private var chatOnlineListener: ChatOnlineListener?
    private var callInProgressListener: CallInProgressListener?
    var didEnableWebrtcAudioNow: Bool = false
    private var enableRTCAudioExternally = false
    
    private var megaCallManager: MEGACallManager? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let callManager = appDelegate.megaCallManager else {
            return nil
        }
        
        return callManager
    }
    
    private var providerDelegate: MEGAProviderDelegate? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let megaProviderDelegate = appDelegate.megaProviderDelegate else {
            return nil
        }
        
        return megaProviderDelegate
    }

    private override init() { super.init() }

    
    @objc func startCall(chatId: UInt64, enableVideo: Bool, enableAudio: Bool, delegate: MEGAChatStartCallRequestDelegate) {
        self.chatOnlineListener = ChatOnlineListener(
            chatId: chatId,
            sdk: chatSdk
        ) { [weak self] chatId in
            guard let self = self else { return }
            self.chatOnlineListener = nil
            MEGALogDebug("1: CallActionManager: state is online now \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1") ")
            
            self.configureAudioSessionForStartCall(chatId: chatId)
            let requestDelegate = MEGAChatStartCallRequestDelegate { error in
                if error.type == .MEGAChatErrorTypeOk {
                    self.notifyStartCallToCallKit(chatId: chatId)
                }
                delegate.completion(error)
            }
            self.chatSdk.startChatCall(chatId, enableVideo: enableVideo, enableAudio: enableAudio, delegate: requestDelegate)
        }
    }
    
    @objc func answerCall(chatId: UInt64, enableVideo: Bool, enableAudio: Bool, delegate: MEGAChatAnswerCallRequestDelegate) {
        let group = DispatchGroup()
        
        group.enter()
        self.chatOnlineListener = ChatOnlineListener(
            chatId: chatId,
            sdk: chatSdk
        ) { [weak self] chatId in
            guard let self = self else { return }
            self.chatOnlineListener = nil
            MEGALogDebug("2: CallActionManager: state is online now \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1") ")
            group.leave()
        }
        
        group.enter()
        self.callAvailabilityListener = CallAvailabilityListener(
            chatId: chatId,
            sdk: self.chatSdk
        ) { [weak self] chatId, call  in
            guard let self = self else { return }
            self.callAvailabilityListener = nil
            MEGALogDebug("3: CallActionManager: Call is now available for \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1") - \(call)")
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let providerDelegate = self.providerDelegate,
               providerDelegate.isAudioSessionActive {
                self.configureAudioSessionForStartCall(chatId: chatId)
            } else {
                self.disableRTCAudio()
                self.enableRTCAudioExternally = true
            }
            let requestDelegate = MEGAChatAnswerCallRequestDelegate { error in
                if error.type == .MEGAChatErrorTypeOk {
                    self.notifyStartCallToCallKit(chatId: chatId)
                }
                delegate.completion(error)
            }
            
            self.chatSdk.answerChatCall(chatId, enableVideo: enableVideo, enableAudio: enableAudio, delegate: requestDelegate)
        }
    }
    
    @objc func enableRTCAudioIfRequired() {
        MEGALogDebug("CallActionManager: enableRTCAudioIfRequired started")
        guard enableRTCAudioExternally else {
            return
        }
        
        MEGALogDebug("CallActionManager: enableRTCAudioIfRequired success")
        enableRTCAudioExternally = false
        enableRTCAudio()
    }
    
    @objc func disableRTCAudioSession() {
        MEGALogDebug("CallActionManager: Enable webrtc audio session")
        disableRTCAudio()
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(AVAudioSession.sharedInstance())
    }
    
    private func notifyStartCallToCallKit(chatId: UInt64) {
        guard let call = chatSdk.chatCall(forChatId: chatId), !isCallAlreadyAdded(CallEntity(with: call)) else { return }
        
        MEGALogDebug("CallActionManager: Notifiying call to callkit")
        megaCallManager?.start(call)
        megaCallManager?.add(call)
    }
        
    private func configureAudioSessionForStartCall(chatId: UInt64) {
        disableRTCAudio()
        self.callInProgressListener = CallInProgressListener(chatId: chatId, sdk: chatSdk) { [weak self] chatId, call in
            guard let self = self else { return }
            self.enableRTCAudio()
            MEGALogDebug("CallActionManager: Enabled webrtc audio session")
            self.callInProgressListener = nil
        }
    }
    
    private func disableRTCAudio() {
        MEGALogDebug("CallActionManager: Disable webrtc audio")
        RTCAudioSession.sharedInstance().useManualAudio = true
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
    
    private func enableRTCAudio() {
        MEGALogDebug("CallActionManager: Enable webrtc audio session")
        RTCAudioSession.sharedInstance().audioSessionDidActivate(AVAudioSession.sharedInstance())
        RTCAudioSession.sharedInstance().isAudioEnabled = true
        self.didEnableWebrtcAudioNow = true
    }
    
    private func isCallAlreadyAdded(_ call: CallEntity) -> Bool {
        guard let megaCallManager = megaCallManager,
              let uuid = megaCallManager.uuid(forChatId: call.chatId, callId: call.callId) else {
            return false
        }
        
        return megaCallManager.callId(for: uuid) != 0
    }
}

private final class ChatOnlineListener: NSObject {
    private let chatId: UInt64
    typealias Completion = (_ chatId: UInt64) -> Void
    private var completion: Completion?
    private let sdk: MEGAChatSdk

    init(chatId: UInt64,
         sdk: MEGAChatSdk,
         completion: @escaping Completion) {
        self.chatId = chatId
        self.sdk = sdk
        self.completion = completion
        super.init()
        
        if sdk.chatConnectionState(chatId) == .online {
            completion(chatId)
            self.completion = nil
        } else {
            addListener()
        }
    }
    
    private func addListener() {
        sdk.add(self as MEGAChatDelegate)
    }
    
    private func removeListener() {
        sdk.remove(self as MEGAChatDelegate)
    }
}

extension ChatOnlineListener: MEGAChatDelegate {
    func onChatConnectionStateUpdate(_ api: MEGAChatSdk!, chatId: UInt64, newState: Int32) {
        if self.chatId == chatId,
           newState == MEGAChatConnection.online.rawValue {
            MEGALogDebug("CallActionManager: chat state changed to online now for chat id \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1")")
            removeListener()
            completion?(chatId)
            self.completion = nil
        } else if (self.chatId == chatId) {
            MEGALogDebug("CallActionManager: new state is \(newState) for chat id \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1")")
        }
    }
}

private final class CallAvailabilityListener: NSObject {
    private let chatId: UInt64
    typealias Completion = (_ chatId: UInt64, _ call: MEGAChatCall) -> Void
    private var completion: Completion?
    private let sdk: MEGAChatSdk

    init(chatId: UInt64,
         sdk: MEGAChatSdk,
         completion: @escaping Completion) {
        self.chatId = chatId
        self.sdk = sdk
        self.completion = completion
        super.init()
        
        if let call = sdk.chatCall(forChatId: chatId) {
            completion(chatId, call)
            self.completion = nil
        } else {
            addListener()
        }
    }
    
    private func addListener() {
        sdk.add(self as MEGAChatCallDelegate)
    }
    
    private func removeListener() {
        sdk.remove(self as MEGAChatCallDelegate)
    }
}

extension CallAvailabilityListener: MEGAChatCallDelegate {
    func onChatCallUpdate(_ api: MEGAChatSdk!, call: MEGAChatCall!) {
        if call.chatId == chatId {
            MEGALogDebug("CallActionManager: onChatCallUpdate for \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1")")
            if let call = call {
                MEGALogDebug("CallActionManager: call object is \(call)")
                removeListener()
                completion?(chatId, call)
                self.completion = nil
            } else {
                MEGALogDebug("CallActionManager: no call object found for  \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1")")
            }
        }
    }
}


private final class CallInProgressListener: NSObject {
    private let chatId: UInt64
    typealias Completion = (_ chatId: UInt64, _ call: MEGAChatCall) -> Void
    private var completion: Completion?
    private let sdk: MEGAChatSdk

    init(chatId: UInt64,
         sdk: MEGAChatSdk,
         completion: @escaping Completion) {
        self.chatId = chatId
        self.sdk = sdk
        self.completion = completion
        super.init()
        addListener()
    }
    
    private func addListener() {
        sdk.add(self as MEGAChatCallDelegate)
    }
    
    private func removeListener() {
        sdk.remove(self as MEGAChatCallDelegate)
    }
}

extension CallInProgressListener: MEGAChatCallDelegate {
    func onChatCallUpdate(_ api: MEGAChatSdk!, call: MEGAChatCall!) {
        if call.chatId == chatId {
            MEGALogDebug("CallActionManager: onChatCallUpdate for \(MEGASdk.base64Handle(forUserHandle: chatId) ?? "-1")")
            if let call = call, call.status == .inProgress {
                MEGALogDebug("CallActionManager: call object is \(call)")
                removeListener()
                completion?(chatId, call)
                self.completion = nil
            }
        }
    }
}

