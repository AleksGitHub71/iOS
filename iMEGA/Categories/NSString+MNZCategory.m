
#import "NSString+MNZCategory.h"

#import <AVKit/AVKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>

#import "NSDate+DateTools.h"

#import "MEGASdkManager.h"

static NSString* const A = @"[A]";
static NSString* const B = @"[B]";

@implementation NSString (MNZCategory)

- (BOOL)mnz_isImagePathExtension {
    NSArray<NSString *> *supportedExtensions = @[@"bmp",
                                                 @"cr2",
                                                 @"crw",
                                                 @"cur",
                                                 @"dng",
                                                 @"gif",
                                                 @"heic",
                                                 @"ico",
                                                 @"j2c",
                                                 @"jp2",
                                                 @"jpf",
                                                 @"jpeg",
                                                 @"jpg",
                                                 @"nef",
                                                 @"orf",
                                                 @"pbm",
                                                 @"pgm",
                                                 @"png",
                                                 @"pnm",
                                                 @"ppm",
                                                 @"psd",
                                                 @"raf",
                                                 @"rw2",
                                                 @"rwl",
                                                 @"tga",
                                                 @"tif",
                                                 @"tiff"];
    
    return [supportedExtensions containsObject:self.pathExtension.lowercaseString];
}

- (BOOL)mnz_isVideoPathExtension {
    NSArray<NSString *> *supportedExtensions = @[@"3g2",
                                                 @"3gp",
                                                 @"avi",
                                                 @"m4v",
                                                 @"mov",
                                                 @"mp4",
                                                 @"mqv",
                                                 @"qt"];
    
    return [supportedExtensions containsObject:self.pathExtension.lowercaseString];
}

- (BOOL)mnz_isAudioPathExtension {
    NSArray<NSString *> *supportedExtensions = @[@"aac",
                                                 @"ac3",
                                                 @"aif",
                                                 @"aiff",
                                                 @"au",
                                                 @"caf",
                                                 @"eac3",
                                                 @"flac",
                                                 @"m4a",
                                                 @"mp3",
                                                 @"wav"];
    
    return [supportedExtensions containsObject:self.pathExtension.lowercaseString];
}

- (BOOL)mnz_isMultimediaPathExtension {
    return self.mnz_isVideoPathExtension || self.mnz_isAudioPathExtension;
}

#pragma mark - appData

- (NSString *)mnz_appDataToSaveCameraUploadsCount:(NSUInteger)operationCount {
    return [self stringByAppendingString:[NSString stringWithFormat:@">CU=%tu", operationCount]];
}

- (NSString *)mnz_appDataToSaveInPhotosApp {
    return [self stringByAppendingString:@">SaveInPhotosApp"];
}

- (NSString *)mnz_appDataToAttachToChatID:(uint64_t)chatId {
    return [self stringByAppendingString:[NSString stringWithFormat:@">attachToChatID=%llu", chatId]];
}

- (NSString *)mnz_appDataToSaveCoordinates:(NSString *)coordinates {
    return (coordinates ? [self stringByAppendingString:[NSString stringWithFormat:@">setCoordinates=%@", coordinates]] : self);
}

- (NSString *)mnz_appDataToLocalIdentifier:(NSString *)localIdentifier {
    return (localIdentifier ? [self stringByAppendingString:[NSString stringWithFormat:@">localIdentifier=%@", localIdentifier]] : self);
}

#pragma mark - Utils

+ (NSString *)mnz_stringWithoutUnitOfComponents:(NSArray *)componentsSeparatedByStringArray {
    NSString *countString = [componentsSeparatedByStringArray objectAtIndex:0];
    if ([countString isEqualToString:@"Zero"] || ([countString length] == 0)) {
        countString = @"0";
    }
    
    return countString;
}

