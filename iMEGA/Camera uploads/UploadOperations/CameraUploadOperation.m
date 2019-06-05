
#import "CameraUploadOperation.h"
#import "MEGASdkManager.h"
#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "TransferSessionManager.h"
#import "AssetUploadInfo.h"
#import "CameraUploadRecordManager.h"
#import "CameraUploadManager.h"
#import "CameraUploadRequestDelegate.h"
#import "FileEncrypter.h"
#import "NSURL+CameraUpload.h"
#import "MEGAConstants.h"
#import "PHAsset+CameraUpload.h"
#import "CameraUploadManager+Settings.h"
#import "NSError+CameraUpload.h"
#import "MEGAReachabilityManager.h"
#import "MEGAError+MNZCategory.h"
#import "CameraUploadOperation+Utils.h"
#import "NSDate+MNZCategory.h"
@import Photos;

static NSString * const VideoAttributeImageName = @"AttributeImage";

@interface CameraUploadOperation ()

@property (strong, nonatomic, nullable) MEGASdk *sdk;
@property (strong, nonatomic) FileEncrypter *fileEncrypter;

@end

@implementation CameraUploadOperation

#pragma mark - initializers

- (instancetype)initWithUploadInfo:(AssetUploadInfo *)uploadInfo uploadRecord:(MOAssetUploadRecord *)uploadRecord {
    self = [super init];
    if (self) {
        _uploadInfo = uploadInfo;
        _uploadRecord = uploadRecord;
    }
    
    return self;
}

#pragma mark - properties

- (MEGASdk *)sdk {
    if (_sdk == nil) {
        _sdk = [[MEGASdk alloc] initWithAppKey:MEGAiOSAppKey userAgent:nil];
    }
    
    return _sdk;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ %@", NSStringFromClass(self.class), [self.uploadInfo.asset.creationDate mnz_formattedDefaultNameForMedia], self.uploadInfo.savedLocalIdentifier];
}

#pragma mark - start operation

- (void)start {
    if (self.isFinished) {
        return;
    }
    
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    if (self.uploadInfo.asset == nil) {
        MEGALogError(@"[Camera Upload] %@ media asset is empty", self);
        [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
        return;
    }
    
    [self startExecuting];
    
    [self beginBackgroundTask];
    
    if (!MEGASdkManager.sharedMEGASdk.isLoggedIn) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    MEGALogDebug(@"[Camera Upload] %@ starts processing", self);
    [CameraUploadRecordManager.shared updateUploadRecord:self.uploadRecord withStatus:CameraAssetUploadStatusProcessing error:nil];
    
    self.uploadInfo.directoryURL = [self URLForAssetProcessing];
}

- (void)cancel {
    [super cancel];
    [self.fileEncrypter cancelEncryption];
}

#pragma mark - data processing

- (NSURL *)URLForAssetProcessing {
    NSURL *directoryURL = [NSURL mnz_assetURLForLocalIdentifier:self.uploadInfo.savedLocalIdentifier];
    [NSFileManager.defaultManager removeItemIfExistsAtURL:directoryURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    return directoryURL;
}

- (BOOL)createThumbnailAndPreviewFiles {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return NO;
    }
    
    BOOL thumbnailCreated = [self.sdk createThumbnail:self.uploadInfo.attributeImageURL.path destinatioPath:self.uploadInfo.thumbnailURL.path] && [NSFileManager.defaultManager fileExistsAtPath:self.uploadInfo.thumbnailURL.path];
    if (!thumbnailCreated) {
        MEGALogError(@"[Camera Upload] %@ error when to create thumbnail", self);
    }
    
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return NO;
    }
    BOOL previewCreated = [self.sdk createPreview:self.uploadInfo.attributeImageURL.path destinatioPath:self.uploadInfo.previewURL.path] && [NSFileManager.defaultManager fileExistsAtPath:self.uploadInfo.previewURL.path];
    if (!previewCreated) {
        MEGALogError(@"[Camera Upload] %@ error when to create preview", self);
    }
    
    self.sdk = nil;
    return thumbnailCreated && previewCreated;
}

#pragma mark - upload task

- (void)handleProcessedImageFile {
    [self handleProcessedFile:NO];
}

- (void)handleProcessedVideoFile {
    [self handleProcessedFile:YES];
}

