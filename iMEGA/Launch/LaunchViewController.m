
#import "LaunchViewController.h"

#import "MEGASdkManager.h"

#import "UIColor+MNZCategory.h"

@interface LaunchViewController () <MEGARequestDelegate>

@end

@implementation LaunchViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.circularShapeLayer = [CAShapeLayer layer];
    self.circularShapeLayer.bounds = self.logoImageView.bounds;
    CGFloat radiusLogoImageView = self.logoImageView.bounds.size.width/2.0f;
    self.circularShapeLayer.position = CGPointMake(radiusLogoImageView, radiusLogoImageView);
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(radiusLogoImageView, radiusLogoImageView) radius:(radiusLogoImageView + 4.0f) startAngle:-M_PI_2 endAngle:3*M_PI_2 clockwise:YES];
    self.circularShapeLayer.path = [path CGPath];
    self.circularShapeLayer.strokeColor = UIColor.mnz_redMain.CGColor;
    self.circularShapeLayer.fillColor = UIColor.clearColor.CGColor;
    self.circularShapeLayer.lineWidth = 2.0f;
    
    [[MEGASdkManager sharedMEGASdk] addMEGARequestDelegate:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] iPhone4X] || [[UIDevice currentDevice] iPhone5X]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if (error.type) {
        return;
    }
    
    if (request.type == MEGARequestTypeFetchNodes) {
        [self.delegate setupFinished];
    }
}

@end
