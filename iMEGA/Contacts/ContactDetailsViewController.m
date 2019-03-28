#import "ContactDetailsViewController.h"

#import "SVProgressHUD.h"

#import "Helper.h"
#import "UIImageView+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "MEGAInviteContactRequestDelegate.h"
#import "MEGANavigationController.h"
#import "MEGANode+MNZCategory.h"
#import "MEGAReachabilityManager.h"
#import "MEGARemoveContactRequestDelegate.h"
#import "MEGAChatCreateChatGroupRequestDelegate.h"
#import "MEGAArchiveChatRequestDelegate.h"

#import "BrowserViewController.h"
#import "CloudDriveViewController.h"
#import "CustomActionViewController.h"
#import "ContactTableViewCell.h"
#import "CallViewController.h"
#import "GroupCallViewController.h"
#import "DevicePermissionsHelper.h"
#import "DisplayMode.h"
#import "GradientView.h"
#import "MainTabBarController.h"
#import "MessagesViewController.h"
#import "NodeInfoViewController.h"
#import "SharedItemsTableViewCell.h"
#import "VerifyCredentialsViewController.h"

@interface ContactDetailsViewController () <CustomActionViewControllerDelegate, MEGAChatDelegate, MEGAChatCallDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIImageView *verifiedImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *emailLabel;
@property (weak, nonatomic) IBOutlet UIView *onlineStatusView;
@property (weak, nonatomic) IBOutlet GradientView *gradientView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *avatarViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIButton *callButton;
@property (weak, nonatomic) IBOutlet UIButton *videoCallButton;
@property (weak, nonatomic) IBOutlet UIButton *messageButton;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *callLabel;
@property (weak, nonatomic) IBOutlet UILabel *videoLabel;
@property (weak, nonatomic) IBOutlet UIButton *backButton;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIView *participantsHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *participantsHeaderViewLabel;

@property (strong, nonatomic) MEGAUser *user;
@property (strong, nonatomic) MEGANodeList *incomingNodeListForUser;
@property (strong, nonatomic) MEGAChatRoom *chatRoom;

@property (strong, nonatomic) UIPanGestureRecognizer *panAvatar;
@property (assign, nonatomic) CGFloat avatarExpandedPosition;
@property (assign, nonatomic) CGFloat avatarCollapsedPosition;

@end

