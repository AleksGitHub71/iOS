#import "SharedItemsViewController.h"

#import "SVProgressHUD.h"
#import "UIScrollView+EmptyDataSet.h"

#import "Helper.h"
#import "MEGASdkManager.h"
#import "MEGAReachabilityManager.h"
#import "MEGANavigationController.h"
#import "MEGANode+MNZCategory.h"
#import "MEGAUser+MNZCategory.h"
#import "MEGARemoveRequestDelegate.h"
#import "MEGAShareRequestDelegate.h"
#import "NSMutableArray+MNZCategory.h"

#import "BrowserViewController.h"
#import "CloudDriveViewController.h"
#import "ContactsViewController.h"
#import "SharedItemsTableViewCell.h"
#import "CustomActionViewController.h"
#import "NodeInfoViewController.h"

@interface SharedItemsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UIViewControllerPreviewingDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGAGlobalDelegate, MEGARequestDelegate, MGSwipeTableCellDelegate, NodeInfoViewControllerDelegate, CustomActionViewControllerDelegate> {
    BOOL allNodesSelected;
}

@property (nonatomic) id<UIViewControllerPreviewing> previewingContext;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *carbonCopyBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *leaveShareBarButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareFolderBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeShareBarButtonItem;

@property (nonatomic, strong) MEGAShareList *incomingShareList;
@property (nonatomic, strong) NSMutableArray *incomingNodesMutableArray;

@property (nonatomic, strong) MEGAShareList *outgoingShareList;
@property (nonatomic, strong) NSMutableArray *outgoingSharesMutableArray;
@property (nonatomic, strong) NSMutableArray *outgoingNodesMutableArray;

@property (nonatomic, strong) NSMutableArray *selectedNodesMutableArray;
@property (nonatomic, strong) NSMutableArray *selectedSharesMutableArray;

@property (nonatomic, strong) NSMutableDictionary *incomingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *incomingIndexPathsMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingIndexPathsMutableDictionary;

@property (nonatomic) NSMutableArray *searchNodesArray;
@property (nonatomic) UISearchController *searchController;

@property (weak, nonatomic) IBOutlet UIView *selectorView;
@property (weak, nonatomic) IBOutlet UIButton *incomingButton;
@property (weak, nonatomic) IBOutlet UIView *incomingLineView;
@property (weak, nonatomic) IBOutlet UIButton *outgoingButton;
@property (weak, nonatomic) IBOutlet UIView *outgoingLineView;

@end

@implementation SharedItemsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.definesPresentationContext = YES;
    
    //White background for the view behind the table view
    self.tableView.backgroundView = UIView.alloc.init;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.navigationItem.title = AMLocalizedString(@"sharedItems", @"Title of Shared Items section");
    
    self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem];
    self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
    
    [self.incomingButton setTitle:AMLocalizedString(@"incoming", nil) forState:UIControlStateNormal];
    [self.outgoingButton setTitle:AMLocalizedString(@"outgoing", nil) forState:UIControlStateNormal];
    
    self.incomingNodesForEmailMutableDictionary = NSMutableDictionary.alloc.init;
    self.incomingIndexPathsMutableDictionary = NSMutableDictionary.alloc.init;
    self.outgoingNodesForEmailMutableDictionary = NSMutableDictionary.alloc.init;
    self.outgoingIndexPathsMutableDictionary = NSMutableDictionary.alloc.init;
    
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    
    self.searchController = [Helper customSearchControllerWithSearchResultsUpdaterDelegate:self searchBarDelegate:self];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
    });
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    
    if (self.searchController && !self.tableView.tableHeaderView) {
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
    
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([self.tableView isEditing]) {
        [self setEditing:NO animated:NO];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.tableView reloadEmptyDataSet];
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
        if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
            if (!self.previewingContext) {
                self.previewingContext = [self registerForPreviewingWithDelegate:self sourceView:self.view];
            }
        } else {
            [self unregisterForPreviewingWithContext:self.previewingContext];
            self.previewingContext = nil;
        }
    }
}

#pragma mark - Private

- (void)reloadUI {
    if (self.incomingButton.selected) {
        [self incomingNodes];
    } else if (self.outgoingButton.selected) {
        [self outgoingNodes];
    }
    
    [self updateNavigationBarTitle];
    
    [self.tableView reloadData];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setNavigationBarButtonItemsEnabled:boolValue];
    [self toolbarItemsSetEnabled:boolValue];
    
    [self.tableView reloadData];
}

- (void)setNavigationBarButtonItemsEnabled:(BOOL)boolValue {
    [self.editBarButtonItem setEnabled:boolValue];
}

