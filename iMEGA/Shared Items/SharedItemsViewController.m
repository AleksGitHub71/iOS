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
#import "UIActivityViewController+MNZCategory.h"
#import "UIImage+MNZCategory.h"
#import "UIViewController+MNZCategory.h"

#import "BrowserViewController.h"
#import "CloudDriveViewController.h"
#import "ContactsViewController.h"
#import "CopyrightWarningViewController.h"
#import "EmptyStateView.h"
#import "SharedItemsTableViewCell.h"
#import "MEGAPhotoBrowserViewController.h"
#import "NodeTableViewCell.h"

@interface SharedItemsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UIViewControllerPreviewingDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGAGlobalDelegate, MEGARequestDelegate, MGSwipeTableCellDelegate, NodeInfoViewControllerDelegate, NodeActionViewControllerDelegate, BrowserViewControllerDelegate, ContatctsViewControllerDelegate> {
    BOOL allNodesSelected;
}

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
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeLinkBarButtonItem;

@property (nonatomic, strong) MEGAShareList *incomingShareList;
@property (nonatomic, strong) NSMutableArray *incomingNodesMutableArray;

@property (nonatomic, strong) MEGAShareList *outgoingShareList;
@property (nonatomic, strong) NSMutableArray *outgoingSharesMutableArray;
@property (nonatomic, strong) NSMutableArray *outgoingNodesMutableArray;

@property (nonatomic, strong) NSArray *publicLinksArray;

@property (nonatomic, strong) NSMutableArray *selectedNodesMutableArray;
@property (nonatomic, strong) NSMutableArray *selectedSharesMutableArray;

@property (nonatomic, strong) NSMutableDictionary *incomingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *incomingIndexPathsMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingNodesForEmailMutableDictionary;
@property (nonatomic, strong) NSMutableDictionary *outgoingIndexPathsMutableDictionary;

@property (nonatomic) NSMutableArray *searchNodesArray;
@property (nonatomic) UISearchController *searchController;

@property (nonatomic) MEGASortOrderType sortOrderType;

@property (weak, nonatomic) IBOutlet UIView *selectorView;
@property (weak, nonatomic) IBOutlet UIButton *incomingButton;
@property (weak, nonatomic) IBOutlet UILabel *incomingLabel;
@property (weak, nonatomic) IBOutlet UIView *incomingLineView;
@property (weak, nonatomic) IBOutlet UIButton *outgoingButton;
@property (weak, nonatomic) IBOutlet UILabel *outgoingLabel;
@property (weak, nonatomic) IBOutlet UIView *outgoingLineView;
@property (weak, nonatomic) IBOutlet UIButton *linksButton;
@property (weak, nonatomic) IBOutlet UILabel *linksLabel;
@property (weak, nonatomic) IBOutlet UIView *linksLineView;

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
    
    self.editBarButtonItem.accessibilityLabel = NSLocalizedString(@"more", @"Top menu option which opens more menu options in a context menu.");
    self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem];
    
    self.incomingButton.accessibilityLabel = NSLocalizedString(@"incoming", nil);
    self.outgoingButton.accessibilityLabel = NSLocalizedString(@"outgoing", nil);
    self.linksButton.accessibilityLabel = NSLocalizedString(@"Links", nil);
    
    self.incomingLabel.text = NSLocalizedString(@"incoming", nil);
    self.incomingLabel.isAccessibilityElement = NO;
    self.outgoingLabel.text = NSLocalizedString(@"outgoing", nil);
    self.outgoingLabel.isAccessibilityElement = NO;
    self.linksLabel.text = NSLocalizedString(@"Links", nil);
    self.linksLabel.isAccessibilityElement = NO;
    
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
    
    if (@available(iOS 13.0, *)) {
        [self configPreviewingRegistration];
    }
    self.sortOrderType = [NSUserDefaults.standardUserDefaults integerForKey:@"SharedItemsSortOrderType"];
    if (self.sortOrderType == MEGASortOrderTypeNone) {
        self.sortOrderType = MEGASortOrderTypeAlphabeticalAsc;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    
    [self addSearchBar];
    
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[TransfersWidgetViewController sharedTransferViewController].progressView showWidgetIfNeeded];
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
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [AppearanceManager forceToolbarUpdate:self.toolbar traitCollection:self.traitCollection];
            [AppearanceManager forceSearchBarUpdate:self.searchController.searchBar traitCollection:self.traitCollection];
            
            [self updateAppearance];
        }
    }
    
    [self configPreviewingRegistration];
}

