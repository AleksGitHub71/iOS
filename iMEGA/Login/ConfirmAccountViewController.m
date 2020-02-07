#import "ConfirmAccountViewController.h"

#import "SAMKeychain.h"
#import "SVProgressHUD.h"

#import "Helper.h"
#import "MEGALinkManager.h"
#import "MEGALoginRequestDelegate.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"

#import "InputView.h"
#import "PasswordView.h"

@interface ConfirmAccountViewController () <UITextFieldDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet UIImageView *logoImageView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmTextTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet UILabel *confirmTextLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmTextBottomLayoutConstraint;

@property (weak, nonatomic) IBOutlet InputView *emailInputView;
@property (weak, nonatomic) IBOutlet PasswordView *passwordView;

@property (weak, nonatomic) IBOutlet UIButton *confirmAccountButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@end

@implementation ConfirmAccountViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (UIDevice.currentDevice.iPhone4X) {
        self.logoTopLayoutConstraint.constant = 12.f;
        self.confirmTextTopLayoutConstraint.constant = 6.f;
        self.confirmTextBottomLayoutConstraint.constant = 6.f;
    } else if (UIDevice.currentDevice.iPhone5X || (UIDevice.currentDevice.iPadDevice && UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation))) {
        self.logoTopLayoutConstraint.constant = 24.f;
    }
    
    switch (self.urlType) {
        case URLTypeConfirmationLink:
            self.confirmTextLabel.text = AMLocalizedString(@"confirmText", @"Text shown on the confirm account view to remind the user what to do");
            [self.confirmAccountButton setTitle:AMLocalizedString(@"Confirm account", @"Label for any ‘Confirm account’ button, link, text, title, etc. - (String as short as possible).") forState:UIControlStateNormal];
            
            break;
        
        case URLTypeChangeEmailLink:
            self.confirmTextLabel.text = AMLocalizedString(@"verifyYourEmailAddress_description", @"Text shown on the confirm email view to remind the user what to do");
            [self.confirmAccountButton setTitle:AMLocalizedString(@"confirmEmail", @"Button text for the user to confirm their change of email address.") forState:UIControlStateNormal];
            
            break;
        
        case URLTypeCancelAccountLink:
            self.confirmTextLabel.text = AMLocalizedString(@"enterYourPasswordToConfirmThatYouWanToClose", @"Account closure, message shown when you click on the link in the email to confirm the closure of your account");
            [self.confirmAccountButton setTitle:AMLocalizedString(@"closeAccount", @"Account closure, password check dialog when user click on closure email.") forState:UIControlStateNormal];
            
            break;
            
        default:
            break;
    }
    
    [self.cancelButton setTitle:AMLocalizedString(@"cancel", nil) forState:UIControlStateNormal];
    
    self.emailInputView.inputTextField.text = self.emailString;
    self.emailInputView.inputTextField.enabled = NO;
    self.emailInputView.inputTextField.keyboardType = UIKeyboardTypeEmailAddress;
    if (@available(iOS 11.0, *)) {
        self.emailInputView.inputTextField.textContentType = UITextContentTypeUsername;
    }
    
    self.passwordView.passwordTextField.delegate = self;
    if (@available(iOS 11.0, *)) {
        self.passwordView.passwordTextField.textContentType = UITextContentTypePassword;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UIDevice.currentDevice.iPhoneDevice) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - IBActions

- (IBAction)confirmTouchUpInside:(UIButton *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        if ([self validateForm]) {
            [SVProgressHUD show];
            [self lockUI:YES];
            switch (self.urlType) {
                case URLTypeConfirmationLink:
                    [[MEGASdkManager sharedMEGASdk] confirmAccountWithLink:self.confirmationLinkString password:self.passwordView.passwordTextField.text delegate:self];
                    
                    break;
                    
                case URLTypeChangeEmailLink:
                    [[MEGASdkManager sharedMEGASdk] confirmChangeEmailWithLink:self.confirmationLinkString password:self.passwordView.passwordTextField.text delegate:self];
                    
                    break;
                    
                case URLTypeCancelAccountLink:
                    [[MEGASdkManager sharedMEGASdk] confirmCancelAccountWithLink:self.confirmationLinkString password:self.passwordView.passwordTextField.text delegate:self];
                    
                    break;
                    
                default:
                    break;
            }
        }
    }
}

