import Foundation
import MEGADomain
import MEGAL10n
import MEGASDKRepo

// This protocol was added to enable both new and legacy Cloud Drive screen use the same navigation mechanism
// using NodeOpener to drill deeper into folders or files, and also use the same for context menu presentation
protocol NodeRouting {
    func didTapMoreAction(
        on node: HandleEntity,
        button: UIButton
    )
    
    func didTapMoreAction(
        on node: HandleEntity,
        button: UIButton,
        displayMode: DisplayMode?
    )

    func didTapNode(nodeHandle: HandleEntity, allNodeHandles: [HandleEntity]?, displayMode: DisplayMode?)

    func didTapNode(nodeHandle: HandleEntity, allNodeHandles: [HandleEntity]?)

    func didTapNode(nodeHandle: HandleEntity)
}

final class HomeSearchResultRouter: NodeRouting {
    
    private weak var navigationController: UINavigationController?
    
    private var nodeActionViewControllerDelegate: NodeActionViewControllerGenericDelegate
    
    private lazy var nodeOpener = NodeOpener(navigationController: navigationController)
    
    private let backupsUseCase: any BackupsUseCaseProtocol
    
    private let nodeUseCase: any NodeUseCaseProtocol
    
    init(
        navigationController: UINavigationController,
        nodeActionViewControllerDelegate: NodeActionViewControllerGenericDelegate,
        backupsUseCase: some BackupsUseCaseProtocol,
        nodeUseCase: some NodeUseCaseProtocol
    ) {
        self.navigationController = navigationController
        self.nodeActionViewControllerDelegate = nodeActionViewControllerDelegate
        self.backupsUseCase = backupsUseCase
        self.nodeUseCase = nodeUseCase
    }
    
    func didTapMoreAction(
        on node: HandleEntity,
        button: UIButton
    ) {
        didTapMoreAction(on: node, button: button, displayMode: nil)
    }
    
    func didTapMoreAction(
        on node: HandleEntity,
        button: UIButton,
        displayMode: DisplayMode?
    ) {
        let isBackupNode = backupsUseCase.isBackupNodeHandle(node)
        guard let nodeActionViewController = NodeActionViewController(
            node: node,
            delegate: nodeActionViewControllerDelegate,
            displayMode: displayMode ?? .cloudDrive,
            isIncoming: false,
            isBackupNode: isBackupNode,
            sender: button
        ) else { return }
        navigationController?.present(nodeActionViewController, animated: true, completion: nil)
    }

    func didTapNode(nodeHandle: HandleEntity, allNodeHandles: [HandleEntity]?, displayMode: DisplayMode?) {
        guard let node = nodeUseCase.nodeForHandle(nodeHandle) else { return }
        if node.isTakenDown {
            showTakenDownAlert(isFolder: node.isFolder)
        } else {
            nodeOpener.openNode(
                nodeHandle: nodeHandle,
                allNodes: allNodeHandles,
                config: .withOptionalDisplayMode(displayMode)
            )
        }
    }
    
    func didTapNode(nodeHandle: HandleEntity, allNodeHandles: [HandleEntity]?) {
        didTapNode(nodeHandle: nodeHandle, allNodeHandles: allNodeHandles, displayMode: nil)
    }
    
    func didTapNode(nodeHandle: HandleEntity) {
        didTapNode(nodeHandle: nodeHandle, allNodeHandles: nil, displayMode: nil)
    }
    
    func showTakenDownAlert(isFolder: Bool) {
        let alert = UIAlertController(model: takenDownModel(isFolder: isFolder))
        navigationController?.present(alert, animated: true)
    }
    
    func takenDownModel(isFolder: Bool) -> AlertModel {
        let message = isFolder ? Strings.Localizable.thisFolderHasBeenTheSubjectOfATakedownNotice : Strings.Localizable.thisFileHasBeenTheSubjectOfATakedownNotice
        return .init(
            title: nil,
            message: message,
            actions: [
                .init(
                    title: Strings.Localizable.disputeTakedown,
                    style: .default,
                    handler: {
                        NSURL(string: MEGADisputeURL)?.mnz_presentSafariViewController()
                    }
                ),
                .init(
                    title: Strings.Localizable.cancel,
                    style: .cancel,
                    handler: {}
                )
            ]
        )
    }
}
