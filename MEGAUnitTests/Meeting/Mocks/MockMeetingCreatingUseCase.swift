@testable import MEGA
import MEGADomain

final class MockMeetingCreatingUseCase: MeetingCreatingUseCaseProtocol {
    let userName: String
    var chatCallCompletion: Result<ChatRoomEntity, CallErrorEntity>
    var createEphemeralAccountCompletion: Result<Void, MEGASDKErrorType>
    var joinCallCompletion: Result<ChatRoomEntity, CallErrorEntity>
    var checkChatLinkCompletion: Result<ChatRoomEntity, CallErrorEntity>
    
    var createChatLink_calledTimes = 0
    
    init(userName: String = "Test Name",
         chatCallCompletion: Result<ChatRoomEntity, CallErrorEntity> = .failure(.generic),
         createEphemeralAccountCompletion: Result<Void, MEGASDKErrorType> = .failure(.unexpected),
         joinCallCompletion: Result<ChatRoomEntity, CallErrorEntity> = .failure(.generic),
         checkChatLinkCompletion: Result<ChatRoomEntity, CallErrorEntity> = .failure(.generic)
    ) {
        self.userName = userName
        self.chatCallCompletion = chatCallCompletion
        self.createEphemeralAccountCompletion = createEphemeralAccountCompletion
        self.joinCallCompletion = joinCallCompletion
        self.checkChatLinkCompletion = checkChatLinkCompletion
    }
    
    func startCall(_ startCall: StartCallEntity, completion: @escaping (Result<ChatRoomEntity, CallErrorEntity>) -> Void) {
        completion(chatCallCompletion)
    }
    
    func joinCall(forChatId chatId: UInt64, enableVideo: Bool, enableAudio: Bool, userHandle: UInt64, completion: @escaping (Result<ChatRoomEntity, CallErrorEntity>) -> Void) {
        completion(joinCallCompletion)
    }
    
    func getUsername() -> String {
        userName
    }
    
    func getCall(forChatId chatId: UInt64) -> CallEntity? {
        CallEntity(status: .inProgress, chatId: 0, callId: 0, changeType: nil, duration: 0, initialTimestamp: 0, finalTimestamp: 0, hasLocalAudio: false, hasLocalVideo: false, termCodeType: nil, isRinging: false, callCompositionChange: nil, numberOfParticipants: 0, isOnHold: false, sessionClientIds: [], clientSessions: [], participants: [], waitingRoomStatus: .unknown, waitingRoom: nil, waitingRoomHandleList: [], uuid: UUID(uuidString: "45adcd56-a31c-11eb-bcbc-0242ac130002")!)
    }
    
    func checkChatLink(link: String, completion: @escaping (Result<ChatRoomEntity, CallErrorEntity>) -> Void) {
        completion(checkChatLinkCompletion)
    }
    
    func createEphemeralAccountAndJoinChat(firstName: String, lastName: String, link: String, completion: @escaping (Result<Void, MEGASDKErrorType>) -> Void, karereInitCompletion: @escaping () -> Void) {
        completion(createEphemeralAccountCompletion)
    }
    
    func createChatLink(forChatId chatId: UInt64) {
        createChatLink_calledTimes += 1
    }
}
