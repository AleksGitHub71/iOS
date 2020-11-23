
#import "OfflineTableViewViewController.h"

#import "NSDate+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIImage+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

#import "Helper.h"
#import "MEGAStore.h"
#import "MEGASdkManager.h"

#import "OfflineTableViewCell.h"
#import "OfflineViewController.h"
#import "OpenInActivity.h"
#import "MEGA-Swift.h"

static NSString *kFileName = @"kFileName";
static NSString *kPath = @"kPath";

@interface OfflineTableViewViewController () <MGSwipeTableCellDelegate, UITableViewDataSource, UITableViewDelegate>

@end

@implementation OfflineTableViewViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //White background for the view behind the table view
    self.tableView.backgroundView = UIView.alloc.init;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self updateAppearance:self.traitCollection];
}

#pragma mark - Public

- (void)tableViewSelectIndexPath:(NSIndexPath *)indexPath {
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

- (void)setTableViewEditing:(BOOL)editing animated:(BOOL)animated {
    [self.tableView setEditing:editing animated:animated];
    
    [self.offline setViewEditing:editing];
    
    if (editing) {
        for (OfflineTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        for (OfflineTableViewCell *cell in self.tableView.visibleCells) {
            cell.selectedBackgroundView = nil;
        }
    }
}

#pragma mark - IBAction

- (IBAction)moreButtonTouchUpInside:(UIButton *)sender {
    if (self.tableView.isEditing) {
        return;
    }
    
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    
    OfflineTableViewCell *cell = (OfflineTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    NSString *itemPath = [self.offline.currentOfflinePath stringByAppendingPathComponent:cell.nameLabel.text];
    
    [self.offline showInfoFilePath:itemPath at:indexPath from:sender];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = self.offline.searchController.isActive ? self.offline.searchItemsArray.count : self.offline.offlineSortedItems.count;
    [self.offline enableButtonsByNumberOfItems];
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OfflineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"offlineTableViewCell" forIndexPath:indexPath];
    
    NSString *directoryPathString = [self.offline currentOfflinePath];
    NSString *nameString = [[self.offline itemAtIndexPath:indexPath] objectForKey:kFileName];
    NSString *pathForItem = [directoryPathString stringByAppendingPathComponent:nameString];
    
    cell.itemNameString = nameString;
    
    MOOfflineNode *offNode = [[MEGAStore shareInstance] fetchOfflineNodeWithPath:[Helper pathRelativeToOfflineDirectory:pathForItem]];
    NSString *handleString = offNode.base64Handle;
    
    cell.thumbnailPlayImageView.hidden = YES;
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:pathForItem isDirectory:&isDirectory];
    if (isDirectory) {
        cell.thumbnailImageView.image = UIImage.mnz_folderImage;
        
        NSInteger files = 0;
        NSInteger folders = 0;
        
        NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathForItem error:nil];
        for (NSString *file in directoryContents) {
            BOOL isDirectory;
            NSString *path = [pathForItem stringByAppendingPathComponent:file];
            if (![path.pathExtension.lowercaseString isEqualToString:@"mega"]) {
                [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
                isDirectory ? folders++ : files++;
            }
            
        }
        
        cell.infoLabel.text = [NSString mnz_stringByFiles:files andFolders:folders];
    } else {
        NSString *extension = nameString.pathExtension.lowercaseString;
        
        if (!handleString) {
            NSString *fpLocal = [[MEGASdkManager sharedMEGASdk] fingerprintForFilePath:pathForItem];
            if (fpLocal) {
                MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForFingerprint:fpLocal];
                if (node) {
                    handleString = node.base64Handle;
                    [[MEGAStore shareInstance] insertOfflineNode:node api:[MEGASdkManager sharedMEGASdk] path:[[Helper pathRelativeToOfflineDirectory:pathForItem] decomposedStringWithCanonicalMapping]];
                }
            }
        }
        
        NSString *thumbnailFilePath = [Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"];
        thumbnailFilePath = [thumbnailFilePath stringByAppendingPathComponent:handleString];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath] && handleString) {
            UIImage *thumbnailImage = [UIImage imageWithContentsOfFile:thumbnailFilePath];
            if (thumbnailImage) {
                [cell.thumbnailImageView setImage:thumbnailImage];
                if (nameString.mnz_isVideoPathExtension) {
                    cell.thumbnailPlayImageView.hidden = NO;
                }
            }
            
        } else {
            if (nameString.mnz_isImagePathExtension) {
                if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
                    [[MEGASdkManager sharedMEGASdk] createThumbnail:pathForItem destinatioPath:thumbnailFilePath];
                }
            } else {
                [cell.thumbnailImageView mnz_setImageForExtension:extension];
            }
        }
        
        NSDate *modificationDate = [[NSFileManager.defaultManager attributesOfItemAtPath:pathForItem error:nil] valueForKey:NSFileModificationDate];
        
        unsigned long long size = [NSFileManager.defaultManager attributesOfItemAtPath:pathForItem error:nil].fileSize;
        
        cell.infoLabel.text = [NSString stringWithFormat:@"%@ • %@", [Helper memoryStyleStringFromByteCount:size], modificationDate.mnz_formattedDateMediumTimeShortStyle];
    }
    cell.nameLabel.text = [[MEGASdkManager sharedMEGASdk] unescapeFsIncompatible:nameString destinationPath:[NSHomeDirectory() stringByAppendingString:@"/"]];
    
    if (self.tableView.isEditing) {
        for (NSURL *url in self.offline.selectedItems) {
            if ([url.path isEqualToString:pathForItem]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
    
    if (@available(iOS 11.0, *)) {} else {
        cell.delegate = self;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self.offline itemAtIndexPath:indexPath] objectForKey:kPath];
        [self.offline.selectedItems addObject:filePathURL];
        
        [self.offline updateNavigationBarTitle];
        [self.offline enableButtonsBySelectedItems];
        
        self.offline.allItemsSelected = (self.offline.selectedItems.count == self.offline.offlineSortedItems.count);
        
        return;
    }
    
    OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    [self.offline itemTapped:cell.nameLabel.text atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self.offline itemAtIndexPath:indexPath] objectForKey:kPath];
        
        NSMutableArray *tempArray = self.offline.selectedItems.copy;
        for (NSURL *url in tempArray) {
            if ([url.filePathURL isEqual:filePathURL]) {
                [self.offline.selectedItems removeObject:url];
            }
        }
        
        [self.offline updateNavigationBarTitle];
        [self.offline enableButtonsBySelectedItems];
        
        self.offline.allItemsSelected = NO;
        
        return;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        NSString *itemPath = [[self.offline currentOfflinePath] stringByAppendingPathComponent:cell.itemNameString];
        [self.offline showRemoveAlertWithConfirmAction:^{
            [self.offline removeOfflineNodeCell:itemPath];
            [self.offline updateNavigationBarTitle];
        } andCancelAction:^{
            [self.offline setEditMode:NO];
        }];
    }];
    if (@available(iOS 13.0, *)) {
        deleteAction.image = [[UIImage imageNamed:@"delete"] imageWithTintColor:UIColor.whiteColor];
    } else {
        deleteAction.image = [UIImage imageNamed:@"delete"];
    }
    deleteAction.backgroundColor = UIColor.mnz_redError;
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma clang diagnostic pop

