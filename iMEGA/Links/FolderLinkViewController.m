#import "FolderLinkViewController.h"

#import "SVProgressHUD.h"
#import "SAMKeychain.h"
#import "UIScrollView+EmptyDataSet.h"

#import "DisplayMode.h"
#import "Helper.h"
#import "MEGANavigationController.h"
#import "MEGANode+MNZCategory.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGAPhotoBrowserViewController.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"

#import "NSString+MNZCategory.h"
#import "MEGALinkManager.h"
#import "UIApplication+MNZCategory.h"
#import "UIImageView+MNZCategory.h"
#import "UITextField+MNZCategory.h"

#import "BrowserViewController.h"
#import "CustomActionViewController.h"
#import "NodeTableViewCell.h"
#import "MainTabBarController.h"
#import "LoginViewController.h"
#import "LinkOption.h"
#import "UnavailableLinkView.h"

@interface FolderLinkViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchResultsUpdating, UISearchDisplayDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGAGlobalDelegate, MEGARequestDelegate, CustomActionViewControllerDelegate> {
    
    BOOL isLoginDone;
    BOOL isFetchNodesDone;
    BOOL isFolderLinkNotValid;
    BOOL isValidatingDecryptionKey;
}

@property (weak, nonatomic) UILabel *navigationBarLabel;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *moreBarButtonItem;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *importBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;

@property (strong, nonatomic) UISearchController *searchController;

@property (nonatomic, strong) MEGANode *parentNode;
@property (nonatomic, strong) MEGANodeList *nodeList;
@property (nonatomic, strong) NSArray *nodesArray;
@property (nonatomic, strong) NSArray *searchNodesArray;

@property (nonatomic, strong) NSMutableArray *cloudImages;
@property (nonatomic, strong) NSMutableArray *selectedNodesArray;
@property (nonatomic, getter=areAllNodesSelected) BOOL allNodesSelected;

@end

@implementation FolderLinkViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.searchController = [Helper customSearchControllerWithSearchResultsUpdaterDelegate:self searchBarDelegate:self];
    self.definesPresentationContext = YES;
    
    isLoginDone = NO;
    isFetchNodesDone = NO;
    
    NSString *thumbsDirectory = [Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"];
    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:thumbsDirectory]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:thumbsDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            MEGALogError(@"Create directory at path failed with error: %@", error);
        }
    }
    
    NSString *previewsDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"previewsV3"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:previewsDirectory]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:previewsDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            MEGALogError(@"Create directory at path failed with error: %@", error);
        }
    }
    
    [self.navigationController.view setBackgroundColor:[UIColor mnz_grayF9F9F9]];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    self.navigationItem.title = AMLocalizedString(@"folderLink", nil);
    
    self.moreBarButtonItem.title = nil;
    self.moreBarButtonItem.image = [UIImage imageNamed:@"moreSelected"];
    self.navigationItem.rightBarButtonItems = @[self.moreBarButtonItem];
    
    self.importBarButtonItem.title = AMLocalizedString(@"import", nil);
    self.downloadBarButtonItem.title = AMLocalizedString(@"downloadButton", @"Download");

    self.navigationController.topViewController.toolbarItems = self.toolbar.items;
    [self.navigationController setToolbarHidden:NO animated:YES];
    self.navigationController.toolbar.barTintColor = UIColor.whiteColor;
    
    self.closeBarButtonItem.title = AMLocalizedString(@"close", @"A button label.");

    if (self.isFolderRootNode) {
        [[MEGASdkManager sharedMEGASdkFolder] loginToFolderLink:self.publicLinkString delegate:self];

        self.navigationItem.leftBarButtonItem = self.closeBarButtonItem;
        
        [self setActionButtonsEnabled:NO];
    } else {
        [self reloadUI];
    }
    
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdkFolder] addMEGAGlobalDelegate:self];
    [[MEGASdkManager sharedMEGASdkFolder] addMEGARequestDelegate:self];
    [[MEGASdkManager sharedMEGASdkFolder] retryPendingConnections];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.navigationController.toolbarHidden = YES;
    
    [[MEGASdkManager sharedMEGASdkFolder] removeMEGAGlobalDelegate:self];
    [[MEGASdkManager sharedMEGASdkFolder] removeMEGARequestDelegate:self];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (isFetchNodesDone) {
            [self setNavigationBarTitleLabel];
        }
        
        [self.tableView reloadEmptyDataSet];
    } completion:nil];
}

