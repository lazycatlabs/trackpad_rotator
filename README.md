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

## How it works

- `MTBridge.c`: loads Apple's private `MultitouchSupport.framework` with `dlopen` and streams raw finger frames.
- `TouchMonitor.swift`: tracks which device is touched and the centroid travel of the fingers (mm).
- `EventTap.swift`:
  - **Pointer** (HID-level tap): direction comes from finger travel turned by the orientation; distance comes from macOS's own delta × the pointer speed. While the trackpad is touched, the cursor is detached from the hardware (`CGAssociateMouseAndMouseCursorPosition`) and placed with `CGWarpMouseCursorPosition`.
  - **Scroll** (session-level tap): the same direction approach, with momentum keeping the last direction and Natural scrolling respected.
- `Settings.swift`: `AxisTransform` (rotation + swap/invert) and persisted settings.
- `Views.swift`: the menu bar panel and the Touch Preview & Settings window.

Diagnostics are logged under the `local.trackpadrotator` subsystem:

```bash
log show --last 5m --predicate 'subsystem == "local.trackpadrotator"'
```

## Limitations

- System gestures (Mission Control and Spaces swipes, pinch, rotate) are handled by macOS and are not remapped.
- It relies on a private framework, which may change in future macOS releases.

## Icon

```bash
./Scripts/make-icon.sh   # writes Resources/AppIcon.icns and Resources/AppIcon-1024.png
```