+ (NSString *)mnz_stringWithoutCountOfComponents:(NSArray *)componentsSeparatedByStringArray {
    NSString *unitString;
    if (componentsSeparatedByStringArray.count == 1) {
        unitString = @"KB";
    } else {
        unitString = [componentsSeparatedByStringArray objectAtIndex:1];
        if ([unitString isEqualToString:@"bytes"] || ([unitString length] == 0)) {
            unitString = @"KB";
        }
    }
    
    return unitString;
}

- (NSString*)mnz_stringBetweenString:(NSString*)start andString:(NSString*)end {
    NSScanner* scanner = [NSScanner scannerWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:start intoString:NULL];
    if ([scanner scanString:start intoString:NULL]) {
        NSString* result = nil;
        if ([scanner scanUpToString:end intoString:&result]) {
            return result;
        }
    }
    return nil;
}

+ (NSString *)mnz_stringByFiles:(NSInteger)files andFolders:(NSInteger)folders {
    if (files > 1 && folders > 1) {
        NSString *filesString = [NSString stringWithFormat:@"%ld", (long)files];
        NSString *foldersString = [NSString stringWithFormat:@"%ld", (long)folders];
        NSString *filesAndFoldersString = AMLocalizedString(@"foldersAndFiles", @"Subtitle shown on folders that gives you information about its content. This case \"[A] = {1+} folders ‚ [B] = {1+} files\"");
        filesAndFoldersString = [filesAndFoldersString stringByReplacingOccurrencesOfString:A withString:foldersString];
        filesAndFoldersString = [filesAndFoldersString stringByReplacingOccurrencesOfString:B withString:filesString];
        return filesAndFoldersString;
    }
    
    if (files > 1 && folders == 1) {
        return [NSString stringWithFormat:AMLocalizedString(@"folderAndFiles", @"Subtitle shown on folders that gives you information about its content. This case \"{1} folder • {1+} file\""), (int)files];
    }
    
    if (files > 1 && !folders) {
        return [NSString stringWithFormat:AMLocalizedString(@"files", @"Subtitle shown on folders that gives you information about its content. This case \"{1+} files\""), (int)files];
    }
    
    if (files == 1 && folders > 1) {
        return [NSString stringWithFormat:AMLocalizedString(@"foldersAndFile", @"Subtitle shown on folders that gives you information about its content. This case \"{1} folder • {1+} file\""), (int)folders];
    }
    
    if (files == 1 && folders == 1) {
        return [NSString stringWithFormat:AMLocalizedString(@"folderAndFile", @"Subtitle shown on folders that gives you information about its content. This case \"{1} folder • {1} file\""), (int)folders];
    }
    
    if (files == 1 && !folders) {
        return [NSString stringWithFormat:AMLocalizedString(@"oneFile", @"Subtitle shown on folders that gives you information about its content. This case \"{1} file\""), (int)files];
    }
    
    if (!files && folders > 1) {
        return [NSString stringWithFormat:AMLocalizedString(@"folders", @"Subtitle shown on folders that gives you information about its content. This case \"{1+} folders\""), (int)folders];
    }
    
    if (!files && folders == 1) {
        return [NSString stringWithFormat:AMLocalizedString(@"oneFolder", @"Subtitle shown on folders that gives you information about its content. This case \"{1} folder\""), (int)folders];
    }
    
    return AMLocalizedString(@"emptyFolder", @"Title shown when a folder doesn't have any files");
}

