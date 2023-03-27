#import "SharedItemsViewController.h"

#import "SVProgressHUD.h"
#import "UIApplication+MNZCategory.h"
#import "UIScrollView+EmptyDataSet.h"

#import "Helper.h"
#import "MEGASdkManager.h"
#import "MEGA-Swift.h"
#import "MEGAReachabilityManager.h"
#import "MEGANavigationController.h"
#import "MEGANode+MNZCategory.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGAUser+MNZCategory.h"
#import "MEGARemoveRequestDelegate.h"
#import "MEGAShareRequestDelegate.h"
#import "NSArray+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIImage+MNZCategory.h"
#import "UIViewController+MNZCategory.h"

#import "BrowserViewController.h"
#import "CloudDriveViewController.h"
#import "ContactsViewController.h"
#import "CopyrightWarningViewController.h"
#import "EmptyStateView.h"
#import "MEGAPhotoBrowserViewController.h"
#import "NodeTableViewCell.h"

@interface SharedItemsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchControllerDelegate, UISearchResultsUpdating, DZNEmptyDataSetDelegate, MEGAGlobalDelegate, MEGARequestDelegate, NodeInfoViewControllerDelegate, NodeActionViewControllerDelegate, AudioPlayerPresenterProtocol, BrowserViewControllerDelegate, TextFileEditable, UINavigationControllerDelegate> {
    BOOL allNodesSelected;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *carbonCopyBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *leaveShareBarButtonItem;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareLinkBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareFolderBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeShareBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeLinkBarButtonItem;

@property (nonatomic, strong) NSMutableArray *outgoingSharesMutableArray;
@property (nonatomic, strong) NSMutableArray *selectedSharesMutableArray;

@property (nonatomic, strong) NSMutableDictionary *incomingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *incomingIndexPathsMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingIndexPathsMutableDictionary;

@property (nonatomic, assign) BOOL shouldRemovePlayerDelegate;

@end

@implementation SharedItemsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.definesPresentationContext = YES;
    
    [self updateAppearance];
    
    //White background for the view behind the table view
    self.tableView.backgroundView = UIView.alloc.init;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    self.navigationItem.title = NSLocalizedString(@"sharedItems", @"Title of Shared Items section");
    self.editBarButtonItem.title = NSLocalizedString(@"cancel", @"Button title to cancel something");
    
    [self setNavigationBarButtons];
    
    [self.incomingButton setTitle:NSLocalizedString(@"incoming", nil) forState:UIControlStateNormal];
    [self.outgoingButton setTitle:NSLocalizedString(@"outgoing", nil) forState:UIControlStateNormal];
    [self.linksButton setTitle:NSLocalizedString(@"Links", nil) forState:UIControlStateNormal];
    
    self.incomingButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.outgoingButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.linksButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    
    self.incomingNodesForEmailMutableDictionary = NSMutableDictionary.alloc.init;
    self.incomingIndexPathsMutableDictionary = NSMutableDictionary.alloc.init;
    self.outgoingNodesForEmailMutableDictionary = NSMutableDictionary.alloc.init;
    self.outgoingIndexPathsMutableDictionary = NSMutableDictionary.alloc.init;
    
    self.outgoingUnverifiedSharesMutableArray = NSMutableArray.alloc.init;
    self.outgoingUnverifiedNodesMutableArray = NSMutableArray.alloc.init;
    [self allOutgoingNodes];
    
    self.incomingUnverifiedSharesMutableArray = NSMutableArray.alloc.init;
    self.incomingUnverifiedNodesMutableArray = NSMutableArray.alloc.init;
    [self incomingUnverifiedNodes];
    
    self.searchUnverifiedNodesArray = NSMutableArray.new;
    self.searchUnverifiedSharesArray = NSMutableArray.new;
    
    [self configSearchController];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.sortOrderType = [NSUserDefaults.standardUserDefaults integerForKey:@"SharedItemsSortOrderType"];
    if (self.sortOrderType == MEGASortOrderTypeNone) {
        self.sortOrderType = MEGASortOrderTypeDefaultAsc;
    }
    
    self.navigationController.delegate = self;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"SharedItemsTableViewCell" bundle:nil] forCellReuseIdentifier:@"sharedItemsTableViewCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"NodeTableViewCell" bundle:nil] forCellReuseIdentifier:@"nodeCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    
    [self addSearchBar];
    
    [self reloadUI];
    
    self.shouldRemovePlayerDelegate = YES;
    
    [self refreshMyAvatar];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([self.tableView isEditing]) {
        [self setEditing:NO animated:NO];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:MEGAAudioPlayerShouldUpdateContainerNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[TransfersWidgetViewController sharedTransferViewController].progressView showWidgetIfNeeded];
    [AudioPlayerManager.shared addDelegate:self];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.shouldRemovePlayerDelegate) {
        [AudioPlayerManager.shared removeDelegate:self];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.tableView reloadEmptyDataSet];
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [AppearanceManager forceToolbarUpdate:self.toolbar traitCollection:self.traitCollection];
        [AppearanceManager forceSearchBarUpdate:self.searchController.searchBar traitCollection:self.traitCollection];
        
        [self updateAppearance];
    }
}

