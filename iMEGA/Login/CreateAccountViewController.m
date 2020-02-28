
#import "CreateAccountViewController.h"

#import "SVProgressHUD.h"

#import "InputView.h"
#import "MEGACreateAccountRequestDelegate.h"
#import "MEGAReachabilityManager.h"
#import "MEGASdkManager.h"
#import "MEGA-Swift.h"
#import "NSURL+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"

#import "CheckEmailAndFollowTheLinkViewController.h"
#import "PasswordStrengthIndicatorView.h"
#import "PasswordView.h"

typedef NS_ENUM(NSInteger, TextFieldTag) {
    FirstNameTextFieldTag = 0,
    LastNameTextFieldTag,
    EmailTextFieldTag,
    PasswordTextFieldTag,
    RetypeTextFieldTag
};

@interface CreateAccountViewController () <UINavigationControllerDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelBarButtonItem;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet InputView *firstNameInputView;
@property (weak, nonatomic) IBOutlet InputView *lastNameInputView;
@property (weak, nonatomic) IBOutlet InputView *emailInputView;

@property (weak, nonatomic) IBOutlet UIStackView *passwordStackView;
@property (weak, nonatomic) IBOutlet PasswordView *passwordView;
@property (weak, nonatomic) IBOutlet UIView *passwordStrengthIndicatorContainerView;
@property (weak, nonatomic) IBOutlet PasswordStrengthIndicatorView *passwordStrengthIndicatorView;
@property (weak, nonatomic) IBOutlet PasswordView *retypePasswordView;

@property (weak, nonatomic) IBOutlet UIButton *termsCheckboxButton;
@property (weak, nonatomic) IBOutlet UIButton *termsOfServiceButton;

@property (weak, nonatomic) IBOutlet UIButton *termsForLosingPasswordCheckboxButton;
@property (weak, nonatomic) IBOutlet UILabel *termsForLosingPasswordLabel;

@property (weak, nonatomic) IBOutlet UIButton *createAccountButton;

@property (weak, nonatomic) InputView *activeInputView;
@property (weak, nonatomic) PasswordView *activePasswordView;

@property (strong, nonatomic) UITapGestureRecognizer *tapGesture;

@end

@implementation CreateAccountViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self updateUI];
    
    self.passwordStrengthIndicatorContainerView.hidden = YES;
    
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    self.tapGesture.cancelsTouchesInView = NO;
    self.tapGesture.delegate = self;
    [self.scrollView addGestureRecognizer:self.tapGesture];
    
    self.cancelBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
    
    self.firstNameInputView.inputTextField.returnKeyType = UIReturnKeyNext;
    self.firstNameInputView.inputTextField.delegate = self;
    self.firstNameInputView.inputTextField.tag = FirstNameTextFieldTag;
    
    self.lastNameInputView.inputTextField.returnKeyType = UIReturnKeyNext;
    self.lastNameInputView.inputTextField.delegate = self;
    self.lastNameInputView.inputTextField.tag = LastNameTextFieldTag;
    self.firstNameInputView.inputTextField.textContentType = UITextContentTypeGivenName;
    self.lastNameInputView.inputTextField.textContentType = UITextContentTypeFamilyName;

    self.emailInputView.inputTextField.returnKeyType = UIReturnKeyNext;
    self.emailInputView.inputTextField.delegate = self;
    self.emailInputView.inputTextField.tag = EmailTextFieldTag;
    self.emailInputView.inputTextField.keyboardType = UIKeyboardTypeEmailAddress;
    if (self.emailString) {
        self.emailInputView.inputTextField.text = self.emailString;
    }
    if (@available(iOS 11.0, *)) {
        self.emailInputView.inputTextField.textContentType = UITextContentTypeUsername;
    }
    
    self.passwordView.passwordTextField.returnKeyType = UIReturnKeyNext;
    self.passwordView.passwordTextField.delegate = self;
    self.passwordView.passwordTextField.tag = PasswordTextFieldTag;
    
    self.retypePasswordView.passwordTextField.delegate = self;
    self.retypePasswordView.passwordTextField.tag = RetypeTextFieldTag;
    if (@available(iOS 12.0, *)) {
        self.passwordView.passwordTextField.textContentType = UITextContentTypePassword;
        self.retypePasswordView.passwordTextField.textContentType = UITextContentTypeNewPassword;
    }
    
    [self.createAccountButton setTitle:AMLocalizedString(@"createAccount", @"Button title which triggers the action to create a MEGA account") forState:UIControlStateNormal];
    
    [self registerForKeyboardNotifications];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController.navigationBar.topItem setTitle:AMLocalizedString(@"createAccount", nil)];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UIDevice.currentDevice.iPhoneDevice) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [AppearanceManager setupAppearance:self.traitCollection];
            [AppearanceManager invalidateViews];
            
            [self updateUI];
        }
    }
}