- (void)toolbarItemsSetEnabled:(BOOL)boolValue {
    [_downloadBarButtonItem setEnabled:boolValue];
    [_carbonCopyBarButtonItem setEnabled:boolValue];
    [_leaveShareBarButtonItem setEnabled:boolValue];
    
    [self.shareBarButtonItem setEnabled:((self.selectedNodesMutableArray.count < 100) ? boolValue : NO)];
    [_shareFolderBarButtonItem setEnabled:boolValue];
    [_removeShareBarButtonItem setEnabled:boolValue];
}

- (void)incomingNodes {
    [_incomingNodesForEmailMutableDictionary removeAllObjects];
    [_incomingIndexPathsMutableDictionary removeAllObjects];
    
    self.incomingNodesMutableArray = NSMutableArray.alloc.init;
    
    self.incomingShareList = [[MEGASdkManager sharedMEGASdk] inSharesList];
    NSUInteger count = self.incomingShareList.size.unsignedIntegerValue;
    for (NSUInteger i = 0; i < count; i++) {
        MEGAShare *share = [self.incomingShareList shareAtIndex:i];
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:share.nodeHandle];
        [self.incomingNodesMutableArray addObject:node];
    }
    
    if (self.incomingNodesMutableArray.count == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        if (!self.tableView.tableHeaderView) {
            self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
            self.tableView.tableHeaderView = self.searchController.searchBar;
        }
    }
}

- (void)outgoingNodes {
    [_outgoingNodesForEmailMutableDictionary removeAllObjects];
    [_outgoingIndexPathsMutableDictionary removeAllObjects];
    
    _outgoingShareList = [[MEGASdkManager sharedMEGASdk] outShares];
    self.outgoingSharesMutableArray = NSMutableArray.alloc.init;
    
    NSString *lastBase64Handle = @"";
    self.outgoingNodesMutableArray = NSMutableArray.alloc.init;
    
    NSUInteger count = self.outgoingShareList.size.unsignedIntegerValue;
    for (NSUInteger i = 0; i < count; i++) {
        MEGAShare *share = [_outgoingShareList shareAtIndex:i];
        if ([share user] != nil) {
            [_outgoingSharesMutableArray addObject:share];
            
            MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:share.nodeHandle];
            
            if (![lastBase64Handle isEqualToString:node.base64Handle]) {
                lastBase64Handle = node.base64Handle;
                [_outgoingNodesMutableArray addObject:node];
            }
        }
    }
    
    if (self.outgoingNodesMutableArray.count == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        if (!self.tableView.tableHeaderView) {
            self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
            self.tableView.tableHeaderView = self.searchController.searchBar;
        }
    }
}

- (NSMutableArray *)outSharesForNode:(MEGANode *)node {

    NSMutableArray *outSharesForNodeMutableArray = NSMutableArray.alloc.init;
    
    MEGAShareList *outSharesForNodeShareList = [[MEGASdkManager sharedMEGASdk] outSharesForNode:node];
    NSUInteger outSharesForNodeCount = outSharesForNodeShareList.size.unsignedIntegerValue;
    for (NSInteger i = 0; i < outSharesForNodeCount; i++) {
        MEGAShare *share = [outSharesForNodeShareList shareAtIndex:i];
        if ([share user] != nil) {
            [outSharesForNodeMutableArray addObject:share];
        }
    }
    
    return outSharesForNodeMutableArray;
}

- (void)toolbarItemsForSharedItems {
    
    NSMutableArray *toolbarItemsMutableArray = NSMutableArray.alloc.init;
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    if (self.incomingButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.downloadBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.leaveShareBarButtonItem]];
    } else if (self.outgoingButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.shareBarButtonItem, flexibleItem, self.shareFolderBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.removeShareBarButtonItem]];
    }
    
    [_toolbar setItems:toolbarItemsMutableArray];
}

- (void)removeSelectedIncomingShares {
    NSArray *filesAndFolders = self.selectedNodesMutableArray.mnz_numberOfFilesAndFolders;
    MEGARemoveRequestDelegate *removeRequestDelegate = [[MEGARemoveRequestDelegate alloc] initWithMode:DisplayModeSharedItem files:[filesAndFolders[0] unsignedIntegerValue] folders:[filesAndFolders[1] unsignedIntegerValue] completion:nil];
    for (NSInteger i = 0; i < self.selectedNodesMutableArray.count; i++) {
        [[MEGASdkManager sharedMEGASdk] removeNode:[self.selectedNodesMutableArray objectAtIndex:i] delegate:removeRequestDelegate];
    }
    
    [self setEditing:NO animated:YES];
}