#pragma mark - Private

- (void)updateAppearance {
    self.view.backgroundColor = UIColor.mnz_background;
    
    self.tableView.separatorColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    [self updateSelector];
}

- (void)reloadUI {
    if (self.incomingButton.selected) {
        [self incomingNodes];
    } else if (self.outgoingButton.selected) {
        [self outgoingNodes];
    } else if (self.linksButton.selected) {
        [self publicLinks];
    }
    
    [self updateNavigationBarTitle];
    
    [self.tableView reloadData];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setNavigationBarButtonItemsEnabled:boolValue];
    [self toolbarItemsSetEnabled:boolValue];
    
    boolValue ? [self addSearchBar] : [self hideSearchBarIfNotActive];
    
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
    self.removeLinkBarButtonItem.enabled = boolValue;
}

- (void)addSearchBar {
    if (self.searchController && !self.tableView.tableHeaderView) {
        self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
}

- (void)hideSearchBarIfNotActive {
    if (!self.searchController.isActive) {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)incomingNodes {
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
    
    if (self.incomingNodesMutableArray.count == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        [self addSearchBar];
    }
}

- (void)outgoingNodes {
    [_outgoingNodesForEmailMutableDictionary removeAllObjects];
    [_outgoingIndexPathsMutableDictionary removeAllObjects];
    
    _outgoingShareList = [MEGASdkManager.sharedMEGASdk outShares:self.sortOrderType];
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
        [toolbarItemsMutableArray addObjectsFromArray:@[self.shareBarButtonItem, flexibleItem, self.shareFolderBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.removeShareBarButtonItem]];
    } else if (self.linksButton.selected) {
        [toolbarItemsMutableArray addObjectsFromArray:@[self.shareBarButtonItem, flexibleItem, self.downloadBarButtonItem, flexibleItem, self.removeLinkBarButtonItem]];
    }
    
    [_toolbar setItems:toolbarItemsMutableArray];
}

- (void)removeSelectedIncomingShares {
    NSArray *filesAndFolders = self.selectedNodesMutableArray.mnz_numberOfFilesAndFolders;
    MEGARemoveRequestDelegate *removeRequestDelegate = [MEGARemoveRequestDelegate.alloc initWithMode:DisplayModeSharedItem files:[filesAndFolders.firstObject unsignedIntegerValue] folders:[filesAndFolders[1] unsignedIntegerValue] completion:nil];
    for (NSInteger i = 0; i < self.selectedNodesMutableArray.count; i++) {
        [[MEGASdkManager sharedMEGASdk] removeNode:[self.selectedNodesMutableArray objectAtIndex:i] delegate:removeRequestDelegate];
    }
    
    [self setEditing:NO animated:YES];
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
        [self setEditing:NO animated:YES];
        [self reloadUI];
    }];
    
    for (MEGAShare *share in self.selectedSharesMutableArray) {
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[share nodeHandle]];
        [[MEGASdkManager sharedMEGASdk] shareNode:node withEmail:share.user level:MEGAShareTypeAccessUnknown delegate:shareRequestDelegate];
    }
    
    [self setEditing:NO animated:YES];
}

- (MEGANode *)nodeAtIndexPath:(NSIndexPath *)indexPath {
    if (self.searchController.isActive) {
        return self.searchNodesArray[indexPath.row];
    } else {
        if (self.incomingButton.selected) {
            return self.incomingNodesMutableArray[indexPath.row];
        } else if (self.outgoingButton.selected) {
            return self.outgoingNodesMutableArray[indexPath.row];
        } else if (self.linksButton.selected) {
            return self.publicLinksArray[indexPath.row];
        } else {
            return nil;
        }
    }
}

