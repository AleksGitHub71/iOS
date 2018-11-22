
#import "MEGALocalNotificationManager.h"

#import <UserNotifications/UserNotifications.h>

#import "Helper.h"
#import "MEGAGetThumbnailRequestDelegate.h"
#import "MEGAStore.h"
#import "NSString+MNZCategory.h"

@interface MEGALocalNotificationManager ()

@property (nonatomic) MEGAChatMessage *message;
@property (nonatomic) MEGAChatRoom *chatRoom;
@property (nonatomic, getter=isSilent) BOOL silent;

@end

@implementation MEGALocalNotificationManager

- (instancetype)initWithChatRoom:(MEGAChatRoom *)chatRoom message:(MEGAChatMessage *)message silent:(BOOL)silent {
    self = [super init];
    
    if (self) {
        _chatRoom = chatRoom;
        _message = message;
        _silent = silent;
    }
    
    return self;
}

- (void)proccessNotification {
    if (self.message.status == MEGAChatMessageStatusNotSeen) {
        if  (self.message.type == MEGAChatMessageTypeNormal || self.message.type == MEGAChatMessageTypeContact || self.message.type == MEGAChatMessageTypeAttachment) {
            
            if (self.message.deleted) {
                [self removePendingAndDeliveredNotificationForMessage];
            } else {
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                
                UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                content.categoryIdentifier = @"nz.mega.chat.message";
                content.userInfo = @{@"chatId" : @(self.chatRoom.chatId)};
                content.title = self.chatRoom.title;
                
                UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
                NSString *identifier = [NSString stringWithFormat:@"%@%@", [MEGASdk base64HandleForUserHandle:self.chatRoom.chatId], [MEGASdk base64HandleForUserHandle:self.message.messageId]];
                
                if (self.chatRoom.isGroup) {
                    MOUser *user = [[MEGAStore shareInstance] fetchUserWithUserHandle:self.message.userHandle];
                    content.subtitle = user.fullName;
                }
                
                NSString *body;
                BOOL waitForThumbnail = NO;
                if (self.message.type == MEGAChatMessageTypeContact) {
                    if(self.message.usersCount == 1) {
                        body = [NSString stringWithFormat:@"👤 %@", [self.message userNameAtIndex:0]];
                    } else {
                        body = [self.message userNameAtIndex:0];
                        for (NSUInteger i = 1; i < self.message.usersCount; i++) {
                            body = [body stringByAppendingString:[NSString stringWithFormat:@", %@", [self.message userNameAtIndex:i]]];
                        }
                    }
                } else if (self.message.type == MEGAChatMessageTypeAttachment) {
                    MEGANodeList *nodeList = self.message.nodeList;
                    if (nodeList) {
                        if (nodeList.size.integerValue == 1) {
                            MEGANode *node = [nodeList nodeAtIndex:0];
                            
                            if (node.hasThumbnail) {
                                if (node.name.mnz_isVideoPathExtension) {
                                    body = [NSString stringWithFormat:@"📹 %@", node.name];
                                } else if (node.name.mnz_isImagePathExtension) {
                                    body = [NSString stringWithFormat:@"📷 %@", node.name];
                                } else {
                                    body = [NSString stringWithFormat:@"📄 %@", node.name];
                                }
                                
                                waitForThumbnail = YES;
                                NSString *thumbnailFilePath = [Helper pathForNode:node inSharedSandboxCacheDirectory:@"thumbnailsV3"];
                                MEGAGetThumbnailRequestDelegate *getThumbnailRequestDelegate = [[MEGAGetThumbnailRequestDelegate alloc] initWithCompletion:^(MEGARequest *request) {
                                    NSError *error;
                                    if (![[NSFileManager defaultManager] createSymbolicLinkAtPath:[request.file stringByAppendingPathExtension:@"jpg"] withDestinationPath:request.file error:&error]) {
                                        MEGALogError(@"Create symbolic link at path failed %@", error);
                                    }
                                    NSURL *fileURL = [NSURL fileURLWithPath:[request.file stringByAppendingPathExtension:@"jpg"]];
                                    UNNotificationAttachment *notificationAttachment = [UNNotificationAttachment attachmentWithIdentifier:node.base64Handle URL:fileURL options:nil error:&error];
                                    
                                    content.body = body;
                                    
                                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                                        content.sound = nil;
                                    } else {
                                        content.sound = self.isSilent ? nil : [UNNotificationSound defaultSound];
                                    }
                                    
                                    if (!error) {
                                        content.attachments = @[notificationAttachment];
                                    }
                                    UNNotificationRequest *notificationRequest = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
                                    [center addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
                                        if (error) {
                                            MEGALogError(@"Add NotificationRequest failed with error: %@", error);
                                        }
                                    }];
                                }];
                                [[MEGASdkManager sharedMEGASdk] getThumbnailNode:node destinationFilePath:thumbnailFilePath delegate:getThumbnailRequestDelegate];
                            } else {
                                body = [NSString stringWithFormat:@"📄 %@", node.name];
                            }
                        }
                    }
                } else {
                    body = self.message.content;
                }
                
                if (!waitForThumbnail) {
                    if (self.message.isEdited) {
                        content.body = [NSString stringWithFormat:@"%@ %@", self.message.content, AMLocalizedString(@"edited", nil)];
                        content.sound = nil;
                    } else {
                        content.body = body;
                        content.sound = self.isSilent ? nil : [UNNotificationSound defaultSound];
                    }
                    
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        content.sound = nil;
                    }
                    
                    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
                    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                        if (error) {
                            MEGALogError(@"Add NotificationRequest failed with error: %@", error);
                        }
                    }];
                }
            }
            
        } else if (self.message.type == MEGAChatMessageTypeTruncate) {
            [self removeAllPendingAndDeliveredNotificationsForChatRoom];
        }
    } else {
        [self removePendingAndDeliveredNotificationForMessage];
    }
    
    MOMessage *mMessage = [[MEGAStore shareInstance] fetchMessageWithChatId:self.chatRoom.chatId messageId:self.message.messageId];
    if (mMessage) {
        [[MEGAStore shareInstance] deleteMessage:mMessage];
    }
}