- (void)selectedSharesOfSelectedNodes {
    self.selectedSharesMutableArray = NSMutableArray.alloc.init;
    
    for (MEGANode *node in self.selectedNodesMutableArray) {
        NSMutableArray *outSharesOfNodeMutableArray = [self outSharesForNode:node];
        [self.selectedSharesMutableArray addObjectsFromArray:outSharesOfNodeMutableArray];
    }
}

- (void)removeSelectedOutgoingShares {
    MEGAShareRequestDelegate *shareRequestDelegate = [[MEGAShareRequestDelegate alloc] initToChangePermissionsWithNumberOfRequests:self.selectedSharesMutableArray.count completion:^{
        [self setEditing:NO animated:YES];
        [self reloadUI];
    }];
    
    for (MEGAShare *share in self.selectedSharesMutableArray) {
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[share nodeHandle]];
        [[MEGASdkManager sharedMEGASdk] shareNode:node withEmail:share.user level:MEGAShareTypeAccessUnknown delegate:shareRequestDelegate];
    }
    
    [self setEditing:NO animated:YES];
}

- (NSArray *)indexPathsForUserEmail:(NSString *)email {
    NSMutableArray *indexPathsMutableArray = NSMutableArray.alloc.init;
    if (self.incomingButton.selected) {
        NSArray *base64HandleArray = [self.incomingNodesForEmailMutableDictionary allKeysForObject:email];
        indexPathsMutableArray = [[self.incomingIndexPathsMutableDictionary objectsForKeys:base64HandleArray notFoundMarker:NSNull.null] mutableCopy];
    } else if (self.outgoingButton.selected) {
        NSArray *base64HandleArray = [self.outgoingNodesForEmailMutableDictionary allKeysForObject:email];
        indexPathsMutableArray = [[self.outgoingIndexPathsMutableDictionary objectsForKeys:base64HandleArray notFoundMarker:NSNull.null] mutableCopy];
    }
    
    [indexPathsMutableArray removeObjectsInArray:[NSArray arrayWithObject:[NSNull null]]];
    
    return indexPathsMutableArray;
}

- (MEGANode *)nodeAtIndexPath:(NSIndexPath *)indexPath {
    return self.searchController.isActive ? [self.searchNodesArray objectAtIndex:indexPath.row] : (self.incomingButton.selected ? [self.incomingNodesMutableArray objectAtIndex:indexPath.row] : [self.outgoingNodesMutableArray objectAtIndex:indexPath.row]);
}

- (void)showNodeInfo:(MEGANode *)node {
    UINavigationController *nodeInfoNavigation = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"NodeInfoNavigationControllerID"];
    NodeInfoViewController *nodeInfoVC = nodeInfoNavigation.viewControllers.firstObject;
    nodeInfoVC.node = node;
    nodeInfoVC.nodeInfoDelegate = self;
    nodeInfoVC.incomingShareChildView = self.incomingButton.selected == 0;

    [self presentViewController:nodeInfoNavigation animated:YES completion:nil];
}

- (void)updateNavigationBarTitle {
    NSString *navigationTitle;
    if (self.tableView.isEditing) {
        if (self.selectedNodesMutableArray.count == 0) {
            navigationTitle = AMLocalizedString(@"selectTitle", @"Title shown on the Camera Uploads section when the edit mode is enabled. On this mode you can select photos");
        } else {
            navigationTitle = (self.selectedNodesMutableArray.count == 1) ? [NSString stringWithFormat:AMLocalizedString(@"oneItemSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected one photo"), self.selectedNodesMutableArray.count] : [NSString stringWithFormat:AMLocalizedString(@"itemsSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected more than one photo"), self.selectedNodesMutableArray.count];
        }
    } else {
        navigationTitle = AMLocalizedString(@"sharedItems", @"Title of Shared Items section");
    }
    
    self.navigationItem.title = navigationTitle;
}

#pragma mark - Utils

- (void)selectSegment:(NSUInteger)index {
    if (index == 0) {
        [self incomingTouchUpInside:nil];
    } else if (index == 1) {
        [self outgoingTouchUpInside:nil];
    }
}

#pragma mark - IBActions