- (void)showNodeInfo:(MEGANode *)node {
    MEGANavigationController *nodeInfoNavigation = [NodeInfoViewController instantiateWithNode:node delegate:self];
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
    
    MEGAShare *share = nil;
    for (NSUInteger i = 0; i < self.incomingShareList.size.unsignedIntegerValue; i++) {
        MEGAShare *s = [self.incomingShareList shareAtIndex:i];
        if (s.nodeHandle == node.handle) {
            share = s;
            break;
        }
    }
    
    NSString *userEmail = share.user;
    self.incomingNodesForEmailMutableDictionary[node.base64Handle] = userEmail;
    self.incomingIndexPathsMutableDictionary[node.base64Handle] = indexPath;
    
    cell.thumbnailImageView.image = UIImage.mnz_incomingFolderImage;
    
    cell.nameLabel.text = node.name;
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
    [cell configureCellForNode:node delegate:self api:MEGASdkManager.sharedMEGASdk];
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

- (void)updateSelector {
    self.selectorView.backgroundColor = [UIColor mnz_mainBarsForTraitCollection:self.traitCollection];
    
    self.incomingButton.tintColor = self.incomingButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.incomingLabel.textColor = self.incomingButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.incomingLineView.backgroundColor = self.incomingButton.selected ? [UIColor mnz_redForTraitCollection:self.traitCollection] : nil;
    
    self.outgoingButton.tintColor = self.outgoingButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.outgoingLabel.textColor = self.outgoingButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.outgoingLineView.backgroundColor = self.outgoingButton.selected ? [UIColor mnz_redForTraitCollection:self.traitCollection] : nil;
    
    self.linksButton.tintColor = self.linksButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.linksLabel.textColor = self.linksButton.selected ? [UIColor mnz_redForTraitCollection:(self.traitCollection)] : [UIColor mnz_primaryGrayForTraitCollection:(self.traitCollection)];
    self.linksLineView.backgroundColor = self.linksButton.selected ? [UIColor mnz_redForTraitCollection:self.traitCollection] : nil;
}

- (void)shouldStartEditingModeAtIndex:(NSIndexPath *)indexPath {
    [self setEditing:YES animated:YES];
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    [self configToolbarItemsForSharedItems];
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark - Utils

- (void)selectSegment:(NSUInteger)index {
    if (index == 0) {
        [self incomingTouchUpInside:nil];
    } else if (index == 1) {
        [self outgoingTouchUpInside:nil];
    }
}

- (MEGAPhotoBrowserViewController *)photoBrowserForMediaNode:(MEGANode *)node {
    NSArray *nodesArray = (self.searchController.isActive ? self.searchNodesArray : self.publicLinksArray);
    NSMutableArray<MEGANode *> *mediaNodesArray = NSMutableArray.alloc.init;
    for (MEGANode *node in nodesArray) {
        if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
            [mediaNodesArray addObject:node];
        }
    }
    
    MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:MEGASdkManager.sharedMEGASdk displayMode:DisplayModeCloudDrive presentingNode:node preferredIndex:0];
    
    return photoBrowserVC;
}

#pragma mark - IBActions

