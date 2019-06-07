
#import "TransferSessionTaskDelegate.h"
#import "CameraUploadCompletionManager.h"
#import "TransferResponseValidator.h"

static const NSUInteger MEGATransferTokenLength = 36;

@interface TransferSessionTaskDelegate ()

@property (strong, nonatomic) NSMutableData *mutableData;
@property (copy, nonatomic) UploadCompletionHandler completion;
@property (strong, nonatomic) TransferResponseValidator *responseValidator;

@end

@implementation TransferSessionTaskDelegate

- (instancetype)initWithCompletionHandler:(UploadCompletionHandler)completion {
    self = [super init];
    if (self) {
        _mutableData = [NSMutableData data];
        _completion = completion;
        _responseValidator = [[TransferResponseValidator alloc] init];
    }
    
    return self;
}

#pragma mark - task level delegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSInteger statusCode = 0;
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = [(NSHTTPURLResponse *)task.response statusCode];
    }
    
    MEGALogInfo(@"[Camera Upload] Session %@ %p task %@ %p completed with status %li", session.configuration.identifier, session, task.taskDescription, task, (long)statusCode);

    NSData *transferToken = [self.mutableData copy];
    
    if (error) {
        if (self.completion) {
            self.completion(transferToken, error);
        } else {
            [self handleTransferError:error forTask:task];
        }
    } else {
        NSError *responseError;
        [self.responseValidator validateURLResponse:task.response data:transferToken error:&responseError];
        if (self.completion) {
            self.completion(transferToken, responseError);
        } else {
            if (responseError) {
                [self handleTransferError:responseError forTask:task];
            } else {
                [self handleTransferToken:transferToken forTask:task inSession:session];
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    MEGALogDebug(@"[Camera Upload] Session %@ %p task %@ %p did send body data %lli, total bytes sent %lli, total bytes expected to send %lli", session.configuration.identifier, session, task.taskDescription, task, bytesSent, totalBytesSent, totalBytesExpectedToSend);
}

#pragma mark - data level delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    MEGALogDebug(@"[Camera Upload] Session %@ %p task %@ %p received data with size: %lu", session.configuration.identifier, session, dataTask.taskDescription, dataTask, (unsigned long)data.length);
    [self.mutableData appendData:data];
}

#pragma mark - util methods

- (void)handleTransferError:(NSError *)error forTask:(NSURLSessionTask *)task {
    NSString *localIdentifier = task.taskDescription;
    MEGALogError(@"[Camera Upload] Session task %@ completed with error %@", localIdentifier, error);
    if (localIdentifier.length == 0) {
        MEGALogError(@"[Camera Upload] Session task description is empty");
        return;
    }
    
    CameraAssetUploadStatus errorStatus = CameraAssetUploadStatusFailed;
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        errorStatus = CameraAssetUploadStatusCancelled;
    }

    [CameraUploadCompletionManager.shared finishUploadForLocalIdentifier:localIdentifier status:errorStatus];
}

- (void)handleTransferToken:(NSData *)token forTask:(NSURLSessionTask *)task inSession:(NSURLSession *)session {
    NSString *localIdentifier = task.taskDescription;
    if (localIdentifier.length == 0) {
        MEGALogError(@"[Camera Upload] Session task description is empty");
        return;
    }

    if (token.length == 0) {
        MEGALogDebug(@"[Camera Upload] Session %@ task %@ completed with empty token", session.configuration.identifier, localIdentifier);
        [CameraUploadCompletionManager.shared handleEmptyTransferTokenInSessionTask:task];
    } else if (token.length == MEGATransferTokenLength) {
        [CameraUploadCompletionManager.shared handleCompletedTransferWithLocalIdentifier:localIdentifier token:token];
    } else {
        MEGALogError(@"[Camera Upload] Session %@ task %@ completed with bad transfer token %@, URL %@, response %@", session.configuration.identifier, localIdentifier, [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding], task.response.URL, task.response);
        [CameraUploadCompletionManager.shared finishUploadForLocalIdentifier:localIdentifier status:CameraAssetUploadStatusFailed];
    }
}

@end
