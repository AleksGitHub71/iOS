
#import "MyAccountHallViewController.h"

#import "AchievementsViewController.h"
#import "ContactLinkQRViewController.h"
#import "ContactsViewController.h"
#import "Helper.h"
#import "MEGAPurchase.h"
#import "MEGASdk+MNZCategory.h"
#import "MEGAUserAlertList+MNZCategory.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "MEGA-Swift.h"
#import "MyAccountHallTableViewCell.h"
#import "NotificationsTableViewController.h"
#import "OfflineViewController.h"
#import "SettingsTableViewController.h"
#import "TransfersViewController.h"
#import "UpgradeTableViewController.h"
#import "UsageViewController.h"

typedef NS_ENUM(NSInteger, MyAccountSection) {
    MyAccountSectionMEGA = 0,
    MyAccountSectionOther
};

typedef NS_ENUM(NSInteger, MyAccount) {
    MyAccountStorage = 0,
    MyAccountUsage = 0,
    MyAccountSettings = 0,
    MyAccountContacts,
    MyAccountNotifications,
    MyAccountAchievements,
    MyAccountTransfers,
    MyAccountOffline
};

@interface MyAccountHallViewController () <UITableViewDataSource, UITableViewDelegate, MEGAPurchasePricingDelegate, MEGAGlobalDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buyPROBarButtonItem;

@property (weak, nonatomic) IBOutlet UILabel *businessLabel;
@property (weak, nonatomic) IBOutlet UIView *profileView;
@property (weak, nonatomic) IBOutlet UILabel *viewAndEditProfileLabel;
@property (weak, nonatomic) IBOutlet UIButton *viewAndEditProfileButton;
@property (weak, nonatomic) IBOutlet UIImageView *viewAndEditProfileImageView;
@property (weak, nonatomic) IBOutlet UIView *profileBottomSeparatorView;

@property (weak, nonatomic) IBOutlet UIView *addPhoneNumberView;
@property (weak, nonatomic) IBOutlet UIImageView *addPhoneNumberImageView;
@property (weak, nonatomic) IBOutlet UILabel *addPhoneNumberTitle;
@property (weak, nonatomic) IBOutlet UILabel *addPhoneNumberDescription;
@property (weak, nonatomic) IBOutlet UIView *addPhoneNumberBottomSeparatorView;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIImageView *qrCodeImageView;

@property (weak, nonatomic) IBOutlet UIView *tableFooterView;
@property (weak, nonatomic) IBOutlet UIView *tableFooterContainerView;
@property (weak, nonatomic) IBOutlet UILabel *tableFooterLabel;

@end

@implementation MyAccountHallViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
        
    self.viewAndEditProfileLabel.text = AMLocalizedString(@"viewAndEditProfile", @"Title show on the hall of My Account section that describes a place where you can view, edit and upgrade your account and profile");
    self.viewAndEditProfileButton.accessibilityLabel = AMLocalizedString(@"viewAndEditProfile", @"Title show on the hall of My Account section that describes a place where you can view, edit and upgrade your account and profile");

    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewAndEditProfileTouchUpInside:)];
    self.profileView.gestureRecognizers = @[tapGestureRecognizer];
    
    self.avatarImageView.image = self.avatarImageView.image.imageFlippedForRightToLeftLayoutDirection;
    self.qrCodeImageView.image = self.qrCodeImageView.image.imageFlippedForRightToLeftLayoutDirection;
    self.viewAndEditProfileImageView.image = self.viewAndEditProfileImageView.image.imageFlippedForRightToLeftLayoutDirection;
    self.addPhoneNumberImageView.image = self.addPhoneNumberImageView.image.imageFlippedForRightToLeftLayoutDirection;

    [[MEGAPurchase sharedInstance] setPricingsDelegate:self];
    
    UITapGestureRecognizer *tapAvatarGestureRecognizer = [UITapGestureRecognizer.alloc initWithTarget:self action:@selector(avatarTapped:)];
    self.avatarImageView.gestureRecognizers = @[tapAvatarGestureRecognizer];
    self.avatarImageView.userInteractionEnabled = YES;
    
    if (@available(iOS 11.0, *)) {
        self.avatarImageView.accessibilityIgnoresInvertColors = YES;
    }
    self.addPhoneNumberView.hidden = YES;
    
    [self configAddPhoneNumberTexts];
    
    [self updateAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[MEGASdkManager sharedMEGASdk] addMEGARequestDelegate:self];
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    
    if (MEGASdkManager.sharedMEGASdk.mnz_shouldRequestAccountDetails) {
        [MEGASdkManager.sharedMEGASdk getAccountDetails];
    }
    [self reloadUI];
    self.buyPROBarButtonItem.enabled = [MEGAPurchase sharedInstance].products.count;
    
    if (self.navigationController.isNavigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self configAddPhoneNumberView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
    [MEGASdkManager.sharedMEGASdk removeMEGARequestDelegate:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateAppearance];
            
            [self.tableView reloadData];
        }
    }
}

