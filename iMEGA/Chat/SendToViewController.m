#import "SendToViewController.h"

#import "UIImage+GKContact.h"
#import "UIScrollView+EmptyDataSet.h"
#import "SVProgressHUD.h"

#import "UIImageView+MNZCategory.h"

#import "EmptyStateView.h"
#import "Helper.h"
#import "MEGAChatAttachNodeRequestDelegate.h"
#import "MEGAChatAttachVoiceClipRequestDelegate.h"
#import "MEGAChatCreateChatGroupRequestDelegate.h"
#import "MEGAChatMessage+MNZCategory.h"
#import "MEGACopyRequestDelegate.h"
#import "MEGACreateFolderRequestDelegate.h"
#import "MEGANodeList+MNZCategory.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "MEGAUser+MNZCategory.h"

#ifdef MNZ_APP_EXTENSION
#import "MEGAShare-Swift.h"
#else
#import "MEGA-Swift.h"
#endif

#import "ContactTableViewCell.h"
#import "ChatRoomCell.h"
#import "ItemListViewController.h"

@interface SendToViewController () <UISearchBarDelegate, UISearchResultsUpdating, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, UISearchControllerDelegate, ItemListViewControllerDelegate, UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendBarButtonItem;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *itemListViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *itemListView;
@property (weak, nonatomic) IBOutlet UIView *searchView;

@property (weak, nonatomic) IBOutlet UIView *topSeparatorRecentsHeaderView;
@property (weak, nonatomic) IBOutlet UIView *recentsHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *recentsHeaderViewLabel;
@property (weak, nonatomic) IBOutlet UIView *bottomSeparatorRecentsHeaderView;

@property (weak, nonatomic) IBOutlet UIView *topSeparatorChatsHeaderView;
@property (weak, nonatomic) IBOutlet UIView *chatsHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *chatsHeaderViewLabel;
@property (weak, nonatomic) IBOutlet UIView *bottomSeparatorChatsHeaderView;

@property (nonatomic, strong) UISearchController *searchController;

@property (nonatomic, strong) NSMutableArray *usersAndGroupChatsMutableArray;
@property (nonatomic, strong) NSMutableArray *searchedUsersAndGroupChatsMutableArray;

@property (nonatomic, strong) MEGAChatListItemList *chatListItemList;
@property (nonatomic, strong) NSMutableArray *recentsMutableArray;
@property (nonatomic, strong) NSMutableArray *groupChatsMutableArray;
@property (nonatomic, strong) NSMutableArray *searchedGroupChatsMutableArray;
@property (nonatomic, strong) NSMutableArray *selectedGroupChatsMutableArray;

@property (nonatomic, strong) MEGAUserList *users;
@property (nonatomic, strong) NSMutableArray *visibleUsersMutableArray;
@property (nonatomic, strong) NSMutableArray *searchedUsersMutableArray;
@property (nonatomic, strong) NSMutableArray *selectedUsersMutableArray;

@property (nonatomic) NSUInteger pendingAttachNodeOperations;

@property (strong, nonatomic) ItemListViewController *itemListVC;

@property (nonatomic) NSUInteger pendingForwardOperations;
@property (nonatomic) NSMutableArray<NSNumber *> *chatIdNumbers;
@property (nonatomic) NSMutableArray<MEGAChatMessage *> *sentMessages;

@property (nonatomic) UIPanGestureRecognizer *panOnTable;

@end

