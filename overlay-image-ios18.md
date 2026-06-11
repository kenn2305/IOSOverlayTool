# Overlay Image Tool For Jailbroken iOS 18

## Goal

Create a system-wide overlay image tool for iOS 18 jailbroken devices.

The overlay must remain visible above all applications.

## Core Features

### Image Selection

User can select an image from Photos Library.

When selected:

* Image displays immediately.
* Original aspect ratio preserved.
* No border.
* No shadow.
* Transparent background.

### Image Manipulation

User can:

* Drag image anywhere on screen.
* Scale image up/down using pinch gesture.
* Maintain smooth 60/120 FPS interaction.
* Position persists between sessions.

### Overlay Rendering

Overlay must:

* Stay above all applications.
* Use UIWindow.
* Use UIWindowLevelAlert + custom priority.
* Remain visible during app switching.

### Tap Through Mode

When enabled:

If touch occurs outside image bounds:

* Pass touch directly to underlying application.

If touch occurs inside image bounds:

* Overlay receives touch.

### Visibility Toggle

Special mode:

When Tap Through Mode is enabled:

Touch outside image:

* Toggle image visibility.

Behavior:

Visible -> Hidden

Hidden -> Visible

Underlying application still receives touch event.

### Persistence

Store:

* Position
* Scale
* Selected image path
* Visibility state

Using:

NSUserDefaults

### Performance Requirements

Target:

* 120 FPS on ProMotion devices
* No dropped frames
* GPU accelerated transforms
* No continuous layout recalculation

Use:

* CALayer transforms
* CATransaction disabled animations where appropriate

### Animation Requirements

Show Animation:

* Fade In
* Duration 0.15s

Hide Animation:

* Fade Out
* Duration 0.15s

Drag:

* No animation delay

Scale:

* Realtime

### Safety

Tool must never:

* Inject code into target apps.
* Modify application memory.
* Intercept keyboard input.
* Record screen contents.

Only render overlay window.