- (IBAction)editTapped:(UIBarButtonItem *)sender {
    BOOL enableEditing = !self.tableView.isEditing;
    [self setEditing:enableEditing animated:YES];
    
    if (enableEditing) {
        self.selectedNodesMutableArray = NSMutableArray.alloc.init;
        self.selectedSharesMutableArray = NSMutableArray.alloc.init;
        
        [self toolbarItemsForSharedItems];
        [self toolbarItemsSetEnabled:NO];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    [self.tableView setEditing:editing animated:animated];
    
    [self updateNavigationBarTitle];
    
    if (editing) {
        self.editBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
        self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        [self.toolbar setAlpha:0.0];
        [self.tabBarController.view addSubview:self.toolbar];
        self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
        
        NSLayoutAnchor *bottomAnchor;
        if (@available(iOS 11.0, *)) {
            bottomAnchor = self.tabBarController.tabBar.safeAreaLayoutGuide.bottomAnchor;
        } else {
            bottomAnchor = self.tabBarController.tabBar.bottomAnchor;
        }
        
        [NSLayoutConstraint activateConstraints:@[[self.toolbar.topAnchor constraintEqualToAnchor:self.tabBarController.tabBar.topAnchor constant:0],
                                                  [self.toolbar.leadingAnchor constraintEqualToAnchor:self.tabBarController.tabBar.leadingAnchor constant:0],
                                                  [self.toolbar.trailingAnchor constraintEqualToAnchor:self.tabBarController.tabBar.trailingAnchor constant:0],
                                                  [self.toolbar.bottomAnchor constraintEqualToAnchor:bottomAnchor constant:0]]];

        [UIView animateWithDuration:0.33f animations:^ {
            [self.toolbar setAlpha:1.0];
        }];
        
        for (SharedItemsTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = UIView.alloc.init;
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
        allNodesSelected = NO;
        [_selectedNodesMutableArray removeAllObjects];
        [_selectedSharesMutableArray removeAllObjects];
        self.navigationItem.leftBarButtonItems = @[];
        
        [UIView animateWithDuration:0.33f animations:^ {
            [self.toolbar setAlpha:0.0];
        } completion:^(BOOL finished) {
            if (finished) {
                [self.toolbar removeFromSuperview];
            }
        }];
        
        for (SharedItemsTableViewCell *cell in self.tableView.visibleCells) {
            cell.selectedBackgroundView = nil;
        }
    }
    
    if (!self.selectedNodesMutableArray) {
        self.selectedNodesMutableArray = NSMutableArray.alloc.init;
        self.selectedSharesMutableArray = NSMutableArray.alloc.init;
        
        [self toolbarItemsSetEnabled:NO];
    }
}

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [_selectedSharesMutableArray removeAllObjects];
    [_selectedNodesMutableArray removeAllObjects];
    
    if (!allNodesSelected) {
        MEGANode *n = nil;
        MEGAShare *s = nil;
        if (self.incomingButton.selected) {
            NSUInteger count = self.incomingShareList.size.unsignedIntegerValue;
            for (NSInteger i = 0; i < count; i++) {
                s = [self.incomingShareList shareAtIndex:i];
                n = [self.incomingNodesMutableArray objectAtIndex:i];
                [self.selectedSharesMutableArray addObject:s];
                [self.selectedNodesMutableArray addObject:n];
            }
        } else if (self.outgoingButton.selected) {
            NSUInteger count = self.outgoingNodesMutableArray.count;
            for (NSInteger i = 0; i < count; i++) {
                n = [self.outgoingNodesMutableArray objectAtIndex:i];
                [self.selectedSharesMutableArray addObjectsFromArray:[self outSharesForNode:n]];
                [self.selectedNodesMutableArray addObject:n];
            }
        }
        allNodesSelected = YES;
    } else {
        allNodesSelected = NO;
    }
    
    if (self.selectedNodesMutableArray.count == 0) {
        [self toolbarItemsSetEnabled:NO];
    } else if (self.selectedNodesMutableArray.count >= 1) {
        [self toolbarItemsSetEnabled:YES];
    }
    
    [self updateNavigationBarTitle];
    
    [self.tableView reloadData];
}

- (IBAction)permissionsTouchUpInside:(UIButton *)sender {
    if (self.tableView.isEditing) {
        return;
    }
    
    if ([MEGAReachabilityManager isReachableHUDIfNot] && self.outgoingButton.selected) {
        ContactsViewController *contactsVC =  [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsViewControllerID"];
        contactsVC.contactsMode = ContactsModeFolderSharedWith;
        
        CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
        contactsVC.node = [self nodeAtIndexPath:indexPath];
        [self.navigationController pushViewController:contactsVC animated:YES];
    }
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    if (self.tableView.isEditing) {
        return;
    }
    
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    CustomActionViewController *actionController = CustomActionViewController.alloc.init;
    actionController.node = node;
    actionController.displayMode = DisplayModeSharedItem;
    actionController.actionDelegate = self;
    actionController.actionSender = sender;
    actionController.incomingShareChildView = self.incomingButton.selected;
    if ([[UIDevice currentDevice] iPadDevice]) {
        actionController.modalPresentationStyle = UIModalPresentationPopover;
        actionController.popoverPresentationController.delegate = actionController;
        actionController.popoverPresentationController.sourceView = sender;
        actionController.popoverPresentationController.sourceRect = CGRectMake(0, 0, sender.frame.size.width/2, sender.frame.size.height/2);
    } else {
        actionController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    [self presentViewController:actionController animated:YES completion:nil];
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        for (MEGANode *n in _selectedNodesMutableArray) {
            if (![Helper isFreeSpaceEnoughToDownloadNode:n isFolderLink:NO]) {
                [self setEditing:NO animated:YES];
                return;
            }
        }
        
        [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
        
        for (MEGANode *n in _selectedNodesMutableArray) {
            [Helper downloadNode:n folderPath:[Helper relativePathForOffline] isFolderLink:NO shouldOverwrite:NO];
        }
        
        [self setEditing:NO animated:YES];
    }
}

- (IBAction)copyAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
        browserVC.selectedNodesArray = [NSArray arrayWithArray:self.selectedNodesMutableArray];
        [browserVC setBrowserAction:BrowserActionCopy];
        
        [self setEditing:NO animated:YES];
    }
}

- (IBAction)leaveShareAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSString *alertMessage = (_selectedNodesMutableArray.count > 1) ? AMLocalizedString(@"leaveSharesAlertMessage", @"Alert message shown when the user tap on the leave share action selecting multipe inshares") : AMLocalizedString(@"leaveShareAlertMessage", @"Alert message shown when the user tap on the leave share action for one inshare");
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"leaveFolder", nil) message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self removeSelectedIncomingShares];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)shareAction:(UIBarButtonItem *)sender {
    UIActivityViewController *activityVC = [Helper activityViewControllerForNodes:self.selectedNodesMutableArray sender:self.shareBarButtonItem];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (IBAction)shareFolderAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsNavigationControllerID"];
        ContactsViewController *contactsVC = navigationController.viewControllers.firstObject;
        contactsVC.contactsMode = ContactsModeShareFoldersWith;
        [contactsVC setNodesArray:[_selectedNodesMutableArray copy]];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        [self setEditing:NO animated:YES];
    }
}

