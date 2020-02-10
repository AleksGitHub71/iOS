
#import "MEGAChatMessage+MNZCategory.h"

#import <objc/runtime.h>

#import "Helper.h"
#import "MEGAAttachmentMediaItem.h"
#import "MEGACallManagementMediaItem.h"
#import "MEGADialogMediaItem.h"
#import "MEGAChatGenericRequestDelegate.h"
#import "MEGAFetchNodesRequestDelegate.h"
#import "MEGAGetPublicNodeRequestDelegate.h"
#import "MEGALocationMediaItem.h"
#import "MEGAGenericRequestDelegate.h"
#import "MEGAPhotoMediaItem.h"
#import "MEGARichPreviewMediaItem.h"
#import "MEGASdkManager.h"
#import "MEGAStore.h"
#import "MEGAVoiceClipMediaItem.h"
#import "NSAttributedString+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "NSURL+MNZCategory.h"

static const void *chatIdTagKey = &chatIdTagKey;
static const void *attributedTextTagKey = &attributedTextTagKey;
static const void *warningDialogTagKey = &warningDialogTagKey;
static const void *MEGALinkTagKey = &MEGALinkTagKey;
static const void *nodeTagKey = &nodeTagKey;
static const void *richStringTagKey = &richStringTagKey;
static const void *richNumberTagKey = &richNumberTagKey;
static const void *richTitleTagKey = &richTitleTagKey;

@implementation MEGAChatMessage (MNZCategory)

- (NSString *)senderId {
    return [NSString stringWithFormat:@"%llu", self.userHandle];
}

- (NSString *)senderDisplayName {
    return [NSString stringWithFormat:@"%llu", self.userHandle];
}

- (NSDate *)date {
    return self.timestamp;
}

- (BOOL)isMediaMessage {
    BOOL mediaMessage = NO;
    
    if (!self.isDeleted && (self.type == MEGAChatMessageTypeContact || self.type == MEGAChatMessageTypeAttachment || self.type == MEGAChatMessageTypeVoiceClip || (self.warningDialog > MEGAChatMessageWarningDialogNone) || (self.type == MEGAChatMessageTypeContainsMeta && [self containsMetaAnyValue]) || self.richNumber || self.type == MEGAChatMessageTypeCallEnded || self.type == MEGAChatMessageTypeCallStarted)) {
        mediaMessage = YES;
    }
    
    return mediaMessage;
}

- (BOOL)containsMetaAnyValue {
    if (self.containsMeta.richPreview.title && ![self.containsMeta.richPreview.title isEqualToString:@""]) {
        return YES;
    }
    if (self.containsMeta.richPreview.previewDescription && ![self.containsMeta.richPreview.previewDescription isEqualToString:@""]) {
        return YES;
    }
    if (self.containsMeta.richPreview.image && ![self.containsMeta.richPreview.image isEqualToString:@""]) {
        return YES;
    }
    if (self.containsMeta.richPreview.icon && ![self.containsMeta.richPreview.icon isEqualToString:@""]) {
        return YES;
    }
    if (self.containsMeta.richPreview.url && ![self.containsMeta.richPreview.url isEqualToString:@""]) {
        return YES;
    }
    if (self.containsMeta.geolocation.image) {
        return YES;
    }
    return NO;
}

