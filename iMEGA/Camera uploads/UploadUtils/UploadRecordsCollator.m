
#import "UploadRecordsCollator.h"
#import "CameraUploadRecordManager.h"
#import "NSURL+CameraUpload.h"
#import "NSFileManager+MNZCategory.h"
#import "TransferSessionManager.h"

@implementation UploadRecordsCollator

- (void)collateNonUploadingRecords {
    [CameraUploadRecordManager.shared.backgroundContext performBlock:^{
        [self clearErrorRecordsPerLaunch];
        NSArray<MOAssetUploadRecord *> *records = [CameraUploadRecordManager.shared fetchUploadRecordsByStatuses:AssetUploadStatus.nonUploadingStatusesToCollate error:nil];
        if (records.count == 0) {
            MEGALogDebug(@"[Camera Upload] no non-uploading records to collate");
            return;
        }
        
        MEGALogDebug(@"[Camera Upload] %lu non-uploading records to revert back to not stated status", (unsigned long)records.count);
        for (MOAssetUploadRecord *record in records) {
            [self revertBackToNotStartedForRecord:record];
        }
        
        [CameraUploadRecordManager.shared saveChangesIfNeededWithError:nil];
    }];
}

- (void)collateUploadingRecordsByPendingTasks:(NSArray<NSURLSessionTask *> *)tasks {
    [CameraUploadRecordManager.shared.backgroundContext performBlock:^{
        NSArray<MOAssetUploadRecord *> *uploadingRecords = [CameraUploadRecordManager.shared fetchUploadRecordsByStatuses:@[@(CameraAssetUploadStatusUploading)] error:nil];
        if (uploadingRecords.count == 0) {
            MEGALogDebug(@"[Camera Upload] no uploading records to collate");
            return;
        }
        
        MEGALogDebug(@"[Camera Upload] %lu uploading records to collate, running tasks count %lu", (unsigned long)uploadingRecords.count, (unsigned long)tasks.count);
        NSMutableArray<NSString *> *runningTaskIdentifiers = [NSMutableArray array];
        for (NSURLSessionUploadTask *task in tasks) {
            MEGALogDebug(@"[Camera Upload] %@ running task state %li", task.taskDescription, (long)task.state);
            if (task.taskDescription.length > 0) {
                [runningTaskIdentifiers addObject:task.taskDescription];
            }
        }
        
        NSComparator localIdComparator = ^(NSString *s1, NSString *s2) {
            return [s1 compare:s2];
        };
        
        [runningTaskIdentifiers sortUsingComparator:localIdComparator];
        for (MOAssetUploadRecord *record in uploadingRecords) {
            NSUInteger index = [runningTaskIdentifiers indexOfObject:record.localIdentifier inSortedRange:NSMakeRange(0, runningTaskIdentifiers.count) options:NSBinarySearchingFirstEqual usingComparator:localIdComparator];
            if (index == NSNotFound) {
                [self revertBackToNotStartedForRecord:record];
            }
        }
        
        [CameraUploadRecordManager.shared saveChangesIfNeededWithError:nil];
    }];
}

- (void)clearErrorRecordsPerLaunch {
    [CameraUploadRecordManager.shared deleteAllErrorRecordsPerLaunchWithError:nil];
}

- (void)revertBackToNotStartedForRecord:(MOAssetUploadRecord *)record {
    if (record.status.integerValue == CameraAssetUploadStatusDone) {
        MEGALogDebug(@"[Camera Upload] skip collation as upload is done for %@", record.localIdentifier);
        return;
    }
    
    MEGALogDebug(@"[Camera Upload] revert record status %@ to not started for %@", [AssetUploadStatus stringForStatus:record.status.unsignedIntegerValue], record.localIdentifier);
    record.status = @(CameraAssetUploadStatusNotStarted);
    [NSFileManager.defaultManager removeItemIfExistsAtURL:[NSURL mnz_assetURLForLocalIdentifier:record.localIdentifier]];
}

@end
