import Combine
import Foundation
import MEGADomain
import MEGASdk
import MEGASwift

public final class AccountRepository: NSObject, AccountRepositoryProtocol {
    private let sdk: MEGASdk
    private let currentUserSource: CurrentUserSource
    private let myChatFilesFolderNodeAccess: MyChatFilesFolderNodeAccess
    
    private let requestResultSourcePublisher = PassthroughSubject<Result<AccountRequestEntity, any Error>, Never>()
    public var requestResultPublisher: AnyPublisher<Result<AccountRequestEntity, any Error>, Never> {
        requestResultSourcePublisher.eraseToAnyPublisher()
    }
    
    private let contactRequestSourcePublisher = PassthroughSubject<[ContactRequestEntity], Never>()
    public var contactRequestPublisher: AnyPublisher<[ContactRequestEntity], Never> {
        contactRequestSourcePublisher.eraseToAnyPublisher()
    }
    
    private let userAlertUpdateSourcePublisher = PassthroughSubject<[UserAlertEntity], Never>()
    public var userAlertUpdatePublisher: AnyPublisher<[UserAlertEntity], Never> {
        userAlertUpdateSourcePublisher.eraseToAnyPublisher()
    }
    
    public init(
        sdk: MEGASdk = MEGASdk.sharedSdk,
        currentUserSource: CurrentUserSource = .shared,
        myChatFilesFolderNodeAccess: MyChatFilesFolderNodeAccess
    ) {
        self.sdk = sdk
        self.currentUserSource = currentUserSource
        self.myChatFilesFolderNodeAccess = myChatFilesFolderNodeAccess
    }

    // MARK: - User authentication status and identifiers
    public var currentUserHandle: HandleEntity? {
        currentUserSource.currentUserHandle
    }
    
    public var isGuest: Bool {
        currentUserSource.isGuest
    }
    
    public var isNewAccount: Bool {
        sdk.isNewAccount
    }
    
    public var myEmail: String? {
        sdk.myEmail
    }

    // MARK: - Account characteristics
    public var accountCreationDate: Date? {
        sdk.accountCreationDate
    }
    
    public var currentAccountDetails: AccountDetailsEntity? {
        currentUserSource.accountDetails
    }
    
    public var bandwidthOverquotaDelay: Int64 {
        sdk.bandwidthOverquotaDelay
    }
    
    public var isMasterBusinessAccount: Bool {
        sdk.isMasterBusinessAccount
    }
    
    public var isSMSAllowed: Bool {
        sdk.smsAllowedState() == .optInAndUnblock
    }
    
    public var isAchievementsEnabled: Bool {
        sdk.isAchievementsEnabled
    }

    // MARK: - User and session management
    public func currentUser() async -> UserEntity? {
        await currentUserSource.currentUser()
    }
    
    public func isLoggedIn() -> Bool {
        currentUserSource.isLoggedIn
    }
    
    public func isAccountType(_ type: AccountTypeEntity) -> Bool {
        guard let currentAccountDetails else { return false }
        
        return currentAccountDetails.proLevel == type
    }
    
    public func refreshCurrentAccountDetails() async throws -> AccountDetailsEntity {
        try await withAsyncThrowingValue(in: { completion in
            sdk.getAccountDetails(with: RequestDelegate { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let request):
                    guard let accountDetails = request.megaAccountDetails?.toAccountDetailsEntity() else {
                        completion(.failure(AccountDetailsErrorEntity.generic))
                        return
                    }
                    currentUserSource.setAccountDetails(accountDetails)
                    completion(.success(accountDetails))
                case .failure:
                    completion(.failure(AccountDetailsErrorEntity.generic))
                }
            })
        })
    }

    // MARK: - Account operations
    public func contacts() -> [UserEntity] {
        sdk.contacts().toUserEntities()
    }
    
    public func totalNodesCount() -> UInt64 {
        sdk.totalNodes
    }
    
    public func getMyChatFilesFolder(completion: @escaping (Result<NodeEntity, AccountErrorEntity>) -> Void) {
        myChatFilesFolderNodeAccess.loadNode { myChatFilesFolderNode, _ in
            guard let myChatFilesFolderNode = myChatFilesFolderNode else {
                completion(.failure(AccountErrorEntity.nodeNotFound))
                return
            }
            
            completion(.success(myChatFilesFolderNode.toNodeEntity()))
        }
    }
    
    public func upgradeSecurity() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            guard Task.isCancelled == false else {
                continuation.resume(throwing: CancellationError())
                return
            }
            sdk.upgradeSecurity(with: RequestDelegate { (result) in
                guard Task.isCancelled == false else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(throwing: AccountErrorEntity.generic)
                }
            })
        }
    }
    
    public func getMiscFlags() async throws {
        try await withAsyncThrowingValue(in: { completion in
            sdk.getMiscFlags(with: RequestDelegate { result in
                switch result {
                case .success:
                    completion(.success)
                case .failure:
                    completion(.failure(AccountErrorEntity.generic))
                }
            })
        })
    }
    
    public func sessionTransferURL(path: String) async throws -> URL {
        try await withAsyncThrowingValue(in: { completion in
            sdk.getSessionTransferURL(path, delegate: RequestDelegate { result in
                switch result {
                case .success(let request):
                    guard let link = request.link,
                          let url = URL(string: link) else {
                        completion(.failure(AccountErrorEntity.generic))
                        return
                    }
                    completion(.success(url))
                case .failure:
                    completion(.failure(AccountErrorEntity.generic))
                }
            })
        })
    }

    // MARK: - Account social and notifications
    public func incomingContactsRequestsCount() -> Int {
        sdk.incomingContactRequests().size
    }
    
    public func relevantUnseenUserAlertsCount() -> UInt {
        sdk.userAlertList().relevantUnseenCount
    }

    // MARK: - Account events and delegates
    public func registerMEGARequestDelegate() async {
        sdk.add(self as (any MEGARequestDelegate))
    }
    
    public func deRegisterMEGARequestDelegate() async {
        sdk.remove(self as (any MEGARequestDelegate))
    }
    
    public func registerMEGAGlobalDelegate() async {
        sdk.add(self as (any MEGAGlobalDelegate))
    }
    
    public func deRegisterMEGAGlobalDelegate() async {
        sdk.remove(self as (any MEGAGlobalDelegate))
    }
    
    public func multiFactorAuthCheck(email: String) async throws -> Bool {
        try await withAsyncThrowingValue { completion in
            sdk.multiFactorAuthCheck(withEmail: email, delegate: RequestDelegate { result in
                switch result {
                case .success(let request):
                    completion(.success(request.flag))
                case .failure:
                    completion(.failure(AccountErrorEntity.generic))
                }
            })
        }
    }
}

// MARK: - MEGARequestDelegate
extension AccountRepository: MEGARequestDelegate {
    public func onRequestFinish(_ api: MEGASdk, request: MEGARequest, error: MEGAError) {
        guard error.type == .apiOk else {
            requestResultSourcePublisher.send(.failure(error))
            return
        }
        requestResultSourcePublisher.send(.success(request.toAccountRequestEntity()))
    }
}

// MARK: - MEGAGlobalDelegate
extension AccountRepository: MEGAGlobalDelegate {
    public func onUserAlertsUpdate(_ api: MEGASdk, userAlertList: MEGAUserAlertList) {
        userAlertUpdateSourcePublisher.send(userAlertList.toUserAlertEntities())
    }
    
    public func onContactRequestsUpdate(_ api: MEGASdk, contactRequestList: MEGAContactRequestList) {
        contactRequestSourcePublisher.send(contactRequestList.toContactRequestEntities())
    }
}
