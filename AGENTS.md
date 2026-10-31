# AGENTS.md

Guide for AI agents working on Trackpad Rotator, a macOS menu bar app that remaps a rotated Magic Trackpad's pointer,
scroll and swipes.

> **Rule of thumb:** when this document and the code disagree, the code wins. Copy the pattern of the closest existing
> view rather than inventing a new one.

---

## 1. Project facts

| Item             | Value |
|------------------|-------|
| Target / scheme  | `TrackpadRotator` (one app target, no test targets) |
| Platform         | macOS 14.0+ |
| Swift            | Swift 6 language mode, strict concurrency. UI state is `@MainActor @Observable`. |
| Project          | `TrackpadRotator.xcodeproj` with a synchronized `Sources` folder: new files are picked up automatically. No packages. |
| Bundle id        | `lazycatlabs.trackpadrotator` (logs use the same subsystem) |
| Localization     | English only, no String Catalog yet (see §4) |
| Commits          | Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`), one commit per change, squash-merged PRs |

## 2. Layout

```
Sources/
  App.swift          @main: MenuBarExtra (MenuBarPage) and the main window (MainPage)
  DesignSystem/      Spacing, Radius, Opacity, Metrics.<Area>
  Engine/            Event tap, multitouch (MTBridge.c/.h), HID, dock and edge swipes
  Models/            EngineConfig, AxisTransform, Rotation, DeviceTarget
  Repositories/      Settings (UserDefaults), permissions, trackpad
  ViewModels/        StatusViewModel, SettingsViewModel, UpdateChecker
  Views/             Pages, sections, items (see §4)
```

## 3. Commands

```bash
./build.sh
```

Builds and signs `build/Trackpad Rotator.app` without Xcode. Or:

```bash
xcodebuild -project TrackpadRotator.xcodeproj -scheme TrackpadRotator build
```

There are no automated tests: after a UI change, run the app and check the menu bar panel and the main window.

## 4. UI conventions

- **No magic numbers.** Use `Spacing.xxs…page`, `Radius`, `Opacity`, and a `Metrics.<Area>` entry for anything else
  (`Metrics.Pad` for the touch preview's drawing). Add a token rather than a literal; `0`, `1`, `0.5` as plain maths
  are fine.
- **User-facing strings stay in SwiftUI.** The app is English only, but SwiftUI string literals are already
  localization keys. When a view takes text as a parameter, type it `LocalizedStringKey`, not `String`, so it stays
  translatable. Adding a language means adding a String Catalog then.
- **Small `body`.** Split views as described below.
- Settings are grouped with `GroupBox` in the main window and `Divider`s in the menu bar panel. Both reuse the same
  sections, so a setting changes in one place.
- Give every control an `accessibilityIdentifier` (`area.name`, e.g. `apply.scroll`, `menuBar.enabled`), and a label
  even when it's hidden with `.labelsHidden()`.
- Respect light and dark mode: use semantic colours (`.secondary`, `.accentColor`, system tints) and check new ones in
  both.

### View naming and where a view lives

| Kind of UI                                     | Type and file suffix | Example |
|------------------------------------------------|----------------------|---------|
| A whole screen, window, sheet or panel         | `Page`               | `MainPage.swift`, `MenuBarPage.swift`, `WhatsNewPage.swift` |
| One row of a `List`, `ForEach` or grid         | `Item`               | `PermissionsSection+Item.swift`, `MainPage.DeviceItem` |
| A named block of a page                        | `Section`            | `OrientationSection.swift`, `MainPage+AboutSection.swift` |
| Loading state                                  | `Loading`            | |
| Empty state                                    | `Empty`              | `MainPage.DevicesEmpty` |

For every piece of a page the decision is the same:

- **Reusable** (used by more than one page, or plausibly will be): an `internal` struct in its own file in `Views/`.
  `OrientationSection`, `ApplySection`, `SpeedSection` and `PermissionsSection` are shared by both pages.
- **Used only by one page**: nest it, `extension MainPage { struct AboutSection: View { … } }` in
  `MainPage+AboutSection.swift`, used as `AboutSection` inside the page. A piece of a few lines can stay a `private`
  struct in the page's own file (`PadCanvas`, `SpeedSlider`, `ReleaseNotesSection`).

Shared components that aren't a page, section or item (`StatusBanner`) keep their own names.

## 5. Workflow

- Stage files by path; never `git add -A` blindly.
- Don't push unless asked.
- Releases: bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` in a `chore: release X.Y.Z`
  commit. The About section reads What's New from the GitHub release tagged `vX.Y.Z`, so the
  release notes are what users see.