- (IBAction)editTapped:(UIBarButtonItem *)sender {
    if (self.tableView.isEditing) {
        [self setEditing:NO animated:YES];
    } else {
        __weak __typeof__(self) weakSelf = self;
        UIImageView *checkmarkImageView = [UIImageView.alloc initWithImage:[UIImage imageNamed:@"turquoise_checkmark"]];

        NSMutableArray<ActionSheetAction *> *actions = NSMutableArray.new;
        [actions addObject:[ActionSheetAction.alloc initWithTitle:NSLocalizedString(@"sortTitle", @"Section title of the 'Sort by'") detail:nil image:[UIImage imageNamed:@"sort"] style:UIAlertActionStyleDefault actionHandler:^{
            NSMutableArray<ActionSheetAction *> *actions = NSMutableArray.new;
            [actions addObject:[ActionSheetAction.alloc initWithTitle:NSLocalizedString(@"nameAscending", @"Sort by option (1/6). This one orders the files alphabethically") detail:nil accessoryView:self.sortOrderType == MEGASortOrderTypeAlphabeticalAsc ? checkmarkImageView : nil image:[UIImage imageNamed:@"ascending"] style:UIAlertActionStyleDefault actionHandler:^{
                weakSelf.sortOrderType = MEGASortOrderTypeAlphabeticalAsc;
                [weakSelf reloadUI];
                [NSUserDefaults.standardUserDefaults setInteger:self.sortOrderType forKey:@"SharedItemsSortOrderType"];
            }]];
            [actions addObject:[ActionSheetAction.alloc initWithTitle:NSLocalizedString(@"nameDescending", @"Sort by option (2/6). This one arranges the files on reverse alphabethical order") detail:nil accessoryView:self.sortOrderType == MEGASortOrderTypeAlphabeticalDesc ? checkmarkImageView : nil image:[UIImage imageNamed:@"descending"] style:UIAlertActionStyleDefault actionHandler:^{
                weakSelf.sortOrderType = MEGASortOrderTypeAlphabeticalDesc;
                [weakSelf reloadUI];
                [NSUserDefaults.standardUserDefaults setInteger:self.sortOrderType forKey:@"SharedItemsSortOrderType"];
            }]];
            
            ActionSheetViewController *sortByActionSheet = [ActionSheetViewController.alloc initWithActions:actions headerTitle:nil dismissCompletion:nil sender:self.navigationItem.rightBarButtonItems.firstObject];
            [weakSelf presentViewController:sortByActionSheet animated:YES completion:nil];
        }]];
        [actions addObject:[ActionSheetAction.alloc initWithTitle:NSLocalizedString(@"select", @"Button that allows you to select a given folder") detail:nil image:[UIImage imageNamed:@"select"] style:UIAlertActionStyleDefault actionHandler:^{
            [weakSelf setEditing:YES animated:YES];
            
            weakSelf.selectedNodesMutableArray = NSMutableArray.alloc.init;
            weakSelf.selectedSharesMutableArray = NSMutableArray.alloc.init;
            
            [weakSelf configToolbarItemsForSharedItems];
            [weakSelf toolbarItemsSetEnabled:NO];
        }]];
        
        ActionSheetViewController *moreActionSheet = [ActionSheetViewController.alloc initWithActions:actions headerTitle:nil dismissCompletion:nil sender:self.navigationItem.rightBarButtonItems.firstObject];
        [self presentViewController:moreActionSheet animated:YES completion:nil];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    [self.tableView setEditing:editing animated:animated];
    
    [self updateNavigationBarTitle];
    
    if (editing) {
        self.editBarButtonItem.image = nil;
        self.editBarButtonItem.title = NSLocalizedString(@"cancel", @"Button title to cancel something");
        self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        
        if (![self.tabBarController.view.subviews containsObject:self.toolbar]) {
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
        }
        
        for (SharedItemsTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = UIView.alloc.init;
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        self.editBarButtonItem.image = [UIImage imageNamed:@"moreSelected"];
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
    
    NodeActionViewController *nodeActions = [NodeActionViewController.alloc initWithNode:[self nodeAtIndexPath:indexPath] delegate:self displayMode:self.linksButton.selected ? DisplayModeCloudDrive : DisplayModeSharedItem isIncoming:self.incomingButton.selected sender:sender];
    [self presentViewController:nodeActions animated:YES completion:nil];
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        for (MEGANode *n in _selectedNodesMutableArray) {
            if (![Helper isFreeSpaceEnoughToDownloadNode:n isFolderLink:NO]) {
                [self setEditing:NO animated:YES];
                return;
            }
        }
        
        [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:NSLocalizedString(@"downloadStarted", nil)];
        
        for (MEGANode *n in _selectedNodesMutableArray) {
            [Helper downloadNode:n folderPath:[Helper relativePathForOffline] isFolderLink:NO];
        }
        
        [self setEditing:NO animated:YES];
    }
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

- (IBAction)shareAction:(UIBarButtonItem *)sender {
    UIActivityViewController *activityVC = [UIActivityViewController activityViewControllerForNodes:self.selectedNodesMutableArray sender:self.shareBarButtonItem];
    __weak __typeof__(self) weakSelf = self;
    activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        if (completed && !activityError) {
            [weakSelf setEditing:NO animated:YES];
        }
    };
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (IBAction)shareFolderAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsNavigationControllerID"];
        ContactsViewController *contactsVC = navigationController.viewControllers.firstObject;
        contactsVC.contatctsViewControllerDelegate = self;
        contactsVC.contactsMode = ContactsModeShareFoldersWith;
        [contactsVC setNodesArray:[_selectedNodesMutableArray copy]];
        [self presentViewController:navigationController animated:YES completion:nil];
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

    [self updateSelector];

    [self disableSearchAndSelection];
    
    [self incomingNodes];
    [self.tableView reloadData];
}

- (IBAction)outgoingTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.incomingButton.selected = self.linksButton.selected = NO;
    
    [self updateSelector];
    
    [self disableSearchAndSelection];
    
    [self outgoingNodes];
    [self.tableView reloadData];
}

- (IBAction)linksTouchUpInside:(UIButton *)sender {
    if (sender.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    self.incomingButton.selected = self.outgoingButton.selected = NO;
    
    [self updateSelector];
    
    [self disableSearchAndSelection];
    
    [self publicLinks];
    [self.tableView reloadData];
}

- (IBAction)removeLinkAction:(UIBarButtonItem *)sender {
    if (MEGAReachabilityManager.isReachableHUDIfNot) {
        for (MEGANode *node in self.selectedNodesMutableArray) {
            [node mnz_removeLink];
        }
        [self setEditing:NO animated:YES];
    }
}

- (void)disableSearchAndSelection {
    if (self.searchController.isActive) {
        self.searchController.active = NO;
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
            } else if (self.linksButton.selected) {
                numberOfRows = self.publicLinksArray.count;
            }
        }
    }
    
    if (numberOfRows == 0) {
        [self setNavigationBarButtonItemsEnabled:NO];
    } else {
        [self setNavigationBarButtonItemsEnabled:YES];
    }
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MEGANode *node = [self nodeAtIndexPath:indexPath];
    
    if (self.incomingButton.selected) {
        return [self incomingSharedCellAtIndexPath:indexPath forNode:node];
    } else if (self.outgoingButton.selected) {
        return [self outgoingSharedCellAtIndexPath:indexPath forNode:node];
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
    if (@available(iOS 11.0, *)) {
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
    } else {
        cell.delegate = self;
    }
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
        
        for (MEGANode *tempNode in self.selectedNodesMutableArray) {
            if (tempNode.handle == node.handle) {
                return;
            }
        }
        
        if (node != nil) {
            [_selectedNodesMutableArray addObject:node];
        }
        
        [self updateNavigationBarTitle];
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
            CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            [cloudDriveVC setParentNode:node];
            [cloudDriveVC setDisplayMode:DisplayModeCloudDrive];            
            
            [self.navigationController pushViewController:cloudDriveVC animated:YES];
            break;
        }
        
        case MEGANodeTypeFile: {
            if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
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
        }
        
        allNodesSelected = NO;
        
        return;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didBeginMultipleSelectionInteractionAtIndexPath:(NSIndexPath *)indexPath {
    [self shouldStartEditingModeAtIndex:indexPath];
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
        shareAction.image = [UIImage imageNamed:@"leaveShareGesture"];
        shareAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else if (self.outgoingButton.selected) {
        UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_removeSharing];
            [self setEditing:NO animated:YES];
        }];
        shareAction.image = [UIImage imageNamed:@"removeShareGesture"];
        shareAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[shareAction]];
    } else if (self.linksButton.selected) {
        UIContextualAction *removeLinkAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [node mnz_removeLink];
            [self setEditing:NO animated:YES];
        }];
        removeLinkAction.image = [UIImage imageNamed:@"removeLinkGesture"];
        removeLinkAction.backgroundColor = [UIColor mnz_redForTraitCollection:self.traitCollection];
        return [UISwipeActionsConfiguration configurationWithActions:@[removeLinkAction]];
    } else {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
}

