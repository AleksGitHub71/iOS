#import <UIKit/UIKit.h>

#import "DisplayMode.h"

@class MEGANode;
@class MEGAUser;
@class MyAvatarManager;

static const NSUInteger kMinimumLettersToStartTheSearch = 1;

NS_ASSUME_NONNULL_BEGIN

@interface CloudDriveViewController : UIViewController

@property (nonatomic, strong, nullable) MEGANode *parentNode;
@property (nonatomic, strong, nullable) MEGAUser *user;
@property (nonatomic) DisplayMode displayMode;
@property (nonatomic, getter=isIncomingShareChildView) BOOL incomingShareChildView;

@property (nonatomic, strong, nullable) MEGANodeList *nodes;
@property (nonatomic, strong, nullable) NSMutableArray<MEGANode *> *searchNodesArray;
@property (nonatomic, strong, nullable) NSMutableArray<MEGANode *> *selectedNodesArray;
@property (nonatomic, strong, nullable) NSMutableDictionary *nodesIndexPathMutableDictionary;

@property (nonatomic, strong, nullable) MEGARecentActionBucket *recentActionBucket;

@property (strong, nonatomic, nullable) UISearchController *searchController;

@property (assign, nonatomic) BOOL allNodesSelected;
@property (assign, nonatomic) BOOL shouldRemovePlayerDelegate;

@property (nonatomic, strong, nullable) MyAvatarManager * myAvatarManager;

- (void)presentUploadAlertController;
- (void)presentScanDocument;
- (void)setViewEditing:(BOOL)editing;
- (void)updateNavigationBarTitle;
- (void)toolbarActionsForNodeArray:(NSArray *)nodeArray;
- (void)setToolbarActionsEnabled:(BOOL)boolValue;
- (void)showCustomActionsForNode:(MEGANode *)node sender:(UIButton *)sender;
- (void)didSelectNode:(MEGANode *)node;
- (void)confirmDeleteActionFiles:(NSUInteger)numFilesAction andFolders:(NSUInteger)numFoldersAction;
- (void)setEditMode:(BOOL)editMode;
- (nullable MEGANode *)nodeAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
