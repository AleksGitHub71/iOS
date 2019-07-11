
#import "VideoUploadsQualityTableViewController.h"
#import "SelectableTableViewCell.h"
#import "CameraUploadManager+Settings.h"

@interface VideoUploadsQualityTableViewController ()

@property (weak, nonatomic) IBOutlet UILabel *lowLabel;
@property (weak, nonatomic) IBOutlet UILabel *mediumLabel;
@property (weak, nonatomic) IBOutlet UILabel *highLabel;
@property (weak, nonatomic) IBOutlet UILabel *originalLabel;

@property (weak, nonatomic) NSIndexPath *currentIndexPath;

@end

@implementation VideoUploadsQualityTableViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = AMLocalizedString(@"videoQuality", @"Title that refers to the quality of the chat (Either Online or Offline)");
    
    self.lowLabel.text = AMLocalizedString(@"low", @"Low");
    self.mediumLabel.text = AMLocalizedString(@"medium", nil);
    self.highLabel.text = AMLocalizedString(@"high", @"High");
    self.originalLabel.text = AMLocalizedString(@"original", @"Original");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.currentIndexPath = [NSIndexPath indexPathForRow:CameraUploadManager.HEVCToH264CompressionQuality inSection:0];
    SelectableTableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.currentIndexPath];
    cell.redCheckmarkImageView.hidden = NO;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (CameraUploadManager.HEVCToH264CompressionQuality == indexPath.row) {
        return;
    }
    
    [CameraUploadManager setHEVCToH264CompressionQuality:indexPath.row];
    SelectableTableViewCell *previousSelectedCell = [self.tableView cellForRowAtIndexPath:self.currentIndexPath];
    previousSelectedCell.redCheckmarkImageView.hidden = YES;
    SelectableTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    cell.redCheckmarkImageView.hidden = NO;
    self.currentIndexPath = indexPath;
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