- (SharedItemsViewModel *)viewModel {
    if (_viewModel == nil) {
        _viewModel = [self createSharedItemsViewModel];
    }
    
    return _viewModel;
}

- (void)configSearchController {
    self.searchController = [Helper customSearchControllerWithSearchResultsUpdaterDelegate:self searchBarDelegate:self];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
    });
}

#pragma mark - Private
- (void)updateAppearance {
    self.view.backgroundColor = UIColor.mnz_background;
    
    self.tableView.separatorColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    [self updateTabSelection];
}

- (void)reloadUI {
    if (self.incomingButton.selected) {
        [self incomingVerifiedNodes];
        [self incomingUnverifiedNodes];
    } else if (self.outgoingButton.selected) {
        [self allOutgoingNodes];
    } else if (self.linksButton.selected) {
        [self publicLinks];
    }
    
    [self updateNavigationBarTitle];
    [self configNavigationBarButtonItems];
    
    [self.tableView reloadData];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setNavigationBarButtonItemsEnabled:boolValue || self.tableView.isEditing];
    [self toolbarItemsSetEnabled:boolValue];
    
    boolValue ? [self addSearchBar] : [self hideSearchBarIfNotActive];
    
    [self.tableView reloadData];
}

- (void)toolbarItemsSetEnabled:(BOOL)boolValue {
    [_downloadBarButtonItem setEnabled:boolValue];
    [_carbonCopyBarButtonItem setEnabled:boolValue];
    [_leaveShareBarButtonItem setEnabled:boolValue];
    
    [self.shareLinkBarButtonItem setEnabled:boolValue];
    [_shareFolderBarButtonItem setEnabled:boolValue];
    [_removeShareBarButtonItem setEnabled:boolValue];
    self.removeLinkBarButtonItem.enabled = boolValue;
    self.saveToPhotosBarButtonItem.enabled = boolValue;
}

- (void)addSearchBar {
    if (self.searchController) {
        if (!self.tableView.tableHeaderView) {
            self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
        }
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
}

- (void)hideSearchBarIfNotActive {
    if (!self.searchController.isActive) {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)incomingVerifiedNodes {
    [_incomingNodesForEmailMutableDictionary removeAllObjects];
    [_incomingIndexPathsMutableDictionary removeAllObjects];
    
    self.incomingNodesMutableArray = NSMutableArray.alloc.init;
    
    self.incomingShareList = [MEGASdkManager.sharedMEGASdk inSharesList:self.sortOrderType];
    NSUInteger count = self.incomingShareList.size.unsignedIntegerValue;
    for (NSUInteger i = 0; i < count; i++) {
        MEGAShare *share = [self.incomingShareList shareAtIndex:i];
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:share.nodeHandle];
        [self.incomingNodesMutableArray addObject:node];
    }
    
    [self addInShareSearcBarIfNeeded];
}

- (void)allOutgoingNodes {
    [_outgoingNodesForEmailMutableDictionary removeAllObjects];
    [_outgoingIndexPathsMutableDictionary removeAllObjects];
    
    _outgoingShareList = [MEGASdkManager.sharedMEGASdk outShares:self.sortOrderType];
    self.outgoingSharesMutableArray = NSMutableArray.alloc.init;
    self.outgoingUnverifiedSharesMutableArray = NSMutableArray.alloc.init;
    
    NSString *lastBase64Handle = @"";
    self.outgoingNodesMutableArray = NSMutableArray.alloc.init;
    self.outgoingUnverifiedNodesMutableArray = NSMutableArray.alloc.init;
    
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
            
            if (!share.isVerified) {
                [self addToUnverifiedOutSharesWithShare:share node:node];
            }
        }
    }
    
    [self configUnverifiedOutShareBadge];

    if (self.outgoingNodesMutableArray.count == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        [self addSearchBar];
    }
}

- (void)publicLinks {
    [self.outgoingNodesForEmailMutableDictionary removeAllObjects];
    [self.outgoingIndexPathsMutableDictionary removeAllObjects];
    
    self.publicLinksArray = [MEGASdkManager.sharedMEGASdk publicLinks:self.sortOrderType].mnz_nodesArrayFromNodeList;
    
    if (self.publicLinksArray.count == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        [self addSearchBar];
    }
}

- (void)configToolbarItemsForSharedItems {
    
    NSMutableArray *toolbarItemsMutableArray = NSMutableArray.alloc.init;
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    if (self.incomingButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.downloadBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.leaveShareBarButtonItem]];
    } else if (self.outgoingButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.shareLinkBarButtonItem, flexibleItem, self.shareFolderBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.removeShareBarButtonItem]];
    } else if (self.linksButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.shareLinkBarButtonItem, flexibleItem, self.downloadBarButtonItem]];
        if ([self.viewModel areMediaNodes:self.selectedNodesMutableArray]) {
            [toolbarItemsMutableArray addObjectsFromArray:@[flexibleItem, self.saveToPhotosBarButtonItem]];
        }
        [toolbarItemsMutableArray addObjectsFromArray:@[flexibleItem, self.removeLinkBarButtonItem]];
    }
    
    [_toolbar setItems:toolbarItemsMutableArray];
}

