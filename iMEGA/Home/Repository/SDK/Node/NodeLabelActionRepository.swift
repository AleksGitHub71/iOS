import Foundation
import MEGADomain

protocol NodeLabelActionRepositoryProtocol {

    var labelColors: [NodeLabelColor] { get }

    func setNodeLabelColor(
        _ labelColor: NodeLabelColor,
        forNode nodeHandle: HandleEntity,
        completion: ((Result<Void, NodeLabelActionDomainError>) -> Void)?
    )

    func resetNodeLabelColor(
        forNode nodeHandle: HandleEntity,
        completion: ((Result<Void, NodeLabelActionDomainError>) -> Void)?
    )

    func nodeLabelColor(
        forNode nodeHandle: HandleEntity,
        completion: ((Result<NodeLabelColor, NodeLabelActionDomainError>) -> Void)?
    )
}

final class NodeLabelActionRepository: NodeLabelActionRepositoryProtocol {

    private let sdk: MEGASdk

    init(sdk: MEGASdk = MEGASdk.shared) {
        self.sdk = sdk
    }

    func setNodeLabelColor(
        _ labelColor: NodeLabelColor,
        forNode nodeHandle: HandleEntity,
        completion: ((Result<Void, NodeLabelActionDomainError>) -> Void)?
    ) {
        guard let node = sdk.node(forHandle: nodeHandle) else {
            completion?(.failure(.nodeNotFound))
            return
        }

        guard let SDKLabelColor = MEGANodeLabel(rawValue: labelColor.rawValue) else {
            completion?(.failure(.unsupportedNodeLabelColorFound))
            return
        }

        let delegate = MEGAGenericRequestDelegate { (_, error) in
            if let errorType = error.sdkError {
                completion?(.failure(.sdkError(errorType)))
                return
            }
            completion?(.success(()))
        }

        sdk.setNodeLabel(node, label: SDKLabelColor, delegate: delegate)
    }

    func resetNodeLabelColor(
        forNode nodeHandle: HandleEntity,
        completion: ((Result<Void, NodeLabelActionDomainError>) -> Void)?
    ) {
        guard let node = sdk.node(forHandle: nodeHandle) else {
            completion?(.failure(.nodeNotFound))
            return
        }
        let delegate = MEGAGenericRequestDelegate { (_, error) in
            if let errorType = error.sdkError {
                completion?(.failure(.sdkError(errorType)))
                return
            }
            completion?(.success(()))
        }
        sdk.resetNodeLabel(node, delegate: delegate)
    }

    var labelColors: [NodeLabelColor] {
        NodeLabelColor.allCases
    }

    func nodeLabelColor(
        forNode nodeHandle: HandleEntity,
        completion: ((Result<NodeLabelColor, NodeLabelActionDomainError>) -> Void)?
    ) {
        guard let node = sdk.node(forHandle: nodeHandle) else {
            completion?(.failure(.nodeNotFound))
            return
        }
        guard let labelColor = NodeLabelColor(rawValue: node.label.rawValue) else {
            completion?(.failure(.unsupportedNodeLabelColorFound))
            return
        }
        completion?(.success(labelColor))
    }
}

enum NodeLabelColor: Int, CaseIterable {
    case red = 1
    case orange
    case yellow
    case green
    case blue
    case purple
    case grey
    case unknown = 0
}

private extension NodeLabelColor {
    var sdkLabel: MEGANodeLabel {
        return MEGANodeLabel(rawValue: rawValue) ?? .unknown
    }
}