#pragma mark - Private

- (BOOL)validateForm {
    BOOL valid = YES;
    if (![self validateFirstName]) {
        [self.firstNameInputView.inputTextField becomeFirstResponder];
        
        valid = NO;
    }
    
    if (![self validateLastName]) {
        if (valid) {
            [self.lastNameInputView.inputTextField becomeFirstResponder];
        }
        
        valid = NO;
    }
    
    if (![self validateEmail]) {
        if (valid) {
            [self.emailInputView.inputTextField becomeFirstResponder];
        }
        
        valid = NO;
    }
    
    if (![self validatePassword]) {
        if (valid) {
            [self.passwordView.passwordTextField becomeFirstResponder];
        }
        
        valid = NO;
    }
    
    if (![self validateRetypePassword]) {
        if (valid) {
            [self.retypePasswordView.passwordTextField becomeFirstResponder];
        }

        valid = NO;
    }
    
    if (!self.termsCheckboxButton.isSelected) {
        if (valid) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudWarning"] status:AMLocalizedString(@"termsCheckboxUnselected", @"Error text shown when you don't have selected the checkbox to agree with the Terms of Service")];
        }
        
        valid = NO;
    }
    
    if (!self.termsForLosingPasswordCheckboxButton.isSelected) {
        if (valid) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudWarning"]
                              status:AMLocalizedString(@"termsForLosingPasswordCheckboxUnselected", nil)];
        }
        
        valid = NO;
    }
    
    return valid;
}

- (BOOL)validateFirstName {
    self.firstNameInputView.inputTextField.text = self.firstNameInputView.inputTextField.text.mnz_removeWhitespacesAndNewlinesFromBothEnds;
    if (self.firstNameInputView.inputTextField.text.mnz_isEmpty) {
        [self.firstNameInputView setErrorState:YES withText:AMLocalizedString(@"nameInvalidFormat", @"Error text shown when you have not entered a correct name")];
        return NO;
    } else {
        [self.firstNameInputView setErrorState:NO withText:AMLocalizedString(@"firstName", @"Hint text for the first name (Placeholder)")];
        return YES;
    }
}

- (BOOL)validateLastName {
    self.lastNameInputView.inputTextField.text = self.lastNameInputView.inputTextField.text.mnz_removeWhitespacesAndNewlinesFromBothEnds;
    if (self.lastNameInputView.inputTextField.text.mnz_isEmpty) {
        [self.lastNameInputView setErrorState:YES withText:AMLocalizedString(@"lastName", @"Hint text for the last name (Placeholder)")];
        return NO;
    } else {
        [self.lastNameInputView setErrorState:NO withText:AMLocalizedString(@"lastName", @"Hint text for the last name (Placeholder)")];
        return YES;
    }
}

- (BOOL)validateEmail {
    self.emailInputView.inputTextField.text = self.emailInputView.inputTextField.text.mnz_removeWhitespacesAndNewlinesFromBothEnds;
    if (self.emailInputView.inputTextField.text.mnz_isValidEmail) {
        [self.emailInputView setErrorState:NO withText:AMLocalizedString(@"emailPlaceholder", @"Hint text to suggest that the user has to write his email")];
        return YES;
    } else {
        [self.emailInputView setErrorState:YES withText:AMLocalizedString(@"emailInvalidFormat", @"Message shown when the user writes an invalid format in the email field")];
        return NO;
    }
}

- (BOOL)validatePassword {
    if (self.passwordView.passwordTextField.text.mnz_isEmpty) {
        [self.passwordView setErrorState:YES withText:AMLocalizedString(@"passwordInvalidFormat", @"Message shown when the user enters a wrong password")];
        return NO;
    } else if ([[MEGASdkManager sharedMEGASdk] passwordStrength:self.passwordView.passwordTextField.text] == PasswordStrengthVeryWeak) {
        [self.passwordView setErrorState:YES withText:AMLocalizedString(@"pleaseStrengthenYourPassword", nil)];
        return NO;
    } else {
        [self.passwordView setErrorState:NO withText:AMLocalizedString(@"passwordPlaceholder", @"Hint text to suggest that the user has to write his password")];
        return YES;
    }
}