+ (NSString *)mnz_stringByMissedAudioCalls:(NSInteger)missedAudioCalls andMissedVideoCalls:(NSInteger)missedVideoCalls {
    NSString *missedAudioCallsString = [NSString stringWithFormat:@"%ld", (long)missedAudioCalls];
    NSString *missedVideoCallsString = [NSString stringWithFormat:@"%ld", (long)missedVideoCalls];
    NSString *missedString;
    if (missedVideoCalls == 0) {
        if (missedAudioCalls == 1) {
            missedString = AMLocalizedString(@"missedAudioCall", @"Notification text body shown when you have missed one audio call");
        } else { //missedAudioCalls > 1
            missedString = AMLocalizedString(@"missedAudioCalls", @"Notification text body shown when you have missed several audio calls. [A] = {number of missed audio calls}");
            missedString = [missedString stringByReplacingOccurrencesOfString:A withString:missedAudioCallsString];
        }
    } else if (missedVideoCalls == 1) {
        if (missedAudioCalls == 0) {
            missedString = AMLocalizedString(@"missedVideoCall", @"Notification text body shown when you have missed one video call");
        } else if (missedAudioCalls == 1) {
            missedString = AMLocalizedString(@"missedAudioCallAndMissedVideoCall", @"Notification text body shown when you have missed one audio call and one video call");
        } else { //missedAudioCalls > 1
            missedString = AMLocalizedString(@"missedAudioCallsAndMissedVideoCall", @"Notification text body shown when you have missed several audio calls and one video call. [A] = {number of missed audio calls}");
            missedString = [missedString stringByReplacingOccurrencesOfString:A withString:missedAudioCallsString];
        }
    } else { // missedVideoCalls > 1
        if (missedAudioCalls == 0) {
            missedString = AMLocalizedString(@"missedVideoCalls", @"Notification text body shown when you have missed several video calls. [A] = {number of missed video calls}");
            missedString = [missedString stringByReplacingOccurrencesOfString:A withString:missedVideoCallsString];
        } else if (missedAudioCalls == 1) {
            missedString = AMLocalizedString(@"missedAudioCallAndMissedVideoCalls", @"Notification text body shown when you have missed one audio call and several video calls. [A] = {number of missed video calls}");
            missedString = [missedString stringByReplacingOccurrencesOfString:A withString:missedVideoCallsString];
        } else { //missedAudioCalls > 1
            missedString = AMLocalizedString(@"missedAudioCallsAndMissedVideoCalls", @"Notification text body shown when you have missed several audio calls and video calls. [A] = {number of missed audio calls}. [B] = {number of missed video calls}");
            missedString = [missedString stringByReplacingOccurrencesOfString:A withString:missedString];
            missedString = [missedString stringByReplacingOccurrencesOfString:B withString:missedString];            
        }
    }
    
    return missedString;
}

+ (NSString *)chatStatusString:(MEGAChatStatus)onlineStatus {
    NSString *onlineStatusString;
    switch (onlineStatus) {
        case MEGAChatStatusOffline:
            onlineStatusString = AMLocalizedString(@"offline", @"Title of the Offline section");
            break;
            
        case MEGAChatStatusAway:
            onlineStatusString = AMLocalizedString(@"away", nil);
            break;
            
        case MEGAChatStatusOnline:
            onlineStatusString = AMLocalizedString(@"online", nil);
            break;
            
        case MEGAChatStatusBusy:
            onlineStatusString = AMLocalizedString(@"busy", nil);
            break;
            
        default:
            onlineStatusString = nil;
            break;
    }
    
    return onlineStatusString;
}

