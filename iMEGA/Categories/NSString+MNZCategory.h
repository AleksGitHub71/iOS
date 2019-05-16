
#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, MEGAChatStatus);
typedef NS_ENUM(NSInteger, MEGAChatMessageEndCallReason);

@interface NSString (MNZCategory)

@property (nonatomic, readonly, getter=mnz_isImagePathExtension) BOOL mnz_imagePathExtension;
@property (nonatomic, readonly, getter=mnz_isVideoPathExtension) BOOL mnz_videoPathExtension;
@property (nonatomic, readonly, getter=mnz_isMultimediaPathExtension) BOOL mnz_multimediaPathExtension;

#pragma mark - appData

- (NSString *)mnz_appDataToSaveCameraUploadsCount:(NSUInteger)operationCount;
- (NSString *)mnz_appDataToSaveInPhotosApp;
- (NSString *)mnz_appDataToAttachToChatID:(uint64_t)chatId;
- (NSString *)mnz_appDataToSaveCoordinates:(NSString *)coordinates;
- (NSString *)mnz_appDataToLocalIdentifier:(NSString *)localIdentifier;

#pragma mark - Utils

+ (NSString *)mnz_stringWithoutUnitOfComponents:(NSArray *)componentsSeparatedByStringArray;
+ (NSString *)mnz_stringWithoutCountOfComponents:(NSArray *)componentsSeparatedByStringArray;

- (NSString *)mnz_stringBetweenString:(NSString*)start andString:(NSString*)end;
+ (NSString *)mnz_stringByFiles:(NSInteger)files andFolders:(NSInteger)folders;
+ (NSString *)mnz_stringByMissedAudioCalls:(NSInteger)missedAudioCalls andMissedVideoCalls:(NSInteger)missedVideoCalls;

+ (NSString *)chatStatusString:(MEGAChatStatus)onlineStatus;
+ (NSString *)mnz_stringByEndCallReason:(MEGAChatMessageEndCallReason)endCallReason userHandle:(uint64_t)userHandle duration:(NSInteger)duration;

- (BOOL)mnz_isValidEmail;

- (BOOL)mnz_isEmpty;

- (BOOL)mnz_containsInvalidChars;

- (NSString *)mnz_removeWebclientFormatters;

+ (NSString *)mnz_stringFromTimeInterval:(NSTimeInterval)interval;
+ (NSString *)mnz_stringFromCallDuration:(NSInteger)duration;

- (NSString *)SHA256;

- (BOOL)mnz_isDecimalNumber;

- (BOOL)mnz_containsEmoji;
- (BOOL)mnz_isPureEmojiString;
- (NSInteger)mnz_emojiCount;
- (NSString *)mnz_initialForAvatar;

- (NSString *)mnz_coordinatesOfPhotoOrVideo;
+ (NSString *)mnz_base64FromBase64URLEncoding:(NSString *)base64URLEncondingString;

- (NSString *)mnz_relativeLocalPath;

+ (NSString *)mnz_lastGreenStringFromMinutes:(NSInteger)minutes;

/**
 * @brief Convert decimal degrees coordinate into degrees, minutes, seconds and direction
 *
 * @param latitude The latitude coordinate in its decimal degree notation
 * @param longitude The longitude coordinate in its decimal degree notation
 *
 * @return The coordinate in degrees, minutes, seconds and direction
 */
+ (NSString *)mnz_convertCoordinatesLatitude:(float)latitude longitude:(float)longitude;

+ (NSString *)mnz_addedByInRecentActionBucket:(MEGARecentActionBucket *)recentActionBucket nodesArray:(NSArray *)nodesArray;

#pragma mark - File names and extensions

- (NSString *)mnz_fileNameWithLowercaseExtension;
- (NSString *)mnz_lastExtensionInLowercase;
- (NSString *)mnz_sequentialFileNameInParentNode:(MEGANode *)parentNode;

@end