- (BOOL)containsMEGALink {
    if (self.MEGALink) {
        return YES;
    }
    if (!self.content) {
        return NO;
    }
    
    NSDataDetector* linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    for (NSTextCheckingResult *match in [linkDetector matchesInString:self.content options:0 range:NSMakeRange(0, self.content.length)]) {
        URLType type = [match.URL mnz_type];
        if (type == URLTypeFileLink || type == URLTypeFolderLink || type == URLTypePublicChatLink) {
            self.MEGALink = match.URL;
            switch (type) {
                case URLTypeFileLink: {
                    MEGAGetPublicNodeRequestDelegate *delegate = [[MEGAGetPublicNodeRequestDelegate alloc] initWithCompletion:^(MEGARequest *request, MEGAError *error) {
                        self.richNumber = request.publicNode.size;
                        self.node = request.publicNode;
                    }];
                    [[MEGASdkManager sharedMEGASdk] publicNodeForMegaFileLink:[self.MEGALink mnz_MEGAURL] delegate:delegate];
                    
                    break;
                }
                    
                case URLTypeFolderLink: {
                    MEGAGenericRequestDelegate *delegate = [[MEGAGenericRequestDelegate alloc] initWithCompletion:^(MEGARequest *request, MEGAError *error) {
                        if (!error.type) {
                            self.richString = [NSString mnz_stringByFiles:request.megaFolderInfo.files andFolders:request.megaFolderInfo.folders];
                            self.richNumber = @(request.megaFolderInfo.currentSize);
                            self.richTitle = request.text;
                        }

                    }];
                    [MEGASdkManager.sharedMEGASdk getPublicLinkInformationWithFolderLink:self.MEGALink.mnz_MEGAURL delegate:delegate];
                    
                    break;
                }
                    
                case URLTypePublicChatLink: {
                    MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                        if (error.type == MEGAErrorTypeApiOk || error.type == MEGAErrorTypeApiEExist) {
                            self.richString = request.text;
                            self.richNumber = @(request.number);
                        }
                    }];
                    [[MEGASdkManager sharedMEGAChatSdk] checkChatLink:self.MEGALink delegate:delegate];
                    
                    break;
                }
                    
                default:
                    break;
            }

            return YES;
        }
    }
    
    return NO;
}

- (BOOL)shouldShowForwardAccessory {
    BOOL shouldShowForwardAccessory = NO;
    
    if (!self.isDeleted && (self.type == MEGAChatMessageTypeContact || self.type == MEGAChatMessageTypeAttachment || (self.type == MEGAChatMessageTypeVoiceClip && !self.richNumber) || (self.type == MEGAChatMessageTypeContainsMeta && [self containsMetaAnyValue]) || self.node)) {
        shouldShowForwardAccessory = YES;
    }
    
    return shouldShowForwardAccessory;
}

