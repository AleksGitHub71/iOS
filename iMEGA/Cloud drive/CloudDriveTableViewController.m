#import "CloudDriveTableViewController.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>

#import "MWPhotoBrowser.h"
#import "SVProgressHUD.h"
#import "UIScrollView+EmptyDataSet.h"
#import "CTAssetsPickerController.h"

#import "NSFileManager+MNZCategory.h"
#import "NSMutableAttributedString+MNZCategory.h"
#import "NSString+MNZCategory.h"

#import "Helper.h"
#import "MEGAAssetOperation.h"
#import "MEGAAVViewController.h"
#import "MEGANavigationController.h"
#import "MEGAQLPreviewController.h"
#import "MEGAReachabilityManager.h"
#import "MEGAStore.h"

#import "BrowserViewController.h"
#import "DetailsNodeInfoViewController.h"
#import "NodeTableViewCell.h"
#import "PhotosViewController.h"
#import "PreviewDocumentViewController.h"
#import "SortByTableViewController.h"

@interface CloudDriveTableViewController () <UIActionSheetDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UISearchDisplayDelegate, UIDocumentPickerDelegate, UIDocumentMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGADelegate, CTAssetsPickerControllerDelegate> {

    UIAlertView *folderAlertView;
    UIAlertView *removeAlertView;
    
    NSUInteger remainingOperations;
    
    NSMutableArray *matchSearchNodes;
    
    BOOL allNodesSelected;
    BOOL isSwipeEditing;
    
    MEGAShareType lowShareType; //Control the actions allowed for node/nodes selected
    
    NSUInteger numFilesAction, numFoldersAction;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *sortByBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *moveBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *carbonCopyBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteBarButtonItem;

@property (nonatomic, strong) MEGANodeList *nodes;

@property (nonatomic, strong) NSMutableArray *cloudImages;
@property (nonatomic, strong) NSMutableArray *selectedNodesArray;

@property (nonatomic, strong) NSMutableDictionary *nodesIndexPathMutableDictionary;

@end

@implementation CloudDriveTableViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.searchDisplayController.searchResultsTableView.emptyDataSetSource = self;
    self.searchDisplayController.searchResultsTableView.emptyDataSetDelegate = self;
    self.searchDisplayController.searchResultsTableView.tableFooterView = [UIView new];
    [self.searchDisplayController setValue:@"" forKey:@"_noResultsMessage"];
    
    [self.toolbar setFrame:CGRectMake(0, 49, CGRectGetWidth(self.view.frame), 49)];
    
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    switch (self.displayMode) {
        case DisplayModeCloudDrive: {
            if (!self.parentNode) {
                self.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
            }
            
            MEGAShareType accessType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.parentNode];
            
            UIBarButtonItem *negativeSpaceBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
            if ([[UIDevice currentDevice] iPadDevice] || [[UIDevice currentDevice] iPhone6XPlus]) {
                [negativeSpaceBarButtonItem setWidth:-8.0];
            } else {
                [negativeSpaceBarButtonItem setWidth:-4.0];
            }
            
            switch (accessType) {
                case MEGAShareTypeAccessRead: {
                    self.navigationItem.rightBarButtonItems = @[negativeSpaceBarButtonItem, self.editBarButtonItem, self.sortByBarButtonItem];
                    break;
                }
                    
                default: {
                    self.navigationItem.rightBarButtonItems = @[negativeSpaceBarButtonItem, self.editBarButtonItem, self.addBarButtonItem, self.sortByBarButtonItem];
                    break;
                }
            }
            
            break;
        }
            
