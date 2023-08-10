#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, ContactsMode) {
    ContactsModeDefault = 0,
    ContactsModeShareFoldersWith = 1,
    ContactsModeFolderSharedWith = 2,
    ContactsModeChatStartConversation = 3,
    ContactsModeChatAddParticipant = 4,
    ContactsModeChatAttachParticipant = 5,
    ContactsModeChatCreateGroup = 6,
    ContactsModeChatNamingGroup = 7,
    ContactsModeInviteParticipants = 8,
    ContactsModeScheduleMeeting = 9
};

typedef NS_ENUM(NSUInteger, ChatOptionType) {
    ChatOptionTypeNone = 0,
    ChatOptionTypeMeeting = 1,
    ChatOptionTypeNonMeeting = 2
};

@protocol ContatctsViewControllerDelegate <NSObject>
@optional
- (void)nodeEditCompleted:(BOOL)complete;
@end

@class ItemListModel, UserEntity;

@interface ContactsViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareFolderWithBarButtonItem;

@property (weak, nonatomic) IBOutlet UIView *contactsNotVerifiedView;

@property (nonatomic) ContactsMode contactsMode;
@property (nonatomic) ChatOptionType chatOptionType;

@property (nonatomic) BOOL avoidPresentIncomingPendingContactRequests;

@property (nonatomic, strong) MEGANode *node;
@property (nonatomic, strong) NSArray *nodesArray;
@property (nonatomic, strong) NSMutableArray *selectedUsersArray;
@property (nonatomic, strong) NSMutableArray<MEGAUser *> *visibleUsersArray;
@property (strong, nonatomic) UISearchController *searchController;

@property (nonatomic, copy) void(^userSelected)(NSArray<MEGAUser *> *);
@property (nonatomic, copy) void(^chatSelected)(uint64_t);
@property (nonatomic, copy) void(^createGroupChat)(NSArray *,  NSString *, BOOL, BOOL, BOOL);

@property (strong, nonatomic) NSMutableDictionary *participantsMutableDictionary;
@property (nonatomic, weak) id<ContatctsViewControllerDelegate> contatctsViewControllerDelegate;

- (void)shareNodesWithLevel:(MEGAShareType)shareType nodes:(NSArray *)nodes;
- (void)shareNodesWithLevel:(MEGAShareType)shareType;
- (void)selectPermissionsFromButton:(UIBarButtonItem *)sourceButton;
- (void)addItemsToList:(NSArray<ItemListModel *> *)items;

@end
