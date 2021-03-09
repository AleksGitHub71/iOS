
#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, MEGAChatStatus);
typedef NS_ENUM(NSInteger, MEGAChatMessageEndCallReason);

NS_ASSUME_NONNULL_BEGIN

@interface NSString (MNZCategory)

@property (nonatomic, readonly, getter=mnz_isImagePathExtension) BOOL mnz_imagePathExtension;
@property (nonatomic, readonly, getter=mnz_isVideoPathExtension) BOOL mnz_videoPathExtension;
@property (nonatomic, readonly, getter=mnz_isMultimediaPathExtension) BOOL mnz_multimediaPathExtension;
@property (nonatomic, readonly, getter=mnz_isWebCodePathExtension) BOOL mnz_webCodePathExtension;

#pragma mark - appData

- (NSString *)mnz_appDataToSaveInPhotosApp;
- (NSString *)mnz_appDataToAttachToChatID:(uint64_t)chatId asVoiceClip:(BOOL)asVoiceClip;
- (NSString *)mnz_appDataToSaveCoordinates:(NSString *)coordinates;
- (NSString *)mnz_appDataToLocalIdentifier:(NSString *)localIdentifier;
- (NSString *)mnz_appDataToPath:(NSString *)path;

#pragma mark - Utils

+ (NSString *)mnz_stringWithoutUnitOfComponents:(NSArray *)componentsSeparatedByStringArray;
+ (NSString *)mnz_stringWithoutCountOfComponents:(NSArray *)componentsSeparatedByStringArray;
+ (NSString *)mnz_formatStringFromByteCountFormatter:(NSString *)stringFromByteCount;

- (NSString * _Nullable)mnz_stringBetweenString:(NSString*)start andString:(NSString*)end;
+ (NSString *)mnz_stringByFiles:(NSInteger)files andFolders:(NSInteger)folders;
+ (NSString *)localizedSortOrderType:(MEGASortOrderType)sortOrderType;

+ (NSString * _Nullable)chatStatusString:(MEGAChatStatus)onlineStatus;
+ (NSString *)mnz_stringByEndCallReason:(MEGAChatMessageEndCallReason)endCallReason userHandle:(uint64_t)userHandle duration:(NSNumber * _Nullable)duration isGroup:(BOOL)isGroup;
+ (NSString *)mnz_hoursDaysWeeksMonthsOrYearFrom:(NSUInteger)seconds;

- (BOOL)mnz_isValidEmail;

- (BOOL)mnz_isEmpty;
- (NSString *)mnz_removeWhitespacesAndNewlinesFromBothEnds;

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

- (NSString * _Nullable)mnz_coordinatesOfPhotoOrVideo;
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

+ (NSString *)mnz_addedByInRecentActionBucket:(MEGARecentActionBucket *)recentActionBucket;

#pragma mark - File names and extensions

- (NSString *)mnz_fileNameWithLowercaseExtension;
- (NSString *)mnz_lastExtensionInLowercase;
- (NSString *)mnz_sequentialFileNameInParentNode:(MEGANode *)parentNode;

/**
 Remove invalid file characters from a string. So we can use the new string safely as a folder name or file name
 
 For now, we remove characters ":", "/", "\\"

 @return a new string without invalid characters
 */
- (NSString *)mnz_stringByRemovingInvalidFileCharacters;

@end

NS_ASSUME_NONNULL_END