        case DisplayModeRubbishBin:
            self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem, self.sortByBarButtonItem];
            [self.deleteBarButtonItem setImage:[UIImage imageNamed:@"remove"]];
            [self.toolbar setItems:@[self.downloadBarButtonItem, flexibleItem, self.moveBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.deleteBarButtonItem]];
            break;
        
        default:
            break;
    }
    
    
    MEGAShareType shareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.parentNode];
    
    [self toolbarActionsForShareType:shareType];

    NSString *thumbsDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"thumbnailsV3"];
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
    
    self.nodesIndexPathMutableDictionary = [[NSMutableDictionary alloc] init];
    
    matchSearchNodes = [[NSMutableArray alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] addMEGADelegate:self];
    [[MEGASdkManager sharedMEGASdk] retryPendingConnections];
    
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGADelegate:self];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.tableView.isEditing) {
        self.selectedNodesArray = nil;
        [self setEditing:NO animated:NO];
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] iPhone4X] || [[UIDevice currentDevice] iPhone5X]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.tableView reloadEmptyDataSet];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if ([MEGAReachabilityManager isReachable]) {
        if (tableView == self.searchDisplayController.searchResultsTableView) {
            numberOfRows = [matchSearchNodes count];
        } else {
            numberOfRows = [[self.nodes size] integerValue];
        }
    }
    
    if (numberOfRows == 0) {
        if (tableView == self.searchDisplayController.searchResultsTableView) {
            [self.searchDisplayController.searchResultsTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        } else {
            [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        }
    } else {
        if (tableView == self.searchDisplayController.searchResultsTableView) {
            [self.searchDisplayController.searchResultsTableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
        }
        
        [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    }
    
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MEGANode *node = nil;
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    [self.nodesIndexPathMutableDictionary setObject:indexPath forKey:node.base64Handle];
    
    BOOL isDownloaded = NO;
    
    NodeTableViewCell *cell;
    if ([[Helper downloadingNodes] objectForKey:node.base64Handle] != nil) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"downloadingNodeCell" forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[NodeTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"downloadingNodeCell"];
        }
        
        [cell.downloadingArrowImageView setImage:[UIImage imageNamed:@"downloadQueued"]];
        [cell.infoLabel setText:AMLocalizedString(@"queued", @"Queued")];
    } else {
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"nodeCell" forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[NodeTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"nodeCell"];
        }
        
        NSString *fingerprint = [[MEGASdkManager sharedMEGASdk] fingerprintForNode:node];
        MOOfflineNode *offlineNode = [[MEGAStore shareInstance] fetchOfflineNodeWithFingerprint:fingerprint];
        
        // Check fingerprint, if we download a file with NULL fingerprint, all folders are marked as downloaded because the fingerprinf for folders are NULL
        if (offlineNode && fingerprint) {
            isDownloaded = YES;
        }
        
        cell.infoLabel.text = [Helper sizeAndDateForNode:node api:[MEGASdkManager sharedMEGASdk]];
    }
    
    if ([node isExported]) {
        if (isDownloaded) {
            [cell.upImageView setImage:[UIImage imageNamed:@"linked"]];
            [cell.middleImageView setImage:nil];
            [cell.downImageView setImage:[Helper downloadedArrowImage]];
        } else {
            [cell.upImageView setImage:nil];
            [cell.middleImageView setImage:[UIImage imageNamed:@"linked"]];
            [cell.downImageView setImage:nil];
        }
    } else {
        [cell.upImageView setImage:nil];
        [cell.downImageView setImage:nil];
        
        if (isDownloaded) {
            [cell.middleImageView setImage:[Helper downloadedArrowImage]];
        } else {
            [cell.middleImageView setImage:nil];
        }
    }
    
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor mnz_grayF7F7F7]];
    [cell setSelectedBackgroundView:view];
    [cell setSeparatorInset:UIEdgeInsetsMake(0.0, 60.0, 0.0, 0.0)];
    
    cell.nameLabel.text = [node name];
    
    [cell.thumbnailImageView.layer setCornerRadius:4];
    [cell.thumbnailImageView.layer setMasksToBounds:YES];
    
    [cell.thumbnailPlayImageView setHidden:YES];
    
    if ([node type] == MEGANodeTypeFile) {
        if ([node hasThumbnail]) {
            [Helper thumbnailForNode:node api:[MEGASdkManager sharedMEGASdk] cell:cell];
        } else {
            [cell.thumbnailImageView setImage:[Helper imageForNode:node]];
        }
    } else if ([node type] == MEGANodeTypeFolder) {
        [cell.thumbnailImageView setImage:[Helper imageForNode:node]];
        
        cell.infoLabel.text = [Helper filesAndFoldersInFolderNode:node api:[MEGASdkManager sharedMEGASdk]];
    }
    
    cell.nodeHandle = [node handle];
    
    if (self.isEditing) {
        // Check if selectedNodesArray contains the current node in the tableView
        for (MEGANode *n in self.selectedNodesArray) {
            if ([n handle] == [node handle]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    if (tableView.isEditing) {
        [self.selectedNodesArray addObject:node];
        
        [self toolbarActionsForNodeArray:self.selectedNodesArray];
        
        [self setToolbarActionsEnabled:YES];
        
        if (self.selectedNodesArray.count == self.nodes.size.integerValue) {
            allNodesSelected = YES;
        } else {
            allNodesSelected = NO;
        }
        
        return;
    }
    
    switch ([node type]) {
        case MEGANodeTypeFolder: {
            CloudDriveTableViewController *cdvc = [self.storyboard instantiateViewControllerWithIdentifier:@"CloudDriveID"];
            [cdvc setParentNode:node];
            
            if (self.displayMode == DisplayModeRubbishBin) {
                [cdvc setDisplayMode:self.displayMode];
            }
            
            [self.navigationController pushViewController:cdvc animated:YES];
            break;
        }
            
        case MEGANodeTypeFile: {
            
            NSString *name = [node name];
            CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef _Nonnull)([name pathExtension]), NULL);
            if (UTTypeConformsTo(fileUTI, kUTTypeImage)) {
                
                int offsetIndex = 0;
                self.cloudImages = [NSMutableArray new];
                
                if (tableView == self.searchDisplayController.searchResultsTableView) {
                    for (NSInteger i = 0; i < matchSearchNodes.count; i++) {
                        MEGANode *n = [matchSearchNodes objectAtIndex:i];
                        
                        if (fileUTI) {
                            CFRelease(fileUTI);
                        }
                        
                        fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef _Nonnull)([n.name pathExtension]), NULL);
                        
                        if (UTTypeConformsTo(fileUTI, kUTTypeImage) && [n type] == MEGANodeTypeFile) {
                            MWPhoto *photo = [[MWPhoto alloc] initWithNode:n];
                            [self.cloudImages addObject:photo];
                            if ([n handle] == [node handle]) {
                                offsetIndex = (int)[self.cloudImages count] - 1;
                            }
                        }
                    }
                } else {
                    for (NSInteger i = 0; i < [[self.nodes size] integerValue]; i++) {
                        MEGANode *n = [self.nodes nodeAtIndex:i];
                        
                        if (fileUTI) {
                            CFRelease(fileUTI);
                        }
                        
                        fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef _Nonnull)([n.name pathExtension]), NULL);
                        
                        if (UTTypeConformsTo(fileUTI, kUTTypeImage) && [n type] == MEGANodeTypeFile) {
                            MWPhoto *photo = [[MWPhoto alloc] initWithNode:n];
                            [self.cloudImages addObject:photo];
                            if ([n handle] == [node handle]) {
                                offsetIndex = (int)[self.cloudImages count] - 1;
                            }
                        }
                    }
                }
                
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:self.cloudImages];
                browser.displayActionButton = YES;
                browser.displayNavArrows = YES;
                browser.displaySelectionButtons = NO;
                browser.zoomPhotosToFill = YES;
                browser.alwaysShowControls = NO;
                browser.enableGrid = YES;
                browser.startOnGrid = NO;
                browser.displayMode = self.displayMode;
                
                // Optionally set the current visible photo before displaying
                //    [browser setCurrentPhotoIndex:1];
                
                [self.navigationController pushViewController:browser animated:YES];
                
                [browser showNextPhotoAnimated:YES];
                [browser showPreviousPhotoAnimated:YES];
                [browser setCurrentPhotoIndex:offsetIndex];
            } else {
                MOOfflineNode *offlineNodeExist = [[MEGAStore shareInstance] fetchOfflineNodeWithFingerprint:[[MEGASdkManager sharedMEGASdk] fingerprintForNode:node]];
                
                NSString *previewDocumentPath = nil;
                if (offlineNodeExist) {
                    previewDocumentPath = [[Helper pathForOffline] stringByAppendingPathComponent:offlineNodeExist.localPath];
                } else {
                    NSString *nodeFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[node base64Handle]];                    
                    NSString *tmpFilePath = [nodeFolderPath stringByAppendingPathComponent:node.name];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpFilePath isDirectory:nil]) {
                        previewDocumentPath = tmpFilePath;
                    }
                }

                if (previewDocumentPath) {
                    if (!isMultimedia(node.name.pathExtension)) {
                        MEGAQLPreviewController *previewController = [[MEGAQLPreviewController alloc] initWithFilePath:previewDocumentPath];                       
                        [self presentViewController:previewController animated:YES completion:nil];
                    } else {
                        NSURL *path = [NSURL fileURLWithPath:[[Helper pathForOffline] stringByAppendingString:offlineNodeExist.localPath]];
                        MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithURL:path];
                        [self presentViewController:megaAVViewController animated:YES completion:nil];
                        if (fileUTI) {
                            CFRelease(fileUTI);
                        }
                        return;
                    }
                } else if (UTTypeConformsTo(fileUTI, kUTTypeAudiovisualContent) && [[MEGASdkManager sharedMEGASdk] httpServerStart:YES port:4443]) {
                    MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithNode:node folderLink:NO];
                    [self presentViewController:megaAVViewController animated:YES completion:nil];
                    
                    if (fileUTI) {
                        CFRelease(fileUTI);
                    }
                    return;
                } else {
                    if ([[[[MEGASdkManager sharedMEGASdk] downloadTransfers] size] integerValue] > 0) {
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"documentOpening_alertTitle", nil)
                                                                            message:AMLocalizedString(@"documentOpening_alertMessage", nil)
                                                                           delegate:nil
                                                                  cancelButtonTitle:AMLocalizedString(@"ok", nil)
                                                                  otherButtonTitles:nil, nil];
                        [alertView show];
                    } else {
                        // There isn't enough space in the device for preview the document
                        if (![Helper isFreeSpaceEnoughToDownloadNode:node isFolderLink:NO]) {
                            if (fileUTI) {
                                CFRelease(fileUTI);
                            }
                            return;
                        }
                        
                        PreviewDocumentViewController *previewDocumentVC = [self.storyboard instantiateViewControllerWithIdentifier:@"previewDocumentID"];
                        [previewDocumentVC setNode:node];
                        [previewDocumentVC setApi:[MEGASdkManager sharedMEGASdk]];
                        
                        [self.navigationController pushViewController:previewDocumentVC animated:YES];
                        
                        [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    }
                } 
            }
            
            if (fileUTI) {
                CFRelease(fileUTI);
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row > self.nodes.size.integerValue) {
        return;
    }
    MEGANode *node = [self.nodes nodeAtIndex:indexPath.row];
    
    if (tableView.isEditing) {
        
        //tempArray avoid crash: "was mutated while being enumerated."
        NSMutableArray *tempArray = [self.selectedNodesArray copy];
        for (MEGANode *n in tempArray) {
            if (n.handle == node.handle) {
                [self.selectedNodesArray removeObject:n];
            }
        }
        
        [self toolbarActionsForNodeArray:self.selectedNodesArray];
        
        if (self.selectedNodesArray.count == 0) {
            [self setToolbarActionsEnabled:NO];
        }
        
        allNodesSelected = NO;
        
        return;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    if (self.displayMode == DisplayModeCloudDrive && [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node] < MEGAShareTypeAccessFull) {
        return UITableViewCellEditingStyleNone;
    } else {
        self.selectedNodesArray = [NSMutableArray new];
        [self.selectedNodesArray addObject:node];
        
        [self setToolbarActionsEnabled:YES];
        
        isSwipeEditing = YES;
        
        MEGAShareType shareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node];
        [self toolbarActionsForShareType:shareType];
        
        return UITableViewCellEditingStyleDelete;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node;
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        if (indexPath.row > matchSearchNodes.count) {
            return @"";
        }
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        if (indexPath.row > self.nodes.size.integerValue) {
            return @"";
        }
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    MEGAShareType accessType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node];
    if (accessType >= MEGAShareTypeAccessFull) {
        return AMLocalizedString(@"remove", nil);
    }
    
    return @"";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle==UITableViewCellEditingStyleDelete) {
        MEGANode *node = nil;
        
        if (tableView == self.searchDisplayController.searchResultsTableView) {
            node = [matchSearchNodes objectAtIndex:indexPath.row];
        } else {
            node = [self.nodes nodeAtIndex:indexPath.row];
        }
        remainingOperations = 1;
        
        if ([node isFolder]) {
            numFoldersAction = 1;
            numFilesAction = 0;
        } else {
            numFilesAction = 1;
            numFoldersAction = 0;
        }
        
        MEGAShareType accessType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node];
    
        if (accessType == MEGAShareTypeAccessOwner) {
            if (self.displayMode == DisplayModeCloudDrive) {
                [[MEGASdkManager sharedMEGASdk] moveNode:node newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
            } else { //DisplayModeRubbishBin (Remove)
                [[MEGASdkManager sharedMEGASdk] removeNode:node];
            }
        } if (accessType == MEGAShareTypeAccessFull) { //DisplayModeSharedItem (Move to the Rubbish Bin)
            [[MEGASdkManager sharedMEGASdk] moveNode:node newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending)) {
        return 44.0;
    }
    else {
        return UITableViewAutomaticDimension;
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending)) {
        return 44.0;
    }
    else {
        return UITableViewAutomaticDimension;
    }
}
- (IBAction)editTapped:(UIBarButtonItem *)sender {
    BOOL value = [self.editBarButtonItem.image isEqual:[UIImage imageNamed:@"edit"]];
    [self setEditing:value animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if (editing) {
        [self.editBarButtonItem setImage:[UIImage imageNamed:@"done"]];
        [self.addBarButtonItem setEnabled:NO];
        [self.sortByBarButtonItem setEnabled:NO];
        if (!isSwipeEditing) {
            self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        }
    } else {
        [self.editBarButtonItem setImage:[UIImage imageNamed:@"edit"]];
        allNodesSelected = NO;
        self.selectedNodesArray = nil;
        [self.addBarButtonItem setEnabled:YES];
        [self.sortByBarButtonItem setEnabled:YES];
        self.navigationItem.leftBarButtonItems = @[];
    }
    
    if (!self.selectedNodesArray) {
        self.selectedNodesArray = [NSMutableArray new];
        
        [self setToolbarActionsEnabled:NO];
    }
    
    [self.tabBarController.tabBar addSubview:self.toolbar];
    
    [UIView animateWithDuration:animated ? .33 : 0 animations:^{
        self.toolbar.frame = CGRectMake(0, editing ? 0 : 49 , CGRectGetWidth(self.view.frame), 49);
    }];
    
    isSwipeEditing = NO;
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.parentNode == nil) {
            return nil;
        }
        
        if ([self.searchDisplayController isActive]) {
            text = AMLocalizedString(@"noResults", nil);
        } else {
            switch (self.displayMode) {
                case DisplayModeCloudDrive: {
                    if ([self.parentNode type] == MEGANodeTypeRoot) {
                        return [NSMutableAttributedString mnz_darkenSectionTitleInString:AMLocalizedString(@"cloudDriveEmptyState_title", @"Title shown when your Cloud Drive is empty, when you don't have any files.") sectionTitle:AMLocalizedString(@"cloudDrive", @"Title of the Cloud Drive section")];
                    } else {
                        text = AMLocalizedString(@"emptyFolder", @"Title shown when a folder doesn't have any files");
                    }
                    break;
                }
                    
                case DisplayModeRubbishBin:
                    if ([self.parentNode type] == MEGANodeTypeRubbish) {
                        return [NSMutableAttributedString mnz_darkenSectionTitleInString:AMLocalizedString(@"cloudDriveEmptyState_titleRubbishBin", @"Title shown when your Rubbish Bin is empty.") sectionTitle:AMLocalizedString(@"rubbishBinLabel", @"Title of one of the Settings sections where you can see your MEGA 'Rubbish Bin'")];
                    } else {
                        text = AMLocalizedString(@"emptyFolder", @"Title shown when a folder doesn't have any files");
                    }
                    break;
                    
                default:
                    break;
            }
        }
    } else {
        text = AMLocalizedString(@"noInternetConnection",  @"No Internet Connection");
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont fontWithName:kFont size:18.0], NSForegroundColorAttributeName:[UIColor mnz_gray999999]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    UIImage *image = nil;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.parentNode == nil) {
            return nil;
        }
        
        if ([self.searchDisplayController isActive]) {
            image = [UIImage imageNamed:@"emptySearch"];
        } else {
            switch (self.displayMode) {
                case DisplayModeCloudDrive: {
                    if ([self.parentNode type] == MEGANodeTypeRoot) {
                        image = [UIImage imageNamed:@"emptyCloudDrive"];
                    } else {
                        image = [UIImage imageNamed:@"emptyFolder"];
                    }
                    break;
                }
                    
                case DisplayModeRubbishBin: {
                    if ([self.parentNode type] == MEGANodeTypeRubbish) {
                        image = [UIImage imageNamed:@"emptyRubbishBin"];
                    } else {
                        image = [UIImage imageNamed:@"emptyFolder"];
                    }
                    break;
                }
                    
                default:
                    break;
            }
        }
    } else {
         image = [UIImage imageNamed:@"noInternetConnection"];
    }
    
    return image;
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    MEGAShareType parentShareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.parentNode];
    if (parentShareType == MEGAShareTypeAccessRead) {
        return nil;
    }
    
    NSString *text = @"";
    if ([MEGAReachabilityManager isReachable]) {
        if (self.parentNode == nil) {
            return nil;
        }
        
        switch (self.displayMode) {
            case DisplayModeCloudDrive: {
                if (![self.searchDisplayController isActive]) {
                    text = AMLocalizedString(@"addFiles", nil);
                }
                break;
            }
                
            default:
                text = @"";
                break;
        }
        
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont fontWithName:kFont size:20.0f], NSForegroundColorAttributeName:[UIColor mnz_gray777777]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (UIImage *)buttonBackgroundImageForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    MEGAShareType parentShareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.parentNode];
    if (parentShareType == MEGAShareTypeAccessRead) {
        return nil;
    }
    
    UIEdgeInsets capInsets = [Helper capInsetsForEmptyStateButton];
    UIEdgeInsets rectInsets = [Helper rectInsetsForEmptyStateButton];
    
    return [[[UIImage imageNamed:@"buttonBorder"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch] imageWithAlignmentRectInsets:rectInsets];
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIColor whiteColor];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:[self.searchDisplayController isActive]];
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

