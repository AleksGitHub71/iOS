import AsyncAlgorithms
import MEGASwift
// MARK: - Use case protocol -
public protocol NodeUseCaseProtocol: Sendable {
    /// Node updates
    /// - Returns: `AnyAsyncSequence` that will yield `[NodeEntity]` items until sequence terminated.
    var nodeUpdates: AnyAsyncSequence<[NodeEntity]> { get }
    func rootNode() -> NodeEntity?
    func nodeAccessLevel(nodeHandle: HandleEntity) -> NodeAccessTypeEntity
    func nodeAccessLevelAsync(nodeHandle: HandleEntity) async -> NodeAccessTypeEntity
    func labelString(label: NodeLabelTypeEntity) -> String
    func getFilesAndFolders(nodeHandle: HandleEntity) -> (childFileCount: Int, childFolderCount: Int)
    func sizeFor(node: NodeEntity) -> UInt64?
    func folderInfo(node: NodeEntity) async throws -> FolderInfoEntity?
    func hasVersions(nodeHandle: HandleEntity) -> Bool
    func isDownloaded(nodeHandle: HandleEntity) -> Bool
    func isARubbishBinRootNode(nodeHandle: HandleEntity) -> Bool
    func isInRubbishBin(nodeHandle: HandleEntity) -> Bool
    func nodeForHandle(_ handle: HandleEntity) -> NodeEntity?
    func parentForHandle(_ handle: HandleEntity) -> NodeEntity?
    func parentsForHandle(_ handle: HandleEntity) async -> [NodeEntity]?
    func asyncChildrenOf(node: NodeEntity, sortOrder: SortOrderEntity) async -> NodeListEntity?
    func childrenOf(node: NodeEntity) -> NodeListEntity?
    func childrenNamesOf(node: NodeEntity) -> [String]?
    func isRubbishBinRoot(node: NodeEntity) -> Bool
    func isRestorable(node: NodeEntity) -> Bool
    func createFolder(with name: String, in parent: NodeEntity) async throws -> NodeEntity
    
    /// Ascertain if the node's ancestor is marked as sensitive
    ///  - Parameters: node - the node to check
    ///  - Returns: true if the node's ancestor is marked as sensitive
    ///  - Throws: `NodeError.nodeNotFound` if the parent node cant be found
    @available(*, deprecated, message: "Use SensitiveNodeUseCaseProtocol instead for all sensitive related code")
    func isInheritingSensitivity(node: NodeEntity) async throws -> Bool
    /// Ascertain if the node's ancestor is marked as sensitive
    ///  - Parameters: node - the node to check
    ///  - Returns: true if the node's ancestor is marked as sensitive
    ///  - Throws: `NodeError.nodeNotFound` if the parent node cant be found
    /// - Important: This could possibly block the calling thread, make sure not to call it on main thread.
    @available(*, deprecated, message: "Use SensitiveNodeUseCaseProtocol instead for all sensitive related code")
    func isInheritingSensitivity(node: NodeEntity) throws -> Bool
    /// On a folder sensitivity change it will recalculate the inherited sensitivity of the ancestor of the node.
    /// - Parameter node: The node check for inherited sensitivity changes
    /// - Returns: An `AnyAsyncThrowingSequence<Bool>` indicating inherited sensitivity changes
    @available(*, deprecated, message: "Use SensitiveNodeUseCaseProtocol instead for all sensitive related code")
    func monitorInheritedSensitivity(for node: NodeEntity) -> AnyAsyncThrowingSequence<Bool, any Error>
    /// On node update it will yield the sensitivity changes of the node
    /// - Parameter node: The node check for sensitive change types
    /// - Returns: An `AnyAsyncSequence<Bool>` indicating node sensitivity changes
    @available(*, deprecated, message: "Use SensitiveNodeUseCaseProtocol instead for all sensitive related code")
    func sensitivityChanges(for node: NodeEntity) -> AnyAsyncSequence<Bool>
    /// Merges sensitivity changes due to node inheritance and the direct sensitivity changes of the node itself.
    ///
    /// This method combines two streams:
    /// - `monitorInheritedSensitivity(for:)`: Monitors sensitivity changes that are inherited from parent nodes.
    /// - `sensitivityChanges(for:)`: Monitors direct sensitivity changes of the node itself.
    ///
    /// The resulting stream emits `Bool` values indicating sensitivity changes, where `true` means the node is sensitive
    /// and `false` means it is not. This method is useful for tracking both inherited and direct sensitivity changes
    /// in a unified way.
    ///
    /// - Parameter node: The `NodeEntity` for which to monitor sensitivity changes.
    /// - Returns: An `AnyAsyncThrowingSequence<Bool, any Error>` that emits sensitivity change events for the specified node.
    @available(*, deprecated, message: "Use SensitiveNodeUseCaseProtocol instead for all sensitive related code")
    func mergeInheritedAndDirectSensitivityChanges(for node: NodeEntity) -> AnyAsyncThrowingSequence<Bool, any Error>
}

// MARK: - Use case implementation -
public struct NodeUseCase<T: NodeDataRepositoryProtocol, U: NodeValidationRepositoryProtocol, V: NodeRepositoryProtocol>: NodeUseCaseProtocol {
    
    private let nodeDataRepository: T
    private let nodeValidationRepository: U
    private let nodeRepository: V
    
