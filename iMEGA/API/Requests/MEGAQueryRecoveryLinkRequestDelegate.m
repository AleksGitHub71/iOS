
#import "MEGAQueryRecoveryLinkRequestDelegate.h"

#import "SAMKeychain.h"
#import "SVProgressHUD.h"

#import "ChangePasswordViewController.h"
#import "MEGASdkManager.h"
#import "MEGANavigationController.h"
#import "MEGALinkManager.h"
#import "UIApplication+MNZCategory.h"

@interface MEGAQueryRecoveryLinkRequestDelegate ()

@property (nonatomic, copy) void (^completion)(MEGARequest *request, MEGAError *error);
@property (nonatomic) URLType urlType;

@property (nonatomic) NSString *link;
@property (nonatomic) NSString *email;

@end

@implementation MEGAQueryRecoveryLinkRequestDelegate

- (instancetype)initWithRequestCompletion:(void (^)(MEGARequest *request, MEGAError *error))requestCompletion urlType:(URLType)urlType {
    self = [super init];
    if (self) {
        _completion = requestCompletion;
        _urlType = urlType;
    }
    return self;
}

#pragma mark - Private

- (void)presentChangeViewType:(ChangeType)changeType email:(NSString *)email masterKey:(NSString *)masterKey link:(NSString *)link {
    ChangePasswordViewController *changePasswordVC = [[UIStoryboard storyboardWithName:@"Settings" bundle:nil] instantiateViewControllerWithIdentifier:@"ChangePasswordViewControllerID"];
    changePasswordVC.changeType = changeType;
    changePasswordVC.email = email;
    changePasswordVC.masterKey = masterKey;
    changePasswordVC.link = link;
    
    MEGANavigationController *navigationController = [[MEGANavigationController alloc] initWithRootViewController:changePasswordVC];
    [navigationController addCancelButton];
    
    UIViewController *visibleViewController = UIApplication.mnz_visibleViewController;
    if ([visibleViewController isKindOfClass:UIAlertController.class]) {
        [visibleViewController dismissViewControllerAnimated:NO completion:^{
            [UIApplication.mnz_visibleViewController presentViewController:navigationController animated:YES completion:nil];
        }];
    } else {
        [visibleViewController presentViewController:navigationController animated:YES completion:nil];
    }
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    [super onRequestStart:api request:request];
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    [super onRequestFinish:api request:request error:error];
    
    if (error.type) {
        switch (error.type) {
            case MEGAErrorTypeApiEExpired: {
                NSString *alertTitle;
                if ([MEGALinkManager urlType] == URLTypeCancelAccountLink) {
                    alertTitle = AMLocalizedString(@"cancellationLinkHasExpired", @"During account cancellation (deletion)");
                } else if ([MEGALinkManager urlType] == URLTypeRecoverLink) {
                    alertTitle = AMLocalizedString(@"recoveryLinkHasExpired", @"Message shown during forgot your password process if the link to reset password has expired");
                }
                UIAlertController *linkHasExpiredAlertController = [UIAlertController alertControllerWithTitle:alertTitle message:nil preferredStyle:UIAlertControllerStyleAlert];
                [linkHasExpiredAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
                
                [UIApplication.mnz_visibleViewController presentViewController:linkHasExpiredAlertController animated:YES completion:nil];
                break;
            }
                
            case MEGAErrorTypeApiENoent: {
                [MEGALinkManager showLinkNotValid];
                break;
            }
                
            default: {
                [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
                [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"%@ %@", request.requestString, error.name]];
                break;
            }
        }
    } else {
        if ([MEGALinkManager urlType] == URLTypeChangeEmailLink) {
            [MEGALinkManager presentConfirmViewWithURLType:URLTypeChangeEmailLink link:request.link email:request.email];
        } else if ([MEGALinkManager urlType] == URLTypeCancelAccountLink) {
            [MEGALinkManager presentConfirmViewWithURLType:URLTypeCancelAccountLink link:request.link email:request.email];
        } else if ([MEGALinkManager urlType] == URLTypeRecoverLink) {
            if (request.flag) {
                UIAlertController *masterKeyLoggedInAlertController;
                if ([SAMKeychain passwordForService:@"MEGA" account:@"sessionV3"]) {
                    masterKeyLoggedInAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"passwordReset", @"Headline of the password reset recovery procedure") message:AMLocalizedString(@"youRecoveryKeyIsGoingTo", @"Text of the alert after opening the recovery link to reset pass being logged.") preferredStyle:UIAlertControllerStyleAlert];
                } else {
                    masterKeyLoggedInAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"passwordReset", @"Headline of the password reset recovery procedure") message:AMLocalizedString(@"pleaseEnterYourRecoveryKey", @"A message shown to explain that the user has to input (type or paste) their recovery key to continue with the reset password process.") preferredStyle:UIAlertControllerStyleAlert];
                    [masterKeyLoggedInAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                        textField.placeholder = AMLocalizedString(@"recoveryKey", @"Label for any 'Recovery Key' button, link, text, title, etc. Preserve uppercase - (String as short as possible). The Recovery Key is the new name for the account 'Master Key', and can unlock (recover) the account if the user forgets their password.");
                    }];
                }
                
                [masterKeyLoggedInAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                [masterKeyLoggedInAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    NSString *masterKey = masterKeyLoggedInAlertController.textFields.count ? masterKeyLoggedInAlertController.textFields[0].text : [[MEGASdkManager sharedMEGASdk] masterKey];
                    [self presentChangeViewType:ChangeTypeResetPassword email:[MEGALinkManager emailOfNewSignUpLink] masterKey:masterKey link:request.link];
                    [MEGALinkManager setEmailOfNewSignUpLink:nil];
                }]];
                
                [MEGALinkManager setEmailOfNewSignUpLink:request.email];
                
                [UIApplication.mnz_visibleViewController presentViewController:masterKeyLoggedInAlertController animated:YES completion:nil];
            } else {
                [self presentChangeViewType:ChangeTypeParkAccount email:request.email masterKey:nil link:request.link];
            }
        }
    }
}

@end
