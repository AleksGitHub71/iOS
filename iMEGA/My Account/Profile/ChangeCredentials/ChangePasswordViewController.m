
#import "ChangePasswordViewController.h"

#import "MEGASdkManager.h"
#import "MEGAReachabilityManager.h"
#import "NSString+MNZCategory.h"
#import "SVProgressHUD.h"
#import "UIApplication+MNZCategory.h"
#import "UITextField+MNZCategory.h"

#import "AwaitingEmailConfirmationView.h"
#import "Helper.h"
#import "InputView.h"
#import "PasswordStrengthIndicatorView.h"
#import "PasswordView.h"
#import "TwoFactorAuthenticationViewController.h"

typedef NS_ENUM(NSUInteger, TextFieldTag) {
    CurrentEmailTextFieldTag = 0,
    NewEmailTextFieldTag,
    ConfirmEmailTextFieldTag,
    CurrentPasswordTextFieldTag,
    NewPasswordTextFieldTag,
    ConfirmPasswordTextFieldTag
};

@interface ChangePasswordViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate, MEGARequestDelegate, MEGAGlobalDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet InputView *currentEmailInputView;
@property (weak, nonatomic) IBOutlet InputView *theNewEmailInputView;
@property (weak, nonatomic) IBOutlet InputView *confirmEmailInputView;

@property (weak, nonatomic) IBOutlet PasswordView *currentPasswordView;
@property (weak, nonatomic) IBOutlet PasswordView *theNewPasswordView;
@property (weak, nonatomic) IBOutlet PasswordStrengthIndicatorView *passwordStrengthIndicatorView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *passwordStrengthIndicatorViewHeightLayoutConstraint;
@property (weak, nonatomic) IBOutlet PasswordView *confirmPasswordView;

@property (weak, nonatomic) InputView *activeInputView;
@property (weak, nonatomic) PasswordView *activePasswordView;

@property (strong, nonatomic) UIBarButtonItem *confirmButton;

@property (strong, nonatomic) UITapGestureRecognizer *tapGesture;

@end

@implementation ChangePasswordViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.passwordStrengthIndicatorViewHeightLayoutConstraint.constant = 0;
    self.confirmButton = [[UIBarButtonItem alloc] initWithTitle:AMLocalizedString(@"save", @"save password or email associated to an account.") style:UIBarButtonItemStylePlain target:self action:@selector(confirmButtonTouchUpInside:)];
    [self.confirmButton setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17.0f weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = self.confirmButton;
    
    switch (self.changeType) {
        case ChangeTypePassword:
        case ChangeTypePasswordFromLogout:
            self.navigationItem.title = AMLocalizedString(@"changePasswordLabel", @"Section title where you can change your MEGA's password");
            
            self.theNewPasswordView.passwordTextField.returnKeyType = UIReturnKeyNext;
            self.theNewPasswordView.passwordTextField.delegate = self;
            self.theNewPasswordView.passwordTextField.tag = NewPasswordTextFieldTag;
            
            self.confirmPasswordView.passwordTextField.delegate = self;
            self.confirmPasswordView.passwordTextField.tag = ConfirmPasswordTextFieldTag;
            if (@available(iOS 12.0, *)) {
                self.theNewPasswordView.passwordTextField.textContentType = UITextContentTypePassword;
                self.confirmPasswordView.passwordTextField.textContentType = UITextContentTypeNewPassword;
            }
            
            
            [self.theNewPasswordView.passwordTextField becomeFirstResponder];
            
            break;
            
        case ChangeTypeEmail: {
            self.navigationItem.title = AMLocalizedString(@"Change Email", @"The title of the alert dialog to change the email associated to an account.");
            self.theNewPasswordView.hidden = self.confirmPasswordView.hidden = YES;
            self.currentEmailInputView.hidden = self.theNewEmailInputView.hidden = self.confirmEmailInputView.hidden = NO;
            
            self.currentEmailInputView.inputTextField.text = [MEGASdkManager sharedMEGASdk].myEmail;
            self.currentEmailInputView.inputTextField.userInteractionEnabled = NO;
            
            self.theNewEmailInputView.inputTextField.returnKeyType = UIReturnKeyNext;
            self.theNewEmailInputView.inputTextField.delegate = self;
            self.theNewEmailInputView.inputTextField.tag = NewEmailTextFieldTag;
            self.theNewEmailInputView.inputTextField.keyboardType = UIKeyboardTypeEmailAddress;

            self.confirmEmailInputView.inputTextField.delegate = self;
            self.confirmEmailInputView.inputTextField.tag = ConfirmEmailTextFieldTag;
            self.confirmEmailInputView.inputTextField.keyboardType = UIKeyboardTypeEmailAddress;
            if (@available(iOS 11.0, *)) {
                self.theNewEmailInputView.inputTextField.textContentType = UITextContentTypeUsername;
                self.confirmEmailInputView.inputTextField.textContentType = UITextContentTypeUsername;
            }
            
            [self.theNewEmailInputView.inputTextField becomeFirstResponder];
            
            break;
        }
            
        case ChangeTypeResetPassword:
        case ChangeTypeParkAccount:
            self.navigationItem.title = (self.changeType == ChangeTypeResetPassword) ? AMLocalizedString(@"passwordReset", @"Headline of the password reset recovery procedure") : AMLocalizedString(@"parkAccount", @"Headline for parking an account (basically restarting from scratch)");
            self.currentEmailInputView.hidden = NO;
            
            self.currentEmailInputView.inputTextField.text = self.email;
            self.currentEmailInputView.inputTextField.userInteractionEnabled = NO;
            
            self.theNewPasswordView.passwordTextField.returnKeyType = UIReturnKeyNext;
            self.theNewPasswordView.passwordTextField.delegate = self;
            self.theNewPasswordView.passwordTextField.tag = NewPasswordTextFieldTag;
            
            self.confirmPasswordView.passwordTextField.delegate = self;
            self.confirmPasswordView.passwordTextField.tag = ConfirmPasswordTextFieldTag;
            if (@available(iOS 12.0, *)) {
                self.theNewPasswordView.passwordTextField.textContentType = UITextContentTypePassword;
                self.confirmPasswordView.passwordTextField.textContentType = UITextContentTypeNewPassword;
            }

            [self.theNewPasswordView.passwordTextField becomeFirstResponder];
            
            break;
    }
    
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    self.tapGesture.cancelsTouchesInView = NO;
    self.tapGesture.delegate = self;
    [self.view addGestureRecognizer:self.tapGesture];
    
    [self registerForKeyboardNotifications];
    
    [self updateAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emailHasChanged) name:@"emailHasChanged" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateAppearance];
        }
    }
}

