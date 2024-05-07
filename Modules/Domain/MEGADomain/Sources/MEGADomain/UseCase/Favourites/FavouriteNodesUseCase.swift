import AsyncAlgorithms
import Foundation

public protocol FavouriteNodesUseCaseProtocol {
    func getAllFavouriteNodes(completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void)
    func getFavouriteNodes(limitCount: Int, completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void)
    
    /// Get all favourite nodes for the active account and filter the result by the search query and the specified exclusion criteria. The result will exclude sensitive results based on account global showHiddenNodes preference.
    /// - Parameters:
    ///   - searchString: Search text used to case insensitively filter the Node results by their name, if the search term is included in the name it will return true. If nil, no name filtering is applied.
    /// - Returns: List of Favourited nodes, filtered by search and exclusion criteria.
    func allFavouriteNodes(searchString: String?) async throws -> [NodeEntity]
    
    /// Get all favourite nodes for the active account and filter the result by the search query and the specified exclusion criteria.
    /// - Parameters:
    ///   - searchString: Search text used to case insensitively filter the Node results by their name, if the search term is included in the name it will return true. If nil, no name filtering is applied.
    ///   - excludeSensitives: True, indicates that the returned result will not include any sensitively inherited nodes.
    /// - Returns: List of Favourited nodes, filtered by search and exclusion criteria.
    func allFavouriteNodes(searchString: String?, excludeSensitives: Bool) async throws -> [NodeEntity]
    
    func registerOnNodesUpdate(callback: @escaping ([NodeEntity]) -> Void)
    func unregisterOnNodesUpdate()
}

public struct FavouriteNodesUseCase<T: FavouriteNodesRepositoryProtocol, U: NodeRepositoryProtocol, V: ContentConsumptionUserAttributeUseCaseProtocol>: FavouriteNodesUseCaseProtocol {
    
    private let repo: T
    private let nodeRepository: U
    private let contentConsumptionUserAttributeUseCase: V
    private let hiddenNodesFeatureFlagEnabled: @Sendable () -> Bool

    public init(repo: T, nodeRepository: U, contentConsumptionUserAttributeUseCase: V, hiddenNodesFeatureFlagEnabled: @escaping @Sendable () -> Bool) {
        self.repo = repo
        self.nodeRepository = nodeRepository
        self.contentConsumptionUserAttributeUseCase = contentConsumptionUserAttributeUseCase
        self.hiddenNodesFeatureFlagEnabled = hiddenNodesFeatureFlagEnabled
    }
    
    public func allFavouriteNodes(searchString: String?) async throws -> [NodeEntity] {
        try await allFavouriteNodes(searchString: searchString, overrideExcludeSensitives: nil)
    }
    
    public func allFavouriteNodes(searchString: String?, excludeSensitives: Bool) async throws -> [NodeEntity] {
        try await allFavouriteNodes(searchString: searchString, overrideExcludeSensitives: excludeSensitives)
    }

    @available(*, renamed: "allFavouriteNodes()")
    public func getAllFavouriteNodes(completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void) {
        repo.getAllFavouriteNodes(completion: completion)
    }
    
    public func getFavouriteNodes(limitCount: Int, completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void) {
        repo.getFavouriteNodes(limitCount: limitCount, completion: completion)
    }
    
    public func registerOnNodesUpdate(callback: @escaping ([NodeEntity]) -> Void) {
        repo.registerOnNodesUpdate(callback: callback)
    }
    
    public func unregisterOnNodesUpdate() {
        repo.unregisterOnNodesUpdate()
    }
    
    private func allFavouriteNodes(searchString: String?, overrideExcludeSensitives: Bool?) async throws -> [NodeEntity] {
        let nodes = try await repo.allFavouritesNodes(searchString: searchString)
        
        return if await shouldExcludeSensitive(override: overrideExcludeSensitives) {
            try await withThrowingTaskGroup(of: (Int, NodeEntity?).self, returning: [NodeEntity].self) { taskGroup in
                let nodeRepository = self.nodeRepository
                for (index, node) in nodes.enumerated() {
                    _ = taskGroup.addTaskUnlessCancelled {
                        let optionalNode: NodeEntity? = try await nodeRepository.isInheritingSensitivity(node: node) ? nil : node
                        return (index, optionalNode)
                    }
                }
                return try await taskGroup
                    .reduce(into: Array(repeating: Optional<NodeEntity>.none, count: nodes.count)) { $0[$1.0] = $1.1 }
                    .compactMap { $0 }
            }
        } else {
            nodes
        }
    }

    private func shouldExcludeSensitive(override: Bool?) async -> Bool {
        if let override { override }
        else if hiddenNodesFeatureFlagEnabled() { await !contentConsumptionUserAttributeUseCase.fetchSensitiveAttribute().showHiddenNodes }
        else { false }
    }
}