@implementation SendToViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    switch (self.sendMode) {
        case SendModeCloud:
        case SendModeForward:
            self.cancelBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
            
            break;
            
        case SendModeShareExtension:
            self.navigationItem.leftBarButtonItem = nil;
            
            break;
    }
    
    self.sendBarButtonItem.title = AMLocalizedString(@"send", @"Label for any 'Send' button, link, text, title, etc. - (String as short as possible).");
    [self.sendBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:[UIFont mnz_SFUISemiBoldWithSize:17.f]} forState:UIControlStateNormal];
    
    self.navigationItem.title = AMLocalizedString(@"selectDestination", @"Title shown on the navigation bar to explain that you have to choose a destination for the files and/or folders in case you copy, move, import or do some action with them.");
    
    self.tableView.separatorColor = self.topSeparatorRecentsHeaderView.backgroundColor = self.bottomSeparatorRecentsHeaderView.backgroundColor = self.topSeparatorRecentsHeaderView.backgroundColor = self.bottomSeparatorRecentsHeaderView.backgroundColor = [UIColor mnz_separatorColorForTraitCollection:self.traitCollection];
    self.recentsHeaderViewLabel.text = AMLocalizedString(@"Recents", @"Title for the recents section").uppercaseString;
    self.recentsHeaderViewLabel.textColor = [UIColor mnz_secondaryGrayForTraitCollection:self.traitCollection];
    self.chatsHeaderViewLabel.text = AMLocalizedString(@"My chats", @"Column header of my contacts/chats at copy dialog").uppercaseString;
    self.chatsHeaderViewLabel.textColor = [UIColor mnz_secondaryGrayForTraitCollection:self.traitCollection];
    
    self.searchController = [Helper customSearchControllerWithSearchResultsUpdaterDelegate:self searchBarDelegate:self];
    self.searchController.definesPresentationContext = YES;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.searchController.delegate = self;
    [self.searchView addSubview:self.searchController.searchBar];
    
    [self setGroupChatsAndRecents];
    [self setVisibleUsers];
    [self groupAndOrderUserAndGroupChats];
    [self sortAndFilterRecents];
    
    [self.tableView setEditing:YES];
    
    self.panOnTable = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(shouldDismissSearchController)];
    self.panOnTable.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
#ifdef MNZ_APP_EXTENSION
            [ExtensionAppearanceManager setupAppearance:self.traitCollection];
            [ExtensionAppearanceManager invalidateViews];
#else
            [AppearanceManager setupAppearance:self.traitCollection];
            [AppearanceManager invalidateViews];
#endif
        }
    }
}

#pragma mark - Private

- (void)setGroupChatsAndRecents {
    self.chatListItemList = [[MEGASdkManager sharedMEGAChatSdk] activeChatListItems];
    self.recentsMutableArray = [[NSMutableArray alloc] init];
    self.groupChatsMutableArray = [[NSMutableArray alloc] init];
    self.selectedGroupChatsMutableArray = [[NSMutableArray alloc] init];
    if (self.chatListItemList.size) {
        for (NSUInteger i = 0; i < self.chatListItemList.size ; i++) {
            MEGAChatListItem *chatListItem = [self.chatListItemList chatListItemAtIndex:i];
            if (chatListItem.ownPrivilege >= MEGAChatRoomPrivilegeStandard) {
                [self.recentsMutableArray addObject:chatListItem];
                if (chatListItem.isGroup) {
                    [self.groupChatsMutableArray addObject:chatListItem];
                }
            }
        }
    }
}

- (void)setVisibleUsers {
    self.users = [[MEGASdkManager sharedMEGASdk] contacts];
    self.visibleUsersMutableArray = [[NSMutableArray alloc] init];
    self.selectedUsersMutableArray = [[NSMutableArray alloc] init];
    NSInteger count = self.users.size.integerValue;
    for (NSInteger i = 0; i < count; i++) {
        MEGAUser *user = [self.users userAtIndex:i];
        if (user.visibility == MEGAUserVisibilityVisible) {
            [self.visibleUsersMutableArray addObject:user];
        }
    }
}

- (void)groupAndOrderUserAndGroupChats {
    self.usersAndGroupChatsMutableArray = [[NSMutableArray alloc] init];
    [self.usersAndGroupChatsMutableArray addObjectsFromArray:self.groupChatsMutableArray];
    [self.usersAndGroupChatsMutableArray addObjectsFromArray:self.visibleUsersMutableArray];
    self.usersAndGroupChatsMutableArray = [[self.usersAndGroupChatsMutableArray sortedArrayUsingComparator:[self comparatorToOrderUsersAndGroupChats]] mutableCopy];
}

- (NSComparator)comparatorToOrderUsersAndGroupChats {
    return ^NSComparisonResult(id a, id b) {
        NSString *first;
        NSString *second;
        
        if ([a isKindOfClass:MEGAChatListItem.class]) {
            MEGAChatListItem *chatListItem = a;
            first = chatListItem.title;
        } else if ([a isKindOfClass:MEGAUser.class]) {
            MEGAUser *user = a;
            first = user.mnz_fullName;
        }
        
        if ([b isKindOfClass:MEGAChatListItem.class]) {
            MEGAChatListItem *chatListItem = b;
            second = chatListItem.title;
        } else if ([b isKindOfClass:MEGAUser.class]) {
            MEGAUser *user = b;
            second = user.mnz_fullName;
        }
        
        return [first compare:second options:NSCaseInsensitiveSearch];
    };
}

