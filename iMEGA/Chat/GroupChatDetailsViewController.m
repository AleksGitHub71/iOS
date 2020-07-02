#import "GroupChatDetailsViewController.h"

#import "UIImage+GKContact.h"
#import "SVProgressHUD.h"

#import "MEGAReachabilityManager.h"
#import "UIAlertAction+MNZCategory.h"
#import "UIImageView+MNZCategory.h"
#import "UITextField+MNZCategory.h"

#import "ChatRoomsViewController.h"
#import "ContactsViewController.h"
#import "ContactDetailsViewController.h"
#import "CustomModalAlertViewController.h"
#import "GroupChatDetailsViewTableViewCell.h"

#import "MEGAInviteContactRequestDelegate.h"
#import "MEGANavigationController.h"
#import "MEGASdkManager.h"
#import "MEGAGlobalDelegate.h"
#import "MEGAArchiveChatRequestDelegate.h"
#import "MEGAChatGenericRequestDelegate.h"
#import "MEGAStore.h"
#import "MEGA-Swift.h"

#import "MEGA-Swift.h"

typedef NS_ENUM(NSUInteger, GroupChatDetailsSection) {
    GroupChatDetailsSectionChatNotifications = 0,
    GroupChatDetailsSectionRenameGroup,
    GroupChatDetailsSectionSharedFiles,
    GroupChatDetailsSectionGetChatLink,
    GroupChatDetailsSectionClearChatHistory,
    GroupChatDetailsSectionArchiveChat,
    GroupChatDetailsSectionLeaveGroup,
    GroupChatDetailsSectionEncryptedKeyRotation,
    GroupChatDetailsSectionObservers,
    GroupChatDetailsSectionParticipants,
};

@interface GroupChatDetailsViewController () <MEGAChatRequestDelegate, MEGAChatDelegate, MEGAGlobalDelegate, GroupChatDetailsViewTableViewCellDelegate, PushNotificationControlProtocol>

@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *participantsLabel;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIView *participantsHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *participantsHeaderViewLabel;

@property (strong, nonatomic) NSMutableArray<NSNumber *> *participantsMutableArray;
@property (nonatomic) NSMutableDictionary<NSString *, NSIndexPath *> *indexPathsMutableDictionary;
@property (nonatomic) NSMutableSet<NSNumber *> *requestedParticipantsMutableSet;

@property (strong, nonatomic) ChatNotificationControl *chatNotificationControl;

@end

@implementation GroupChatDetailsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = AMLocalizedString(@"info", @"A button label. The button allows the user to get more info of the current context");
    self.requestedParticipantsMutableSet = NSMutableSet.new;
    self.chatNotificationControl = [ChatNotificationControl.alloc initWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    [[MEGASdkManager sharedMEGAChatSdk] addChatDelegate:self];
    [MEGASdkManager.sharedMEGAChatSdk addChatRequestDelegate:self];
    
    [self updateHeadingView];
    [self setParticipants];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
    [[MEGASdkManager sharedMEGAChatSdk] removeChatDelegate:self];
    [MEGASdkManager.sharedMEGAChatSdk removeChatRequestDelegate:self];
}

- (BOOL)hidesBottomBarWhenPushed {
    return YES;
}

#pragma mark - Private

- (void)updateHeadingView {
    self.chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:self.chatRoom.chatId];
    self.nameLabel.text = self.chatRoom.chatTitle;
    
    CGSize avatarSize = self.avatarImageView.frame.size;
    UIImage *avatarImage = [UIImage imageForName:self.chatRoom.title.uppercaseString size:avatarSize backgroundColor:[UIColor mnz_gray999999] textColor:[UIColor whiteColor] font:[UIFont mnz_SFUIRegularWithSize:(avatarSize.width/2.0f)]];
    self.avatarImageView.image = avatarImage;
    
    if (self.chatRoom.ownPrivilege < MEGAChatRoomPrivilegeRo) {
        self.participantsLabel.text = AMLocalizedString(@"Inactive chat", @"Subtitle of chat screen when the chat is inactive");
    } else {
        NSInteger peers = self.chatRoom.peerCount + (!self.chatRoom.isPreview ? 1 : 0);
        self.participantsLabel.text = (peers == 1) ? [NSString stringWithFormat:AMLocalizedString(@"%d participant", @"Singular of participant. 1 participant").capitalizedString, 1] : [NSString stringWithFormat:AMLocalizedString(@"%d participants", @"Singular of participant. 1 participant").capitalizedString, peers];
    }
}

- (void)setParticipants {
    self.participantsMutableArray = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < self.chatRoom.peerCount; i++) {
        uint64_t peerHandle = [self.chatRoom peerHandleAtIndex:i];
        if ([self.chatRoom peerPrivilegeByHandle:peerHandle] > MEGAChatRoomPrivilegeRm) {
            [self.participantsMutableArray addObject:[NSNumber numberWithUnsignedLongLong:peerHandle]];
        }
    }
    
    if (!self.chatRoom.isPreview) {
        uint64_t myHandle = [[MEGASdkManager sharedMEGAChatSdk] myUserHandle];
        [self.participantsMutableArray addObject:[NSNumber numberWithUnsignedLongLong:myHandle]];
    }
    
    self.indexPathsMutableDictionary = [[NSMutableDictionary alloc] initWithCapacity:self.participantsMutableArray.count];
}