#pragma clang diagnostic pop
    
#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchNodesArray = nil;
    
    if (!MEGAReachabilityManager.isReachable) {
        self.tableView.tableHeaderView = nil;
    }
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if (searchController.isActive) {
        if ([searchString isEqualToString:@""]) {
            if (self.incomingButton.selected) {
                self.searchNodesArray = self.incomingNodesMutableArray;
            } else if (self.outgoingButton.selected) {
                self.searchNodesArray = self.outgoingNodesMutableArray;
            } else if (self.linksButton.selected) {
                self.searchNodesArray = self.publicLinksArray.mutableCopy;
            }
        } else {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF.name contains[c] %@", searchString];
            if (self.incomingButton.selected) {
                self.searchNodesArray = [[self.incomingNodesMutableArray filteredArrayUsingPredicate:resultPredicate] mutableCopy];
            } else if (self.outgoingButton.selected) {
                self.searchNodesArray = [[self.outgoingNodesMutableArray filteredArrayUsingPredicate:resultPredicate] mutableCopy];
            } else if (self.linksButton.selected) {
                self.searchNodesArray = [self.publicLinksArray filteredArrayUsingPredicate:resultPredicate].mutableCopy;
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
                MEGANode *nodePressed = self.incomingButton.selected ? [self.incomingNodesMutableArray objectOrNilAtIndex:indexPath.row] : [self.outgoingNodesMutableArray objectOrNilAtIndex:indexPath.row];
                if (nodeSelected.handle == nodePressed.handle) {
                    [self setEditing:NO animated:YES];
                }
            }
        } else {
            [self shouldStartEditingModeAtIndex:indexPath];
        }
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - DZNEmptyDataSetSource

- (nullable UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView {
    EmptyStateView *emptyStateView = [EmptyStateView.alloc initWithImage:[self imageForEmptyState] title:[self titleForEmptyState] description:[self descriptionForEmptyState] buttonTitle:[self buttonTitleForEmptyState]];
    [emptyStateView.button addTarget:self action:@selector(buttonTouchUpInsideEmptyState) forControlEvents:UIControlEventTouchUpInside];
    
    return emptyStateView;
}

#pragma mark - Empty State

- (NSString *)titleForEmptyState {
    NSString *text = @"";
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.searchController.searchBar.text.length > 0) {
                text = NSLocalizedString(@"noResults", @"Title shown when you make a search and there is 'No Results'");
            }
        } else {
            if (self.incomingButton.selected) {
                text = NSLocalizedString(@"noIncomingSharedItemsEmptyState_text", nil);
            } else if (self.outgoingButton.selected) {
                text = NSLocalizedString(@"noOutgoingSharedItemsEmptyState_text", nil);
            } else if (self.linksButton.selected) {
                text = NSLocalizedString(@"No Public Links", @"Title for empty state view of 'Links' in Shared Items.");
            }
        }
    } else {
        text = NSLocalizedString(@"noInternetConnection",  nil);
    }
    
    return text;
}