@implementation ContactDetailsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"";

    self.avatarExpandedPosition = self.view.frame.size.height * 0.5;
    self.avatarCollapsedPosition = self.view.frame.size.height * 0.3;
    self.avatarViewHeightConstraint.constant = self.avatarCollapsedPosition;
    
    self.user = [[MEGASdkManager sharedMEGASdk] contactForEmail:self.userEmail];
    if (self.chatId) {
        self.chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:self.chatId];
        [self.avatarImageView mnz_setImageAvatarOrColorForUserHandle:[self.chatRoom peerHandleAtIndex:0]];
    } else {
        if (self.user.visibility == MEGAUserVisibilityVisible) {
            [self.avatarImageView mnz_setImageAvatarOrColorForUserHandle:self.user.handle];
        } else {
            [self.avatarImageView mnz_setImageAvatarOrColorForUserHandle:self.userHandle];
        }
    }
    
    [self.backButton setImage:self.backButton.imageView.image.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
    self.messageLabel.text = AMLocalizedString(@"Message", @"Label for any ‘Message’ button, link, text, title, etc. - (String as short as possible).").lowercaseString;
    self.callLabel.text = AMLocalizedString(@"Call", @"Title of the button in the contact info screen to start an audio call").lowercaseString;
    self.videoLabel.text = AMLocalizedString(@"Video", @"Title of the button in the contact info screen to start a video call").lowercaseString;
    
    //TODO: Show the blue check if the Contact is verified
    
    self.nameLabel.text = self.userName;
    self.emailLabel.text = self.userEmail;
    
    MEGAChatStatus userStatus = [MEGASdkManager.sharedMEGAChatSdk userOnlineStatus:self.user.handle];
    if (userStatus != MEGAChatStatusInvalid) {
        if (userStatus < MEGAChatStatusOnline) {
            [MEGASdkManager.sharedMEGAChatSdk requestLastGreen:self.user.handle];
        }
        self.onlineStatusView.backgroundColor = [UIColor mnz_colorForStatusChange:[MEGASdkManager.sharedMEGAChatSdk userOnlineStatus:self.user.handle]];
        self.statusLabel.text = [NSString chatStatusString:userStatus];
        self.onlineStatusView.layer.shadowOffset = CGSizeMake(0, 2);
        self.onlineStatusView.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.2].CGColor;
        self.onlineStatusView.layer.shadowOpacity = 1;
        self.onlineStatusView.layer.shadowRadius = 4;
        self.onlineStatusView.layer.borderWidth = 1;
        self.onlineStatusView.layer.borderColor = UIColor.whiteColor.CGColor;
    } else {
        self.statusLabel.hidden = YES;
        self.onlineStatusView.hidden = YES;
    }
    
    self.incomingNodeListForUser = [[MEGASdkManager sharedMEGASdk] inSharesForUser:self.user];
    
    if (@available(iOS 11.0, *)) {
        self.avatarImageView.accessibilityIgnoresInvertColors = YES;
    }
    
    [self configureGestures];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[MEGASdkManager sharedMEGAChatSdk] addChatDelegate:self];
    [[MEGASdkManager sharedMEGAChatSdk] addChatCallDelegate:self];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCallButtonsState) name:kReachabilityChangedNotification object:nil];
    [self updateCallButtonsState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[MEGASdkManager sharedMEGAChatSdk] removeChatDelegate:self];
    [[MEGASdkManager sharedMEGAChatSdk] removeChatCallDelegate:self];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UIDevice.currentDevice.iPhone4X || UIDevice.currentDevice.iPhone5X) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.avatarExpandedPosition = self.view.frame.size.height * 0.5;
        self.avatarCollapsedPosition = self.view.frame.size.height * 0.3;
        self.avatarViewHeightConstraint.constant = self.avatarCollapsedPosition;
        self.gradientView.alpha = 1.0f;
    } completion:nil];
}

#pragma mark - Private

- (void)showClearChatHistoryAlert {
    UIAlertController *clearChatHistoryAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.") message:AMLocalizedString(@"clearTheFullMessageHistory", @"A confirmation message for a user to confirm that they want to clear the history of a chat.") preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"continue", @"'Next' button in a dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [[MEGASdkManager sharedMEGAChatSdk] clearChatHistory:self.chatId];
    }];
    
    [clearChatHistoryAlertController addAction:cancelAction];
    [clearChatHistoryAlertController addAction:continueAction];
    
    [self presentViewController:clearChatHistoryAlertController animated:YES completion:nil];
}

- (void)showArchiveChatAlertAtIndexPath {
    NSString *title = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChatMessage", @"Confirmation message for user to confirm it will unarchive an archived chat.") : AMLocalizedString(@"archiveChatMessage", @"Confirmation message on archive chat dialog for user to confirm.");
    UIAlertController *leaveAlertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        MEGAArchiveChatRequestDelegate *archiveChatRequesDelegate = [[MEGAArchiveChatRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
            self.chatRoom = chatRoom;
            [self.tableView reloadData];
        }];
        [[MEGASdkManager sharedMEGAChatSdk] archiveChat:self.chatRoom.chatId archive:!self.chatRoom.isArchived delegate:archiveChatRequesDelegate];
    }]];
    
    [self presentViewController:leaveAlertController animated:YES completion:nil];
}