- (BOOL)localPreview {
    if (self.type == MEGAChatMessageTypeAttachment) {
        MEGANode *node = [self.nodeList nodeAtIndex:0];
        NSString *previewFilePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"previewsV3"] stringByAppendingPathComponent:node.base64Handle];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:previewFilePath]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)text {
    NSString *text;
    uint64_t myHandle = [[MEGASdkManager sharedMEGAChatSdk] myUserHandle];
    
    UIFont *textFontRegular = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    UIFont *textFontMedium = [[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline] fontWithWeight:UIFontWeightMedium];
    UIFont *textFontMediumFootnote = [[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] fontWithWeight:UIFontWeightMedium];

    if (self.isDeleted) {
        text = AMLocalizedString(@"thisMessageHasBeenDeleted", @"A log message in a chat to indicate that the message has been deleted by the user.");
    } else if (self.isManagementMessage) {
        NSString *fullNameDidAction = [self fullNameDidAction];
        NSString *fullNameReceiveAction = [self fullNameReceiveAction];
        
        switch (self.type) {
            case MEGAChatMessageTypeAlterParticipants:
                switch (self.privilege) {
                    case -1: {
                        if (fullNameDidAction && ![fullNameReceiveAction isEqualToString:fullNameDidAction]) {
                            NSString *wasRemovedFromTheGroupChatBy = AMLocalizedString(@"wasRemovedFromTheGroupChatBy", @"A log message in a chat conversation to tell the reader that a participant [A] was removed from the group chat by the moderator [B]. Please keep [A] and [B], they will be replaced by the participant and the moderator names at runtime. For example: Alice was removed from the group chat by Frank.");
                            wasRemovedFromTheGroupChatBy = [wasRemovedFromTheGroupChatBy stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameReceiveAction];
                            wasRemovedFromTheGroupChatBy = [wasRemovedFromTheGroupChatBy stringByReplacingOccurrencesOfString:@"[B]" withString:fullNameDidAction];
                            text = wasRemovedFromTheGroupChatBy;
                            
                            NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:wasRemovedFromTheGroupChatBy attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[wasRemovedFromTheGroupChatBy rangeOfString:fullNameReceiveAction]];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:self.userHandle] } range:[wasRemovedFromTheGroupChatBy rangeOfString:fullNameDidAction]];
                            self.attributedText = mutableAttributedString;
                        } else {
                            NSString *leftTheGroupChat = AMLocalizedString(@"leftTheGroupChat", @"A log message in the chat conversation to tell the reader that a participant [A] left the group chat. For example: Alice left the group chat.");
                            leftTheGroupChat = [leftTheGroupChat stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameReceiveAction];
                            text = leftTheGroupChat;
                            
                            NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:leftTheGroupChat attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[leftTheGroupChat rangeOfString:fullNameReceiveAction]];
                            self.attributedText = mutableAttributedString;
                        }
                        break;
                    }
                        
                    case -2: {
                        if (fullNameDidAction && ![fullNameReceiveAction isEqualToString:fullNameDidAction]) {
                            NSString *joinedTheGroupChatByInvitationFrom = AMLocalizedString(@"joinedTheGroupChatByInvitationFrom", @"A log message in a chat conversation to tell the reader that a participant [A] was added to the chat by a moderator [B]. Please keep the [A] and [B] placeholders, they will be replaced by the participant and the moderator names at runtime. For example: Alice joined the group chat by invitation from Frank.");
                            joinedTheGroupChatByInvitationFrom = [joinedTheGroupChatByInvitationFrom stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameReceiveAction];
                            joinedTheGroupChatByInvitationFrom = [joinedTheGroupChatByInvitationFrom stringByReplacingOccurrencesOfString:@"[B]" withString:fullNameDidAction];
                            text = joinedTheGroupChatByInvitationFrom;
                            
                            NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:joinedTheGroupChatByInvitationFrom attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[joinedTheGroupChatByInvitationFrom rangeOfString:fullNameReceiveAction]];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:self.userHandle] } range:[joinedTheGroupChatByInvitationFrom rangeOfString:fullNameDidAction]];
                            self.attributedText = mutableAttributedString;
                        } else {
                            NSString *joinedTheGroupChat = [NSString stringWithFormat:AMLocalizedString(@"%@ joined the group chat.", @"Management message shown in a chat when the user %@ joined it from a public chat link"), fullNameReceiveAction];
                            text = joinedTheGroupChat;
                            
                            NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:joinedTheGroupChat attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                            [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[joinedTheGroupChat rangeOfString:fullNameReceiveAction]];
                            self.attributedText = mutableAttributedString;
                        }
                        break;
                    }
                        
                    default:
                        break;
                }
                break;
                
            case MEGAChatMessageTypeTruncate: {
                NSString *clearedTheChatHistory = AMLocalizedString(@"clearedTheChatHistory", @"A log message in the chat conversation to tell the reader that a participant [A] cleared the history of the chat. For example, Alice cleared the chat history.");
                clearedTheChatHistory = [clearedTheChatHistory stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameDidAction];
                text = clearedTheChatHistory;
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:clearedTheChatHistory attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[clearedTheChatHistory rangeOfString:fullNameDidAction]];
                self.attributedText = mutableAttributedString;
                break;
            }
                
            case MEGAChatMessageTypePrivilegeChange: {
                NSString *wasChangedToBy = AMLocalizedString(@"wasChangedToBy", @"A log message in a chat to display that a participant's permission was changed and by whom. This message begins with the user's name who receive the permission change [A]. [B] will be replaced with the permission name (such as Moderator or Read-only) and [C] will be replaced with the person who did it. Please keep the [A], [B] and [C] placeholders, they will be replaced at runtime. For example: Alice Jones was changed to Moderator by John Smith.");
                wasChangedToBy = [wasChangedToBy stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameReceiveAction];
                NSString *privilige;
                switch (self.privilege) {
                    case 0:
                        privilige = AMLocalizedString(@"readOnly", @"Permissions given to the user you share your folder with");
                        break;
                        
                    case 2:
                        privilige = AMLocalizedString(@"standard", @"The Standard permission level in chat. With the standard permissions a participant can read and type messages in a chat.");
                        break;
                        
                    case 3:
                        privilige = AMLocalizedString(@"moderator", @"The Moderator permission level in chat. With moderator permissions a participant can manage the chat");
                        break;
                        
                    default:
                        break;
                }
                wasChangedToBy = [wasChangedToBy stringByReplacingOccurrencesOfString:@"[B]" withString:privilige];
                wasChangedToBy = [wasChangedToBy stringByReplacingOccurrencesOfString:@"[C]" withString:fullNameDidAction];
                text = wasChangedToBy;
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:wasChangedToBy attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[wasChangedToBy rangeOfString:fullNameReceiveAction]];
                [mutableAttributedString addAttribute:NSFontAttributeName value:textFontMedium range:[wasChangedToBy rangeOfString:privilige]];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:self.userHandle] } range:[wasChangedToBy rangeOfString:fullNameDidAction]];
                self.attributedText = mutableAttributedString;
                break;
            }
                
            case MEGAChatMessageTypeChatTitle: {
                NSString *changedGroupChatNameTo = AMLocalizedString(@"changedGroupChatNameTo", @"A hint message in a group chat to indicate the group chat name is changed to a new one. Please keep %s when translating this string which will be replaced with the name at runtime.");
                changedGroupChatNameTo = [changedGroupChatNameTo stringByReplacingOccurrencesOfString:@"[A]" withString:fullNameDidAction];
                changedGroupChatNameTo = [changedGroupChatNameTo stringByReplacingOccurrencesOfString:@"[B]" withString:(self.content ? self.content : @" ")];
                text = changedGroupChatNameTo;
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:changedGroupChatNameTo attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[changedGroupChatNameTo rangeOfString:fullNameDidAction]];
                if (self.content) [mutableAttributedString addAttribute:NSFontAttributeName value:textFontMedium range:[changedGroupChatNameTo rangeOfString:self.content]];
                self.attributedText = mutableAttributedString;
                break;
            }
                
            case MEGAChatMessageTypePublicHandleCreate: {
                NSString *publicHandleCreated = [NSString stringWithFormat:AMLocalizedString(@"%@ created a public link for the chat.", @"Management message shown in a chat when the user %@ creates a public link for the chat"), fullNameReceiveAction];
                text = publicHandleCreated;
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:publicHandleCreated attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[publicHandleCreated rangeOfString:fullNameReceiveAction]];
                
                self.attributedText = mutableAttributedString;
                break;
            }
                
            case MEGAChatMessageTypePublicHandleDelete: {
                NSString *publicHandleRemoved = [NSString stringWithFormat:AMLocalizedString(@"%@ removed a public link for the chat.", @"Management message shown in a chat when the user %@ removes a public link for the chat"), fullNameReceiveAction];
                text = publicHandleRemoved;
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:publicHandleRemoved attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[publicHandleRemoved rangeOfString:fullNameReceiveAction]];
                
                self.attributedText = mutableAttributedString;
                break;
            }
                
            case MEGAChatMessageTypeSetPrivateMode: {
                NSString *setPrivateMode = [NSString stringWithFormat:AMLocalizedString(@"%@ enabled Encrypted Key Rotation", @"Management message shown in a chat when the user %@ enables the 'Encrypted Key Rotation'"), fullNameReceiveAction];
                NSString *keyRotationExplanation = AMLocalizedString(@"Key rotation is slightly more secure, but does not allow you to create a chat link and new participants will not see past messages.", @"Footer text to explain what means 'Encrypted Key Rotation'");
                text = [NSString stringWithFormat:@"%@\n\n%@", setPrivateMode, keyRotationExplanation];
                
                NSMutableAttributedString *mutableAttributedString = [NSMutableAttributedString.alloc initWithString:text attributes:@{NSFontAttributeName:textFontRegular, NSForegroundColorAttributeName:UIColor.mnz_label}];
                [mutableAttributedString addAttributes:@{ NSFontAttributeName: textFontMedium, NSLinkAttributeName: [self chatPeerOptionsUrlStringForUserHandle:[self userHandleReceiveAction]] } range:[text rangeOfString:fullNameReceiveAction]];
                [mutableAttributedString addAttribute:NSFontAttributeName value:textFontMedium range:[text rangeOfString:AMLocalizedString(@"Encrypted Key Rotation", nil)]];
                [mutableAttributedString addAttribute:NSFontAttributeName value:textFontMediumFootnote range:[text rangeOfString:keyRotationExplanation]];
                [mutableAttributedString addAttribute:NSForegroundColorAttributeName value:[UIColor mnz_secondaryGrayForTraitCollection:UIScreen.mainScreen.traitCollection] range:[text rangeOfString:keyRotationExplanation]];
                
                self.attributedText = mutableAttributedString;
                break;
            }
                
            default:
                text = @"default";
                break;
        }
    } else if (self.type == MEGAChatMessageTypeContact) {
        text = @"MEGAChatMessageTypeContact";
    } else if (self.type == MEGAChatMessageTypeAttachment) {
        text = @"MEGAChatMessageTypeAttachment";
    } else if (self.type == MEGAChatMessageTypeRevokeAttachment) {
        text = @"MEGAChatMessageTypeRevokeAttachment";
    } else if (self.type == MEGAChatMessageTypeVoiceClip) {
        text = @"MEGAChatMessageTypeVoiceClip";
    } else if (self.type == MEGAChatMessageTypeContainsMeta && self.containsMeta.type == MEGAChatContainsMetaTypeInvalid) {
        text = @"Message contains invalid meta";
    } else {
        UIColor *textColor = self.userHandle == myHandle ? UIColor.whiteColor : UIColor.mnz_label;
        
        self.attributedText = [NSAttributedString mnz_attributedStringFromMessage:self.content
                                                                             font:textFontRegular
                                                                            color:textColor];
        
        if (self.isEdited && self.type != MEGAChatMessageTypeContainsMeta) {
            NSAttributedString *edited = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", AMLocalizedString(@"edited", @"A log message in a chat to indicate that the message has been edited by the user.")] attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1].italic, NSForegroundColorAttributeName:textColor}];
            NSMutableAttributedString *attributedText = [self.attributedText mutableCopy];
            [attributedText appendAttributedString:edited];
            self.attributedText = attributedText;
        }
        
        text = self.attributedText.string;
    }
    return text;
}

