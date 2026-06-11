#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ImagePickerControllerDelegate <NSObject>
- (void)imagePickerControllerDidSelectImage:(UIImage *)image identifier:(nullable NSString *)identifier;
- (void)imagePickerControllerDidCancel;
@end

@interface ImagePickerController : NSObject

- (instancetype)initWithPresentingViewController:(UIViewController *)vc delegate:(id<ImagePickerControllerDelegate>)delegate;
- (void)present;

@end

NS_ASSUME_NONNULL_END