- (NSString *)descriptionForEmptyState {
    NSString *text = @"";
    if (!MEGAReachabilityManager.isReachable && !MEGAReachabilityManager.sharedManager.isMobileDataEnabled) {
        text = NSLocalizedString(@"Mobile Data is turned off", @"Information shown when the user has disabled the 'Mobile Data' setting for MEGA in the iOS Settings.");
    }
    
    return text;
}

- (UIImage *)imageForEmptyState {
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
            } else if (self.linksButton.selected) {
                image = [UIImage imageNamed:@"linksEmptyState"];
            }
        }
    } else {
        image = [UIImage imageNamed:@"noInternetEmptyState"];
    }
    
    return image;
}

- (NSString *)buttonTitleForEmptyState {
    NSString *text = @"";
    if (!MEGAReachabilityManager.isReachable && !MEGAReachabilityManager.sharedManager.isMobileDataEnabled) {
        text = NSLocalizedString(@"Turn Mobile Data on", @"Button title to go to the iOS Settings to enable 'Mobile Data' for the MEGA app.");
    }
    
    return text;
}

- (void)buttonTouchUpInsideEmptyState {
    if (!MEGAReachabilityManager.isReachable && !MEGAReachabilityManager.sharedManager.isMobileDataEnabled) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
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
            MGSwipeButton *shareButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"leaveShareGesture"] backgroundColor:[UIColor mnz_redForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [node mnz_leaveSharingInViewController:self];
                return YES;
            }];
            [shareButton iconTintColor:UIColor.whiteColor];
            
            return @[shareButton];
        } else if (self.outgoingButton.selected) {
            MGSwipeButton *shareButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"removeShareGesture"] backgroundColor:[UIColor mnz_redForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [node mnz_removeSharing];
                return YES;
            }];
            [shareButton iconTintColor:UIColor.whiteColor];
            
            return @[shareButton];
        } else if (self.linksButton.selected) {
            MGSwipeButton *removeLinkButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"removeLinkGesture"] backgroundColor:[UIColor mnz_redForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [node mnz_removeLink];
                return YES;
            }];
            [removeLinkButton iconTintColor:UIColor.whiteColor];
            
            return @[removeLinkButton];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

