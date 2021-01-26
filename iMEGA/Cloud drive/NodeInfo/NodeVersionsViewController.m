
#import "NodeVersionsViewController.h"

#import "SVProgressHUD.h"

#import "MEGASdkManager.h"
#import "MEGANode+MNZCategory.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGAReachabilityManager.h"
#import "MEGA-Swift.h"
#import "UIImageView+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "Helper.h"
#import "NodeTableViewCell.h"

#import "MEGAPhotoBrowserViewController.h"

@interface NodeVersionsViewController () <UITableViewDelegate, UITableViewDataSource, MGSwipeTableCellDelegate, NodeActionViewControllerDelegate, MEGADelegate> {
    BOOL allNodesSelected;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *revertBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeBarButtonItem;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSMutableArray<MEGANode *> *nodeVersionsMutableArray;
@property (nonatomic, strong) NSMutableArray<MEGANode *> *selectedNodesArray;
@property (nonatomic, strong) NSMutableDictionary *nodesIndexPathMutableDictionary;

@end

@implementation NodeVersionsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedString(@"versions", @"Title of section to display number of all historical versions of files.");
    self.editBarButtonItem.title = NSLocalizedString(@"select", @"Caption of a button to select files");

    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [self setToolbarItems:@[self.downloadBarButtonItem, flexibleItem, self.revertBarButtonItem, flexibleItem, self.removeBarButtonItem] animated:YES];
    
    [self reloadUI];
    
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    
    self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem];
    
    self.nodesIndexPathMutableDictionary = [[NSMutableDictionary alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.presentedViewController) {
        [[MEGASdkManager sharedMEGASdk] addMEGADelegate:self];
    }
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (!self.presentedViewController) {
        [[MEGASdkManager sharedMEGASdk] removeMEGADelegate:self];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateAppearance];
            
            [self.tableView reloadData];
        }
    }
}

#pragma mark - Private

- (void)reloadUI {
    if (self.node.mnz_numberOfVersions == 0) {
        [self.navigationController popViewControllerAnimated:YES];
    }  else {
        [self.nodesIndexPathMutableDictionary removeAllObjects];
        
        self.nodeVersionsMutableArray = [NSMutableArray.alloc initWithArray:self.node.mnz_versions];
        
        [self.tableView reloadData];
    }
}

