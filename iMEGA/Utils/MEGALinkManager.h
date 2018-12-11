
#import <Foundation/Foundation.h>

#import "LinkOption.h"
#import "URLType.h"

@interface MEGALinkManager : NSObject

#pragma mark - Utils to manage MEGA links

@property (class, nonatomic) NSURL *linkURL;
@property (class, nonatomic) NSURL *linkEncryptedURL;
@property (class, nonatomic) URLType urlType;
@property (class, nonatomic) NSString *emailOfNewSignUpLink;

+ (void)resetLinkAndURLType;

#pragma mark - Utils to manage links when you are not logged

@property (class, nonatomic) LinkOption selectedOption;
@property (class, nonatomic, readonly) NSMutableArray *nodesFromLinkMutableArray;

+ (void)resetUtilsForLinksWithoutSession;

+ (void)processSelectedOptionOnLink;

#pragma mark - Spotlight

@property (class, nonatomic) NSString *nodeToPresentBase64Handle;

+ (void)presentNode;

#pragma mark - Manage MEGA links

+ (void)processLinkURL:(NSURL *)url;

+ (void)showLinkNotValid;

+ (void)presentConfirmViewWithURLType:(URLType)urlType link:(NSString *)link email:(NSString *)email;

+ (void)showFileLinkView;

@end
