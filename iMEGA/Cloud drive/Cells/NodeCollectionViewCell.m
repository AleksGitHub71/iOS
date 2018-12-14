
#import "NodeCollectionViewCell.h"

#import "NSString+MNZCategory.h"

#import "Helper.h"
#import "MEGAGetThumbnailRequestDelegate.h"
#import "MEGASdkManager.h"
#import "UIImageView+MNZCategory.h"

@implementation NodeCollectionViewCell

- (void)configureCellForNode:(MEGANode *)node {
    if (node.hasThumbnail) {
        NSString *thumbnailFilePath = [Helper pathForNode:node inSharedSandboxCacheDirectory:@"thumbnailsV3"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
            self.thumbnailImageView.image = [UIImage imageWithContentsOfFile:thumbnailFilePath];
        } else {
            MEGAGetThumbnailRequestDelegate *getThumbnailRequestDelegate = [[MEGAGetThumbnailRequestDelegate alloc] initWithCompletion:^(MEGARequest *request) {
                self.thumbnailImageView.image = [UIImage imageWithContentsOfFile:request.file];
            }];
            [[MEGASdkManager sharedMEGASdk] getThumbnailNode:node destinationFilePath:thumbnailFilePath delegate:getThumbnailRequestDelegate];
            [self.thumbnailImageView mnz_imageForNode:node];
        }
        self.thumbnailImageView.hidden = NO;
        self.thumbnailIconView.hidden = YES;
    } else {
        self.thumbnailIconView.hidden = NO;
        [self.thumbnailIconView mnz_imageForNode:node];
        self.thumbnailImageView.hidden = YES;
    }
        
    self.nameLabel.text = node.name;
    self.thumbnailPlayImageView.hidden = !node.name.mnz_isVideoPathExtension;

    if (@available(iOS 11.0, *)) {
        self.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        self.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    }
}

- (void)selectCell:(BOOL)selected {
    self.selectImageView.image = selected ? [UIImage imageNamed:@"thumbnail_selected"] :[UIImage imageNamed:@"checkBoxUnselected"];
}

@end
