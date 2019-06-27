
#import "MEGAImagePickerController.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>

#import "SVProgressHUD.h"

#import "Helper.h"
#import "MEGACreateFolderRequestDelegate.h"
#import "MEGASdkManager.h"
#import "NSDate+MNZCategory.h"
#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"

@interface MEGAImagePickerController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, getter=toUploadSomething) BOOL uploadSomething;
@property (nonatomic) MEGANode *parentNode;

@property (nonatomic, getter=toChangeAvatar) BOOL changeAvatar;

@property (nonatomic, getter=toShareThroughChat) BOOL shareThroughChat;
@property (nonatomic, copy) void (^filePathCompletion)(NSString *filePath, UIImagePickerControllerSourceType sourceType);
@property (nonatomic) NSString *filePath;

@end

@implementation MEGAImagePickerController

- (instancetype)initToUploadWithParentNode:(MEGANode *)parentNode sourceType:(UIImagePickerControllerSourceType)sourceType {
    self = [super init];
    
    if (self) {
        _uploadSomething = YES;
        _parentNode = parentNode;
        self.sourceType  = sourceType;
    }
    
    return self;
}

- (instancetype)initToChangeAvatarWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    self = [super init];
    
    if (self) {
        _changeAvatar = YES;
        self.sourceType  = sourceType;
    }
    
    return self;
}

- (instancetype)initToShareThroughChatWithSourceType:(UIImagePickerControllerSourceType)sourceType filePathCompletion:(void (^)(NSString *filePath, UIImagePickerControllerSourceType sourceType))filePathCompletion {
    self = [super init];
    
    if (self) {
        _shareThroughChat = YES;
        _filePathCompletion = filePathCompletion;
        self.sourceType = sourceType;
    }
    
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.toShareThroughChat) {
        [self createMyChatFilesFolderWithCompletion:nil];
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:NSTemporaryDirectory()]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:NSTemporaryDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    if (![UIImagePickerController isSourceTypeAvailable:self.sourceType]) {
        if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
            [SVProgressHUD showImage:[UIImage imageNamed:@"hudNoCamera"] status:AMLocalizedString(@"noCamera", @"Error message shown when there's no camera available on the device")];
        }
        return;
    }
    
    self.modalPresentationStyle = UIModalPresentationCurrentContext;
    if (self.toUploadSomething) {
        self.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, (NSString *)kUTTypeImage, nil];
    } else if (self.toChangeAvatar) {
        self.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, nil];
    } else if (self.toShareThroughChat) {
        if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
            self.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:self.sourceType];
        }
    }
    self.videoQuality = UIImagePickerControllerQualityTypeHigh;
    self.delegate = self;
}

#pragma mark - Private