#pragma mark - Private

- (void)updateAppearance {
    self.view.backgroundColor = [UIColor mnz_backgroundGroupedForTraitCollection:self.traitCollection];
    
    self.tableView.backgroundColor = [UIColor mnz_backgroundGroupedForTraitCollection:self.traitCollection];
    self.tableView.separatorColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    self.profileView.backgroundColor = [UIColor mnz_mainBarsForTraitCollection:self.traitCollection];
    self.viewAndEditProfileLabel.textColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
    self.qrCodeImageView.image = [UIImage imageNamed:@"qrCodeIcon"].imageFlippedForRightToLeftLayoutDirection;
    self.profileBottomSeparatorView.backgroundColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    self.addPhoneNumberView.backgroundColor = [UIColor mnz_secondaryBackgroundGrouped:self.traitCollection];
    self.addPhoneNumberBottomSeparatorView.backgroundColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    if (MEGASdkManager.sharedMEGASdk.isBusinessAccount) {
        self.businessLabel.textColor = [UIColor mnz_subtitlesForTraitCollection:self.traitCollection];
        
        self.tableFooterContainerView.backgroundColor = [UIColor mnz_tertiaryBackgroundGrouped:self.traitCollection];
        self.tableFooterLabel.textColor = [UIColor mnz_subtitlesForTraitCollection:self.traitCollection];
    }
}

- (void)configAddPhoneNumberTexts {
    self.addPhoneNumberTitle.text = AMLocalizedString(@"Add Your Phone Number", nil);

    if (!MEGASdkManager.sharedMEGASdk.isAchievementsEnabled) {
        self.addPhoneNumberDescription.text = AMLocalizedString(@"Add your phone number to MEGA. This makes it easier for your contacts to find you on MEGA.", nil);
    } else {
        [MEGASdkManager.sharedMEGASdk getAccountAchievementsWithDelegate:[[MEGAGenericRequestDelegate alloc] initWithCompletion:^(MEGARequest * _Nonnull request, MEGAError * _Nonnull error) {
            if (error.type == MEGAErrorTypeApiOk) {
                NSString *storageText = [Helper memoryStyleStringFromByteCount:[request.megaAchievementsDetails classStorageForClassId:MEGAAchievementAddPhone]];
                self.addPhoneNumberDescription.text = [NSString stringWithFormat:AMLocalizedString(@"Get free %@ when you add your phone number. This makes it easier for your contacts to find you on MEGA.", nil), storageText];
            }
        }]];
    }
}