- (void)handleProcessedFile:(BOOL)isVideoFile {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    self.uploadInfo.fingerprint = [MEGASdkManager.sharedMEGASdk fingerprintForFilePath:self.uploadInfo.fileURL.path modificationTime:self.uploadInfo.asset.creationDate];
    MEGANode *matchingNode = [MEGASdkManager.sharedMEGASdk nodeForFingerprint:self.uploadInfo.fingerprint parent:self.uploadInfo.parentNode];
    if (matchingNode) {
        MEGALogDebug(@"[Camera Upload] %@ found existing node by file fingerprint", self);
        [self finishUploadForFingerprintMatchedNode:matchingNode];
        return;
    }
    
    if (isVideoFile) {
        self.uploadInfo.attributeImageURL = [[self.uploadInfo.fileURL URLByAppendingPathExtension:VideoAttributeImageName] URLByAppendingPathExtension:MEGAJPGFileExtension];
        if (![self.uploadInfo.fileURL mnz_exportVideoThumbnailToImageURL:self.uploadInfo.attributeImageURL]) {
            MEGALogError(@"[Camera Upload] %@ error when to export video attribute image", self);
            [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
            return;
        }
    } else {
        self.uploadInfo.attributeImageURL = self.uploadInfo.fileURL;
    }
    
    if (![self createThumbnailAndPreviewFiles]) {
        [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
        return;
    }
    
    self.uploadInfo.mediaUpload = [[MEGABackgroundMediaUpload alloc] initWithMEGASdk:MEGASdkManager.sharedMEGASdk];
    
    CLLocation *assetLocation = self.uploadInfo.asset.location;
    if (assetLocation) {
        [self.uploadInfo.mediaUpload setCoordinatesWithLatitude:assetLocation.coordinate.latitude longitude:assetLocation.coordinate.longitude isUnshareable:YES];
    }
    
    if (![self.uploadInfo.mediaUpload analyseMediaInfoForFileAtPath:self.uploadInfo.fileURL.path]) {
        MEGALogError(@"[Camera Upload] %@ analyse media info failed", self);
    }
    
    [self encryptFile];
}

- (void)encryptFile {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    self.fileEncrypter = [[FileEncrypter alloc] initWithMediaUpload:self.uploadInfo.mediaUpload outputDirectoryURL:self.uploadInfo.encryptionDirectoryURL shouldTruncateInputFile:YES];
    
    __weak __typeof__(self) weakSelf = self;
    [self.fileEncrypter encryptFileAtURL:self.uploadInfo.fileURL completion:^(BOOL success, unsigned long long fileSize, NSDictionary<NSString *,NSURL *> * _Nonnull chunkURLsKeyedByUploadSuffix, NSError * _Nonnull error) {
        if (weakSelf.isCancelled) {
            [weakSelf finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
            return;
        }

        if (success) {
            MEGALogDebug(@"[Camera Upload] %@ file %llu encrypted to %lu, %@", weakSelf, fileSize, (unsigned long)chunkURLsKeyedByUploadSuffix.count, chunkURLsKeyedByUploadSuffix.allKeys);
            weakSelf.uploadInfo.fileSize = fileSize;
            weakSelf.uploadInfo.encryptedChunkURLsKeyedByUploadSuffix = chunkURLsKeyedByUploadSuffix;
            weakSelf.uploadInfo.encryptedChunksCount = chunkURLsKeyedByUploadSuffix.count;
            [weakSelf requestUploadURL];
        } else {
            MEGALogError(@"[Camera Upload] %@ error when to encrypt file %@", weakSelf, error);
            if ([error.domain isEqualToString:CameraUploadErrorDomain] && error.code == CameraUploadErrorNoEnoughDiskFreeSpace) {
                [weakSelf finishUploadWithNoEnoughDiskSpace];
            } else if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileWriteOutOfSpaceError) {
                [weakSelf finishUploadWithNoEnoughDiskSpace];
            } else if ([error.domain isEqualToString:CameraUploadErrorDomain] && error.code == CameraUploadErrorEncryptionCancelled) {
                [weakSelf finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
            } else {
                [weakSelf finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
            }
            return;
        }
    }];
}

- (void)requestUploadURL {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    [MEGASdkManager.sharedMEGASdk requestBackgroundUploadURLWithFileSize:self.uploadInfo.fileSize mediaUpload:self.uploadInfo.mediaUpload delegate:[[CameraUploadRequestDelegate alloc] initWithCompletion:^(MEGARequest * _Nonnull request, MEGAError * _Nonnull error) {
        if (self.isCancelled) {
            [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
            return;
        }
        
        if (error.type) {
            MEGALogError(@"[Camera Upload] %@ error when to requests upload url %@", self, error.nativeError);
            if (error.type == MEGAErrorTypeApiEOverQuota || error.type == MEGAErrorTypeApiEgoingOverquota) {
                [NSNotificationCenter.defaultCenter postNotificationName:MEGAStorageOverQuotaNotification object:self];
                [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
            } else {
                [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
            }
        } else {
            self.uploadInfo.uploadURLString = [self.uploadInfo.mediaUpload uploadURLString];
            MEGALogDebug(@"[Camera Upload] %@ requested upload url %@ for file size %llu", self, self.uploadInfo.uploadURLString, self.uploadInfo.fileSize);
            if ([self archiveUploadInfoDataForBackgroundTransfer]) {
                [self uploadEncryptedChunksToServer];
            } else {
                [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
            }
        }
    }]];
}

- (void)uploadEncryptedChunksToServer {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return;
    }
    
    NSError *error;
    NSArray<NSURLSessionUploadTask *> *uploadTasks = [self createUploadTasksWithError:&error];
    if (error) {
        MEGALogError(@"[Camera Upload] %@ error when to create upload task %@", self, error);
        [self finishOperationWithStatus:CameraAssetUploadStatusFailed shouldUploadNextAsset:YES];
        for (NSURLSessionUploadTask *task in uploadTasks) {
            MEGALogDebug(@"[Camera Upload] %@ cancel upload task %@", self, task.taskDescription);
            [task cancel];
        }
        return;
    }
    
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        for (NSURLSessionUploadTask *task in uploadTasks) {
            MEGALogDebug(@"[Camera Upload] %@ cancel upload task %@", self, task.taskDescription);
            [task cancel];
        }
        return;
    }
    
    for (NSURLSessionUploadTask *task in uploadTasks) {
        [task resume];
    }
    
    [self finishOperationWithStatus:CameraAssetUploadStatusUploading shouldUploadNextAsset:YES];
}

- (NSArray<NSURLSessionUploadTask *> *)createUploadTasksWithError:(NSError **)error {
    NSMutableArray<NSURLSessionUploadTask *> *uploadTasks = [NSMutableArray array];
    
    for (NSString *uploadSuffix in self.uploadInfo.encryptedChunkURLsKeyedByUploadSuffix.allKeys) {
        NSURL *serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", self.uploadInfo.uploadURLString, uploadSuffix]];
        NSURL *chunkURL = self.uploadInfo.encryptedChunkURLsKeyedByUploadSuffix[uploadSuffix];
        if ([NSFileManager.defaultManager isReadableFileAtPath:chunkURL.path]) {
            NSURLSessionUploadTask *uploadTask;
            if (self.uploadInfo.asset.mediaType == PHAssetMediaTypeVideo) {
                uploadTask = [TransferSessionManager.shared videoUploadTaskWithURL:serverURL fromFile:chunkURL completion:nil];
            } else {
                uploadTask = [[TransferSessionManager shared] photoUploadTaskWithURL:serverURL fromFile:chunkURL completion:nil];
            }
            uploadTask.taskDescription = self.uploadInfo.savedLocalIdentifier;
            [uploadTasks addObject:uploadTask];
        } else {
            if (error != NULL) {
                *error = [NSError mnz_cameraUploadChunkMissingError];
            }
            break;
        }
    }
    
    return [uploadTasks copy];
}

#pragma mark - archive upload info

- (BOOL)archiveUploadInfoDataForBackgroundTransfer {
    if (self.isCancelled) {
        [self finishOperationWithStatus:CameraAssetUploadStatusCancelled shouldUploadNextAsset:NO];
        return NO;
    }
    
    NSURL *archivedURL = [NSURL mnz_archivedUploadInfoURLForLocalIdentifier:self.uploadInfo.savedLocalIdentifier];
    return [NSKeyedArchiver archiveRootObject:self.uploadInfo toFile:archivedURL.path];
}

#pragma mark - finish operation

- (void)finishOperationWithStatus:(CameraAssetUploadStatus)status shouldUploadNextAsset:(BOOL)uploadNextAsset {
    if (self.isFinished) {
        return;
    }
    
    [self finishOperation];
    
    MEGALogDebug(@"[Camera Upload] %@ finishes with status: %@", self, [AssetUploadStatus stringForStatus:status]);
    
    if (!MEGASdkManager.sharedMEGASdk.isLoggedIn) {
        return;
    }
    
    [CameraUploadRecordManager.shared.backgroundContext performBlockAndWait:^{
        [CameraUploadRecordManager.shared updateUploadRecord:self.uploadRecord withStatus:status error:nil];
        [CameraUploadRecordManager.shared refaultObject:self.uploadRecord];
    }];
    
    if (status != CameraAssetUploadStatusUploading) {
        [NSFileManager.defaultManager removeItemIfExistsAtURL:self.uploadInfo.directoryURL];
    }
    
    if (status == CameraAssetUploadStatusDone) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadStatsChangedNotification object:nil];
        });
    }
    
    if (uploadNextAsset) {
        [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadQueueUpNextAssetNotification object:nil userInfo:@{MEGAAssetMediaTypeUserInfoKey : @(self.uploadInfo.asset.mediaType)}];
    }
}

@end
