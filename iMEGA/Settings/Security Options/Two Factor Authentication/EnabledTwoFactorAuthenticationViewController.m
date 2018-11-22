
#import "EnabledTwoFactorAuthenticationViewController.h"

#import "Helper.h"
#import "MEGASdkManager.h"
#import "UIApplication+MNZCategory.h"

@interface EnabledTwoFactorAuthenticationViewController () <MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *firstLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondLabel;

@property (weak, nonatomic) IBOutlet UIView *recoveryKeyView;

@property (weak, nonatomic) IBOutlet UIButton *exportRecoveryButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;

@property (getter=isRecoveryKeyExported) BOOL recoveryKeyExported;

@end

@implementation EnabledTwoFactorAuthenticationViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (([[UIDevice currentDevice] iPhone4X])) {
        self.recoveryKeyView.hidden = YES;
    }
    
    self.navigationItem.title = AMLocalizedString(@"twoFactorAuthentication", @"A title for the Two-Factor Authentication section on the My Account - Security page.");
    self.titleLabel.text = AMLocalizedString(@"twoFactorAuthenticationEnabled", @"A title on the mobile web client page showing that 2FA has been enabled successfully.");
    self.firstLabel.text = AMLocalizedString(@"twoFactorAuthenticationEnabledDescription", @"A message on the dialog shown after 2FA was successfully enabled.");
    self.secondLabel.text = AMLocalizedString(@"twoFactorAuthenticationEnabledWarning", @"An informational message on the Backup Recovery Key dialog.");
    
    self.recoveryKeyView.layer.borderColor = [UIColor mnz_grayE3E3E3].CGColor;
    
    [self.exportRecoveryButton setTitle:AMLocalizedString(@"exportRecoveryKey", @"A dialog title to export the Recovery Key for the current user.") forState:UIControlStateNormal];
    [self.closeButton setTitle:AMLocalizedString(@"close", @"A button label. The button allows the user to close the conversation.") forState:UIControlStateNormal];
    self.closeButton.layer.borderColor = [UIColor mnz_gray999999].CGColor;
    
    [[MEGASdkManager sharedMEGASdk] isMasterKeyExportedWithDelegate:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] iPhoneDevice]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private

- (void)showSaveYourRecoveryKeyAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"pleaseSaveYourRecoveryKey", @"A warning message on the Backup Recovery Key dialog to tell the user to backup their Recovery Key to their local computer.") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
    [UIApplication.mnz_presentingViewController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - IBActions

- (IBAction)exportRecoveryKeyTouchUpInside:(UIButton *)sender {
    [Helper showExportMasterKeyInView:self completion:nil];
}

- (IBAction)closeTouchUpInside:(UIButton *)sender {
    if (self.isRecoveryKeyExported) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self showSaveYourRecoveryKeyAlert];
    }
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if (error.type) {
        return;
    }
    
    if (request.type == MEGARequestTypeGetAttrUser) {
        self.recoveryKeyExported = request.access;
    }              
}

@end