- (void)removeSelectedIncomingShares {
    NSArray *filesAndFolders = self.selectedNodesMutableArray.mnz_numberOfFilesAndFolders;
    MEGARemoveRequestDelegate *removeRequestDelegate = [MEGARemoveRequestDelegate.alloc initWithMode:DisplayModeSharedItem files:[filesAndFolders.firstObject unsignedIntegerValue] folders:[filesAndFolders[1] unsignedIntegerValue] completion:nil];
    for (NSInteger i = 0; i < self.selectedNodesMutableArray.count; i++) {
        [[MEGASdkManager sharedMEGASdk] removeNode:[self.selectedNodesMutableArray objectAtIndex:i] delegate:removeRequestDelegate];
    }
    
    [self endEditingMode];
}

- (void)selectedSharesOfSelectedNodes {
    self.selectedSharesMutableArray = NSMutableArray.alloc.init;
    
    for (MEGANode *node in self.selectedNodesMutableArray) {
        NSMutableArray *outSharesOfNodeMutableArray = node.outShares;
        [self.selectedSharesMutableArray addObjectsFromArray:outSharesOfNodeMutableArray];
    }
}

- (void)removeSelectedOutgoingShares {
    MEGAShareRequestDelegate *shareRequestDelegate = [[MEGAShareRequestDelegate alloc] initToChangePermissionsWithNumberOfRequests:self.selectedSharesMutableArray.count completion:^{
        [self endEditingMode];
        [self reloadUI];
    }];
    
    for (MEGAShare *share in self.selectedSharesMutableArray) {
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[share nodeHandle]];
        [[MEGASdkManager sharedMEGASdk] shareNode:node withEmail:share.user level:MEGAShareTypeAccessUnknown delegate:shareRequestDelegate];
    }
    
    [self endEditingMode];
}

- (MEGANode *)nodeAtIndexPath:(NSIndexPath *)indexPath {
    if (self.searchController.isActive) {
        if (self.linksButton.selected || indexPath.section == 1) {
            return self.searchNodesArray[indexPath.row];
        }
        return self.searchUnverifiedNodesArray[indexPath.row];
    } else {
        if (self.incomingButton.selected) {
            if (indexPath.section == 0) {
                return self.incomingUnverifiedNodesMutableArray[indexPath.row];
            }
            return self.incomingNodesMutableArray[indexPath.row];
        } else if (self.outgoingButton.selected) {
            if (indexPath.section == 0) {
                return self.outgoingUnverifiedNodesMutableArray[indexPath.row];
            }
            return self.outgoingNodesMutableArray[indexPath.row];
        } else if (self.linksButton.selected) {
            return self.publicLinksArray[indexPath.row];
        } else {
            return nil;
        }
    }
}

- (void)showNodeInfo:(MEGANode *)node from:(UIButton *)sender {
    NSIndexPath *indexPath = [self indexPathFromSender:sender];
    if (indexPath == nil) {
        return;
    }

    BOOL isNodeUndecryptedFolder = self.incomingButton.selected && indexPath.section == 0;
    NodeInfoViewModel *viewModel = [self createNodeInfoViewModelWithNode:node
                                                 isNodeUndecryptedFolder:isNodeUndecryptedFolder];
    MEGANavigationController *nodeInfoNavigation = [NodeInfoViewController instantiateWithViewModel:viewModel delegate:self];
    [self presentViewController:nodeInfoNavigation animated:YES completion:nil];
}

- (void)updateNavigationBarTitle {
    NSString *navigationTitle;
    if (self.tableView.isEditing) {
        if (self.selectedNodesMutableArray.count == 0) {
            navigationTitle = NSLocalizedString(@"selectTitle", @"Title shown on the Camera Uploads section when the edit mode is enabled. On this mode you can select photos");
        } else {
            navigationTitle = (self.selectedNodesMutableArray.count == 1) ? [NSString stringWithFormat:NSLocalizedString(@"oneItemSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected one photo"), self.selectedNodesMutableArray.count] : [NSString stringWithFormat:NSLocalizedString(@"itemsSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected more than one photo"), self.selectedNodesMutableArray.count];
        }
    } else {
        navigationTitle = NSLocalizedString(@"sharedItems", @"Title of Shared Items section");
    }
    
    self.navigationItem.title = navigationTitle;
}

