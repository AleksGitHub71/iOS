
#import <UIKit/UIKit.h>
#import "MEGAOperation.h"
#import "AssetUploadInfo.h"
#import "MEGABackgroundTaskOperation.h"
#import "AssetUploadStatus.h"

NS_ASSUME_NONNULL_BEGIN

@class MOAssetUploadRecord;

/**
 A base class for camera upload operation. It's supposed to be subclassed.
 */
@interface CameraUploadOperation : MEGABackgroundTaskOperation

@property (strong, nonatomic) AssetUploadInfo *uploadInfo;
@property (strong, nonatomic) MOAssetUploadRecord *uploadRecord;

- (instancetype)initWithUploadInfo:(AssetUploadInfo *)uploadInfo uploadRecord:(MOAssetUploadRecord *)uploadRecord;

- (void)handleProcessedImageFile;

- (void)handleProcessedVideoFile;

- (void)finishOperationWithStatus:(CameraAssetUploadStatus)status shouldUploadNextAsset:(BOOL)uploadNextAsset;

@end

NS_ASSUME_NONNULL_END