- (id<JSQMessageMediaData>)media {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 200;
    });
    
    id<JSQMessageMediaData> media = [cache objectForKey:@(self.messageHash)];
    if (media) {
        return media;
    }
    
    switch (self.type) {
        case MEGAChatMessageTypeContact:
            media = [[MEGAAttachmentMediaItem alloc] initWithMEGAChatMessage:self];
            break;
            
        case MEGAChatMessageTypeAttachment: {
            MEGANode *node = [self.nodeList nodeAtIndex:0];
            if (self.nodeList.size.integerValue > 1 || (!node.name.mnz_isImagePathExtension && !node.name.mnz_isVideoPathExtension)) {
                media = [[MEGAAttachmentMediaItem alloc] initWithMEGAChatMessage:self];
            } else {
                media = [[MEGAPhotoMediaItem alloc] initWithMEGAChatMessage:self];
            }
            
            break;
        }
            
        case MEGAChatMessageTypeVoiceClip:
            media = [[MEGAVoiceClipMediaItem alloc] initWithMEGAChatMessage:self];
            break;
            
        case MEGAChatMessageTypeContainsMeta: {
            if (self.containsMeta.type == MEGAChatContainsMetaTypeRichPreview) {
                media = [[MEGARichPreviewMediaItem alloc] initWithMEGAChatMessage:self];
            } else if (self.containsMeta.type == MEGAChatContainsMetaTypeGeolocation) {
                media = [[MEGALocationMediaItem alloc] initWithMEGAChatMessage:self];
            }
            break;
        }
            
        case MEGAChatMessageTypeNormal: {
            if (self.warningDialog > MEGAChatMessageWarningDialogNone) {
                media = [[MEGADialogMediaItem alloc] initWithMEGAChatMessage:self];
            } else if (self.richNumber) {
                media = [[MEGARichPreviewMediaItem alloc] initWithMEGAChatMessage:self];
            }
            
            break;
        }
            
        case MEGAChatMessageTypeCallStarted:
        case MEGAChatMessageTypeCallEnded:
            media = [[MEGACallManagementMediaItem alloc] initWithMEGAChatMessage:self];
            break;
            
        default:
            break;
    }
    
    if (media && self.type != MEGAChatMessageTypeContact) {
        [cache setObject:media forKey:@(self.messageHash)];
    }
    return media;
}