#pragma mark - Private

- (void)updateAppearance {
    self.view.backgroundColor = [UIColor mnz_settingsBackgroundForTraitCollection:self.traitCollection];
    
    switch (self.changeType) {
        case ChangeTypePassword:
        case ChangeTypePasswordFromLogout:
            [self.theNewPasswordView updateAppearance];
            [self.confirmPasswordView updateAppearance];
            break;
            
        case ChangeTypeEmail:
            [self.currentEmailInputView updateAppearance];
            [self.theNewEmailInputView updateAppearance];
            [self.confirmEmailInputView updateAppearance];
            break;
            
        case ChangeTypeResetPassword:
        case ChangeTypeParkAccount:
            [self.currentEmailInputView updateAppearance];
            [self.theNewPasswordView updateAppearance];
            [self.confirmPasswordView updateAppearance];
            break;
    }
}

- (BOOL)validateForm {
    BOOL valid = YES;
    switch (self.changeType) {
        case ChangeTypePassword:
        case ChangeTypeResetPassword:
        case ChangeTypeParkAccount:
        case ChangeTypePasswordFromLogout:
            if (![self validateNewPassword]) {
                [self.theNewPasswordView.passwordTextField becomeFirstResponder];
                
                valid = NO;
            }
            
            if (![self validateConfirmPassword]) {
                if (valid) {
                    [self.confirmPasswordView.passwordTextField becomeFirstResponder];
                }
                
                valid = NO;
            }
            
            break;
            
        case ChangeTypeEmail:
            if (![self validateEmail]) {
                [self.theNewEmailInputView.inputTextField becomeFirstResponder];
                
                valid = NO;
            }
            
            if (![self validateConfirmEmail]) {
                if (valid) {
                    [self.confirmEmailInputView.inputTextField becomeFirstResponder];
                }
                
                valid = NO;
            }
            
            break;
    }
    
    return valid;
}

