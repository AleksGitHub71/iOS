#import "TransferTableViewCell.h"

#import <Photos/Photos.h>

#import "Helper.h"
#import "MEGAPauseTransferRequestDelegate.h"
#import "MEGASdkManager.h"
#import "NSDate+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIImage+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

@interface TransferTableViewCell ()

@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (nonatomic, getter=isThumbnailSet) BOOL thumbnailSet;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *arrowImageView;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (strong, nonatomic) IBOutlet UIButton *cancelButton;
@property (strong, nonatomic) IBOutlet UIButton *pauseButton;

@property (weak, nonatomic) IBOutlet UIView *separatorView;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;

@property (strong, nonatomic) MEGATransfer *transfer;
@property (strong, nonatomic) NSString *uploadTransferLocalIdentifier;

@end

@implementation TransferTableViewCell

#pragma mark - Public

- (void)configureCellForTransfer:(MEGATransfer *)transfer delegate:(id<TransferTableViewCellDelegate>)delegate {
    [self configureCellForTransfer:transfer overquota:false delegate:delegate];
}

- (void)configureCellForTransfer:(MEGATransfer *)transfer overquota:(BOOL)overquota delegate:(id<TransferTableViewCellDelegate>)delegate {
    self.delegate = delegate;
    self.overquota = overquota;
    self.transfer = transfer;
    self.uploadTransferLocalIdentifier = nil;
    
    self.nameLabel.text = [[MEGASdkManager sharedMEGASdk] unescapeFsIncompatible:transfer.fileName destinationPath:[NSHomeDirectory() stringByAppendingString:@"/"]];
    self.pauseButton.hidden = self.cancelButton.hidden = NO;
    float percentage = (transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
    self.progressView.progress = percentage;
    switch (transfer.type) {
        case MEGATransferTypeDownload: {
            MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:transfer.nodeHandle];
            if (node) {
                [self.iconImageView mnz_setThumbnailByNode:node];
            } else {
                [self.iconImageView mnz_setImageForExtension:transfer.fileName.pathExtension];
            }
            self.thumbnailSet = YES;
            break;
        }
            
        case MEGATransferTypeUpload: {
            if (transfer.fileName.mnz_isImagePathExtension || transfer.fileName.mnz_isVideoPathExtension) {
                NSString *transferThumbnailAbsolutePath = [[[NSHomeDirectory() stringByAppendingPathComponent:transfer.path] stringByDeletingPathExtension] stringByAppendingString:@"_thumbnail"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:transferThumbnailAbsolutePath]) {
                    self.iconImageView.image = [UIImage imageWithContentsOfFile:transferThumbnailAbsolutePath];
                    self.thumbnailSet = YES;
                } else {
                    [self.iconImageView mnz_setImageForExtension:transfer.fileName.pathExtension];
                    self.thumbnailSet = NO;
                }
            } else {
                [self.iconImageView mnz_setImageForExtension:transfer.fileName.pathExtension];
                self.thumbnailSet = YES;
            }
            break;
        }
            
        default:
            break;
    }
    
    
    [self configureCellWithTransferState:transfer.state];
    
    self.separatorView.layer.borderColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection].CGColor;
    self.separatorView.layer.borderWidth = 0.5;
    
}

- (void)setOverquota:(BOOL)overquota {
    _overquota = overquota;
    if (overquota) {
        self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadingOverquotaTransferImage : UIImage.mnz_uploadingOverquotaTransferImage;
        self.infoLabel.text = AMLocalizedString(@"Transfer over quota", @"Label indicating transfer over quota");
        self.infoLabel.textColor = [UIColor mnz_fromHexString:@"FFCC00"];
        self.pauseButton.hidden = self.cancelButton.hidden = NO;
    }
}

- (void)reconfigureCellWithTransfer:(MEGATransfer *)transfer {
    self.uploadTransferLocalIdentifier = nil;
    self.transfer = transfer;
    
    [self configureCellWithTransferState:MEGATransferStateActive];
}

- (void)configureCellForQueuedTransfer:(NSString *)uploadTransferLocalIdentifier delegate:(id<TransferTableViewCellDelegate>)delegate {
    self.delegate = delegate;
    self.transfer = nil;
    self.uploadTransferLocalIdentifier = uploadTransferLocalIdentifier;
    
    if (!uploadTransferLocalIdentifier) {
        return;
    }
    
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[uploadTransferLocalIdentifier] options:nil];
    if (fetchResult == nil) {
        return;
    }
    
    PHAsset *asset = fetchResult.firstObject;
    if (asset == nil) {
        return;
    }
    
    NSString *extension;
    
    if ([PHAssetResource assetResourcesForAsset:asset].count > 0) {
        PHAssetResource *assetResource = [PHAssetResource assetResourcesForAsset:asset].firstObject;
        if (assetResource.originalFilename) {
            extension = assetResource.originalFilename.mnz_lastExtensionInLowercase;
        }
    }
    
    NSString *name = asset.creationDate.mnz_formattedDefaultNameForMedia;
    if (extension) {
        name = [name stringByAppendingPathExtension:extension];
    }
    
    self.nameLabel.text = name;

    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.networkAccessAllowed = YES;
    
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:self.iconImageView.frame.size contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if (result) {
            self.iconImageView.image = result;
        } else {
            [self.iconImageView mnz_setImageForExtension:extension];
        }
    }];
    
    [self queuedStateLayout];
}

