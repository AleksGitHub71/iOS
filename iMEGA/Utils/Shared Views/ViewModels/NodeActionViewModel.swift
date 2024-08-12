import Foundation
import MEGADomain
import MEGAPresentation
import MEGASwift

struct NodeActionViewModel {
    private struct NodeSensitivity {
        let isMarkedSensitive: Bool
        let isInheritingSensitivity: Bool
    }
    
    private let accountUseCase: any AccountUseCaseProtocol
    private let systemGeneratedNodeUseCase: any SystemGeneratedNodeUseCaseProtocol
    private let sensitiveNodeUseCase: any SensitiveNodeUseCaseProtocol
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    
    private let maxDetermineSensitivityTasks: Int
    
    var hasValidProOrUnexpiredBusinessAccount: Bool {
        accountUseCase.hasValidProOrUnexpiredBusinessAccount()
    }
    
    init(accountUseCase: some AccountUseCaseProtocol,
         systemGeneratedNodeUseCase: some SystemGeneratedNodeUseCaseProtocol,
         sensitiveNodeUseCase: some SensitiveNodeUseCaseProtocol,
         maxDetermineSensitivityTasks: Int = 500,
         featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider) {
        self.accountUseCase = accountUseCase
        self.systemGeneratedNodeUseCase = systemGeneratedNodeUseCase
        self.sensitiveNodeUseCase = sensitiveNodeUseCase
        self.maxDetermineSensitivityTasks = maxDetermineSensitivityTasks
        self.featureFlagProvider = featureFlagProvider
    }
    
    /// Indicates if nodes are already hidden or not. If nodes are hidden, then show unhide action; if not, then show hide action. If no action should be shown, return nil. If nodes contain system-generated nodes, return nil. If nodes are from shared items, return nil.
    /// - Parameter nodes: The nodes to check to show hide entry point or not
    /// - Parameter isFromSharedItem: Indicates if the nodes are from a shared item
    /// - Parameter containsABackupNode: Indicates if the nodes contain a backup node
    /// - Returns: An `Optional<Bool>`: if value is nil, don't show entry point; if value is false, show hide action; if value is true, don't show hide action
    func isHidden(_ nodes: [NodeEntity], isFromSharedItem: Bool, containsBackupNode: Bool) async -> Bool? {
        do {
            guard featureFlagProvider.isFeatureFlagEnabled(for: .hiddenNodes),
                  isFromSharedItem == false,
                  !containsBackupNode,
                  nodes.isNotEmpty,
                  try await !systemGeneratedNodeUseCase.containsSystemGeneratedNode(nodes: nodes) else {
                return nil
            }
            
            return await containsOnlySensitiveNodes(for: nodes)
        } catch is CancellationError {
            MEGALogError("[\(type(of: self))] containsOnlySensitiveNodes cancelled")
        } catch {
            MEGALogError("[\(type(of: self))] Error determining node sensitivity. Error: \(error)")
        }
        return nil
    }
    
    func isSensitive(node: NodeEntity) async -> Bool {
        if !featureFlagProvider.isFeatureFlagEnabled(for: .hiddenNodes) {
            false
        } else if node.isMarkedSensitive {
            true
        } else {
            (try? await sensitiveNodeUseCase.isInheritingSensitivity(node: node)) ?? false
        }
    }
    
    // MARK: - Private methods
    
    /// Determine if nodes contains only sensitive nodes
    /// - Parameter nodes: The nodes to check if they are all sensitive
    /// - Returns: An `Optional<Bool>` if value contains inherited sensitivity it will return nil, otherwise true if all nodes are marked as sensitive. If nodes are empty it will return nil.
    private func containsOnlySensitiveNodes(for nodes: [NodeEntity]) async -> Bool? {
        guard nodes.isNotEmpty else {
            return nil
        }
        return await withTaskGroup(of: NodeSensitivity.self,
                                   returning: Optional<Bool>.self) { taskGroup in
            defer { taskGroup.cancelAll() }
            
            let maxTasks = min(maxDetermineSensitivityTasks, nodes.count)
            var iterator = nodes.makeIterator()
            
            for _ in 0..<maxTasks {
                guard let node = iterator.next(),
                      taskGroup.addTaskUnlessCancelled(operation: {
                          await combinedNodeSensitivity(for: node)
                      }) else {
                    break
                }
            }
            
            var containsOnlySensitiveNodes: Bool? = true
            for await nodeSensitivity in taskGroup {
                guard !nodeSensitivity.isInheritingSensitivity else {
                    containsOnlySensitiveNodes = nil
                    break
                }
                if !nodeSensitivity.isMarkedSensitive {
                    containsOnlySensitiveNodes = false
                }
                if let node = iterator.next() {
                    guard taskGroup.addTaskUnlessCancelled(operation: {
                        await combinedNodeSensitivity(for: node)
                    }) else {
                        break
                    }
                }
            }
            return containsOnlySensitiveNodes
        }
    }
    
    private func combinedNodeSensitivity(for node: NodeEntity) async -> NodeSensitivity {
        NodeSensitivity(
            isMarkedSensitive: node.isMarkedSensitive,
            isInheritingSensitivity: (try? await sensitiveNodeUseCase.isInheritingSensitivity(node: node)) ?? false)
    }
}