- (NSString *)createAvatarWithImagePath:(NSString *)imagePath {
    NSString *base64Handle = [MEGASdk base64HandleForUserHandle:[[[MEGASdkManager sharedMEGASdk] myUser] handle]];
    NSString *avatarFilePath = [[Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"] stringByAppendingPathComponent:base64Handle];
    if ([[MEGASdkManager sharedMEGASdk] createAvatar:imagePath destinationPath:avatarFilePath]) {
        return avatarFilePath;
    } else {
        return nil;
    }
}

- (void)prepareUploadDestination {
    MEGANode *parentNode = [[MEGASdkManager sharedMEGASdk] nodeForPath:@"/My chat files"];
    if (parentNode) {
        [self triggerPathCompletion];
    } else {
        [self createMyChatFilesFolderWithCompletion:^(MEGARequest *request) {
            [self triggerPathCompletion];
        }];
    }
}

- (void)triggerPathCompletion {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.filePathCompletion) {
        self.filePathCompletion(self.filePath, self.sourceType);
    }
}

- (void)createMyChatFilesFolderWithCompletion:(void (^)(MEGARequest *request))completion {
    MEGANode *parentNode = [[MEGASdkManager sharedMEGASdk] nodeForPath:@"/My chat files"];
    if (!parentNode) {
        MEGACreateFolderRequestDelegate *createFolderRequestDelegate = [[MEGACreateFolderRequestDelegate alloc] initWithCompletion:completion];
        [[MEGASdkManager sharedMEGASdk] createFolderWithName:@"My chat files" parent:[[MEGASdkManager sharedMEGASdk] rootNode] delegate:createFolderRequestDelegate];
    }
}

- (void)actionForImagePath:(NSString *)imagePath {
    if (self.toUploadSomething) {
        self.filePath = imagePath.mnz_relativeLocalPath;
        [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:self.filePath parent:self.parentNode appData:nil isSourceTemporary:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (self.toChangeAvatar) {
        NSString *avatarFilePath = [self createAvatarWithImagePath:imagePath];
        [[MEGASdkManager sharedMEGASdk] setAvatarUserWithSourceFilePath:avatarFilePath];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (self.toShareThroughChat) {
        [[MEGASdkManager sharedMEGASdk] createPreview:imagePath destinatioPath:imagePath];
        self.filePath = imagePath.mnz_relativeLocalPath;
        [self prepareUploadDestination];
    }
}

- (void)actionForVideo {
    if (self.toUploadSomething) {
        [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:self.filePath parent:self.parentNode appData:nil isSourceTemporary:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (self.toShareThroughChat) {
        [self prepareUploadDestination];
    }
}

- (void)createAssetType:(PHAssetResourceType)type filePath:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCreationRequest *assetCreationRequest = [PHAssetCreationRequest creationRequestForAsset];
        [assetCreationRequest addResourceWithType:type fileURL:fileURL options:nil];
    } completionHandler:^(BOOL success, NSError * _Nullable nserror) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (type) {
                    case PHAssetResourceTypePhoto:
                        [self actionForImagePath:filePath];
                        break;
                    case PHAssetResourceTypeVideo:
                        [self actionForVideo];
                        break;
                        
                    default:
                        break;
                }
            });
        } else {
            MEGALogError(@"Creation request for asset failed: %@ (Domain: %@ - Code:%ld)", nserror.localizedDescription, nserror.domain, nserror.code);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissViewControllerAnimated:YES completion:nil];
            });
        }
    }];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeImage]) {
        NSString *imageName = [NSString stringWithFormat:@"%@.jpg", NSDate.date.mnz_formattedDefaultNameForMedia];
        NSString *imagePath = (self.toUploadSomething || self.toShareThroughChat) ? [[[NSFileManager defaultManager] uploadsDirectory] stringByAppendingPathComponent:imageName] : [NSTemporaryDirectory() stringByAppendingPathComponent:imageName];
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        [imageData writeToFile:imagePath atomically:YES];
        
        //If the app has 'Read and Write' access to Photos and the user didn't configure the setting to save the media captured from the MEGA app in Photos, enable it by default.
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"isSaveMediaCapturedToGalleryEnabled"]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isSaveMediaCapturedToGalleryEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        BOOL isSaveMediaCapturedToGalleryEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"isSaveMediaCapturedToGalleryEnabled"];
        if (isSaveMediaCapturedToGalleryEnabled) {
            [self createAssetType:PHAssetResourceTypePhoto filePath:imagePath];
        } else {
            [self actionForImagePath:imagePath];
        }
    } else if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie]) {
        NSURL *videoUrl = (NSURL *)[info objectForKey:UIImagePickerControllerMediaURL];
        NSDictionary *attributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:videoUrl.path error:nil];
        NSDate *modificationDate = [attributesDictionary objectForKey:NSFileModificationDate];
        NSString *videoName = [modificationDate.mnz_formattedDefaultNameForMedia stringByAppendingPathExtension:@"mov"];
        NSString *localFilePath = [[[NSFileManager defaultManager] uploadsDirectory] stringByAppendingPathComponent:videoName];
        NSError *error = nil;
        
        self.filePath = localFilePath.mnz_relativeLocalPath;
        if ([[NSFileManager defaultManager] moveItemAtPath:videoUrl.path toPath:localFilePath error:&error]) {
            //If the app has 'Read and Write' access to Photos and the user didn't configure the setting to save the media captured from the MEGA app in Photos, enable it by default.
            if (![[NSUserDefaults standardUserDefaults] objectForKey:@"isSaveMediaCapturedToGalleryEnabled"]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isSaveMediaCapturedToGalleryEnabled"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            BOOL isSaveMediaCapturedToGalleryEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"isSaveMediaCapturedToGalleryEnabled"];
            if (isSaveMediaCapturedToGalleryEnabled) {
                [self createAssetType:PHAssetResourceTypeVideo filePath:localFilePath];
            } else {
                [self actionForVideo];
            }
        } else {
            MEGALogError(@"Move item at path failed with error: %@", error);
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