- (void)loadParticipantsFromIndex:(NSUInteger)index {
    if (index >= self.participantsMutableArray.count) {
        return;
    }
    
    NSUInteger participantsToLoad = 20;
    NSUInteger topIndex = MIN(index + participantsToLoad, self.participantsMutableArray.count);
    NSMutableArray<NSNumber *> *usersHandles = [NSMutableArray.alloc initWithCapacity:participantsToLoad];
    for (NSUInteger i = index; i < topIndex; i++) {
        NSNumber *handle = [self.participantsMutableArray objectAtIndex:i];
        if (![MEGASdkManager.sharedMEGAChatSdk userFullnameFromCacheByUserHandle:handle.unsignedLongLongValue] && ![self.requestedParticipantsMutableSet containsObject:handle]) {
            [usersHandles addObject:handle];
            [self.requestedParticipantsMutableSet addObject:handle];
        }
    }
    if (usersHandles.count) {
        [MEGASdkManager.sharedMEGAChatSdk loadUserAttributesForChatId:self.chatRoom.chatId usersHandles:usersHandles delegate:self];
    }
}

- (void)alertTextFieldDidChange:(UITextField *)textField {
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController) {
        UIAlertAction *rightButtonAction = alertController.actions.lastObject;
        BOOL enableRightButton = NO;
        if ((textField.text.length > 0) && ![textField.text isEqualToString:self.chatRoom.title] && ![[textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""] && ([textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 31)) {
            enableRightButton = YES;
        }
        rightButtonAction.enabled = enableRightButton;
    }
}

- (void)showClearChatHistoryAlert {
    UIAlertController *clearChatHistoryAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.") message:AMLocalizedString(@"clearTheFullMessageHistory", @"A confirmation message for a user to confirm that they want to clear the history of a chat.") preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"continue", @"'Next' button in a dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [[MEGASdkManager sharedMEGAChatSdk] clearChatHistory:self.chatRoom.chatId delegate:self];
    }];
    
    [clearChatHistoryAlertController addAction:cancelAction];
    [clearChatHistoryAlertController addAction:continueAction];
    
    [self presentViewController:clearChatHistoryAlertController animated:YES completion:nil];
}

- (void)showArchiveChatAlert {
    NSString *title = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChatMessage", @"Confirmation message for user to confirm it will unarchive an archived chat.") : AMLocalizedString(@"archiveChatMessage", @"Confirmation message on archive chat dialog for user to confirm.");
    UIAlertController *archiveAlertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [archiveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    [archiveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        MEGAArchiveChatRequestDelegate *archiveChatRequesDelegate = [[MEGAArchiveChatRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
            if (chatRoom.isArchived) {
                if (self.navigationController.childViewControllers.count >= 3) {
                    NSUInteger MessagesVCIndex = self.navigationController.childViewControllers.count - 2;
                    [MEGASdkManager.sharedMEGAChatSdk closeChatRoom:chatRoom.chatId delegate:self.navigationController.childViewControllers[MessagesVCIndex]];
                }
                [self.navigationController popToRootViewControllerAnimated:YES];
            } else {
                self.chatRoom = chatRoom;
                [self.tableView reloadData];
            }
        }];
        [[MEGASdkManager sharedMEGAChatSdk] archiveChat:self.chatRoom.chatId archive:!self.chatRoom.isArchived delegate:archiveChatRequesDelegate];
    }]];
    
    [self presentViewController:archiveAlertController animated:YES completion:nil];
}

- (void)showLeaveChatAlert {
    UIAlertController *leaveAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"youWillNoLongerHaveAccessToThisConversation", @"Alert text that explains what means confirming the action 'Leave'") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"leave", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[MEGASdkManager sharedMEGAChatSdk] leaveChat:self.chatRoom.chatId];
    }]];
    
    [self presentViewController:leaveAlertController animated:YES completion:nil];
}

