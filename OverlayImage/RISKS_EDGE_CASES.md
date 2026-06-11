# OverlayImage: Risks, Edge Cases, and Mitigations

---

## Critical Risks

### 1. **Window Level Conflict with System UI**
**Risk**: If `UIWindowLevelAlert + 1000` is too high, overlay may block emergency calls, Siri, or system alerts.

**Severity**: HIGH

**Scenarios**:
- User receives emergency call; overlay blocks the interface.
- System reboot prompt hidden behind overlay.

**Mitigations**:
- Chose `UIWindowLevelAlert + 1000` (not `UIWindowLevelStatusBar` or higher).
- Monitor system events (phone state, Siri activation) and hide overlay on-demand.
- Add system preference to allow users to disable overlay during sensitive operations.
- Testing: verify overlay does not appear above emergency call UI.

**Code**:
```objc
// In future: subscribe to phone state
[[NSNotificationCenter defaultCenter] addObserver:self 
    selector:@selector(phoneStateDidChange:) 
    name:@"CTCallStateChangeNotification" 
    object:nil];

- (void)phoneStateDidChange:(NSNotification *)n {
    // Hide overlay if call active
    [self hideOverlayAnimated:YES];
}
```

---

### 2. **Memory Leak from Strong Reference Cycles**
**Risk**: Gesture recognizers or delegates holding strong references to OverlayManager could create retain cycles.

**Severity**: MEDIUM

**Scenarios**:
- Gesture recognizer block captures `self` strongly.
- Delegate callback holds strong reference.

**Mitigations**:
- Use `__weak typeof(self)` in blocks.
- Implement delegate methods as weak reference by passing `__weak` to blocks.
- Remove gesture recognizers on dealloc (if OverlayManager is ever deallocated).

**Code**:
```objc
__weak typeof(self) weakSelf = self;
[result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(...) {
    UIImage *image = ...;
    if (image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate imagePickerControllerDidSelectImage:image ...];
        });
    }
}];
```

---

### 3. **Race Condition: State Persistence During Rapid Gestures**
**Risk**: If user drags and pinches simultaneously, saveState() called multiple times in quick succession could corrupt NSUserDefaults.

**Severity**: LOW

**Scenarios**:
- User pans image while two-finger pinch; rapid state saves.
- Value written mid-gesture, then overwritten.

**Mitigations**:
- NSUserDefaults `synchronize()` is atomic; each write is serialized.
- Alternatively, batch state saves using `dispatch_queue_create()` with `DISPATCH_QUEUE_SERIAL`.
- In practice, gesture recognizer callbacks are already throttled by event loop.

**Code** (if needed):
```objc
static dispatch_queue_t _persistenceQueue = nil;

+ (dispatch_queue_t)persistenceQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _persistenceQueue = dispatch_queue_create("com.overlayimage.persistence", DISPATCH_QUEUE_SERIAL);
    });
    return _persistenceQueue;
}

- (void)saveState {
    dispatch_async(self.class.persistenceQueue, ^{
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kOverlayPrefsKey];
        // ... write defaults
        [defaults synchronize];
    });
}
```

---

### 4. **Jailbreak Compatibility Across iOS Versions**
**Risk**: Theos, Logos, or UIKit API changes across iOS 18 and future versions may break the tweak.

**Severity**: MEDIUM

**Scenarios**:
- iOS 18.1 changes UIWindow initialization.
- Future iOS deprecates Photos.framework API.
- Theos Makefile syntax changes.

**Mitigations**:
- Use iOS version checks with `@available()` macro.
- Test on multiple iOS versions (17.x, 18.x).
- Use stable APIs (UIKit, Photos.framework are rarely deprecated).
- Keep Theos/Logos up-to-date.

**Code**:
```objc
if (@available(iOS 14.0, *)) {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    // iOS 14+ code
} else {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    // iOS < 14 fallback
}
```

---

### 5. **Photos Library Permission Denial**
**Risk**: If user denies Photos access, image picker fails silently; overlay has no fallback.

**Severity**: LOW

**Scenarios**:
- User taps "Don't Allow" on Photos permission prompt.
- Overlay stays empty or shows cached image.