- (SharedItemsTableViewCell *)incomingSharedCellAtIndexPath:(NSIndexPath *)indexPath forNode:(MEGANode *)node {
    SharedItemsTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"sharedItemsTableViewCell" forIndexPath:indexPath];
    if (cell == nil) {
        cell = [SharedItemsTableViewCell.alloc initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sharedItemsTableViewCell"];
    }
    
    cell.delegate = self;
    
    MEGAShare *share = nil;
    for (NSUInteger i = 0; i < self.incomingShareList.size.unsignedIntegerValue; i++) {
        MEGAShare *s = [self.incomingShareList shareAtIndex:i];
        if (s.nodeHandle == node.handle) {
            share = s;
            break;
        }
    }
    
    NSString *userEmail = share.user;
    if (node.base64Handle) {
        self.incomingNodesForEmailMutableDictionary[node.base64Handle] = userEmail;
        self.incomingIndexPathsMutableDictionary[node.base64Handle] = indexPath;
    }

    cell.thumbnailImageView.image = UIImage.mnz_incomingFolderImage;
    
    cell.nameLabel.text = node.name;
    cell.nameLabel.textColor = UIColor.mnz_label;
    [self setupLabelAndFavouriteForNode:node cell:cell];
    
    MEGAUser *user = [MEGASdkManager.sharedMEGASdk contactForEmail:userEmail];

    NSString *userDisplayName = user.mnz_displayName;
    cell.infoLabel.text = (userDisplayName != nil) ? userDisplayName : userEmail;

    [cell.permissionsButton setImage:[UIImage mnz_permissionsButtonImageForShareType:share.access] forState:UIControlStateNormal];
    cell.permissionsButton.hidden = NO;

    cell.nodeHandle = node.handle;
    
    [self configureSelectionForCell:cell atIndexPath:indexPath forNode:node];
    [self configureAccessibilityForCell:cell];
    
    return cell;
}

- (SharedItemsTableViewCell *)outgoingSharedCellAtIndexPath:(NSIndexPath *)indexPath forNode:(MEGANode *)node {
    SharedItemsTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"sharedItemsTableViewCell" forIndexPath:indexPath];
    if (cell == nil) {
        cell = [SharedItemsTableViewCell.alloc initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"sharedItemsTableViewCell"];
    }
    
    cell.delegate = self;
    
    NSUInteger outSharesCount = 1;
    MEGAShare *share = nil;
    for (NSUInteger i = 0; i < self.outgoingSharesMutableArray.count; i++) {
        MEGAShare *s = self.outgoingSharesMutableArray[i];
        if (s.nodeHandle == node.handle) {
            share = s;
            break;
        }
    }
    
    self.outgoingNodesForEmailMutableDictionary[node.base64Handle] = share.user;
    self.outgoingIndexPathsMutableDictionary[node.base64Handle] = indexPath;
    
    cell.thumbnailImageView.image = UIImage.mnz_outgoingFolderImage;
    cell.nameLabel.textColor = UIColor.mnz_label;
    cell.nameLabel.text = node.name;
    [self setupLabelAndFavouriteForNode:node cell:cell];
    
    NSString *userName;
    NSMutableArray *outSharesMutableArray = node.outShares;
    outSharesCount = outSharesMutableArray.count;
    if (outSharesCount > 1) {
        userName = [NSString stringWithFormat:NSLocalizedString(@"sharedWithXContacts", nil), outSharesCount];
    } else {
        MEGAUser *user = [MEGASdkManager.sharedMEGASdk contactForEmail:[outSharesMutableArray.firstObject user]];
        NSString *userDisplayName = user.mnz_displayName;
        userName = (userDisplayName != nil) ? userDisplayName : user.email;
    }
    
    cell.permissionsButton.hidden = YES;
    
    cell.infoLabel.text = userName;
    
    cell.nodeHandle = share.nodeHandle;
    
    [self configureSelectionForCell:cell atIndexPath:indexPath forNode:node];
    [self configureAccessibilityForCell:cell];
    
    return cell;
}

- (NodeTableViewCell *)linkSharedCellAtIndexPath:(NSIndexPath *)indexPath forNode:(MEGANode *)node {
    NodeTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"nodeCell" forIndexPath:indexPath];
    cell.cellFlavor = NodeTableViewCellFlavorSharedLink;
    [cell configureCellForNode:node api:MEGASdkManager.sharedMEGASdk];
    //We are on the Shared Items - Links tab, no need to show any icon next to the thumbnail.
    cell.linkImageView.hidden = YES;
    
    [self configureSelectionForCell:cell atIndexPath:indexPath forNode:node];
    
    return cell;
}

- (void)setupLabelAndFavouriteForNode:(MEGANode *)node cell:(SharedItemsTableViewCell *)cell {
    cell.favouriteView.hidden = !node.isFavourite;
    cell.labelView.hidden = (node.label == MEGANodeLabelUnknown);
    if (node.label != MEGANodeLabelUnknown) {
        NSString *labelString = [[MEGANode stringForNodeLabel:node.label] stringByAppendingString:@"Small"];
        cell.labelImageView.image = [UIImage imageNamed:labelString];
    }
}

- (void)startEditingModeAtIndex:(NSIndexPath *)indexPath {
    [self setEditing:YES animated:YES];
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    [self configToolbarItemsForSharedItems];
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    [self audioPlayerHidden:YES];
}

- (void)endEditingMode {
    [self setEditing:NO animated:YES];
    [self audioPlayerHidden:NO];
}

- (void)audioPlayerHidden:(BOOL)hidden {
    if ([AudioPlayerManager.shared isPlayerAlive]) {
        [AudioPlayerManager.shared playerHidden:hidden presenter:self];
    }
}

