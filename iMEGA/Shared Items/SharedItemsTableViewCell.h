#import <UIKit/UIKit.h>


@protocol SharedItemsTableViewCellDelegate

@optional

@property (nonatomic, readonly, getter=isPseudoEditing) BOOL pseudoEdit;

@end

@interface SharedItemsTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIButton *permissionsButton;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;

@property (nonatomic) uint64_t nodeHandle;

@property (nonatomic, assign) id <SharedItemsTableViewCellDelegate> customEditDelegate;

@property (assign, nonatomic) BOOL isSwiping;

@end