- (IBAction)removeShareAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        [self selectedSharesOfSelectedNodes];
        
        NSMutableArray *usersMutableArray = NSMutableArray.alloc.init;
        if (self.selectedSharesMutableArray != nil) {
            for (MEGAShare *share in self.selectedSharesMutableArray) {
                if (![usersMutableArray containsObject:share.user]) {
                    [usersMutableArray addObject:share.user];
                }
            }
        }
        
        NSString *alertMessage;
        if ((usersMutableArray.count == 1) && (self.selectedNodesMutableArray.count == 1)) {
            alertMessage = AMLocalizedString(@"removeOneShareOneContactMessage", nil);
        } else if ((usersMutableArray.count > 1) && (self.selectedNodesMutableArray.count == 1)) {
            alertMessage = [NSString stringWithFormat:AMLocalizedString(@"removeOneShareMultipleContactsMessage", nil), usersMutableArray.count];
        } else {
            alertMessage = [NSString stringWithFormat:AMLocalizedString(@"removeMultipleSharesMultipleContactsMessage", nil), usersMutableArray.count];
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"removeSharing", nil) message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self removeSelectedOutgoingShares];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)incomingTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.outgoingButton.selected = !self.outgoingButton.selected;
    
    self.incomingLineView.backgroundColor = UIColor.mnz_redMain;
    self.outgoingLineView.backgroundColor = UIColor.mnz_grayCCCCCC;
    
    if (self.searchController.isActive) {
        self.searchController.active = NO;
    }
    
    if (self.tableView.isEditing) {
        [self.selectedNodesMutableArray removeAllObjects];
        [self.selectedSharesMutableArray removeAllObjects];
        
        [self updateNavigationBarTitle];
        
        [self toolbarItemsForSharedItems];
        [self toolbarItemsSetEnabled:NO];
    }
    
    [self incomingNodes];
    [self.tableView reloadData];
}

