#import "OverlayManager.h"
#import "OverlayWindow.h"
#import "OverlayView.h"
#import "ImagePickerController.h"
#import <Photos/Photos.h>

static NSString * const kOverlayPrefsKey = @"com.example.overlayimage";
static NSString * const kPositionXKey = @"positionX";
static NSString * const kPositionYKey = @"positionY";
static NSString * const kScaleKey = @"scale";
static NSString * const kVisibilityKey = @"visibility";
static NSString * const kImagePathKey = @"imagePath";
static NSString * const kTapThroughKey = @"tapThrough";

@interface OverlayManager () <ImagePickerControllerDelegate>
@property (nonatomic, strong) OverlayWindow *window;
@property (nonatomic, strong) OverlayView *overlayView;
@property (nonatomic, assign) BOOL tapThroughEnabled;
@property (nonatomic, strong) ImagePickerController *imagePicker;
@end

@implementation OverlayManager

+ (instancetype)sharedManager {
    static OverlayManager *s_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_shared = [[self alloc] init];
    });
    return s_shared;
}

- (instancetype)init {
    if (self = [super init]) {
        CGRect screen = [UIScreen mainScreen].bounds;
        _window = [[OverlayWindow alloc] initWithFrame:screen];
        _window.hidden = NO;
        _overlayView = [[OverlayView alloc] initWithFrame:screen];
        _overlayView.manager = self;
        [_window addSubview:_overlayView];
        _tapThroughEnabled = YES;
        [self restoreState];
        [self setupGestureRecognizers];
    }
    return self;
}

- (void)setupGestureRecognizers {
    // Pan gesture for dragging
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.overlayView addGestureRecognizer:pan];
    
    // Pinch gesture for scaling
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self.overlayView addGestureRecognizer:pinch];
    
    // Tap gesture outside image to toggle visibility (if tap-through enabled)
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOutsideTap:)];
    tap.cancelsTouchesInView = NO;  // Let touch pass through
    [self.window addGestureRecognizer:tap];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.overlayView.superview];
    CGPoint center = self.overlayView.imageView.center;
    center.x += translation.x;
    center.y += translation.y;
    self.overlayView.imageView.center = center;
    [gesture setTranslation:CGPointZero inView:self.overlayView.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self saveState];
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    if (gesture.scale != 0) {
        CATransform3D transform = self.overlayView.imageView.layer.transform;
        CGFloat scale = sqrt(pow(transform.m11, 2) + pow(transform.m12, 2));
        scale *= gesture.scale;
        // Clamp scale between 0.5x and 3.0x
        scale = MAX(0.5, MIN(3.0, scale));
        
        CATransform3D newTransform = CATransform3DMakeScale(scale, scale, 1.0);
        self.overlayView.imageView.layer.transform = newTransform;
        gesture.scale = 1.0;
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self saveState];
    }
}

- (void)handleOutsideTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.window];
    BOOL tappedInside = [self.overlayView.imageView pointInside:[self.window convertPoint:point toView:self.overlayView.imageView] withEvent:nil];
    
    if (!tappedInside && self.tapThroughEnabled) {
        [self toggleVisibility];
    }
}

- (void)presentImagePickerFromViewController:(UIViewController *)vc {
    self.imagePicker = [[ImagePickerController alloc] initWithPresentingViewController:vc delegate:self];
    [self.imagePicker present];
}

- (void)setImage:(UIImage *)image withIdentifier:(NSString *)identifier {
    [self.overlayView setImage:image];
    [self saveState];
}

- (void)showOverlayAnimated:(BOOL)animated {
    if (animated) {
        CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeIn.fromValue = @0.0;
        fadeIn.toValue = @1.0;
        fadeIn.duration = 0.15;
        fadeIn.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fadeIn.fillMode = kCAFillModeForwards;
        fadeIn.removedOnCompletion = NO;
        [self.overlayView.layer addAnimation:fadeIn forKey:@"fadeIn"];
    }
    self.overlayView.hidden = NO;
}

- (void)hideOverlayAnimated:(BOOL)animated {
    if (animated) {
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeOut.fromValue = @1.0;
        fadeOut.toValue = @0.0;
        fadeOut.duration = 0.15;
        fadeOut.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fadeOut.fillMode = kCAFillModeForwards;
        fadeOut.removedOnCompletion = NO;
        [self.overlayView.layer addAnimation:fadeOut forKey:@"fadeOut"];
    }
    self.overlayView.hidden = YES;
}

- (void)toggleVisibility {
    BOOL hidden = self.overlayView.isHidden;
    if (hidden) {
        [self showOverlayAnimated:YES];
    } else {
        [self hideOverlayAnimated:YES];
    }
    [self saveState];
}

- (void)setTapThroughEnabled:(BOOL)enabled {
    _tapThroughEnabled = enabled;
    self.window.tapThroughEnabled = enabled;
    [self saveState];
}

- (BOOL)isTapThroughEnabled { return _tapThroughEnabled; }

- (void)saveState {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kOverlayPrefsKey];
    CGPoint center = self.overlayView.imageView.center;
    [defaults setFloat:center.x forKey:kPositionXKey];
    [defaults setFloat:center.y forKey:kPositionYKey];
    CATransform3D transform = self.overlayView.imageView.layer.transform;
    CGFloat scale = sqrt(pow(transform.m11, 2) + pow(transform.m12, 2));
    [defaults setFloat:scale forKey:kScaleKey];
    [defaults setBool:!self.overlayView.isHidden forKey:kVisibilityKey];
    [defaults setBool:self.tapThroughEnabled forKey:kTapThroughKey];
    [defaults synchronize];
}

- (void)restoreState {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kOverlayPrefsKey];
    
    CGFloat x = [defaults floatForKey:kPositionXKey];
    CGFloat y = [defaults floatForKey:kPositionYKey];
    if (x > 0 && y > 0) {
        self.overlayView.imageView.center = CGPointMake(x, y);
    }
    
    CGFloat scale = [defaults floatForKey:kScaleKey];
    if (scale > 0) {
        CATransform3D transform = CATransform3DMakeScale(scale, scale, 1.0);
        self.overlayView.imageView.layer.transform = transform;
    }
    
    BOOL visible = [defaults boolForKey:kVisibilityKey];
    self.overlayView.hidden = !visible;
    
    BOOL tapThrough = [defaults boolForKey:kTapThroughKey];
    self.tapThroughEnabled = tapThrough;
    self.window.tapThroughEnabled = tapThrough;
}

#pragma mark - ImagePickerControllerDelegate
- (void)imagePickerControllerDidSelectImage:(UIImage *)image identifier:(NSString *)identifier {
    [self setImage:image withIdentifier:identifier];
    [self showOverlayAnimated:YES];
}

- (void)imagePickerControllerDidCancel {
    // Handle cancellation
}

@end
