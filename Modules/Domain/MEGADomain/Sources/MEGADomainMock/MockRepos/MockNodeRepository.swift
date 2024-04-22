import Foundation
import MEGADomain
import MEGASwift

public final class MockNodeRepository: NodeRepositoryProtocol, @unchecked Sendable {
    
    public static var newRepo: MockNodeRepository { MockNodeRepository() }
    
    private let node: NodeEntity?
    private let rubbishBinNode: NodeEntity?
    private let nodeRoot: NodeEntity?
    private let nodeAccessLevel: NodeAccessTypeEntity
    private let childNodeNamed: NodeEntity?
    private let childNode: NodeEntity?
    private let images: [NodeEntity]
    private let fileLinkNode: NodeEntity?
    private let childNodes: [String: NodeEntity]
    @Atomic public var childrenNodes: [NodeEntity] = []
    private let parentNodes: [NodeEntity]
    private let isInheritingSensitivityResult: Result<Bool, Error>
    
    public init(
        node: NodeEntity? = nil,
        rubbishBinNode: NodeEntity? = nil,
        nodeRoot: NodeEntity? = nil,
        nodeAccessLevel: NodeAccessTypeEntity = .unknown,
        childNodeNamed: NodeEntity? = nil,
        childNode: NodeEntity? = nil,
        images: [NodeEntity] = [],
        fileLinkNode: NodeEntity? = nil,
        childNodes: [String: NodeEntity] = [:],
        childrenNodes: [NodeEntity] = [],
        parentNodes: [NodeEntity] = [],
        isInheritingSensitivityResult: Result<Bool, Error> = .failure(GenericErrorEntity())
    ) {
        self.node = node
        self.rubbishBinNode = rubbishBinNode
        self.nodeRoot = nodeRoot
        self.nodeAccessLevel = nodeAccessLevel
        self.childNodeNamed = childNodeNamed
        self.childNode = childNode
        self.images = images
        self.fileLinkNode = fileLinkNode
        self.childNodes = childNodes
        self.parentNodes = parentNodes
        self.isInheritingSensitivityResult = isInheritingSensitivityResult
        $childrenNodes.mutate { $0 = childrenNodes }
    }
    
    public func nodeForHandle(_ handle: HandleEntity) -> NodeEntity? {
        node
    }
    
    public func nodeFor(fileLink: FileLinkEntity, completion: @escaping (Result<NodeEntity, NodeErrorEntity>) -> Void) {
        guard let node = fileLinkNode else {
            completion(.failure(.nodeNotFound))
            return
        }
        completion(.success(node))
    }
    
    public func nodeFor(fileLink: FileLinkEntity) async throws -> NodeEntity {
        guard let node = fileLinkNode else {
            throw NodeErrorEntity.nodeNotFound
        }
        return node
    }
    
    public func childNodeNamed(name: String, in parentHandle: HandleEntity) -> NodeEntity? {
        childNode
    }
    
    public func childNode(parent node: NodeEntity,
                          name: String,
                          type: NodeTypeEntity) async -> NodeEntity? {
        childNodes[name]
    }
    
    public func images(for parentNode: NodeEntity) -> [NodeEntity] {
        images
    }
    
    public func images(for parentHandle: HandleEntity) -> [NodeEntity] {
        images
    }
    
    public func rubbishNode() -> NodeEntity? {
        rubbishBinNode
    }
    
    public func rootNode() -> NodeEntity? {
        nodeRoot
    }
    
    public func parents(of node: NodeEntity) async -> [NodeEntity] {
        parentNodes
    }
    
    public func asyncChildren(of node: NodeEntity) async -> [NodeEntity] {
        childrenNodes
    }
    
    public func children(of node: NodeEntity) -> NodeListEntity? {
        .init(nodesCount: 0, nodeAt: { _ in nil })
    }

    public func asyncChildren(of node: NodeEntity, sortOrder: SortOrderEntity) async -> NodeListEntity? {
        guard !childrenNodes.isEmpty else { return nil }
        return .init(nodesCount: childrenNodes.count, nodeAt: { index in
            return self.childrenNodes[index]
        })
    }

    public func childrenNames(of node: NodeEntity) -> [String]? {
        childrenNodes.compactMap {$0.name}
    }

    public func isInRubbishBin(node: NodeEntity) -> Bool {
        rubbishBinNode == node
    }

    public func createFolder(with name: String, in parent: NodeEntity) async throws -> NodeEntity {
        parent
    }
    
    public func isInheritingSensitivity(node: NodeEntity) async throws -> Bool {
        try await withCheckedThrowingContinuation {
            $0.resume(with: isInheritingSensitivityResult)
        }
    }
}