- (void)addParticipant {
    MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsNavigationControllerID"];
    ContactsViewController *contactsVC = navigationController.viewControllers.firstObject;
    contactsVC.contactsMode = ContactsModeChatAddParticipant;
    NSMutableDictionary *participantsMutableDictionary = [[NSMutableDictionary alloc] init];
    NSUInteger peerCount = self.chatRoom.peerCount;
    for (NSUInteger i = 0; i < peerCount; i++) {
        uint64_t peerHandle = [self.chatRoom peerHandleAtIndex:i];
        if ([self.chatRoom peerPrivilegeByHandle:peerHandle] > MEGAChatRoomPrivilegeRm) {
            [participantsMutableDictionary setObject:[NSNumber numberWithUnsignedLongLong:peerHandle] forKey:[NSNumber numberWithUnsignedLongLong:peerHandle]];
        }
    }
    contactsVC.participantsMutableDictionary = participantsMutableDictionary.copy;
    
    contactsVC.userSelected = ^void(NSArray *users) {
        for (NSInteger i = 0; i < users.count; i++) {
            MEGAUser *user = [users objectAtIndex:i];
            [[MEGASdkManager sharedMEGAChatSdk] inviteToChat:self.chatRoom.chatId user:user.handle privilege:MEGAChatRoomPrivilegeStandard delegate:self];
        }
    };
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)renameChatGroup {
    UIAlertController *renameGroupAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"renameGroup", @"The title of a menu button which allows users to rename a group chat.") message:AMLocalizedString(@"renameNodeMessage", @"Hint text to suggest that the user have to write the new name for the file or folder") preferredStyle:UIAlertControllerStyleAlert];
    
    [renameGroupAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.chatRoom.title;
        [textField addTarget:self action:@selector(alertTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        textField.shouldReturnCompletion = ^BOOL(UITextField *textField) {
            return ((textField.text.length > 0) && ![textField.text isEqualToString:self.chatRoom.title] && ![[textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""] && ([textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 31));
        };
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"rename", @"Title for the action that allows you to rename a file or folder") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        UITextField *textField = [[renameGroupAlertController textFields] firstObject];
        NSString *newGroupName = textField.text;
        [[MEGASdkManager sharedMEGAChatSdk] setChatTitle:self.chatRoom.chatId title:newGroupName delegate:self];
    }];
    
    [renameGroupAlertController addAction:cancelAction];
    [renameGroupAlertController addAction:renameAction];
    
    renameAction.enabled = NO;
    
    [self presentViewController:renameGroupAlertController animated:YES completion:nil];
}

- (void)presentNoChatLinkAvailable {
    CustomModalAlertViewController *customModalAlertVC = [[CustomModalAlertViewController alloc] init];
    customModalAlertVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    customModalAlertVC.image = [UIImage imageNamed:@"chatLinkCreation"];
    customModalAlertVC.viewTitle = self.chatRoom.title;
    customModalAlertVC.firstButtonTitle = AMLocalizedString(@"close", @"A button label. The button allows the user to close the conversation.");
    customModalAlertVC.link = AMLocalizedString(@"No chat link available.", @"In some cases, a user may try to get the link for a chat room, but if such is not set by an operator - it would say \"not link available\" and not auto create it.");
    __weak typeof(CustomModalAlertViewController) *weakCustom = customModalAlertVC;
    customModalAlertVC.firstCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:nil];
    };
    
    [self presentViewController:customModalAlertVC animated:YES completion:nil];
}

- (void)presentChatLinkOptionsWithLink:(NSString *)link {
    CustomModalAlertViewController *customModalAlertVC = [[CustomModalAlertViewController alloc] init];
    customModalAlertVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    customModalAlertVC.image = [UIImage imageNamed:@"chatLinkCreation"];
    customModalAlertVC.viewTitle = self.chatRoom.title;
    customModalAlertVC.detail = AMLocalizedString(@"People can join your group by using this link.", @"Text explaining users how the chat links work.");
    customModalAlertVC.firstButtonTitle = AMLocalizedString(@"share", @"Button title which, if tapped, will trigger the action of sharing with the contact or contacts selected ");
    customModalAlertVC.link = link;
    if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
        customModalAlertVC.secondButtonTitle = AMLocalizedString(@"delete", nil);
    }
    customModalAlertVC.dismissButtonTitle = AMLocalizedString(@"dismiss", @"Label for any 'Dismiss' button, link, text, title, etc. - (String as short as possible).");
    __weak typeof(CustomModalAlertViewController) *weakCustom = customModalAlertVC;
    customModalAlertVC.firstCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:^{            
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[link] applicationActivities:nil];
            if (UIDevice.currentDevice.iPadDevice) {
                activityVC.popoverPresentationController.sourceView = self.view;
                activityVC.popoverPresentationController.sourceRect = self.view.frame;
                
            }
            [self presentViewController:activityVC animated:YES completion:nil];
        }];
    };
    
    customModalAlertVC.secondCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:^{
            MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                if (!error.type) {
                    [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"linkRemoved", @"Message shown when the link to a file or folder has been removed")];
                }
            }];
            [[MEGASdkManager sharedMEGAChatSdk] removeChatLink:self.chatRoom.chatId delegate:delegate];
        }];
    };
    
    customModalAlertVC.dismissCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:nil];
    };
    
    [self presentViewController:customModalAlertVC animated:YES completion:nil];
}

