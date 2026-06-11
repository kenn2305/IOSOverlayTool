#import <UIKit/UIKit.h>
#import "OverlayManager.h"

%ctor {
    @autoreleasepool {
        // Initialize the overlay manager at process startup
        // This will create the overlay window and restore saved state
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [OverlayManager sharedManager];
        });
    }
}
