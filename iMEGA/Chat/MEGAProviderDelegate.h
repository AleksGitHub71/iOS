
#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>

#import "MEGACallManager.h"
#import "MEGAChatCall+MNZCategory.h"

@interface MEGAProviderDelegate : NSObject <CXProviderDelegate>

@property (getter=isOutgoingCall) BOOL outgoingCall;

- (instancetype)initWithMEGACallManager:(MEGACallManager *)megaCallManager;

- (void)reportIncomingCall:(MEGAChatCall *)call;
- (void)reportOutgoingCall:(MEGAChatCall *)call;
- (void)reportEndCall:(MEGAChatCall *)call;

@end