- (BOOL)validateNewPassword {
    if (self.theNewPasswordView.passwordTextField.text.mnz_isEmpty) {
        [self.theNewPasswordView setErrorState:YES withText:AMLocalizedString(@"passwordInvalidFormat", @"Message shown when the user enters a wrong password")];
        return NO;
    } else if ([[MEGASdkManager sharedMEGASdk] passwordStrength:self.theNewPasswordView.passwordTextField.text] == PasswordStrengthVeryWeak) {
        [self.theNewPasswordView setErrorState:YES withText:AMLocalizedString(@"pleaseStrengthenYourPassword", nil)];
        return NO;
    } else {
        [self.theNewPasswordView setErrorState:NO withText:AMLocalizedString(@"passwordPlaceholder", @"Hint text to suggest that the user has to write his password")];
        return YES;
    }
}

- (BOOL)validateConfirmPassword {
    if ([self.confirmPasswordView.passwordTextField.text isEqualToString:self.theNewPasswordView.passwordTextField.text]) {
        [self.confirmPasswordView setErrorState:NO withText:AMLocalizedString(@"confirmPassword", @"Hint text where the user have to re-write the new password to confirm it")];
        return YES;
    } else {
        [self.confirmPasswordView setErrorState:YES withText:AMLocalizedString(@"passwordsDoNotMatch", @"Error text shown when you have not written the same password")];
        return NO;
    }
}

- (BOOL)validateEmail {
    self.theNewEmailInputView.inputTextField.text = self.theNewEmailInputView.inputTextField.text.mnz_removeWhitespacesAndNewlinesFromBothEnds;
    if (!self.theNewEmailInputView.inputTextField.text.mnz_isValidEmail) {
        [self.theNewEmailInputView setErrorState:YES withText:AMLocalizedString(@"emailInvalidFormat", @"Message shown when the user writes an invalid format in the email field")];
        return NO;
    } else if ([self.theNewEmailInputView.inputTextField.text isEqualToString:self.currentEmailInputView.inputTextField.text]) {
        [self.theNewEmailInputView setErrorState:YES withText:AMLocalizedString(@"oldAndNewEmailMatch", @"Error message shown when the users tryes to change his/her email and writes the current one as the new one.")];
        return NO;
    } else {
        [self.theNewEmailInputView setErrorState:NO withText:AMLocalizedString(@"newEmail", @"Placeholder text to explain that the new email should be written on this text field.")];
        return YES;
    }
}

- (BOOL)validateConfirmEmail {
    self.confirmEmailInputView.inputTextField.text = self.confirmEmailInputView.inputTextField.text.mnz_removeWhitespacesAndNewlinesFromBothEnds;
    if ([self.confirmEmailInputView.inputTextField.text isEqualToString:self.theNewEmailInputView.inputTextField.text]) {
        [self.confirmEmailInputView setErrorState:NO withText:AMLocalizedString(@"confirmNewEmail", @"Placeholder text to explain that the new email should be re-written on this text field.")];
        return YES;
    } else {
        [self.confirmEmailInputView setErrorState:YES withText:AMLocalizedString(@"emailsDoNotMatch", @"Error message shown when you have not written the same email")];
        return NO;
    }
}

- (void)emailHasChanged {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"emailHasChanged" object:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)processStarted {
    [self.currentEmailInputView.inputTextField resignFirstResponder];
    [self.theNewEmailInputView.inputTextField resignFirstResponder];
    [self.confirmEmailInputView.inputTextField resignFirstResponder];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"processStarted" object:nil];
    
    AwaitingEmailConfirmationView *awaitingEmailConfirmationView = [[[NSBundle mainBundle] loadNibNamed:@"AwaitingEmailConfirmationView" owner:self options: nil] firstObject];
    awaitingEmailConfirmationView.titleLabel.text = AMLocalizedString(@"awaitingEmailConfirmation", @"Title shown just after doing some action that requires confirming the action by an email");
    awaitingEmailConfirmationView.descriptionLabel.text = AMLocalizedString(@"emailIsChanging_description", @"Text shown just after tap to change an email account to remenber the user what to do to complete the change email proccess");
    awaitingEmailConfirmationView.frame = self.view.bounds;
    self.view = awaitingEmailConfirmationView;
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    
}

- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary *info = aNotification.userInfo;
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    CGRect viewFrame = self.view.frame;
    viewFrame.size.height -= keyboardSize.height;
    CGRect activeTextFieldFrame = self.activeInputView ? self.activeInputView.frame : self.activePasswordView.frame;
    if (!CGRectContainsPoint(viewFrame, activeTextFieldFrame.origin)) {
        [self.scrollView scrollRectToVisible:activeTextFieldFrame animated:YES];
    }
}

