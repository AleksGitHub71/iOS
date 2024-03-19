import Combine

public protocol AccountPlanPurchaseRepositoryProtocol: RepositoryProtocol {
    func accountPlanProducts() async -> [AccountPlanEntity]
    func restorePurchase()
    func purchasePlan(_ plan: AccountPlanEntity) async
    func cancelCreditCardSubscriptions(reason: String?) async throws
    
    var successfulRestorePublisher: AnyPublisher<Void, Never> { get }
    var incompleteRestorePublisher: AnyPublisher<Void, Never> { get }
    var failedRestorePublisher: AnyPublisher<AccountPlanErrorEntity, Never> { get }
    var purchasePlanResultPublisher: AnyPublisher<Result<Void, AccountPlanErrorEntity>, Never> { get }
    
    func registerRestoreDelegate() async
    func deRegisterRestoreDelegate() async
    func registerPurchaseDelegate() async
    func deRegisterPurchaseDelegate() async
}
