---
name: magic-device
description: "Gate background work on mains power and viewer idle, and drive macOS window fullscreen, with the magic_device package."
version: 0.0.2
when_to_use: "Use when code imports package:magic_device or needs DevicePower, WindowFullscreen, a charging or idle gate or a macOS fullscreen toggle."
---

<!-- magic_device 0.0.2 | Skill v0.0.2 (2026-11-13) -->

# magic_device

Two classes answer three device questions. `DevicePower` says whether the device is on mains power and whether the viewer is away, so a heavy background job knows when it is safe to run. `WindowFullscreen` says whether the macOS window is fullscreen and flips it. There is no service provider, config file, facade or CLI command, and the package does not depend on `magic`: construct the classes where you need them (a controller, a provider's `boot()`, a background job).

This skill covers `magic_device` only. The Magic framework itself is the `magic-framework` skill; this package needs none of it.

## Install

```bash
flutter pub add magic_device
```

Requires Dart >=3.6 and Flutter >=3.27. There is no `plugin:install` step. The macOS plugin registers the `magic_device/window` channel by itself, so the host's `MainFlutterWindow.swift` stays Flutter's stock one; do not edit it. Import only the barrel, because everything under `src/` is private:

```dart
import 'package:magic_device/magic_device.dart';
```

`BatteryState` is re-exported from the barrel, so a custom `batteryState` reader names the type without adding `battery_plus` to the app's own dependencies.

## DevicePower rules

1. Call `start()` before you read `idle`. Nothing is collected until then, `idle` stays false, and `stop()` resets it to false so a stopped instance claims no stale signal.
2. `charging` is a `Future<bool>` that asks the platform on every read; `idle` is a cached `bool`. Await the first, never await or cache the second.
3. Let one component own `start()` and `stop()`. `DevicePower.instance` is shared and `stop()` has no reference count, so one consumer stopping it closes every other consumer's idle gate.
4. `DevicePower.instance` is built with defaults and can never answer for a television. On Android TV build your own `DevicePower(television: () => isTelevision)` and hold it. The package cannot detect a television, so `isTelevision` is the host's own signal.
5. Never construct a `Battery()` beside it. `DevicePower` holds the process's one instance, and a second one steals its EventChannel subscription. To replace the battery read, pass `batteryState:`.
6. `BatteryState.unknown` is not mains: it is what a batteryless Android reports. Do not widen the rule; use `television`. `full`, `charging` and `connectedNotCharging` count (a batteryless Mac reports the last). A platform with no `battery_plus` implementation answers false.
7. State what `idle` means per platform. On macOS and Windows it is the system-wide last-input clock, polled every 30 seconds against a 2 minute threshold. Everywhere else it means the app is not in front (not `resumed`), never "no touches for two minutes".

## WindowFullscreen rules

1. Use `WindowFullscreen.instance` only. There is no public constructor, because the channel takes one handler and a second object would replace the first one's.
2. A view adds and removes a listener and never disposes the shared instance, or every other reader is left on a disposed notifier.
3. Gate every control on `available`. It is true on macOS only (never on web); elsewhere `toggle()` sends nothing.
4. Read the right state. `active` is what the window last confirmed, `target` moves on AppKit's will-notification so a layout can animate with the window, and `transitioning` covers the gap while the window size changes on every frame.
5. Expect `toggle()` to be ignored while a press or a transition is under way, so a double press cannot undo itself. It throws `PlatformException` with code `no_window` when the Flutter view is not in a window; that refusal releases the press.
6. AppKit silently ignores the call for an app that is not frontmost and posts nothing. After `pressTimeout` (1 second) the press ends and the window state is read again; treat the missing change as normal, not as an error.
7. The state follows the window, not the calls: the green button, Esc and the Window menu notify listeners exactly as `toggle()` does.

## Recipes

Gate a heavy job on mains power and an away viewer:

```dart
final DevicePower power = DevicePower(television: () => isTelevision);
power.start();

if (await power.charging && power.idle) {
  // Safe to run the job.
}

power.stop();
```

A fullscreen button that follows the window. `ListenableBuilder` adds and removes the listener itself:

```dart
if (WindowFullscreen.instance.available)
  ListenableBuilder(
    listenable: WindowFullscreen.instance,
    builder: (BuildContext context, Widget? child) => IconButton(
      icon: Icon(
        WindowFullscreen.instance.active
            ? Icons.fullscreen_exit
            : Icons.fullscreen,
      ),
      onPressed: WindowFullscreen.instance.toggle,
    ),
  ),
```

## Testing

No mocking library is needed. Every `DevicePower` platform read is a constructor parameter except the app lifecycle, which you drive through the test binding:

```dart
final DevicePower power = DevicePower(
  batteryState: () async => BatteryState.discharging,
  idleDuration: () async => const Duration(minutes: 5).inMilliseconds,
  platform: TargetPlatform.macOS,
);

power.start();
await power.refreshIdle(); // @visibleForTesting: drive the poll without waiting

expect(await power.charging, isFalse);
expect(power.idle, isTrue);

power.stop();
```

For `WindowFullscreen`, set `debugDefaultTargetPlatformOverride = TargetPlatform.macOS`, stand a fake window on the `magic_device/window` channel through `TestDefaultBinaryMessengerBinding`, and call `WindowFullscreen.resetInstance()` in `tearDown` so the next test does not inherit the handler and state.