- (void)presentGetLinkVCForNodes:(NSArray<MEGANode *> *)nodes {
    if (MEGAReachabilityManager.isReachableHUDIfNot) {
        [CopyrightWarningViewController presentGetLinkViewControllerForNodes:nodes inViewController:UIApplication.mnz_presentingViewController];
    }
}

#pragma mark - Utils

- (void)selectSegment:(NSUInteger)index {
    if (index == 0) {
        [self incomingTouchUpInside:self.incomingButton];
    } else if (index == 1) {
        [self outgoingTouchUpInside:self.outgoingButton];
    } else if (index == 2) {
        [self linksTouchUpInside:self.linksButton];
    }
}

- (MEGAPhotoBrowserViewController *)photoBrowserForMediaNode:(MEGANode *)node {
    NSArray *nodesArray = (self.searchController.isActive ? self.searchNodesArray : self.publicLinksArray);
    NSMutableArray<MEGANode *> *mediaNodesArray = NSMutableArray.alloc.init;
    for (MEGANode *node in nodesArray) {
        if (node.name.mnz_isVisualMediaPathExtension) {
            [mediaNodesArray addObject:node];
        }
    }
    
    MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:MEGASdkManager.sharedMEGASdk displayMode:DisplayModeCloudDrive presentingNode:node];
    
    return photoBrowserVC;
}

- (void)nodesSortTypeHasChanged {
    [self reloadUI];
}

#pragma mark - IBActions

- (IBAction)editTapped:(UIBarButtonItem *)sender {
    if (self.tableView.isEditing) {
        [self endEditingMode];
    }
}

- (void)didTapSelect {
    [self setEditing:YES animated:YES];
    
    self.selectedNodesMutableArray = NSMutableArray.alloc.init;
    self.selectedSharesMutableArray = NSMutableArray.alloc.init;
    
    [self configToolbarItemsForSharedItems];
    [self configNavigationBarButtonItems];
    [self toolbarItemsSetEnabled:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    [self.tableView setEditing:editing animated:animated];
    
    [self updateNavigationBarTitle];
    
    [self setNavigationBarButtons];
    
    if (editing) {
        if (![self.tabBarController.view.subviews containsObject:self.toolbar]) {
            [self.toolbar setAlpha:0.0];
            [self.tabBarController.view addSubview:self.toolbar];
            self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
            [self.toolbar setBackgroundColor:[UIColor mnz_mainBarsForTraitCollection:self.traitCollection]];
            
            NSLayoutAnchor *bottomAnchor  = self.tabBarController.tabBar.safeAreaLayoutGuide.bottomAnchor;
            
            [NSLayoutConstraint activateConstraints:@[[self.toolbar.topAnchor constraintEqualToAnchor:self.tabBarController.tabBar.topAnchor constant:0],
                                                      [self.toolbar.leadingAnchor constraintEqualToAnchor:self.tabBarController.tabBar.leadingAnchor constant:0],
                                                      [self.toolbar.trailingAnchor constraintEqualToAnchor:self.tabBarController.tabBar.trailingAnchor constant:0],
                                                      [self.toolbar.bottomAnchor constraintEqualToAnchor:bottomAnchor constant:0]]];

            [UIView animateWithDuration:0.33f animations:^ {
                [self.toolbar setAlpha:1.0];
            }];
        }
        
        for (SharedItemsTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = UIView.alloc.init;
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        allNodesSelected = NO;
        [_selectedNodesMutableArray removeAllObjects];
        [_selectedSharesMutableArray removeAllObjects];
        self.navigationItem.leftBarButtonItems = @[self.myAvatarManager.myAvatarBarButton];
        
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
                [self.selectedSharesMutableArray addObjectsFromArray:n.outShares];
                [self.selectedNodesMutableArray addObject:n];
            }
        } else if (self.linksButton.selected) {
            NSUInteger count = self.publicLinksArray.count;
            for (NSInteger i = 0; i < count; i++) {
                [self.selectedNodesMutableArray addObject:self.publicLinksArray[i]];
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
    [self updateToolbarItemsIfNeeded];
    
    [self.tableView reloadData];
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        [CancellableTransferRouterOCWrapper.alloc.init downloadNodes:self.selectedNodesMutableArray presenter:self isFolderLink:NO];
        [self endEditingMode];
    }
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    [self showNodeActions:sender];
}

- (void)showNodeActions:(UIButton *)sender {
    if (self.tableView.isEditing) {
        return;
    }
    
    NSIndexPath *indexPath = [self indexPathFromSender:sender];
    if (indexPath == nil) {
        return;
    }
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    BOOL isBackupNode = [[[MyBackupsOCWrapper alloc] init] isBackupNode:node];
    NodeActionViewController *nodeActions = [NodeActionViewController.alloc initWithNode:node delegate:self displayMode:self.linksButton.selected ? DisplayModeCloudDrive : DisplayModeSharedItem isIncoming:self.incomingButton.selected isBackupNode:isBackupNode sender:sender];
    [self presentViewController:nodeActions animated:YES completion:nil];
}

- (IBAction)copyAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
        browserVC.browserViewControllerDelegate = self;
        browserVC.selectedNodesArray = [NSArray arrayWithArray:self.selectedNodesMutableArray];
        [browserVC setBrowserAction:BrowserActionCopy];
    }
}

