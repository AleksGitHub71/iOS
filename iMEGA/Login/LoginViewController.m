#import "LoginViewController.h"

#import "SAMKeychain.h"
#import "SVProgressHUD.h"

#import "Helper.h"
#import "MEGANavigationController.h"
#import "MEGALogger.h"
#import "MEGAReachabilityManager.h"
#import "MEGALoginRequestDelegate.h"
#import "NSString+MNZCategory.h"

#import "CreateAccountViewController.h"
#import "PasswordView.h"

@interface LoginViewController () <UITextFieldDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *logoImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoTopLayoutConstraint;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet PasswordView *passwordView;

@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@property (weak, nonatomic) IBOutlet UIButton *createAccountButton;
@property (weak, nonatomic) IBOutlet UIButton *forgotPasswordButton;

@property (nonatomic) NSString *email;
@property (nonatomic) NSString *password;

@end

@implementation LoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (([[UIDevice currentDevice] iPhone4X])) {
        self.logoTopLayoutConstraint.constant = 24.f;
    }
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(logoTappedFiveTimes:)];
    tapGestureRecognizer.numberOfTapsRequired = 5;
    self.logoImageView.gestureRecognizers = @[tapGestureRecognizer];
    
    [self.emailTextField setPlaceholder:AMLocalizedString(@"emailPlaceholder", @"Email")];
    self.passwordView.passwordTextField.delegate = self;
    self.passwordView.passwordTextField.tag = 1;
    self.passwordView.passwordTextField.textColor = UIColor.mnz_black333333;
    self.passwordView.passwordTextField.font = [UIFont mnz_SFUIRegularWithSize:17];

    [self.loginButton setTitle:AMLocalizedString(@"login", @"Login") forState:UIControlStateNormal];
    self.loginButton.backgroundColor = UIColor.mnz_grayEEEEEE;
    
    [self.createAccountButton setTitle:AMLocalizedString(@"createAccount", nil) forState:UIControlStateNormal];
    NSString *forgotPasswordString = AMLocalizedString(@"forgotPassword", @"An option to reset the password.");
    forgotPasswordString = [forgotPasswordString stringByReplacingOccurrencesOfString:@"?" withString:@""];
    forgotPasswordString = [forgotPasswordString stringByReplacingOccurrencesOfString:@"¿" withString:@""];
    [self.forgotPasswordButton setTitle:forgotPasswordString forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationItem setTitle:AMLocalizedString(@"login", nil)];
    
    [[MEGALogger sharedLogger] enableChatlogs];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] iPhoneDevice]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - IBActions

- (IBAction)tapLogin:(id)sender {
    if ([MEGASdkManager sharedMEGAChatSdk] == nil) {
        [MEGASdkManager createSharedMEGAChatSdk];
    }
    
    if ([[MEGASdkManager sharedMEGAChatSdk] initState] != MEGAChatInitWaitingNewSession) {
        MEGAChatInit chatInit = [[MEGASdkManager sharedMEGAChatSdk] initKarereWithSid:nil];
        if (chatInit != MEGAChatInitWaitingNewSession) {
            MEGALogError(@"Init Karere without sesion must return waiting for a new sesion");
            [[MEGASdkManager sharedMEGAChatSdk] logout];
        }
    }
    
    [self.emailTextField resignFirstResponder];
    [self.passwordView.passwordTextField resignFirstResponder];
    
    if ([self validateForm]) {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            self.email = self.emailTextField.text;
            self.password = self.passwordView.passwordTextField.text;
            
            NSOperationQueue *operationQueue = [NSOperationQueue new];
            
            NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(generateKeys)
                                                                                      object:nil];
            [operationQueue addOperation:operation];
        }
    }
}

- (IBAction)forgotPasswordTouchUpInside:(UIButton *)sender {
    [Helper presentSafariViewControllerWithURL:[NSURL URLWithString:@"https://mega.nz/recovery"]];
}

#pragma mark - Private

- (void)logoTappedFiveTimes:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [Helper enableOrDisableLog];
    }
}

- (void)generateKeys {
    NSString *privateKey = [[MEGASdkManager sharedMEGASdk] base64pwkeyForPassword:self.password];
    NSString *publicKey  = [[MEGASdkManager sharedMEGASdk] hashForBase64pwkey:privateKey email:self.email];
    
    MEGALoginRequestDelegate *loginRequestDelegate = [[MEGALoginRequestDelegate alloc] init];
    [[MEGASdkManager sharedMEGASdk] fastLoginWithEmail:self.email stringHash:publicKey base64pwKey:privateKey delegate:loginRequestDelegate];
}

- (BOOL)validateForm {
    if (!self.emailTextField.text.mnz_isValidEmail) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"emailInvalidFormat", @"Enter a valid email")];
        [self.emailTextField becomeFirstResponder];
        return NO;
    } else if (![self validatePassword:self.passwordView.passwordTextField.text]) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"passwordInvalidFormat", @"Enter a valid password")];
        [self.passwordView.passwordTextField becomeFirstResponder];
        return NO;
    }
    return YES;
}

- (BOOL)validatePassword:(NSString *)password {
    if (password.length == 0) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)isEmptyAnyTextFieldForTag:(NSInteger )tag {
    BOOL isAnyTextFieldEmpty = NO;
    switch (tag) {
        case 0: {
            if ([self.passwordView.passwordTextField.text isEqualToString:@""]) {
                isAnyTextFieldEmpty = YES;
            }
            break;
        }
            
        case 1: {
            if ([self.emailTextField.text isEqualToString:@""]) {
                isAnyTextFieldEmpty = YES;
            }
            break;
        }
    }
    
    return isAnyTextFieldEmpty;
}

- (NSString *)timeFormatted:(NSUInteger)totalSeconds {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    NSString *currentLanguageID = [[LocalizationSystem sharedLocalSystem] getLanguage];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:currentLanguageID];
    
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:totalSeconds];
    
    return [dateFormatter stringFromDate:date];
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - UIViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateAccountStoryboardSegueID"] && [sender isKindOfClass:[NSString class]]) {
        CreateAccountViewController *createAccountVC = (CreateAccountViewController *)segue.destinationViewController;
        [createAccountVC setEmailString:sender];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL shoulBeLoginButtonGray = NO;
    if ([text isEqualToString:@""] || (!self.emailTextField.text.mnz_isValidEmail)) {
        shoulBeLoginButtonGray = YES;
    } else {
        shoulBeLoginButtonGray = [self isEmptyAnyTextFieldForTag:textField.tag];
    }
    
    self.loginButton.backgroundColor = shoulBeLoginButtonGray ? UIColor.mnz_grayEEEEEE : UIColor.mnz_redFF4D52;
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.loginButton.backgroundColor = UIColor.mnz_grayEEEEEE;
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    switch (textField.tag) {
        case 0:
            [self.passwordView.passwordTextField becomeFirstResponder];
            break;
            
        case 1:
            [self.passwordView.passwordTextField resignFirstResponder];
            [self tapLogin:self.loginButton];
            break;
            
        default:
            break;
    }
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField.tag == 1) {
        self.passwordView.rightImageView.hidden = NO;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag == 1) {
        self.passwordView.rightImageView.hidden = YES;
    }
}

@end