- (void)sortAndFilterRecents {
    self.recentsMutableArray = [[[self.recentsMutableArray sortedArrayUsingComparator:[self comparatorToOrderRecents]] subarrayWithRange:NSMakeRange(0, MIN(5, self.recentsMutableArray.count))] mutableCopy];
    for (NSUInteger i = 0; i < self.recentsMutableArray.count; i++) {
        MEGAChatListItem *chatListItem = [self.recentsMutableArray objectAtIndex:i];
        if (!chatListItem.isGroup) {
            for (MEGAUser *user in self.visibleUsersMutableArray) {
                if (user.handle == chatListItem.peerHandle) {
                    [self.recentsMutableArray replaceObjectAtIndex:i withObject:user];
                    break;
                }
            }
        }
    }
    [self.usersAndGroupChatsMutableArray removeObjectsInArray:self.recentsMutableArray];
}

- (NSComparator)comparatorToOrderRecents {
    return ^NSComparisonResult(id a, id b) {
        NSDate *first  = [(MEGAChatListItem *)a lastMessageDate] ?: [NSDate dateWithTimeIntervalSince1970:0];
        NSDate *second = [(MEGAChatListItem *)b lastMessageDate] ?: [NSDate dateWithTimeIntervalSince1970:0];
        return [second compare:first];
    };
}

- (void)updateNavigationBarTitle {
    NSString *navigationTitle;
    NSInteger selectedItems = (self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count);
    if (selectedItems == 0) {
        navigationTitle = AMLocalizedString(@"selectDestination", @"Title shown on the navigation bar to explain that you have to choose a destination for the files and/or folders in case you copy, move, import or do some action with them.");
    } else {
        navigationTitle = (selectedItems == 1) ? AMLocalizedString(@"1 selected", @"Title shown when multiselection is enabled and only one item has been selected.") : [NSString stringWithFormat:AMLocalizedString(@"xSelected", @"Title shown when multiselection is enabled and the user has more than one item selected."), selectedItems];
    }
    
    self.navigationItem.title = navigationTitle;
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    
    id itemAtIndex = nil;
    
    if (self.searchController.isActive) {
        itemAtIndex = [self.searchedUsersAndGroupChatsMutableArray objectAtIndex:indexPath.row];
    } else if (indexPath.section == 0) {
        itemAtIndex = [self.recentsMutableArray objectAtIndex:indexPath.row];
    } else {
        itemAtIndex = [self.usersAndGroupChatsMutableArray objectAtIndex:indexPath.row];
    }
    
    return itemAtIndex;
}

- (void)updateMainSearchArray {
    self.searchedUsersAndGroupChatsMutableArray = [[NSMutableArray alloc] init];
    [self.searchedUsersAndGroupChatsMutableArray addObjectsFromArray:self.searchedGroupChatsMutableArray];
    [self.searchedUsersAndGroupChatsMutableArray addObjectsFromArray:self.searchedUsersMutableArray];
    self.searchedUsersAndGroupChatsMutableArray = [[self.searchedUsersAndGroupChatsMutableArray sortedArrayUsingComparator:[self comparatorToOrderUsersAndGroupChats]] mutableCopy];
}

- (void)showSuccessMessage {
    NSString *status;
    if (self.nodes.count == 1) {
        if ((self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) == 1) {
            status = AMLocalizedString(@"fileSentToChat", @"Toast text upon sending a single file to chat");
        } else {
            status = [NSString stringWithFormat:AMLocalizedString(@"fileSentToXChats", @"Success message when the attachment has been sent to a many chats"), (self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) ];
        }
    } else {
        if ((self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) == 1) {
            status = AMLocalizedString(@"filesSentToChat", @"Toast text upon sending multiple files to chat");
        } else {
            status = [NSString stringWithFormat:AMLocalizedString(@"xfilesSentSuccesfully", @"success message when sending multiple files. Please do not modify the %d placeholder."), self.nodes.count];
        }
    }
    
    [SVProgressHUD showSuccessWithStatus:status];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self.tableView addGestureRecognizer:self.panOnTable];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self shouldDismissSearchController];
    [self.tableView removeGestureRecognizer:self.panOnTable];
}

