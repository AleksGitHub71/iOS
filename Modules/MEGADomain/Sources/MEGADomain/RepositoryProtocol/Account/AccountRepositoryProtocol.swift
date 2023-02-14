public protocol AccountRepositoryProtocol: RepositoryProtocol {
    func totalNodesCount() -> UInt
    func getMyChatFilesFolder(completion: @escaping (Result<NodeEntity, AccountErrorEntity>) -> Void)
    func getAccountDetails(completion: @escaping (Result<AccountDetailsEntity, AccountDetailsErrorEntity>) -> Void)
    func upgradeSecurity() async throws -> Bool
}