#pragma mark - DZNEmptyDataSetDelegate Methods

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    switch (self.displayMode) {
        case DisplayModeCloudDrive: {
            [self optionAdd:_addBarButtonItem];
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        //New folder
        case 0:
            folderAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"newFolder", @"New Folder")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:AMLocalizedString(@"cancel", nil)
                                               otherButtonTitles:AMLocalizedString(@"createFolderButton", @"Create"), nil];
            [folderAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
            [folderAlertView textFieldAtIndex:0].placeholder = AMLocalizedString(@"newFolderMessage", nil);
            folderAlertView.tag = 1;
            [folderAlertView show];
            break;
            
        //Choose
        case 1:
            [self showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            break;
          
        //Capture
        case 2:
            if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    // Will get here on both iOS 7 & 8 even though camera permissions weren't required
                    // until iOS 8. So for iOS 7 permission will always be granted.
                    if (granted) {
                        // Permission has been granted. Use dispatch_async for any UI updating
                        // code because this block may be executed in a thread.
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showImagePickerForSourceType:UIImagePickerControllerSourceTypeCamera];
                        });
                    } else {
                        // Permission has been denied.
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"attention", @"Attention")
                                                                            message:AMLocalizedString(@"cameraPermissions", @"Please give MEGA app permission to access your Camera in your settings app!")
                                                                           delegate:self cancelButtonTitle:(&UIApplicationOpenSettingsURLString ? AMLocalizedString(@"cancel", nil) : AMLocalizedString(@"ok", nil))
                                                                  otherButtonTitles:(&UIApplicationOpenSettingsURLString ? AMLocalizedString(@"ok", nil) : nil), nil];
                            alert.tag = 3;
                            [alert show];
                        });
                    }
                }];
            }

            break;
          
        // Upload a file iOS 8+
        case 3: {
            if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)) {
                UIDocumentMenuViewController *documentMenuViewController = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[(__bridge NSString *) kUTTypeContent,
                                                                                                                                 (__bridge NSString *) kUTTypeData,
                                                                                                                                 (__bridge NSString *) kUTTypePackage,
                                                                                                                                 (@"com.apple.iwork.pages.pages"),
                                                                                                                                 (@"com.apple.iwork.numbers.numbers"),
                                                                                                                                 (@"com.apple.iwork.keynote.key")]
                                                                                                                        inMode:UIDocumentPickerModeImport];
                documentMenuViewController.delegate = self;
                if ([documentMenuViewController respondsToSelector:@selector(popoverPresentationController)]) {
                    documentMenuViewController.popoverPresentationController.barButtonItem = self.addBarButtonItem;
                } else {
                    documentMenuViewController.modalPresentationStyle = UIModalPresentationFormSheet;
                }

                [self presentViewController:documentMenuViewController animated:YES completion:nil];
            }
            break;
        }
            
        default:
            break;
    }
}

