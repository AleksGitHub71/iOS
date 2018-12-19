
#import "ChatAttachedNodesViewController.h"

#import "SVProgressHUD.h"

#import "BrowserViewController.h"
#import "DisplayMode.h"
#import "Helper.h"
#import "MEGAChatMessage+MNZCategory.h"
#import "MEGANavigationController.h"
#import "MEGANode+MNZCategory.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGAPhotoBrowserViewController.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "NodeTableViewCell.h"
#import "NSString+MNZCategory.h"
#import "MEGAGetThumbnailRequestDelegate.h"
#import "UIImageView+MNZCategory.h"

@interface ChatAttachedNodesViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSMutableArray *selectedNodesMutableArray;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *importBarButtonItem;

@end

@implementation ChatAttachedNodesViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupAttachedNodes];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private

- (void)setupAttachedNodes {
    self.selectedNodesMutableArray = [[NSMutableArray alloc] init];
    
    self.backBarButtonItem.image = self.backBarButtonItem.image.imageFlippedForRightToLeftLayoutDirection;
    self.navigationItem.leftBarButtonItem = self.backBarButtonItem;
    self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
    self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem];
    
    self.downloadBarButtonItem.title = AMLocalizedString(@"saveForOffline", @"List option shown on the details of a file or folder");
    [self.downloadBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:[UIFont mnz_SFUIRegularWithSize:17.0f], NSForegroundColorAttributeName:UIColor.mnz_redMain} forState:UIControlStateNormal];
    self.importBarButtonItem.title = AMLocalizedString(@"import", @"Button title that triggers the importing link action");
    [self.importBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:[UIFont mnz_SFUIMediumWithSize:17.0f], NSForegroundColorAttributeName:UIColor.mnz_redMain} forState:UIControlStateNormal];
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSString *myUserHandleString = [NSString stringWithFormat:@"%llu", [[MEGASdkManager sharedMEGAChatSdk] myUserHandle]];
    if ([self.message.senderId isEqualToString:myUserHandleString]) {
        [self setToolbarItems:@[flexibleItem, self.downloadBarButtonItem]];
    } else {
        [self setToolbarItems:@[self.downloadBarButtonItem, flexibleItem, self.importBarButtonItem]];
    }
}

- (void)reloadUI {
    [self setNavigationBarTitle];
    
    [self setNavigationBarButtonItemsEnabled:[MEGAReachabilityManager isReachable]];
    
    [self.tableView reloadData];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setNavigationBarButtonItemsEnabled:boolValue];
    
    boolValue ? [self reloadUI] : [self.tableView reloadData];
}

- (void)setNavigationBarButtonItemsEnabled:(BOOL)boolValue {
    self.editBarButtonItem.enabled = boolValue;
}

- (void)setNavigationBarTitle {
    [self updatePromptTitle];
    
    NSString *navigationTitle = AMLocalizedString(@"attachedXFiles", @"A summary message when a user has attached many files at once into the chat. Please keep %s as it will be replaced at runtime with the number of files.");
    navigationTitle = [navigationTitle stringByReplacingOccurrencesOfString:@"%s" withString:self.message.nodeList.size.stringValue];
    self.navigationItem.title = navigationTitle;
}

- (void)updatePromptTitle {
    if (self.tableView.isEditing) {
        NSNumber *selectedNodesCount = [NSNumber numberWithUnsignedInteger:self.selectedNodesMutableArray.count];
        self.navigationItem.prompt = [self titleForPromptWithCountOfNodes:selectedNodesCount];
    } else {
        self.navigationItem.prompt = nil;
    }
}

- (NSString *)titleForPromptWithCountOfNodes:(NSNumber *)count {
    NSString *promptString;
    if (count.unsignedIntegerValue == 0) {
        promptString = AMLocalizedString(@"select", @"Button that allows you to select a given folder");
    } else if (count.unsignedIntegerValue == 1) {
        promptString = AMLocalizedString(@"oneItemSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected one photo");
        promptString = [promptString stringByReplacingOccurrencesOfString:@"%lu" withString:count.stringValue];
    } else {
        promptString = AMLocalizedString(@"itemsSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected more than one photo");
        promptString = [promptString stringByReplacingOccurrencesOfString:@"%lu" withString:count.stringValue];
    }
    
    return promptString;
}

- (void)setTableViewEditing:(BOOL)editing animated:(BOOL)animated {
    [self.tableView setEditing:editing animated:animated];
    
    if (editing) {
        self.editBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
        [self setToolbarItemsEnabled:NO];
    } else {
        self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
        [self setToolbarItemsEnabled:YES];
        
        [self.selectedNodesMutableArray removeAllObjects];
    }
}