#pragma mark - Private

- (void)reloadUI {
    if (!self.parentNode) {
        self.parentNode = [[MEGASdkManager sharedMEGASdkFolder] rootNode];
    }
    
    [self setNavigationBarTitleLabel];
    
    self.nodeList = [[MEGASdkManager sharedMEGASdkFolder] childrenForParent:self.parentNode];
    if (_nodeList.size.unsignedIntegerValue == 0) {
        [self setActionButtonsEnabled:NO];
    } else {
        [self setActionButtonsEnabled:YES];
    }
    
    NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:self.nodeList.size.integerValue];
    for (NSUInteger i = 0; i < self.nodeList.size.integerValue ; i++) {
        [tempArray addObject:[self.nodeList nodeAtIndex:i]];
    }
    
    self.nodesArray = tempArray;
    
    [self.tableView reloadData];
    
    if (self.nodeList.size.unsignedIntegerValue == 0) {
        [_tableView setTableHeaderView:nil];
    } else {
        self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame));
        if (!self.tableView.tableHeaderView) {
            [_tableView setTableHeaderView:self.searchController.searchBar];
        }
    }
}

- (void)setNavigationBarTitleLabel {
    if (self.parentNode.name && !isFolderLinkNotValid) {
        UILabel *label = [Helper customNavigationBarLabelWithTitle:self.parentNode.name subtitle:AMLocalizedString(@"folderLink", nil)];
        label.frame = CGRectMake(0, 0, self.navigationItem.titleView.bounds.size.width, 44);
        self.navigationBarLabel = label;
        self.navigationItem.titleView = self.navigationBarLabel;
    } else {
        self.navigationItem.title = AMLocalizedString(@"folderLink", nil);
    }
}

- (void)showUnavailableLinkView {
    [SVProgressHUD dismiss];
    
    [self disableUIItems];
    
    UnavailableLinkView *unavailableLinkView = [[[NSBundle mainBundle] loadNibNamed:@"UnavailableLinkView" owner:self options: nil] firstObject];
    unavailableLinkView.imageView.image = [UIImage imageNamed:@"invalidFolderLink"];
    unavailableLinkView.titleLabel.text = AMLocalizedString(@"linkUnavailable", nil);
    
    NSString *folderLinkUnavailableText = [NSString stringWithFormat:@"%@\n%@\n%@\n%@", AMLocalizedString(@"folderLinkUnavailableText1", nil), AMLocalizedString(@"folderLinkUnavailableText2", nil), AMLocalizedString(@"folderLinkUnavailableText3", nil), AMLocalizedString(@"folderLinkUnavailableText4", nil)];

    unavailableLinkView.textLabel.text = folderLinkUnavailableText;
    
    if ([[UIDevice currentDevice] iPhone4X]) {
        unavailableLinkView.imageViewCenterYLayoutConstraint.constant = -64;
    }
    
    [self.tableView setBackgroundView:unavailableLinkView];
}

- (void)disableUIItems {
    
    [self.tableView setSeparatorColor:[UIColor clearColor]];
    [self.tableView setBounces:NO];
    [self.tableView setScrollEnabled:NO];
    
    [self setActionButtonsEnabled:NO];
}

- (void)setActionButtonsEnabled:(BOOL)boolValue {
    [_moreBarButtonItem setEnabled:boolValue];
    
    [_importBarButtonItem setEnabled:boolValue];
    [_downloadBarButtonItem setEnabled:boolValue];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setActionButtonsEnabled:boolValue];
    
    [self.tableView reloadData];
}

- (void)setToolbarButtonsEnabled:(BOOL)boolValue {
    [self.downloadBarButtonItem setEnabled:boolValue];
    [self.importBarButtonItem setEnabled:boolValue];
}

- (void)showLinkNotValid {
    isFolderLinkNotValid = YES;
    
    [self disableUIItems];
    
    [SVProgressHUD dismiss];
    [self.tableView reloadData];
}

