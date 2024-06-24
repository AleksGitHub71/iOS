import Combine

public protocol FilesSearchRepositoryProtocol: RepositoryProtocol, Sendable {
    var nodeUpdatesPublisher: AnyPublisher<[NodeEntity], Never> { get }
    
    func startMonitoringNodesUpdate(callback: (([NodeEntity]) -> Void)?)
    func stopMonitoringNodesUpdate()
    func node(by id: HandleEntity) async -> NodeEntity?
    
    /// Search files and folders by name. It will return a list of nodes based on the criteria provided in the params.
    /// - Parameters:
    ///   - filter: SearchFilterEntity contains all necessary information to build search query.
    ///   - completion: Completion block to handle result from the request
    func search(filter: SearchFilterEntity, completion: @escaping ([NodeEntity]?, Bool) -> Void)
    
    /// Search files and folders by name. It will return a list of nodes based on the criteria provided in the params.
    /// - Parameters:
    ///   - filter: SearchFilterEntity contains all necessary information to build search query.
    /// - Returns: List of NodeEntities that match the criteria provided.
    func search(filter: SearchFilterEntity) async throws -> [NodeEntity]
    
    /// Search files and folders by name. It will return a list of nodes based on the criteria provided in the params.
    /// - Parameters:
    ///   - filter: SearchFilterEntity contains all necessary information to build search query.
    /// - Returns: NodeListEntity that match the criteria provided.
    func search(filter: SearchFilterEntity) async throws -> NodeListEntity
    
    /// Cancel last search that had set `supportCancel` to true.
    func cancelSearch()
}
