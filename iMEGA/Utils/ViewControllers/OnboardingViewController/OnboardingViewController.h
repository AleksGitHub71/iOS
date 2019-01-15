
#import <UIKit/UIKit.h>

#import "OnboardingType.h"

NS_ASSUME_NONNULL_BEGIN

@interface OnboardingViewController : UIViewController

+ (OnboardingViewController *)instanciateOnboardingWithType:(OnboardingType)type;

@property (nonatomic, copy) void (^completion)(void);

@end

NS_ASSUME_NONNULL_END