- (BOOL)validateRetypePassword {
    if ([self.retypePasswordView.passwordTextField.text isEqualToString:self.passwordView.passwordTextField.text]) {
        [self.retypePasswordView setErrorState:NO withText:AMLocalizedString(@"confirmPassword", @"Hint text where the user have to re-write the new password to confirm it")];
        return YES;
    } else {
        [self.retypePasswordView setErrorState:YES withText:AMLocalizedString(@"passwordsDoNotMatch", @"Error text shown when you have not written the same password")];
        return NO;
    }
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
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

- (void)setTermsOfServiceAttributedTitle {
    NSString *agreeWithTheMEGATermsOfService = AMLocalizedString(@"agreeWithTheMEGATermsOfService", @"");
    NSString *termsOfServiceString = [agreeWithTheMEGATermsOfService mnz_stringBetweenString:@"<a href=\"terms\">" andString:@"</a>"];
    if (!termsOfServiceString) {
        termsOfServiceString = [agreeWithTheMEGATermsOfService mnz_stringBetweenString:@"<a href='terms'>" andString:@"</a>"];
    }
    agreeWithTheMEGATermsOfService = [agreeWithTheMEGATermsOfService mnz_removeWebclientFormatters];
    
    UIColor *termsOfServiceColor = [UIColor mnz_turquoiseForTraitCollection:self.traitCollection];
    NSMutableAttributedString *termsOfServiceMutableAttributedString = [NSMutableAttributedString.alloc initWithString:agreeWithTheMEGATermsOfService attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f], NSForegroundColorAttributeName:[UIColor mnz_primaryGrayForTraitCollection:self.traitCollection]}];
    [termsOfServiceMutableAttributedString setAttributes:@{NSForegroundColorAttributeName:termsOfServiceColor} range:[agreeWithTheMEGATermsOfService rangeOfString:@"MEGA"]];
    if (termsOfServiceString) {
        [termsOfServiceMutableAttributedString setAttributes:@{NSForegroundColorAttributeName:termsOfServiceColor} range:[agreeWithTheMEGATermsOfService rangeOfString:termsOfServiceString]];
    }
    
    [self.termsOfServiceButton setAttributedTitle:termsOfServiceMutableAttributedString forState:UIControlStateNormal];
}

- (void)setTermsForLosingPasswordAttributedText {
    NSString *agreementForLosingPasswordText = AMLocalizedString(@"agreeWithLosingPasswordYouLoseData", @"");

    NSString *semiboldPrimaryGrayText = [agreementForLosingPasswordText mnz_stringBetweenString:@"[S]" andString:@"[/S]"];
    NSString *greenText = [agreementForLosingPasswordText mnz_stringBetweenString:@"[/S]" andString:@"</a>"];

    agreementForLosingPasswordText = agreementForLosingPasswordText.mnz_removeWebclientFormatters;
    greenText = greenText.mnz_removeWebclientFormatters;

    NSRange semiboldPrimaryGrayTextRange = [agreementForLosingPasswordText rangeOfString:semiboldPrimaryGrayText];
    NSRange greenTextRange = [agreementForLosingPasswordText rangeOfString:greenText];

    UIColor *primaryGrayColor = [UIColor mnz_primaryGrayForTraitCollection:self.traitCollection];
    NSMutableAttributedString *termsMutableAttributedString = [NSMutableAttributedString.alloc initWithString:agreementForLosingPasswordText attributes:@{NSForegroundColorAttributeName : primaryGrayColor}];

    NSDictionary *semiboldPrimaryGrayTextAttributes = @{NSFontAttributeName : [UIFont systemFontOfSize:12.f weight:UIFontWeightSemibold], NSForegroundColorAttributeName : primaryGrayColor};
    [termsMutableAttributedString setAttributes:semiboldPrimaryGrayTextAttributes range:semiboldPrimaryGrayTextRange];

    NSDictionary *greenTextAttributes = @{NSForegroundColorAttributeName : [UIColor mnz_turquoiseForTraitCollection:self.traitCollection]};
    [termsMutableAttributedString setAttributes:greenTextAttributes range:greenTextRange];

    self.termsForLosingPasswordLabel.textColor = primaryGrayColor;
    self.termsForLosingPasswordLabel.attributedText = termsMutableAttributedString;
}

