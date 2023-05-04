import MEGADomain

public struct CreateContextMenuRepository: CreateContextMenuRepositoryProtocol {
    public static var newRepo: CreateContextMenuRepository {
        CreateContextMenuRepository()
    }
    
    public func createContextMenu(config: CMConfigEntity) -> CMEntity? {
        ContextMenuBuilder()
                        .setType(config.menuType)
                        .setViewMode(config.viewMode)
                        .setAccessLevel(config.accessLevel)
                        .setSortType(config.sortType)
                        .setFilterType(config.filterType)
                        .setIsAFolder(config.isAFolder)
                        .setIsRubbishBinFolder(config.isRubbishBinFolder)
                        .setIsViewInFolder(config.isViewInFolder)
                        .setIsOfflineFolder(config.isOfflineFolder)
                        .setIsRestorable(config.isRestorable)
                        .setIsInVersionsView(config.isInVersionsView)
                        .setVersionsCount(config.versionsCount)
                        .setIsSelectHidden(config.isSelectHidden)
                        .setIsSharedItems(config.isSharedItems)
                        .setIsIncomingShareChild(config.isIncomingShareChild)
                        .setIsFavouritesExplorer(config.isFavouritesExplorer)
                        .setIsDocumentExplorer(config.isDocumentExplorer)
                        .setIsAudiosExplorer(config.isAudiosExplorer)
                        .setIsVideosExplorer(config.isVideosExplorer)
                        .setIsCameraUploadExplorer(config.isCameraUploadExplorer)
                        .setAlbumType(config.albumType)
                        .setIsFilterEnabled(config.isFilterEnabled)
                        .setIsHome(config.isHome)
                        .setShowMediaDiscovery(config.showMediaDiscovery)
                        .setChatStatus(config.chatStatus)
                        .setIsDoNotDisturbEnabled(config.isDoNotDisturbEnabled)
                        .setTimeRemainingToDeactiveDND(config.timeRemainingToDeactiveDND)
                        .setIsShareAvailable(config.isShareAvailable)
                        .setBackupsRootNode(config.isBackupsRootNode)
                        .setIsBackupsChild(config.isBackupsChild)
                        .setIsSharedItemsChild(config.isSharedItemsChild)
                        .setIsOutShare(config.isOutShare)
                        .setIsExported(config.isExported)
                        .setIsEmptyState(config.isEmptyState)
                        .setShouldScheduleMeeting(config.shouldScheduleMeeting)
                        .setSharedLinkStatus(config.sharedLinkStatus)
                        .build()
    }
}