- (void)showRemoveContactAlert {
    
    NSString *message = [NSString stringWithFormat:AMLocalizedString(@"removeUserMessage", nil), self.userEmail];
    
    UIAlertController *removeContactAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"removeUserTitle", @"Alert title shown when you want to remove one or more contacts") message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        MEGARemoveContactRequestDelegate *removeContactRequestDelegate = [[MEGARemoveContactRequestDelegate alloc] initWithNumberOfRequests:1 completion:^{
            //TODO: Close chat room because the contact was removed
            
            [self.navigationController popViewControllerAnimated:YES];
        }];
        [[MEGASdkManager sharedMEGASdk] removeContactUser:self.user delegate:removeContactRequestDelegate];
    }];
    
    [removeContactAlertController addAction:cancelAction];
    [removeContactAlertController addAction:okAction];
    
    [self presentViewController:removeContactAlertController animated:YES completion:nil];
}

- (void)sendInviteContact {
    MEGAInviteContactRequestDelegate *inviteContactRequestDelegate = [[MEGAInviteContactRequestDelegate alloc] initWithNumberOfRequests:1];
    [[MEGASdkManager sharedMEGASdk] inviteContactWithEmail:self.userEmail message:@"" action:MEGAInviteActionAdd delegate:inviteContactRequestDelegate];
}

- (void)pushVerifyCredentialsViewController {
    VerifyCredentialsViewController *verifyCredentialsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"VerifyCredentialsViewControllerID"];
    [self.navigationController pushViewController:verifyCredentialsVC animated:YES];
}

- (void)openChatRoomWithChatId:(uint64_t)chatId {
    MEGAChatRoom *chatRoom             = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatId];
    MessagesViewController *messagesVC = [[MessagesViewController alloc] init];
    messagesVC.chatRoom                = chatRoom;
    [self.navigationController pushViewController:messagesVC animated:YES];
}

- (void)sendMessageToContact {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"IsChatEnabled"]) {
        if (self.contactDetailsMode == ContactDetailsModeDefault) {
            MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomByUser:self.userHandle];
            if (chatRoom) {
                [self openChatRoomWithChatId:chatRoom.chatId];
            } else {
                MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
                [peerList addPeerWithHandle:self.userHandle privilege:MEGAChatRoomPrivilegeStandard];
                MEGAChatCreateChatGroupRequestDelegate *createChatGroupRequestDelegate = [[MEGAChatCreateChatGroupRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
                    [self openChatRoomWithChatId:chatRoom.chatId];
                }];
                [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:NO peers:peerList delegate:createChatGroupRequestDelegate];
            }
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else {
        [SVProgressHUD showImage:[UIImage imageNamed:@"hudWarning"] status:AMLocalizedString(@"chatIsDisabled", @"Title show when the chat is disabled")];
    }
}

- (void)collapseAvatarView {
    [UIView animateWithDuration:.3 animations:^{
        self.avatarViewHeightConstraint.constant = self.avatarCollapsedPosition;
        self.gradientView.alpha = 1;
        [self.view layoutIfNeeded];
    }];
}

- (void)expandAvatarView {
    [UIView animateWithDuration:.3 animations:^{
        self.avatarViewHeightConstraint.constant = self.avatarExpandedPosition;
        self.gradientView.alpha = 0;
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)isSharedFolderSection:(NSInteger)section {
    return (section == 1 && self.contactDetailsMode == ContactDetailsModeDefault) || (section == 2 && self.contactDetailsMode == ContactDetailsModeFromChat);
}

- (void)openSharedFolderAtIndexPath:(NSIndexPath *)indexPath {
    CloudDriveViewController *cloudDriveVC = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"CloudDriveID"];
    MEGANode *incomingNode = [self.incomingNodeListForUser nodeAtIndex:indexPath.row];
    cloudDriveVC.parentNode = incomingNode;
    cloudDriveVC.displayMode = DisplayModeCloudDrive;
    [self.navigationController pushViewController:cloudDriveVC animated:YES];
}

- (void)performCallWithVideo:(BOOL)video {
    if (self.chatRoom) {
        [self openCallViewWithVideo:video active:NO];
    } else {
        MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
        [peerList addPeerWithHandle:self.userHandle privilege:MEGAChatRoomPrivilegeStandard];
        MEGAChatCreateChatGroupRequestDelegate *createChatGroupRequestDelegate = [[MEGAChatCreateChatGroupRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
            self.chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatRoom.chatId];
            [self openCallViewWithVideo:video active:NO];
        }];
        [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:NO peers:peerList delegate:createChatGroupRequestDelegate];
    }
}