#pragma mark - Private

- (void)removeAllPendingAndDeliveredNotificationsForChatRoom {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
        NSString *base64ChatId = [MEGASdk base64HandleForUserHandle:self.chatRoom.chatId];
        for (UNNotification *notification in notifications) {
            if ([notification.request.identifier containsString:base64ChatId]) {
                [center removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
            }
        }
    }];
    
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSString *base64ChatId = [MEGASdk base64HandleForUserHandle:self.chatRoom.chatId];
        for (UNNotificationRequest *request in requests) {
            if ([request.identifier containsString:base64ChatId]) {
                [center removePendingNotificationRequestsWithIdentifiers:@[request.identifier]];
            }
        }
    }];
}

- (void)removePendingAndDeliveredNotificationForMessage {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
        NSString *notificationIdentifier = [NSString stringWithFormat:@"%@%@", [MEGASdk base64HandleForUserHandle:self.chatRoom.chatId], [MEGASdk base64HandleForUserHandle:self.message.messageId]];
        for (UNNotification *notification in notifications) {
            if ([notificationIdentifier isEqualToString:notification.request.identifier]) {
                [center removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
                break;
            }
        }
    }];
    
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSString *notificationIdentifier = [NSString stringWithFormat:@"%@%@", [MEGASdk base64HandleForUserHandle:self.chatRoom.chatId], [MEGASdk base64HandleForUserHandle:self.message.messageId]];
        for (UNNotificationRequest *request in requests) {
            if ([notificationIdentifier isEqualToString:request.identifier]) {
                [center removePendingNotificationRequestsWithIdentifiers:@[request.identifier]];
                break;
            }
        }
    }];
}

@end