+ (NSString *)mnz_stringByEndCallReason:(MEGAChatMessageEndCallReason)endCallReason userHandle:(uint64_t)userHandle duration:(NSInteger)duration {
    NSString *endCallReasonString;
    switch (endCallReason) {
        case MEGAChatMessageEndCallReasonEnded: {
            NSString *durationString = [NSString stringWithFormat:AMLocalizedString(@"duration", @"Displayed after a call had ended, where %@ is the duration of the call (1h, 10seconds, etc)"), [NSString mnz_stringFromCallDuration:duration]];
            NSString *callEnded = AMLocalizedString(@"callEnded", @"When an active call of user A with user B had ended");
            endCallReasonString = [NSString stringWithFormat:@"%@ %@", callEnded, durationString];
            break;
        }
            
        case MEGAChatMessageEndCallReasonRejected:
            endCallReasonString = AMLocalizedString(@"callWasRejected", @"When an outgoing call of user A with user B had been rejected by user B");
            break;
            
        case MEGAChatMessageEndCallReasonNoAnswer:
            if (userHandle == [MEGASdkManager sharedMEGAChatSdk].myUserHandle) {
                endCallReasonString = AMLocalizedString(@"callWasNotAnswered", @"When an active call of user A with user B had not answered");
            } else {
                endCallReasonString = AMLocalizedString(@"missedCall", @"Title of the notification for a missed call");
            }
            
            break;
            
        case MEGAChatMessageEndCallReasonFailed:
            endCallReasonString = AMLocalizedString(@"callFailed", @"When an active call of user A with user B had failed");
            break;
            
        case MEGAChatMessageEndCallReasonCancelled:
            if (userHandle == [MEGASdkManager sharedMEGAChatSdk].myUserHandle) {
                endCallReasonString = AMLocalizedString(@"callWasCancelled", @"When an active call of user A with user B had cancelled");
            } else {
                endCallReasonString = AMLocalizedString(@"missedCall", @"Title of the notification for a missed call");
            }
            break;
            
        default:
            endCallReasonString = @"[Call] End Call Reason Default";
            break;
    }
    return endCallReasonString;
}

- (BOOL)mnz_isValidEmail {
    NSString *emailRegex =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
    
    return [predicate evaluateWithObject:self];
}

- (BOOL)mnz_isEmpty {
    return ![[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length];
}

- (BOOL)mnz_containsInvalidChars {
    return [self rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"|*/:<>?\"\\"]].length;
}

- (NSString *)mnz_removeWebclientFormatters {
    NSString *string;
    string = [self stringByReplacingOccurrencesOfString:@"[A]" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"[/A]" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"[S]" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"[/S]" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"<a href='terms'>" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"<a href=’terms’>" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"</a>" withString:@""];
    
    return string;
}

+ (NSString *)mnz_stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    }
}

+ (NSString *)mnz_stringFromCallDuration:(NSInteger)duration {
    NSInteger ti = duration;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    if (hours > 0) {
        if (hours == 1) {
            if (minutes == 0) {
                return AMLocalizedString(@"1Hour", nil);
            } else if (minutes == 1) {
                return AMLocalizedString(@"1Hour1Minute", nil);
            } else {
                return [NSString stringWithFormat:AMLocalizedString(@"1HourxMinutes", nil), (int)minutes];
            }
        } else {
            if (minutes == 0) {
                return [NSString stringWithFormat:AMLocalizedString(@"xHours", nil), (int)hours];
            } else if (minutes == 1) {
                return [NSString stringWithFormat:AMLocalizedString(@"xHours1Minute", nil), (int)hours];
            } else {
                NSString *durationString = AMLocalizedString(@"xHoursxMinutes", nil);
                durationString = [durationString stringByReplacingOccurrencesOfString:@"%1$d" withString:[NSString stringWithFormat:@"%td", hours]];
                durationString = [durationString stringByReplacingOccurrencesOfString:@"%2$d" withString:[NSString stringWithFormat:@"%td", minutes]];
                return durationString;
            }
        }
    } else if (minutes > 0) {
        if (minutes == 1) {
            return AMLocalizedString(@"1Minute", nil);
        } else {
            NSString *xMinutes = AMLocalizedString(@"xMinutes", nil);
            return [NSString stringWithFormat:@"%@", [xMinutes stringByReplacingOccurrencesOfString:@"[X]" withString:[NSString stringWithFormat:@"%ld", (long)minutes]]];
        }
    } else {
        if (seconds == 1) {
            return AMLocalizedString(@"1Second", nil);
        } else {
            return [NSString stringWithFormat:AMLocalizedString(@"xSeconds", nil), (int) seconds];
        }
    }
}

- (NSString *)SHA256 {
    unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];
    
    CC_SHA256(self.UTF8String, (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], output);
    
    NSMutableString* hash = [NSMutableString stringWithCapacity:outputLength * 2];
    for (unsigned int i = 0; i < outputLength; i++) {
        [hash appendFormat:@"%02x", output[i]];
        output[i] = 0;
    }
    
    return hash;
}

