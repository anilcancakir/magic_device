<p align="center">
  <img src="https://raw.githubusercontent.com/anilcancakir/magic_device/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Device</h1>

<p align="center">
  <strong>Know when it is safe to run the heavy job.</strong><br/>
  Whether the device is on mains power, whether the viewer is away, and whether the macOS window is fullscreen. One import, no setup.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_device"><img src="https://img.shields.io/pub/v/magic_device.svg" alt="pub package"></a>
  <a href="https://github.com/anilcancakir/magic_device/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anilcancakir/magic_device/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://codecov.io/gh/anilcancakir/magic_device"><img src="https://codecov.io/gh/anilcancakir/magic_device/graph/badge.svg" alt="codecov"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic_device/score"><img src="https://img.shields.io/pub/points/magic_device" alt="pub points"></a>
</p>

<p align="center">
  <a href="https://anilcancakir.com/magic_device">Documentation</a> ·
  <a href="https://pub.dev/packages/magic_device">pub.dev</a> ·
  <a href="https://github.com/anilcancakir/magic_device/issues">Issues</a>
</p>

## At a glance

| Fact | Value |
|---|---|
| Package | [`magic_device`](https://pub.dev/packages/magic_device) |
| Install | `flutter pub add magic_device` |
| Import | `package:magic_device/magic_device.dart` |
| Entry points | `DevicePower` (mains power, viewer away), `WindowFullscreen` (macOS window state) |
| Platforms | `DevicePower` is plain Dart over `battery_plus` with no native code of its own; system-wide idle on macOS and Windows only. `WindowFullscreen` is macOS only and reports `available == false` elsewhere. |
| Requires | Dart >=3.6, Flutter >=3.27 |
| Dependencies | `battery_plus`, `flutter_inactive_timer`; `WindowFullscreen` uses the Flutter SDK only |
| License | MIT |

## Install

```bash
flutter pub add magic_device
```

`DevicePower` needs no setup. `WindowFullscreen` registers its own macOS plugin, so a macOS host needs no edit to its Runner either.

## DevicePower

Two hardware signals a background job can gate on: whether the device draws from the mains, and whether the viewer has been away long enough that the work would not disturb them.

```dart
import 'package:magic_device/magic_device.dart';

final DevicePower power = DevicePower(television: () => isTelevision);
power.start();

if (await power.charging && power.idle) {
  // Safe to run the heavy job.
}

power.stop();
```

| Signal | Meaning |
|--------|---------|
| `charging` | On mains power. `full`, `charging` and `connectedNotCharging` count; `discharging` and `unknown` do not. A platform with no battery implementation answers false. |
| `idle` | Away for at least `DevicePower.idleThreshold` (2 minutes). macOS and Windows read the system-wide last-input clock every `pollInterval` (30 seconds); every other platform reports idle whenever the app is not in front, read from the current lifecycle state at `start()` and followed from there. |

Nothing is collected until `start()`, and `stop()` forgets both answers.

### Televisions

A batteryless Android TV reports `unknown`, which would read as not charging forever. Pass a `television` predicate and `charging` answers true without asking the platform. The default is `() => false`.

### Testing

Every platform read except the app lifecycle is a constructor parameter: `batteryState`, `idleDuration`, `platform` and `television`. Drive the lifecycle through the test binding.

## WindowFullscreen

Whether the macOS window is fullscreen, and the one call that flips it. The package's macOS plugin registers the `magic_device/window` channel itself, so the host's `MainFlutterWindow.swift` stays Flutter's stock one.

```dart
import 'package:magic_device/magic_device.dart';

final WindowFullscreen fullscreen = WindowFullscreen.instance;
fullscreen.addListener(() => setState(() {}));

if (fullscreen.available) {
  await fullscreen.toggle();
}
```

| Reading | Meaning |
|---------|---------|
| `available` | True on macOS only. Everywhere else `toggle()` sends nothing, so gate the control on it. |
| `active` | Fullscreen, as the window last confirmed (AppKit's did-notification). |
| `target` | Fullscreen or on its way there: moves on the will-notification, so a layout can animate with the window. |
| `transitioning` | Between the two: the window's size changes on every frame. |

The state follows the window, not the calls: the green button, Esc and the Window menu notify listeners just as `toggle()` does, and a window that opens already fullscreen is read once on first use.

`toggle()` is ignored while a press or an animation is under way, so a double press cannot undo itself. It throws a `PlatformException` (`no_window`) when the Flutter view is not in a window, and that refusal releases the press. AppKit silently ignores the call for an app that is not frontmost; when the window posts nothing within `WindowFullscreen.pressTimeout` (1 second), the press ends and the window's state is read again.

Use the one `instance`: the channel takes one handler. A view adds and removes a listener and never disposes it. A test calls `WindowFullscreen.resetInstance()` in `tearDown`.

The `example/` app toggles the window from a button and logs each notification in order.

## For AI coding agents

Rules for an agent writing code against this package. Each one is a mistake the maintainers already made once.

| Do | Because |
|----|---------|
| Import only `package:magic_device/magic_device.dart` | Everything under `src/` is private. |
| Use `DevicePower.instance`, or build one `DevicePower(...)` when you need to inject a reader; let one component own `start()` and `stop()` | `instance` is shared and `stop()` has no reference count: it resets `idle` to false for every consumer. It already holds the process's one `Battery()`, so never construct a `Battery()` yourself: a second instance steals the first one's EventChannel subscription. |
| `await power.charging`, read `power.idle` synchronously | `charging` asks the platform; `idle` is cached after `start()`. |
| Pass `television: () => isTelevision` on Android TV | A batteryless TV reports `unknown`, which reads as not charging forever. |
| Use `WindowFullscreen.instance`, add and remove a listener, never `dispose()` it, and gate the control on `available` | The channel takes one handler, and disposing the shared instance leaves every other reader on a disposed notifier. Non-macOS platforms send nothing. |
| Call `WindowFullscreen.resetInstance()` in `tearDown`; inject the four `DevicePower` readers in tests | No mocking library is needed. |

## Dependencies

`battery_plus` for the battery state (one `Battery()` per process, held by `DevicePower`) and `flutter_inactive_timer` for the desktop idle clock, loaded through a conditional export so `dart:ffi` never reaches the web compiler. The web has no system-wide input clock. `WindowFullscreen` uses the Flutter SDK only.

## Links

- [Documentation](doc/getting-started/installation.md): installation, `DevicePower`, `WindowFullscreen` and testing
- [API reference](https://pub.dev/documentation/magic_device/latest/)
- [llms.txt](llms.txt) and the [agent skill](skills/magic-device/SKILL.md) for AI coding agents: `npx skills add anilcancakir/magic_device`
- [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/anilcancakir/magic_device/issues)
- [Security policy](SECURITY.md)

## License

MIT, see [LICENSE](LICENSE). Built by [Anılcan Çakır](https://anilcancakir.com).
