#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OverlayWindow, OverlayView;

@interface OverlayManager : NSObject

+ (instancetype)sharedManager;

- (void)presentImagePickerFromViewController:(UIViewController *)vc;
- (void)setImage:(UIImage *)image withIdentifier:(nullable NSString *)identifier;
- (void)showOverlayAnimated:(BOOL)animated;
- (void)hideOverlayAnimated:(BOOL)animated;
- (void)toggleVisibility;
- (void)setTapThroughEnabled:(BOOL)enabled;
- (BOOL)isTapThroughEnabled;

- (void)saveState;
- (void)restoreState;

@end

NS_ASSUME_NONNULL_END