- (BOOL)mnz_isDecimalNumber {
    NSCharacterSet *decimalDigitInvertedCharacterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange range = [self rangeOfCharacterFromSet:decimalDigitInvertedCharacterSet];
    
    return (range.location == NSNotFound);
}

- (BOOL)mnz_containsEmoji {
    __block BOOL containsEmoji = NO;
    
    [self enumerateSubstringsInRange:NSMakeRange(0,
                                                 [self length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop)
     {
         const unichar hs = [substring characterAtIndex:0];
         // surrogate pair
         if (0xd800 <= hs &&
             hs <= 0xdbff)
         {
             if (substring.length > 1)
             {
                 const unichar ls = [substring characterAtIndex:1];
                 const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc &&
                     uc <= 0x1f9c0)
                 {
                     containsEmoji = YES;
                 }
             }
         }
         else if (substring.length > 1)
         {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3 ||
                 ls == 0xfe0f ||
                 ls == 0xd83c)
             {
                 containsEmoji = YES;
             }
         }
         else
         {
             // non surrogate
             if (0x2100 <= hs &&
                 hs <= 0x27ff)
             {
                 containsEmoji = YES;
             }
             else if (0x2B05 <= hs &&
                      hs <= 0x2b07)
             {
                 containsEmoji = YES;
             }
             else if (0x2934 <= hs &&
                      hs <= 0x2935)
             {
                 containsEmoji = YES;
             }
             else if (0x3297 <= hs &&
                      hs <= 0x3299)
             {
                 containsEmoji = YES;
             }
             else if (hs == 0xa9 ||
                      hs == 0xae ||
                      hs == 0x303d ||
                      hs == 0x3030 ||
                      hs == 0x2b55 ||
                      hs == 0x2b1c ||
                      hs == 0x2b1b ||
                      hs == 0x2b50)
             {
                 containsEmoji = YES;
             }
         }
         
         if (containsEmoji)
         {
             *stop = YES;
         }
     }];
    
    return containsEmoji;
}

- (BOOL)mnz_isPureEmojiString {
    if (self.mnz_isEmpty) {
        return NO;
    }
    
    NSArray *wordsArray = [self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *noWhitespacesNorNewlinesString = [wordsArray componentsJoinedByString:@""];
    
    __block BOOL isPureEmojiString = YES;
    
    [noWhitespacesNorNewlinesString enumerateSubstringsInRange:NSMakeRange(0, noWhitespacesNorNewlinesString.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop)
     {
         BOOL containsEmoji = NO;
         const unichar hs = [substring characterAtIndex:0];
         // surrogate pair
         if (0xd800 <= hs &&
             hs <= 0xdbff)
         {
             if (substring.length > 1)
             {
                 const unichar ls = [substring characterAtIndex:1];
                 const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc &&
                     uc <= 0x1f9c0)
                 {
                     containsEmoji = YES;
                 }
             }
         }
         else if (substring.length > 1)
         {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3 ||
                 ls == 0xfe0f ||
                 ls == 0xd83c)
             {
                 containsEmoji = YES;
             }
         }
         else
         {
             // non surrogate
             if (0x2100 <= hs &&
                 hs <= 0x27ff)
             {
                 containsEmoji = YES;
             }
             else if (0x2B05 <= hs &&
                      hs <= 0x2b07)
             {
                 containsEmoji = YES;
             }
             else if (0x2934 <= hs &&
                      hs <= 0x2935)
             {
                 containsEmoji = YES;
             }
             else if (0x3297 <= hs &&
                      hs <= 0x3299)
             {
                 containsEmoji = YES;
             }
             else if (hs == 0xa9 ||
                      hs == 0xae ||
                      hs == 0x303d ||
                      hs == 0x3030 ||
                      hs == 0x2b55 ||
                      hs == 0x2b1c ||
                      hs == 0x2b1b ||
                      hs == 0x2b50)
             {
                 containsEmoji = YES;
             }
         }
         
         if (!containsEmoji)
         {
             isPureEmojiString = NO;
             *stop = YES;
         }
     }];
    
    return isPureEmojiString;
}