- (NSUInteger)messageHash {
    return self.hash;
}

- (NSString *)fullNameDidAction {
    NSString *fullNameDidAction;
    
    if ([MEGASdkManager sharedMEGAChatSdk].myUserHandle == self.userHandle) {
        fullNameDidAction = [MEGASdkManager sharedMEGAChatSdk].myFullname;
    } else {
        fullNameDidAction = [self fullNameByHandle:self.userHandle];
    }
    
    return fullNameDidAction;
}

- (NSString *)fullNameReceiveAction {
    NSString *fullNameReceiveAction;
    uint64_t tempHandle = [self userHandleReceiveAction];
    
    if ([MEGASdkManager sharedMEGAChatSdk].myUserHandle == tempHandle) {
        fullNameReceiveAction = [MEGASdkManager sharedMEGAChatSdk].myFullname;
    } else {
        fullNameReceiveAction = [self fullNameByHandle:tempHandle];
    }
    
    return fullNameReceiveAction;
}

- (NSString *)fullNameByHandle:(uint64_t)handle {
    NSString *fullName = @"";
    
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithUserHandle:handle];
    if (moUser) {
        if (!moUser.nickname.mnz_isEmpty) {
            fullName = moUser.nickname;
        } else {
            fullName = moUser.fullName;
        }
    }
    
    return fullName;
}

