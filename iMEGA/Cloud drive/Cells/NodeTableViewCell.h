
/*
 NodeTableViewCellFlavor is used to tell how `NodeTableViewCell` being used, e.g. CloudDriveCell, RecentCell, SharedLinkCell.
 In fact, this is a work around to tell the different scenario the same cell is reused, which should be prohibited, as it's
 hard to maintain. We should improve this later with table cell model.
 */
typedef NS_ENUM(NSInteger, NodeTableViewCellFlavor) {
    NodeTableViewCellFlavorCloudDrive = 0,
    NodeTableViewCellFlavorVersions,
    NodeTableViewCellFlavorRecentAction,
    NodeTableViewCellFlavorSharedLink,
    NodeTableViewCellExplorerView
};

@interface NodeTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leadingConstraint;
@property (weak, nonatomic) IBOutlet UIImageView *middleImageView;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIView *labelView;
@property (weak, nonatomic) IBOutlet UIImageView *labelImageView;
@property (weak, nonatomic) IBOutlet UIView *favouriteView;
@property (weak, nonatomic) IBOutlet UIImageView *favouriteImageView;
@property (weak, nonatomic) IBOutlet UIView *linkView;
@property (weak, nonatomic) IBOutlet UIImageView *linkImageView;

@property (weak, nonatomic) IBOutlet UIImageView *downloadingArrowImageView;

@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;

@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (weak, nonatomic) IBOutlet UIImageView *incomingOrOutgoingImageView;
@property (weak, nonatomic) IBOutlet UIImageView *uploadOrVersionImageView;

@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;

@property (weak, nonatomic) IBOutlet UIView *disclosureIndicatorView;

@property (weak, nonatomic) IBOutlet UIView *separatorView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelButtonTrailingConstraint;

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailPlayImageView;

@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIImageView *versionedImageView;

@property (strong, nonatomic) MEGANode *node;
@property (strong, nonatomic) MEGARecentActionBucket *recentActionBucket;

@property (nonatomic) NodeTableViewCellFlavor cellFlavor;

@property (nonatomic, copy) void(^moreButtonAction)(UIButton *) ;

- (void)configureCellForNode:(MEGANode *)node api:(MEGASdk *)api;

- (void)configureForRecentAction:(MEGARecentActionBucket *)recentActionBucket;

@end