//For iOS 7 UIActionSheet color
- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
    for (UIView *subview in actionSheet.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:[UIColor mnz_redD90007] forState:UIControlStateNormal];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    switch ([alertView tag]) {
        case 1: {
            if (buttonIndex == 1) {
                if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                    [[MEGASdkManager sharedMEGASdk] createFolderWithName:[[folderAlertView textFieldAtIndex:0] text] parent:self.parentNode];
                }
            }
            break;
        }
            
        case 2: {
            if (buttonIndex == 1) {
                if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                    remainingOperations = self.selectedNodesArray.count;
                    for (NSInteger i = 0; i < self.selectedNodesArray.count; i++) {
                        if (self.displayMode == DisplayModeCloudDrive || self.displayMode == DisplayModeSharedItem) {
                            [[MEGASdkManager sharedMEGASdk] moveNode:[self.selectedNodesArray objectAtIndex:i] newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
                        } else { //DisplayModeRubbishBin (Remove)
                            [[MEGASdkManager sharedMEGASdk] removeNode:[self.selectedNodesArray objectAtIndex:i]];
                        }
                    }
                }
            }
            break;
        }
        
        // Check camera permissions
        case 3: {
            if (buttonIndex == 1) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            }
        }
            
        default:
            break;
    }
}

#pragma mark - CTAssetsPickerControllerDelegate

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)assets {
    if (assets.count==0) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd' 'HH'.'mm'.'ss"];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:locale];
    
    [self dismissViewControllerAnimated:YES completion:^{
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        if ([operationQueue respondsToSelector:@selector(qualityOfService)]) {
            operationQueue.qualityOfService = NSOperationQualityOfServiceUtility;
        }
        
        operationQueue.maxConcurrentOperationCount = 1;
        
        for (PHAsset *asset in assets) {
            MEGAAssetOperation *assetOperation = [[MEGAAssetOperation alloc] initWithPHAsset:asset parentNode:self.parentNode automatically:NO];
            [operationQueue addOperation:assetOperation];
        }
    }];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd' 'HH'.'mm'.'ss"];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:locale];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie]) {
        NSURL *videoUrl = (NSURL *)[info objectForKey:UIImagePickerControllerMediaURL];
        NSDictionary *attributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[videoUrl path] error:nil];
        NSDate *modificationDate = [attributesDictionary objectForKey:NSFileModificationDate];
        NSString *videoName = [[formatter stringFromDate:modificationDate] stringByAppendingPathExtension:@"mov"];
        NSString *localFilePath = [[[NSFileManager defaultManager] uploadsDirectory] stringByAppendingPathComponent:videoName];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] moveItemAtPath:[videoUrl path] toPath:localFilePath error:&error]) {
            MEGALogError(@"Move item at path failed with error: %@", error);
        }
        
        [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:[localFilePath stringByReplacingOccurrencesOfString:[NSHomeDirectory() stringByAppendingString:@"/"] withString:@""] parent:self.parentNode appData:nil isSourceTemporary:YES];
        
    } else if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeImage]) {
        NSString *filename = [NSString stringWithFormat:@"%@.jpg",[formatter stringFromDate:[NSDate date]]];
        
        NSString *uploadsDirectory = [[NSFileManager defaultManager] uploadsDirectory];
        NSString *imagePath = [uploadsDirectory stringByAppendingPathComponent:filename];
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        [imageData writeToFile:imagePath atomically:YES];
        
        if (isImage(imagePath.pathExtension)) {
            [[MEGASdkManager sharedMEGASdk] createThumbnail:imagePath destinatioPath:[imagePath stringByAppendingString:@"_thumbnail"]];
            [[MEGASdkManager sharedMEGASdk] createPreview:imagePath destinatioPath:[imagePath stringByAppendingString:@"_preview"]];
        }
        [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:[imagePath stringByReplacingOccurrencesOfString:[NSHomeDirectory() stringByAppendingString:@"/"] withString:@""] parent:self.parentNode appData:nil isSourceTemporary:YES];
    }
    [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"uploadStarted_Message", nil)];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    MEGANode *node = [self.selectedNodesArray objectAtIndex:0];
    NSString *nodeName = [textField text];
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextRange *textRange;
    
    switch ([node type]) {
        case MEGANodeTypeFile: {
            if ([[nodeName pathExtension] isEqualToString:@""] && [nodeName isEqualToString:[nodeName stringByDeletingPathExtension]]) { //File without extension
                UITextPosition *end = textField.endOfDocument;
                textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            } else {
                NSRange filenameRange = [nodeName rangeOfString:@"." options:NSBackwardsSearch];
                UITextPosition *beforeExtension = [textField positionFromPosition:beginning offset:filenameRange.location];
                textRange = [textField textRangeFromPosition:beginning  toPosition:beforeExtension];
            }
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        case MEGANodeTypeFolder: {
            UITextPosition *end = textField.endOfDocument;
            textRange = [textField textRangeFromPosition:beginning  toPosition:end];
            [textField setSelectedTextRange:textRange];
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Private

- (void)reloadUI {
    switch (self.displayMode) {
        case DisplayModeCloudDrive: {
            if (!self.parentNode) {
                self.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
            }
            
            if ([self.parentNode type] == MEGANodeTypeRoot) {
                [self.navigationItem setTitle:AMLocalizedString(@"cloudDrive", @"Cloud drive")];
            } else {
                if (!self.parentNode) {
                    [self.navigationItem setTitle:AMLocalizedString(@"cloudDrive", @"Cloud drive")];
                } else {
                    [self.navigationItem setTitle:[self.parentNode name]];
                }
            }
            
            //Sort configuration by default is "default ascending"
            if (![[NSUserDefaults standardUserDefaults] integerForKey:@"SortOrderType"]) {
                [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"SortOrderType"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            MEGASortOrderType sortOrderType = [[NSUserDefaults standardUserDefaults] integerForKey:@"SortOrderType"];
            
            self.nodes = [[MEGASdkManager sharedMEGASdk] childrenForParent:self.parentNode order:sortOrderType];
            
            break;
        }
            
        case DisplayModeRubbishBin: {
            if ([self.parentNode type] == MEGANodeTypeRubbish) {
                [self.navigationItem setTitle:AMLocalizedString(@"rubbishBinLabel", @"Rubbish bin")];
            } else {
                [self.navigationItem setTitle:[self.parentNode name]];
            }
            
            self.nodes = [[MEGASdkManager sharedMEGASdk] childrenForParent:self.parentNode];
            
            break;
        }
            
        default:
            break;
    }
    
    if ([[self.nodes size] unsignedIntegerValue] == 0) {
        [_editBarButtonItem setEnabled:NO];
        
        [self.tableView setTableHeaderView:nil];
        [self.tableView setContentOffset:CGPointZero];
    } else {
        [_editBarButtonItem setEnabled:YES];
        
        [self.tableView setTableHeaderView:self.searchDisplayController.searchBar];
        [self.tableView setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchDisplayController.searchBar.frame))];
    }
    
    [self.tableView reloadData];
}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType {
    if (![[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:NSTemporaryDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        if (sourceType == UIImagePickerControllerSourceTypeCamera) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudNoCamera"] status:AMLocalizedString(@"noCamera", nil)];
        }
        return;
    }
    
    if (sourceType == UIImagePickerControllerSourceTypeCamera || [[[UIDevice currentDevice] systemVersion] floatValue] < 8.0) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
        imagePickerController.sourceType = sourceType;
        imagePickerController.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, (NSString *)kUTTypeImage, nil];
        imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
        imagePickerController.delegate = self;
        
        if ([[UIDevice currentDevice] iPadDevice] && ([imagePickerController sourceType] == UIImagePickerControllerSourceTypePhotoLibrary)) {
            UIPopoverController *popoverController = [[UIPopoverController alloc] initWithContentViewController:imagePickerController];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [popoverController presentPopoverFromBarButtonItem:self.addBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }];
        } else {
            [self.tabBarController presentViewController:imagePickerController animated:YES completion:nil];
        }
    } else {
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    CTAssetsPickerController *picker = [[CTAssetsPickerController alloc] init];
                    picker.delegate = self;
                    
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                        picker.modalPresentationStyle = UIModalPresentationFormSheet;
                    }
                    
                    [self presentViewController:picker animated:YES completion:nil];
                });
            }];
        }
    }
}

