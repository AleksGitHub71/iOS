
#import "RubbishBinTableViewController.h"

#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"

#import "MEGANavigationController.h"
#import "MEGAReachabilityManager.h"

#import "CustomModalAlertViewController.h"
#import "MEGASdkManager.h"
#import "MEGASdk+MNZCategory.h"
#import "UpgradeTableViewController.h"

@interface RubbishBinTableViewController () <MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UILabel *clearRubbishBinLabel;
@property (weak, nonatomic) IBOutlet UILabel *clearRubbishBinDetailLabel;

@property (weak, nonatomic) IBOutlet UILabel *rubbishBinCleaningSchedulerLabel;
@property (weak, nonatomic) IBOutlet UISwitch *rubbishBinCleaningSchedulerSwitch;

@property (weak, nonatomic) IBOutlet UILabel *removeFilesOlderThanLabel;
@property (weak, nonatomic) IBOutlet UILabel *removeFilesOlderThanDetailLabel;

@property NSInteger rubbishBinAutopurgePeriod;

@property (nonatomic) NSByteCountFormatter *byteCountFormatter;

@end

@implementation RubbishBinTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.byteCountFormatter = [[NSByteCountFormatter alloc] init];
    self.byteCountFormatter.countStyle = NSByteCountFormatterCountStyleMemory;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.title = AMLocalizedString(@"rubbishBinLabel", @"Title of one of the Settings sections where you can see your MEGA 'Rubbish Bin'");
    
    self.clearRubbishBinLabel.text = AMLocalizedString(@"emptyRubbishBin", @"Section title where you can 'Empty Rubbish Bin' of your MEGA account");
    NSNumber *rubbishBinSizeNumber = [[MEGASdkManager sharedMEGASdk] sizeForNode:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
    NSString *stringFromByteCount = [self.byteCountFormatter stringFromByteCount:rubbishBinSizeNumber.unsignedLongLongValue];
    self.clearRubbishBinDetailLabel.text = [self formatStringFromByteCountFormatter:stringFromByteCount];
    
    self.rubbishBinCleaningSchedulerLabel.text = [AMLocalizedString(@"Rubbish-Bin Cleaning Scheduler:", @"Title for the Rubbish-Bin Cleaning Scheduler feature") stringByReplacingOccurrencesOfString:@":" withString:@""];
    [self.rubbishBinCleaningSchedulerSwitch setOn:[[MEGASdkManager sharedMEGASdk] serverSideRubbishBinAutopurgeEnabled]];
    
    self.removeFilesOlderThanLabel.text = AMLocalizedString(@"Remove files older than", @"A rubbish bin scheduler setting which allows removing old files from the rubbish bin automatically. E.g. Remove files older than 15 days.");
    
    [[MEGASdkManager sharedMEGASdk] getRubbishBinAutopurgePeriodWithDelegate:self];
}

#pragma mark - Private

- (void)deleteFolderContentsInPath:(NSString *)folderPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *fileArray = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
    NSError *error = nil;
    for (NSString *filename in fileArray)  {
        if (![fileManager removeItemAtPath:[folderPath stringByAppendingPathComponent:filename] error:&error] ) {
            MEGALogError(@"Remove item at path failed with error: %@", error);
        }
    }
}

- (NSString *)formatStringFromByteCountFormatter:(NSString *)stringFromByteCount {
    NSArray *componentsSeparatedByStringArray = [stringFromByteCount componentsSeparatedByString:@" "];
    NSString *countString = [NSString mnz_stringWithoutUnitOfComponents:componentsSeparatedByStringArray];
    NSString *unitString = [NSString mnz_stringWithoutCountOfComponents:componentsSeparatedByStringArray];
    
    return [NSString stringWithFormat:@"%@ %@", countString, unitString];
}