- (void)updateAppearance {
    self.tableView.backgroundColor = [UIColor mnz_backgroundGroupedForTraitCollection:self.traitCollection];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return self.node.mnz_numberOfVersions-1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeForIndexPath:indexPath];

    [self.nodesIndexPathMutableDictionary setObject:indexPath forKey:node.base64Handle];
    
    NodeTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"nodeCell" forIndexPath:indexPath];
    cell.cellFlavor = NodeTableViewCellFlavorVersions;
    [cell configureCellForNode:node delegate:self api:[MEGASdkManager sharedMEGASdk]];
    
    if (self.tableView.isEditing) {
        for (MEGANode *tempNode in self.selectedNodesArray) {
            if (tempNode.handle == node.handle) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return NO;
    }
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor mnz_secondaryBackgroundGroupedElevated:self.traitCollection];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self nodeForIndexPath:indexPath];

    if (tableView.isEditing) {
        if (indexPath.section == 0) {
            return;
        }
        [self.selectedNodesArray addObject:node];
        
        [self updateNavigationBarTitle];
        
        [self setToolbarActionsEnabled:YES];
        
        if (self.selectedNodesArray.count == self.node.mnz_numberOfVersions-1) {
            allNodesSelected = YES;
        } else {
            allNodesSelected = NO;
        }
    
    } else {
        if (node.name.mnz_isImagePathExtension || node.name.mnz_isVideoPathExtension) {
            NSMutableArray<MEGANode *> *mediaNodesArray = [[[MEGASdkManager sharedMEGASdk] versionsForNode:self.node] mnz_mediaNodesMutableArrayFromNodeList];
            
            MEGAPhotoBrowserViewController *photoBrowserVC = [MEGAPhotoBrowserViewController photoBrowserWithMediaNodes:mediaNodesArray api:[MEGASdkManager sharedMEGASdk] displayMode:DisplayModeNodeVersions presentingNode:node preferredIndex:0];
            
            [self.navigationController presentViewController:photoBrowserVC animated:YES completion:nil];
        } else {
            [node mnz_openNodeInNavigationController:self.navigationController folderLink:NO fileLink:nil];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row > (self.node.mnz_numberOfVersions - 1)) {
        return;
    }

    if (tableView.isEditing) {
        MEGANode *node = [self nodeForIndexPath:indexPath];
        NSMutableArray *tempArray = [self.selectedNodesArray copy];
        for (MEGANode *tempNode in tempArray) {
            if (tempNode.handle == node.handle) {
                [self.selectedNodesArray removeObject:tempNode];
            }
        }
        
        [self updateNavigationBarTitle];
        
        [self setToolbarActionsEnabled:self.selectedNodesArray.count != 0];
        
        allNodesSelected = NO;
        
        return;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewCell *sectionHeader = [self.tableView dequeueReusableCellWithIdentifier:@"nodeInfoHeader"];
    
    UILabel *titleSection = (UILabel*)[sectionHeader viewWithTag:1];
    titleSection.textColor = [UIColor mnz_secondaryGrayForTraitCollection:self.traitCollection];
    UILabel *versionsSize = (UILabel*)[sectionHeader viewWithTag:2];
    versionsSize.textColor = UIColor.mnz_label;
    
    if (section == 0) {
        titleSection.text = NSLocalizedString(@"currentVersion", @"Title of section to display information of the current version of a file").uppercaseString;
        versionsSize.text = nil;
    } else {
        titleSection.text = NSLocalizedString(@"previousVersions", @"A button label which opens a dialog to display the full version history of the selected file").uppercaseString;
        versionsSize.text = [Helper memoryStyleStringFromByteCount:self.node.mnz_versionsSize];
    }
    
    UIView *separatorView = [sectionHeader viewWithTag:3];
    separatorView.backgroundColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    return sectionHeader;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UITableViewCell *sectionFooter = [self.tableView dequeueReusableCellWithIdentifier:@"nodeInfoFooter"];
    
    UIView *separatorView = [sectionFooter viewWithTag:1];
    separatorView.backgroundColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    return sectionFooter;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.node] < MEGAShareTypeAccessFull) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    self.selectedNodesArray = [NSMutableArray arrayWithObject:[self nodeForIndexPath:indexPath]];
    
    NSMutableArray *rightActions = [NSMutableArray new];
    
    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self removeAction:nil];
    }];
    if (@available(iOS 13.0, *)) {
        removeAction.image = [[UIImage imageNamed:@"delete"] imageWithTintColor:UIColor.whiteColor];
    } else {
        removeAction.image = [UIImage imageNamed:@"delete"];
    }
    removeAction.backgroundColor = [UIColor mnz_redForTraitCollection:(self.traitCollection)];
    [rightActions addObject:removeAction];
    
    if (indexPath.section != 0) {
        UIContextualAction *revertAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [self revertAction:nil];
        }];
        revertAction.image = [UIImage imageNamed:@"history"];
        revertAction.backgroundColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
        [rightActions addObject:revertAction];
    }
        
    UIContextualAction *downloadAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        MEGANode *node = [self nodeForIndexPath:indexPath];
        [node mnz_downloadNode];
        [self setEditing:NO animated:YES];
    }];
    downloadAction.image = [UIImage imageNamed:@"infoDownload"];
    downloadAction.backgroundColor = [UIColor mnz_turquoiseForTraitCollection:self.traitCollection];
    [rightActions addObject:downloadAction];
    
    return [UISwipeActionsConfiguration configurationWithActions:rightActions];
}

#pragma clang diagnostic pop

