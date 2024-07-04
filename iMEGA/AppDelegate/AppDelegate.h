NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MEGANotificationType) {
    MEGANotificationTypeShareFolder = 1,
    MEGANotificationTypeChatMessage = 2,
    MEGANotificationTypeContactRequest = 3,
    MEGANotificationTypeGeneric = 8
};

@class MainTabBarController;
@class CloudDriveQuickUploadActionRouter;
@class CallsCoordinator;
@class VoIPPushDelegate;

@interface AppDelegate : UIResponder

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, nullable) CallsCoordinator *callsCoordinator;
@property (nonatomic, nullable) VoIPPushDelegate *voIPPushDelegate;
@property (strong, nonatomic, nullable) UIWindow *blockingWindow;
@property (nonatomic, weak, readonly) MainTabBarController *mainTBC;
@property (nonatomic) NSNumber *openChatLater;
@property (nonatomic) BOOL showAccountUpgradeScreen;
@property (nonatomic) BOOL loadProductsAndShowAccountUpgradeScreen;
@property (strong, nonatomic) CloudDriveQuickUploadActionRouter* quickUploadActionRouter;

- (void)showMainTabBar;
- (void)showOnboardingWithCompletion:(nullable void (^)(void))completion;
- (void)presentAccountExpiredAlertIfNeeded;
- (void)showLink:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