- (void)shouldDismissSearchController {
    switch (self.sendMode) {
        case SendModeCloud:
        case SendModeShareExtension:
            if (self.searchController.isActive) {
                [self.searchController.searchBar resignFirstResponder];
            }
            break;
            
        default:
            break;
    }
}

- (void)addItemToList:(ItemListModel *)item {
    if (self.childViewControllers.count) {
        [self.itemListVC addItem:item];
    } else {
        [UIView animateWithDuration:.25 animations:^{
            self.itemListViewHeightConstraint.constant = 110;
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            ItemListViewController *usersList = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ItemListViewControllerID"];
            self.itemListVC = usersList;
            self.itemListVC.itemListDelegate = self;
            [self addChildViewController:usersList];
            usersList.view.frame = self.itemListView.bounds;
            [self.itemListView addSubview:usersList.view];
            [usersList didMoveToParentViewController:self];
            [self.itemListVC addItem:item];
        }];
    }
}

- (void)removeUsersListSubview {
    ItemListViewController *usersList = self.childViewControllers.lastObject;
    [usersList willMoveToParentViewController:nil];
    [usersList.view removeFromSuperview];
    [usersList removeFromParentViewController];
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:.25 animations:^ {
        self.itemListViewHeightConstraint.constant = 0;
        [self.view layoutIfNeeded];
    }];
}

- (void)completeForwardingMessage:(MEGAChatMessage *)message toChat:(uint64_t)chatId {
    @synchronized(self.sentMessages) {
        if (chatId == self.sourceChatId && message.type != MEGAChatMessageTypeAttachment && message.type != MEGAChatMessageTypeVoiceClip) {
            [self.sentMessages addObject:message];
        }
        
        if (--self.pendingForwardOperations == 0) {
            self.completion(self.chatIdNumbers, self.sentMessages);
        }
    }
}

- (void)forwardMessages {
    for (MEGAChatMessage *message in self.messages) {
        switch (message.type) {
            case MEGAChatMessageTypeNormal:
            case MEGAChatMessageTypeContainsMeta: {
                for (NSNumber *chatIdNumber in self.chatIdNumbers) {
                    uint64_t chatId = chatIdNumber.unsignedLongLongValue;
                    MEGAChatMessage *newMessage;
                    if (message.containsMeta.type == MEGAChatContainsMetaTypeGeolocation) {
                        newMessage = [[MEGASdkManager sharedMEGAChatSdk] sendGeolocationToChat:chatId longitude:message.containsMeta.geolocation.longitude latitude:message.containsMeta.geolocation.latitude image:message.containsMeta.geolocation.image];
                    } else {
                        newMessage = [[MEGASdkManager sharedMEGAChatSdk] sendMessageToChat:chatId message:message.content];
                    }
                    [self completeForwardingMessage:newMessage toChat:chatId];
                }
                
                break;
            }
            case MEGAChatMessageTypeContact: {
                for (NSNumber *chatIdNumber in self.chatIdNumbers) {
                    uint64_t chatId = chatIdNumber.unsignedLongLongValue;
                    MEGAChatMessage *newMessage = [[MEGASdkManager sharedMEGAChatSdk] forwardContactFromChat:message.chatId messageId:message.messageId targetChatId:chatId];
                    [self completeForwardingMessage:newMessage toChat:chatId];
                }
                
                break;
            }
                
            case MEGAChatMessageTypeAttachment:
            case MEGAChatMessageTypeVoiceClip: {
                MEGANode *node = [message.nodeList mnz_nodesArrayFromNodeList].firstObject;
                [Helper importNode:node toShareWithCompletion:^(MEGANode *node) {
                    [self attachNode:node.handle asVoiceClip:message.type == MEGAChatMessageTypeVoiceClip];
                }];
                
                break;
            }
                
            default:
                break;
        }
    }
}