- (void)toolbarActionsForShareType:(MEGAShareType )shareType {
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    lowShareType = shareType;
    
    switch (shareType) {
        case MEGAShareTypeAccessRead:
        case MEGAShareTypeAccessReadWrite: {
            [self.moveBarButtonItem setImage:[UIImage imageNamed:@"copy"]];
            [self.toolbar setItems:@[self.downloadBarButtonItem, flexibleItem, self.moveBarButtonItem]];
            break;
        }
            
        case MEGAShareTypeAccessFull: {
            [self.moveBarButtonItem setImage:[UIImage imageNamed:@"copy"]];
            [self.toolbar setItems:@[self.downloadBarButtonItem, flexibleItem, self.moveBarButtonItem, flexibleItem, self.deleteBarButtonItem]];
            break;
        }
            
        case MEGAShareTypeAccessOwner: {
            if (self.displayMode == DisplayModeCloudDrive) {
                [self.toolbar setItems:@[self.downloadBarButtonItem, flexibleItem, self.shareBarButtonItem, flexibleItem, self.moveBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.deleteBarButtonItem]];
            } else { //Rubbish Bin
                [self.toolbar setItems:@[self.downloadBarButtonItem, flexibleItem, self.moveBarButtonItem, flexibleItem, self.carbonCopyBarButtonItem, flexibleItem, self.deleteBarButtonItem]];
            }
            
            break;
        }
            
        default:
            break;
    }
}

- (void)setToolbarActionsEnabled:(BOOL)boolValue {
    self.downloadBarButtonItem.enabled = boolValue;
    [self.shareBarButtonItem setEnabled:((self.selectedNodesArray.count < 100) ? boolValue : NO)];
    self.moveBarButtonItem.enabled = boolValue;
    self.carbonCopyBarButtonItem.enabled = boolValue;
    self.deleteBarButtonItem.enabled = boolValue;
}

- (void)toolbarActionsForNodeArray:(NSArray *)nodeArray {
    if (nodeArray.count == 0) {
        return;
    }
    
    MEGAShareType shareType;
    lowShareType = MEGAShareTypeAccessOwner;
    
    for (MEGANode *n in nodeArray) {
        shareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:n];
        
        if (shareType == MEGAShareTypeAccessRead  && shareType < lowShareType) {
            lowShareType = shareType;
            break;
        }
        
        if (shareType == MEGAShareTypeAccessReadWrite && shareType < lowShareType) {
            lowShareType = shareType;
        }
        
        if (shareType == MEGAShareTypeAccessFull && shareType < lowShareType) {
            lowShareType = shareType;
            
        }
    }
    
    [self toolbarActionsForShareType:lowShareType];
}

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    [self setNavigationBarButtonItemsEnabled:boolValue];
    
    [self.tableView reloadData];
}

