#import "ChatStatusTableViewController.h"

#import "NSDate+DateTools.h"
#import "SVProgressHUD.h"
#import "UIScrollView+EmptyDataSet.h"

#import "Helper.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"

#import "SelectableTableViewCell.h"

@interface ChatStatusTableViewController () <UITextFieldDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGAChatDelegate>

@property (nonatomic) MEGAChatPresenceConfig *presenceConfig;
@property (weak, nonatomic) NSIndexPath *currentStatusIndexPath;

@property (weak, nonatomic) IBOutlet UILabel *onlineLabel;
@property (weak, nonatomic) IBOutlet UIImageView *onlineRedCheckmarkImageView;
@property (weak, nonatomic) IBOutlet UILabel *awayLabel;
@property (weak, nonatomic) IBOutlet UIImageView *awayRedCheckmarkImageView;
@property (weak, nonatomic) IBOutlet UILabel *busyLabel;
@property (weak, nonatomic) IBOutlet UIImageView *busyRedCheckmarkImageView;
@property (weak, nonatomic) IBOutlet UILabel *offlineLabel;
@property (weak, nonatomic) IBOutlet UIImageView *offlineRedCheckmarkImageView;

@property (weak, nonatomic) IBOutlet UILabel *autoAwayLabel;
@property (weak, nonatomic) IBOutlet UISwitch *autoAwaySwitch;
@property (weak, nonatomic) IBOutlet UITextField *autoAwayTimeTextField;
@property (weak, nonatomic) IBOutlet UIButton *autoAwayTimeSaveButton;
@property (nonatomic) NSInteger autoAwayTimeoutInMinutes;

@property (weak, nonatomic) IBOutlet UILabel *statusPersistenceLabel;
@property (weak, nonatomic) IBOutlet UISwitch *statusPersistenceSwitch;

@property (weak, nonatomic) IBOutlet UILabel *lastActiveLabel;
@property (weak, nonatomic) IBOutlet UISwitch *lastActiveSwitch;

@end

@implementation ChatStatusTableViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.navigationItem.title = AMLocalizedString(@"status", @"Title that refers to the status of the chat (Either Online or Offline)");
    
    [self.tableView registerNib:[UINib nibWithNibName:@"SelectableTableViewCell" bundle:nil] forCellReuseIdentifier:@"SelectableTableViewCellID"];
    
    self.onlineLabel.text = AMLocalizedString(@"online", nil);
    self.awayLabel.text = AMLocalizedString(@"away", nil);
    self.busyLabel.text = AMLocalizedString(@"busy", nil);
    self.offlineLabel.text = AMLocalizedString(@"offline", @"Title of the Offline section");
    
    self.autoAwayLabel.text = AMLocalizedString(@"autoAway", nil);
    
    self.statusPersistenceLabel.text = AMLocalizedString(@"statusPersistence", nil);
    [self.autoAwayTimeSaveButton setTitle:AMLocalizedString(@"save", @"Button title to 'Save' the selected option") forState:UIControlStateNormal];
    
    NSAttributedString *lastSeenString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:AMLocalizedString(@"Last seen %s", nil), "..."] attributes:@{NSFontAttributeName:[UIFont italicSystemFontOfSize:17.0]}];
    NSMutableAttributedString *showLastSeenAttributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", AMLocalizedString(@"Show", @"Label shown next to a feature name that can be enabled or disabled, like in 'Show Last seen...'")]];
    [showLastSeenAttributedString appendAttributedString:lastSeenString];
    
    self.lastActiveLabel.attributedText = showLastSeenAttributedString;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGAChatSdk] addChatDelegate:self];
    
    self.presenceConfig = [[MEGASdkManager sharedMEGAChatSdk] presenceConfig];
    [self updateUIWithPresenceConfig];
    
    self.autoAwayTimeoutInMinutes = (NSInteger)(self.presenceConfig.autoAwayTimeout / 60);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGAChatSdk] removeChatDelegate:self];
}

#pragma mark - Private

- (void)internetConnectionChanged {
    [self.tableView reloadData];
}

