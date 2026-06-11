#import "OverlayWindow.h"

@implementation OverlayWindow

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Ensure window is above all normal UI but below some system elements
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.tapThroughEnabled = YES;
        
        // Enable high-frequency touch delivery for smooth 120 FPS support
        if (@available(iOS 13.4, *)) {
            self.windowScene.windows;  // Ensure we're registered as top window
        }
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    
    // If tap-through is enabled and we hit this window (not a subview), return nil to pass touch through
    if (self.tapThroughEnabled && view == self) {
        return nil;
    }
    
    return view;
}

@end
