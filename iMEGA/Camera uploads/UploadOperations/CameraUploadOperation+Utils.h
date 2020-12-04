
#import "CameraUploadOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraUploadOperation (Utils)

- (nullable NSString *)mnz_generateLocalFileNamewithExtension:(NSString *)extension error:(NSError * __autoreleasing _Nullable *)error;

- (void)handleCloudDownloadError:(NSError *)error;
- (void)handleMEGARequestError:(MEGAError *)error;

- (MEGANode *)nodeForOriginalFingerprint:(NSString *)fingerprint;

- (void)finishUploadForFingerprintMatchedNode:(MEGANode *)node;
- (void)finishUploadWithNoEnoughDiskSpace;

@end

NS_ASSUME_NONNULL_END
