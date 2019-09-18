
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <CoreTelephony/CTCellularData.h>
#import "SVProgressHUD.h"
#import "UIApplication+MNZCategory.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"

@interface MEGAReachabilityManager ()

@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic) NSString *lastKnownAddress;

@property (nonatomic, getter=isMobileDataEnabled) BOOL mobileDataEnabled;
@property (nonatomic) CTCellularDataRestrictedState mobileDataState;

@end

@implementation MEGAReachabilityManager

+ (MEGAReachabilityManager *)sharedManager {
    static MEGAReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

+ (BOOL)isReachable {
    NetworkStatus status = [[[MEGAReachabilityManager sharedManager] reachability] currentReachabilityStatus];
    return status == ReachableViaWiFi || status == ReachableViaWWAN;
}

+ (BOOL)isReachableViaWWAN {
    NetworkStatus status = [[[MEGAReachabilityManager sharedManager] reachability] currentReachabilityStatus];
    return status == ReachableViaWWAN;
}

+ (BOOL)isReachableViaWiFi {
    NetworkStatus status = [[[MEGAReachabilityManager sharedManager] reachability] currentReachabilityStatus];
    return status == ReachableViaWiFi;
}

+ (bool)hasCellularConnection {
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    bool found = false;
    if (getifaddrs(&addrs) == 0) {
        cursor = addrs;
        while (cursor != NULL) {
            NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
            if ([name isEqualToString:@"pdp_ip0"]) {
                found = true;
                break;
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return found;
}

+ (BOOL)isReachableHUDIfNot {
    BOOL isReachable = [self isReachable];
    if (!isReachable) {
        switch (MEGAReachabilityManager.sharedManager.mobileDataState) {
            case kCTCellularDataRestricted:
                [MEGAReachabilityManager.sharedManager mobileDataIsTurnedOffAlert];
                break;
            
            case kCTCellularDataRestrictedStateUnknown:
            case kCTCellularDataNotRestricted:
                [SVProgressHUD showImage:[UIImage imageNamed:@"hudForbidden"] status:NSLocalizedString(@"noInternetConnection", @"Text shown on the app when you don't have connection to the internet or when you have lost it")];
                break;
        }
    }
    
    return isReachable;
}

#pragma mark - Private Initialization

- (id)init {
    self = [super init];
    
    if (self) {
        self.reachability = [Reachability reachabilityForInternetConnection];
        [self.reachability startNotifier];
        _lastKnownAddress = self.currentAddress;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityDidChange:)
                                                     name:kReachabilityChangedNotification object:nil];
        [self monitorAccessToMobileData];
    }
    
    return self;
}

#pragma mark - Get IP Address

- (NSString *)currentAddress {
    NSString *address = nil;
    
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success == 0) {
        
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] || [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
                    char straddr[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, (void *)&((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr, straddr, sizeof(straddr));
                    
                    if(strncasecmp(straddr, "127.", 4) && strncasecmp(straddr, "169.254.", 8)) {
                        address = [NSString stringWithUTF8String:straddr];
                    }
                }
            }
            
            if(temp_addr->ifa_addr->sa_family == AF_INET6) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] || [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
                    char straddr[INET6_ADDRSTRLEN];
                    inet_ntop(AF_INET6, (void *)&((struct sockaddr_in6 *)temp_addr->ifa_addr)->sin6_addr, straddr, sizeof(straddr));
                    
                    if(strncasecmp(straddr, "FE80:", 5) && strncasecmp(straddr, "FD00:", 5)) {
                        address = [NSString stringWithFormat:@"[%@]", [NSString stringWithUTF8String:straddr]];
                    }
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    
    return address;
}

- (void)retryOrReconnect {
    if ([MEGAReachabilityManager isReachable]) {
        NSString *currentAddress = self.currentAddress;
        if ([self.lastKnownAddress isEqualToString:currentAddress]) {
            MEGALogDebug(@"IP didn't change (%@), retrying...", self.lastKnownAddress);
            [self retryPendingConnections];
        } else {
            MEGALogDebug(@"IP has changed (%@ -> %@), reconnecting...", self.lastKnownAddress, currentAddress);
            [self reconnect];
            self.lastKnownAddress = currentAddress;
        }
    }
}

- (void)retryPendingConnections {
    [[MEGASdkManager sharedMEGASdk] retryPendingConnections];
    [[MEGASdkManager sharedMEGAChatSdk] retryPendingConnections];
}

- (void)reconnect {
    MEGALogDebug(@"Reconnecting...");
    [[MEGASdkManager sharedMEGASdk] reconnect];
    [[MEGASdkManager sharedMEGASdkFolder] reconnect];
    [[MEGASdkManager sharedMEGAChatSdk] reconnect];
}

- (void)monitorAccessToMobileData {
    CTCellularData *cellularData = CTCellularData.alloc.init;
    [self recordMobileDataState:cellularData.restrictedState];
    
    [cellularData setCellularDataRestrictionDidUpdateNotifier:^(CTCellularDataRestrictedState state) {
        [self recordMobileDataState:state];
    }];
}

- (void)recordMobileDataState:(CTCellularDataRestrictedState)state {
    self.mobileDataState = state;
    switch (state) {
        case kCTCellularDataRestrictedStateUnknown:
            MEGALogInfo(@"Access to Mobile Data is unknonwn");
            self.mobileDataEnabled = YES; //To avoid possible issues with devices that do not have 'Mobile Data', this value is YES when the state is unknown.
            break;
            
        case kCTCellularDataRestricted:
            MEGALogInfo(@"Access to Mobile Data is restricted");
            self.mobileDataEnabled = NO;
            break;
            
        case kCTCellularDataNotRestricted:
            MEGALogInfo(@"Access to Mobile Data is NOT restricted");
            self.mobileDataEnabled = YES;
            break;
    }
}

- (void)mobileDataIsTurnedOffAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Mobile Data is turned off", @"Information shown when the user has disabled the 'Mobile Data' setting for MEGA in the iOS Settings.") message:NSLocalizedString(@"You can turn on mobile data for this app in Settings.", @"Extra information shown when the user has disabled the 'Mobile Data' setting for MEGA in the iOS Settings.") preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"settingsTitle", @"Title of the Settings section") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:nil]];
    
    [UIApplication.mnz_presentingViewController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Reachability Changes

- (void)reachabilityDidChange:(NSNotification *)notification {
    [self retryOrReconnect];

    if ([MEGAReachabilityManager isReachable]) {
        NSUInteger chatsConnected = 0;
        MEGAChatListItemList *chatList = [[MEGASdkManager sharedMEGAChatSdk] activeChatListItems];
        for (NSUInteger i=0; i<chatList.size; i++) {
            MEGAChatListItem *chat = [chatList chatListItemAtIndex:i];
            MEGAChatConnection state = [[MEGASdkManager sharedMEGAChatSdk] chatConnectionState:chat.chatId];
            if (state == MEGAChatConnectionOnline) {
                chatsConnected++;
            }
        }
        self.chatRoomListState = chatsConnected == chatList.size ? MEGAChatRoomListStateOnline : MEGAChatRoomListStateInProgress;
    } else {
        self.chatRoomListState = MEGAChatRoomListStateOffline;
    }
}

@end