- (NSInteger)mnz_emojiCount
{
    __block NSInteger emojiCount = 0;
    
    [self enumerateSubstringsInRange:NSMakeRange(0,
                                                 [self length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop)
     {
         const unichar hs = [substring characterAtIndex:0];
         // surrogate pair
         if (0xd800 <= hs &&
             hs <= 0xdbff)
         {
             if (substring.length > 1)
             {
                 const unichar ls = [substring characterAtIndex:1];
                 const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc &&
                     uc <= 0x1f9c0)
                 {
                     emojiCount = emojiCount + 1;
                 }
             }
         }
         else if (substring.length > 1)
         {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3 ||
                 ls == 0xfe0f ||
                 ls == 0xd83c)
             {
                 emojiCount = emojiCount + 1;
             }
         }
         else
         {
             // non surrogate
             if (0x2100 <= hs &&
                 hs <= 0x27ff)
             {
                 emojiCount = emojiCount + 1;
             }
             else if (0x2B05 <= hs &&
                      hs <= 0x2b07)
             {
                 emojiCount = emojiCount + 1;
             }
             else if (0x2934 <= hs &&
                      hs <= 0x2935)
             {
                 emojiCount = emojiCount + 1;
             }
             else if (0x3297 <= hs &&
                      hs <= 0x3299)
             {
                 emojiCount = emojiCount + 1;
             }
             else if (hs == 0xa9 ||
                      hs == 0xae ||
                      hs == 0x303d ||
                      hs == 0x3030 ||
                      hs == 0x2b55 ||
                      hs == 0x2b1c ||
                      hs == 0x2b1b ||
                      hs == 0x2b50)
             {
                 emojiCount = emojiCount + 1;
             }
         }
     }];
    
    return emojiCount;
}

- (NSString *)mnz_coordinatesOfPhotoOrVideo {
    if (self.mnz_isImagePathExtension) {
        NSURL *fileURL;
        if ([self containsString:@"/tmp/"]) {
            fileURL = [NSURL fileURLWithPath:self];
        } else {
            fileURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:self]];
        }
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
            NSData *data = [NSData dataWithContentsOfURL:fileURL];
            if (data) {
                CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)data, NULL);
                if (imageData) {
                    NSDictionary *metadata = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageData, 0, NULL);
                    
                    CFRelease(imageData);
                    
                    NSDictionary *exifDictionary = [metadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary];
                    if (exifDictionary) {
                        NSNumber *latitude = [exifDictionary objectForKey:@"Latitude"];
                        NSNumber *longitude = [exifDictionary objectForKey:@"Longitude"];
                        if (latitude && longitude) {
                            return [NSString stringWithFormat:@"%@&%@", latitude, longitude];
                        }
                    }
                } else {
                    MEGALogError(@"Create image source with data returns nil");
                }
            } else {
                MEGALogError(@"The data object could not be created");
            }
        } else {
            MEGALogError(@"The file does not exist or its existence could not be determined. File path %@", fileURL);
        }
    }
    
    if (self.mnz_isVideoPathExtension) {
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:self]]];
        for (AVMetadataItem *item in asset.metadata) {
            if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]) {
                NSString *latlon = item.stringValue;
                NSString *latitude  = [latlon substringToIndex:8];
                NSString *longitude = [latlon substringWithRange:NSMakeRange(8, 9)];
                if (latitude && longitude) {
                    return [NSString stringWithFormat:@"%@&%@", latitude, longitude];
                }
            }
        }
    }
    
    return nil;
}