- (IBAction)cancelTouchUpInside:(UIButton *)sender {
    [self.passwordView.passwordTextField resignFirstResponder];

    if (self.urlType == URLTypeConfirmationLink) {
        NSString *message = AMLocalizedString(@"areYouSureYouWantToAbortTheRegistration", @"Asking whether the user really wants to abort/stop the registration process or continue on.");
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [MEGALinkManager resetLinkAndURLType];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [MEGALinkManager resetLinkAndURLType];
            
            if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionId"]) {
                [[MEGASdkManager sharedMEGASdk] logout];
                [Helper clearEphemeralSession];
            }
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Private

- (BOOL)validateForm {
    BOOL validPassword = !self.passwordView.passwordTextField.text.mnz_isEmpty;
    
    if (validPassword) {
        [self.passwordView setErrorState:NO];
    } else {
        [self.passwordView setErrorState:YES withText:AMLocalizedString(@"passwordInvalidFormat", @"Enter a valid password")];
        [self.passwordView.passwordTextField becomeFirstResponder];
    }
    
    return validPassword;
}

- (void)lockUI:(BOOL)boolValue {
    self.passwordView.passwordTextField.enabled = !boolValue;
    self.cancelButton.enabled = !boolValue;
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.passwordView.toggleSecureButton.hidden = NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self validateForm];
    self.passwordView.passwordTextField.secureTextEntry = YES;
    [self.passwordView configureSecureTextEntry];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self.passwordView setErrorState:NO];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.passwordView.passwordTextField resignFirstResponder];
    [self confirmTouchUpInside:self.confirmAccountButton];
    return YES;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
        [SVProgressHUD dismiss];
        
        [self lockUI:NO];
        
        switch ([error type]) {
            case MEGAErrorTypeApiEKey:
            case MEGAErrorTypeApiENoent: { //MEGARequestTypeConfirmAccount, MEGARequestTypeConfirmChangeEmailLink, MEGARequestTypeConfirmCancelLink
                [self.passwordView setErrorState:YES];
                [self.passwordView.passwordTextField becomeFirstResponder];
                break;
            }
                
            case MEGAErrorTypeApiEAccess: {
                UIAlertController *alreadyLoggedInAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"error", nil) message:AMLocalizedString(@"This link is not related to this account. Please log in with the correct account.", @"Error message shown when opening a link with an account that not corresponds to the link") preferredStyle:UIAlertControllerStyleAlert];
                [alreadyLoggedInAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDestructive handler:nil]];
                
                [self presentViewController:alreadyLoggedInAlertController animated:YES completion:nil];
                break;
            }
                
            case MEGAErrorTypeApiEExist: {
                [self.emailInputView setErrorState:YES withText:AMLocalizedString(@"emailAlreadyInUse", @"Error shown when the user tries to change his mail to one that is already used")];
                break;
            }
                
            case MEGAErrorTypeApiESid:
                break;
                
            default:
                [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"%@ (%ld)", error.name, (long)error.type]];
                break;
        }
        
        return;
    }
    
    switch ([request type]) {
        case MEGARequestTypeConfirmAccount: {
            if ([MEGASdkManager sharedMEGAChatSdk] == nil) {
                [MEGASdkManager createSharedMEGAChatSdk];
            }
            
            MEGAChatInit chatInit = [[MEGASdkManager sharedMEGAChatSdk] initKarereWithSid:nil];
            if (chatInit != MEGAChatInitWaitingNewSession) {
                MEGALogError(@"Init Karere without sesion must return waiting for a new sesion");
                [[MEGASdkManager sharedMEGAChatSdk] logout];
            }

            if ([api isLoggedIn] <= 1) {
                MEGALoginRequestDelegate *loginRequestDelegate = [[MEGALoginRequestDelegate alloc] init];
                [api loginWithEmail:self.emailInputView.inputTextField.text password:self.passwordView.passwordTextField.text delegate:loginRequestDelegate];

                [Helper clearEphemeralSession];
            }
            break;
        }
            
        case MEGARequestTypeLogout: {
            [Helper logoutFromConfirmAccount];
            [[MEGASdkManager sharedMEGASdk] confirmAccountWithLink:self.confirmationLinkString password:self.passwordView.passwordTextField.text delegate:self];
            break;
        }
            
        case MEGARequestTypeConfirmChangeEmailLink: {
            [SVProgressHUD dismiss];
            [self.passwordView.passwordTextField resignFirstResponder];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"emailHasChanged" object:nil];
            [self dismissViewControllerAnimated:YES completion:^{
                NSString *alertMessage = [AMLocalizedString(@"congratulationsNewEmailAddress", @"The [X] will be replaced with the e-mail address.") stringByReplacingOccurrencesOfString:@"[X]" withString:request.email];
                UIAlertController *newEmailAddressAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"newEmail", @"Hint text to suggest that the user have to write the new email on it") message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
                
                [newEmailAddressAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:nil]];
                
                [UIApplication.mnz_presentingViewController presentViewController:newEmailAddressAlertController animated:YES completion:nil];
            }];
            break;
        }
            
        default:
            break;
    }
}

@end