- (void)openCallViewWithVideo:(BOOL)videoCall active:(BOOL)active {
    if ([[UIDevice currentDevice] orientation] != UIInterfaceOrientationPortrait) {
        NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
        [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    }

    CallViewController *callVC = [[UIStoryboard storyboardWithName:@"Chat" bundle:nil] instantiateViewControllerWithIdentifier:@"CallViewControllerID"];
    callVC.chatRoom = self.chatRoom; [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:self.chatId];
    callVC.videoCall = videoCall;
    callVC.callType = active ? CallTypeActive : CallTypeOutgoing;
    callVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    if (@available(iOS 10.0, *)) {
        callVC.megaCallManager = [(MainTabBarController *)UIApplication.sharedApplication.keyWindow.rootViewController megaCallManager];
    }
    [self presentViewController:callVC animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.avatarImageView];
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (translation.y < 0 && self.avatarViewHeightConstraint.constant > self.avatarCollapsedPosition) {
            self.avatarViewHeightConstraint.constant += translation.y;
        }
        
        if (translation.y > 0 && self.avatarViewHeightConstraint.constant < self.avatarExpandedPosition) {
            self.avatarViewHeightConstraint.constant += translation.y;
        }
        
        float alpha = ((self.avatarViewHeightConstraint.constant - self.avatarExpandedPosition) / (self.avatarCollapsedPosition - self.avatarExpandedPosition));
        self.gradientView.alpha = alpha;
        
        [recognizer setTranslation:CGPointZero inView:self.avatarImageView];
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded ) {
        CGPoint velocity = [recognizer velocityInView:self.avatarImageView];
        if (velocity.y != 0) {
            if (velocity.y < 0 && self.avatarViewHeightConstraint.constant > self.avatarCollapsedPosition) {
                [self collapseAvatarView];
            } else if (velocity.y > 0 && self.avatarViewHeightConstraint.constant < self.avatarExpandedPosition) {
                [self expandAvatarView];
            }
        } else {
            if (((self.avatarViewHeightConstraint.constant - self.avatarExpandedPosition) / (self.avatarCollapsedPosition - self.avatarExpandedPosition)) > 0.5) {
                [self collapseAvatarView];
            } else {
                [self expandAvatarView];
            }
        }
    }
}

- (void)updateCallButtonsState {
    MEGAChatRoom *chatRoom = self.chatRoom ? self.chatRoom : [[MEGASdkManager sharedMEGAChatSdk] chatRoomByUser:self.userHandle];
    if (chatRoom) {
        if (chatRoom.ownPrivilege < MEGAChatRoomPrivilegeStandard) {
            self.messageButton.enabled = self.callButton.enabled = self.videoCallButton.enabled = NO;
            return;
        }
        MEGAChatConnection chatConnection = [[MEGASdkManager sharedMEGAChatSdk] chatConnectionState:chatRoom.chatId];
        if (chatConnection != MEGAChatConnectionOnline) {
            self.callButton.enabled = self.videoCallButton.enabled = NO;
            return;
        }
    }
    
    if (!MEGAReachabilityManager.isReachable) {
        self.callButton.enabled = self.videoCallButton.enabled = NO;
        return;
    }
    
    MEGAHandleList *chatRoomIDsWithCallInProgress = [MEGASdkManager.sharedMEGAChatSdk chatCallsWithState:MEGAChatCallStatusInProgress];
    if (chatRoomIDsWithCallInProgress.size > 0) {
        self.callButton.enabled = self.videoCallButton.enabled = NO;
        return;
    }
    
    self.callButton.enabled = self.videoCallButton.enabled = YES;
}

