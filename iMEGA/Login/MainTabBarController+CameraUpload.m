
#import "MainTabBarController+CameraUpload.h"
#import "CameraUploadManager+Settings.h"
#import "CustomModalAlertViewController.h"
#import "CameraUploadsTableViewController.h"
#import "UIApplication+MNZCategory.h"
#import "MEGANavigationController.h"

@implementation MainTabBarController (CameraUpload)

#pragma mark - Camera Upload v2 migration

- (void)showCameraUploadV2MigrationScreenIfNeeded {
    if (!CameraUploadManager.shouldShowCameraUploadV2MigrationScreen) {
        return;
    }
    
    CustomModalAlertViewController *migrationVC = [[CustomModalAlertViewController alloc] init];
    migrationVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    migrationVC.image = [UIImage imageNamed:@"cameraUploadsV2Migration"];
    migrationVC.viewTitle = AMLocalizedString(@"newCameraUpload", nil);
    migrationVC.detail = AMLocalizedString(@"newCameraUploadMigrationMessage", nil);
    migrationVC.firstButtonTitle = AMLocalizedString(@"useMostCompatibleFormats", nil);
    migrationVC.dismissButtonTitle = AMLocalizedString(@"customSettings", nil);
    
    __weak __typeof__(CustomModalAlertViewController) *weakCustom = migrationVC;
    migrationVC.firstCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:^{
            [CameraUploadManager migrateCurrentSettingsToCameraUplaodV2];
            CameraUploadManager.migratedToCameraUploadsV2 = YES;
            [CameraUploadManager.shared startCameraUploadIfNeeded];
        }];
    };
    
    migrationVC.dismissCompletion = ^{
        [weakCustom dismissViewControllerAnimated:YES completion:^{
            [self showCameraUploadSettingsScreen];
        }];
    };
    
    [UIApplication.mnz_presentingViewController presentViewController:migrationVC animated:YES completion:nil];
}

- (void)showCameraUploadSettingsScreen {
    CameraUploadsTableViewController *cameraUploadSettingsVC = [[UIStoryboard storyboardWithName:@"CameraUploadSettings" bundle:nil] instantiateViewControllerWithIdentifier:@"CameraUploadsSettingsID"];
    cameraUploadSettingsVC.isPresentedModally = YES;
    MEGANavigationController *navigationController = [[MEGANavigationController alloc] initWithRootViewController:cameraUploadSettingsVC];
    navigationController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [UIApplication.mnz_presentingViewController presentViewController:navigationController animated:YES completion:nil];
}

@end