#pragma mark - Private

- (void)updateNavigationBarTitle {
    NSString *navigationTitle;
    if (self.tableView.isEditing) {
        if (self.selectedNodesArray.count == 0) {
            navigationTitle = NSLocalizedString(@"selectTitle", @"Title shown on the Camera Uploads section when the edit mode is enabled. On this mode you can select photos");
        } else {
            navigationTitle = (self.selectedNodesArray.count <= 1) ? [NSString stringWithFormat:NSLocalizedString(@"oneItemSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected one photo"), self.selectedNodesArray.count] : [NSString stringWithFormat:NSLocalizedString(@"itemsSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected more than one photo"), self.selectedNodesArray.count];
        }
    } else {
        navigationTitle = NSLocalizedString(@"versions", @"Title of section to display number of all historical versions of files.");
    }
    
    self.navigationItem.title = navigationTitle;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    
    [self.tableView setEditing:editing animated:animated];
    
    [self updateNavigationBarTitle];
    
    if (editing) {
        self.editBarButtonItem.title = NSLocalizedString(@"cancel", @"Button title to cancel something");
        self.navigationItem.rightBarButtonItems = @[self.editBarButtonItem];
        self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        [self.navigationController setToolbarHidden:NO animated:YES];
        
        for (NodeTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        self.editBarButtonItem.title = NSLocalizedString(@"select", @"Caption of a button to select files");

        allNodesSelected = NO;
        self.selectedNodesArray = nil;
        self.navigationItem.leftBarButtonItems = @[];
        
        [self.navigationController setToolbarHidden:YES animated:YES];
        
        for (NodeTableViewCell *cell in self.tableView.visibleCells) {
            cell.selectedBackgroundView = nil;
        }
    }
    
    if (!self.selectedNodesArray) {
        self.selectedNodesArray = [NSMutableArray new];

        [self setToolbarActionsEnabled:NO];
    }        
}

- (void)setToolbarActionsEnabled:(BOOL)boolValue {
    self.downloadBarButtonItem.enabled = self.selectedNodesArray.count == 1 ? boolValue : NO;
    self.revertBarButtonItem.enabled = (self.selectedNodesArray.count == 1 && self.selectedNodesArray.firstObject.handle != self.node.handle && [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.node] >= MEGAShareTypeAccessFull) ? boolValue : NO;
    self.removeBarButtonItem.enabled = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.node] < MEGAShareTypeAccessFull ? NO : boolValue;
}

- (MEGANode *)nodeForIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return self.node.mnz_versions.firstObject;
    } else {
        return [self.nodeVersionsMutableArray objectAtIndex:indexPath.row + 1];
    }
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    CGPoint touchPoint = [longPressGestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
    
    if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section] || indexPath.section == 0) {
        return;
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan) {        
        if (self.isEditing) {
            // Only stop editing if long pressed over a cell that is the only one selected or when selected none
            if (self.selectedNodesArray.count == 0) {
                [self setEditing:NO animated:YES];
            }
            if (self.selectedNodesArray.count == 1) {
                MEGANode *nodeSelected = self.selectedNodesArray.firstObject;
                MEGANode *nodePressed = [self nodeForIndexPath:indexPath];
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
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - IBActions

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    if (self.selectedNodesArray.count == 1) {
        [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:NSLocalizedString(@"downloadStarted", nil)];
        
        [self.selectedNodesArray.firstObject mnz_downloadNode];
        
        [self setEditing:NO animated:YES];
        
        [self.tableView reloadData];
    }
}

- (IBAction)revertAction:(id)sender {
    if (self.selectedNodesArray.count != 1) {
        return;
    }
    
    [[MEGASdkManager sharedMEGASdk] restoreVersionNode:[self.selectedNodesArray firstObject]];
    
    [self setEditing:NO animated:YES];
}

- (IBAction)removeAction:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"deleteVersion", @"Question to ensure user wants to delete file version") message:NSLocalizedString(@"permanentlyRemoved", @"Message to notify user the file version will be permanently removed") preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"delete", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        for (MEGANode *node in self.selectedNodesArray) {
            [[MEGASdkManager sharedMEGASdk] removeVersionNode:node];
        }
        [self setEditing:NO animated:YES];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)editTapped:(UIBarButtonItem *)sender {
    [self setEditing:!self.tableView.isEditing animated:YES];
}

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [self.selectedNodesArray removeAllObjects];
    
    if (!allNodesSelected) {
        MEGANode *n = nil;
        
        for (NSInteger i = 1; i < self.node.mnz_numberOfVersions; i++) {
            n = [self.nodeVersionsMutableArray objectAtIndex:i];
            [self.selectedNodesArray addObject:n];
        }
        
        allNodesSelected = YES;
        [self setToolbarActionsEnabled:YES];
    } else {
        allNodesSelected = NO;
        [self setToolbarActionsEnabled:NO];
    }
    
    [self updateNavigationBarTitle];
    [self.tableView reloadData];
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    
    NodeActionViewController *nodeActions = [NodeActionViewController.alloc initWithNode:[self nodeForIndexPath:indexPath] delegate:self displayMode:DisplayModeNodeVersions isIncoming:NO sender:sender];
    [self presentViewController:nodeActions animated:YES completion:nil];
}

