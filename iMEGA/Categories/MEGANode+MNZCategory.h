
@interface MEGANode (MNZCategory) <UITextFieldDelegate>

- (void)mnz_openNodeInNavigationController:(UINavigationController *)navigationController folderLink:(BOOL)isFolderLink;
- (UIViewController *)mnz_viewControllerForNodeInFolderLink:(BOOL)isFolderLink;

- (void)mnz_generateThumbnailForVideoAtPath:(NSURL *)path;

#pragma mark - Actions

- (BOOL)mnz_downloadNodeOverwriting:(BOOL)overwrite;
- (BOOL)mnz_downloadNodeOverwriting:(BOOL)overwrite api:(MEGASdk *)api;
- (void)mnz_renameNodeInViewController:(UIViewController *)viewController;
- (void)mnz_renameNodeInViewController:(UIViewController *)viewController completion:(void(^)(MEGARequest *request))completion;
- (void)mnz_moveToTheRubbishBinInViewController:(UIViewController *)viewController;
- (void)mnz_removeInViewController:(UIViewController *)viewController;
- (void)mnz_leaveSharingInViewController:(UIViewController *)viewController;
- (void)mnz_removeSharing;
- (void)mnz_copyToGalleryFromTemporaryPath:(NSString *)path;
- (void)mnz_restore;
- (void)mnz_saveToPhotosWithApi:(MEGASdk *)api;

#pragma mark - File links

- (void)mnz_fileLinkDownloadFromViewController:(UIViewController *)viewController isFolderLink:(BOOL)isFolderLink;
- (void)mnz_fileLinkImportFromViewController:(UIViewController *)viewController isFolderLink:(BOOL)isFolderLink;

#pragma mark - Utils

- (NSMutableArray *)mnz_parentTreeArray;
- (NSString *)mnz_fileType;
- (BOOL)mnz_isRestorable;
- (BOOL)mnz_isPlayable;

#pragma mark - Versions

- (NSInteger)mnz_numberOfVersions;
- (NSArray *)mnz_versions;
- (long long)mnz_versionsSize;

@end
