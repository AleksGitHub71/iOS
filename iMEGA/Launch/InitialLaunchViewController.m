
#import "InitialLaunchViewController.h"

#import "OnboardingViewController.h"

@interface InitialLaunchViewController () <MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIButton *setupButton;
@property (weak, nonatomic) IBOutlet UIButton *skipButton;

@property (nonatomic) BOOL logoMoved;

@end

@implementation InitialLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.titleLabel.text = AMLocalizedString(@"Setup MEGA", @"Button which triggers the initial setup");
    self.descriptionLabel.text = AMLocalizedString(@"To fully take advantage of your MEGA account we need to ask you some permissions.", @"Detailed explanation of why the user should give some permissions to MEGA");
    [self.setupButton setTitle:AMLocalizedString(@"Setup MEGA", @"Button which triggers the initial setup") forState:UIControlStateNormal];
    [self.skipButton setTitle:AMLocalizedString(@"skipButton", @"Button title that skips the current action") forState:UIControlStateNormal];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if (!self.logoMoved) {
        return;
    }
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self moveLogo];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self centerLabels];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UIDevice.currentDevice.iPhoneDevice) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private

- (void)performAnimation {
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.circularShapeLayer.hidden = YES;
        [self moveLogo];
    } completion:^(BOOL finished) {
        [self centerLabels];
        self.titleLabel.hidden = self.descriptionLabel.hidden = NO;
        self.setupButton.hidden = self.skipButton.hidden = NO;
        self.activityIndicatorView.hidden = YES;
        self.logoMoved = YES;
    }];
}

- (void)moveLogo {
    CGFloat newY = MIN(self.logoImageView.frame.origin.x, 145.0f);
    self.logoImageView.frame = CGRectMake(self.logoImageView.frame.origin.x, newY, self.logoImageView.frame.size.width, self.logoImageView.frame.size.height);
}

- (void)centerLabels {
    CGFloat bottomSeparation = 28.0f;
    CGFloat verticalIncrement = (self.titleLabel.frame.origin.y - (self.logoImageView.frame.origin.y + self.logoImageView.frame.size.height) - bottomSeparation) / 2;
    
    CGRect titleFrame = self.titleLabel.frame;
    titleFrame.origin.y -= verticalIncrement;
    self.titleLabel.frame = titleFrame;
    
    CGRect descriptionFrame = self.descriptionLabel.frame;
    descriptionFrame.origin.y -= verticalIncrement;
    self.descriptionLabel.frame = descriptionFrame;
}

#pragma mark - IBActions

- (IBAction)setupButtonPressed:(UIButton *)sender {
    OnboardingViewController *setupVC = [OnboardingViewController instanciateOnboardingWithType:OnboardingTypePermissions];
    setupVC.completion = ^{
        [self.delegate setupFinished];
    };
    
    [self presentViewController:setupVC animated:NO completion:^{
        self.titleLabel.hidden = self.descriptionLabel.hidden = YES;
        self.setupButton.hidden = self.skipButton.hidden = YES;
    }];
}

- (IBAction)skipButtonPressed:(UIButton *)sender {
    [self.delegate setupFinished];
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if (error.type) {
        return;
    }
    
    if (request.type == MEGARequestTypeFetchNodes) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performAnimation];
        });
    }
}

@end