- (void)configureGestures {
    NSString *avatarFilePath = [[Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"] stringByAppendingPathComponent:[MEGASdk base64HandleForUserHandle:self.userHandle]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarFilePath]) {
        self.panAvatar = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.avatarImageView addGestureRecognizer:self.panAvatar];
        [self.avatarImageView.gestureRecognizers enumerateObjectsUsingBlock:^(__kindof UIGestureRecognizer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[UIPanGestureRecognizer class]]) {
                [obj requireGestureRecognizerToFail:self.navigationController.interactivePopGestureRecognizer];
            }
        }];
    }
}

#pragma mark - IBActions

- (IBAction)notificationsSwitchValueChanged:(UISwitch *)sender {
    //TODO: Enable/disable notifications
}

- (IBAction)infoTouchUpInside:(UIButton *)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    
    MEGANode *node = [self.incomingNodeListForUser nodeAtIndex:indexPath.row];
    
    CustomActionViewController *actionController = [[CustomActionViewController alloc] init];
    actionController.node = node;
    actionController.displayMode = DisplayModeSharedItem;
    actionController.actionDelegate = self;
    actionController.incomingShareChildView = YES;
    if ([[UIDevice currentDevice] iPadDevice]) {
        actionController.modalPresentationStyle = UIModalPresentationPopover;
        actionController.popoverPresentationController.delegate = actionController;
        actionController.popoverPresentationController.sourceView = sender;
        actionController.popoverPresentationController.sourceRect = CGRectMake(0, 0, sender.frame.size.width / 2, sender.frame.size.height / 2);
    } else {
        actionController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    
    [self presentViewController:actionController animated:YES completion:nil];
}

- (IBAction)backTouchUpInside:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)messageTouchUpInside:(id)sender {
    [self sendMessageToContact];
}