- (void)reloadThumbnailImage {
    if (!self.isThumbnailSet) {
        NSString *transferThumbnailAbsolutePath = [[[NSHomeDirectory() stringByAppendingPathComponent:self.transfer.path] stringByDeletingPathExtension] stringByAppendingString:@"_thumbnail"];
        self.iconImageView.image = [UIImage imageWithContentsOfFile:transferThumbnailAbsolutePath];
    }
}

- (void)updatePercentAndSpeedLabelsForTransfer:(MEGATransfer *)transfer {
    self.transfer = transfer;
    [self configureCellWithTransferState:self.transfer.state];
}

- (NSMutableAttributedString *)transferInfoAttributedString {
    MEGATransfer *transfer = self.transfer;
    if (transfer.state == MEGATransferStateCancelled || transfer.state == MEGATransferStateFailed) {
        return NSMutableAttributedString.new;
    }
    UIColor *percentageColor = (transfer.type == MEGATransferTypeDownload) ? UIColor.systemGreenColor : [UIColor mnz_blueForTraitCollection:self.traitCollection];
    float percentage = (transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
    self.progressView.progress = percentage;
    NSString *fileSize = [Helper memoryStyleStringFromByteCount:transfer.totalBytes.longLongValue];
    NSString *percentageCompleted = [NSString stringWithFormat:@"%.f %% of %@ ", percentage  * 100, fileSize];
    NSMutableAttributedString *percentageAttributedString = [NSMutableAttributedString.alloc initWithString:percentageCompleted attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:percentageColor}];
    
    if (transfer.state == MEGATransferStateActive && ![[NSUserDefaults standardUserDefaults] boolForKey:@"TransfersPaused"]) {
        NSString *speed = [NSString stringWithFormat:@"%@/s ", [Helper memoryStyleStringFromByteCount:transfer.speed.longLongValue]];
        NSAttributedString *speedAttributedString = [NSAttributedString.alloc initWithString:speed attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
        [percentageAttributedString appendAttributedString:speedAttributedString];
    }
    return percentageAttributedString;
}

- (void)updateTransferIfNewState:(MEGATransfer *)transfer {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TransfersPaused"]) {
        if (self.transfer.state != transfer.state) {
            self.transfer = transfer;
            float percentage = (transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
            self.progressView.progress = percentage;
            [self configureCellWithTransferState:self.transfer.state];
        }
    }
}

#pragma mark - Private

- (void)configureCellWithTransferState:(MEGATransferState)transferState {
    if (self.overquota) {
        return;
    }
    switch (transferState) {
        case MEGATransferStateQueued: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
            self.infoLabel.textColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
            self.infoLabel.text = AMLocalizedString(@"queued", @"Queued");
            [self.pauseButton setImage:[UIImage imageNamed:@"pauseTransfers"] forState:UIControlStateNormal];
            self.pauseButton.hidden = self.cancelButton.hidden = NO;
            break;
        }
            
        case MEGATransferStateActive: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadingTransferImage : UIImage.mnz_uploadingTransferImage;
            [self.arrowImageView setNeedsDisplay];
            [self.pauseButton setImage:[UIImage imageNamed:@"pauseTransfers"] forState:UIControlStateNormal];
            self.pauseButton.hidden = self.cancelButton.hidden = NO;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TransfersPaused"]) {
                self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
                NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"paused", @"Paused") attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
                NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
                [infoLabel appendAttributedString:status];
                self.infoLabel.attributedText = infoLabel;
            } else {
                self.infoLabel.attributedText = [self transferInfoAttributedString];
            }

            break;
        }
            
        case MEGATransferStatePaused: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
            NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"paused", @"Paused") attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            
            self.infoLabel.attributedText = infoLabel;
            [self.pauseButton setImage:[UIImage imageNamed:@"resumeTransfers"] forState:UIControlStateNormal];
            self.pauseButton.hidden = self.cancelButton.hidden = NO;
            break;
        }
            
        case MEGATransferStateRetrying: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadingTransferImage : UIImage.mnz_uploadingTransferImage;
            NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"Retrying...", @"Label for the state of a transfer when is being retrying - (String as short as possible).") attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            self.infoLabel.attributedText = infoLabel;
            self.pauseButton.hidden = self.cancelButton.hidden = NO;
            break;
        }
            
        case MEGATransferStateCompleting: {
            NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"Completing...", @"Label for the state of a transfer when is being completing - (String as short as possible).")
                                                                       attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:(self.transfer.type == MEGATransferTypeDownload) ? UIColor.systemGreenColor : [UIColor mnz_blueForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            self.infoLabel.attributedText = infoLabel;
            self.pauseButton.hidden = self.cancelButton.hidden = YES;
            }
            break;
            
        case MEGATransferStateCancelled: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
            NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"Cancelled", @"Cancelled") attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            self.infoLabel.attributedText = infoLabel;
            self.progressView.progress = 0;
            self.pauseButton.hidden = self.cancelButton.hidden = YES;
        }
            break;
        case MEGATransferStateFailed: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
            self.infoLabel.textColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
            NSString *transferFailed = AMLocalizedString(@"Transfer failed:", @"Notification message shown when a transfer failed. Keep colon.");
            MEGAError *error = self.transfer.lastErrorExtended;

            NSString *errorString = [MEGAError errorStringWithErrorCode:error.type context:(self.transfer.type == MEGATransferTypeUpload) ? MEGAErrorContextUpload : MEGAErrorContextDownload];
            
            NSAttributedString *status = [NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@ %@", transferFailed, AMLocalizedString(errorString, nil)] attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            self.infoLabel.attributedText = infoLabel;
            
            self.progressView.progress = 0;
            
            self.pauseButton.hidden = self.cancelButton.hidden = YES;

        }
            
            break;
        default: {
            self.arrowImageView.image = (self.transfer.type == MEGATransferTypeDownload) ? UIImage.mnz_downloadQueuedTransferImage : UIImage.mnz_uploadQueuedTransferImage;
            NSAttributedString *status = [NSAttributedString.alloc initWithString:AMLocalizedString(@"queued", @"Queued") attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
            NSMutableAttributedString *infoLabel = [self transferInfoAttributedString];
            [infoLabel appendAttributedString:status];
            self.infoLabel.attributedText = infoLabel;
            
            [self.pauseButton setImage:[UIImage imageNamed:@"pauseTransfers"] forState:UIControlStateNormal];
            self.pauseButton.hidden = self.cancelButton.hidden = NO;
            break;
        }
    }
}