- (void)configAddPhoneNumberView {
    if (MEGASdkManager.sharedMEGASdk.smsVerifiedPhoneNumber != nil || MEGASdkManager.sharedMEGASdk.smsAllowedState != SMSStateOptInAndUnblock) {
        self.addPhoneNumberView.hidden = YES;
    } else {
        if (self.addPhoneNumberView.isHidden) {
            [UIView animateWithDuration:.75 animations:^{
                self.addPhoneNumberView.hidden = NO;
            }];
        }
    }
}

- (void)reloadUI {
    [self configNavigationItem];
    [self configTableFooterView];
    
    self.nameLabel.text = [[[MEGASdkManager sharedMEGASdk] myUser] mnz_fullName];
    [self setUserAvatar];
    
    [self.tableView reloadData];
}

- (void)openAchievements {
    NSArray *viewControllers = self.navigationController.viewControllers;
    if (viewControllers.count > 1) {
        [self.navigationController popToRootViewControllerAnimated:NO];
    }
    
    NSIndexPath *achievementsIndexPath = [NSIndexPath indexPathForRow:MyAccountAchievements inSection:MyAccountSectionMEGA];
    [self tableView:self.tableView didSelectRowAtIndexPath:achievementsIndexPath];
}

- (void)openOffline {
    NSArray *viewControllers = self.navigationController.viewControllers;
    if (viewControllers.count > 1) {
        [self.navigationController popToRootViewControllerAnimated:NO];
    }
    
    NSIndexPath *offlineIndexPath = [NSIndexPath indexPathForRow:MyAccountOffline inSection:MyAccountSectionMEGA];
    [self tableView:self.tableView didSelectRowAtIndexPath:offlineIndexPath];
}

- (void)avatarTapped:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        ContactLinkQRViewController *contactLinkVC = [[UIStoryboard storyboardWithName:@"ContactLinkQR" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactLinkQRViewControllerID"];
        contactLinkVC.scanCode = NO;
        [self presentViewController:contactLinkVC animated:YES completion:nil];
    }
}

- (void)setUserAvatar {
    MEGAUser *myUser = MEGASdkManager.sharedMEGASdk.myUser;
    [self.avatarImageView mnz_setImageForUserHandle:myUser.handle];
}

- (void)configNavigationItem {
    if (MEGASdkManager.sharedMEGASdk.isBusinessAccount) {
        self.navigationItem.rightBarButtonItem = nil;
        self.navigationItem.title = AMLocalizedString(@"myAccount", @"Title of the app section where you can see your account details");
        self.businessLabel.text = AMLocalizedString(@"Business", nil);
    } else {
        self.buyPROBarButtonItem.title = AMLocalizedString(@"upgrade", @"Caption of a button to upgrade the account to Pro status");
        self.navigationItem.title = AMLocalizedString(@"myAccount", @"Title of the app section where you can see your account details");
        self.businessLabel.text = @"";
    }
}

- (void)configTableFooterView {
    if (MEGASdkManager.sharedMEGASdk.isMasterBusinessAccount) {
        self.tableFooterLabel.text = AMLocalizedString(@"User management is only available from a desktop web browser.", @"Label presented to Admins that full management of the business is only available in a desktop web browser");
        self.tableView.tableFooterView = self.tableFooterView;
    } else {
        self.tableView.tableFooterView = [UIView.alloc initWithFrame:CGRectZero];
    }
}

#pragma mark - IBActions