- (BOOL)shouldShowChatNotificationEnabledCell {
    return (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 1 : 0;
}

#pragma mark - IBActions

- (IBAction)notificationsSwitchValueChanged:(UISwitch *)sender {
    //TODO: Enable/disable notifications
}

- (IBAction)didTapPermissionsButton:(UIButton *)sender {
    NSInteger index = (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) ? (sender.tag - 1) : sender.tag;
    
    uint64_t userHandle = [self.participantsMutableArray objectAtIndex:index].unsignedLongLongValue;
    NSString *peerEmail = [MEGASdkManager.sharedMEGAChatSdk userEmailFromCacheByUserHandle:userHandle];
    
    if (index != (self.participantsMutableArray.count - 1)) {
        NSMutableArray<ActionSheetAction *> *actions = NSMutableArray.new;
        MEGAChatRoomPrivilege privilege = [self.chatRoom peerPrivilegeByHandle:userHandle];
        
        if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
            __weak __typeof__(self) weakSelf = self;
            
            [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"moderator", @"The Moderator permission level in chat. With moderator permissions a participant can manage the chat.") detail:privilege == MEGAChatRoomPrivilegeModerator ? @"✓" : @"" image:[UIImage imageNamed:@"moderator"] style:UIAlertActionStyleDefault actionHandler:^{
                [MEGASdkManager.sharedMEGAChatSdk updateChatPermissions:weakSelf.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeModerator delegate:weakSelf];
            }]];
            [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"standard", @"The Standard permission level in chat. With the standard permissions a participant can read and type messages in a chat.") detail:privilege == MEGAChatRoomPrivilegeStandard ? @"✓" : @"" image:[UIImage imageNamed:@"standard"] style:UIAlertActionStyleDefault actionHandler:^{
                [MEGASdkManager.sharedMEGAChatSdk updateChatPermissions:weakSelf.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeStandard delegate:weakSelf];
            }]];
            [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"readOnly", @"Permissions given to the user you share your folder with") detail:privilege == MEGAChatRoomPrivilegeRo ? @"✓" : @"" image:[UIImage imageNamed:@"readOnly"] style:UIAlertActionStyleDefault actionHandler:^{
                [MEGASdkManager.sharedMEGAChatSdk updateChatPermissions:weakSelf.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeRo delegate:weakSelf];
            }]];
            
            if (peerEmail) {
                MEGAUser *user = [[MEGASdkManager sharedMEGASdk] contactForEmail:peerEmail];
                if (!user || user.visibility != MEGAUserVisibilityVisible) {
                    [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"addContact", @"Alert title shown when you select to add a contact inserting his/her email") detail:nil image:[UIImage imageNamed:@"add"] style:UIAlertActionStyleDefault actionHandler:^{
                        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                            MEGAInviteContactRequestDelegate *inviteContactRequestDelegate = [MEGAInviteContactRequestDelegate.alloc initWithNumberOfRequests:1];
                            [MEGASdkManager.sharedMEGASdk inviteContactWithEmail:peerEmail message:@"" action:MEGAInviteActionAdd delegate:inviteContactRequestDelegate];
                        }
                    }]];
                }
            
            }
            [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"removeParticipant", @"A button title which removes a participant from a chat.") detail:nil image:[UIImage imageNamed:@"delete"] style:UIAlertActionStyleDestructive actionHandler:^{
                [MEGASdkManager.sharedMEGAChatSdk removeFromChat:self.chatRoom.chatId userHandle:userHandle delegate:weakSelf];
            }]];
        } else {
            if (peerEmail) {
                MEGAUser *user = [[MEGASdkManager sharedMEGASdk] contactForEmail:peerEmail];
                if (!user || user.visibility != MEGAUserVisibilityVisible) {
                    [actions addObject:[ActionSheetAction.alloc initWithTitle:AMLocalizedString(@"addContact", @"Alert title shown when you select to add a contact inserting his/her email") detail:nil image:[UIImage imageNamed:@"add"] style:UIAlertActionStyleDefault actionHandler:^{
                        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                            MEGAInviteContactRequestDelegate *inviteContactRequestDelegate = [MEGAInviteContactRequestDelegate.alloc initWithNumberOfRequests:1];
                            [MEGASdkManager.sharedMEGASdk inviteContactWithEmail:peerEmail message:@"" action:MEGAInviteActionAdd delegate:inviteContactRequestDelegate];
                        }
                    }]];
                }
            }
        }
        
        if (actions.count > 0) {
            ActionSheetViewController *permissionsActionSheet = [ActionSheetViewController.alloc initWithActions:actions headerTitle:AMLocalizedString(@"permissions", @"Title of the view that shows the kind of permissions (Read Only, Read & Write or Full Access) that you can give to a shared folder ") dismissCompletion:nil sender:sender];
            [self presentViewController:permissionsActionSheet animated:YES completion:nil];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.participantsMutableArray.count == 1 && [self.participantsMutableArray[0] isEqual:[NSNumber numberWithUnsignedLongLong:MEGASdkManager.sharedMEGAChatSdk.myUserHandle]]) {
        return 9;
    } else {
        return 10;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    switch (section) {
        case GroupChatDetailsSectionChatNotifications:
            numberOfRows = [self shouldShowChatNotificationEnabledCell] ? 1 : 0;
            break;
            
        case GroupChatDetailsSectionRenameGroup:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 1 : 0;
            break;

        case GroupChatDetailsSectionSharedFiles:
            numberOfRows = 1;
            break;
            
        case GroupChatDetailsSectionGetChatLink:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo && self.chatRoom.isPublicChat && !self.chatRoom.isPreview) ? 1 : 0;
            break;
            
        case GroupChatDetailsSectionClearChatHistory:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 1 : 0;
            break;
            
        case GroupChatDetailsSectionArchiveChat:
            numberOfRows = self.chatRoom.isPreview ? 0 : 1;
            break;
            
        case GroupChatDetailsSectionLeaveGroup:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 1 : 0;
            break;
            
        case GroupChatDetailsSectionEncryptedKeyRotation: {
            numberOfRows = (!self.chatRoom.isPublicChat || self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 1 : 0;
            break;
        }
            
        case GroupChatDetailsSectionObservers:
            numberOfRows = self.chatRoom.previewersCount ? 1 : 0;
            break;
            
        case GroupChatDetailsSectionParticipants:
            numberOfRows = self.participantsMutableArray.count;
            
            if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
                numberOfRows += 1;
            }
            break;
            
        default:
            break;
    }
    
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GroupChatDetailsViewTableViewCell *cell;
    
    if (indexPath.section != GroupChatDetailsSectionParticipants && indexPath.section != GroupChatDetailsSectionObservers && indexPath.section != GroupChatDetailsSectionChatNotifications) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsLeaveGroupTypeID" forIndexPath:indexPath];
    }
    
    switch (indexPath.section) {
        case GroupChatDetailsSectionChatNotifications:
            cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsNotificationsTypeID" forIndexPath:indexPath];
            [self.chatNotificationControl configureWithCell:(id<ChatNotificationControlCellProtocol>)cell
                                                     chatId:self.chatRoom.chatId];
            cell.delegate = self;
            break;
            
        case GroupChatDetailsSectionRenameGroup:
            cell.leftImageView.image = [UIImage imageNamed:@"renameGroup"];
            cell.leftImageView.tintColor = UIColor.mnz_gray777777;
            cell.nameLabel.text = AMLocalizedString(@"renameGroup", @"The title of a menu button which allows users to rename a group chat.");
            break;
            
        case GroupChatDetailsSectionSharedFiles:
            cell.leftImageView.image = [UIImage imageNamed:@"sharedFiles"];
            cell.nameLabel.text =  AMLocalizedString(@"Shared Files", @"Header of block with all shared files in chat.");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        case GroupChatDetailsSectionGetChatLink:
            cell.leftImageView.image = [UIImage imageNamed:@"Link_grey"];
            cell.nameLabel.text = AMLocalizedString(@"Get Chat Link", @"");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        case GroupChatDetailsSectionClearChatHistory:
            cell.leftImageView.image = [UIImage imageNamed:@"clearChatHistory"];
            cell.nameLabel.text = AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.");
            break;
            
        case GroupChatDetailsSectionArchiveChat:
            cell.leftImageView.image = self.chatRoom.isArchived ? [UIImage imageNamed:@"unArchiveChat"] : [UIImage imageNamed:@"archiveChat_gray"];
            cell.nameLabel.text = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChat", @"The title of the dialog to unarchive an archived chat.") : AMLocalizedString(@"archiveChat", @"Title of button to archive chats.");
            cell.nameLabel.textColor = self.chatRoom.isArchived ? UIColor.mnz_redMain : UIColor.mnz_black333333;
            break;
            
        case GroupChatDetailsSectionLeaveGroup:
            cell.leftImageView.image = [UIImage imageNamed:@"leaveGroup"];
            cell.nameLabel.text = self.chatRoom.isPreview ? AMLocalizedString(@"close", nil) : AMLocalizedString(@"leaveGroup", @"Button title that allows the user to leave a group chat.");
            cell.nameLabel.textColor = UIColor.mnz_redMain;
            break;

        case GroupChatDetailsSectionEncryptedKeyRotation:
            cell.nameLabel.text = self.chatRoom.isPublicChat ? AMLocalizedString(@"Enable Encrypted Key Rotation", @"Title show in a cell where the users can enable the 'Encrypted Key Rotation'") : AMLocalizedString(@"Encrypted Key Rotation", @"Label in a cell where you can enable the 'Encrypted Key Rotation'");
            cell.leftImageView.hidden = YES;
            if (self.chatRoom.isPublicChat) {
                cell.enableLabel.hidden = YES;
                cell.nameLabel.enabled = cell.userInteractionEnabled = self.chatRoom.peerCount <= 100;
            } else {
                cell.enableLabel.hidden = cell.userInteractionEnabled = NO;
            }
            cell.enableLabel.text = AMLocalizedString(@"Enabled", @"The label of the toggle switch to indicate that file versioning is enabled.");
            break;
            
        case GroupChatDetailsSectionObservers:
            cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsObserversTypeID" forIndexPath:indexPath];
            cell.leftImageView.image = [UIImage imageNamed:@"chatObservers"];
            cell.emailLabel.text = AMLocalizedString(@"Observers", @"Users previewing a public chat");
            cell.rightLabel.text = [NSString stringWithFormat:@"%tu", self.chatRoom.previewersCount];
            break;
            
        case GroupChatDetailsSectionParticipants: {
            if ((indexPath.row == 0) && (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator)) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantEmailTypeID" forIndexPath:indexPath];
                cell.leftImageView.image = [UIImage imageNamed:@"inviteToChat"];
                cell.emailLabel.text = AMLocalizedString(@"addParticipant", @"Button label. Allows to add contacts in current chat conversation.");
                cell.onlineStatusView.backgroundColor = nil;
                [cell.permissionsButton setImage:nil forState:UIControlStateNormal];
                cell.permissionsButton.tag = indexPath.row;
                
                return cell;
            }
            
            NSInteger index = (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) ? (indexPath.row - 1) : indexPath.row;
            
            uint64_t handle = [[self.participantsMutableArray objectAtIndex:index] unsignedLongLongValue];
            NSString *base64Handle = [MEGASdk base64HandleForUserHandle:handle];
            
            [self.indexPathsMutableDictionary setObject:indexPath forKey:base64Handle];
            
            NSString *peerFullname;
            NSString *peerEmail;
            MEGAChatRoomPrivilege privilege;
            if (handle == [[MEGASdkManager sharedMEGAChatSdk] myUserHandle]) {
                NSString *myFullname = [[MEGASdkManager sharedMEGAChatSdk] myFullname];
                peerFullname = [NSString stringWithFormat:@"%@ (%@)", myFullname, AMLocalizedString(@"me", @"The title for my message in a chat. The message was sent from yourself.")];
                peerEmail = [[MEGASdkManager sharedMEGAChatSdk] myEmail];
                privilege = self.chatRoom.ownPrivilege;
            } else {
                peerFullname = [MEGASdkManager.sharedMEGAChatSdk userFullnameFromCacheByUserHandle:handle];
                peerEmail = [MEGASdkManager.sharedMEGAChatSdk userEmailFromCacheByUserHandle:handle] ?: @"";
                if (!peerFullname) {
                    peerFullname = @"";
                    if (![self.requestedParticipantsMutableSet containsObject:[self.participantsMutableArray objectAtIndex:index]]) {
                        [self loadParticipantsFromIndex:index];
                    }
                }
                privilege = [self.chatRoom peerPrivilegeAtIndex:index];
            }
            
            BOOL isNameEmpty = [[peerFullname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
            if (isNameEmpty) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantEmailTypeID" forIndexPath:indexPath];
            } else {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantTypeID" forIndexPath:indexPath];
                cell.nameLabel.text = peerFullname;
            }
            
            [cell.leftImageView mnz_setImageForUserHandle:handle];
            cell.onlineStatusView.backgroundColor = [UIColor mnz_colorForStatusChange:[[MEGASdkManager sharedMEGAChatSdk] userOnlineStatus:handle]];
            
            cell.emailLabel.text = peerEmail;
            
            UIImage *permissionsImage = nil;
            switch (privilege) {
                case MEGAChatRoomPrivilegeUnknown:
                case MEGAChatRoomPrivilegeRm:
                    break;
                    
                case MEGAChatRoomPrivilegeRo:
                    permissionsImage = [UIImage imageNamed:@"readOnly"];
                    break;
                    
                case MEGAChatRoomPrivilegeStandard:
                    permissionsImage = [UIImage imageNamed:@"standard"];
                    break;
                    
                case MEGAChatRoomPrivilegeModerator:
                    permissionsImage = [UIImage imageNamed:@"moderator"];
                    break;
            }
            [cell.permissionsButton setImage:permissionsImage forState:UIControlStateNormal];
            cell.permissionsButton.tag = indexPath.row;
            MEGAUser *user = [MEGASdkManager.sharedMEGASdk contactForEmail:base64Handle];
            cell.verifiedImageView.hidden = ![MEGASdkManager.sharedMEGASdk areCredentialsVerifiedOfUser:user];
            break;
        }
            
        default:
            break;
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == GroupChatDetailsSectionParticipants) {
        self.participantsHeaderViewLabel.text = [AMLocalizedString(@"participants", @"Label to describe the section where you can see the participants of a group chat") uppercaseString];
        return self.participantsHeaderView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    CGFloat height;
    switch (section) {
        case GroupChatDetailsSectionChatNotifications:
            height = [self shouldShowChatNotificationEnabledCell] ? 20.0 : 0.1f;
            break;
            
        case GroupChatDetailsSectionRenameGroup:
            height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionSharedFiles:
            height = 10.0f;
            break;
            
        case GroupChatDetailsSectionGetChatLink:
            if (self.chatRoom.isPublicChat) {
                if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
                    height = 10.0f;
                } else if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo && !self.chatRoom.isPreview) {
                    height = 20.0f;
                } else {
                    height = 0.1f;
                }
            } else {
                height = 0.1f;
            }
            break;
            
        case GroupChatDetailsSectionClearChatHistory:
            height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionArchiveChat:
            if (self.chatRoom.isPreview) {
                height = 0.1f;
            } else {
                if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) {
                    height = 10.0f;
                } else if ( self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) {
                    if (self.chatRoom.isPublicChat) {
                        height = 10.0f;
                    } else {
                        height = 20.0f;
                    }
                } else {
                    height = 20.0f;
                }
            }
            
            break;
            
        case GroupChatDetailsSectionLeaveGroup:
            height = self.chatRoom.isPreview ? 20.0f : 10.0f;
            break;
            
        case GroupChatDetailsSectionEncryptedKeyRotation:
            height = (!self.chatRoom.isPublicChat || self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionObservers:
            height = self.chatRoom.previewersCount ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionParticipants:
            height = 24.0f;
            break;
            
        default:
            height = 0.1f;
            break;
    }
    
    return height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    CGFloat height;
    switch (section) {
        case GroupChatDetailsSectionChatNotifications:
            height = 10.0f;
            break;
            
        case GroupChatDetailsSectionRenameGroup:
            height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionSharedFiles:
            height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionGetChatLink:
            height = ((self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) && self.chatRoom.isPublicChat  && !self.chatRoom.isPreview) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionClearChatHistory:
            height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionArchiveChat:
            height = self.chatRoom.isPreview ? 0.1f : 10.0f;
            break;
            
        case GroupChatDetailsSectionLeaveGroup:
            height = 10.0f;
            break;
            
        case GroupChatDetailsSectionEncryptedKeyRotation: {
            if (self.chatRoom.isPublicChat) {
                height = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? UITableViewAutomaticDimension : 0.1f;
            } else {
                height = 10.0f;
            }
            break;
        }
            
        case GroupChatDetailsSectionObservers:
            height = self.chatRoom.previewersCount ? 10.0f : 0.1f;
            break;
            
        case GroupChatDetailsSectionParticipants:
            height = 20.0f;
            break;
            
        default:
            height = 0.1f;
            break;
           
    }
    
    return height;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == GroupChatDetailsSectionEncryptedKeyRotation && self.chatRoom.isPublicChat && self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) {
        if (self.chatRoom.peerCount <= 100) {
            return [AMLocalizedString(@"Key rotation is slightly more secure, but does not allow you to create a chat link and new participants will not see past messages.", @"Footer text to explain what means 'Encrypted Key Rotation'") stringByAppendingString:@"\n"];
        } else {
            return AMLocalizedString(@"Key rotation is disabled for conversations with more than 100 participants.", @"Footer to explain why key rotation is disabled for public chats with many participants");
        }
    } else if (section == GroupChatDetailsSectionChatNotifications && [self shouldShowChatNotificationEnabledCell]) {
        return [self.chatNotificationControl timeRemainingForDNDDeactivationStringWithChatId:self.chatRoom.chatId];
    }
    
    return nil;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat heightForRow;
    switch (indexPath.section) {
        case GroupChatDetailsSectionChatNotifications:
            heightForRow = 44.0f;
            break;
            
        case GroupChatDetailsSectionRenameGroup:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionSharedFiles:
            heightForRow = 44.0f;
            break;
            
        case GroupChatDetailsSectionGetChatLink:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 44.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionClearChatHistory:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionArchiveChat:
            heightForRow = self.chatRoom.isPreview ? 0.0f : 44.0f;
            break;
            
        case GroupChatDetailsSectionLeaveGroup:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 44.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionEncryptedKeyRotation:
            heightForRow = (!self.chatRoom.isPublicChat || self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionObservers:
            heightForRow = self.chatRoom.previewersCount ? 60.0f : 0.0f;
            break;
            
        case GroupChatDetailsSectionParticipants:
            heightForRow = 60.0f;
            break;
            
        default:
            heightForRow = 0.0f;
            break;
    }
    
    return heightForRow;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        switch (indexPath.section) {
            case GroupChatDetailsSectionRenameGroup:
                [self renameChatGroup];
                break;

            case GroupChatDetailsSectionSharedFiles:
                [self.navigationController pushViewController:[ChatSharedItemsViewController instantiateWith:self.chatRoom] animated:YES];
                break;
            
            case GroupChatDetailsSectionGetChatLink: {
                if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) {
                    if (self.chatRoom.hasCustomTitle) {
                        MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                            if (error.type == MEGAChatErrorTypeOk) {
                                [self presentChatLinkOptionsWithLink:request.text];
                            } else {
                                MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                                    if (error.type == MEGAChatErrorTypeOk) {
                                        [self presentChatLinkOptionsWithLink:request.text];
                                    }
                                }];
                                [[MEGASdkManager sharedMEGAChatSdk] createChatLink:self.chatRoom.chatId delegate:delegate];
                            }
                        }];
                        [[MEGASdkManager sharedMEGAChatSdk] queryChatLink:self.chatRoom.chatId delegate:delegate];
                    } else {
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"Chat Link", @"Label shown in a cell where you can enable a switch to get a chat link") message:AMLocalizedString(@"To create a chat link you must name the group.", @"Alert message to advice the users that to generate a chat link they need enter a group name for the chat")  preferredStyle:UIAlertControllerStyleAlert];
                        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        }]];
                        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self renameChatGroup];
                        }]];
                        [self presentViewController:alertController animated:YES completion:nil];
                    }
                } else if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) {
                    if (self.chatRoom.hasCustomTitle) {
                        MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                            if (error.type == MEGAChatErrorTypeOk) {
                                [self presentChatLinkOptionsWithLink:request.text];
                            } else {
                                [self presentNoChatLinkAvailable];
                            }
                        }];
                        [[MEGASdkManager sharedMEGAChatSdk] queryChatLink:self.chatRoom.chatId delegate:delegate];
                    } else {
                        [self presentNoChatLinkAvailable];
                    }
                }
                break;
            }
                
            case GroupChatDetailsSectionClearChatHistory:
                [self showClearChatHistoryAlert];
                break;
                
            case GroupChatDetailsSectionArchiveChat:
                [self showArchiveChatAlert];
                break;
                
            case GroupChatDetailsSectionLeaveGroup:
                if (self.chatRoom.isPreview) {
                    [[MEGASdkManager sharedMEGAChatSdk] closeChatPreview:self.chatRoom.chatId];
                    if (self.presentingViewController) {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    } else {
                        [self.navigationController popToRootViewControllerAnimated:YES];
                    }
                } else {
                    [self showLeaveChatAlert];
                }
                break;
                
            case GroupChatDetailsSectionEncryptedKeyRotation: {
                CustomModalAlertViewController *customModalAlertVC = [[CustomModalAlertViewController alloc] init];
                customModalAlertVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
                customModalAlertVC.image = [UIImage imageNamed:@"lock"];
                customModalAlertVC.viewTitle = AMLocalizedString(@"Enable Encrypted Key Rotation", @"Title show in a cell where the users can enable the 'Encrypted Key Rotation'");
                customModalAlertVC.detail = AMLocalizedString(@"Key rotation is slightly more secure, but does not allow you to create a chat link and new participants will not see past messages.", @"Footer text to explain what means 'Encrypted Key Rotation'");
                customModalAlertVC.firstButtonTitle = AMLocalizedString(@"enable", nil);
                customModalAlertVC.dismissButtonTitle = AMLocalizedString(@"cancel", nil);
                __weak typeof(CustomModalAlertViewController) *weakCustom = customModalAlertVC;
                customModalAlertVC.firstCompletion = ^{
                    MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                        if (error.type == MEGAChatErrorTypeOk) {
                            [weakCustom dismissViewControllerAnimated:YES completion:^{
                                [self.tableView reloadData];
                            }];
                        }
                    }];
                    [[MEGASdkManager sharedMEGAChatSdk] setPublicChatToPrivate:self.chatRoom.chatId delegate:delegate];
                };
                
                [self presentViewController:customModalAlertVC animated:YES completion:nil];
                break;
            }
                
            case GroupChatDetailsSectionParticipants:
                if (!MEGASdkManager.sharedMEGASdk.isLoggedIn) {
                    break;
                }
                
                if ((indexPath.row == 0) && (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator)) {
                    [self addParticipant];
                    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                    return;
                }
                
                NSInteger index = (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) ? (indexPath.row - 1) : indexPath.row;
                uint64_t userHandle = [self.participantsMutableArray[index] unsignedLongLongValue];

                if (userHandle != MEGASdkManager.sharedMEGASdk.myUser.handle) {
                    NSString *userEmail = [MEGASdkManager.sharedMEGAChatSdk userEmailFromCacheByUserHandle:userHandle];
                    if (userEmail) {
                        ContactDetailsViewController *contactDetailsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactDetailsViewControllerID"];
                        contactDetailsVC.contactDetailsMode = ContactDetailsModeFromGroupChat;
                        contactDetailsVC.userEmail = userEmail;
                        contactDetailsVC.userHandle = userHandle;
                        contactDetailsVC.groupChatRoom = self.chatRoom;

                        [self.navigationController pushViewController:contactDetailsVC animated:YES];
                    }
                }
                break;
                
            default:
                break;
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - MEGAChatRequestDelegate