**Mitigations**:
- Check `PHAuthorizationStatus` before presenting picker.
- Show error toast if permission denied.
- Allow user to manually select image via file system fallback (if needed).
- Cache last-used image; show it if permission denied.

**Code**:
```objc
[PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite 
    completionHandler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
                // Show alert or use cached image
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Photos Access Denied" 
                    message:@"Please enable Photos access in Settings." 
                    preferredStyle:UIAlertControllerStyleAlert];
                [self.presentingVC presentViewController:alert animated:YES completion:nil];
            } else {
                [self presentPicker];
            }
        });
    }];
```

---

## Edge Cases

### 6. **Image Larger Than Screen**
**Edge Case**: User selects a massive image (e.g., 4000x3000 px).

**Impact**: 
- Initial decode may stall main thread briefly.
- Layer scaling could cause GPU memory pressure.

**Mitigations**:
- Decode on background thread (PHPicker does this).
- Resize/downscale image if it exceeds screen dimensions.
- Clamp scale transform to max 3.0x.

**Code**:
```objc
- (UIImage *)downscaledImage:(UIImage *)image maxSize:(CGSize)maxSize {
    if (image.size.width <= maxSize.width && image.size.height <= maxSize.height) {
        return image;
    }
    CGFloat ratio = MAX(image.size.width / maxSize.width, image.size.height / maxSize.height);
    CGSize newSize = CGSizeMake(image.size.width / ratio, image.size.height / ratio);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled;
}
```

---

### 7. **Rapid App Switching**
**Edge Case**: User switches apps very quickly (e.g., Alt-Tab style).

**Impact**: 
- Overlay may briefly lag or not restore position correctly.
- State not yet saved when app switches.

**Mitigations**:
- Subscribe to `UIApplicationDidEnterBackground` and save state immediately.
- Use atomic writes in NSUserDefaults.

**Code**:
```objc
- (instancetype)init {
    if (self = [super init]) {
        // ... setup ...
        [[NSNotificationCenter defaultCenter] addObserver:self 
            selector:@selector(appWillResignActive:) 
            name:UIApplicationWillResignActiveNotification 
            object:nil];
    }
    return self;
}

- (void)appWillResignActive:(NSNotification *)n {
    [self saveState];  // Immediate persist
}
```

---

### 8. **Device Rotation**
**Edge Case**: Device rotates; overlay positioned for portrait may be off-screen in landscape.

**Impact**: 
- Image appears at old coordinates, partially or fully off-screen.
- Aspect ratio mismatch if rotation happens during pinch.

**Mitigations**:
- Observe `UIDeviceOrientationDidChangeNotification`.
- Reposition overlay to center screen on rotation.
- Optionally lock overlay to portrait-only if rotation is too complex.

**Code**:
```objc
[[NSNotificationCenter defaultCenter] addObserver:self 
    selector:@selector(deviceDidRotate:) 
    name:UIDeviceOrientationDidChangeNotification 
    object:nil];

- (void)deviceDidRotate:(NSNotification *)n {
    CGRect newBounds = [UIScreen mainScreen].bounds;
    self.window.frame = newBounds;
    self.overlayView.frame = newBounds;
    // Re-center image
    CGSize imgSize = self.overlayView.imageView.image.size;
    // ... recalculate center ...
}
```

---

### 9. **Gesture Recognition Ambiguity**
**Edge Case**: Pinch and pan occur simultaneously; which takes precedence?

**Impact**: 
- User intends to pan but pinch also triggers; scale and position change unexpectedly.

**Mitigations**:
- Set `gestureRecognizer.delaysTouchesForPinchRecognizer = YES` on pan recognizer to delay pan until pinch is ruled out.
- This is automatic for common gesture combinations.

**Code**:
```objc
pan.delaysTouchesForPinchRecognizer = YES;  // Wait to see if pinch happens
```

---

### 10. **NSUserDefaults Suite Name Conflict**
**Edge Case**: Another tweak uses the same suite name `com.example.overlayimage`.

**Impact**: 
- Shared/corrupted preference data.
- State not persisted correctly.

