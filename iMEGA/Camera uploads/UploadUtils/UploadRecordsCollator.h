
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UploadRecordsCollator : NSObject

- (void)collateNonUploadingRecords;
- (void)collateUploadingRecordsByPendingTasks:(NSArray<NSURLSessionTask *> *)tasks;

@end

NS_ASSUME_NONNULL_END
