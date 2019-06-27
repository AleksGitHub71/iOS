
#import "PasswordView.h"

@implementation PasswordView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    [self customInit];
    [self.customView prepareForInterfaceBuilder];
    // Trigger the setters:
    self.leftImage = self.leftImage;
    self.topLabelTextKey = self.topLabelTextKey;
}

#pragma mark - Private

- (void)customInit {
    self.customView = [[NSBundle bundleForClass:self.class] loadNibNamed:@"PasswordView" owner:self options:nil].firstObject;
    [self addSubview:self.customView];
    self.customView.frame = self.bounds;
    self.customView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.passwordTextField.delegate = self;
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self addGestureRecognizer:singleTap];
}

- (void)configureToggleSecureButton {
    if (self.passwordTextField.secureTextEntry) {
        [self.toggleSecureButton setImage:[UIImage imageNamed:@"showHidePassword"] forState:UIControlStateNormal];
    } else {
        [self.toggleSecureButton setImage:[UIImage imageNamed:@"showHidePassword_active"] forState:UIControlStateNormal];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    [self.passwordTextField becomeFirstResponder];
}

#pragma mark - Public

- (void)configureSecureTextEntry {
    [self configureToggleSecureButton];
    self.toggleSecureButton.hidden = YES;
}

- (void)setErrorState:(BOOL)error {
    NSString *text = error ? AMLocalizedString(@"passwordWrong", @"Wrong password") : AMLocalizedString(@"passwordPlaceholder", @"Hint text to suggest that the user has to write his password");
    [self setErrorState:error withText:text];
}

- (void)setErrorState:(BOOL)error withText:(NSString *)text {
    self.topLabel.text = text;
    if (error) {
        self.topLabel.textColor = UIColor.mnz_redError;
        self.passwordTextField.textColor = UIColor.mnz_redError;
    } else {
        self.topLabel.textColor = UIColor.mnz_gray999999;
        self.passwordTextField.textColor = UIColor.blackColor;
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.toggleSecureButton.hidden = NO;
    [self.delegate passwordViewBeginEditing];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.passwordTextField.secureTextEntry = YES;
    self.toggleSecureButton.hidden = YES;
}

#pragma mark - IBActions

- (IBAction)tapToggleSecureTextEntry:(id)sender {
    self.passwordTextField.secureTextEntry = !self.passwordTextField.secureTextEntry;
    [self configureToggleSecureButton];
    //This code fix the position of the text field cursor not locating properly when toggle secure text entry
    NSString *tmpString = self.passwordTextField.text;
    self.passwordTextField.text = @" ";
    self.passwordTextField.text = tmpString;
}

#pragma mark - IBInspectables

- (void)setLeftImage:(UIImage *)leftImage {
    _leftImage = leftImage;
    self.leftImageView.image = self.leftImage;
}

- (void)setTopLabelTextKey:(NSString *)topLabelTextKey {
    _topLabelTextKey = topLabelTextKey;
#ifdef TARGET_INTERFACE_BUILDER
    self.topLabel.text = [[NSBundle bundleForClass:self.class] localizedStringForKey:self.topLabelTextKey value:nil table:nil];
#else
    self.topLabel.text = AMLocalizedString(self.topLabelTextKey, nil);
#endif
}

@end
