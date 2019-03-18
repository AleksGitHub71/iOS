
#import "LivePhotoUploadOperation.h"
#import "AssetUploadInfo.h"
#import "CameraUploadRecordManager.h"
#import "PHAsset+CameraUpload.h"
#import "MEGAConstants.h"
#import "NSFileManager+MNZCategory.h"
#import "CameraUploadOperation+Utils.h"
#import "PHAssetResource+CameraUpload.h"
@import Photos;
@import CoreServices;

static NSString * const LivePhotoVideoResourceExportName = @"livePhotoVideoResource.mov";

@interface LivePhotoUploadOperation ()

@property (strong, nonatomic) AVAssetExportSession *exportSession;

@end

@implementation LivePhotoUploadOperation

- (void)start {
    [super start];
    
    if (self.isFinished) {
        return;
    }
    
    if (!MEGASdkManager.sharedMEGASdk.isLoggedIn) {
        return;
    }
    
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    [self requestLivePhotoResource];
}

- (void)requestLivePhotoResource {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    NSArray *livePhotoSearchTypes;
    if (@available(iOS 10.0, *)) {
        livePhotoSearchTypes = @[@(PHAssetResourceTypeFullSizePairedVideo), @(PHAssetResourceTypePairedVideo), @(PHAssetResourceTypeAdjustmentBasePairedVideo)];
    } else {
        livePhotoSearchTypes = @[@(PHAssetResourceTypePairedVideo)];
    }
    
    PHAssetResource *videoResource = [self.uploadInfo.asset searchAssetResourceByTypes:livePhotoSearchTypes];
    if (videoResource) {
        NSURL *videoURL = [self.uploadInfo.directoryURL URLByAppendingPathComponent:LivePhotoVideoResourceExportName];
        [self exportAssetResource:videoResource toURL:videoURL];
    } else {
        MEGALogError(@"[Camera Upload] %@ can not find the video resource in live photo", self);
        [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
    }
}

#pragma mark - asset resource export delegate

- (void)assetResource:(PHAssetResource *)resource didExportToURL:(NSURL *)URL {
    [super assetResource:resource didExportToURL:URL];
    
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    MEGALogDebug(@"[Camera Upload] %@ starts exporting live photo to video", self);
    
    AVURLAsset *urlAsset = [AVURLAsset assetWithURL:URL];
    AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:urlAsset presetName:AVAssetExportPresetHighestQuality];
    self.exportSession = session;
    session.outputFileType = AVFileTypeMPEG4;
    self.uploadInfo.fileName = [self mnz_generateLocalFileNamewithExtension:MEGAMP4FileExtension];
    session.outputURL = self.uploadInfo.fileURL;
    session.canPerformMultiplePassesOverSourceMediaData = YES;
    session.shouldOptimizeForNetworkUse = YES;
    session.metadataItemFilter = [AVMetadataItemFilter metadataItemFilterForSharing];
    
    __weak __typeof__(self) weakSelf = self;
    [session exportAsynchronouslyWithCompletionHandler:^{
        if (weakSelf.isCancelled) {
            [weakSelf finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
            return;
        }
        
        switch (session.status) {
            case AVAssetExportSessionStatusCompleted:
                MEGALogDebug(@"[Camera Upload] %@ finished exporting video to file %@", weakSelf, weakSelf.uploadInfo.fileName);
                [weakSelf handleProcessedVideoFile];
                break;
            case AVAssetExportSessionStatusCancelled:
                MEGALogDebug(@"[Camera Upload] %@ video exporting got cancelled", weakSelf);
                [weakSelf finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
                break;
            case AVAssetExportSessionStatusFailed:
                MEGALogError(@"[Camera Upload] %@ error when to export video %@", weakSelf, session.error)
                if ([session.error.domain isEqualToString:AVFoundationErrorDomain] && session.error.code == AVErrorDiskFull) {
                    [weakSelf finishUploadWithNoEnoughDiskSpace];
                } else {
                    [weakSelf finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
                }
                break;
            default:
                break;
        }
    }];
}

#pragma mark - cancel operation

- (void)cancel {
    [super cancel];
    
    switch (self.exportSession.status) {
        case AVAssetExportSessionStatusWaiting:
        case AVAssetExportSessionStatusExporting:
            MEGALogDebug(@"[Camera Upload] %@ cancel live photo video exporting as the operation is cancelled", self);
            [self.exportSession cancelExport];
            break;
        default:
            break;
    }
}

@end
