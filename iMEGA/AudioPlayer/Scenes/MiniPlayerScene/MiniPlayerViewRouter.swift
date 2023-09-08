import Foundation
import MEGAPresentation
import UIKit

final class MiniPlayerViewRouter: NSObject, MiniPlayerViewRouting {
    private weak var baseViewController: UIViewController?
    private weak var presenter: UIViewController?
    private var configEntity: AudioPlayerConfigEntity
    private var folderSDKLogoutRequired: Bool = false
    
    init(configEntity: AudioPlayerConfigEntity, presenter: UIViewController) {
        self.configEntity = configEntity
        self.presenter = presenter
    }
    
    @objc func build() -> UIViewController {
        let vc = UIStoryboard(name: "AudioPlayer", bundle: nil).instantiateViewController(withIdentifier: "MiniPlayerViewControllerID") as! MiniPlayerViewController
                
        folderSDKLogoutRequired = configEntity.isFolderLink
        
        vc.viewModel = MiniPlayerViewModel(
            configEntity: configEntity,
            router: MiniPlayerViewRouterMainQueueDispatchDecorator(decoratee: self),
            nodeInfoUseCase: NodeInfoUseCase(nodeInfoRepository: NodeInfoRepository()),
            streamingInfoUseCase: StreamingInfoUseCase(streamingInfoRepository: StreamingInfoRepository()),
            offlineInfoUseCase: configEntity.relatedFiles != nil ? OfflineFileInfoUseCase(offlineInfoRepository: OfflineInfoRepository()) : nil,
            playbackContinuationUseCase: DIContainer.playbackContinuationUseCase
        )
        
        baseViewController = vc
        
        return vc
    }

    @objc func start() {
        configEntity.playerHandler.presentMiniPlayer(build())
    }
    
    @objc func updatePresenter(_ presenter: UIViewController) {
        self.presenter = presenter
    }
    
    func folderSDKLogout(required: Bool) {
        folderSDKLogoutRequired = required
    }
    
    func isFolderSDKLogoutRequired() -> Bool {
        folderSDKLogoutRequired && !isAFolderLinkPresenter()
    }
    
    func isAFolderLinkPresenter() -> Bool {
        presenter?.isKind(of: FolderLinkViewController.self) ?? false
    }
    
    // MARK: - UI Actions
    func dismiss() {
        configEntity.playerHandler.closePlayer()
    }
    
    func showPlayer(node: MEGANode?, filePath: String?) {
        guard let presenter = presenter else { return }
                
        AudioPlayerManager.shared.initFullScreenPlayer(node: node, fileLink: filePath, filePaths: configEntity.relatedFiles, isFolderLink: configEntity.isFolderLink, presenter: presenter, messageId: .invalid, chatId: .invalid, allNodes: nil)

    }
}

final class MiniPlayerViewRouterMainQueueDispatchDecorator: MiniPlayerViewRouting {
    private let decoratee: any MiniPlayerViewRouting
    
    init(decoratee: some MiniPlayerViewRouting) {
        self.decoratee = decoratee
    }
    
    func dismiss() {
        runOnMainThread { [weak self] in
            self?.decoratee.dismiss()
        }
    }
    
    func showPlayer(node: MEGANode?, filePath: String?) {
        runOnMainThread { [weak self] in
            self?.decoratee.showPlayer(node: node, filePath: filePath)
        }
    }
    
    func isAFolderLinkPresenter() -> Bool {
        decoratee.isAFolderLinkPresenter()
    }
    
    func build() -> UIViewController {
        decoratee.build()
    }
    
    func start() {
        runOnMainThread { [weak self] in
            self?.decoratee.start()
        }
    }
    
    private func runOnMainThread(completion: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { completion() }
            return
        }
        completion()
    }
}
