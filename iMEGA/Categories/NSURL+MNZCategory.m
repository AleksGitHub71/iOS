
#import "NSURL+MNZCategory.h"

#import <SafariServices/SafariServices.h>

#import "SVProgressHUD.h"
#import "MEGAReachabilityManager.h"
#import "UIApplication+MNZCategory.h"
#import "NSFileManager+MNZCategory.h"

@implementation NSURL (MNZCategory)

- (void)mnz_presentSafariViewController {
    if (!([self.scheme.lowercaseString isEqualToString:@"http"] || [self.scheme.lowercaseString isEqualToString:@"https"])) {
        if (@available(iOS 10.0, *)) {
            [UIApplication.sharedApplication openURL:self options:@{} completionHandler:^(BOOL success) {
                if (success) {
                    MEGALogInfo(@"URL opened on other app");
                } else {
                    MEGALogInfo(@"URL NOT opened");
                    [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"linkNotValid", @"Message shown when the user clicks on an link that is not valid")];
                }
            }];
        } else {
            if ([UIApplication.sharedApplication openURL:self]) {
                MEGALogInfo(@"URL opened on other app");
            } else {
                MEGALogInfo(@"URL NOT opened");
                [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"linkNotValid", @"Message shown when the user clicks on an link that is not valid")];
            }
        }
        return;
    }
    
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:self];
        if (@available(iOS 10.0, *)) {
            safariViewController.preferredControlTintColor = UIColor.mnz_redMain;
        } else {
            safariViewController.view.tintColor = UIColor.mnz_redMain;
        }
        
        [UIApplication.mnz_visibleViewController presentViewController:safariViewController animated:YES completion:nil];
    }
}

- (URLType)mnz_type {
    URLType type = URLTypeDefault;
    
    if ([self.absoluteString rangeOfString:@"file:///"].location != NSNotFound) {
        return URLTypeOpenInLink;
    }
    
    NSString *afterSlashesString = [self mnz_afterSlashesString];
    
    if (afterSlashesString.length < 2) {
        return URLTypeDefault;
    }
    
    if (afterSlashesString.length >= 2 && [[afterSlashesString substringToIndex:2] isEqualToString:@"#!"]) {
        return URLTypeFileLink;
    }
    
    if (afterSlashesString.length >= 3 && [[afterSlashesString substringToIndex:3] isEqualToString:@"#F!"]) {
        return URLTypeFolderLink;
    }
    
    if (afterSlashesString.length >= 3 && [[afterSlashesString substringToIndex:3] isEqualToString:@"#P!"]) {
        return URLTypeEncryptedLink;
    }
    
    if (afterSlashesString.length >= 8 && [[afterSlashesString substringToIndex:8] isEqualToString:@"#confirm"]) {
        return URLTypeConfirmationLink;
    }
    if (afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"confirm"]) {
        return URLTypeConfirmationLink;
    }
    
    if (afterSlashesString.length >= 10 && [[afterSlashesString substringToIndex:10] isEqualToString:@"#newsignup"]) {
        return URLTypeNewSignUpLink;
    }
    
    if ((afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"#backup"]) || (afterSlashesString.length >= 6 && [[afterSlashesString substringToIndex:6] isEqualToString:@"backup"])) {
        return URLTypeBackupLink;
    }
    
    if (afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"#fm/ipc"]) {
        return URLTypeIncomingPendingContactsLink;
    }
    
    if (afterSlashesString.length >= 6 && [[afterSlashesString substringToIndex:6] isEqualToString:@"fm/ipc"]) {
        return URLTypeIncomingPendingContactsLink;
    }
    
    if (afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"#verify"]) {
        return URLTypeChangeEmailLink;
    }
    
    if (afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"#cancel"]) {
        return URLTypeCancelAccountLink;
    }
    
    if (afterSlashesString.length >= 8 && [[afterSlashesString substringToIndex:8] isEqualToString:@"#recover"]) {
        return URLTypeRecoverLink;
    }
    
    if (afterSlashesString.length >= 3 && [[afterSlashesString substringToIndex:3] isEqualToString:@"#C!"]) {
        return URLTypeContactLink;
    }
    if (afterSlashesString.length >= 2 && [[afterSlashesString substringToIndex:2] isEqualToString:@"C!"]) {
        return URLTypeContactLink;
    }
    
    if ((afterSlashesString.length >= 8 && [[afterSlashesString substringToIndex:8] isEqualToString:@"#fm/chat"]) || (afterSlashesString.length >= 7 && [[afterSlashesString substringToIndex:7] isEqualToString:@"fm/chat"])) {
        return URLTypeOpenChatSectionLink;
    }
    
    if (afterSlashesString.length >= 14 && [[afterSlashesString substringToIndex:14] isEqualToString:@"#loginrequired"]) {
        return URLTypeLoginRequiredLink;
    }
    
    if (afterSlashesString.length >= 5 && [[afterSlashesString substringToIndex:5] isEqualToString:@"chat/"]) {
        return URLTypePublicChatLink;
    }
    
    if ((afterSlashesString.length == 9) && [afterSlashesString hasPrefix:@"#"]) {
        return URLTypeHandleLink;
    }
    
    if (afterSlashesString.length >= 12 && [[afterSlashesString substringToIndex:12] isEqualToString:@"achievements"]) {
        return URLTypeAchievementsLink;
    }
    
    return type;
}