- (void)queuedStateLayout {
    self.arrowImageView.image = UIImage.mnz_uploadQueuedTransferImage;
    self.infoLabel.textColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
    self.infoLabel.text = AMLocalizedString(@"pending", @"Label shown when a contact request is pending");
    self.pauseButton.hidden = YES;
    self.cancelButton.hidden = NO;
    self.progressView.progress = 0;

}

#pragma mark - IBActions

- (IBAction)cancelTransfer:(id)sender {
    if (self.transfer) {
        if ([[MEGASdkManager sharedMEGASdk] transferByTag:self.transfer.tag] != nil) {
            [[MEGASdkManager sharedMEGASdk] cancelTransferByTag:self.transfer.tag];
        } else {
            if ([[MEGASdkManager sharedMEGASdkFolder] transferByTag:self.transfer.tag] != nil) {
                [[MEGASdkManager sharedMEGASdkFolder] cancelTransferByTag:self.transfer.tag];
            }
        }
    } else if (self.uploadTransferLocalIdentifier) {
        [self.delegate cancelQueuedUploadTransfer:self.uploadTransferLocalIdentifier];
    }
}

- (IBAction)pauseTransfer:(id)sender {
    if (self.transfer) {
        MEGAPauseTransferRequestDelegate *pauseTransferDelegate = [[MEGAPauseTransferRequestDelegate alloc] initWithCompletion:^(MEGARequest *request) {
            MEGATransfer *transfer = [[MEGASdkManager sharedMEGASdk] transferByTag:self.transfer.tag];
            if (transfer) {
                self.transfer = transfer;
            } else {
                transfer = [[MEGASdkManager sharedMEGASdkFolder] transferByTag:self.transfer.tag];
                if (transfer) {
                    self.transfer = transfer;
                }
            }
            
            [self.delegate pauseTransfer:self.transfer];
            [self configureCellWithTransferState:(request.flag) ? MEGATransferStatePaused : MEGATransferStateActive];
        }];
        
        MEGATransfer *transfer = [[MEGASdkManager sharedMEGASdk] transferByTag:self.transfer.tag];
        if (transfer) {
            [[MEGASdkManager sharedMEGASdk] pauseTransferByTag:self.transfer.tag pause:!(transfer.state == MEGATransferStatePaused) delegate:pauseTransferDelegate];
        } else {
            transfer = [[MEGASdkManager sharedMEGASdkFolder] transferByTag:self.transfer.tag];
            if (transfer) {
                [[MEGASdkManager sharedMEGASdkFolder] pauseTransferByTag:self.transfer.tag pause:!(transfer.state == MEGATransferStatePaused) delegate:pauseTransferDelegate];
            }
        }
    }
}

@end