#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction fromPoint:(CGPoint)point {
    MEGAShareType accessType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:self.node];
    if (direction == MGSwipeDirectionLeftToRight || (direction == MGSwipeDirectionRightToLeft && accessType < MEGAShareTypeAccessFull)) {
        return NO;
    }
    return !self.isEditing;
}

- (void)swipeTableCellWillBeginSwiping:(nonnull MGSwipeTableCell *)cell {
    NodeTableViewCell *nodeCell = (NodeTableViewCell *)cell;
    nodeCell.moreButton.hidden = YES;
}

- (void)swipeTableCellWillEndSwiping:(nonnull MGSwipeTableCell *)cell {
    NodeTableViewCell *nodeCell = (NodeTableViewCell *)cell;
    nodeCell.moreButton.hidden = NO;
}

- (NSArray *)swipeTableCell:(MGSwipeTableCell *)cell swipeButtonsForDirection:(MGSwipeDirection)direction
              swipeSettings:(MGSwipeSettings *)swipeSettings expansionSettings:(MGSwipeExpansionSettings *)expansionSettings {
    
    swipeSettings.transition = MGSwipeTransitionDrag;
    expansionSettings.buttonIndex = 0;
    expansionSettings.expansionLayout = MGSwipeExpansionLayoutCenter;
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 2;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    MEGANode *node = [self nodeForIndexPath:indexPath];
    
    if (direction == MGSwipeDirectionLeftToRight && [[Helper downloadingNodes] objectForKey:node.base64Handle] == nil) {
        MGSwipeButton *downloadButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"infoDownload"] backgroundColor:[UIColor mnz_turquoiseForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
            [node mnz_downloadNode];
            return YES;
        }];
        downloadButton.tintColor = UIColor.whiteColor;
        
        return @[downloadButton];
    } else if (direction == MGSwipeDirectionRightToLeft) {
        
        NSMutableArray *rightButtons = [NSMutableArray new];
        self.selectedNodesArray = [NSMutableArray arrayWithObject:node];

        MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete"] backgroundColor:[UIColor mnz_redForTraitCollection:(self.traitCollection)] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
            [self removeAction:nil];
            return YES;
        }];
        deleteButton.tintColor = UIColor.whiteColor;
        [rightButtons addObject:deleteButton];
        
        if (indexPath.section != 0) {
            MGSwipeButton *revertButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"history"] backgroundColor:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
                [self revertAction:nil];
                return YES;
            }];
            revertButton.tintColor = UIColor.whiteColor;
            [rightButtons addObject:revertButton];
        }

        return rightButtons;
    } else {
        return nil;
    }
}

