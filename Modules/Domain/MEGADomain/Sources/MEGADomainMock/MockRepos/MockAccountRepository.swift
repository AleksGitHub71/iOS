import Combine
import MEGADomain

public final class MockAccountRepository: AccountRepositoryProtocol {
    private let nodesCount: UInt64
    private let getMyChatFilesFolderResult: (Result<NodeEntity, AccountErrorEntity>)
    private let accountDetailsResult: (Result<AccountDetailsEntity, AccountDetailsErrorEntity>)
    private let _currentAccountDetails: AccountDetailsEntity?
    private let isUpgradeSecuritySuccess: Bool
    private let _isLoggedIn: Bool
    private let _isMasterBusinessAccount: Bool
    private let _contacts: [UserEntity]
    private let _bandwidthOverquotaDelay: Int64
    private let contactsRequestsCount: Int
    private let unseenUserAlertsCount: UInt
    public let requestResultPublisher: AnyPublisher<Result<AccountRequestEntity, Error>, Never>
    public let contactRequestPublisher: AnyPublisher<[ContactRequestEntity], Never>
    public let userAlertUpdatePublisher: AnyPublisher<[UserAlertEntity], Never>
    public var registerMEGARequestDelegateCalled = 0
    public var deRegisterMEGARequestDelegateCalled = 0
    public var registerMEGAGlobalDelegateCalled = 0
    public var deRegisterMEGAGlobalDelegateCalled = 0
    
    let currentUser: UserEntity?
    public let isGuest: Bool

    public init(currentUser: UserEntity? = nil,
                isGuest: Bool = false,
                isLoggedIn: Bool = true,
                isMasterBusinessAccount: Bool = false,
                contacts: [UserEntity] = [],
                nodesCount: UInt64 = 0,
                contactsRequestsCount: Int = 0,
                unseenUserAlertsCount: UInt = 0,
                getMyChatFilesFolderResult: Result<NodeEntity, AccountErrorEntity> = .failure(.nodeNotFound),
                currentAccountDetails: AccountDetailsEntity? = nil,
                accountDetailsResult: Result<AccountDetailsEntity, AccountDetailsErrorEntity> = .failure(.generic),
                requestResultPublisher: AnyPublisher<Result<AccountRequestEntity, Error>, Never> = Empty().eraseToAnyPublisher(),
                contactRequestPublisher: AnyPublisher<[ContactRequestEntity], Never> = Empty().eraseToAnyPublisher(),
                userAlertUpdatePublisher: AnyPublisher<[UserAlertEntity], Never> = Empty().eraseToAnyPublisher(),
                isUpgradeSecuritySuccess: Bool = false,
                bandwidthOverquotaDelay: Int64 = 0) {
        _isLoggedIn = isLoggedIn
        _isMasterBusinessAccount = isMasterBusinessAccount
        _contacts = contacts
        _currentAccountDetails = currentAccountDetails
        _bandwidthOverquotaDelay = bandwidthOverquotaDelay
        self.currentUser = currentUser
        self.isGuest = isGuest
        self.nodesCount = nodesCount
        self.getMyChatFilesFolderResult = getMyChatFilesFolderResult
        self.accountDetailsResult = accountDetailsResult
        self.isUpgradeSecuritySuccess = isUpgradeSecuritySuccess
        self.contactsRequestsCount = contactsRequestsCount
        self.unseenUserAlertsCount = unseenUserAlertsCount
        self.requestResultPublisher = requestResultPublisher
        self.contactRequestPublisher = contactRequestPublisher
        self.userAlertUpdatePublisher = userAlertUpdatePublisher
    }
    
    public var currentUserHandle: HandleEntity? {
        currentUser?.handle
    }
    
    public func currentUser() async -> UserEntity? {
        currentUser
    }
    
    public func isLoggedIn() -> Bool {
        _isLoggedIn
    }
    
    public var isMasterBusinessAccount: Bool {
        _isMasterBusinessAccount
    }
    
    public func contacts() -> [UserEntity] {
        _contacts
    }
    
    public var bandwidthOverquotaDelay: Int64 {
        _bandwidthOverquotaDelay
    }
    
    public static var newRepo: MockAccountRepository {
        MockAccountRepository()
    }
    
    public func totalNodesCount() -> UInt64 { nodesCount }
    
    public func getMyChatFilesFolder(completion: @escaping (Result<NodeEntity, AccountErrorEntity>) -> Void) {
        completion(getMyChatFilesFolderResult)
    }
    
    public var currentAccountDetails: AccountDetailsEntity? {
        _currentAccountDetails
    }
    
    public func refreshCurrentAccountDetails() async throws -> AccountDetailsEntity {
        switch accountDetailsResult {
        case .success(let details): return details
        case .failure(let error): throw error
        }
    }
    
    public func upgradeSecurity() async throws -> Bool {
        isUpgradeSecuritySuccess
    }
    
    public func incomingContactsRequestsCount() -> Int {
        contactsRequestsCount
    }
    
    public func relevantUnseenUserAlertsCount() -> UInt {
        unseenUserAlertsCount
    }
    
    public func registerMEGARequestDelegate() async {
        registerMEGARequestDelegateCalled += 1
    }
    
    public func deRegisterMEGARequestDelegate() {
        deRegisterMEGARequestDelegateCalled += 1
    }
    
    public func registerMEGAGlobalDelegate() async {
        registerMEGAGlobalDelegateCalled += 1
    }
    
    public func deRegisterMEGAGlobalDelegate() async {
        deRegisterMEGAGlobalDelegateCalled += 1
    }
}
