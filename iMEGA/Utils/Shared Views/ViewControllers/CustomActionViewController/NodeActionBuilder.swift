final class NodeActionBuilder {
    private var displayMode: DisplayMode = .unknown
    private var accessLevel: MEGAShareType = .accessUnknown
    private var isMediaFile = false
    private var isEditableTextFile = false
    private var isFile = false
    private var versionCount = 0
    private var isFavourite = false
    private var label: MEGANodeLabel = .unknown
    private var isRestorable = false
    private var isPdf = false
    private var isLink = false
    private var isPageView = true
    private var isIncomingShareChildView = false
    private var isExported = false
    private var linkedNodeCount = 0
    private var isAllLinkedNode = false
    private var isOutShare = false
    private var isChildVersion = false
    private var isInVersionsView = false
    private var selectedNodeCount = 1
    private var viewMode: ViewModePreference = .list
    private var nodeSelectionType: NodeSelectionType = .single
    private var isBackupNode: Bool = false
    private var isTakedown = false
    private var isVerifyContact = false
    private var areMediaFiles = false
    private var sharedFolderContact: MEGAUser = MEGAUser()
    private var sharedFolderReceiverDetail = ""

    func setDisplayMode(_ displayMode: DisplayMode) -> NodeActionBuilder {
        self.displayMode = displayMode
        return self
    }
    
    func setAccessLevel(_ accessLevel: MEGAShareType) -> NodeActionBuilder {
        self.accessLevel = accessLevel
        return self
    }
    
    func setIsMediaFile(_ isMediaFile: Bool) -> NodeActionBuilder {
        self.isMediaFile = isMediaFile
        return self
    }
    
    func setIsEditableTextFile(_ isEditableTextFile: Bool) -> NodeActionBuilder {
        self.isEditableTextFile = isEditableTextFile
        return self
    }
    
    func setIsFile(_ isFile: Bool) -> NodeActionBuilder {
        self.isFile = isFile
        return self
    }
    
    func setVersionCount(_ versionCount: Int) -> NodeActionBuilder {
        self.versionCount = versionCount
        return self
    }
    
    func setIsFavourite(_ isFavourite: Bool) -> NodeActionBuilder {
        self.isFavourite = isFavourite
        return self
    }
    
    func setLabel(_ label: MEGANodeLabel) -> NodeActionBuilder {
        self.label = label
        return self
    }
    
    func setIsRestorable(_ isRestorable: Bool) -> NodeActionBuilder {
        self.isRestorable = isRestorable
        return self
    }
    
    func setIsPdf(_ isPdf: Bool) -> NodeActionBuilder {
        self.isPdf = isPdf
        return self
    }
    
    func setIsLink(_ isLink: Bool) -> NodeActionBuilder {
        self.isLink = isLink
        return self
    }
    
    func setIsPageView(_ isPageView: Bool) -> NodeActionBuilder {
        self.isPageView = isPageView
        return self
    }
    
    func setisIncomingShareChildView(_ isIncomingShareChildView: Bool) -> NodeActionBuilder {
        self.isIncomingShareChildView = isIncomingShareChildView
        return self
    }
    
    func setIsExported(_ isExported: Bool) -> NodeActionBuilder {
        self.isExported = isExported
        return self
    }
    
    func setLinkedNodeCount(_ count: Int) -> NodeActionBuilder {
        self.linkedNodeCount = count
        return self
    }
    
    func setIsAllLinkedNode(_ isAllLinkedNode: Bool) -> NodeActionBuilder {
        self.isAllLinkedNode = isAllLinkedNode
        return self
    }
    
    func setIsOutshare(_ isOutShare: Bool) -> NodeActionBuilder {
        self.isOutShare = isOutShare
        return self
    }
    
    func setIsChildVersion(_ isChildVersion: Bool?) -> NodeActionBuilder {
        self.isChildVersion = isChildVersion ?? false
        return self
    }
    
    func setIsInVersionsView(_ isInVersionsView: Bool) -> NodeActionBuilder {
        self.isInVersionsView = isInVersionsView
        return self
    }

    func setViewMode(_ viewMode: ViewModePreference?) -> NodeActionBuilder {
        self.viewMode = viewMode ?? .list
        return self
    }
    
    func setNodeSelectionType(_ selectionType: NodeSelectionType?,
                              selectedNodeCount: Int) -> NodeActionBuilder {
        self.nodeSelectionType = selectionType ?? .single
        self.selectedNodeCount = selectedNodeCount
        return self
    }
    
    func setIsBackupNode(_ isBackupNode: Bool) -> NodeActionBuilder {
        self.isBackupNode = isBackupNode
        return self
    }
    
    func setIsTakedown(_ isTakedown: Bool) -> NodeActionBuilder {
        self.isTakedown = isTakedown
        return self
    }
    
    func setIsVerifyContact(_ isVerifyContact: Bool,
                            sharedFolderReceiverEmail: String,
                            sharedFolderContact: MEGAUser?) -> NodeActionBuilder {
        self.isVerifyContact = isVerifyContact
        self.sharedFolderReceiverDetail = sharedFolderContact?.mnz_displayName ?? sharedFolderContact?.email ?? sharedFolderReceiverEmail
        return self
    }
    
    func setAreMediaFiles(_ areMediaFiles: Bool) -> NodeActionBuilder {
        self.areMediaFiles = areMediaFiles
        return self
    }
    
    func build() -> [NodeAction] {
        var nodeActions = [NodeAction]()
        
        if isTakedown {
            nodeActions.append(contentsOf: takedownNodeActions())
        } else {
            if shouldAddRestoreAction() {
                nodeActions.append(.restoreAction())
            }
            
            nodeActions.append(contentsOf: nodeActionsForDisplayModeOrAccessLevels())
        }
    
        return nodeActions
    }
    
    func multiselectBuild() -> [NodeAction] {
        switch displayMode {
        case .photosAlbum:
            return normalAlbumActions()
        case .photosFavouriteAlbum:
            return favouriteAlbumActions()
        default: break
        }
        
        switch nodeSelectionType {
        case .single:
            return []
        case .files:
            return multiselectFilesActions()
        case .folders:
            return multiselectFoldersActions()
        case .filesAndFolders:
            return multiselectFoldersAndFilesActions()
        }
    }
    
    // MARK: - Private methods
    
    private func shouldAddRestoreAction() -> Bool {
        guard isRestorable else {
            return false
        }
        
        return displayMode == .rubbishBin ? !isInVersionsView : true
    }
    
    private func folderLinkNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = [
            .importAction(),
            .downloadAction(),
            .selectAction(),
            .shareLinkAction(),
            .sendToChatAction(),
            .sortAction()
        ]
        
        if viewMode == .list {
            nodeActions.append(.thumbnailAction())
        } else {
            nodeActions.append(.listAction())
        }
        
        return nodeActions
    }
    
    private func fileLinkNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = [.importAction(), .downloadAction(), .shareLinkAction(), .sendToChatAction()]
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        return nodeActions
    }
    
    private func nodeInsideFolderLinkActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = [.importAction(), .downloadAction()]

        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        return nodeActions
    }
    
    private func textEditorActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []

        if !isBackupNode && accessLevel != .accessRead && accessLevel != .accessUnknown  {
            nodeActions.append(.textEditorAction())
        }
        nodeActions.append(.downloadAction())
        if accessLevel != .accessOwner {
            nodeActions.append(.importAction())
        }
        if accessLevel == .accessOwner {
            nodeActions.append(contentsOf: exportedNodeActions())
        }
        nodeActions.append(.exportFileAction())
        nodeActions.append(.sendToChatAction())

        return nodeActions
    }
    
    private func previewDocumentNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []

        if isLink {
            nodeActions.append(.importAction())
        }
        nodeActions.append(.downloadAction())
        if accessLevel == .accessOwner || isLink {
            nodeActions.append(.shareLinkAction())
        }
        if accessLevel == .accessOwner {
            nodeActions.append(.exportFileAction())
        }
        nodeActions.append(.sendToChatAction())
        if isPdf {
            nodeActions.append(.searchAction())
            if isPageView {
                nodeActions.append(.pdfThumbnailViewAction())
            } else {
                nodeActions.append(.pdfPageViewAction())
            }
        }

        return nodeActions
    }
    
    private func chatNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = [.forwardAction()]
        nodeActions.append(.downloadAction())
        nodeActions.append(.exportFileAction())
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        if accessLevel != .accessOwner {
            nodeActions.append(.importAction())
        }
        return nodeActions
    }
    
    private func transfersNodeActions() -> [NodeAction] {
        [.viewInFolderAction(), .shareLinkAction(), .clearAction()]
    }
    
    private func transfersFailedNodeActions() -> [NodeAction] {
        [.retryAction(), .clearAction()]
    }
    
    private func verifyContactNodeActions(accessType: MEGAShareType) -> [NodeAction] {
        var nodeActions: [NodeAction] = []
        nodeActions.append(.verifyContactAction(receiverDetail: sharedFolderReceiverDetail))
        nodeActions.append(.infoAction())
        
        if accessType == .accessFull {
            nodeActions.append(.labelAction(label: label))
        }
        
        if isIncomingShareChildView {
            nodeActions.append(.leaveSharingAction())
        }
        return nodeActions
    }
    
    private func unknownAccessLevelNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = [.importAction()]
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        nodeActions.append(.downloadAction())
        return nodeActions
    }
    
    private func readAndWriteAccessLevelNodeActions() -> [NodeAction] {
        guard !isVerifyContact else {
            return verifyContactNodeActions(accessType: .accessReadWrite)
        }
        
        var nodeActions: [NodeAction] = []

        if accessLevel == .accessReadWrite && isEditableTextFile && (displayMode == .cloudDrive || displayMode == .recents || displayMode == .sharedItem) && !isBackupNode {
            nodeActions.append(.textEditorAction())
        }
        
        if displayMode != .nodeInfo && displayMode != .nodeVersions {
            nodeActions.append(.infoAction())
            if versionCount > 0 {
                nodeActions.append(.viewVersionsAction(versionCount: versionCount))
            }
        }
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        nodeActions.append(.downloadAction())
        
        if displayMode != .nodeVersions {
            nodeActions.append(.copyAction())
            if isIncomingShareChildView {
                nodeActions.append(.leaveSharingAction())
            }
        } else if accessLevel == .accessReadWrite && isChildVersion {
            nodeActions.append(.revertVersionAction())
        }
        
        return nodeActions
    }
    
    private func fullAccessLevelNodeActions() -> [NodeAction] {
        guard !isVerifyContact else {
            return verifyContactNodeActions(accessType: .accessFull)
        }
        
        var nodeActions: [NodeAction] = []
        
        if isVerifyContact {
            nodeActions.append(.verifyContactAction(receiverDetail: sharedFolderReceiverDetail))
        }

        if !isBackupNode && isEditableTextFile && (displayMode == .cloudDrive || displayMode == .recents || displayMode == .sharedItem) {
            nodeActions.append(.textEditorAction())
        }
        if displayMode != .nodeInfo && displayMode != .nodeVersions {
            nodeActions.append(.infoAction())
            if versionCount > 0 {
                nodeActions.append(.viewVersionsAction(versionCount: versionCount))
            }
            
            if !isBackupNode {
                nodeActions.append(.labelAction(label: label))
            }
        }
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        nodeActions.append(.downloadAction())
        if displayMode == .nodeVersions {
            if isChildVersion {
                nodeActions.append(.revertVersionAction())
            }
            nodeActions.append(.removeVersionAction())
        } else {
            if !isBackupNode {
                nodeActions.append(.renameAction())
            }
            nodeActions.append(.copyAction())
            if isIncomingShareChildView {
                nodeActions.append(.leaveSharingAction())
            } else {
                nodeActions.append(.moveAction())
                nodeActions.append(.moveToRubbishBinAction())
            }
        }
        
        return nodeActions
    }
    
    private func ownerAccessLevelNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []

        switch displayMode {
        case .unknown: break
            
        case .cloudDrive, .sharedItem, .nodeInfo, .recents:
            if isBackupNode {
                nodeActions = backupsNodeActions()
            } else {
                nodeActions = cloudLikeViewsNodeActions()
            }
            
        case .rubbishBin:
            nodeActions = nodeActionsForRubbishBin()
            
        case .folderLink, .fileLink, .nodeInsideFolderLink, .publicLinkTransfers, .transfers, .transfersFailed, .chatSharedFiles, .previewDocument, .textEditor, .photosAlbum, .photosFavouriteAlbum, .photosTimeline, .mediaDiscovery: break
            
        case .nodeVersions:
            nodeActions = nodeVersionsNodeActions()
            
        case .chatAttachment:
            nodeActions = chatAttachmentNodeActions()

        case .backup:
            nodeActions = backupsNodeActions()
            
        @unknown default: break
        }
        
        return nodeActions
    }
    
    private func nodeActionsForDisplayModeOrAccessLevels() -> [NodeAction] {
        switch displayMode {
        case .folderLink:
            return folderLinkNodeActions()
        case .fileLink:
            return fileLinkNodeActions()
        case .nodeInsideFolderLink:
            return nodeInsideFolderLinkActions()
        case .publicLinkTransfers:
            return [.clearAction()]
        case .transfers:
            return transfersNodeActions()
        case .transfersFailed:
            return transfersFailedNodeActions()
        case .chatSharedFiles, .chatAttachment:
            return chatNodeActions()
        case .previewDocument:
            return previewDocumentNodeActions()
        case .textEditor:
            return textEditorActions()
        default: //.unknown, .cloudDrive, .rubbishBin, .sharedItem, .nodeInfo, .nodeVersions, .recents
            switch accessLevel {
            case .accessUnknown:
                return unknownAccessLevelNodeActions()
            case .accessRead, .accessReadWrite:
                return readAndWriteAccessLevelNodeActions()
            case .accessFull:
                return fullAccessLevelNodeActions()
            case .accessOwner:
                return ownerAccessLevelNodeActions()
            default:
                return []
            }
        }
    }
    
    private func cloudLikeViewsNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []
        
        if isVerifyContact {
            nodeActions.append(.verifyContactAction(receiverDetail: sharedFolderReceiverDetail))
        }
        
        if !isBackupNode && isEditableTextFile && (displayMode == .cloudDrive || displayMode == .recents || displayMode == .sharedItem) {
            nodeActions.append(.textEditorAction())
        }
        
        if displayMode != .nodeInfo {
            nodeActions.append(.infoAction())
            if versionCount > 0 {
                nodeActions.append(.viewVersionsAction(versionCount: versionCount))
            }
            if !isBackupNode {
                nodeActions.append(.favouriteAction(isFavourite: isFavourite))
                nodeActions.append(.labelAction(label: label))
            }
        }
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        nodeActions.append(.downloadAction())
        
        nodeActions.append(contentsOf: exportedNodeActions())
        
        if !isFile {
            if isOutShare {
                nodeActions.append(.manageFolderAction())
            } else {
                nodeActions.append(.shareFolderAction())
            }
        } else {
            nodeActions.append(.exportFileAction())
        }
        
        if isFile {
            nodeActions.append(.sendToChatAction())
        }
        
        if !isBackupNode {
            nodeActions.append(.renameAction())
        }
        
        if displayMode != .sharedItem && !isBackupNode {
            nodeActions.append(.moveAction())
        }
        
        nodeActions.append(.copyAction())
        
        if !isBackupNode {
            if displayMode == .cloudDrive || displayMode == .nodeInfo || displayMode == .recents {
                nodeActions.append(.moveToRubbishBinAction())
            }
        }
        
        if displayMode == .sharedItem {
            nodeActions.append(.removeSharingAction())
        }
        
        return nodeActions
    }
    
    private func nodeActionsForRubbishBin() -> [NodeAction] {
        var nodeActions: [NodeAction] = []

        if isBackupNode {
            nodeActions.append(.restoreBackupAction())
        }

        nodeActions.append(.infoAction())

        if !isInVersionsView {
            if versionCount > 0 {
                nodeActions.append(.viewVersionsAction(versionCount: versionCount))
            }
            nodeActions.append(.removeAction())
        }
        
        return nodeActions
    }
    
    private func nodeVersionsNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        nodeActions.append(.downloadAction())
        nodeActions.append(.exportFileAction())
        if isChildVersion {
            if isBackupNode {
                nodeActions.append(.copyAction())
            } else {
                nodeActions.append(.revertVersionAction())
            }
        }
        
        if !(isBackupNode && !isChildVersion) {
            nodeActions.append(.removeVersionAction())
        }
        return nodeActions
    }
    
    private func chatAttachmentNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []
        
        nodeActions.append(.infoAction())
        if versionCount > 0 {
            nodeActions.append(.viewVersionsAction(versionCount: versionCount))
        }
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        nodeActions.append(.downloadAction())
        nodeActions.append(.shareLinkAction())
        nodeActions.append(.exportFileAction())
        nodeActions.append(.sendToChatAction())
        
        return nodeActions
    }
    
    private func backupsNodeActions() -> [NodeAction] {
        var nodeActions: [NodeAction] = []
        
        nodeActions.append(.infoAction())
        
        if isFile && versionCount > 0 {
            nodeActions.append(.viewVersionsAction(versionCount: versionCount))
        }
        
        if isMediaFile {
            nodeActions.append(.saveToPhotosAction())
        }
        
        nodeActions.append(.downloadAction())
        
        if isExported {
            nodeActions.append(.manageLinkAction())
            nodeActions.append(.removeLinkAction())
        } else {
            nodeActions.append(.shareLinkAction())
        }
        
        if isFile {
            nodeActions.append(.exportFileAction())
            nodeActions.append(.sendToChatAction())
        } else {
            if isOutShare {
                nodeActions.append(.manageFolderAction())
            } else {
                nodeActions.append(.shareFolderAction())
            }
        }
        
        nodeActions.append(.copyAction())
        
        if isOutShare && displayMode == .sharedItem {
            nodeActions.append(.removeSharingAction())
        }
        
        return nodeActions
    }
    
    private func multiselectedLinkNodesAction() -> NodeAction {
        isAllLinkedNode ?
            .manageLinkAction(nodeCount: linkedNodeCount) :
            .shareLinkAction(nodeCount: selectedNodeCount)
    }
    
    private func multiselectFoldersActions() -> [NodeAction] {
        var actions = [.downloadAction(),
                       multiselectedLinkNodesAction(),
                       .shareFolderAction(nodeCount: selectedNodeCount)]
        
        if isBackupNode {
            actions.append(.copyAction())
        } else {
            actions.append(contentsOf: [.moveAction(), .copyAction(), .moveToRubbishBinAction()])
        }
        
        if linkedNodeCount > 0 {
            actions.insert(.removeLinkAction(nodeCount: linkedNodeCount), at: 2)
        }
        return actions
    }
    
    private func multiselectFilesActions() -> [NodeAction] {
        var actions = [.downloadAction(),
                       multiselectedLinkNodesAction(),
                       .exportFileAction(nodeCount: selectedNodeCount),
                       .sendToChatAction()]
        
        if areMediaFiles {
            actions.append(.saveToPhotosAction())
        }
        
        if isBackupNode {
            actions.append(.copyAction())
        } else {
            actions.append(contentsOf: [.moveAction(), .copyAction(), .moveToRubbishBinAction()])
        }
        
        if linkedNodeCount > 0 {
            actions.insert(.removeLinkAction(nodeCount: linkedNodeCount), at: 2)
        }
        return actions
    }
    
    private func multiselectFoldersAndFilesActions() -> [NodeAction] {
        var actions = [.downloadAction(),
                       multiselectedLinkNodesAction()]
        
        if isBackupNode {
            actions.append(.copyAction())
        } else {
            actions.append(contentsOf: [.moveAction(), .copyAction(), .moveToRubbishBinAction()])
        }
        
        if linkedNodeCount > 0 {
            actions.insert(.removeLinkAction(nodeCount: linkedNodeCount), at: 2)
        }
        return actions
    }
    
    private func favouriteAlbumActions() -> [NodeAction] {
        [.downloadAction(),
         .shareLinkAction(nodeCount: selectedNodeCount),
         .exportFileAction(nodeCount: selectedNodeCount),
         .sendToChatAction(),
         .saveToPhotosAction(),
         .favouriteAction(isFavourite: isFavourite),
         .copyAction(),
         .moveToRubbishBinAction()]
    }
    
    private func normalAlbumActions() -> [NodeAction] {
        [.downloadAction(),
         .shareLinkAction(nodeCount: selectedNodeCount),
         .exportFileAction(nodeCount: selectedNodeCount),
         .sendToChatAction(),
         .saveToPhotosAction(),
         .moveAction(),
         .copyAction()]
    }
    
    private func takedownNodeActions() -> [NodeAction] {
        [.infoAction(),
         .disputeTakedownAction(),
         .renameAction(),
         displayMode == .rubbishBin ? .removeAction() :
         .moveToRubbishBinAction()]
    }
    
    private func exportedNodeActions() -> [NodeAction] {
        if isExported {
            return [.manageLinkAction(), .removeLinkAction()]
        } else {
            return [.shareLinkAction()]
        }
    }
}