- (void)showDecryptionAlert {
    UIAlertController *decryptionAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"decryptionKeyAlertTitle", nil) message:AMLocalizedString(@"decryptionKeyAlertMessage", nil) preferredStyle:UIAlertControllerStyleAlert];
    
    [decryptionAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = AMLocalizedString(@"decryptionKey", nil);
        [textField addTarget:self action:@selector(decryptionTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        textField.shouldReturnCompletion = ^BOOL(UITextField *textField) {
            return !textField.text.mnz_isEmpty;
        };
    }];
    
    [decryptionAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [[MEGASdkManager sharedMEGASdkFolder] logout];
        [decryptionAlertController.textFields.firstObject resignFirstResponder];
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [decryptionAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"decrypt", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *linkString;
        NSString *key = decryptionAlertController.textFields.firstObject.text;
        if ([[key substringToIndex:1] isEqualToString:@"!"]) {
            linkString = self.publicLinkString;
        } else {
            linkString = [self.publicLinkString stringByAppendingString:@"!"];
        }
        linkString = [linkString stringByAppendingString:key];
        
        isValidatingDecryptionKey = YES;
        
        [[MEGASdkManager sharedMEGASdkFolder] loginToFolderLink:linkString delegate:self];
    }]];
    
    decryptionAlertController.actions.lastObject.enabled = NO;
    
    [self presentViewController:decryptionAlertController animated:YES completion:nil];
}

- (void)showDecryptionKeyNotValidAlert {
    isValidatingDecryptionKey = NO;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"decryptionKeyNotValid", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self showDecryptionAlert];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)navigateToNodeWithBase64Handle:(NSString *)base64Handle {
    if (self.isFolderRootNode) {
        // Push folders to go to the selected subfolder:
        MEGANode *targetNode = [[MEGASdkManager sharedMEGASdkFolder] nodeForHandle:[MEGASdk handleForBase64Handle:base64Handle]];
        if (targetNode) {
            MEGANode *tempNode = targetNode;
            NSMutableArray *nodesToPush = [NSMutableArray new];
            while (tempNode.handle != self.parentNode.handle) {
                [nodesToPush insertObject:tempNode atIndex:0];
                tempNode = [[MEGASdkManager sharedMEGASdkFolder] nodeForHandle:tempNode.parentHandle];
            }
            
            for (MEGANode *node in nodesToPush) {
                if (node.type == MEGANodeTypeFolder) {
                    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Links" bundle:nil];
                    FolderLinkViewController *folderLinkVC = [storyboard instantiateViewControllerWithIdentifier:@"FolderLinkViewControllerID"];
                    [folderLinkVC setParentNode:node];
                    [folderLinkVC setIsFolderRootNode:NO];
                    folderLinkVC.publicLinkString = self.publicLinkString;
                    [self.navigationController pushViewController:folderLinkVC animated:NO];

                } else {
                    if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
                        [self presentMediaNode:node];
                    } else {
                        [node mnz_openNodeInNavigationController:self.navigationController folderLink:YES];
                    }
                }
            }
        }
    }
}

- (void)decryptionTextFieldDidChange:(UITextField *)textField {
    UIAlertController *decryptionAlertController = (UIAlertController *)self.presentedViewController;
    if (decryptionAlertController) {
        UIAlertAction *okAction = decryptionAlertController.actions.lastObject;
        okAction.enabled = !textField.text.mnz_isEmpty;
    }
}

- (void)presentMediaNode:(MEGANode *)node {
    MEGANode *parentNode = [[MEGASdkManager sharedMEGASdkFolder] nodeForHandle:node.parentHandle];
    MEGANodeList *nodeList = [[MEGASdkManager sharedMEGASdkFolder] childrenForParent:parentNode];
    NSMutableArray<MEGANode *> *mediaNodesArray = [nodeList mnz_mediaNodesMutableArrayFromNodeList];
    
    MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:[MEGASdkManager sharedMEGASdkFolder] displayMode:DisplayModeSharedItem presentingNode:node preferredIndex:0];
    
    [self.navigationController presentViewController:photoBrowserVC animated:YES completion:nil];
}

#pragma mark - IBActions