    public init(nodeDataRepository: T, nodeValidationRepository: U, nodeRepository: V) {
        self.nodeDataRepository = nodeDataRepository
        self.nodeValidationRepository = nodeValidationRepository
        self.nodeRepository = nodeRepository
    }
    
    public var nodeUpdates: AnyAsyncSequence<[NodeEntity]> {
        nodeRepository.nodeUpdates
    }
    
    public func rootNode() -> NodeEntity? {
        nodeRepository.rootNode()
    }

    public func nodeAccessLevel(nodeHandle: HandleEntity) -> NodeAccessTypeEntity {
        nodeDataRepository.nodeAccessLevel(nodeHandle: nodeHandle)
    }
    
    public func nodeAccessLevelAsync(nodeHandle: HandleEntity) async -> NodeAccessTypeEntity {
        await nodeDataRepository.nodeAccessLevelAsync(nodeHandle: nodeHandle)
    }
    
    public func labelString(label: NodeLabelTypeEntity) -> String {
        return nodeDataRepository.labelString(label: label)
    }
    
    public func getFilesAndFolders(nodeHandle: HandleEntity) -> (childFileCount: Int, childFolderCount: Int) {
        nodeDataRepository.getFilesAndFolders(nodeHandle: nodeHandle)
    }
    
    public func sizeFor(node: NodeEntity) -> UInt64? {
        nodeDataRepository.sizeForNode(handle: node.handle)
    }
    
    public func folderInfo(node: NodeEntity) async throws -> FolderInfoEntity? {
        try await nodeDataRepository.folderInfo(node: node)
    }
    
    public func hasVersions(nodeHandle: HandleEntity) -> Bool {
        nodeValidationRepository.hasVersions(nodeHandle: nodeHandle)
    }
    
    public func isDownloaded(nodeHandle: HandleEntity) -> Bool {
        nodeValidationRepository.isDownloaded(nodeHandle: nodeHandle)
    }

    public func isARubbishBinRootNode(nodeHandle: HandleEntity) -> Bool {
        nodeRepository.rubbishNode()?.handle == nodeHandle
    }

    public func isInRubbishBin(nodeHandle: HandleEntity) -> Bool {
        nodeValidationRepository.isInRubbishBin(nodeHandle: nodeHandle)
    }
    
    public func nodeForHandle(_ handle: HandleEntity) -> NodeEntity? {
        nodeDataRepository.nodeForHandle(handle)
    }
    
    public func parentForHandle(_ handle: HandleEntity) -> NodeEntity? {
        nodeDataRepository.parentForHandle(handle)
    }
    
    public func parentsForHandle(_ handle: HandleEntity) async -> [NodeEntity]? {
        guard let node = nodeForHandle(handle) else { return nil }
        return await nodeRepository.parents(of: node)
    }
    
    public func childrenNamesOf(node: NodeEntity) -> [String]? {
        nodeRepository.childrenNames(of: node)
    }
    
    public func isRubbishBinRoot(node: NodeEntity) -> Bool {
        node.handle == nodeRepository.rubbishNode()?.handle
    }
 
    public func isRestorable(node: NodeEntity) -> Bool {
        let restoreParentHandle = node.restoreParentHandle
        guard let restoreNode = nodeRepository.nodeForHandle(restoreParentHandle) else {
            return false
        }
        
        return !isInRubbishBin(nodeHandle: restoreNode.handle) && isInRubbishBin(nodeHandle: node.handle)
    }
    
    public func asyncChildrenOf(node: NodeEntity, sortOrder: SortOrderEntity) async -> NodeListEntity? {
        await nodeRepository.asyncChildren(of: node, sortOrder: sortOrder)
    }
    
    public func childrenOf(node: NodeEntity) -> NodeListEntity? {
        nodeRepository.children(of: node)
    }

    public func createFolder(with name: String, in parent: NodeEntity) async throws -> NodeEntity {
        try await nodeRepository.createFolder(with: name, in: parent)
    }
    
    public func isInheritingSensitivity(node: NodeEntity) async throws -> Bool {
        try await nodeRepository.isInheritingSensitivity(node: node)
    }
    
    public func isInheritingSensitivity(node: NodeEntity) throws -> Bool {
        try nodeRepository.isInheritingSensitivity(node: node)
    }
    
    public func monitorInheritedSensitivity(for node: NodeEntity) -> AnyAsyncThrowingSequence<Bool, any Error> {
        nodeRepository.nodeUpdates
            .filter { $0.contains { $0.isFolder && $0.changeTypes.contains(.sensitive)} }
            .map { _ in
                try await nodeRepository.isInheritingSensitivity(node: node)
            }
            .removeDuplicates()
            .eraseToAnyAsyncThrowingSequence()
    }
    
    public func sensitivityChanges(for node: NodeEntity) -> AnyAsyncSequence<Bool> {
        nodeRepository.nodeUpdates
            .compactMap {
                $0.first(where: {
                    $0.handle == node.handle && $0.changeTypes.contains(.sensitive)
                })?.isMarkedSensitive
            }
            .eraseToAnyAsyncSequence()
    }

    public func mergeInheritedAndDirectSensitivityChanges(
        for node: NodeEntity
    ) -> AnyAsyncThrowingSequence<Bool, any Error> {
        AsyncAlgorithms.merge(
            sensitivityChanges(for: node),
            monitorInheritedSensitivity(for: node)
        )
        .eraseToAnyAsyncThrowingSequence()
    }
}