- (IBAction)leaveShareAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSString *alertMessage = (_selectedNodesMutableArray.count > 1) ? NSLocalizedString(@"leaveSharesAlertMessage", @"Alert message shown when the user tap on the leave share action selecting multipe inshares") : NSLocalizedString(@"leaveShareAlertMessage", @"Alert message shown when the user tap on the leave share action for one inshare");
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"leaveFolder", nil) message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self removeSelectedIncomingShares];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)shareLinkAction:(UIBarButtonItem *)sender {
    [self presentGetLinkVCForNodes:self.selectedNodesMutableArray];
    
    [self setEditing:NO animated:YES];
}

- (IBAction)shareFolderAction:(UIBarButtonItem *)sender {
    [self shareFolder];
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
            alertMessage = NSLocalizedString(@"removeOneShareOneContactMessage", nil);
        } else if ((usersMutableArray.count > 1) && (self.selectedNodesMutableArray.count == 1)) {
            alertMessage = [NSString stringWithFormat:NSLocalizedString(@"removeOneShareMultipleContactsMessage", nil), usersMutableArray.count];
        } else {
            alertMessage = [NSString stringWithFormat:NSLocalizedString(@"removeMultipleSharesMultipleContactsMessage", nil), usersMutableArray.count];
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"removeSharing", nil) message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
    self.outgoingButton.selected = self.linksButton.selected = NO;

    [self updateTabSelection];

    [self disableSearchAndSelection];
    
    [self incomingVerifiedNodes];
    [self incomingUnverifiedNodes];
    [self.tableView reloadData];
}

- (IBAction)outgoingTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.incomingButton.selected = self.linksButton.selected = NO;
    
    [self updateTabSelection];
    
    [self disableSearchAndSelection];
    
    [self allOutgoingNodes];
    [self.tableView reloadData];
}

- (IBAction)linksTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.incomingButton.selected = self.outgoingButton.selected = NO;
    
    [self updateTabSelection];
    
    [self disableSearchAndSelection];
    
    [self publicLinks];
    [self.tableView reloadData];
}

- (IBAction)removeLinkAction:(UIBarButtonItem *)sender {
    [self showRemoveLinkWarning:self.selectedNodesMutableArray];
}

- (IBAction)saveToPhotosAction:(UIBarButtonItem *)sender {
    [self saveSelectedNodesToPhotos];
}

- (void)disableSearchAndSelection {
    if (self.searchController.isActive) {
        self.searchController.active = NO;
        [self searchBarCancelButtonClicked:self.searchController.searchBar];
    }
    
    if (self.tableView.isEditing) {
        [self.selectedNodesMutableArray removeAllObjects];
        [self.selectedSharesMutableArray removeAllObjects];
        
        [self updateNavigationBarTitle];
        
        [self configToolbarItemsForSharedItems];
        [self toolbarItemsSetEnabled:NO];
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.linksButton.selected || section == 1) {
                numberOfRows = self.searchNodesArray.count;
            } else {
                numberOfRows = self.searchUnverifiedNodesArray.count;
            }
        } else {
            if (self.incomingButton.selected) {
                if (section == 0) {
                    numberOfRows = self.incomingUnverifiedNodesMutableArray.count;
                } else {
                    numberOfRows = self.incomingNodesMutableArray.count;
                }
            } else if (self.outgoingButton.selected) {
                if (section == 0) {
                    numberOfRows = self.outgoingUnverifiedNodesMutableArray.count;
                } else {
                    numberOfRows = self.outgoingNodesMutableArray.count;
                }
            } else if (self.linksButton.selected) {
                numberOfRows = self.publicLinksArray.count;
            }
        }
    }
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (self.incomingButton.selected) {
        if (indexPath.section == 0) {
            return [self unverifiedIncomingSharedCellAtIndexPath:indexPath node:node];
        }
        return [self isSharedItemsRootNode:node] ? [self incomingSharedCellAtIndexPath:indexPath forNode:node] : [self nodeCellAtIndexPath:indexPath node:node];
    } else if (self.outgoingButton.selected) {
        if (indexPath.section == 0) {
            return [self unverifiedOutgoingSharedCellAtIndexPath:indexPath node:node];
        }
        return [self isSharedItemsRootNode:node] ? [self outgoingSharedCellAtIndexPath:indexPath forNode:node] : [self nodeCellAtIndexPath:indexPath node:node];
    } else {
        return [self linkSharedCellAtIndexPath:indexPath forNode:node];
    }
}

