import MEGADomain
import MEGAPresentation
import MEGASDKRepo
import SwiftUI
import Video

struct FilesExplorerRouter {
    private weak var navigationController: UINavigationController?
    private let explorerType: ExplorerTypeEntity
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    
    init(navigationController: UINavigationController?, explorerType: ExplorerTypeEntity, featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider) {
        self.navigationController = navigationController
        self.explorerType = explorerType
        self.featureFlagProvider = featureFlagProvider
    }
    
    func start() {
        guard let navController = navigationController else {
            MEGALogDebug("Unable to start Document Explorer screen as navigation controller is nil")
            return
        }
        
        if explorerType == .video && featureFlagProvider.isFeatureFlagEnabled(for: .videoRevamp) {
            let isDesignTokenEnabled = featureFlagProvider.isFeatureFlagEnabled(for: .designToken)
            let router = VideoRevampRouter(explorerType: explorerType, navigationController: navigationController, isDesignTokenEnabled: isDesignTokenEnabled)
            router.start()
            return
        }
        
        let sdk = MEGASdk.shared
        let nodesUpdateListenerRepo = SDKNodesUpdateListenerRepository(sdk: sdk)
        let transferListenerRepo = SDKTransferListenerRepository(sdk: sdk)
        let fileSearchRepo = FilesSearchRepository(sdk: sdk)
        let clipboardOperationRepo = SDKNodeClipboardOperationRepository(sdk: sdk)
        let useCase = FilesSearchUseCase(repo: fileSearchRepo,
                                         nodeFormat: explorerType.toNodeFormatEntity(),
                                         nodesUpdateListenerRepo: nodesUpdateListenerRepo,
                                         nodeRepository: NodeRepository.newRepo)
        let nodeClipboardOperationUseCase = NodeClipboardOperationUseCase(repo: clipboardOperationRepo)
        let fileDownloadUseCase = FilesDownloadUseCase(repo: transferListenerRepo)
        let createContextMenuUseCase = CreateContextMenuUseCase(repo: CreateContextMenuRepository.newRepo)
        
        let viewModel = FilesExplorerViewModel(
            explorerType: explorerType,
            router: self,
            useCase: useCase,
            filesDownloadUseCase: fileDownloadUseCase,
            nodeClipboardOperationUseCase: nodeClipboardOperationUseCase,
            contentConsumptionUserAttributeUseCase: ContentConsumptionUserAttributeUseCase(
                repo: UserAttributeRepository.newRepo),
            createContextMenuUseCase: createContextMenuUseCase,
            nodeProvider: DefaultMEGANodeProvider(sdk: .sharedSdk))
        let preference: FilesExplorerContainerViewController.ViewPreference = explorerType == .video ? .list : .both
        let vc = FilesExplorerContainerViewController(viewModel: viewModel,
                                                      viewPreference: preference)
        navController.pushViewController(vc, animated: true)
    }
    
    func didSelect(node: MEGANode, allNodes: [MEGANode]) {
        NodeOpener(navigationController: navigationController)
            .openNode(node: node, allNodes: allNodes)
    }
    
    func showDownloadTransfer(node: MEGANode) {
        guard let navigationController = navigationController else {
            return
        }
        
        let transfer = CancellableTransfer(handle: node.handle, name: nil, appData: nil, priority: false, isFile: node.isFile(), type: .download)
        CancellableTransferRouter(presenter: navigationController, transfers: [transfer], transferType: .download).start()
    }
}
