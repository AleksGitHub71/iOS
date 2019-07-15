
#import "CameraUploadAdvancedOptionsViewController.h"
#import "CameraUploadManager+Settings.h"
#import "CameraScanner.h"

typedef NS_ENUM(NSUInteger, AdvancedOptionSection) {
    AdvancedOptionSectionLivePhoto,
    AdvancedOptionSectionBurstPhoto,
    AdvancedOptionSectionHiddenAlbum,
};

@interface CameraUploadAdvancedOptionsViewController ()

@property (weak, nonatomic) IBOutlet UILabel *uploadVideosForLivePhotosLabel;
@property (weak, nonatomic) IBOutlet UISwitch *uploadVideosForlivePhotosSwitch;
@property (weak, nonatomic) IBOutlet UILabel *uploadAllBurstPhotosLabel;
@property (weak, nonatomic) IBOutlet UISwitch *uploadAllBurstPhotosSwitch;
@property (weak, nonatomic) IBOutlet UILabel *uploadHiddenAlbumLabel;
@property (weak, nonatomic) IBOutlet UISwitch *uploadHiddenAlbumSwitch;

@end

@implementation CameraUploadAdvancedOptionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationItem setTitle:AMLocalizedString(@"advanced", nil)];
    
    self.uploadVideosForLivePhotosLabel.text = AMLocalizedString(@"Upload videos for Live Photos", nil);
    self.uploadVideosForlivePhotosSwitch.on = CameraUploadManager.shouldUploadVideosForLivePhotos;
    self.uploadAllBurstPhotosLabel.text = AMLocalizedString(@"Upload all burst photos", nil);
    self.uploadAllBurstPhotosSwitch.on = CameraUploadManager.shouldUploadAllBurstPhotos;
    self.uploadHiddenAlbumLabel.text = AMLocalizedString(@"Upload Hidden Album", nil);
    self.uploadHiddenAlbumSwitch.on = CameraUploadManager.shouldUploadHiddenAlbum;
}

#pragma mark - UI Actions

- (IBAction)didChangeValueForLivePhotosSwitch:(UISwitch *)sender {
    CameraUploadManager.uploadVideosForLivePhotos = sender.isOn;
    [self configCameraUploadWhenValueChangedForSwitch:sender];
}

- (IBAction)didChangeValueForBurstPhotosSwitch:(UISwitch *)sender {
    CameraUploadManager.uploadAllBurstPhotos = sender.isOn;
    [self configCameraUploadWhenValueChangedForSwitch:sender];
}

- (IBAction)didChangeValueForHiddenAssetsSwitch:(UISwitch *)sender {
    CameraUploadManager.uploadHiddenAlbum = sender.isOn;
    [self configCameraUploadWhenValueChangedForSwitch:sender];
}

- (void)configCameraUploadWhenValueChangedForSwitch:(UISwitch *)sender {
    [self.tableView reloadData];
    if (sender.isOn) {
        [CameraUploadManager.shared startCameraUploadIfNeeded];
    }
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *title;
    switch (section) {
        case AdvancedOptionSectionLivePhoto:
            if (self.uploadVideosForlivePhotosSwitch.isOn) {
                title = AMLocalizedString(@"Underlying videos and key photos in Live Photos will be uploaded.", nil);
            } else {
                title = AMLocalizedString(@"Only key photos in Live Photos will be uploaded.", nil);
            }
            break;
        case AdvancedOptionSectionBurstPhoto:
            if (self.uploadAllBurstPhotosSwitch.isOn) {
                title = AMLocalizedString(@"All photos from burst photo sequences will be uploaded.", nil);
            } else {
                title = AMLocalizedString(@"Only the picked and representative photos from burst photo sequences will be uploaded.", nil);
            }
            break;
        case AdvancedOptionSectionHiddenAlbum:
            if (self.uploadHiddenAlbumSwitch.isOn) {
                title = AMLocalizedString(@"The photos or videos in your Hidden Album will be uploaded.", nil);
            } else {
                title = AMLocalizedString(@"The photos or videos in your Hidden Album will not be uploaded.", nil);
            }
            break;
        default:
            break;
    }
    
    return title;
}

@end