+ (NSString *)mnz_base64FromBase64URLEncoding:(NSString *)base64URLEncondingString {
    base64URLEncondingString = [base64URLEncondingString stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64URLEncondingString = [base64URLEncondingString stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    NSUInteger paddedLength = base64URLEncondingString.length + (4 - (base64URLEncondingString.length % 4));
    NSString *base64FromBase64URLEncoding = [base64URLEncondingString stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
    
    return base64FromBase64URLEncoding;
}

- (NSString *)mnz_relativeLocalPath {
    return [self stringByReplacingOccurrencesOfString:[NSHomeDirectory() stringByAppendingString:@"/"] withString:@""];
}

+ (NSString *)mnz_lastGreenStringFromMinutes:(NSInteger)minutes {    
    NSString *lastSeenMessage;
    if (minutes < 65535) {
        NSDate *dateLastSeen = [NSDate dateWithTimeIntervalSinceNow:-minutes*SECONDS_IN_MINUTE];
        NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
        timeFormatter.dateFormat = @"HH:mm";
        timeFormatter.locale = [NSLocale autoupdatingCurrentLocale];
        NSString *timeString = [timeFormatter stringFromDate:dateLastSeen];
        NSString *dateString = [[NSCalendar currentCalendar] isDateInToday:dateLastSeen] ? AMLocalizedString(@"Today", @"") : [dateLastSeen formattedDateWithFormat:@"dd MMM"];
        lastSeenMessage = AMLocalizedString(@"Last seen [A] at [B]", @"Text to inform the user the 'Last seen' time of a contact, for example 'Last seen 20 Nov 18 at 15:15'");
        lastSeenMessage = [lastSeenMessage stringByReplacingOccurrencesOfString:@"[A]" withString:dateString];
        lastSeenMessage = [lastSeenMessage stringByReplacingOccurrencesOfString:@"[B]" withString:timeString];
    } else {
        lastSeenMessage = AMLocalizedString(@"Last seen a long time ago", @"Text to inform the user the 'Last seen' time of a contact is a long time ago (more than 65535 minutes)");
    }
    return lastSeenMessage;
}

#pragma mark - File names and extensions

+ (NSString *)mnz_fileNameWithDate:(NSDate *)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy'-'MM'-'dd' 'HH'.'mm'.'ss";
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    
    return [dateFormatter stringFromDate:date];
}

- (NSString *)mnz_fileNameWithLowercaseExtension {
    NSString *fileName;
    NSString *extension;
    
    NSMutableArray<NSString *> *fileNameComponents = [[self componentsSeparatedByString:@"."] mutableCopy];
    if (fileNameComponents.count > 1) {
        extension = fileNameComponents.lastObject.lowercaseString;
        [fileNameComponents replaceObjectAtIndex:(fileNameComponents.count - 1) withObject:extension];
    }
    fileName = [fileNameComponents componentsJoinedByString:@"."];
    
    return fileName;
}

- (NSString *)mnz_lastExtensionInLowercase {
    NSString *extension;
    NSMutableArray<NSString *> *fileNameComponents = [[self.lastPathComponent componentsSeparatedByString:@"."] mutableCopy];
    if (fileNameComponents.count > 1) {
        extension = fileNameComponents.lastObject.lowercaseString;
    }
    
    return extension;
}

- (NSString *)mnz_sequentialFileNameInParentNode:(MEGANode *)parentNode {
    NSString *nameWithoutExtension = self.stringByDeletingPathExtension;
    NSString *extension = self.pathExtension;
    int index = 0;
    int listSize = 0;
    
    do {
        if (index != 0) {
            nameWithoutExtension = [self.stringByDeletingPathExtension stringByAppendingString:[NSString stringWithFormat:@"_%d", index]];
        }
        
        MEGANodeList *nameNodeList = [[MEGASdkManager sharedMEGASdk] nodeListSearchForNode:parentNode searchString:[nameWithoutExtension stringByAppendingPathExtension:extension]];
        listSize = nameNodeList.size.intValue;
        index++;
    } while (listSize != 0);
    
    return [nameWithoutExtension stringByAppendingPathExtension:extension];
}

@end