- (void)setNavigationBarButtonItemsEnabled:(BOOL)boolValue {
    switch (self.displayMode) {
        case DisplayModeCloudDrive: {
            [self.sortByBarButtonItem setEnabled:boolValue];
            [self.addBarButtonItem setEnabled:boolValue];
            [self.editBarButtonItem setEnabled:boolValue];
            break;
        }
            
        case DisplayModeRubbishBin: {
            [self.sortByBarButtonItem setEnabled:boolValue];
            [self.editBarButtonItem setEnabled:boolValue];
            break;
        }
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPathsArray {
    if ([self.searchDisplayController isActive]) {
        [self.searchDisplayController.searchResultsTableView reloadRowsAtIndexPaths:indexPathsArray withRowAnimation:UITableViewRowAnimationNone];
    } else {
        [self.tableView reloadRowsAtIndexPaths:indexPathsArray withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)endEditingAndReloadSearch { 
    [self.searchDisplayController.searchResultsTableView setEditing:NO animated:YES];
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text];
    [self.searchDisplayController.searchResultsTableView reloadData];
}

#pragma mark - IBActions

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [self.selectedNodesArray removeAllObjects];
    
    if (!allNodesSelected) {
        MEGANode *n = nil;
        NSInteger nodeListSize = [[self.nodes size] integerValue];
        
        for (NSInteger i = 0; i < nodeListSize; i++) {
            n = [self.nodes nodeAtIndex:i];
            [self.selectedNodesArray addObject:n];
        }
        
        allNodesSelected = YES;
        
        [self toolbarActionsForNodeArray:self.selectedNodesArray];
    } else {
        allNodesSelected = NO;
    }
    
    if (self.selectedNodesArray.count == 0) {
        [self setToolbarActionsEnabled:NO];
    } else if (self.selectedNodesArray.count >= 1) {
        [self setToolbarActionsEnabled:YES];
    }
    
    [self.tableView reloadData];
}

- (IBAction)optionAdd:(id)sender {
    UIActionSheet *actionSheet;
    
    //iOS 8+
    if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)) {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:AMLocalizedString(@"cancel", nil)
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:AMLocalizedString(@"newFolder", @"New Folder"), AMLocalizedString(@"choosePhotoVideo", @"Choose"), AMLocalizedString(@"capturePhotoVideo", @"Capture"), AMLocalizedString(@"uploadFrom", @"Option given on the `Add` section to allow the user upload something from another cloud storage provider."), nil];
    } else {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:AMLocalizedString(@"cancel", nil)
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:AMLocalizedString(@"newFolder", @"New Folder"), AMLocalizedString(@"choosePhotoVideo", @"Choose"), AMLocalizedString(@"capturePhotoVideo", @"Capture"), nil];
    }
    
    if ([[UIDevice currentDevice] iPadDevice]) {
        [actionSheet showFromBarButtonItem:self.addBarButtonItem animated:YES];
    } else {
        [actionSheet showFromTabBar:self.tabBarController.tabBar];
    }
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    for (MEGANode *n in self.selectedNodesArray) {
        if (![Helper isFreeSpaceEnoughToDownloadNode:n isFolderLink:NO]) {
            [self setEditing:NO animated:YES];
            return;
        }
    }
    
    [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", nil)];
    
    for (MEGANode *n in self.selectedNodesArray) {
        [Helper downloadNode:n folderPath:[Helper relativePathForOffline] isFolderLink:NO];
    }
    
    [self setEditing:NO animated:YES];
    
    if ([self.searchDisplayController isActive]) {
        [self.searchDisplayController.searchResultsTableView reloadData];
    }
    
    [self.tableView reloadData];
}

- (IBAction)shareAction:(UIBarButtonItem *)sender {
    UIActivityViewController *activityVC = [Helper activityViewControllerForNodes:self.selectedNodesArray button:self.shareBarButtonItem];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (IBAction)moveAction:(UIBarButtonItem *)sender {
    MEGANavigationController *navigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
    [self presentViewController:navigationController animated:YES completion:nil];
    
    BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
    browserVC.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
    browserVC.selectedNodesArray = [NSArray arrayWithArray:self.selectedNodesArray];
    if (lowShareType == MEGAShareTypeAccessOwner) {
        [browserVC setBrowserAction:BrowserActionMove];
    }
    
    if ([self.searchDisplayController isActive]) {
        [self.searchDisplayController.searchResultsTableView reloadData];
    }
}

- (IBAction)deleteAction:(UIBarButtonItem *)sender {
    numFilesAction = 0;
    numFoldersAction = 0;
    for (MEGANode *n in self.selectedNodesArray) {
        if ([n type] == MEGANodeTypeFolder) {
            numFoldersAction++;
        } else {
            numFilesAction++;
        }
    }
    
    if (self.displayMode == DisplayModeCloudDrive) {
        NSString *message;
        if (numFilesAction == 0) {
            if (numFoldersAction == 1) {
                message = AMLocalizedString(@"moveFolderToRubbishBinMessage", nil);
            } else { //folders > 1
                message = [NSString stringWithFormat:AMLocalizedString(@"moveFoldersToRubbishBinMessage", nil), numFoldersAction];
            }
        } else if (numFilesAction == 1) {
            if (numFoldersAction == 0) {
                message = AMLocalizedString(@"moveFileToRubbishBinMessage", nil);
            } else if (numFoldersAction == 1) {
                message = AMLocalizedString(@"moveFileFolderToRubbishBinMessage", nil);
            } else {
                message = [NSString stringWithFormat:AMLocalizedString(@"moveFileFoldersToRubbishBinMessage", nil), numFoldersAction];
            }
        } else {
            if (numFoldersAction == 0) {
                message = [NSString stringWithFormat:AMLocalizedString(@"moveFilesToRubbishBinMessage", nil), numFilesAction];
            } else if (numFoldersAction == 1) {
                message = [NSString stringWithFormat:AMLocalizedString(@"moveFilesFolderToRubbishBinMessage", nil), numFilesAction];
            } else {
                message = AMLocalizedString(@"moveFilesFoldersToRubbishBinMessage", nil);
                NSString *filesString = [NSString stringWithFormat:@"%ld", (long)numFilesAction];
                NSString *foldersString = [NSString stringWithFormat:@"%ld", (long)numFoldersAction];
                message = [message stringByReplacingOccurrencesOfString:@"[A]" withString:filesString];
                message = [message stringByReplacingOccurrencesOfString:@"[B]" withString:foldersString];
            }
        }
        
        removeAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"moveToTheRubbishBin", nil) message:message delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
    } else {
        NSString *message;
        if (numFilesAction == 0) {
            if (numFoldersAction == 1) {
                message = AMLocalizedString(@"removeFolderToRubbishBinMessage", nil);
            } else { //folders > 1
                message = [NSString stringWithFormat:AMLocalizedString(@"removeFoldersToRubbishBinMessage", nil), numFoldersAction];
            }
        } else if (numFilesAction == 1) {
            if (numFoldersAction == 0) {
                message = AMLocalizedString(@"removeFileToRubbishBinMessage", nil);
            } else if (numFoldersAction == 1) {
                message = AMLocalizedString(@"removeFileFolderToRubbishBinMessage", nil);
            } else {
                message = [NSString stringWithFormat:AMLocalizedString(@"removeFileFoldersToRubbishBinMessage", nil), numFoldersAction];
            }
        } else {
            if (numFoldersAction == 0) {
                message = [NSString stringWithFormat:AMLocalizedString(@"removeFilesToRubbishBinMessage", nil), numFilesAction];
            } else if (numFoldersAction == 1) {
                message = [NSString stringWithFormat:AMLocalizedString(@"removeFilesFolderToRubbishBinMessage", nil), numFilesAction];
            } else {
                message = AMLocalizedString(@"removeFilesFoldersToRubbishBinMessage", nil);
                NSString *filesString = [NSString stringWithFormat:@"%ld", (long)numFilesAction];
                NSString *foldersString = [NSString stringWithFormat:@"%ld", (long)numFoldersAction];
                message = [message stringByReplacingOccurrencesOfString:@"[A]" withString:filesString];
                message = [message stringByReplacingOccurrencesOfString:@"[B]" withString:foldersString];
            }
        }
        
        removeAlertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"removeNodeFromRubbishBinTitle", @"Remove node from rubbish bin") message:message delegate:self cancelButtonTitle:AMLocalizedString(@"cancel", nil) otherButtonTitles:AMLocalizedString(@"ok", nil), nil];
    }
    removeAlertView.tag = 2;
    [removeAlertView show];
    
    if ([self.searchDisplayController isActive]) {
        [self.searchDisplayController.searchResultsTableView reloadData];
    }
}