#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction fromPoint:(CGPoint)point {
    if (self.tableView.isEditing) {
        return NO;
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        return NO;
    }
    
    return YES;
}

- (NSArray *)swipeTableCell:(MGSwipeTableCell *)cell swipeButtonsForDirection:(MGSwipeDirection)direction swipeSettings:(MGSwipeSettings *)swipeSettings expansionSettings:(MGSwipeExpansionSettings *)expansionSettings {
    
    swipeSettings.transition = MGSwipeTransitionDrag;
    expansionSettings.buttonIndex = 0;
    expansionSettings.expansionLayout = MGSwipeExpansionLayoutCenter;
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 2;
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete"] backgroundColor:[UIColor mnz_redForTraitCollection:self.traitCollection] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
            OfflineTableViewCell *offlineCell = (OfflineTableViewCell *)cell;
            NSString *itemPath = [self.offline.currentOfflinePath stringByAppendingPathComponent:offlineCell.itemNameString];
            [self.offline showRemoveAlertWithConfirmAction:^{
                [self.offline removeOfflineNodeCell:itemPath];
            } andCancelAction:^{
                [self.offline setEditMode:NO];
            }];
            return YES;
        }];
        [deleteButton iconTintColor:[UIColor whiteColor]];
        
        return @[deleteButton];
    }
    else {
        return nil;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAppearance:self.traitCollection];
}

- (void)updateAppearance:(UITraitCollection *)currentTraitCollection{
    if (@available(iOS 13.0, *)) {
        switch (currentTraitCollection.userInterfaceStyle) {
            case UIUserInterfaceStyleUnspecified:
            case UIUserInterfaceStyleLight: {
                self.tableView.backgroundColor = UIColor.whiteColor;
            }
                break;
            case UIUserInterfaceStyleDark: {
                self.tableView.backgroundColor = UIColor.mnz_black1C1C1E;
            }
        }
    } else {
        self.tableView.backgroundColor = UIColor.whiteColor;
    }
}

@end