- (IBAction)cancelAction:(UIBarButtonItem *)sender {
    [MEGALinkManager resetUtilsForLinksWithoutSession];
    
    [[MEGASdkManager sharedMEGASdkFolder] logout];
    
    [SVProgressHUD dismiss];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)moreAction:(UIBarButtonItem *)sender {
    if (self.tableView.isEditing) {
        [self setEditing:NO animated:YES];
        return;
    }
    
    CustomActionViewController *actionController = [[CustomActionViewController alloc] init];
    actionController.node = self.parentNode;
    actionController.displayMode = DisplayModeFolderLink;
    actionController.actionDelegate = self;
    actionController.actionSender = sender;
    
    if ([[UIDevice currentDevice] iPadDevice]) {
        actionController.modalPresentationStyle = UIModalPresentationPopover;
        actionController.popoverPresentationController.delegate = actionController;
        actionController.popoverPresentationController.barButtonItem = sender;
    } else {
        actionController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    [self presentViewController:actionController animated:YES completion:nil];
}

- (IBAction)editAction:(UIBarButtonItem *)sender {
    BOOL enableEditing = !self.tableView.isEditing;
    [self setEditing:enableEditing animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    [_tableView setEditing:editing animated:YES];
    
    [self setToolbarButtonsEnabled:!editing];
    
    if (editing) {
        self.moreBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
        self.moreBarButtonItem.image = nil;

        [self.navigationItem setLeftBarButtonItem:_selectAllBarButtonItem];
    } else {
        self.moreBarButtonItem.title = nil;
        self.moreBarButtonItem.image = [UIImage imageNamed:@"moreSelected"];

        [self setAllNodesSelected:NO];
        _selectedNodesArray = nil;

        if (self.isFolderRootNode) {
            [self.navigationItem setLeftBarButtonItem:_closeBarButtonItem];
        } else {
            [self.navigationItem setLeftBarButtonItem:nil];
        }
    }
    
    if (!_selectedNodesArray) {
        _selectedNodesArray = [NSMutableArray new];
    }
}

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [_selectedNodesArray removeAllObjects];
    
    if (![self areAllNodesSelected]) {
        MEGANode *node = nil;
        NSInteger nodeListSize = [[_nodeList size] integerValue];
        for (NSInteger i = 0; i < nodeListSize; i++) {
            node = [_nodeList nodeAtIndex:i];
            [_selectedNodesArray addObject:node];
        }
        
        [self setAllNodesSelected:YES];
    } else {
        [self setAllNodesSelected:NO];
    }
    
    (self.selectedNodesArray.count == 0) ? [self setToolbarButtonsEnabled:NO] : [self setToolbarButtonsEnabled:YES];
    
    [_tableView reloadData];
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    
    MEGANode *node = self.searchController.isActive ? [self.searchNodesArray objectAtIndex:indexPath.row] : [self.nodeList nodeAtIndex:indexPath.row];
        
    CustomActionViewController *actionController = [[CustomActionViewController alloc] init];
    actionController.node = node;
    actionController.displayMode = DisplayModeFolderLink;
    actionController.actionDelegate = self;
    actionController.actionSender = sender;
    
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
    //TODO: If documents have been opened for preview and the user download the folder link after that, move the dowloaded documents to Offline and avoid re-downloading.
    if (self.selectedNodesArray.count != 0) {
        for (MEGANode *node in _selectedNodesArray) {
            if (![Helper isFreeSpaceEnoughToDownloadNode:node isFolderLink:YES]) {
                [self setEditing:NO animated:YES];
                return;
            }
        }
    } else {
        if (![Helper isFreeSpaceEnoughToDownloadNode:_parentNode isFolderLink:YES]) {
            return;
        }
    }
    
    if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionV3"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            if ([UIApplication.sharedApplication.keyWindow.rootViewController isKindOfClass:MainTabBarController.class]) {
                MainTabBarController *mainTBC = (MainTabBarController *)UIApplication.sharedApplication.keyWindow.rootViewController;
                [mainTBC showOffline];
            }
            
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
            
            if (self.selectedNodesArray.count != 0) {
                for (MEGANode *node in self.selectedNodesArray) {
                    [Helper downloadNode:node folderPath:[Helper relativePathForOffline] isFolderLink:YES shouldOverwrite:NO];
                }
            } else {
                [Helper downloadNode:self.parentNode folderPath:[Helper relativePathForOffline] isFolderLink:YES shouldOverwrite:NO];
            }
        }];
    } else {
        if (self.selectedNodesArray.count != 0) {
            [MEGALinkManager.nodesFromLinkMutableArray addObjectsFromArray:self.selectedNodesArray];
        } else {
            [MEGALinkManager.nodesFromLinkMutableArray addObject:self.parentNode];
        }
        MEGALinkManager.selectedOption = LinkOptionDownloadFolderOrNodes;
        
        LoginViewController *loginVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"LoginViewControllerID"];
        [self.navigationController pushViewController:loginVC animated:YES];
    }
}

