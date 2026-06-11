# OverlayImage Tweak Architecture

## Design Overview

OverlayImage is a system-wide image overlay tool for jailbroken iOS 18 that displays user-selected photos above all applications, supports gesture manipulation, persists state, and implements advanced touch handling for seamless app interaction.

---

## Major Design Decisions

### 1. **SpringBoard Injection (Process-Level Overlay)**
**Decision**: Hook into SpringBoard (or the main process) to create an OverlayWindow at system level.

**Rationale**:
- Ensures overlay remains visible above all applications.
- Survives app switching (stays in SpringBoard's window hierarchy, not app-specific).
- Centralized lifecycle; no per-app overhead.
- Single point of configuration and state management.

**Trade-offs**:
- Requires jailbreak environment (Theos/Logos).
- May conflict with other system-level tweaks if windowLevel is not managed carefully.
- Requires careful lifecycle handling during device sleep/wake.

---

### 2. **UIWindow with Custom windowLevel (Alert + 1000)**
**Decision**: Use `UIWindowLevelAlert + 1000` for overlay window.

**Rationale**:
- `UIWindowLevelAlert` is high enough to appear above normal UI.
- Custom +1000 offset ensures overlay is above most system alerts without blocking critical system UI (e.g., emergency calls, Siri).
- Avoids accidental full-screen modal blocking.

**Performance Note**: Window creation is one-time; no repeated allocations.

---

### 3. **GPU-Accelerated Transforms via CALayer (No Layout Passes)**
**Decision**: All image manipulation (drag, pinch, scale) directly modifies `CALayer.transform` using `CATransform3D`.

**Rationale**:
- `CATransform3D` transforms are rasterized by GPU; no CPU-intensive layout recalculation.
- Achieves smooth 120 FPS on ProMotion devices with minimal CPU overhead.
- `CATransaction setDisableActions:YES` disables implicit animations, allowing direct GPU updates.
- Pinch gesture scale applied directly to layer, not re-laying out subviews.

**Implementation Detail**:
```objc
CATransform3D transform = CATransform3DMakeScale(scale, scale, 1.0);
self.overlayView.imageView.layer.transform = transform;
```

---

### 4. **Tap-Through Mode via Hit-Testing Override**
**Decision**: Override `hitTest:withEvent:` in OverlayWindow to return `nil` when tap-through is enabled and touch lands outside the image.

**Rationale**:
- Touches hitting empty space return `nil`, allowing event to pass to lower windows.
- Touches hitting image view (subview) return the image view, allowing interaction.
- No event consumption; underlying app receives the touch naturally.
- Low CPU overhead (single hit-test decision per touch).

**Code**:
```objc
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    if (self.tapThroughEnabled && view == self) {
        return nil;  // Pass through to underlying app
    }
    return view;
}
```

---

### 5. **Visibility Toggle on Outside Tap (Non-Consuming)**
**Decision**: Use `UITapGestureRecognizer` on the window with `cancelsTouchesInView = NO` and `hitTest:` returning `nil` outside image.

**Rationale**:
- Gesture recognizer detects tap outside image bounds.
- `cancelsTouchesInView = NO` ensures recognizer fires but doesn't consume the touch.
- Underlying app still receives the touch event.
- Achieves both toggle AND pass-through in a single tap.

**Requirement Satisfaction**: 
- Requirement 15: Tapping outside toggles visibility. ✓
- Requirement 16: Underlying app receives touch. ✓

---

### 6. **Persistence via NSUserDefaults + Image File**
**Decision**: Store small state (position, scale, visibility) in NSUserDefaults; store image separately (or as path reference).

**Rationale**:
- NSUserDefaults is atomic, fast, and reliable for small data.
- Position/scale/visibility are floats/bools → lightweight.
- Avoids file I/O on every frame.
- Easy to version and migrate if schema changes.

**Stored Keys**:
- `positionX`, `positionY`: CGPoint center of image.
- `scale`: CGFloat of CATransform3D scale.
- `visibility`: BOOL (hidden state).
- `tapThrough`: BOOL (mode state).

---

### 7. **Fade Animations (0.15s) via CABasicAnimation**
**Decision**: Use `CABasicAnimation` with opacity keypath for show/hide animations.

**Rationale**:
- CABasicAnimation is hardware-accelerated; runs on render thread.
- Opacity change has minimal CPU cost.
- 0.15s duration matches iOS design guidelines for quick feedback.
- `fillMode = kCAFillModeForwards` ensures final state persists.

---

### 8. **Gesture Recognizers on OverlayView**
**Decision**: Pan and Pinch recognizers attached to the image view container; outside-tap recognizer on the window.

**Rationale**:
- Pan/Pinch only active when user interacts with image area.
- Tap recognizer on window captures touches everywhere (allows toggle detection).
- Clean separation: view gestures vs. system gestures.

---

### 9. **Async Image Loading (PHPicker)**
**Decision**: Use `PHPickerViewController` (iOS 14+) with async `itemProvider.loadObjectOfClass:` to prevent main thread blocking.

**Rationale**:
- PHPickerViewController uses modern privacy-respecting Photos framework.
- `itemProvider.loadObjectOfClass:` performs decode on background thread.
- Result dispatched back to main for layer update.
- Fallback to `UIImagePickerController` for iOS < 14.

---

### 10. **Stateless Gesture Handling**
**Decision**: Each gesture update (pan/pinch) applied directly to layer; no intermediate state machine.

**Rationale**:
- Simplifies logic; reduces memory overhead.
- Gesture recognizer state machine (`began`, `changed`, `ended`) is self-contained.
- State only persisted when gesture ends (lower I/O frequency).

---

## Performance Optimizations

### CPU Minimization
- **CALayer transforms**: GPU handles matrix multiplication, no CPU recalculation.
- **Disabled implicit animations**: `CATransaction setDisableActions:YES` prevents layout passes.
- **No rasterization loops**: Avoid `layer.shouldRasterize = YES` during active gestures (would force CPU redraw each frame).
- **Gesture recognizer throttling**: Recognizers naturally throttle by event dispatch frequency (~60 Hz from input subsystem, or 120 Hz on ProMotion).

### GPU Acceleration
- **CATransform3D**: Hardware matrix transforms.
- **CABasicAnimation**: Runs on render server, not main thread.
- **UIImageView layer-backed**: Direct GPU rendering of image; no CPU bitmap copying per frame.

### Memory
- **Single image buffer**: Image decoded once, referenced in UIImageView.
- **No persistent gesture state**: Coordinates computed on-demand from layer transform.
- **Minimal UserDefaults**: ~200 bytes for state plist.

---

## Touch Event Flow

### Tap-Through Enabled, Outside Image
```
User tap
  ↓
OverlayWindow.hitTest:withEvent: returns nil
  ↓
Event passes to lower window (underlying app)
  ↓
App receives touch naturally
  ↓
Outside-tap UITapGestureRecognizer (cancelsTouchesInView=NO) fires
  ↓
toggleVisibility() called
```

### Inside Image
```
User tap/gesture
  ↓
OverlayWindow.hitTest:withEvent: returns image view
  ↓
Image view receives touch / gesture recognizer fires
  ↓
Pan/Pinch handler updates CALayer.transform
  ↓
Underlying app does NOT receive touch
```

---

## Thread Safety

- **Main thread only**: All UIView/CALayer operations bound to main thread.
- **Gesture callbacks**: Dispatched on main thread by UIKit.
- **Image loading**: Background decode, dispatched to main for layer update.
- **NSUserDefaults**: Thread-safe API; synchronize() waits for write.

---

## File Structure

```
OverlayImage/
├── Tweak.xm                    # Logos hook entry; init manager
├── OverlayManager.h/.m         # Singleton; lifecycle, persistence, gesture coordination
├── OverlayWindow.h/.m          # UIWindow subclass; hit-testing logic
├── OverlayView.h/.m            # Container view; hosts image view
├── ImagePickerController.h/.m  # PHPicker wrapper; photo library access
├── Makefile                    # Theos build config
├── Resources/Info.plist        # Photos usage description
├── Preferences/README.md       # Placeholder for Settings bundle
└── ARCHITECTURE.md             # This file
```

---

## API Usage Example

```objc
// In a settings app or tweak preference view:
OverlayManager *mgr = [OverlayManager sharedManager];

// Show image picker
[mgr presentImagePickerFromViewController:self];

// Or set image directly
UIImage *img = [UIImage imageNamed:@"..."];
[mgr setImage:img withIdentifier:nil];

// Control visibility
[mgr showOverlayAnimated:YES];
[mgr hideOverlayAnimated:YES];
[mgr toggleVisibility];

// Toggle tap-through mode
[mgr setTapThroughEnabled:YES];
BOOL enabled = [mgr isTapThroughEnabled];
```

---

## Future Enhancements

1. **Rotation support**: Rotation transform via device orientation observer.
2. **Multi-image carousel**: Swipe to switch between saved overlays.
3. **Opacity control**: Alpha slider for partially transparent overlays.
4. **Custom preset sizes**: "Full screen", "Half screen", "Small" buttons.
5. **Touch recording detection**: Monitor for ScreenRecorder process to disable overlay during recording.
6. **Inertia on gesture release**: Velocity-based deceleration for more natural drag/fling.
