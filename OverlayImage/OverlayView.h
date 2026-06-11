#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OverlayManager;

@interface OverlayView : UIView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, weak) OverlayManager *manager;

- (void)setImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
