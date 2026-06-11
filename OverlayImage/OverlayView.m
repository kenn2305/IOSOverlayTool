#import "OverlayView.h"
#import <QuartzCore/QuartzCore.h>

@implementation OverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.userInteractionEnabled = YES;
        _imageView.clipsToBounds = NO;
        _imageView.layer.shadowOpacity = 0.0;  // No shadow
        _imageView.layer.borderWidth = 0.0;    // No border
        
        // GPU acceleration: use layer-backed rendering
        _imageView.layer.drawsAsynchronously = YES;
        _imageView.layer.rasterizationScale = [UIScreen mainScreen].scale;
        
        [self addSubview:_imageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.imageView.image && CGRectIsEmpty(self.imageView.frame)) {
        [self setImage:self.imageView.image];
    }
}

- (void)setImage:(UIImage *)image {
    if (!image) return;
    
    self.imageView.image = image;
    
    CGSize imgSize = image.size;
    if (imgSize.width > 0 && imgSize.height > 0) {
        // Calculate size maintaining aspect ratio, max 300pt on longest side
        CGFloat maxDim = 300.0;
        CGFloat ratio = imgSize.width / imgSize.height;
        CGSize target;
        
        if (ratio >= 1.0) {
            target = CGSizeMake(maxDim, maxDim / ratio);
        } else {
            target = CGSizeMake(maxDim * ratio, maxDim);
        }
        
        // Use CATransaction to disable implicit animations for smoother direct layer updates
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        self.imageView.bounds = CGRectMake(0, 0, target.width, target.height);
        self.imageView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        
        [CATransaction commit];
    }
}

@end