- (IBAction)startAudioVideoCallTouchUpInside:(UIButton *)sender {
    MEGAHandleList *chatRoomIDsWithCallInProgress = [MEGASdkManager.sharedMEGAChatSdk chatCallsWithState:MEGAChatCallStatusInProgress];
    if (chatRoomIDsWithCallInProgress.size == 0) {
        [DevicePermissionsHelper audioPermissionModal:YES forIncomingCall:NO withCompletionHandler:^(BOOL granted) {
            if (granted) {
                if (sender.tag) {
                    [DevicePermissionsHelper videoPermissionWithCompletionHandler:^(BOOL granted) {
                        if (granted) {
                            [self performCallWithVideo:sender.tag];
                        } else {
                            [DevicePermissionsHelper alertVideoPermissionWithCompletionHandler:nil];
                        }
                    }];
                } else {
                    [self performCallWithVideo:sender.tag];
                }
            } else {
                [DevicePermissionsHelper alertAudioPermissionForIncomingCall:NO];
            }
        }];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger numberOfSections = 0;
    if (self.contactDetailsMode == ContactDetailsModeDefault) {
        numberOfSections = 1;
    } else if (self.contactDetailsMode == ContactDetailsModeFromChat) {
        numberOfSections = 2;
    }
    
    if (self.incomingNodeListForUser.size.integerValue != 0) {
        numberOfSections += 1;
    }
    
    return numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    if (self.contactDetailsMode == ContactDetailsModeDefault) {
        //TODO: When possible, re-add the rows "Chat Notifications", "Set Nickname" and "Verify Credentials".
        if (section == 0) {
            numberOfRows = 1;
        } else if (section == 1) {
            numberOfRows = self.incomingNodeListForUser.size.integerValue;
        }
    } else if (self.contactDetailsMode == ContactDetailsModeFromChat) {
        //TODO: When possible, re-add the rows "Chat Notifications", "Set Nickname" and "Verify Credentials".
        if (section == 2) {
            numberOfRows = self.incomingNodeListForUser.size.integerValue;
        } else {
            numberOfRows = 1;
        }
    }
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactTableViewCell *cell;
    
    if (self.contactDetailsMode == ContactDetailsModeDefault) {
        switch (indexPath.section) {
            case 0:
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactDetailsDefaultTypeID" forIndexPath:indexPath];
                if (self.user.visibility == MEGAUserVisibilityVisible) { //Remove Contact
                    cell.avatarImageView.image = [UIImage imageNamed:@"delete"];
                    cell.nameLabel.text = AMLocalizedString(@"removeUserTitle", @"Alert title shown when you want to remove one or more contacts");
                    cell.nameLabel.font = [UIFont mnz_SFUIRegularWithSize:15.0f];
                    cell.nameLabel.textColor = UIColor.mnz_redMain;
                } else { //Add contact
                    cell.avatarImageView.image = [UIImage imageNamed:@"add"];
                    cell.avatarImageView.tintColor = [UIColor mnz_gray777777];
                    cell.nameLabel.text = AMLocalizedString(@"addContact", @"Alert title shown when you select to add a contact inserting his/her email");
                    cell.nameLabel.font = [UIFont mnz_SFUIRegularWithSize:15.0f];
                }
                break;
                
            case 1: //Shared folders
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactDetailsSharedFolderTypeID" forIndexPath:indexPath];
                MEGANode *node = [self.incomingNodeListForUser nodeAtIndex:indexPath.row];
                cell.avatarImageView.image = [Helper incomingFolderImage];
                cell.nameLabel.text = node.name;
                cell.shareLabel.text = [Helper filesAndFoldersInFolderNode:node api:[MEGASdkManager sharedMEGASdk]];
                MEGAShareType shareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node];
                cell.permissionsImageView.image = [Helper permissionsButtonImageForShareType:shareType];
                break;
        }
            
    } else if (self.contactDetailsMode == ContactDetailsModeFromChat) {
        switch (indexPath.section) {
            case 0: //Clear Chat History
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactDetailsDefaultTypeID" forIndexPath:indexPath];
                cell.avatarImageView.image = [UIImage imageNamed:@"clearChatHistory"];
                cell.nameLabel.text = AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.");
                cell.nameLabel.enabled = self.user.visibility == MEGAUserVisibilityVisible;
                cell.nameLabel.font = [UIFont mnz_SFUIRegularWithSize:15.0f];
                cell.userInteractionEnabled = self.user.visibility == MEGAUserVisibilityVisible;
                break;
                
            case 1: //Archive chat
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactDetailsDefaultTypeID" forIndexPath:indexPath];
                cell.avatarImageView.image = self.chatRoom.isArchived ? [UIImage imageNamed:@"unArchiveChat"] : [UIImage imageNamed:@"archiveChat_gray"];
                cell.nameLabel.text = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChat", @"The title of the dialog to unarchive an archived chat.") : AMLocalizedString(@"archiveChat", @"Title of button to archive chats.");
                cell.nameLabel.textColor = self.chatRoom.isArchived ? UIColor.mnz_redMain : UIColor.mnz_black333333;
                cell.nameLabel.font = [UIFont mnz_SFUIRegularWithSize:15.0f];
                break;
                
            case 2: //Shared folders
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactDetailsSharedFolderTypeID" forIndexPath:indexPath];
                MEGANode *node = [self.incomingNodeListForUser nodeAtIndex:indexPath.row];
                cell.avatarImageView.image = [Helper incomingFolderImage];
                cell.nameLabel.text = node.name;
                cell.shareLabel.text = [Helper filesAndFoldersInFolderNode:node api:[MEGASdkManager sharedMEGASdk]];
                MEGAShareType shareType = [[MEGASdkManager sharedMEGASdk] accessLevelForNode:node];
                cell.permissionsImageView.image = [Helper permissionsButtonImageForShareType:shareType];
                break;
        }
    }
    
    if (@available(iOS 11.0, *)) {
        cell.avatarImageView.accessibilityIgnoresInvertColors = YES;
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self isSharedFolderSection:section]) {
        self.participantsHeaderViewLabel.text = [AMLocalizedString(@"sharedFolders", @"Title of the incoming shared folders of a user.") uppercaseString];
        return self.participantsHeaderView;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0 || [self isSharedFolderSection:section]) {
        return 24;
    }
    
    return 0.01f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 24.0f;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isSharedFolderSection:indexPath.section]) {
        return 60.0f;
    } else {
        return 44.0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.contactDetailsMode == ContactDetailsModeDefault) {
        switch (indexPath.section) {
            case 0: {
                if (self.user.visibility == MEGAUserVisibilityVisible) {
                    [self showRemoveContactAlert];
                } else {
                    [self sendInviteContact];
                }
                break;
            }
        
            case 1: {
                [self openSharedFolderAtIndexPath:indexPath];
                break;
            }
        }
    } else if (self.contactDetailsMode == ContactDetailsModeFromChat) {
        switch (indexPath.section) {
            case 0:
                [self showClearChatHistoryAlert];
                break;
                
            case 1:
                [self showArchiveChatAlertAtIndexPath];
                break;
                
            case 2: {
                [self openSharedFolderAtIndexPath:indexPath];
                break;
            }
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - CustomActionViewControllerDelegate

- (void)performAction:(MegaNodeActionType)action inNode:(MEGANode *)node fromSender:(id)sender {
    switch (action) {
        case MegaNodeActionTypeDownload:
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudDownload"] status:AMLocalizedString(@"downloadStarted", @"Message shown when a download starts")];
            [node mnz_downloadNodeOverwriting:NO];
            break;
            
        case MegaNodeActionTypeCopy: {
            MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"BrowserNavigationControllerID"];
            [self presentViewController:navigationController animated:YES completion:nil];
            
            BrowserViewController *browserVC = navigationController.viewControllers.firstObject;
            browserVC.selectedNodesArray = @[node];
            browserVC.browserAction = BrowserActionCopy;
            break;
        }
            
        case MegaNodeActionTypeRename:
            [node mnz_renameNodeInViewController:self];
            break;
            
        case MegaNodeActionTypeFileInfo: {
            UINavigationController *nodeInfoNavigation = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"NodeInfoNavigationControllerID"];
            NodeInfoViewController *nodeInfoVC = nodeInfoNavigation.viewControllers.firstObject;
            nodeInfoVC.node = node;
            
            [self presentViewController:nodeInfoNavigation animated:YES completion:nil];
            break;
        }
            
        case MegaNodeActionTypeLeaveSharing:
            [node mnz_leaveSharingInViewController:self];
            break;
            
        default:
            break;
    }
}