- (uint64_t)userHandleReceiveAction {
    return self.type == MEGAChatMessageTypeAlterParticipants || self.type == MEGAChatMessageTypePrivilegeChange ? self.userHandleOfAction : self.userHandle;
}

- (NSString *)chatPeerOptionsUrlStringForUserHandle:(uint64_t)userHandle {
    return [NSString stringWithFormat:@"mega://chatPeerOptions#%@", [MEGASdk base64HandleForUserHandle:userHandle]];
}

#pragma mark - NSObject

- (NSUInteger)hash {
    NSUInteger contentHash = self.type == MEGAChatMessageTypeAttachment || self.type == MEGAChatMessageTypeVoiceClip ? (NSUInteger)[self.nodeList nodeAtIndex:0].handle : self.content.hash ^ self.richNumber.hash;
    NSUInteger metaHash = self.type == MEGAChatMessageTypeContainsMeta ? self.containsMeta.type : MEGAChatContainsMetaTypeInvalid;
    return self.chatId ^ self.messageId ^ contentHash ^ self.warningDialog ^ metaHash ^ self.localPreview;
}

- (id)debugQuickLookObject {
    return [self.media mediaView] ?: [self.media mediaPlaceholderView];
}

#pragma mark - Properties

- (uint64_t)chatId {
    return ((NSNumber *)objc_getAssociatedObject(self, chatIdTagKey)).unsignedLongLongValue;
}

- (void)setChatId:(uint64_t)chatId {
    objc_setAssociatedObject(self, &chatIdTagKey, @(chatId), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSAttributedString *)attributedText {
    return objc_getAssociatedObject(self, attributedTextTagKey);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    objc_setAssociatedObject(self, &attributedTextTagKey, attributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (MEGAChatMessageWarningDialog)warningDialog {
    return ((NSNumber *)objc_getAssociatedObject(self, warningDialogTagKey)).integerValue;
}

- (void)setWarningDialog:(MEGAChatMessageWarningDialog)warningDialog {
    objc_setAssociatedObject(self, &warningDialogTagKey, @(warningDialog), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)MEGALink {
    return objc_getAssociatedObject(self, MEGALinkTagKey);
}

- (void)setMEGALink:(NSURL *)MEGALink {
    objc_setAssociatedObject(self, &MEGALinkTagKey, MEGALink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (MEGANode *)node {
    return objc_getAssociatedObject(self, nodeTagKey);
}

- (void)setNode:(MEGANode *)node {
    objc_setAssociatedObject(self, &nodeTagKey, node, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)richString {
    return objc_getAssociatedObject(self, richStringTagKey);
}

- (void)setRichString:(NSString *)richString {
    objc_setAssociatedObject(self, &richStringTagKey, richString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)richNumber {
    return objc_getAssociatedObject(self, richNumberTagKey);
}

- (void)setRichNumber:(NSNumber *)richNumber {
    objc_setAssociatedObject(self, &richNumberTagKey, richNumber, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)richTitle {
    return objc_getAssociatedObject(self, richTitleTagKey);
}

- (void)setRichTitle:(NSString *)richTitle {
    objc_setAssociatedObject(self, &richTitleTagKey, richTitle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