- (void)attachNode:(uint64_t)handle asVoiceClip:(BOOL)asVoiceClip {
    void (^completion)(MEGAChatRequest *request, MEGAChatError *error) = ^(MEGAChatRequest *request, MEGAChatError *error) {
        [self completeForwardingMessage:request.chatMessage toChat:request.chatHandle];
    };
    
    MEGAChatBaseRequestDelegate *delegate;
    if (asVoiceClip) {
        delegate = [[MEGAChatAttachVoiceClipRequestDelegate alloc] initWithCompletion:completion];
    } else {
        delegate = [[MEGAChatAttachNodeRequestDelegate alloc] initWithCompletion:completion];
    }
    
    for (NSNumber *chatIdNumber in self.chatIdNumbers) {
        uint64_t chatId = chatIdNumber.unsignedLongLongValue;
        if (asVoiceClip) {
            [[MEGASdkManager sharedMEGAChatSdk] attachVoiceMessageToChat:chatId node:handle delegate:delegate];
        } else {
            [[MEGASdkManager sharedMEGAChatSdk] attachNodeToChat:chatId node:handle delegate:delegate];
        }
    }
}

- (NSString *)participantsNamesForChatRoom:(MEGAChatRoom *)chatRoom {
    NSString *participantsNames = @"";
    for (NSUInteger i = 0; i < chatRoom.peerCount; i++) {
        NSString *peerName;
        NSString *peerFirstname = [chatRoom peerFirstnameAtIndex:i];
        if (peerFirstname.length > 0 && ![[peerFirstname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
            peerName = peerFirstname;
        } else {
            NSString *peerLastname = [chatRoom peerLastnameAtIndex:i];
            if (peerLastname.length > 0 && ![[peerLastname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
                peerName = peerLastname;
            }
        }
        
        if (!peerName.length) {
            peerName = [chatRoom peerEmailByHandle:[chatRoom peerHandleAtIndex:i]];
        }
        
        if (chatRoom.peerCount == 1 || (i + 1) == chatRoom.peerCount) {
            participantsNames = [participantsNames stringByAppendingString:peerName ? peerName : @"Unknown user"];
        } else {
            participantsNames = [participantsNames stringByAppendingString:[NSString stringWithFormat:@"%@, ", peerName]];
        }
    }
    
    NSString *myName = [[MEGASdkManager sharedMEGAChatSdk] myFullname];
    BOOL isNameEmpty = [[myName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
    if (isNameEmpty) {
        myName = MEGASdkManager.sharedMEGAChatSdk.myEmail;
    }
    myName = [NSString stringWithFormat:@"%@ (%@)", myName, AMLocalizedString(@"me", @"The title for my message in a chat. The message was sent from yourself.")];
    if (chatRoom.peerCount) {
        participantsNames = [participantsNames stringByAppendingString:[NSString stringWithFormat:@", %@", myName]];
    } else {
        participantsNames = myName;
    }
    
    return participantsNames;
}

#pragma mark - IBActions

- (IBAction)cancelAction:(UIBarButtonItem *)sender {
    if (self.searchController.isActive) {
        self.searchController.active = NO;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)sendAction:(UIBarButtonItem *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        switch (self.sendMode) {
            case SendModeCloud: {
                self.pendingAttachNodeOperations = (self.nodes.count * self.selectedGroupChatsMutableArray.count) + (self.nodes.count * self.selectedUsersMutableArray.count);
                
                MEGAChatAttachNodeRequestDelegate *chatAttachNodeRequestDelegate = [[MEGAChatAttachNodeRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest *request, MEGAChatError *error) {
                    if (--self.pendingAttachNodeOperations == 0) {
                        [self showSuccessMessage];
                    }
                }];
                
                for (MEGANode *node in self.nodes) {
                    for (MEGAChatListItem *chatListItem in self.selectedGroupChatsMutableArray) {
                        [Helper importNode:node toShareWithCompletion:^(MEGANode *node) {
                            [[MEGASdkManager sharedMEGAChatSdk] attachNodeToChat:chatListItem.chatId node:node.handle delegate:chatAttachNodeRequestDelegate];
                        }];
                    }
                    
                    for (MEGAUser *user in self.selectedUsersMutableArray) {
                        MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomByUser:user.handle];
                        if (chatRoom) {
                            [Helper importNode:node toShareWithCompletion:^(MEGANode *node) {
                                [[MEGASdkManager sharedMEGAChatSdk] attachNodeToChat:chatRoom.chatId node:node.handle delegate:chatAttachNodeRequestDelegate];
                            }];
                        } else {
                            MEGALogDebug(@"There is not a chat with %@, create the chat and attach", user.email);
                            MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
                            [peerList addPeerWithHandle:user.handle privilege:MEGAChatRoomPrivilegeStandard];
                            MEGAChatCreateChatGroupRequestDelegate *createChatGroupRequestDelegate = [[MEGAChatCreateChatGroupRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
                                [Helper importNode:node toShareWithCompletion:^(MEGANode *node) {
                                    [[MEGASdkManager sharedMEGAChatSdk] attachNodeToChat:chatRoom.chatId node:node.handle delegate:chatAttachNodeRequestDelegate];
                                }];
                            }];
                            [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:NO peers:peerList delegate:createChatGroupRequestDelegate];
                        }
                    }
                }
                
                if (self.searchController.isActive) {
                    self.searchController.active = NO;
                }
                
                [self dismissViewControllerAnimated:YES completion:nil];
                
                break;
            }
                
            case SendModeShareExtension:
                [self.sendToViewControllerDelegate sendToChats:self.selectedGroupChatsMutableArray andUsers:self.selectedUsersMutableArray];
                
                break;
                
            case SendModeForward: {
                if (self.searchController.isActive) {
                    self.searchController.active = NO;
                }
                [self dismissViewControllerAnimated:YES completion:^{
                    NSUInteger destinationCount = self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count;
                    self.pendingForwardOperations = self.messages.count * destinationCount;
                    self.sentMessages = [[NSMutableArray<MEGAChatMessage *> alloc] initWithCapacity:self.messages.count];
                    self.chatIdNumbers = [[NSMutableArray<NSNumber *> alloc] init];
                    for (MEGAChatListItem *chatListItem in self.selectedGroupChatsMutableArray) {
                        @synchronized(self.chatIdNumbers) {
                            [self.chatIdNumbers addObject:@(chatListItem.chatId)];
                            if (self.chatIdNumbers.count == destinationCount) {
                                [self forwardMessages];
                            }
                        }
                    }
                    for (MEGAUser *user in self.selectedUsersMutableArray) {
                        MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomByUser:user.handle];
                        if (chatRoom) {
                            @synchronized(self.chatIdNumbers) {
                                [self.chatIdNumbers addObject:@(chatRoom.chatId)];
                                if (self.chatIdNumbers.count == destinationCount) {
                                    [self forwardMessages];
                                }
                            }
                        } else {
                            MEGALogDebug(@"There is not a chat with %@, create the chat and attach", user.email);
                            MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
                            [peerList addPeerWithHandle:user.handle privilege:MEGAChatRoomPrivilegeStandard];
                            MEGAChatCreateChatGroupRequestDelegate *createChatGroupRequestDelegate = [[MEGAChatCreateChatGroupRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
                                @synchronized(self.chatIdNumbers) {
                                    [self.chatIdNumbers addObject:@(chatRoom.chatId)];
                                    if (self.chatIdNumbers.count == destinationCount) {
                                        [self forwardMessages];
                                    }
                                }
                            }];
                            [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:NO peers:peerList delegate:createChatGroupRequestDelegate];
                        }
                    }
                }];
                
                break;
            }
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchedGroupChatsMutableArray = nil;
    self.searchedUsersMutableArray = nil;
    self.searchedUsersAndGroupChatsMutableArray = nil;
    
    [self updateNavigationBarTitle];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if (searchController.isActive) {
        if ([searchString isEqualToString:@""]) {
            self.searchedGroupChatsMutableArray = self.groupChatsMutableArray;
            self.searchedUsersMutableArray = self.visibleUsersMutableArray;
            
            [self updateMainSearchArray];
        } else {
            NSPredicate *chatPredicate = [NSPredicate predicateWithFormat:@"SELF.title contains[c] %@", searchString];
            self.searchedGroupChatsMutableArray = [[self.groupChatsMutableArray filteredArrayUsingPredicate:chatPredicate] mutableCopy];
            
            NSPredicate *usersPredicate = [NSPredicate predicateWithFormat:@"SELF.mnz_fullName contains[c] %@", searchString];
            self.searchedUsersMutableArray = [[self.visibleUsersMutableArray filteredArrayUsingPredicate:usersPredicate] mutableCopy];
            
            [self updateMainSearchArray];
        }
    }
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id itemAtIndex = [self itemAtIndexPath:indexPath];
    
    if ([itemAtIndex isKindOfClass:MEGAChatListItem.class]) {
        MEGAChatListItem *chatListItem = itemAtIndex;
        ChatRoomCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"chatRoomCell" forIndexPath:indexPath];
        
        cell.onlineStatusView.hidden = YES;
        
        UIImage *avatar = [UIImage imageForName:chatListItem.title.uppercaseString size:cell.avatarImageView.frame.size backgroundColor:[UIColor mnz_secondaryGrayForTraitCollection:self.traitCollection] textColor:UIColor.whiteColor font:[UIFont systemFontOfSize:(cell.avatarImageView.frame.size.width/2.0f)]];
        cell.avatarImageView.image = avatar;
        
        cell.chatTitle.text = chatListItem.title;
        
        MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatListItem.chatId];
        cell.chatLastMessage.text = [self participantsNamesForChatRoom:chatRoom];
        cell.chatLastTime.hidden = YES;
        
        if (@available(iOS 11.0, *)) {
            cell.avatarImageView.accessibilityIgnoresInvertColors = YES;
        }
        
        for (MEGAChatListItem *tempChatListItem in self.selectedGroupChatsMutableArray) {
            if (tempChatListItem.chatId == chatListItem.chatId) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        cell.privateChatImageView.hidden = chatListItem.publicChat;
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
        
        return cell;
    }
    
    if ([itemAtIndex isKindOfClass:MEGAUser.class]) {
        MEGAUser *user = itemAtIndex;
        ContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contactCell" forIndexPath:indexPath];
        
        UIColor *color = [UIColor mnz_colorForStatusChange:[[MEGASdkManager sharedMEGAChatSdk] userOnlineStatus:user.handle]];
        if (color) {
            cell.onlineStatusView.backgroundColor = color;
            cell.onlineStatusView.hidden = NO;
        } else {
            cell.onlineStatusView.hidden = YES;
        }
        
        NSString *userName = user.mnz_fullName;
        cell.nameLabel.text = userName ? userName : user.email;
        cell.shareLabel.text = user.email;
        
        [cell.avatarImageView mnz_setImageForUserHandle:user.handle];
        
        if (@available(iOS 11.0, *)) {
            cell.avatarImageView.accessibilityIgnoresInvertColors = YES;
        }
        
        for (MEGAUser *tempUser in self.selectedUsersMutableArray) {
            if ([tempUser.email isEqualToString:user.email]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
        
        return cell;
    }
    
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.searchController.isActive ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    switch (section) {
        case 0:
            numberOfRows = self.searchController.isActive ? self.searchedUsersAndGroupChatsMutableArray.count : self.recentsMutableArray.count;
            break;
            
        case 1:
            numberOfRows = self.usersAndGroupChatsMutableArray.count;
            break;
            
        default:
            break;
    }
    
    self.sendBarButtonItem.enabled = ((self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) > 0);
    self.searchController.searchBar.userInteractionEnabled = self.searchController.isActive ? YES : (numberOfRows > 0);
    
    return numberOfRows;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.usersAndGroupChatsMutableArray.count == 0) {
        return nil;
    }
    if (self.searchController.isActive && self.searchedUsersAndGroupChatsMutableArray.count == 0) {
        return nil;
    }
    if (!self.searchController.isActive && section == 0 && self.recentsMutableArray.count == 0) {
        return nil;
    }
    
    switch (section) {
        case 0:
            return self.searchController.isActive ? self.chatsHeaderView : self.recentsHeaderView;
            
        case 1:
            return self.chatsHeaderView;
            
        default:
            return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 24;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id itemAtIndex = [self itemAtIndexPath:indexPath];
    if ([itemAtIndex isKindOfClass:MEGAChatListItem.class]) {
        MEGAChatListItem *chatListItem = itemAtIndex;
        [self.selectedGroupChatsMutableArray addObject:chatListItem];
        [self addItemToList:[[ItemListModel alloc] initWithChat:chatListItem]];
    } else if ([itemAtIndex isKindOfClass:MEGAUser.class]) {
        MEGAUser *user = itemAtIndex;
        [self.selectedUsersMutableArray addObject:user];
        [self addItemToList:[[ItemListModel alloc] initWithUser:user]];
    }
    
    if (self.searchController.searchBar.isFirstResponder) {
        self.searchController.searchBar.text = @"";
    }
    
    [self updateNavigationBarTitle];
    
    self.sendBarButtonItem.enabled = ((self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) > 0);
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    id itemAtIndex = [self itemAtIndexPath:indexPath];
    if ([itemAtIndex isKindOfClass:MEGAChatListItem.class]) {
        MEGAChatListItem *chatListItem = itemAtIndex;
        NSMutableArray *tempSelectedGroupChatsMutableArray = self.selectedGroupChatsMutableArray.copy;
        for (MEGAChatListItem *tempChatListItem in tempSelectedGroupChatsMutableArray) {
            if (tempChatListItem.chatId == chatListItem.chatId) {
                [self.selectedGroupChatsMutableArray removeObject:tempChatListItem];
            }
        }
        if (self.itemListVC) {
            [self.itemListVC removeItem:[[ItemListModel alloc] initWithChat:chatListItem]];
        }
    } else if ([itemAtIndex isKindOfClass:MEGAUser.class]) {
        MEGAUser *user = itemAtIndex;
        NSMutableArray *tempSelectedUsersMutableArray = self.selectedUsersMutableArray.copy;
        for (MEGAUser *tempUser in tempSelectedUsersMutableArray) {
            if ([tempUser.email isEqualToString:user.email]) {
                [self.selectedUsersMutableArray removeObject:tempUser];
            }
        }
        if (self.itemListVC) {
            [self.itemListVC removeItem:[[ItemListModel alloc] initWithUser:user]];
        }
    }
    
    if (self.searchController.searchBar.isFirstResponder) {
        self.searchController.searchBar.text = @"";
    }
    
    if ((self.selectedUsersMutableArray.count + self.selectedGroupChatsMutableArray.count) == 0 && self.itemListVC) {
        [self removeUsersListSubview];
    }
    
    [self updateNavigationBarTitle];
    
    self.sendBarButtonItem.enabled = ((self.selectedGroupChatsMutableArray.count + self.selectedUsersMutableArray.count) > 0);
}

#pragma mark - DZNEmptyDataSetSource

- (nullable UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView {
    EmptyStateView *emptyStateView = [EmptyStateView.alloc initWithImage:[self imageForEmptyState] title:[self titleForEmptyState] description:nil buttonTitle:nil];
    
    return emptyStateView;
}

#pragma mark - Empty State

- (NSString *)titleForEmptyState {
    NSString *text = @"";
    if (self.searchController.isActive) {
        if (self.searchController.searchBar.text.length) {
            text = AMLocalizedString(@"noResults", @"Title shown when you make a search and there is 'No Results'");
        }
    } else {
        text = AMLocalizedString(@"contactsEmptyState_title", @"Title shown when the Contacts section is empty, when you have not added any contact.");
    }
    
    return text;
}

- (UIImage *)imageForEmptyState {
    UIImage *image = nil;
    if (self.searchController.isActive) {
        if (self.searchController.searchBar.text.length) {
            image = [UIImage imageNamed:@"searchEmptyState"];
        }
    } else {
        image = [UIImage imageNamed:@"contactsEmptyState"];
    }
    
    return image;
}

#pragma mark - ItemListViewControllerDelegate

- (void)removeSelectedItem:(id)item {
    if ([[item class] isEqual:MEGAUser.class]) {
        [self.selectedUsersMutableArray removeObject:item];
    } else {
        [self.selectedGroupChatsMutableArray removeObject:item];
    }
    
    NSUInteger indexOfObject;
    if (self.searchController.isActive) {
        indexOfObject = [self.searchedUsersAndGroupChatsMutableArray indexOfObject:item];
        if (indexOfObject != NSNotFound) {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:indexOfObject inSection:0] animated:YES];
        }
    } else {
        indexOfObject = [self.recentsMutableArray indexOfObject:item];
        if (indexOfObject != NSNotFound) {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:indexOfObject inSection:0] animated:YES];
        }
        indexOfObject = [self.usersAndGroupChatsMutableArray indexOfObject:item];
        if (indexOfObject != NSNotFound) {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:indexOfObject inSection:1] animated:YES];
        }
    }
    
    if ((self.selectedUsersMutableArray.count + self.selectedGroupChatsMutableArray.count) == 0 && self.itemListVC) {
        [self removeUsersListSubview];
    }
    
    [self updateNavigationBarTitle];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end