- (IBAction)outgoingTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.incomingButton.selected = !self.incomingButton.selected;
    
    self.outgoingLineView.backgroundColor = UIColor.mnz_redMain;
    self.incomingLineView.backgroundColor = UIColor.mnz_grayCCCCCC;
    
    if (self.searchController.isActive) {
        self.searchController.active = NO;
    }
    
    if (self.tableView.isEditing) {
        [self.selectedNodesMutableArray removeAllObjects];
        [self.selectedSharesMutableArray removeAllObjects];
        
        [self updateNavigationBarTitle];
        
        [self toolbarItemsForSharedItems];
        [self toolbarItemsSetEnabled:NO];
    }
    
    [self outgoingNodes];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            numberOfRows = self.searchNodesArray.count;
        } else {
            if (self.incomingButton.selected) {
                numberOfRows = self.incomingNodesMutableArray.count;
            } else if (self.outgoingButton.selected) {
                numberOfRows = self.outgoingNodesMutableArray.count;
            }
        }
    }
    
    if (numberOfRows == 0) {
        [self setEditing:NO animated:NO];
        [self setNavigationBarButtonItemsEnabled:NO];
    } else {
        [self setNavigationBarButtonItemsEnabled:YES];
    }
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SharedItemsTableViewCell *cell;
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"sharedItemsTableViewCell" forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[SharedItemsTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sharedItemsTableViewCell"];
    }
    
    MEGAShare *share = nil;
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    NSUInteger outSharesCount = 1;
    
    if (self.incomingButton.selected) {
        for (NSUInteger i = 0; i < self.incomingShareList.size.unsignedIntegerValue; i++) {
            MEGAShare *s = [self.incomingShareList shareAtIndex:i];
            if (s.nodeHandle == node.handle) {
                share = s;
                break;
            }
        }
        
        NSString *userEmail = share.user;
        [self.incomingNodesForEmailMutableDictionary setObject:userEmail forKey:node.base64Handle];
        [self.incomingIndexPathsMutableDictionary setObject:indexPath forKey:node.base64Handle];
        
        cell.thumbnailImageView.image = Helper.incomingFolderImage;
        
        cell.nameLabel.text = node.name;
        
        MEGAUser *user = [MEGASdkManager.sharedMEGASdk contactForEmail:userEmail];
        NSString *userName = user.mnz_fullName ? user.mnz_fullName : userEmail;
        
        NSString *infoLabelText = userName;
        cell.infoLabel.text = infoLabelText;
        
        [cell.permissionsButton setImage:[Helper permissionsButtonImageForShareType:share.access] forState:UIControlStateNormal];
        
        cell.nodeHandle = node.handle;
    } else if (self.outgoingButton.selected) {
        for (NSUInteger i = 0; i < self.outgoingSharesMutableArray.count; i++) {
            MEGAShare *s = self.outgoingSharesMutableArray[i];
            if (s.nodeHandle == node.handle) {
                share = s;
                break;
            }
        }
        
        [self.outgoingNodesForEmailMutableDictionary setObject:share.user forKey:node.base64Handle];
        [self.outgoingIndexPathsMutableDictionary setObject:indexPath forKey:node.base64Handle];
        
        cell.thumbnailImageView.image = Helper.outgoingFolderImage;
        
        cell.nameLabel.text = node.name;
        
        NSString *userName;
        NSMutableArray *outSharesMutableArray = [self outSharesForNode:node];
        outSharesCount = outSharesMutableArray.count;
        if (outSharesCount > 1) {
            userName = [NSString stringWithFormat:AMLocalizedString(@"sharedWithXContacts", nil), outSharesCount];
        } else {
            MEGAUser *user = [MEGASdkManager.sharedMEGASdk contactForEmail:[[outSharesMutableArray objectAtIndex:0] user]];
            userName = user.mnz_fullName ? user.mnz_fullName : user.email;
        }
        
        [cell.permissionsButton setImage:[UIImage imageNamed:@"permissions"] forState:UIControlStateNormal];
        
        cell.infoLabel.text = userName;
        
        cell.nodeHandle = share.nodeHandle;
    }
    
    if ([tableView isEditing]) {
        for (MEGANode *n in _selectedNodesMutableArray) {
            if ([n handle] == [node handle]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = UIView.alloc.init;
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
    
    if (@available(iOS 11.0, *)) {
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
    } else {
        cell.delegate = self;
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (self.searchController.isActive) {
        self.searchController.active = NO;
        [self searchBarCancelButtonClicked:self.searchController.searchBar];
    }
    
    if (tableView.isEditing) {
        if (node != nil) {
            [_selectedNodesMutableArray addObject:node];
        }
        
        [self updateNavigationBarTitle];
        [self toolbarItemsSetEnabled:YES];
        
        NSUInteger nodeListSize = 0;
        if (self.incomingButton.selected) {
            nodeListSize = self.incomingNodesMutableArray.count;
        } else {
            nodeListSize = self.outgoingNodesMutableArray.count;
        }
        
        if (self.selectedNodesMutableArray.count == nodeListSize) {
            allNodesSelected = YES;
        } else {
            allNodesSelected = NO;
        }
        
        return;
    }

    switch ([node type]) {
        case MEGANodeTypeFolder: {
            CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            [cloudDriveVC setParentNode:node];
            [cloudDriveVC setDisplayMode:DisplayModeCloudDrive];
            cloudDriveVC.hideSelectorView = YES;
            
            [self.navigationController pushViewController:cloudDriveVC animated:YES];
            break;
        }
        
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (tableView.isEditing) {
        NSMutableArray *tempNodesMutableArray = [_selectedNodesMutableArray copy];
        for (MEGANode *n in tempNodesMutableArray) {
            if ([n handle] == node.handle) {
                [_selectedNodesMutableArray removeObject:n];
            }
        }
                
        [self updateNavigationBarTitle];
        if (self.selectedNodesMutableArray.count == 0) {
            [self toolbarItemsSetEnabled:NO];
        }
        
        allNodesSelected = NO;
        
        return;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    if (self.incomingButton.selected) {
        UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_leaveSharingInViewController:self];
            [self setEditing:NO animated:YES];
        }];
        shareAction.image = [UIImage imageNamed:@"leaveShare"];
        shareAction.backgroundColor = [UIColor colorWithRed:1.0 green:0.64 blue:0 alpha:1];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else if (self.outgoingButton.selected) {
        UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_removeSharing];
            [self setEditing:NO animated:YES];
        }];
        shareAction.image = [UIImage imageNamed:@"removeShare"];
        shareAction.backgroundColor = [UIColor colorWithRed:1.0 green:0.64 blue:0 alpha:1];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
}

#pragma clang diagnostic pop
    
#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchNodesArray = nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if (searchController.isActive) {
        if ([searchString isEqualToString:@""]) {
            if (self.incomingButton.selected) {
                self.searchNodesArray = self.incomingNodesMutableArray;
            } else {
                self.searchNodesArray = self.outgoingNodesMutableArray;
            }
        } else {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF.name contains[c] %@", searchString];
            if (self.incomingButton.selected) {
                self.searchNodesArray = [[self.incomingNodesMutableArray filteredArrayUsingPredicate:resultPredicate] mutableCopy];
            } else if (self.outgoingButton.selected) {
                self.searchNodesArray = [[self.outgoingNodesMutableArray filteredArrayUsingPredicate:resultPredicate] mutableCopy];
            }
        }
    }
    
    [self.tableView reloadData];
}