- (IBAction)importAction:(UIBarButtonItem *)sender {
    if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionV3"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
            BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
            [browserVC setBrowserAction:BrowserActionImportFromFolderLink];
            if (self.selectedNodesArray.count != 0) {
                browserVC.selectedNodesArray = [NSArray arrayWithArray:_selectedNodesArray];
            } else {
                if (self.parentNode == nil) {
                    return;
                }
                browserVC.selectedNodesArray = [NSArray arrayWithObject:self.parentNode];
            }
            
            [UIApplication.mnz_presentingViewController presentViewController:navigationController animated:YES completion:nil];
        }];
    } else {
        if (self.selectedNodesArray.count != 0) {
            [MEGALinkManager.nodesFromLinkMutableArray addObjectsFromArray:self.selectedNodesArray];
        } else {
            if (self.parentNode == nil) {
                return;
            }
            [MEGALinkManager.nodesFromLinkMutableArray addObject:self.parentNode];
        }
        MEGALinkManager.selectedOption = LinkOptionImportFolderOrNodes;
        
        LoginViewController *loginVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"LoginViewControllerID"];
        [self.navigationController pushViewController:loginVC animated:YES];
    }
    
    return;
}

- (void)openNode:(MEGANode *)node {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
            [self presentMediaNode:node];
        } else {
            [node mnz_openNodeInNavigationController:self.navigationController folderLink:YES];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            numberOfRows = self.searchNodesArray.count;
        } else {
            if (isFolderLinkNotValid) {
                numberOfRows = 0;
            } else {
                numberOfRows = self.nodeList.size.integerValue;
            }
        }
    }
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = self.searchController.isActive ? [self.searchNodesArray objectAtIndex:indexPath.row] : [self.nodeList nodeAtIndex:indexPath.row];
    
    NodeTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"nodeCell" forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[NodeTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"nodeCell"];
    }
    
    if (node.isFile) {
        if (node.hasThumbnail) {
            [Helper thumbnailForNode:node api:[MEGASdkManager sharedMEGASdkFolder] cell:cell];
        } else {
            [cell.thumbnailImageView mnz_imageForNode:node];
        }
        
        cell.infoLabel.text = [Helper sizeAndDateForNode:node api:[MEGASdkManager sharedMEGASdkFolder]];
        
    } else if (node.isFolder) {
        [cell.thumbnailImageView mnz_imageForNode:node];
        
        cell.infoLabel.text = [Helper filesAndFoldersInFolderNode:node api:[MEGASdkManager sharedMEGASdkFolder]];
    }
    
    cell.nameLabel.text = node.name;
    
    cell.node = node;
    
    if (tableView.isEditing) {
        for (MEGANode *n in _selectedNodesArray) {
            if (n.handle == node.handle) {
                [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
    
    if (@available(iOS 11.0, *)) {
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        cell.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = self.searchController.isActive ? [self.searchNodesArray objectAtIndex:indexPath.row] : [self.nodeList nodeAtIndex:indexPath.row];
    
    if (tableView.isEditing) {
        [_selectedNodesArray addObject:node];
        
        [self setToolbarButtonsEnabled:YES];
        
        if ([_selectedNodesArray count] == [_nodeList.size integerValue]) {
            [self setAllNodesSelected:YES];
        } else {
            [self setAllNodesSelected:NO];
        }
        
        return;
    }

    switch ([node type]) {
        case MEGANodeTypeFolder: {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Links" bundle:nil];
            FolderLinkViewController *folderLinkVC = [storyboard instantiateViewControllerWithIdentifier:@"FolderLinkViewControllerID"];
            [folderLinkVC setParentNode:node];
            [folderLinkVC setIsFolderRootNode:NO];
            folderLinkVC.publicLinkString = self.publicLinkString;
            [self.navigationController pushViewController:folderLinkVC animated:YES];
            break;
        }

        case MEGANodeTypeFile: {
            if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
                [self presentMediaNode:node];
            } else {
                [node mnz_openNodeInNavigationController:self.navigationController folderLink:YES];
            }
            break;
        }
        
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [_nodeList nodeAtIndex:indexPath.row];
    
    if (tableView.isEditing) {
        NSMutableArray *tempArray = [_selectedNodesArray copy];
        for (MEGANode *n in tempArray) {
            if (n.handle == node.handle) {
                [_selectedNodesArray removeObject:n];
            }
        }
        
        (self.selectedNodesArray.count == 0) ? [self setToolbarButtonsEnabled:NO] : [self setToolbarButtonsEnabled:YES];
        
        [self setAllNodesSelected:NO];
        
        return;
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchNodesArray = nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if ([searchString isEqualToString:@""]) {
        self.searchNodesArray = self.nodesArray;
    } else {
        NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF.name contains[c] %@", searchString];
        self.searchNodesArray = [self.nodesArray filteredArrayUsingPredicate:resultPredicate];
    }
    [self.tableView reloadData];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [longPressGestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
        
        if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section]) {
            return;
        }
        
        if (self.isEditing) {
            // Only stop editing if long pressed over a cell that is the only one selected or when selected none
            if (self.selectedNodesArray.count == 0) {
                [self setEditing:NO animated:YES];
            }
            if (self.selectedNodesArray.count == 1) {
                MEGANode *nodeSelected = self.selectedNodesArray.firstObject;
                MEGANode *nodePressed = self.searchController.isActive ? [self.searchNodesArray objectAtIndex:indexPath.row] : [self.nodeList nodeAtIndex:indexPath.row];
                if (nodeSelected.handle == nodePressed.handle) {
                    [self setEditing:NO animated:YES];
                }
            }
        } else {
            [self setEditing:YES animated:YES];
            [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text;
    if ([MEGAReachabilityManager isReachable]) {
        if (!isFetchNodesDone && self.isFolderRootNode) {
            if (isFolderLinkNotValid) {
                text = AMLocalizedString(@"linkNotValid", nil);
            } else {
                text = @"";
            }
        } else {
            if (self.searchController.isActive) {
                text = AMLocalizedString(@"noResults", nil);
            } else {
                text = AMLocalizedString(@"emptyFolder", @"Title shown when a folder doesn't have any files");
            }
        }
    } else {
        text = AMLocalizedString(@"noInternetConnection",  @"No Internet Connection");
    }
    
    return [[NSAttributedString alloc] initWithString:text attributes:[Helper titleAttributesForEmptyState]];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    
    if ([MEGAReachabilityManager isReachable]) {
        if (!isFetchNodesDone && self.isFolderRootNode) {
            if (isFolderLinkNotValid) {
                return [UIImage imageNamed:@"invalidFolderLink"];
            }
            return nil;
        }
        
         if (self.searchController.isActive) {
             return [UIImage imageNamed:@"searchEmptyState"];
         }
        
        return [UIImage imageNamed:@"folderEmptyState"];
    } else {
        return [UIImage imageNamed:@"noInternetEmptyState"];
    }
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    if ([MEGAReachabilityManager isReachable]) {
        if (!isFetchNodesDone && self.isFolderRootNode && !isFolderLinkNotValid) {
            return nil;
        }
    }
    
    return [UIColor whiteColor];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:self.searchController.isActive];
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    [self reloadUI];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    switch ([request type]) {
        case MEGARequestTypeLogin: {
            isFolderLinkNotValid = NO;
            break;
        }
            
        case MEGARequestTypeFetchNodes: {
            [SVProgressHUD show];
            break;
        }
            
        default:
            break;
    }
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if (error.type) {
        switch (error.type) {
            case MEGAErrorTypeApiEArgs: {
                if (request.type == MEGARequestTypeLogin) {
                    if (isValidatingDecryptionKey) { //If the user have written the key
                        [self showDecryptionKeyNotValidAlert];
                    } else {
                        [self showLinkNotValid];
                    }
                } else if (request.type == MEGARequestTypeFetchNodes) {
                    [self showUnavailableLinkView];
                }
                break;
            }
                
            case MEGAErrorTypeApiENoent: {
                if (request.type == MEGARequestTypeFetchNodes) {
                    [self showLinkNotValid];
                }
                break;
            }
                
            case MEGAErrorTypeApiEIncomplete: {
                [self showDecryptionAlert];
                break;
            }
                
            default: {
                if (request.type == MEGARequestTypeLogin) {
                    [self showUnavailableLinkView];
                } else if (request.type == MEGARequestTypeFetchNodes) {
                    [api logout];
                    [self showUnavailableLinkView];
                }
                break;
            }
        }
        
        return;
    }
    
    switch (request.type) {
        case MEGARequestTypeLogin: {
            isLoginDone = YES;
            isFetchNodesDone = NO;
            [api fetchNodes];
            break;
        }
            
        case MEGARequestTypeFetchNodes: {
            
            if (request.flag) { //Invalid key
                [api logout];
                
                [SVProgressHUD dismiss];
                
                if (isValidatingDecryptionKey) { //Link without key, after entering a bad one
                    [self showDecryptionKeyNotValidAlert];
                } else { //Link with invalid key
                    [self showLinkNotValid];
                }
                return;
            }
            
            isFetchNodesDone = YES;
            
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLongLong:request.nodeHandle] forKey:@"kLastPublicHandleAccessed"];
            [[NSUserDefaults standardUserDefaults] setDouble:[NSDate date].timeIntervalSince1970 forKey:@"kLastPublicTimestampAccessed"];
            
            [self reloadUI];
            
            NSArray *componentsArray = [self.publicLinkString componentsSeparatedByString:@"!"];
            if (componentsArray.count == 4) {
                [self navigateToNodeWithBase64Handle:componentsArray.lastObject];
            }
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TransfersPaused"]) {
                [api pauseTransfers:YES];
            }
            [SVProgressHUD dismiss];
            break;
        }
            
        case MEGARequestTypeLogout: {
            isLoginDone = NO;
            isFetchNodesDone = NO;
            break;
        }
            
        case MEGARequestTypeGetAttrFile: {
            for (NodeTableViewCell *nodeTableViewCell in self.tableView.visibleCells) {
                if (request.nodeHandle == nodeTableViewCell.node.handle) {
                    MEGANode *node = [api nodeForHandle:request.nodeHandle];
                    [Helper setThumbnailForNode:node api:api cell:nodeTableViewCell reindexNode:NO];
                }
            }
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - CustomActionViewControllerDelegate

- (void)performAction:(MegaNodeActionType)action inNode:(MEGANode *)node fromSender:(id)sender{
    switch (action) {
        case MegaNodeActionTypeDownload:
            self.selectedNodesArray = [NSMutableArray arrayWithObject:node];
            [self downloadAction:nil];
            break;
            
        case MegaNodeActionTypeOpen:
            [self openNode:node];
            break;
            
        case MegaNodeActionTypeImport:
            self.selectedNodesArray = [NSMutableArray arrayWithObject:node];
            [self importAction:nil];
            break;
            
        case MegaNodeActionTypeSelect: {
            BOOL enableEditing = !self.tableView.isEditing;
            [self setEditing:enableEditing animated:YES];
            break;
        }
            
        case MegaNodeActionTypeShare: {
            NSString *link = self.linkEncryptedString ? self.linkEncryptedString : self.publicLinkString;
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[link] applicationActivities:nil];
            activityVC.popoverPresentationController.barButtonItem = sender;
            [self presentViewController:activityVC animated:YES completion:nil];
            break;
        }
            
        case MegaNodeActionTypeSaveToPhotos:
            [node mnz_saveToPhotosWithApi:[MEGASdkManager sharedMEGASdkFolder]];
            break;
            
        default:
            break;
    }
}

@end