- (void)configureSelectionForCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath forNode:(MEGANode *)node {
    if (self.tableView.isEditing) {
        for (MEGANode *n in self.selectedNodesMutableArray) {
            if ([n handle] == [node handle]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = UIView.alloc.init;
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
}

- (void)configureAccessibilityForCell:(SharedItemsTableViewCell *)cell {
    cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (tableView.isEditing) {
        for (MEGANode *tempNode in self.selectedNodesMutableArray) {
            if (tempNode.handle == node.handle) {
                return;
            }
        }
        
        if (node != nil) {
            [_selectedNodesMutableArray addObject:node];
        }
        
        [self updateNavigationBarTitle];
        [self updateToolbarItemsIfNeeded];
        [self toolbarItemsSetEnabled:YES];
        
        NSUInteger nodeListSize = 0;
        if (self.incomingButton.selected) {
            nodeListSize = self.incomingNodesMutableArray.count;
        } else if (self.outgoingButton.selected) {
            nodeListSize = self.outgoingNodesMutableArray.count;
        } else if (self.linksButton.selected) {
            nodeListSize = self.publicLinksArray.count;
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
            if ([self shouldShowContactVerificationOnTapForIndexPath:indexPath node:node]) {
                [self showContactVerificationViewForIndexPath:indexPath];
            } else {
                BOOL isBackupNode = [[[MyBackupsOCWrapper alloc] init] isBackupNode:node];
                CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
                cloudDriveVC.isFromSharedItem = YES;
                [cloudDriveVC setParentNode:node];
                [cloudDriveVC setDisplayMode:isBackupNode ? DisplayModeBackup : DisplayModeCloudDrive];
                
                [self.navigationController pushViewController:cloudDriveVC animated:YES];
            }
            break;
        }
        
        case MEGANodeTypeFile: {
            if (node.name.mnz_isVisualMediaPathExtension) {
                [self.navigationController presentViewController:[self photoBrowserForMediaNode:node] animated:YES completion:nil];
            } else {
                [node mnz_openNodeInNavigationController:self.navigationController folderLink:NO fileLink:nil];
            }
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
        } else {
            [self updateToolbarItemsIfNeeded];
        }
        
        allNodesSelected = NO;
        
        return;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    [self startEditingModeAtIndex:indexPath];
}
    
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    if (self.incomingButton.selected) {
        UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_leaveSharingInViewController:self completion:nil];
            [self endEditingMode];
        }];
        shareAction.image = [[UIImage imageNamed:@"leaveShare"] imageWithTintColor:UIColor.whiteColor];
        shareAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else if (self.outgoingButton.selected) {
        UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_removeSharingWithCompletion:nil];
            [self endEditingMode];
        }];
        shareAction.image = [[UIImage imageNamed:@"removeShare"] imageWithTintColor:UIColor.whiteColor];
        shareAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else if (self.linksButton.selected) {
        UIContextualAction *removeLinkAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [self showRemoveLinkWarning:@[node]];
        }];
        removeLinkAction.image = [[UIImage imageNamed:@"removeLink"] imageWithTintColor:UIColor.whiteColor];
        removeLinkAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[removeLinkAction]];
    } else {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    return [self tableView:tableView contextMenuConfigurationForRowAt:indexPath node:node];
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
         animator:(id<UIContextMenuInteractionCommitAnimating>)animator {
    [self willPerformPreviewActionForMenuWithAnimator:animator];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if (searchController.isActive) {
        if (self.searchController.searchBar.text.length < kMinimumLettersToStartTheSearch) {
            if (self.searchNodeUseCaseOCWrapper != nil) {
                [self.searchNodeUseCaseOCWrapper cancelSearch];
            }
            [self loadDefaultSharedItems];
        } else {
            if (self.searchNodeUseCaseOCWrapper == nil) {
                self.searchNodeUseCaseOCWrapper = SearchNodeUseCaseOCWrapper.alloc.init;
            }

            [self searchBy:searchString];
        }
    } else {
        if (self.searchNodeUseCaseOCWrapper != nil) {
            [self.searchNodeUseCaseOCWrapper cancelSearch];
        }
        [self reloadUI];
    }
}

#pragma mark - UISearchControllerDelegate

- (void)didPresentSearchController:(UISearchController *)searchController {
    if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
        self.searchController.searchBar.superview.frame = CGRectMake(0, self.selectorView.frame.size.height + self.navigationController.navigationBar.frame.size.height, self.searchController.searchBar.superview.frame.size.width, self.searchController.searchBar.superview.frame.size.height);
    }
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    NSInteger itemSelected;
    NSArray *nodesToCheckArray;
    if (self.incomingButton.selected) {
        itemSelected = 0;
        nodesToCheckArray = self.incomingNodesMutableArray;
    } else if (self.outgoingButton.selected) {
        itemSelected = 1;
        nodesToCheckArray = self.outgoingNodesMutableArray;
    } else {
        itemSelected = 2;
        nodesToCheckArray = self.publicLinksArray;
    }
    
    if ([nodeList mnz_shouldProcessOnNodesUpdateInSharedForNodes:nodesToCheckArray itemSelected:itemSelected]) {
        [self reloadUI];
    }
}

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    [self reloadUI];
}

#pragma mark - NodeActionViewControllerDelegate

