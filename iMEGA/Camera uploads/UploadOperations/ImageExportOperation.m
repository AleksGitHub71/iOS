
#import "ImageExportOperation.h"
#import "ImageExportor.h"

@interface ImageExportOperation ()

@property (strong, nonatomic) NSURL *imageURL;
@property (strong, nonatomic) NSURL *outputURL;
@property (strong, nonatomic) NSString *outputImageTypeUTI;
@property (nonatomic) BOOL shouldStripGPSInfo;
@property (copy, nonatomic) void (^completion)(BOOL succeeded);
@property (strong, nonatomic) ImageExportor *imageExporter;

@end

@implementation ImageExportOperation

- (instancetype)initWithImageURL:(NSURL *)imageURL outputURL:(NSURL *)outputURL outputImageTypeUTI:(NSString *)UTI shouldStripGPSInfo:(BOOL)shouldStripGPSInfo completion:(void (^)(BOOL))completion {
    self = [super init];
    if (self) {
        _imageURL = imageURL;
        _outputURL = outputURL;
        _outputImageTypeUTI = UTI;
        _shouldStripGPSInfo = shouldStripGPSInfo;
        _completion = completion;
    }
    
    return self;
}

- (ImageExportor *)imageExporter {
    if (_imageExporter == nil) {
        _imageExporter = [[ImageExportor alloc] init];
    }
    
    return _imageExporter;
}

- (void)start {
    if (self.isCancelled) {
        [self finishOperation];
        if (self.completion) {
            self.completion(NO);
        }
        return;
    }
    
    [self startExecuting];

    BOOL succeeded = [self.imageExporter exportImageFile:self.imageURL toURL:self.outputURL outputImageUTIType:self.outputImageTypeUTI shouldStripGPSInfo:self.shouldStripGPSInfo];
    [self finishOperation];
    if (self.completion) {
        if (self.isCancelled) {
            self.completion(NO);
        } else {
            self.completion(succeeded);
        }
    }
}

@end