- (void)scheduleRubbishBinClearingTextFieldDidChange:(UITextField *)sender {
    UIAlertController *scheduleRubbishBinClearingAlertController = (UIAlertController *)self.presentedViewController;
    if (scheduleRubbishBinClearingAlertController) {
        NSString *days = sender.text;
        UIAlertAction *doneAction = scheduleRubbishBinClearingAlertController.actions.lastObject;
        doneAction.enabled = days.mnz_isDecimalNumber;
    }
}

#pragma mark - IBActions

- (IBAction)scheduleRubbishBinClearingSwitchTouchUpInside:(UIButton *)sender {
    if (self.rubbishBinCleaningSchedulerSwitch.isOn) {
        if ([[MEGASdkManager sharedMEGASdk] mnz_isProAccount]) {
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                [[MEGASdkManager sharedMEGASdk] setRubbishBinAutopurgePeriodInDays:0 delegate:self];
            }
        } else {
            CustomModalAlertViewController *customModalAlertVC = [[CustomModalAlertViewController alloc] init];
            customModalAlertVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            customModalAlertVC.image = [UIImage imageNamed:@"retention_illustration"];
            customModalAlertVC.viewTitle = [AMLocalizedString(@"Rubbish-Bin Cleaning Scheduler:", @"Title for the Rubbish-Bin Cleaning Scheduler feature") stringByReplacingOccurrencesOfString:@":" withString:@""];
            customModalAlertVC.detail = AMLocalizedString(@"To disable the Rubbish-Bin Cleaning Scheduler or set a longer retention period, you need to subscribe to a PRO plan.", @"Description shown when you try to disable the feature Rubbish-Bin Cleaning Scheduler and you are a free user");
            customModalAlertVC.action = AMLocalizedString(@"seePlans", @"Button title to see the available pro plans in MEGA");
            customModalAlertVC.actionColor = [UIColor mnz_green00BFA5];
            customModalAlertVC.dismiss = AMLocalizedString(@"notNow", @"Used in the \"rich previews\", when the user first tries to send an url - we ask them before we generate previews for that URL, since we need to send them unencrypted to our servers.");
            customModalAlertVC.dismissColor = [UIColor colorFromHexString:@"899B9C"];
            __weak typeof(CustomModalAlertViewController) *weakCustom = customModalAlertVC;
            customModalAlertVC.completion = ^{
                [weakCustom dismissViewControllerAnimated:YES completion:^{
                    UpgradeTableViewController *upgradeTVC = [[UIStoryboard storyboardWithName:@"MyAccount" bundle:nil] instantiateViewControllerWithIdentifier:@"UpgradeID"];
                    MEGANavigationController *navigationController = [[MEGANavigationController alloc] initWithRootViewController:upgradeTVC];
                    
                    [UIApplication.mnz_visibleViewController presentViewController:navigationController animated:YES completion:nil];
                }];
            };
            
            customModalAlertVC.onDismiss = ^{
                [weakCustom dismissViewControllerAnimated:YES completion:nil];
            };
            
            [UIApplication.mnz_visibleViewController presentViewController:customModalAlertVC animated:YES completion:nil];
        }
    } else {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            NSInteger days = [[MEGASdkManager sharedMEGASdk] mnz_isProAccount] ? 90 : 14;
            [[MEGASdkManager sharedMEGASdk] setRubbishBinAutopurgePeriodInDays:days delegate:self];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[MEGASdkManager sharedMEGASdk] serverSideRubbishBinAutopurgeEnabled] ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *titleFooter;
    switch (section) {
        case 0:
            titleFooter = AMLocalizedString(@"emptyRubbishBinAlertTitle", @"Alert title shown when you tap 'Empty Rubbish Bin'");
            break;
            
        case 1:
            titleFooter = ([[MEGASdkManager sharedMEGASdk] mnz_isProAccount]) ? AMLocalizedString(@"The Rubbish Bin can be cleaned for you automatically. The minimum period is 7 days.", @"New server-side rubbish-bin cleaning scheduler description (for PRO users)") : AMLocalizedString(@"The Rubbish Bin is cleaned for you automatically. The minimum period is 7 days and your maximum period is 30 days.", @"New server-side rubbish-bin cleaning scheduler description (for Free users)");
            break;
    }
    
    return titleFooter;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: { //Clear Rubbish Bin
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                UIAlertController *emptyRubbishBinAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"emptyRubbishBinAlertTitle", @"Alert title shown when you tap 'Empty Rubbish Bin'") message:nil preferredStyle:UIAlertControllerStyleAlert];
                [emptyRubbishBinAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                [emptyRubbishBinAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [[MEGASdkManager sharedMEGASdk] cleanRubbishBin];
                }]];
                [self presentViewController:emptyRubbishBinAlertController animated:YES completion:nil];
            }
            break;
        }
            
        case 1: { //Remove files older than
            if (indexPath.row == 1) {
                if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                    UIAlertController *scheduleRubbishBinClearingAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"Remove files older than", @"A rubbish bin scheduler setting which allows removing old files from the rubbish bin automatically. E.g. Remove files older than 15 days.") message:nil preferredStyle:UIAlertControllerStyleAlert];
                    [scheduleRubbishBinClearingAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                        textField.keyboardType = UIKeyboardTypeNumberPad;
                        textField.placeholder = AMLocalizedString(@"Days", @"Label for any ‘Days’ button, link, text, title, etc. - (String as short as possible).");
                        [textField addTarget:self action:@selector(scheduleRubbishBinClearingTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                    }];
                    
                    [scheduleRubbishBinClearingAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                    UIAlertAction *doneAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"done", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        NSString *days = scheduleRubbishBinClearingAlertController.textFields.firstObject.text;
                        if ([[MEGASdkManager sharedMEGASdk] mnz_isProAccount]) {
                            if (days.integerValue > 365) {
                                days = @"365";
                            }
                        } else {
                            if (days.integerValue > 30) {
                                days = @"30";
                            }
                        }
                        
                        if (days.integerValue < 7) {
                            days = @"7";
                        }
                        
                        if (self.rubbishBinAutopurgePeriod != days.integerValue) {
                            [[MEGASdkManager sharedMEGASdk] setRubbishBinAutopurgePeriodInDays:days.integerValue delegate:self];
                        }
                    }];
                    doneAction.enabled = NO;
                    [scheduleRubbishBinClearingAlertController addAction:doneAction];
                    
                    [self presentViewController:scheduleRubbishBinClearingAlertController animated:YES completion:nil];
                }
            }
        }
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ((request.type == MEGARequestTypeGetAttrUser || request.type == MEGARequestTypeSetAttrUser) && (request.paramType == MEGAUserAttributeRubbishTime)) {
        if (error.type) {
            if (error.type == MEGAErrorTypeApiENoent) {
                self.rubbishBinAutopurgePeriod = [[MEGASdkManager sharedMEGASdk] mnz_isProAccount] ? 90 : 14;
                self.removeFilesOlderThanDetailLabel.text = [NSString stringWithFormat:@"%ld", (long)self.rubbishBinAutopurgePeriod];
            }
        } else {
            // Zero means that the rubbish-bin cleaning scheduler is disabled (only if the account is PRO). Any negative value means that the configured value is invalid.
            if (request.number.integerValue < 0) {
                return;
            }
            
            self.rubbishBinAutopurgePeriod = request.number.integerValue;
            if (self.rubbishBinAutopurgePeriod == 0) {
                self.rubbishBinCleaningSchedulerSwitch.on = NO;
            } else {
                self.rubbishBinCleaningSchedulerSwitch.on = YES;
            }
            self.removeFilesOlderThanDetailLabel.text = [NSString stringWithFormat:@"%ld", (long)self.rubbishBinAutopurgePeriod];
        }
        [self.tableView reloadData];
    }
}

@end