#pragma mark - MEGAChatDelegate

- (void)onChatOnlineStatusUpdate:(MEGAChatSdk *)api userHandle:(uint64_t)userHandle status:(MEGAChatStatus)onlineStatus inProgress:(BOOL)inProgress {
    if (inProgress) {
        return;
    }
    
    if (userHandle == self.user.handle) {
        [self updateCallButtonsState];
        self.onlineStatusView.backgroundColor = [UIColor mnz_colorForStatusChange:onlineStatus];
        self.statusLabel.text = [NSString chatStatusString:onlineStatus];
        if (onlineStatus < MEGAChatStatusOnline) {
            [MEGASdkManager.sharedMEGAChatSdk requestLastGreen:self.user.handle];
        }
    }
}

- (void)onChatPresenceLastGreen:(MEGAChatSdk *)api userHandle:(uint64_t)userHandle lastGreen:(NSInteger)lastGreen {
    if (self.chatRoom.isGroup) {
        return;
    } else if (userHandle == self.user.handle) {
        if (self.user.handle == userHandle) {
            MEGAChatStatus chatStatus = [[MEGASdkManager sharedMEGAChatSdk] userOnlineStatus:self.user.handle];
            if (chatStatus < MEGAChatStatusOnline) {
                self.statusLabel.text = [NSString mnz_lastGreenStringFromMinutes:lastGreen];
            }
        }
    }
}

#pragma mark - MEGAChatCallDelegate

- (void)onChatCallUpdate:(MEGAChatSdk *)api call:(MEGAChatCall *)call {
    if (call.status == MEGAChatCallStatusDestroyed) {
        [self updateCallButtonsState];
    }
}

@end
