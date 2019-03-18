#import <UIKit/UIKit.h>

@class MEGAChatListItem;

@interface ChatRoomCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *chatTitle;
@property (weak, nonatomic) IBOutlet UILabel *chatLastMessage;
@property (weak, nonatomic) IBOutlet UILabel *chatLastTime;
@property (weak, nonatomic) IBOutlet UIView *onlineStatusView;
@property (weak, nonatomic) IBOutlet UILabel *unreadCount;
@property (weak, nonatomic) IBOutlet UIView *unreadView;
@property (weak, nonatomic) IBOutlet UIImageView *privateChatImageView;
@property (weak, nonatomic) IBOutlet UIImageView *activeCallImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *unreadCountLabelHorizontalMarginConstraint;
@property (weak, nonatomic) IBOutlet UIStackView *onCallInfoView;
@property (weak, nonatomic) IBOutlet UILabel *onCallDuration;
@property (weak, nonatomic) IBOutlet UIImageView *onCallVideoImageView;
@property (weak, nonatomic) IBOutlet UIImageView *onCallMicImageView;

- (void)configureCellForArchivedChat;
- (void)updateUnreadCountChange:(NSInteger)unreadCount;
- (void)updateLastMessageForChatListItem:(MEGAChatListItem *)item;
- (void)configureCellForChatListItem:(MEGAChatListItem *)chatListItem;

@end
