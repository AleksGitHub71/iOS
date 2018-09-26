#import <UIKit/UIKit.h>

@interface ProductTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *upperLineView;
@property (weak, nonatomic) IBOutlet UIImageView *productImageView;
@property (weak, nonatomic) IBOutlet UILabel *productStorageLabel;
@property (weak, nonatomic) IBOutlet UILabel *productBandwidthLabel;
@property (weak, nonatomic) IBOutlet UILabel *subjectToYourParticipationLabel;
@property (weak, nonatomic) IBOutlet UILabel *productPriceLabel;
@property (weak, nonatomic) IBOutlet UIView *productNameView;
@property (weak, nonatomic) IBOutlet UILabel *productNameLabel;

@property (weak, nonatomic) IBOutlet UIImageView *disclosureIndicatorImageView;

@property (weak, nonatomic) IBOutlet UIView *underLineView;

@end