#pragma mark - NodeActionViewControllerDelegate

- (void)nodeAction:(NodeActionViewController *)nodeAction didSelect:(MegaNodeActionType)action for:(MEGANode *)node from:(id)sender {
    switch (action) {
        case MegaNodeActionTypeDownload:
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:NSLocalizedString(@"downloadStarted", @"Message shown when a download starts")];
            [node mnz_downloadNode];
            break;
            
        case MegaNodeActionTypeRemove:
            self.selectedNodesArray = [NSMutableArray arrayWithObject:node];
            [self removeAction:nil];
            break;
            
        case MegaNodeActionTypeRevertVersion:
            self.selectedNodesArray = [NSMutableArray arrayWithObject:node];
            [self revertAction:nil];
            break;
            
        case MegaNodeActionTypeSaveToPhotos:
            [node mnz_saveToPhotosWithApi:[MEGASdkManager sharedMEGASdk]];
            break;
            
        default:
            break;
    }
}

#pragma mark - MEGAGlobalDelegate

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    NSUInteger size = nodeList.size.unsignedIntegerValue;
    for (NSUInteger i = 0; i < size; i++) {
        MEGANode *nodeUpdated = [nodeList nodeAtIndex:i];
        if ([nodeUpdated hasChangedType:MEGANodeChangeTypeRemoved]) {
            if (nodeUpdated.handle == self.node.handle) {
                [self currentVersionRemoved];
                break;
            } else {
                if ([self.nodesIndexPathMutableDictionary objectForKey:nodeUpdated.base64Handle]) {
                    self.node = [MEGASdkManager.sharedMEGASdk nodeForHandle:self.node.handle];
                    [self reloadUI];
                    break;
                }
            }
        }
        
        if ([nodeUpdated hasChangedType:MEGANodeChangeTypeParent]) {
            if (nodeUpdated.handle == self.node.handle) {
                self.node = [MEGASdkManager.sharedMEGASdk nodeForHandle:nodeUpdated.parentHandle];
                [self reloadUI];
                break;
            }
        }
    }
}

- (void)currentVersionRemoved {
    if (self.nodeVersionsMutableArray.count == 1) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        self.node = [self.nodeVersionsMutableArray objectAtIndex:1];
        [self reloadUI];
    }
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
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
    if (transfer.isStreamingTransfer) {
        return;
    }
    
    NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
    
    if (transfer.type == MEGATransferTypeDownload && [[Helper downloadingNodes] objectForKey:base64Handle]) {
        float percentage = (transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue * 100);
        NSString *percentageCompleted = [NSString stringWithFormat:@"%.f%%", percentage];
        NSString *speed = [NSString stringWithFormat:@"%@/s", [Helper memoryStyleStringFromByteCount:transfer.speed.longLongValue]];
        
        NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
        if (indexPath != nil) {
            NodeTableViewCell *cell = (NodeTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            cell.infoLabel.text = [NSString stringWithFormat:@"%@ • %@", percentageCompleted, speed];
            cell.downloadProgressView.progress = transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue;
        }
    }
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if (transfer.isStreamingTransfer) {
        return;
    }
    
    if (error.type) {
        if (error.type == MEGAErrorTypeApiEAccess) {
            if (transfer.type ==  MEGATransferTypeUpload) {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"permissionTitle", nil) message:NSLocalizedString(@"permissionMessage", nil) preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
        } else if (error.type == MEGAErrorTypeApiEIncomplete) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudMinus"] status:NSLocalizedString(@"transferCancelled", nil)];
            NSString *base64Handle = [MEGASdk base64HandleForHandle:transfer.nodeHandle];
            NSIndexPath *indexPath = [self.nodesIndexPathMutableDictionary objectForKey:base64Handle];
            if (indexPath != nil) {
                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        return;
    }
    
    if (transfer.type == MEGATransferTypeDownload) {
        [self.tableView reloadData];
    }
}

@end
