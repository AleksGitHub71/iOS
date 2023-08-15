import Combine

public protocol AccountRepositoryProtocol: RepositoryProtocol {
    var currentUserHandle: HandleEntity? { get }
    func currentUser() async -> UserEntity?
    var isGuest: Bool { get }
    var isMasterBusinessAccount: Bool { get }
    var bandwidthOverquotaDelay: Int64 { get }
    func isLoggedIn() -> Bool
    func contacts() -> [UserEntity]
    func totalNodesCount() -> UInt
    func getMyChatFilesFolder(completion: @escaping (Result<NodeEntity, AccountErrorEntity>) -> Void)
    func upgradeSecurity() async throws -> Bool
    func incomingContactsRequestsCount() -> Int
    func relevantUnseenUserAlertsCount() -> UInt
    
    var currentAccountDetails: AccountDetailsEntity? { get }
    func refreshCurrentAccountDetails() async throws -> AccountDetailsEntity
    
    var requestResultPublisher: AnyPublisher<Result<AccountRequestEntity, Error>, Never> { get }
    var contactRequestPublisher: AnyPublisher<[ContactRequestEntity], Never> { get }
    var userAlertUpdatePublisher: AnyPublisher<[UserAlertEntity], Never> { get }
    
    func registerMEGARequestDelegate() async
    func deRegisterMEGARequestDelegate() async
    func registerMEGAGlobalDelegate() async
    func deRegisterMEGAGlobalDelegate() async
}