**Mitigations**:
- Use a unique, descriptive suite name (include bundle ID).
- Namespace: `com.yourdev.overlayimage` instead of generic `com.example.overlayimage`.

**Code**:
```objc
static NSString * const kOverlayPrefsKey = @"com.yourdev.overlayimage.tweak";
```

---

### 11. **Low Memory Conditions**
**Edge Case**: Device runs low on memory; system kills background processes.

**Impact**: 
- OverlayManager might be deallocated unexpectedly.
- Image not saved; state lost.

**Mitigations**:
- Implement `-applicationDidReceiveMemoryWarning:` handler.
- Aggressively save state on memory warning.
- Use lightweight state representation (no heavy caching).

**Code**:
```objc
[[NSNotificationCenter defaultCenter] addObserver:self 
    selector:@selector(memoryWarning:) 
    name:UIApplicationDidReceiveMemoryWarningNotification 
    object:nil];

- (void)memoryWarning:(NSNotification *)n {
    [self saveState];
}
```

---

### 12. **Tap-Through While Image Animating**
**Edge Case**: User taps to toggle visibility while fade animation is in-flight.

**Impact**: 
- Animation may stop abruptly or flicker.
- State inconsistency (view hidden but layer opacity still animating).

**Mitigations**:
- Remove previous animations before starting new ones.
- Use `CATransaction setCompletionBlock:` to ensure state consistency.

**Code**:
```objc
- (void)hideOverlayAnimated:(BOOL)animated {
    [self.overlayView.layer removeAllAnimations];  // Clear previous animations
    
    if (animated) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            self.overlayView.hidden = YES;  // Finalize state after animation
        }];
        
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@\"opacity\"];
        fadeOut.fromValue = @(self.overlayView.layer.opacity);
        fadeOut.toValue = @0.0;
        fadeOut.duration = 0.15;
        [self.overlayView.layer addAnimation:fadeOut forKey:@\"fadeOut\"];
        
        [CATransaction commit];\n    }\n}\n```\n\n---\n\n### 13. **Corrupted NSUserDefaults Plist**\n**Edge Case**: Tweak crashes during state write; plist becomes corrupted.\n\n**Impact**: \n- State not restored on relaunch.\n- Overlay loses position, scale, image reference.\n\n**Mitigations**:\n- Wrap reads/writes in try-catch (if using custom persistence).\n- Use NSUserDefaults which handles corruption gracefully.\n- Provide \"Reset Defaults\" button in preferences.\n\n**Code**:\n```objc\n- (void)resetDefaults {\n    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kOverlayPrefsKey];\n    [defaults removePersistentDomainForName:kOverlayPrefsKey];\n    [defaults synchronize];\n    // Reload state with defaults\n    [self restoreState];\n}\n```\n\n---\n\n## Testing Recommendations\n\n1. **Permission Denial**: Test Photos access denial; verify graceful fallback.\n2. **Memory Pressure**: Simulate low-memory with iOS Simulator memory warnings.\n3. **App Switching**: Rapidly switch apps; verify overlay position and state persist.\n4. **Gesture Collision**: Perform pan + pinch + tap simultaneously; ensure no crashes.\n5. **Device Rotation**: Rotate device; overlay should reposition.\n6. **State Persistence**: Kill and relaunch app; verify saved position/scale/visibility restore.\n7. **System Alerts**: Trigger system alerts (notifications, emergency call UI); verify overlay does not block.\n8. **Long-Term Stability**: Keep overlay active for 1+ hours; monitor memory growth, CPU usage, frame rate.\n\n---\n\n## Known Limitations\n\n1. **No multi-image support**: Only one overlay at a time. Future: carousel of saved overlays.\n2. **No rotation animation**: Overlay resets position on device rotation; no smooth rotation transform.\n3. **Tap-through ambiguity on borders**: If image edge has semi-transparent pixels, hit-test may be ambiguous. Mitigation: add small margin / use `layer.shadowPath` for precise hit detection.\n4. **No keyboard interception blocking**: User can still type in apps with overlay visible. (By design; security requirement.)\n5. **No background persistence to file**: Image reference stored as path only; if photo deleted from library, overlay shows nothing. Mitigation: copy image to app cache directory.\n"