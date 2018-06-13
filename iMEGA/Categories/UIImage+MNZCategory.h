
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MEGAChatMessageEndCallReason);

@interface UIImage (MNZCategory)

+ (UIImage *)mnz_convertBitmapRGBA8ToUIImage:(unsigned char *)buffer
                               withWidth:(NSInteger)width
                              withHeight:(NSInteger)height;
+ (UIImage *)mnz_imageForUserHandle:(uint64_t)userHandle size:(CGSize)size delegate:(id<MEGARequestDelegate>)delegate;
+ (UIImage *)mnz_qrImageFromString:(NSString *)qrString withSize:(CGSize)size;
+ (UIImage *)mnz_qrImageWithDotsFromString:(NSString *)qrString withSize:(CGSize)size;
+ (UIImage *)mnz_imageByEndCallReason:(MEGAChatMessageEndCallReason)endCallReason;

@end