- (void)nodeAction:(NodeActionViewController *)nodeAction didSelect:(MegaNodeActionType)action for:(MEGANode *)node from:(UIButton *)sender {
    switch (action) {
        case MegaNodeActionTypeEditTextFile: {
            [node mnz_editTextFileInViewController:self];
            break;
        }
            
        case MegaNodeActionTypeDownload:
            if (node != nil) {
                [CancellableTransferRouterOCWrapper.alloc.init downloadNodes:@[node] presenter:self isFolderLink:NO];
            }
            break;
            
        case MegaNodeActionTypeRename:
            [node mnz_renameNodeInViewController:self];
            break;
            
        case MegaNodeActionTypeExportFile:
            [self exportFileFrom:node sender:sender];
            break;
            
        case MegaNodeActionTypeShareFolder:
            self.selectedNodesMutableArray = @[node].mutableCopy;
            [self shareFolder];
            break;
            
        case MegaNodeActionTypeManageShare: {
            ContactsViewController *contactsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsViewControllerID"];
            contactsVC.node = node;
            contactsVC.contactsMode = ContactsModeFolderSharedWith;
            [self.navigationController pushViewController:contactsVC animated:YES];
            break;
        }
            
        case MegaNodeActionTypeInfo:
            [self showNodeInfo:node from:sender];
            break;
            
        case MegaNodeActionTypeFavourite: {
            MEGAGenericRequestDelegate *delegate = [MEGAGenericRequestDelegate.alloc initWithCompletion:^(MEGARequest * _Nonnull request, MEGAError * _Nonnull error) {
                if (error.type == MEGAErrorTypeApiOk) {
                    if (request.numDetails == 1) {
                        [[QuickAccessWidgetManager.alloc init] insertFavouriteItemFor:node];
                    } else {
                        [[QuickAccessWidgetManager.alloc init] deleteFavouriteItemFor:node];
                    }
                }
            }];
            [MEGASdkManager.sharedMEGASdk setNodeFavourite:node favourite:!node.isFavourite delegate:delegate];
            break;
        }
            
        case MegaNodeActionTypeLabel:
            [node mnz_labelActionSheetInViewController:self];
            break;
            
        case MegaNodeActionTypeLeaveSharing:
            [node mnz_leaveSharingInViewController:self completion:nil];
            break;
            
        case MegaNodeActionTypeRemoveSharing:
            [node mnz_removeSharingWithCompletion:nil];
            break;
            
        case MegaNodeActionTypeShareLink:
        case MegaNodeActionTypeManageLink: {
            [self presentGetLinkVCForNodes:@[node]];
            break;
        }
            
        case MegaNodeActionTypeRemoveLink: {
            [self showRemoveLinkWarning:@[node]];
            break;
        }

        case MegaNodeActionTypeMoveToRubbishBin:
            [node mnz_askToMoveToTheRubbishBinInViewController:self];
            break;
            
        case MegaNodeActionTypeSendToChat:
            [node mnz_sendToChatInViewController:self];
            break;
            
        case MegaNodeActionTypeSaveToPhotos:
            [SaveMediaToPhotosUseCaseOCWrapper.alloc.init saveToPhotosWithNode:node isFolderLink:NO];
            break;
            
        case MegaNodeActionTypeMove:
            [node mnz_moveInViewController:self];
            break;
            
        case MegaNodeActionTypeCopy:
            [node mnz_copyInViewController:self];
            break;
            
        case MegaNodeActionTypeVerifyContact: {
            NSIndexPath *indexPath = [self indexPathFromSender:sender];
            [self showContactVerificationViewForIndexPath:indexPath];
            break;
        }
            
        case MegaNodeActionTypeViewVersions:
            [node mnz_showNodeVersionsInViewController:self];
            break;
            
        default:
            break;
    }
}

- (void)showNodeContextMenu:(UIButton *)sender {
    if (self.tableView.isEditing) {
        return;
    }
    
    NSIndexPath *indexPath = [self indexPathFromSender:sender];
    if (indexPath == nil) {
        return;
    }
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    MEGAShare *share = [self shareAtIndexPath:indexPath];
    
    BOOL isBackupNode = [[[MyBackupsOCWrapper alloc] init] isBackupNode:node];
    NodeActionViewController *nodeActions = [NodeActionViewController.alloc initWithNode:node
                                                                                delegate:self
                                                                             displayMode:self.linksButton.selected ? DisplayModeCloudDrive : DisplayModeSharedItem
                                                                              isIncoming:self.incomingButton.selected
                                                                            isBackupNode:isBackupNode
                                                                            sharedFolder:share
                                                                 shouldShowVerifyContact:indexPath.section == 0
                                                                                  sender:sender];
    [self presentViewController:nodeActions animated:YES completion:nil];
}

#pragma mark - NodeInfoViewControllerDelegate

- (void)nodeInfoViewController:(NodeInfoViewController *)nodeInfoViewController presentParentNode:(MEGANode *)node {
    [node navigateToParentAndPresent];
}

#pragma mark - AudioPlayerPresenterProtocol

- (void)updateContentView:(CGFloat)height {
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, height, 0);
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if([AudioPlayerManager.shared isPlayerAlive] && navigationController.viewControllers.count > 1) {
        self.shouldRemovePlayerDelegate = ![viewController conformsToProtocol:@protocol(AudioPlayerPresenterProtocol)];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    self.shouldRemovePlayerDelegate = YES;
}

#pragma mark - BrowserViewControllerDelegate, ContactsViewControllerDelegate

- (void)nodeEditCompleted:(BOOL)complete {
    [self setEditing:!complete animated:NO];
}

@end
