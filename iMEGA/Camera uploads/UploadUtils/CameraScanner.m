
#import "CameraScanner.h"
#import "CameraUploadRecordManager.h"
#import "MOAssetUploadRecord+CoreDataClass.h"
#import "CameraUploadManager.h"
#import "SavedIdentifierParser.h"
#import "CameraUploadManager+Settings.h"
#import "LivePhotoScanner.h"
#import "PHFetchOptions+CameraUpload.h"
#import "PHFetchResult+CameraUpload.h"
#import "MEGAConstants.h"
#import "AssetFetchResult.h"

@interface CameraScanner () <PHPhotoLibraryChangeObserver>

@property (strong, nonatomic) NSOperationQueue *cameraScanQueue;
@property (strong, nonatomic) LivePhotoScanner *livePhotoScanner;
@property (strong, nonatomic) NSMutableArray<AssetFetchResult *> *scannedFetchResults;
@property (weak, nonatomic) id<CameraScannerDelegate> delegate;

@end

@implementation CameraScanner

- (instancetype)initWithDelegate:(id<CameraScannerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _cameraScanQueue = [[NSOperationQueue alloc] init];
        _cameraScanQueue.name = @"cameraScanQueue";
        _cameraScanQueue.maxConcurrentOperationCount = 1;
        _cameraScanQueue.qualityOfService = NSQualityOfServiceBackground;
        _livePhotoScanner = [[LivePhotoScanner alloc] init];
        _scannedFetchResults = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [self unobservePhotoLibraryChanges];
}

#pragma mark - scan camera rolls

- (void)scanMediaTypes:(NSArray<NSNumber *> *)mediaTypes completion:(void (^)(NSError * _Nullable))completion {
    [self.cameraScanQueue addOperationWithBlock:^{
        MEGALogDebug(@"[Camera Upload] Start local album scanning for media types %@", mediaTypes);
        
        PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithOptions:[PHFetchOptions mnz_fetchOptionsForCameraUploadWithMediaTypes:mediaTypes]];
        
        [self updateScannedResultsByAssetFetchResult:[[AssetFetchResult alloc] initWithMediaTypes:mediaTypes fetchResult:fetchResult]];
        
        MEGALogDebug(@"[Camera Upload] total local asset count %lu", (unsigned long)fetchResult.count);
        if (fetchResult.count == 0) {
            if (completion) {
                completion(nil);
            }
            
            return;
        }
        
        __block NSError *error;
        [CameraUploadRecordManager.shared.backgroundContext performBlockAndWait:^{
            NSArray<MOAssetUploadRecord *> *records = [CameraUploadRecordManager.shared fetchUploadRecordsByMediaTypes:mediaTypes includeAdditionalMediaSubtypes:NO sortByIdentifier:YES error:&error];
            if (error) {
                return;
            }
            MEGALogDebug(@"[Camera Upload] initial save with asset count %lu", (unsigned long)fetchResult.count);
            if (records.count == 0) {
                [self saveInitialUploadRecordsByAssetFetchResult:fetchResult error:&error];
            } else {
                MEGALogDebug(@"[Camera Upload] saved upload record count %lu", (unsigned long)records.count);
                NSArray<PHAsset *> *newAssets = [fetchResult findNewAssetsBySortedUploadRecords:records];
                MEGALogDebug(@"[Camera Upload] new assets scanned count %lu", (unsigned long)newAssets.count);
                if (newAssets.count > 0) {
                    [self createUploadRecordsByAssets:newAssets shouldCheckExistence:NO];
                    [CameraUploadRecordManager.shared saveChangesIfNeededWithError:&error];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadStatsChangedNotificationName object:nil];
                    });
                }
            }
            
            if (CameraUploadManager.isLivePhotoSupported && [mediaTypes containsObject:@(PHAssetMediaTypeImage)]) {
                [self.livePhotoScanner scanLivePhotosWithError:&error];
            }
            
            MEGALogDebug(@"[Camera Upload] Finish local album scanning");
        }];
        
        if (completion) {
            completion(error);
        }
    }];
}