- (IBAction)scanQrCode:(UIBarButtonItem *)sender {
    ContactLinkQRViewController *contactLinkVC = [[UIStoryboard storyboardWithName:@"ContactLinkQR" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactLinkQRViewControllerID"];
    contactLinkVC.scanCode = YES;
    contactLinkVC.modalPresentationStyle = UIModalPresentationFullScreen;
    
    [self presentViewController:contactLinkVC animated:YES completion:nil];
}

- (IBAction)buyPROTouchUpInside:(UIBarButtonItem *)sender {
    if ([[MEGASdkManager sharedMEGASdk] mnz_accountDetails]) {
        UpgradeTableViewController *upgradeTVC = [[UIStoryboard storyboardWithName:@"UpgradeAccount" bundle:nil] instantiateViewControllerWithIdentifier:@"UpgradeTableViewControllerID"];
        
        [self.navigationController pushViewController:upgradeTVC animated:YES];
    } else {
         [MEGAReachabilityManager isReachableHUDIfNot];
    }
}

- (IBAction)viewAndEditProfileTouchUpInside:(UIButton *)sender {
    ProfileViewController *profileViewController = [[UIStoryboard storyboardWithName:@"Profile" bundle:nil] instantiateViewControllerWithIdentifier:@"ProfileViewControllerID"];
    [self.navigationController pushViewController:profileViewController animated:YES];
}

- (IBAction)didTapAddPhoneNumberView {
    SMSNavigationViewController *smsNavigationController = [[SMSNavigationViewController alloc] initWithRootViewController:[SMSVerificationViewController instantiateWith:SMSVerificationTypeAddPhoneNumber]];
    smsNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:smsNavigationController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == MyAccountSectionMEGA) ? 6 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = @"MyAccountHallTableViewCellID";
    if (MEGASdkManager.sharedMEGASdk.isBusinessAccount && (indexPath.row == MyAccountUsage && indexPath.section == MyAccountSectionMEGA)) {
        identifier = @"MyAccountHallBusinessUsageTableViewCellID";
    }
    MyAccountHallTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[MyAccountHallTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    if (indexPath.section == MyAccountSectionOther) {
        cell.sectionLabel.text = AMLocalizedString(@"settingsTitle", @"Title of the Settings section");
        cell.iconImageView.image = [UIImage imageNamed:@"icon-settings"].imageFlippedForRightToLeftLayoutDirection;
        cell.pendingView.hidden = YES;
        cell.pendingLabel.text = nil;
        
        return cell;
    }
    
    switch (indexPath.row) {
        case MyAccountStorage: {
            if (MEGASdkManager.sharedMEGASdk.isBusinessAccount) {
                cell.sectionLabel.text = AMLocalizedString(@"Usage", @"Button title that goes to the section Usage where you can see how your MEGA space is used");
                cell.storageLabel.text = AMLocalizedString(@"Storage", @"Label for any ‘Storage’ button, link, text, title, etc. - (String as short as possible).");
                cell.transferLabel.text = AMLocalizedString(@"Transfer", nil);
                MEGAAccountDetails *accountDetails = MEGASdkManager.sharedMEGASdk.mnz_accountDetails;
                if (accountDetails) {
                    NSString *storageUsedString =  [NSString mnz_formatStringFromByteCountFormatter:[Helper memoryStyleStringFromByteCount:accountDetails.storageUsed.longLongValue]];
                    cell.storageUsedLabel.text = storageUsedString;
                    NSString *transferUsedString = [NSString mnz_formatStringFromByteCountFormatter:[Helper memoryStyleStringFromByteCount:accountDetails.transferOwnUsed.longLongValue]];
                    cell.transferUsedLabel.text = transferUsedString;
                } else {
                    cell.storageUsedLabel.text = @"";
                    cell.transferUsedLabel.text = @"";
                }
                
                cell.storageLabel.textColor = cell.storageUsedLabel.textColor = [UIColor mnz_blueForTraitCollection:self.traitCollection];
                cell.transferLabel.textColor = cell.transferUsedLabel.textColor = UIColor.systemGreenColor;
            } else {
                cell.iconImageView.image = [UIImage imageNamed:@"icon-storage"].imageFlippedForRightToLeftLayoutDirection;
                cell.sectionLabel.text = AMLocalizedString(@"Storage", @"Label for any ‘Storage’ button, link, text, title, etc. - (String as short as possible).");
                
                if (MEGASdkManager.sharedMEGASdk.mnz_accountDetails) {
                    MEGAAccountDetails *accountDetails = MEGASdkManager.sharedMEGASdk.mnz_accountDetails;
                    cell.detailLabel.text = [NSString stringWithFormat:@"%@ / %@", [Helper memoryStyleStringFromByteCount:accountDetails.storageUsed.longLongValue], [Helper memoryStyleStringFromByteCount:accountDetails.storageMax.longLongValue]];
                } else {
                    cell.detailTextLabel.text = @"";
                }
            }
            break;
        }
            
        case MyAccountNotifications: {
            cell.sectionLabel.text = AMLocalizedString(@"notifications", nil);
            cell.iconImageView.image = [UIImage imageNamed:@"icon-notifications"].imageFlippedForRightToLeftLayoutDirection;
            NSUInteger unseenUserAlerts = [MEGASdkManager sharedMEGASdk].userAlertList.mnz_relevantUnseenCount;
            if (unseenUserAlerts == 0) {
                cell.pendingView.hidden = YES;
                cell.pendingLabel.text = nil;
            } else {
                if (cell.pendingView.hidden) {
                    cell.pendingView.hidden = NO;
                    cell.pendingView.clipsToBounds = YES;
                }
                
                cell.pendingLabel.text = [NSString stringWithFormat:@"%tu", unseenUserAlerts];
            }
            break;
        }
            
        case MyAccountContacts: {
            cell.sectionLabel.text = AMLocalizedString(@"contactsTitle", @"Title of the Contacts section");
            cell.iconImageView.image = [UIImage imageNamed:@"icon-contacts"].imageFlippedForRightToLeftLayoutDirection;
            MEGAContactRequestList *incomingContactsLists = [[MEGASdkManager sharedMEGASdk] incomingContactRequests];
            NSUInteger incomingContacts = incomingContactsLists.size.unsignedIntegerValue;
            if (incomingContacts == 0) {
                cell.pendingView.hidden = YES;
                cell.pendingLabel.text = nil;
            } else {
                if (cell.pendingView.hidden) {
                    cell.pendingView.hidden = NO;
                    cell.pendingView.clipsToBounds = YES;
                }
                
                cell.pendingLabel.text = [NSString stringWithFormat:@"%tu", incomingContacts];
            }
            break;
        }
            
        case MyAccountAchievements: {
            cell.sectionLabel.text = AMLocalizedString(@"achievementsTitle", @"Title of the Achievements section");
            cell.iconImageView.image = [UIImage imageNamed:@"icon-achievements"].imageFlippedForRightToLeftLayoutDirection;
            cell.pendingView.hidden = YES;
            cell.pendingLabel.text = nil;
            break;
        }
            
        case MyAccountTransfers: {
            cell.sectionLabel.text = AMLocalizedString(@"transfers", @"Title of the Transfers section");
            cell.iconImageView.image = [UIImage imageNamed:@"icon-transfers"].imageFlippedForRightToLeftLayoutDirection;
            cell.pendingView.hidden = YES;
            cell.pendingLabel.text = nil;
            break;
        }
            
        case MyAccountOffline: {
            cell.sectionLabel.text = AMLocalizedString(@"offline", @"Title of the Offline section");
            cell.iconImageView.image = [UIImage imageNamed:@"icon-offline"].imageFlippedForRightToLeftLayoutDirection;
            cell.pendingView.hidden = YES;
            cell.pendingLabel.text = nil;
            break;
        }
    }
    
    [cell.sectionLabel sizeToFit];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat heightForRow;
    if (indexPath.row == MyAccountAchievements && ![MEGASdkManager.sharedMEGASdk isAchievementsEnabled] | MEGASdkManager.sharedMEGASdk.isBusinessAccount) {
        heightForRow = 0.0f;
    } else if (indexPath.row == MyAccountUsage && indexPath.section == MyAccountSectionMEGA && MEGASdkManager.sharedMEGASdk.isBusinessAccount) {
        heightForRow = 94;
    } else {
        heightForRow = 60;
    }
    
    return heightForRow;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MyAccountSectionOther) {
        SettingsTableViewController *settingsTVC = [[UIStoryboard storyboardWithName:@"Settings" bundle:nil] instantiateViewControllerWithIdentifier:@"SettingsTableViewControllerID"];
        [self.navigationController pushViewController:settingsTVC animated:YES];
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    switch (indexPath.row) {
        case MyAccountStorage: {
            if ([[MEGASdkManager sharedMEGASdk] mnz_accountDetails]) {
                UsageViewController *usageVC = [[UIStoryboard storyboardWithName:@"Usage" bundle:nil] instantiateViewControllerWithIdentifier:@"UsageViewControllerID"];
                [self.navigationController pushViewController:usageVC animated:YES];
            } else {
                MEGALogError(@"Account details unavailable");
            }
            
            break;
        }
            
        case MyAccountNotifications: {
            NotificationsTableViewController *notificationsTVC = [[UIStoryboard storyboardWithName:@"Notifications" bundle:nil] instantiateViewControllerWithIdentifier:@"NotificationsTableViewControllerID"];
            [self.navigationController pushViewController:notificationsTVC animated:YES];
            break;
        }
            
        case MyAccountContacts: {
            ContactsViewController *contactsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsViewControllerID"];
            [self.navigationController pushViewController:contactsVC animated:YES];
            break;
        }
            
        case MyAccountAchievements: {
            AchievementsViewController *achievementsVC = [[UIStoryboard storyboardWithName:@"Achievements" bundle:nil] instantiateViewControllerWithIdentifier:@"AchievementsViewControllerID"];
            [self.navigationController pushViewController:achievementsVC animated:YES];
            break;
        }
            
        case MyAccountTransfers: {
            TransfersViewController *transferVC = [[UIStoryboard storyboardWithName:@"Transfers" bundle:nil] instantiateViewControllerWithIdentifier:@"TransfersViewControllerID"];
            [self.navigationController pushViewController:transferVC animated:YES];
            break;
        }
            
        case MyAccountOffline: {
            OfflineViewController *offlineVC = [[UIStoryboard storyboardWithName:@"Offline" bundle:nil] instantiateViewControllerWithIdentifier:@"OfflineViewControllerID"];
            [self.navigationController pushViewController:offlineVC animated:YES];
            break;
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

//To remove the space between the table view and the profile view or the add phone number view
- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.01f;
}

#pragma mark - MEGAPurchasePricingDelegate

- (void)pricingsReady {
    self.buyPROBarButtonItem.enabled = YES;
}

#pragma mark - MEGAGlobalDelegate

- (void)onContactRequestsUpdate:(MEGASdk *)api contactRequestList:(MEGAContactRequestList *)contactRequestList {
    NSIndexPath *contactsIndexPath = [NSIndexPath indexPathForRow:MyAccountContacts inSection:MyAccountSectionMEGA];
    [self.tableView reloadRowsAtIndexPaths:@[contactsIndexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)onUserAlertsUpdate:(MEGASdk *)api userAlertList:(MEGAUserAlertList *)userAlertList {
    NSIndexPath *notificationsIndexPath = [NSIndexPath indexPathForRow:MyAccountNotifications inSection:MyAccountSectionMEGA];
    [self.tableView reloadRowsAtIndexPaths:@[notificationsIndexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    switch (request.type) {
        case MEGARequestTypeAccountDetails:
            if (error.type) {
                return;
            }
            [self reloadUI];
            
            break;
            
        case MEGARequestTypeGetAttrUser: {
            if (error.type) {
                return;
            }
            
            if (request.file) {
                [self setUserAvatar];
            }
            
            if (request.paramType == MEGAUserAttributeFirstname || request.paramType == MEGAUserAttributeLastname) {
                self.nameLabel.text = api.myUser.mnz_fullName;
            }
            break;
        }
            
        default:
            break;
    }
}

@end
