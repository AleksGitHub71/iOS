#import <UIKit/UIKit.h>
#import "MEGASdkManager.h"

typedef NS_ENUM (NSInteger, DisplayMode) {
    DisplayModeCloudDrive = 0,
    DisplayModeRubbishBin,
    DisplayModeSharedItem
};

@interface CloudDriveTableViewController : UITableViewController

@property (nonatomic, strong) MEGANode *parentNode;
@property (nonatomic, strong) MEGAUser *user;
@property (nonatomic) DisplayMode displayMode;

@end