- (IBAction)copyAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        MEGANavigationController *navigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
        browserVC.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
        browserVC.selectedNodesArray = self.selectedNodesArray;
        [browserVC setBrowserAction:BrowserActionCopy];
    }
}

- (IBAction)sortByAction:(UIBarButtonItem *)sender {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Cloud" bundle:nil];
    SortByTableViewController *sortByTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"sortByTableViewControllerID"];
    sortByTableViewController.offline = NO;
    
    MEGANavigationController *megaNavigationController = [[MEGANavigationController alloc] initWithRootViewController:sortByTableViewController];
    
    [self presentViewController:megaNavigationController animated:YES completion:nil];
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    CGPoint buttonPosition;
    NSIndexPath *indexPath;
    MEGANode *node = nil;
    if ([self.searchDisplayController isActive]) {
        buttonPosition = [sender convertPoint:CGPointZero toView:self.searchDisplayController.searchResultsTableView];
        indexPath = [self.searchDisplayController.searchResultsTableView indexPathForRowAtPoint:buttonPosition];
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
        indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    DetailsNodeInfoViewController *detailsNodeInfoVC = [self.storyboard instantiateViewControllerWithIdentifier:@"nodeInfoDetails"];
    [detailsNodeInfoVC setNode:node];
    [detailsNodeInfoVC setDisplayMode:self.displayMode];
    [self.navigationController pushViewController:detailsNodeInfoVC animated:YES];
}

#pragma mark - Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText {
    [matchSearchNodes removeAllObjects];
    MEGANodeList *allNodeList = nil;
    
    allNodeList = [[MEGASdkManager sharedMEGASdk] nodeListSearchForNode:self.parentNode searchString:searchText recursive:YES];
    
    for (NSInteger i = 0; i < [allNodeList.size integerValue]; i++) {
        MEGANode *n = [allNodeList nodeAtIndex:i];
        [matchSearchNodes addObject:n];
    }
    
}

#pragma mark - UISearchDisplayDelegate

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    [self setEditing:NO animated:YES];
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    [self.tableView insertSubview:self.searchDisplayController.searchBar aboveSubview:self.tableView];
    [self setEditing:NO animated:NO];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    [self filterContentForSearchText:searchString];
    
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text];
    
    return YES;
}


#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        NSError *error = nil;
        NSString *localFilePath = [[[NSFileManager defaultManager] uploadsDirectory] stringByAppendingPathComponent:url.lastPathComponent];
        if (![[NSFileManager defaultManager] moveItemAtPath:[url path] toPath:localFilePath error:&error]) {
            MEGALogError(@"Move item at path failed with error: %@", error);
        }
        
        NSString *crcLocal = [[MEGASdkManager sharedMEGASdk] CRCForFilePath:localFilePath];
        MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeByCRC:crcLocal parent:self.parentNode];
        
        // If file doesn't exist in MEGA then upload it
        if (node == nil) {
            [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"uploadStarted_Message", nil)];
            
            if (isImage(localFilePath.pathExtension)) {
                [[MEGASdkManager sharedMEGASdk] createThumbnail:localFilePath destinatioPath:[localFilePath stringByAppendingString:@"_thumbnail"]];
                [[MEGASdkManager sharedMEGASdk] createPreview:localFilePath destinatioPath:[localFilePath stringByAppendingString:@"_preview"]];
            }
            [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:[localFilePath stringByReplacingOccurrencesOfString:[NSHomeDirectory() stringByAppendingString:@"/"] withString:@""] parent:self.parentNode appData:nil isSourceTemporary:YES];
        } else {
            if ([node parentHandle] == [self.parentNode handle]) {
                NSError *error = nil;
                if (![[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&error]) {
                    MEGALogError(@"Remove item at path failed with error: %@", error);
                }
                
                NSString *alertMessage = AMLocalizedString(@"fileExistAlertController_Message", nil);
                
                NSString *localNameString = [NSString stringWithFormat:@"%@", [url lastPathComponent]];
                NSString *megaNameString = [NSString stringWithFormat:@"%@", [node name]];
                alertMessage = [alertMessage stringByReplacingOccurrencesOfString:@"[A]" withString:localNameString];
                alertMessage = [alertMessage stringByReplacingOccurrencesOfString:@"[B]" withString:megaNameString];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alertController = [UIAlertController
                                                          alertControllerWithTitle:nil
                                                          message:alertMessage
                                                          preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alertController animated:YES completion:nil];
                });
            } else {
                [[MEGASdkManager sharedMEGASdk] copyNode:node newParent:self.parentNode newName:url.lastPathComponent];
            }
        }
    }
}