- (void)updateUI {
    self.view.backgroundColor = [UIColor mnz_accountViewsBackgroundColorForTraitCollection:self.traitCollection];
    
    [self.firstNameInputView updateUI];
    [self.lastNameInputView updateUI];
    [self.emailInputView updateUI];
    [self.passwordView updateUI];
    self.passwordStrengthIndicatorContainerView.backgroundColor = [UIColor mnz_inputsBackgroundColorForTraitCollection:self.traitCollection];
    [self.retypePasswordView updateUI];
    
    [self setTermsOfServiceAttributedTitle];
    [self setTermsForLosingPasswordAttributedText];
    
    self.createAccountButton.backgroundColor = [UIColor mnz_turquoiseForTraitCollection:self.traitCollection];
    [self.createAccountButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.createAccountButton.layer.shadowColor = UIColor.blackColor.CGColor;
}

#pragma mark - IBActions

- (IBAction)cancel:(UIBarButtonItem *)sender {
    [self hideKeyboard];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)termsCheckboxTouchUpInside:(id)sender {
    self.termsCheckboxButton.selected = !self.termsCheckboxButton.selected;
    
    [self hideKeyboard];
}

- (IBAction)termOfServiceTouchUpInside:(UIButton *)sender {
    [[NSURL URLWithString:@"https://mega.nz/terms"] mnz_presentSafariViewController];
}

- (IBAction)termsForLosingPasswordCheckboxButtonPressed:(UIButton *)sender {
    self.termsForLosingPasswordCheckboxButton.selected = !self.termsForLosingPasswordCheckboxButton.selected;
    
    [self hideKeyboard];
}

- (IBAction)termsForLosingPasswordTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer {
    [[NSURL URLWithString:@"https://mega.nz/security"] mnz_presentSafariViewController];
}

- (IBAction)createAccountTouchUpInside:(id)sender {
    if ([self validateForm]) {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            [SVProgressHUD show];
            
            MEGACreateAccountRequestDelegate *createAccountRequestDelegate = [[MEGACreateAccountRequestDelegate alloc] initWithCompletion:^(MEGAError *error) {
                [SVProgressHUD dismiss];
                if (error.type == MEGAErrorTypeApiOk) {
                    CheckEmailAndFollowTheLinkViewController *checkEmailAndFollowTheLinkVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CheckEmailAndFollowTheLinkViewControllerID"];
                    if (@available(iOS 13.0, *)) {
                        checkEmailAndFollowTheLinkVC.modalPresentationStyle = UIModalPresentationFullScreen;
                    }
                    [self dismissViewControllerAnimated:YES completion:^{
                        [UIApplication.mnz_presentingViewController presentViewController:checkEmailAndFollowTheLinkVC animated:YES completion:nil];
                    }];
                } else {
                    [self.emailInputView setErrorState:YES withText:AMLocalizedString(@"emailAlreadyInUse", @"Error shown when the user tries to change his mail to one that is already used")];
                    [self.emailInputView.inputTextField becomeFirstResponder];
                }
            }];
            createAccountRequestDelegate.resumeCreateAccount = NO;
            
            uint64_t lastPublicHandleAccessed = [[NSUserDefaults.standardUserDefaults objectForKey:MEGALastPublicHandleAccessed] unsignedLongLongValue];
            NSInteger lastPublicTypeAccessed = [NSUserDefaults.standardUserDefaults integerForKey:MEGALastPublicTypeAccessed];
            NSTimeInterval lastPublicTimestampAccessed = [NSUserDefaults.standardUserDefaults doubleForKey:MEGALastPublicTimestampAccessed];
            if (lastPublicTimestampAccessed && lastPublicHandleAccessed && lastPublicTypeAccessed) {
                [MEGASdkManager.sharedMEGASdk createAccountWithEmail:self.emailInputView.inputTextField.text password:self.passwordView.passwordTextField.text firstname:self.firstNameInputView.inputTextField.text lastname:self.lastNameInputView.inputTextField.text lastPublicHandle:lastPublicHandleAccessed lastPublicHandleType:lastPublicTypeAccessed lastAccessTimestamp:(uint64_t)lastPublicTimestampAccessed delegate:createAccountRequestDelegate];
            } else {
                [MEGASdkManager.sharedMEGASdk createAccountWithEmail:self.emailInputView.inputTextField.text password:self.passwordView.passwordTextField.text firstname:self.firstNameInputView.inputTextField.text lastname:self.lastNameInputView.inputTextField.text delegate:createAccountRequestDelegate];
            }
        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    switch (textField.tag) {
        case FirstNameTextFieldTag:
            self.activeInputView = self.firstNameInputView;
            break;
            
        case LastNameTextFieldTag:
            self.activeInputView = self.lastNameInputView;
            break;
            
        case EmailTextFieldTag:
            self.activeInputView = self.emailInputView;
            break;
            
        case PasswordTextFieldTag:
            self.activePasswordView = self.passwordView;
            self.passwordView.toggleSecureButton.hidden = NO;
            break;
            
        case RetypeTextFieldTag:
            self.activePasswordView = self.retypePasswordView;
            self.retypePasswordView.toggleSecureButton.hidden = NO;
            break;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.activeInputView = nil;
    self.activePasswordView = nil;
    
    switch (textField.tag) {
        case FirstNameTextFieldTag:
            [self validateFirstName];
            break;
            
        case LastNameTextFieldTag:
            [self validateLastName];
            break;
            
        case EmailTextFieldTag:
            [self validateEmail];
            break;
            
        case PasswordTextFieldTag:
            self.passwordView.passwordTextField.secureTextEntry = YES;
            [self.passwordView configureSecureTextEntry];
            [self validatePassword];
            break;
            
        case RetypeTextFieldTag:
            self.retypePasswordView.passwordTextField.secureTextEntry = YES;
            [self.retypePasswordView configureSecureTextEntry];
            [self validateRetypePassword];
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    switch (textField.tag) {
        case FirstNameTextFieldTag:
            [self.firstNameInputView setErrorState:NO withText:AMLocalizedString(@"firstName", @"Hint text for the first name (Placeholder)")];
            break;
            
        case LastNameTextFieldTag:
            [self.lastNameInputView setErrorState:NO withText:AMLocalizedString(@"lastName", @"Hint text for the last name (Placeholder)")];
            break;
            
        case EmailTextFieldTag:
            [self.emailInputView setErrorState:NO withText:AMLocalizedString(@"emailPlaceholder", @"Hint text to suggest that the user has to write his email")];
            break;
            
        case PasswordTextFieldTag:
            [self.passwordView setErrorState:NO withText:AMLocalizedString(@"passwordPlaceholder", @"Hint text to suggest that the user has to write his password")];
            break;
            
        case RetypeTextFieldTag:
            [self.retypePasswordView setErrorState:NO withText:AMLocalizedString(@"confirmPassword", @"Hint text where the user have to re-write the new password to confirm it")];
            break;
            
        default:
            break;
    }
    
    if (textField.tag == PasswordTextFieldTag) {
        if (text.length == 0) {
            self.passwordStrengthIndicatorView.customView.hidden = YES;
            self.passwordStrengthIndicatorContainerView.hidden = YES;
        } else {
            self.passwordStrengthIndicatorContainerView.hidden = NO;
            self.passwordStrengthIndicatorView.customView.hidden = NO;
            [self.scrollView scrollRectToVisible:self.passwordStrengthIndicatorView.frame animated:YES];
            [self.passwordStrengthIndicatorView updateViewWithPasswordStrength:[[MEGASdkManager sharedMEGASdk] passwordStrength:text]];
        }
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    switch (textField.tag) {
        case 0:
            [self.lastNameInputView.inputTextField becomeFirstResponder];
            break;
            
        case 1:
            [self.emailInputView.inputTextField becomeFirstResponder];
            break;
            
        case 2:
            [self.passwordView.passwordTextField becomeFirstResponder];
            break;
            
        case 3:
            [self.retypePasswordView.passwordTextField becomeFirstResponder];
            break;
            
        case 4:
            [self.retypePasswordView.passwordTextField resignFirstResponder];
            break;
            
        default:
            break;
    }
    
    return YES;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ((touch.view == self.passwordView.toggleSecureButton || touch.view == self.retypePasswordView.toggleSecureButton) && (gestureRecognizer == self.tapGesture)) {
        return NO;
    }
    return YES;
}

@end