- (void)updateScannedResultsByAssetFetchResult:(AssetFetchResult *)assetFetchResult {
    for (AssetFetchResult *result in self.scannedFetchResults.copy) {
        if ([result isContainedByAssetFetchResult:assetFetchResult]) {
            [self.scannedFetchResults removeObject:result];
        }
    }
    
    BOOL isContainedByScannedResult = NO;
    for (AssetFetchResult *result in self.scannedFetchResults.copy) {
        if ([assetFetchResult isContainedByAssetFetchResult:result]) {
            isContainedByScannedResult = YES;
            break;
        }
    }
    
    if (!isContainedByScannedResult) {
        [self.scannedFetchResults addObject:assetFetchResult];
    }
}

#pragma mark - Photo Library Change Observer

- (void)observePhotoLibraryChanges {
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)unobservePhotoLibraryChanges {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    for (AssetFetchResult *result in self.scannedFetchResults) {
        PHFetchResultChangeDetails *changes = [changeInstance changeDetailsForFetchResult:result.fetchResult];
        if (changes == nil) {
            return;
        }
        
        result.fetchResult = changes.fetchResultAfterChanges;
        if ([changes hasIncrementalChanges]) {
            NSArray<PHAsset *> *newAssets = [changes insertedObjects];
            if (newAssets.count == 0) {
                return;
            }
            
            [CameraUploadRecordManager.shared.backgroundContext performBlockAndWait:^{
                [self createUploadRecordsByAssets:newAssets shouldCheckExistence:YES];
                [self.livePhotoScanner scanLivePhotosInAssets:newAssets];
                [CameraUploadRecordManager.shared saveChangesIfNeededWithError:nil];
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:MEGACameraUploadStatsChangedNotificationName object:nil];
            });
            
            [self.delegate cameraScanner:self didObserveNewAssets:newAssets];
        }
    }
}

#pragma mark - create and save records

- (BOOL)saveInitialUploadRecordsByAssetFetchResult:(PHFetchResult<PHAsset *> *)result error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSError *coreDataError = nil;
    if (result.count > 0) {
        [CameraUploadRecordManager.shared.backgroundContext performBlockAndWait:^{
            for (PHAsset *asset in result) {
                [self createUploadRecordFromAsset:asset];
            }
            
            [CameraUploadRecordManager.shared saveChangesIfNeededWithError:&coreDataError];
        }];
    }
    
    if (error != NULL) {
        *error = coreDataError;
    }
    
    return coreDataError == nil;
}

- (void)createUploadRecordsByAssets:(NSArray<PHAsset *> *)assets shouldCheckExistence:(BOOL)checkExistence {
    if (assets.count == 0) {
        return;
    }
    
    [CameraUploadRecordManager.shared.backgroundContext performBlockAndWait:^{
        for (PHAsset *asset in assets) {
            if (checkExistence) {
                NSError *error;
                BOOL hasExistingRecord = [CameraUploadRecordManager.shared fetchUploadRecordsByIdentifier:asset.localIdentifier shouldPrefetchErrorRecords:NO error:&error].count > 0;
                if (error) {
                    MEGALogError(@"[Camera Upload] error when to fetch record by identifier %@ %@", asset.localIdentifier, error);
                } else if (!hasExistingRecord) {
                    [self createUploadRecordFromAsset:asset];
                }
            } else {
                [self createUploadRecordFromAsset:asset];
            }
        }
    }];
}

- (MOAssetUploadRecord *)createUploadRecordFromAsset:(PHAsset *)asset {
    if (asset.localIdentifier.length == 0) {
        return nil;
    }
    
    MOAssetUploadRecord *record = [NSEntityDescription insertNewObjectForEntityForName:@"AssetUploadRecord" inManagedObjectContext:CameraUploadRecordManager.shared.backgroundContext];
    record.localIdentifier = asset.localIdentifier;
    record.status = @(CameraAssetUploadStatusNotStarted);
    record.creationDate = asset.creationDate;
    record.mediaType = @(asset.mediaType);
    record.mediaSubtypes = @(asset.mediaSubtypes);
    record.additionalMediaSubtypes = nil;
    
    return record;
}

@end