- (NSString *)mnz_MEGAURL {
    NSString *afterSlashesString = [self mnz_afterSlashesString];
    if ([afterSlashesString hasPrefix:@"#"]) {
        return [NSString stringWithFormat:@"https://mega.nz/%@", [self mnz_afterSlashesString]];
    } else {
        return [NSString stringWithFormat:@"https://mega.nz/#%@", [self mnz_afterSlashesString]];
    }
}

- (NSString *)mnz_afterSlashesString {
    NSString *afterSlashesString;
    
    if ([self.scheme isEqualToString:@"mega"]) {
        // mega://<afterSlashesString>
        afterSlashesString = [self.absoluteString substringFromIndex:7];
    } else {
        // http(s)://(www.)mega(.co).nz/<afterSlashesString>
        NSArray<NSString *> *components = [self.absoluteString componentsSeparatedByString:@"/"];
        afterSlashesString = @"";
        if (components.count < 3 || (![components[2] hasSuffix:@"mega.nz"] && ![components[2] isEqualToString:@"mega.co.nz"])) {
            return afterSlashesString;
        }
        for (NSUInteger i = 3; i < components.count; i++) {
            afterSlashesString = [NSString stringWithFormat:@"%@%@/", afterSlashesString, [components objectAtIndex:i]];
        }
        if (afterSlashesString.length > 0) {
            afterSlashesString = [afterSlashesString substringToIndex:(afterSlashesString.length - 1)];
        }
    }
    
    return afterSlashesString;
}

- (NSURL *)mnz_updatedURLWithCurrentAddress {
    if (!MEGAReachabilityManager.isReachableViaWiFi) {
        return self;
    }
    
    // @see MegaTCPServer::getLink
    NSString *loopbackAddress = @"[::1]";
    NSString *currentAddress = MEGAReachabilityManager.sharedManager.currentAddress;
    return currentAddress ? [NSURL URLWithString:[self.absoluteString stringByReplacingOccurrencesOfString:loopbackAddress withString:currentAddress]] : self;
}

- (BOOL)mnz_moveToDirectory:(NSURL *)directoryURL renameTo:(NSString *)fileName error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    if (![NSFileManager.defaultManager fileExistsAtPath:self.path]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        }
        
        return NO;
    }
    
    NSError *fileError;
    if ([NSFileManager.defaultManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&fileError]) {
        NSURL *newFileURL = [directoryURL URLByAppendingPathComponent:fileName isDirectory:NO];
        [NSFileManager.defaultManager removeItemIfExistsAtURL:newFileURL];
        if ([NSFileManager.defaultManager moveItemAtURL:self toURL:newFileURL error:&fileError]) {
            return YES;
        } else {
            MEGALogError(@"%@ error %@ when to copy new file %@", self, fileError, newFileURL);
            if (error != NULL) {
                *error = fileError;
            }
            
            return NO;
        }
    } else {
        MEGALogError(@"%@ error %@ when to create directory %@", self, fileError, directoryURL);
        if (error != NULL) {
            *error = fileError;
        }
        
        return NO;
    }
}

@end
