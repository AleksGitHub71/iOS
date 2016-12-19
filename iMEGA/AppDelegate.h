#import <UIKit/UIKit.h>
#import "MEGASdkManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, MEGARequestDelegate, MEGATransferDelegate, MEGAGlobalDelegate, MEGAChatRequestDelegate, MEGAChatDelegate> {

    UIBackgroundTaskIdentifier bgTask;
}

@property (strong, nonatomic) UIWindow *window;

@end