- (void)updateUIWithPresenceConfig {
    [self deselectRowWithPreviousStatus];
    
    [self updateCurrentIndexPathForOnlineStatus];
    
    self.autoAwaySwitch.on = self.presenceConfig.isAutoAwayEnabled;
    [self updateAutoAwayTimeLabel];
    
    self.statusPersistenceSwitch.on = self.presenceConfig.isPersist;
    
    self.lastActiveSwitch.on = self.presenceConfig.isLastGreenVisible;
    
    [self.tableView reloadData];
}

- (void)deselectRowWithPreviousStatus {
    if (self.currentStatusIndexPath) {
        SelectableTableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.currentStatusIndexPath];
        cell.redCheckmarkImageView.hidden = YES;
    }
}

- (void)updateCurrentIndexPathForOnlineStatus {
    NSIndexPath *presenceIndexPath;
    switch (self.presenceConfig.onlineStatus) {
        case MEGAChatStatusOffline:
            presenceIndexPath = [NSIndexPath indexPathForRow:3 inSection:0];
            break;
            
        case MEGAChatStatusAway:
            presenceIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
            break;
            
        case MEGAChatStatusOnline:
            presenceIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            break;
            
        case MEGAChatStatusBusy:
            presenceIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
            break;
            
        case MEGAChatStatusInvalid:
            break;
    }
    self.currentStatusIndexPath = presenceIndexPath;
    
    SelectableTableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.currentStatusIndexPath];
    cell.redCheckmarkImageView.hidden = NO;
}

- (void)setPresenceAutoAway:(BOOL)boolValue {
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    [SVProgressHUD show];
    
    [[MEGASdkManager sharedMEGAChatSdk] setPresenceAutoaway:boolValue timeout:(self.autoAwayTimeoutInMinutes * 60)];
}

- (void)updateAutoAwayTimeLabel {
    NSString *xMinutes;
    if ((self.presenceConfig.autoAwayTimeout / 60) < 2) {
        xMinutes = AMLocalizedString(@"1Minute", nil);
        self.autoAwayTimeTextField.text = xMinutes;
    } else {
        xMinutes = AMLocalizedString(@"xMinutes", nil);
        self.autoAwayTimeTextField.text = [xMinutes stringByReplacingOccurrencesOfString:@"[X]" withString:[NSString stringWithFormat:@"%lld", (self.presenceConfig.autoAwayTimeout / 60)]];
    }
    
    self.autoAwayTimeSaveButton.hidden = YES;
}

#pragma mark - IBActions

- (IBAction)autoAwayValueChanged:(UISwitch *)sender {
    [self setPresenceAutoAway:sender.on];
}

- (IBAction)autoAwayTimeSaveButtonTouchUpInside:(UIButton *)sender {
    [self.autoAwayTimeTextField resignFirstResponder];
    
    self.autoAwayTimeSaveButton.enabled = NO;
    self.autoAwayTimeSaveButton.hidden = YES;
    
    if (self.autoAwayTimeTextField.text.intValue == 0) {
        self.autoAwayTimeTextField.text = @"1";
    }
    
    if ([self.autoAwayTimeTextField.text isEqualToString:[NSString stringWithFormat:@"%lld", (self.presenceConfig.autoAwayTimeout / 60)]]) {
        [self updateAutoAwayTimeLabel];
        return;
    }
    
    self.autoAwayTimeoutInMinutes = self.autoAwayTimeTextField.text.intValue;
    
    [self setPresenceAutoAway:self.autoAwaySwitch.isOn];
}

- (IBAction)statusPersistenceValueChanged:(UISwitch *)sender {
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    [SVProgressHUD show];
    
    [[MEGASdkManager sharedMEGAChatSdk] setPresencePersist:sender.on];
}