- (void)onChatRequestFinish:(MEGAChatSdk *)api request:(MEGAChatRequest *)request error:(MEGAChatError *)error {
    self.chatRoom = [api chatRoomForChatId:self.chatRoom.chatId];
    
    if (error.type) {
        return;
    }
    
    switch (request.type) {            
        case MEGAChatRequestTypeUpdatePeerPermissions:
            [self setParticipants];
            [self.tableView reloadData];
            break;
            
        case MEGAChatRequestTypeGetPeerAttributes: {
            MEGAHandleList *handleList = request.megaHandleList;
            NSMutableArray<NSIndexPath *> *indexPathsToReload = [NSMutableArray.alloc initWithCapacity:handleList.size];
            for (NSUInteger i = 0; i < handleList.size; i++) {
                NSString *base64Handle = [MEGASdk base64HandleForUserHandle:[handleList megaHandleAtIndex:i]];
                NSIndexPath *indexPath = [self.indexPathsMutableDictionary objectForKey:base64Handle];
                if (indexPath && [self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                    [indexPathsToReload addObject:indexPath];
                }
            }
            [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
            
            break;
        }
            
        default:
            break;
    }
}
#pragma mark - MEGAChatDelegate

- (void)onChatListItemUpdate:(MEGAChatSdk *)api item:(MEGAChatListItem *)item {
    if (self.chatRoom.chatId == item.chatId) {
        self.chatRoom = [api chatRoomForChatId:item.chatId];
        MEGALogInfo(@"onChatListItemUpdate %@", item);
        
        switch (item.changes) {
            case MEGAChatListItemChangeTypeOwnPrivilege:
            case MEGAChatListItemChangeTypeParticipants:
                [self setParticipants];
                [self.tableView reloadData];
                [self updateHeadingView];
                break;
                
            case MEGAChatListItemChangeTypeTitle:
                [self updateHeadingView];
                break;
                
            case MEGAChatListItemChangeTypeClosed:
                [self.navigationController popToRootViewControllerAnimated:YES];
                break;
                
            case MEGAChatListItemChangeTypeUpdatePreviewers: {
                [self.tableView reloadData];
                break;
            }
                
            default:
                break;
        }
    }
}

- (void)onChatOnlineStatusUpdate:(MEGAChatSdk *)api userHandle:(uint64_t)userHandle status:(MEGAChatStatus)onlineStatus inProgress:(BOOL)inProgress {
    if (inProgress) {
        return;
    }
    
    if (userHandle != api.myUserHandle) {
        NSString *base64Handle = [MEGASdk base64HandleForUserHandle:userHandle];
        NSIndexPath *indexPath = [self.indexPathsMutableDictionary objectForKey:base64Handle];
        if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
            GroupChatDetailsViewTableViewCell *cell = (GroupChatDetailsViewTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            cell.onlineStatusView.backgroundColor = [UIColor mnz_colorForStatusChange:onlineStatus];
        }
    }
}

#pragma mark - MEGAGlobalDelegate

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    [self setParticipants];
    BOOL reloadData = NO;
    for (NSInteger i = 0 ; i < userList.size.integerValue; i++) {
        MEGAUser *user = [userList userAtIndex:i];
        if (user.isOwnChange == 0) {
            reloadData = YES;
            break;
        }
    }
    if (reloadData) {
        [self.tableView reloadData];
    }
}


#pragma mark - ContactTableViewCellDelegate

- (void)notificationSwitchValueChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [self.chatNotificationControl turnOffDNDWithChatId:self.chatRoom.chatId];
    } else {
        [self.chatNotificationControl turnOnDNDWithChatId:self.chatRoom.chatId sender:sender];
    }
}

#pragma mark - ChatNotificationControlProtocol

- (void)pushNotificationSettingsLoaded {
    GroupChatDetailsViewTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:GroupChatDetailsSectionChatNotifications]];
    if (cell.notificationsSwitch != nil) {
        cell.notificationsSwitch.enabled = YES;
    }
}

@end