#pragma mark - NodeActionViewControllerDelegate

- (void)nodeAction:(NodeActionViewController *)nodeAction didSelect:(MegaNodeActionType)action for:(MEGANode *)node from:(id)sender {
    switch (action) {
        case MegaNodeActionTypeDownload:
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:NSLocalizedString(@"downloadStarted", nil)];
            [node mnz_downloadNode];
            break;
            
        case MegaNodeActionTypeRename:
            [node mnz_renameNodeInViewController:self];
            break;
            
        case MegaNodeActionTypeShare:{
            UIActivityViewController *activityVC = [UIActivityViewController activityViewControllerForNodes:@[node] sender:sender];
            [self presentViewController:activityVC animated:YES completion:nil];
        }
            break;
            
        case MegaNodeActionTypeManageShare: {
            ContactsViewController *contactsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsViewControllerID"];
            contactsVC.node = node;
            contactsVC.contactsMode = ContactsModeFolderSharedWith;
            [self.navigationController pushViewController:contactsVC animated:YES];
            break;
        }
            
        case MegaNodeActionTypeInfo:
            [self showNodeInfo:node];
            break;
            
        case MegaNodeActionTypeFavourite:
            if (@available(iOS 14.0, *)) {
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
            } else {
                [MEGASdkManager.sharedMEGASdk setNodeFavourite:node favourite:!node.isFavourite];
            }
            break;
            
        case MegaNodeActionTypeLabel:
            [node mnz_labelActionSheetInViewController:self];
            break;
            
        case MegaNodeActionTypeLeaveSharing:
            [node mnz_leaveSharingInViewController:self];
            break;
            
        case MegaNodeActionTypeRemoveSharing:
            [node mnz_removeSharing];
            break;
            
        case MegaNodeActionTypeGetLink:
        case MegaNodeActionTypeManageLink: {
            if (MEGAReachabilityManager.isReachableHUDIfNot) {
                [CopyrightWarningViewController presentGetLinkViewControllerForNodes:@[node] inViewController:UIApplication.mnz_presentingViewController];
            }
            break;
        }
            
        case MegaNodeActionTypeRemoveLink: {
            [node mnz_removeLink];
            break;
        }

        case MegaNodeActionTypeMoveToRubbishBin:
            [node mnz_askToMoveToTheRubbishBinInViewController:self];
            break;
            
        case MegaNodeActionTypeSendToChat:
            [node mnz_sendToChatInViewController:self];
            break;
            
        case MegaNodeActionTypeSaveToPhotos:
            [node mnz_saveToPhotosWithApi:MEGASdkManager.sharedMEGASdk];
            break;
            
        case MegaNodeActionTypeMove:
            [node mnz_moveInViewController:self];
            break;
            
        case MegaNodeActionTypeCopy:
            [node mnz_copyInViewController:self];
            break;
            
        default:
            break;
    }
}

#pragma mark - NodeInfoViewControllerDelegate

- (void)nodeInfoViewController:(NodeInfoViewController *)nodeInfoViewController presentParentNode:(MEGANode *)node {
    [node navigateToParentAndPresent];
}

#pragma mark - BrowserViewControllerDelegate, ContactsViewControllerDelegate

- (void)nodeEditCompleted:(BOOL)complete {
    [self setEditing:!complete animated:NO];
}


@end
