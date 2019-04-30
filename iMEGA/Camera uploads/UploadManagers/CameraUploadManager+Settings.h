
#import "CameraUploadManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CameraUploadVideoQuality) {
    CameraUploadVideoQualityLow = 0, // 480p
    CameraUploadVideoQualityMedium = 1, // 720p
    CameraUploadVideoQualityHigh = 2, // 1080p
    CameraUploadVideoQualityOriginal = 3 // original
};

@interface CameraUploadManager (Settings)

#pragma mark - camera settings

@property (class, getter=isCameraUploadEnabled) BOOL cameraUploadEnabled;
@property (class, getter=isBackgroundUploadAllowed) BOOL backgroundUploadAllowed;

@property (class, nullable) NSDate *boardingScreenLastShowedDate;

#pragma mark - photo settings

@property (class, getter=isCellularUploadAllowed) BOOL cellularUploadAllowed;
@property (class, getter=shouldConvertHEICPhoto) BOOL convertHEICPhoto;

#pragma mark - video settings

@property (class, getter=isVideoUploadEnabled) BOOL videoUploadEnabled;
@property (class, getter=shouldConvertHEVCVideo) BOOL convertHEVCVideo;
@property (class, getter=isCellularUploadForVideosAllowed) BOOL cellularUploadForVideosAllowed;
@property (class) CameraUploadVideoQuality HEVCToH264CompressionQuality;

#pragma mark - readonly properties

@property (class, readonly) BOOL isLivePhotoSupported;
@property (class, readonly) BOOL shouldShowCameraUploadBoardingScreen;
@property (class, readonly) BOOL isHEVCFormatSupported;
@property (class, readonly) BOOL canBackgroundUploadBeStarted;
@property (class, readonly) BOOL canCameraUploadBeStarted;

#pragma mark - camera upload v2 migration

@property (class, getter=hasMigratedToCameraUploadsV2) BOOL migratedToCameraUploadsV2;
@property (class, readonly) BOOL shouldShowCameraUploadV2MigrationScreen;

+ (void)migrateCurrentSettingsToCameraUplaodV2;

#pragma mark - clear local settings

+ (void)clearLocalSettings;

@end

NS_ASSUME_NONNULL_END