- (IBAction)lastGreenValueChanged:(UISwitch *)sender {
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    [SVProgressHUD show];
    
    [[MEGASdkManager sharedMEGAChatSdk] setLastGreenVisible:sender.on];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger numberOfSections = 0;
    if ([MEGAReachabilityManager isReachable]) {
        MEGAChatStatus onlineStatus = self.presenceConfig.onlineStatus;
        if (onlineStatus == MEGAChatStatusOnline) {
            if (self.presenceConfig.isPersist) {
                numberOfSections = 3; //If Status Persistence is active = No autoaway
            } else {
                numberOfSections = 4;
            }
        } else if (onlineStatus == MEGAChatStatusOffline) {
            numberOfSections = 2; //No autoaway nor persist
        } else {
            numberOfSections = 3; //No autoaway
        }
    }
    
    return numberOfSections;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *titleForFooter;
    switch (section) {
        case 0:
            titleForFooter = nil;
            break;
            
        case 1:
            titleForFooter = AMLocalizedString(@"Allow my contacts to see the last time I was active on MEGA. If disabled you won’t be able to see the activity status of your contacts.", @"Footer text to explain the meaning of the functionaly 'Last seen' of your chat status.");
            break;
            
        case 2:
            titleForFooter = AMLocalizedString(@"maintainMyChosenStatusAppearance", @"Footer text to explain the meaning of the functionaly 'Auto-away' of your chat status.");
            break;
            
        case 3:
            if ((self.presenceConfig.autoAwayTimeout / 60) >= 2) {
                titleForFooter = AMLocalizedString(@"showMeAwayAfterXMinutesOfInactivity", @"Footer text to explain the meaning of the functionaly Auto-away of your chat status.");
                titleForFooter = [titleForFooter stringByReplacingOccurrencesOfString:@"[X]" withString:[NSString stringWithFormat:@"%lld", (self.presenceConfig.autoAwayTimeout / 60)]];
            } else {
                titleForFooter = AMLocalizedString(@"showMeAwayAfter1MinuteOfInactivity", @"Footer text to explain the meaning of the functionaly Auto-away of your chat status.");
            }
            break;
    }
    
    return titleForFooter;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.autoAwayTimeTextField.isEditing) {
        [self.autoAwayTimeTextField resignFirstResponder];
    }
    
    if (self.currentStatusIndexPath == indexPath) {
        return;
    }

    if (indexPath.section == 0) {
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
        [SVProgressHUD show];
        
        switch (indexPath.row) {
            case 0: //Online
                [[MEGASdkManager sharedMEGAChatSdk] setOnlineStatus:MEGAChatStatusOnline];
                break;
                
            case 1: //Away
                [[MEGASdkManager sharedMEGAChatSdk] setOnlineStatus:MEGAChatStatusAway];
                break
                ;
            case 2: //Busy
                [[MEGASdkManager sharedMEGAChatSdk] setOnlineStatus:MEGAChatStatusBusy];
                break;
                
            case 3: //Offline
                [[MEGASdkManager sharedMEGAChatSdk] setOnlineStatus:MEGAChatStatusOffline];
                break;
        }
    } else if (indexPath.section == 3 && indexPath.row == 1) { //Auto-away - Number of minutes for Auto-away
        [self.autoAwayTimeTextField becomeFirstResponder];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    textField.text = [NSString stringWithFormat:@"%lld", (self.presenceConfig.autoAwayTimeout / 60)];
    
    self.autoAwayTimeSaveButton.enabled = YES;
    self.autoAwayTimeSaveButton.hidden = NO;
    
    return YES;
}
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    self.autoAwayTimeSaveButton.enabled = YES;
    
    return YES;
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text = @"";
    if (![MEGAReachabilityManager isReachable]) {
        text = AMLocalizedString(@"noInternetConnection",  @"Text shown on the app when you don't have connection to the internet or when you have lost it");
    }
    
    return [[NSAttributedString alloc] initWithString:text attributes:[Helper titleAttributesForEmptyState]];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    if (![MEGAReachabilityManager isReachable]) {
        return [UIImage imageNamed:@"noInternetEmptyState"];
    }
    
    return nil;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:NO];
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

#pragma mark - MEGAChatDelegate

- (void)onChatPresenceConfigUpdate:(MEGAChatSdk *)api presenceConfig:(MEGAChatPresenceConfig *)presenceConfig {
    if (presenceConfig.isPending) {
        return;
    }
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
    [SVProgressHUD dismiss];
    
    self.presenceConfig = presenceConfig;
    
    [self updateUIWithPresenceConfig];
}

@end
