import MEGADesignToken
import MEGAPresentation

final class AlbumToolbarConfigurator: ExplorerToolbarConfigurator {
    private let favouriteAction: ButtonAction
    private let removeToRubbishBinAction: ButtonAction
    private let exportAction: ButtonAction
    private let sendToChatAction: ButtonAction
    private let albumType: AlbumType
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    
    private var favouriteItemImage: UIImage {
        albumType == .favourite ? UIImage.removeFavourite : UIImage.favourite
    }
    
    private var isHiddenNodesEnabled: Bool {
        featureFlagProvider.isFeatureFlagEnabled(for: .hiddenNodes)
    }
    
    lazy var favouriteItem = UIBarButtonItem(
        image: favouriteItemImage,
        style: .plain,
        target: self,
        action: #selector(buttonPressed(_:))
    )
    
    lazy var sendToChatItem = UIBarButtonItem(
        image: UIImage.sendToChat,
        style: .plain,
        target: self,
        action: #selector(buttonPressed(_:))
    )
    
    lazy var removeToRubbishBinItem = UIBarButtonItem(
        image: UIImage.rubbishBin,
        style: .plain,
        target: self,
        action: #selector(buttonPressed(_:))
    )
    
    init(
        downloadAction: @escaping ButtonAction,
        shareLinkAction: @escaping ButtonAction,
        moveAction: @escaping ButtonAction,
        copyAction: @escaping ButtonAction,
        deleteAction: @escaping ButtonAction,
        favouriteAction: @escaping ButtonAction,
        removeToRubbishBinAction: @escaping ButtonAction,
        exportAction: @escaping ButtonAction,
        sendToChatAction: @escaping ButtonAction,
        moreAction: @escaping ButtonAction,
        albumType: AlbumType,
        featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider
    ) {
        self.favouriteAction = favouriteAction
        self.removeToRubbishBinAction = removeToRubbishBinAction
        self.exportAction = exportAction
        self.sendToChatAction = sendToChatAction
        self.albumType = albumType
        self.featureFlagProvider = featureFlagProvider
        
        super.init(
            downloadAction: downloadAction,
            shareLinkAction: shareLinkAction,
            moveAction: moveAction,
            copyAction: copyAction,
            deleteAction: deleteAction,
            moreAction: moreAction
        )
    }
    
    override func buttonPressed(_ barButtonItem: UIBarButtonItem) {
        switch barButtonItem {
        case downloadItem:
            super.downloadAction(barButtonItem)
        case shareLinkItem:
            super.shareLinkAction(barButtonItem)
        case favouriteItem:
            favouriteAction(barButtonItem)
        case removeToRubbishBinItem:
            removeToRubbishBinAction(barButtonItem)
        case exportItem:
            exportAction(barButtonItem)
        case sendToChatItem:
            sendToChatAction(barButtonItem)
        case moreItem:
            super.moreAction(barButtonItem)
        default:
            super.buttonPressed(barButtonItem)
        }
    }
    
    override func toolbarItems(forNodes nodes: [MEGANode]?) -> [UIBarButtonItem] {
        var barButtonItems = [
            downloadItem,
            flexibleItem,
            shareLinkItem,
            flexibleItem,
            exportItem,
            flexibleItem,
            sendToChatItem
        ]
        if albumType == .favourite {
            barButtonItems.append(contentsOf: [
                flexibleItem,
                isHiddenNodesEnabled ?  moreItem : favouriteItem
            ])
        } else if albumType == .user {
            barButtonItems.append(contentsOf: [
                flexibleItem,
                isHiddenNodesEnabled ? moreItem : removeToRubbishBinItem
            ])
        }
        
        if featureFlagProvider.isFeatureFlagEnabled(for: .designToken) {
            for barButtonItem in barButtonItems {
                barButtonItem.tintColor = TokenColors.Icon.primary
            }
        }

        return enable(
            nodes?.isNotEmpty == true,
            hasDisputedNodes: nodes?.contains(where: { $0.isTakenDown() }) == true,
            barButtonItems: barButtonItems)
    }
}
