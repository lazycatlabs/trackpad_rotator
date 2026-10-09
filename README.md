# Trackpad Rotator

A macOS menu bar app that lets you use a Magic Trackpad turned 90°, 180° or 270°. Pointer movement and two-finger scrolling follow your fingers instead of the trackpad's hardware axes.

Landing page: `~/Workspace/Web/trackpadrotator.lazycatlabs`.

## Build & install

```bash
./build.sh
cp -R "build/Trackpad Rotator.app" /Applications/
```

`build.sh` compiles with `swiftc` (no Xcode project needed). It signs with the first "Apple Development: Mudassir" identity, so macOS privacy permissions survive rebuilds; set `SIGN_IDENTITY` to override. It also renders the icon if `Resources/AppIcon.icns` is missing.

On first launch, grant:

- **Accessibility**: to move the pointer and rewrite scroll events
- **Input Monitoring**: to read finger data from the trackpad

The **Permissions** section (in the menu bar panel and the settings window) shows whether each one is granted and has a **Request** button. macOS only shows each prompt once, so after that the button opens the right pane in System Settings.

## How it works

The UI is SwiftUI with MVVM: **Views → ViewModels → Repositories → Engine**. Views never call the engine or system APIs directly.

- `Sources/Models/EngineConfig.swift`: `AxisTransform` (rotation + swap/invert) and the `EngineConfig` value type.
- `Sources/Repositories/`:
  - `SettingsRepository`: persists settings in UserDefaults, handles launch at login, and publishes the config snapshot the engine reads on every event.
  - `PermissionsRepository`: Accessibility and Input Monitoring checks, prompts and System Settings links.
  - `TrackpadRepository`: the UI's entry point into the engine (devices, live touches, event tap).
- `Sources/ViewModels/`: `StatusViewModel` (permissions, tap and devices, polled every 2 s) and `SettingsViewModel` (editable settings).
- `Sources/Views/`: the menu bar panel, the Touch Preview & Settings window and shared controls. Swipe between pages, the Notification Center swipe and the three/four-finger swipes can each be turned off there.
- `Sources/Engine/`:
  - `MTBridge.c`: loads Apple's private `MultitouchSupport.framework` with `dlopen` and streams raw finger frames.
  - `TouchMonitor.swift`: tracks which device is touched and the centroid travel of the fingers (mm).
  - `EventTap.swift`:
    - **Pointer** (HID-level tap): direction comes from finger travel turned by the orientation; distance comes from macOS's own delta × the pointer speed. While the trackpad is touched, the cursor is detached from the hardware (`CGAssociateMouseAndMouseCursorPosition`) and placed with `CGWarpMouseCursorPosition`.
    - **Scroll** (session-level tap): the same direction approach, with momentum keeping the last direction and Natural scrolling respected.
    - **Swipe between pages**: AppKit decides on more than the scroll deltas, so the tap also turns the undocumented raw deltas, the companion gesture events, the `IOHIDEvent` attached to each event (via private SkyLight/IOKit calls) and the finger positions in the touch events.
    - **Notification Center** (`EdgeSwipe.swift`): macOS looks for its edge swipe on the pad's own right edge, so the app recognises "two fingers left from your right edge" itself, opens Notification Center through its accessibility action and drops that scroll.
    - **Three- and four-finger swipes** (`DockSwipe.swift`, HID-level tap): macOS recognises them on the pad's own axes and sends the Dock a "dock swipe" event with an axis and a progress. The tap turns those (and the attached `IOHIDEvent`, which is what the Dock acts on) into your frame. What each swipe does is still decided by System Settings → Trackpad → More Gestures.
  - `HIDEvent.swift`: reads and rewrites the `IOHIDEvent` attached to a `CGEvent`.

Diagnostics are logged under the `local.trackpadrotator` subsystem:

```bash
/usr/bin/log show --last 5m --predicate 'subsystem == "local.trackpadrotator"'
```

(Use the full path in zsh, where `log` is a shell builtin.) A per-gesture scroll summary is logged at debug level; add `--debug` to see it.

## Limitations

- Pinch and rotate aren't touched; they don't depend on orientation.
- macOS still opens Notification Center from the pad's own right edge, wherever that edge now is.
- It relies on private frameworks and undocumented event fields, which may change in future macOS releases. If they do, swipe between pages and the three/four-finger swipes are the first things to stop working.

## Icon

```bash
./Scripts/make-icon.sh   # writes Resources/AppIcon.icns and Resources/AppIcon-1024.png
```
