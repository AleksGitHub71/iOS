@testable import MEGA
import MEGADomain

final class MockCallManager: CallManagerProtocol {
    
    struct Incoming: Equatable {
        var uuid: UUID
        var chatRoom: ChatRoomEntity
    }
    
    var startCall_CalledTimes = 0
    var answerCall_CalledTimes = 0
    var endCall_CalledTimes = 0
    var muteCall_CalledTimes = 0
    var callUUID_CalledTimes = 0
    var callForUUID_CalledTimes = 0
    var removeCall_CalledTimes = 0
    var removeAllCalls_CalledTimes = 0
    var incomingCalls = [Incoming]()
    var callForUUIDToReturn: CallActionSync?
    var updateCallMuted_CalledTimes = 0
    var callUUID: UUID?
    
    func startCall(in chatRoom: ChatRoomEntity, chatIdBase64Handle: String, hasVideo: Bool, notRinging: Bool, isJoiningActiveCall: Bool) {
        startCall_CalledTimes += 1
    }
    
    func answerCall(in chatRoom: ChatRoomEntity, withUUID uuid: UUID) {
        answerCall_CalledTimes += 1
    }
    
    func endCall(in chatRoom: ChatRoomEntity, endForAll: Bool) {
        endCall_CalledTimes += 1
    }
    
    func muteCall(in chatRoom: MEGADomain.ChatRoomEntity, muted: Bool) {
        muteCall_CalledTimes += 1
    }
    
    func callUUID(forChatRoom chatRoom: ChatRoomEntity) -> UUID? {
        callUUID_CalledTimes += 1
        return callUUID
    }

    func call(forUUID uuid: UUID) -> CallActionSync? {
        callForUUID_CalledTimes += 1
        return callForUUIDToReturn
    }
    
    func removeCall(withUUID uuid: UUID) {
        removeCall_CalledTimes += 1
    }
    
    func removeAllCalls() {
        removeAllCalls_CalledTimes += 1
    }
    
    func addIncomingCall(withUUID uuid: UUID, chatRoom: ChatRoomEntity) {
        incomingCalls.append(
            Incoming(uuid: uuid, chatRoom: chatRoom)
        )
    }
    
    func updateCall(withUUID uuid: UUID, muted: Bool) {
        updateCallMuted_CalledTimes += 1
    }
}