#pragma mark - UIDocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    documentPicker.delegate = self;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    if ([request type] == MEGARequestTypeMove) {
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
        [SVProgressHUD show];
    }
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        if ([error type] == MEGAErrorTypeApiEAccess) {
            if ([request type] == MEGARequestTypeCreateFolder || [request type] == MEGARequestTypeUpload) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"permissionTitle", nil) message:AMLocalizedString(@"permissionMessage", nil) delegate:self cancelButtonTitle:AMLocalizedString(@"ok", nil) otherButtonTitles:nil, nil];
                [alertView show];
            }
        } else {
            if ([request type] == MEGARequestTypeMove || [request type] == MEGARequestTypeRemove) {
                [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
                [SVProgressHUD showErrorWithStatus:error.name];
            }
        }
        return;
    }
    
    switch ([request type]) {
            
        case MEGARequestTypeGetAttrFile: {
            UITableView *tableView = [self.searchDisplayController isActive] ? self.searchDisplayController.searchResultsTableView : self.tableView;
            for (NodeTableViewCell *nodeTableViewCell in [tableView visibleCells]) {
                if ([request nodeHandle] == [nodeTableViewCell nodeHandle]) {
                    MEGANode *node = [api nodeForHandle:request.nodeHandle];
                    [Helper setThumbnailForNode:node api:api cell:nodeTableViewCell];
                }
            }
            break;
        }
            
        case MEGARequestTypeMove: {
            remainingOperations--;
            if (remainingOperations == 0) {
                
                NSString *message;
                if (numFilesAction == 0) {
                    if (numFoldersAction == 1) {
                        message = AMLocalizedString(@"folderMovedToRubbishBinMessage", nil);
                    } else { //folders > 1
                        message = [NSString stringWithFormat:AMLocalizedString(@"foldersMovedToRubbishBinMessage", nil), numFoldersAction];
                    }
                } else if (numFilesAction == 1) {
                    if (numFoldersAction == 0) {
                        message = AMLocalizedString(@"fileMovedToRubbishBinMessage", nil);
                    } else if (numFoldersAction == 1) {
                        message = AMLocalizedString(@"fileFolderMovedToRubbishBinMessage", nil);
                    } else {
                        message = [NSString stringWithFormat:AMLocalizedString(@"fileFoldersMovedToRubbishBinMessage", nil), numFoldersAction];
                    }
                } else {
                    if (numFoldersAction == 0) {
                        message = [NSString stringWithFormat:AMLocalizedString(@"filesMovedToRubbishBinMessage", nil), numFilesAction];
                    } else if (numFoldersAction == 1) {
                        message = [NSString stringWithFormat:AMLocalizedString(@"filesFolderMovedToRubbishBinMessage", nil), numFilesAction];
                    } else {
                        message = AMLocalizedString(@"filesFoldersMovedToRubbishBinMessage", nil);
                        NSString *filesString = [NSString stringWithFormat:@"%ld", (long)numFilesAction];
                        NSString *foldersString = [NSString stringWithFormat:@"%ld", (long)numFoldersAction];
                        message = [message stringByReplacingOccurrencesOfString:@"[A]" withString:filesString];
                        message = [message stringByReplacingOccurrencesOfString:@"[B]" withString:foldersString];
                    }
                }
                
                [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
                [SVProgressHUD showImage:[UIImage imageNamed:@"hudRubbishBin"] status:message];
                
                [self.searchDisplayController isActive] ? [self endEditingAndReloadSearch] : [self setEditing:NO animated:YES];
            }
            break;
        }
            
        case MEGARequestTypeRemove: {
            remainingOperations--;
            if (remainingOperations == 0) {
                NSString *message;
                if (self.displayMode == DisplayModeCloudDrive || self.displayMode == DisplayModeRubbishBin) {
                    if (numFilesAction == 0) {
                        if (numFoldersAction == 1) {
                            message = AMLocalizedString(@"folderRemovedToRubbishBinMessage", nil);
                        } else { //folders > 1
                            message = [NSString stringWithFormat:AMLocalizedString(@"foldersRemovedToRubbishBinMessage", nil), numFoldersAction];
                        }
                    } else if (numFilesAction == 1) {
                        if (numFoldersAction == 0) {
                            message = AMLocalizedString(@"fileRemovedToRubbishBinMessage", nil);
                        } else if (numFoldersAction == 1) {
                            message = AMLocalizedString(@"fileFolderRemovedToRubbishBinMessage", nil);
                        } else {
                            message = [NSString stringWithFormat:AMLocalizedString(@"fileFoldersRemovedToRubbishBinMessage", nil), numFoldersAction];
                        }
                    } else {
                        if (numFoldersAction == 0) {
                            message = [NSString stringWithFormat:AMLocalizedString(@"filesRemovedToRubbishBinMessage", nil), numFilesAction];
                        } else if (numFoldersAction == 1) {
                            message = [NSString stringWithFormat:AMLocalizedString(@"filesFolderRemovedToRubbishBinMessage", nil), numFilesAction];
                        } else {
                            message = AMLocalizedString(@"filesFoldersRemovedToRubbishBinMessage", nil);
                            NSString *filesString = [NSString stringWithFormat:@"%ld", (long)numFilesAction];
                            NSString *foldersString = [NSString stringWithFormat:@"%ld", (long)numFoldersAction];
                            message = [message stringByReplacingOccurrencesOfString:@"[A]" withString:filesString];
                            message = [message stringByReplacingOccurrencesOfString:@"[B]" withString:foldersString];
                        }
                    }
                } else {
                    message = AMLocalizedString(@"shareFolderLeaved", @"Folder leave");
                }
                [SVProgressHUD showImage:[UIImage imageNamed:@"hudMinus"] status:message];
                
                [self.searchDisplayController isActive] ? [self endEditingAndReloadSearch] : [self setEditing:NO animated:YES];
            }
            break;
        }
            
        case MEGARequestTypeCancelTransfer:
            break;
            
        default:
            break;
    }
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    [self.nodesIndexPathMutableDictionary removeAllObjects];
    [self reloadUI];
}

#pragma mark - MEGATransferDelegate

- (void)onTransferStart:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.isStreamingTransfer) {
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
        if (indexPath != nil) {
            [self reloadRowsAtIndexPaths:@[indexPath]];
        }
    }
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.isStreamingTransfer) {
        return;
    }
    
    NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
    
    if (transfer.type == MEGATransferTypeDownload && [[Helper downloadingNodes] objectForKey:base64Handle]) {
        float percentage = ([[transfer transferredBytes] floatValue] / [[transfer totalBytes] floatValue] * 100);
        NSString *percentageCompleted = [NSString stringWithFormat:@"%.f%%", percentage];
        NSString *speed = [NSString stringWithFormat:@"%@/s", [NSByteCountFormatter stringFromByteCount:[[transfer speed] longLongValue]  countStyle:NSByteCountFormatterCountStyleMemory]];
        
        NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
        if (indexPath != nil) {
            UITableView *tableView = [self.searchDisplayController isActive] ? self.searchDisplayController.searchResultsTableView : self.tableView;
            NodeTableViewCell *cell = (NodeTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
            [cell.infoLabel setText:[NSString stringWithFormat:@"%@ • %@", percentageCompleted, speed]];
        }
    }
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if (transfer.isStreamingTransfer) {
        return;
    }
    
    if ([error type]) {
        if ([error type] == MEGAErrorTypeApiEAccess) {
            if ([transfer type] ==  MEGATransferTypeUpload) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:AMLocalizedString(@"permissionTitle", nil) message:AMLocalizedString(@"permissionMessage", nil) delegate:self cancelButtonTitle:AMLocalizedString(@"ok", nil) otherButtonTitles:nil, nil];
                [alertView show];
            }
        } else if ([error type] == MEGAErrorTypeApiEIncomplete) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudMinus"] status:AMLocalizedString(@"transferCancelled", nil)];
            NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
            NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
            if (indexPath != nil) {
                [self reloadRowsAtIndexPaths:@[indexPath]];
            }
        }
        return;
    }
    
    if ([transfer type] == MEGATransferTypeDownload) {
        NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
        NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
        if (indexPath != nil) {
            [self reloadRowsAtIndexPaths:@[indexPath]];
        }
    }
}

@end