- (void)keyboardWillBeHidden:(NSNotification *)aNotification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)alertTextFieldDidChange:(UITextField *)textField {
    UIAlertController *alertController = (UIAlertController *)UIApplication.mnz_visibleViewController;
    if (alertController) {
        UIAlertAction *rightButtonAction = alertController.actions.lastObject;
        rightButtonAction.enabled = !textField.text.mnz_isEmpty;
    }
}

#pragma mark - IBActions

- (IBAction)cancelAction:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)confirmButtonTouchUpInside:(UIButton *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        if ([self validateForm]) {
            switch (self.changeType) {
                case ChangeTypePassword:
                case ChangeTypePasswordFromLogout:
                    if (self.isTwoFactorAuthenticationEnabled) {
                        TwoFactorAuthenticationViewController *twoFactorAuthenticationVC = [[UIStoryboard storyboardWithName:@"TwoFactorAuthentication" bundle:nil] instantiateViewControllerWithIdentifier:@"TwoFactorAuthenticationViewControllerID"];
                        twoFactorAuthenticationVC.twoFAMode = self.changeType == ChangeTypePassword ? TwoFactorAuthenticationChangePassword : TwoFactorAuthenticationChangePasswordFromLogout;
                        twoFactorAuthenticationVC.newerPassword = self.theNewPasswordView.passwordTextField.text;
                        
                        [self.navigationController pushViewController:twoFactorAuthenticationVC animated:YES];
                    } else {
                        [[MEGASdkManager sharedMEGASdk] changePassword:nil newPassword:self.theNewPasswordView.passwordTextField.text delegate:self];
                    }
                    
                    break;
                    
                case ChangeTypeEmail:
                    if (self.isTwoFactorAuthenticationEnabled) {
                        TwoFactorAuthenticationViewController *twoFactorAuthenticationVC = [[UIStoryboard storyboardWithName:@"TwoFactorAuthentication" bundle:nil] instantiateViewControllerWithIdentifier:@"TwoFactorAuthenticationViewControllerID"];
                        twoFactorAuthenticationVC.twoFAMode = TwoFactorAuthenticationChangeEmail;
                        twoFactorAuthenticationVC.email = self.theNewEmailInputView.inputTextField.text;
                        
                        [self.navigationController pushViewController:twoFactorAuthenticationVC animated:YES];
                        
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processStarted) name:@"processStarted" object:nil];
                    } else {
                        [[MEGASdkManager sharedMEGASdk] changeEmail:self.theNewEmailInputView.inputTextField.text delegate:self];
                    }
                    
                    break;
                    
                case ChangeTypeResetPassword:
                    [[MEGASdkManager sharedMEGASdk] confirmResetPasswordWithLink:self.link newPassword:self.theNewPasswordView.passwordTextField.text masterKey:self.masterKey delegate:self];
                    
                    break;
                    
                case ChangeTypeParkAccount: {
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"startNewAccount", @"Headline of the password reset recovery procedure")  message:AMLocalizedString(@"startingFreshAccount", @"Label text of a checkbox to ensure that the user is aware that the data of his current account will be lost when proceeding unless they remember their password or have their master encryption key (now renamed 'Recovery Key')") preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[MEGASdkManager sharedMEGASdk] confirmResetPasswordWithLink:self.link newPassword:self.theNewPasswordView.passwordTextField.text masterKey:nil delegate:self];
                    }]];
                    [self presentViewController:alertController animated:YES completion:nil];
                    
                    break;
                }
            }

        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    switch (textField.tag) {
        case NewEmailTextFieldTag:
            self.activeInputView = self.theNewEmailInputView;
            break;
            
        case ConfirmEmailTextFieldTag:
            self.activeInputView = self.confirmEmailInputView;
            break;
            
        case CurrentPasswordTextFieldTag:
            self.activePasswordView = self.currentPasswordView;
            self.currentPasswordView.toggleSecureButton.hidden = NO;
            break;
            
        case NewPasswordTextFieldTag:
            self.activePasswordView = self.theNewPasswordView;
            self.theNewPasswordView.toggleSecureButton.hidden = NO;
            break;
            
        case ConfirmPasswordTextFieldTag:
            self.activePasswordView = self.confirmPasswordView;
            self.confirmPasswordView.toggleSecureButton.hidden = NO;
            break;
            
        default:
            break;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.activeInputView = nil;
    self.activePasswordView = nil;
    
    switch (textField.tag) {
        case NewEmailTextFieldTag:
            [self validateEmail];
            break;
            
        case ConfirmEmailTextFieldTag:
            [self validateConfirmEmail];
            break;
            
        case NewPasswordTextFieldTag:
            self.theNewPasswordView.passwordTextField.secureTextEntry = YES;
            [self.theNewPasswordView configureSecureTextEntry];
            [self validateNewPassword];
            break;
            
        case ConfirmPasswordTextFieldTag:
            self.confirmPasswordView.passwordTextField.secureTextEntry = YES;
            [self.confirmPasswordView configureSecureTextEntry];
            [self validateConfirmPassword];
            break;
            
        default:
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    switch (textField.tag) {
        case 1:
            [self.theNewEmailInputView setErrorState:NO withText:AMLocalizedString(@"newEmail", @"Placeholder text to explain that the new email should be written on this text field.")];
            
            break;
            
        case 2:
            [self.confirmEmailInputView setErrorState:NO withText:AMLocalizedString(@"confirmNewEmail", @"Placeholder text to explain that the new email should be re-written on this text field.")];
            
            break;
            
        case 4:
            [self.theNewPasswordView setErrorState:NO withText:AMLocalizedString(@"passwordPlaceholder", @"Hint text to suggest that the user has to write his password")];
            
            break;
            
        case 5:
            [self.confirmPasswordView setErrorState:NO withText:AMLocalizedString(@"confirmPassword", @"Hint text where the user have to re-write the new password to confirm it")];
            
            break;
            
        default:
            break;
    }
    
    if (self.changeType == ChangeTypePassword || self.changeType == ChangeTypeResetPassword || self.changeType == ChangeTypeParkAccount) {
        if (textField.tag == NewPasswordTextFieldTag) {
            if (text.length == 0) {
                self.passwordStrengthIndicatorView.customView.hidden = YES;
                self.passwordStrengthIndicatorViewHeightLayoutConstraint.constant = 0;
            } else {
                self.passwordStrengthIndicatorViewHeightLayoutConstraint.constant = 112.0f;
                self.passwordStrengthIndicatorView.customView.hidden = NO;
                [self.passwordStrengthIndicatorView updateViewWithPasswordStrength:[[MEGASdkManager sharedMEGASdk] passwordStrength:text]];
            }
        }
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    switch (textField.tag) {
        case CurrentEmailTextFieldTag:
            [self.theNewEmailInputView.inputTextField becomeFirstResponder];
            break;
            
        case NewEmailTextFieldTag:
            [self.confirmEmailInputView.inputTextField becomeFirstResponder];
            break;
            
        case ConfirmEmailTextFieldTag:
            [self.confirmEmailInputView.inputTextField resignFirstResponder];
            break;
            
        case CurrentPasswordTextFieldTag:
            [self.theNewPasswordView.passwordTextField becomeFirstResponder];
            break;
            
        case NewPasswordTextFieldTag:
            [self.confirmPasswordView.passwordTextField becomeFirstResponder];
            break;
            
        case ConfirmPasswordTextFieldTag:
            [self.confirmPasswordView.passwordTextField resignFirstResponder];
            break;
            
        default:
            break;
    }
    
    return YES;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ((touch.view == self.currentPasswordView.toggleSecureButton || touch.view == self.theNewPasswordView.toggleSecureButton || touch.view == self.confirmPasswordView.toggleSecureButton) && (gestureRecognizer == self.tapGesture)) {
        return NO;
    }
    return YES;
}

#pragma mark - MEGAGlobalDelegate

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    NSInteger count = userList.size.integerValue;
    for (NSInteger i = 0 ; i < count; i++) {
        MEGAUser *user = [userList userAtIndex:i];
        if (user.handle == [MEGASdkManager sharedMEGASdk].myUser.handle && user.changes == MEGAUserChangeTypeEmail) {
            NSString *emailChangedString = [AMLocalizedString(@"congratulationsNewEmailAddress", @"The [X] will be replaced with the e-mail address.") stringByReplacingOccurrencesOfString:@"[X]" withString:user.email];
            [SVProgressHUD showSuccessWithStatus:emailChangedString];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if (error.type) {
        
        switch (error.type) {
            case MEGAErrorTypeApiEArgs: {
                if (request.type == MEGARequestTypeChangePassword) {
                    [self.theNewPasswordView setErrorState:YES withText:AMLocalizedString(@"passwordInvalidFormat", @"Message shown when the user enters a wrong password")];
                    [self.theNewPasswordView.passwordTextField becomeFirstResponder];
                }
                break;
            }
                
            case MEGAErrorTypeApiEExist: {
                if (request.type == MEGARequestTypeGetChangeEmailLink) {
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"emailAddressChangeAlreadyRequested", @"Error message shown when you try to change your account email to one that you already requested.")  message:nil preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alertController animated:YES completion:nil];
                }
                break;
            }
                
            case MEGAErrorTypeApiEKey: {
                if (request.type == MEGARequestTypeConfirmRecoveryLink) {
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"invalidRecoveryKey", @"An alert title where the user provided the incorrect Recovery Key.")  message:nil preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"passwordReset", @"Headline of the password reset recovery procedure")  message:AMLocalizedString(@"pleaseEnterYourRecoveryKey", @"A message shown to explain that the user has to input (type or paste) their recovery key to continue with the reset password process.") preferredStyle:UIAlertControllerStyleAlert];
                        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                            textField.placeholder = AMLocalizedString(@"recoveryKey", @"Label for any 'Recovery Key' button, link, text, title, etc. Preserve uppercase - (String as short as possible). The Recovery Key is the new name for the account 'Master Key', and can unlock (recover) the account if the user forgets their password.");
                            [textField becomeFirstResponder];
                            [textField addTarget:self action:@selector(alertTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                            textField.shouldReturnCompletion = ^BOOL(UITextField *textField) {
                                return !textField.text.mnz_isEmpty;
                            };
                        }];
                        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                                UITextField *textField = alertController.textFields.firstObject;
                                [textField resignFirstResponder];
                                [self dismissViewControllerAnimated:YES completion:nil];
                        }]];
                        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            self.masterKey = alertController.textFields.firstObject.text;
                            [self.theNewEmailInputView.inputTextField becomeFirstResponder];
                        }]];
                        [self presentViewController:alertController animated:YES completion:nil];
                    }]];
                    [self presentViewController:alertController animated:YES completion:nil];
                    
                    self.theNewEmailInputView.inputTextField.text = self.confirmEmailInputView.inputTextField.text = @"";
                }
                break;
            }
                
            case MEGAErrorTypeApiEAccess:
                if (request.type == MEGARequestTypeGetChangeEmailLink) {
                    [self.theNewEmailInputView setErrorState:YES withText:AMLocalizedString(@"emailAlreadyInUse", @"Error shown when the user tries to change his mail to one that is already used")];
                    [self.theNewEmailInputView.inputTextField becomeFirstResponder];
                }
                break;
                
            default:
                break;
        }
        return;
    }
    
    switch (request.type) {
        case MEGARequestTypeChangePassword: {
            [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"passwordChanged", @"The label showed when your password has been changed")];
            
            if (self.changeType == ChangeTypePassword) {
                [self.navigationController popViewControllerAnimated:YES];
            } else if (self.changeType == ChangeTypePasswordFromLogout) {
                [MEGASdkManager.sharedMEGASdk logout];
            }
            
            break;
        }
            
        case MEGARequestTypeGetChangeEmailLink: {
            [self processStarted];
            break;
        }
            
        case MEGARequestTypeConfirmRecoveryLink: {
            if (self.changeType == ChangeTypePassword) {
                [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"passwordChanged", @"The label showed when your password has been changed")];
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self.view endEditing:YES];
                
                NSString *title;
                void (^completion)(void);
                if (self.changeType == ChangeTypeResetPassword) {
                    if ([[MEGASdkManager sharedMEGASdk] isLoggedIn]) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"passwordReset" object:nil];
                        title = AMLocalizedString(@"passwordChanged", @"The label showed when your password has been changed");
                        
                        completion = ^{
                            if (self.link) {
                                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                            } else {
                                [self.navigationController popToViewController:self.navigationController.viewControllers[2] animated:YES];
                            }
                        };
                    } else {
                        title = AMLocalizedString(@"yourPasswordHasBeenReset", nil);
                        
                        completion = ^{
                            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                        };
                    }
                } else if (self.changeType == ChangeTypeParkAccount) {
                    title = AMLocalizedString(@"yourAccounHasBeenParked", nil);
                    
                    completion = ^{
                        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                    };
                }
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    completion();
                }]];
                
                [UIApplication.mnz_presentingViewController presentViewController:alertController animated:YES completion:nil];
            }
            
            break;
        }
            
        default:
            break;
    }
}

@end