- (void)downloadSelectedNodes {
    for (MEGANode *node in self.selectedNodesMutableArray) {
        if (![Helper isFreeSpaceEnoughToDownloadNode:node isFolderLink:YES]) {
            [self setEditing:NO animated:YES];
            return;
        }
    }
    
    [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
    
    if (self.tableView.isEditing) {
        for (MEGANode *node in self.selectedNodesMutableArray) {
            [Helper downloadNode:node folderPath:[Helper relativePathForOffline] isFolderLink:NO  shouldOverwrite:NO];
        }
    }
}

- (void)setToolbarItemsEnabled:(BOOL)boolValue {
    self.downloadBarButtonItem.enabled = boolValue;
    self.importBarButtonItem.enabled = boolValue;
}

#pragma mark - IBActions

- (IBAction)backAction:(UIBarButtonItem *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)editAction:(UIBarButtonItem *)sender {
    BOOL enableEditing = !self.tableView.isEditing;
    
    [self setTableViewEditing:enableEditing animated:YES];
    
    self.navigationItem.leftBarButtonItem = enableEditing ? self.selectAllBarButtonItem : self.backBarButtonItem;
    [self updatePromptTitle];
    [self.navigationController setToolbarHidden:!enableEditing animated:YES];
}

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    NSUInteger selectedNodesCount = self.selectedNodesMutableArray.count;
    if (self.message.nodeList.size.unsignedIntegerValue != selectedNodesCount) {
        [self.selectedNodesMutableArray removeAllObjects];
        
        NSArray *nodesArray = [self.message.nodeList mnz_nodesArrayFromNodeList];
        self.selectedNodesMutableArray = nodesArray.mutableCopy;
    } else {
        [self.selectedNodesMutableArray removeAllObjects];
    }
    
    [self updatePromptTitle];
    
    BOOL toolbarItemsEnabled = (self.selectedNodesMutableArray.count == 0) ? NO : YES;
    [self setToolbarItemsEnabled:toolbarItemsEnabled];
    
    [self.tableView reloadData];
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    if (self.tableView.isEditing) {
        for (MEGANode *node in self.selectedNodesMutableArray) {
            if (![Helper isFreeSpaceEnoughToDownloadNode:node isFolderLink:YES]) {
                [self setEditing:NO animated:YES];
                return;
            }
        }
        
        for (MEGANode *node in self.selectedNodesMutableArray) {
            [Helper downloadNode:node folderPath:[Helper relativePathForOffline] isFolderLink:NO shouldOverwrite:NO];
        }
    }
    
    [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)importAction:(UIBarButtonItem *)sender {
    MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
    BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
    browserVC.browserAction = BrowserActionImport;
    if (self.tableView.isEditing) {
        browserVC.selectedNodesArray = self.selectedNodesMutableArray.copy;
    } else {
        NSArray *nodesArray = [self.message.nodeList mnz_nodesArrayFromNodeList];
        browserVC.selectedNodesArray = nodesArray.mutableCopy;
    }
    
    [self.navigationController presentViewController:navigationController animated:YES completion:^{
        [self.navigationController popViewControllerAnimated:NO];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if ([MEGAReachabilityManager isReachable]) {
        numberOfRows = self.message.nodeList.size.unsignedIntegerValue;
    }
    
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *currentNode = [self.message.nodeList nodeAtIndex:indexPath.row];
    
    NodeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NodeTableViewCellID" forIndexPath:indexPath];
    
    cell.nameLabel.text = currentNode.name;
    cell.infoLabel.text = [Helper sizeAndDateForNode:currentNode api:[MEGASdkManager sharedMEGASdk]];
    
    if (self.tableView.isEditing) {
        NSUInteger selectedNodesCount = self.selectedNodesMutableArray.count;
        for (NSUInteger i = 0; i < selectedNodesCount; i++) {
            MEGANode *node = [self.selectedNodesMutableArray objectAtIndex:i];
            if (currentNode.handle == node.handle) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
    
    if (currentNode.hasThumbnail) {
        NSString *thumbnailFilePath = [Helper pathForNode:currentNode inSharedSandboxCacheDirectory:@"thumbnailsV3"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
            cell.thumbnailImageView.image = [UIImage imageWithContentsOfFile:thumbnailFilePath];
        } else {
            MEGAGetThumbnailRequestDelegate *getThumbnailRequestDelegate = [[MEGAGetThumbnailRequestDelegate alloc] initWithCompletion:^(MEGARequest *request){
                cell.thumbnailImageView.image = [UIImage imageWithContentsOfFile:request.file];
            }];
            [[MEGASdkManager sharedMEGASdk] getThumbnailNode:currentNode destinationFilePath:thumbnailFilePath delegate:getThumbnailRequestDelegate];
            [cell.thumbnailImageView mnz_imageForNode:currentNode];
        }
    } else {
        [cell.thumbnailImageView mnz_imageForNode:currentNode];
    }
    
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.clearColor;
    cell.selectedBackgroundView = view;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self.message.nodeList nodeAtIndex:indexPath.row];
    
    if (tableView.isEditing) {
        [self.selectedNodesMutableArray addObject:node];
        
        [self updatePromptTitle];
        
        BOOL toolbarItemsEnabled = (self.selectedNodesMutableArray.count == 0) ? NO : YES;
        [self setToolbarItemsEnabled:toolbarItemsEnabled];
        
        return;
    } else {
        if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
            NSMutableArray<MEGANode *> *mediaNodesArray = [self.message.nodeList mnz_mediaNodesMutableArrayFromNodeList];
            
            MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:[MEGASdkManager sharedMEGASdk] displayMode:DisplayModeSharedItem presentingNode:node preferredIndex:0];
            
            [self.navigationController presentViewController:photoBrowserVC animated:YES completion:nil];
        } else {
            [node mnz_openNodeInNavigationController:self.navigationController folderLink:NO];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing) {
        MEGANode *nodeDeselected = [self.message.nodeList nodeAtIndex:indexPath.row];
        NSMutableArray *tempArray = self.selectedNodesMutableArray.copy;
        NSUInteger count = tempArray.count;
        for (NSUInteger i = 0; i < count; i++) {
            MEGANode *node = [tempArray objectAtIndex:i];
            if (nodeDeselected.handle == node.handle) {
                [self.selectedNodesMutableArray removeObject:node];
            }
        }
        
        [self updatePromptTitle];
        
        BOOL toolbarItemsEnabled = (self.selectedNodesMutableArray.count == 0) ? NO : YES;
        [self setToolbarItemsEnabled:toolbarItemsEnabled];
    }
}

@end