#pragma mark - UISearchControllerDelegate

- (void)didPresentSearchController:(UISearchController *)searchController {
    if (UIDevice.currentDevice.iPhoneDevice && UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation)) {
        self.searchController.searchBar.superview.frame = CGRectMake(0, self.selectorView.frame.size.height + self.navigationController.navigationBar.frame.size.height, self.searchController.searchBar.superview.frame.size.width, self.searchController.searchBar.superview.frame.size.height);
    }
}

#pragma mark - UIViewControllerPreviewingDelegate

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    CGPoint rowPoint = [self.tableView convertPoint:location fromView:self.view];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:rowPoint];
    if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section]) {
        return nil;
    }
    
    previewingContext.sourceRect = [self.tableView convertRect:[self.tableView cellForRowAtIndexPath:indexPath].frame toView:self.view];
    
    MEGANode *node;
    if (self.incomingButton.selected) {
        node = [self.incomingNodesMutableArray objectAtIndex:indexPath.row];
    } else if (self.outgoingButton.selected) {
        node = [self.outgoingNodesMutableArray objectAtIndex:indexPath.row];
    }
    
    CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
    cloudDriveVC.parentNode = node;
    cloudDriveVC.displayMode = DisplayModeCloudDrive;
    cloudDriveVC.incomingShareChildView = self.incomingButton.selected;
    
    return cloudDriveVC;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self.navigationController pushViewController:viewControllerToCommit animated:YES];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    CGPoint touchPoint = [longPressGestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
    
    if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section]) {
        return;
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan) {        
        if (self.isEditing) {
            // Only stop editing if long pressed over a cell that is the only one selected or when selected none
            if (self.selectedNodesMutableArray.count == 0) {
                [self setEditing:NO animated:YES];
            }
            if (self.selectedNodesMutableArray.count == 1) {
                MEGANode *nodeSelected = self.selectedNodesMutableArray.firstObject;
                MEGANode *nodePressed = self.incomingButton.selected ? [self.incomingNodesMutableArray objectAtIndex:indexPath.row] : [self.outgoingNodesMutableArray objectAtIndex:indexPath.row];
                if (nodeSelected.handle == nodePressed.handle) {
                    [self setEditing:NO animated:YES];
                }
            }
        } else {
            [self setEditing:YES animated:YES];
            [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
            [self toolbarItemsForSharedItems];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text = @"";
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.searchController.searchBar.text.length > 0) {
                text = AMLocalizedString(@"noResults", @"Title shown when you make a search and there is 'No Results'");
            }
        } else {
            if (self.incomingButton.selected) {
                text = AMLocalizedString(@"noIncomingSharedItemsEmptyState_text", nil);
            } else if (self.outgoingButton.selected) {
                text = AMLocalizedString(@"noOutgoingSharedItemsEmptyState_text", nil);
            }
        }
    } else {
        text = AMLocalizedString(@"noInternetConnection",  nil);
    }
    
    return [[NSAttributedString alloc] initWithString:text attributes:[Helper titleAttributesForEmptyState]];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    UIImage *image;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.searchController.searchBar.text.length > 0) {
                return [UIImage imageNamed:@"searchEmptyState"];
            } else {
                return nil;
            }
        } else {
            if (self.incomingButton.selected) {
                image = [UIImage imageNamed:@"incomingEmptyState"];
            } else if (self.outgoingButton.selected) {
                image = [UIImage imageNamed:@"outgoingEmptyState"];
            }
        }
    } else {
        image = [UIImage imageNamed:@"noInternetEmptyState"];
    }
    
    return image;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return UIColor.whiteColor;
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:self.searchController.isActive];
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    [self reloadUI];
}

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    [self reloadUI];
}


#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(MGSwipeTableCell*) cell canSwipe:(MGSwipeDirection) direction fromPoint:(CGPoint)point {
    if (direction == MGSwipeDirectionLeftToRight) {
        return NO;
    }
    
    return !self.isEditing;
}

- (NSArray *)swipeTableCell:(MGSwipeTableCell *)cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings *)swipeSettings expansionSettings:(MGSwipeExpansionSettings *)expansionSettings {
    
    swipeSettings.transition = MGSwipeTransitionDrag;
    expansionSettings.buttonIndex = 0;
    expansionSettings.expansionLayout = MGSwipeExpansionLayoutCenter;
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 2;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        if (self.incomingButton.selected) {
            MGSwipeButton *shareButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"leaveShare"] backgroundColor:[UIColor colorWithRed:1.0 green:0.64 blue:0 alpha:1.0] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [node mnz_leaveSharingInViewController:self];
                return YES;
            }];
            [shareButton iconTintColor:UIColor.whiteColor];
            
            return @[shareButton];
        } else if (self.outgoingButton.selected) {
            MGSwipeButton *shareButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"removeShare"] backgroundColor:[UIColor colorWithRed:1.0 green:0.64 blue:0 alpha:1.0] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [node mnz_removeSharing];
                return YES;
            }];
            [shareButton iconTintColor:UIColor.whiteColor];
            
            return @[shareButton];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

#pragma mark - CustomActionViewControllerDelegate

- (void)performAction:(MegaNodeActionType)action inNode:(MEGANode *)node fromSender:(id)sender{
    switch (action) {
        case MegaNodeActionTypeDownload:
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
            [node mnz_downloadNodeOverwriting:NO];
            break;
            
        case MegaNodeActionTypeCopy:
            self.selectedNodesMutableArray = [[NSMutableArray alloc] initWithObjects:node, nil];
            [self copyAction:nil];
            break;
            
        case MegaNodeActionTypeRename:
            [node mnz_renameNodeInViewController:self];
            break;
            
        case MegaNodeActionTypeShare:{
            UIActivityViewController *activityVC = [Helper activityViewControllerForNodes:@[node] sender:sender];
            [self presentViewController:activityVC animated:YES completion:nil];
        }
            break;
            
        case MegaNodeActionTypeFileInfo:
            [self showNodeInfo:node];
            break;
            
        case MegaNodeActionTypeLeaveSharing:
            [node mnz_leaveSharingInViewController:self];
            break;
            
        case MegaNodeActionTypeRemoveSharing:
            [node mnz_removeSharing];
            break;
            
        case MegaNodeActionTypeRemoveLink:
        case MegaNodeActionTypeMove:
        case MegaNodeActionTypeMoveToRubbishBin:
        case MegaNodeActionTypeRemove:
            break;
            
        default:
            break;
    }
}

#pragma mark - NodeInfoViewControllerDelegate

- (void)presentParentNode:(MEGANode *)node {
    
    if (self.searchController.isActive) {
        NSArray *parentTreeArray = node.mnz_parentTreeArray;
        
        //Created a reference to self.navigationController because if the presented view is not the root controller and search is active, the 'popToRootViewControllerAnimated' makes nil the self.navigationController and therefore the parentTreeArray nodes can't be pushed
        UINavigationController *navigation = self.navigationController;
        [navigation popToRootViewControllerAnimated:NO];
        
        for (MEGANode *node in parentTreeArray) {
            CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            cloudDriveVC.parentNode = node;
            [navigation pushViewController:cloudDriveVC animated:NO];
        }
        
        switch (node.type) {
            case MEGANodeTypeFolder:
            case MEGANodeTypeRubbish: {
                CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
                cloudDriveVC.parentNode = node;
                [navigation pushViewController:cloudDriveVC animated:NO];
                break;
            }
                
            default:
                break;
        }
    }
}

@end
