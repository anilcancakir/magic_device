---
name: magic-device
description: "Gate background work on mains power and viewer idle, and drive macOS window fullscreen, with the magic_device package."
version: 1.0.0
when_to_use: "Use when code imports package:magic_device or needs DevicePower, WindowFullscreen, a charging or away check, or a macOS fullscreen toggle."
---

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

1. Call `start()` before you read `idle`. Nothing is collected until then, `idle` stays false, and `stop()` resets it to false so a stopped instance claims no stale signal. Outside native macOS and Windows `start()` attaches a lifecycle observer, so call it from the main isolate once Flutter's binding exists, not from a background isolate.
2. `charging` is a `Future<bool>` that asks the platform on every read; `idle` is a cached `bool`. Await the first, never await or cache the second.
3. Let one component own `start()` and `stop()`. `DevicePower.instance` is shared and `stop()` has no reference count, so one consumer stopping it closes every other consumer's idle gate.
4. `DevicePower.instance` is built with defaults and can never answer for a television. On Android TV build your own `DevicePower(television: () => isTelevision)` and hold it. The package cannot detect a television, so `isTelevision` is the host's own signal.
5. To fake or replace the battery read, pass `batteryState:` instead of calling `Battery()` yourself; `DevicePower` already holds it.
6. `BatteryState.unknown` is not mains: it is what a batteryless Android reports. Do not widen the rule; use `television`. `full`, `charging` and `connectedNotCharging` count (a batteryless Mac reports the last). A platform with no `battery_plus` implementation answers false.
7. State what `idle` means per platform. On native macOS and Windows it is the system-wide last-input clock, read at `start()` and then every `DevicePower.pollInterval` (30 seconds) against `DevicePower.idleThreshold` (2 minutes). Everywhere else, web included, it means the app is not in front (any state but `resumed`, so `inactive` counts), immediately and with no threshold, never "no touches for two minutes".

## WindowFullscreen rules

1. Use `WindowFullscreen.instance` only. There is no public constructor, because the channel takes one handler and a second object would replace the first one's. The first use reads the window once, so a window that opens already fullscreen is picked up.
2. A view adds and removes a listener and never disposes the shared instance, or every other reader is left on a disposed notifier.
3. Gate every control on `available`. It is true on macOS only (never on web); elsewhere `toggle()` sends nothing.
4. Read the right state. `active` is what the window last confirmed, `target` moves on AppKit's will-notification (the did-notification settles it with `active`) so a layout can animate with the window, and `transitioning` covers the gap while the window size changes on every frame.
5. Expect `toggle()` to be ignored while a press or a transition is under way, so a double press cannot undo itself. Catch the `PlatformException` with code `no_window` where a user can trigger it.
6. Treat a `toggle()` that changes nothing as normal, not as an error: AppKit ignores the call for an app that is not frontmost.
7. The state follows the window, not the calls: the green button, Esc and the Window menu notify listeners exactly as `toggle()` does.

## Recipes

Gate a heavy job on mains power and an away viewer:

```dart
import 'package:magic_device/magic_device.dart';

// isTelevision is the host's own detection.
Future<bool> safeToRunJob({required bool isTelevision}) async {
  final DevicePower power = DevicePower(television: () => isTelevision);
  power.start();

  try {
    return await power.charging && power.idle;
  } finally {
    power.stop();
  }
}
```

A fullscreen button that follows the window. `ListenableBuilder` adds and removes the listener itself, and the handler catches the one refusal a user can cause:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException
import 'package:magic_device/magic_device.dart';

Widget fullscreenButton() {
  if (!WindowFullscreen.instance.available) return const SizedBox.shrink();

  return ListenableBuilder(
    listenable: WindowFullscreen.instance,
    builder: (BuildContext context, Widget? child) => IconButton(
      icon: Icon(
        WindowFullscreen.instance.active
            ? Icons.fullscreen_exit
            : Icons.fullscreen,
      ),
      onPressed: () async {
        try {
          await WindowFullscreen.instance.toggle();
        } on PlatformException catch (error) {
          if (error.code != 'no_window') rethrow;
        }
      },
    ),
  );
}
```

## Testing

No mocking library is needed. Every `DevicePower` platform read is a constructor parameter except the app lifecycle. `idleDuration` returns milliseconds:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_device/magic_device.dart';

void main() {
  test('a discharging device with an away viewer', () async {
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
  });
}
```

For the lifecycle path (any platform but native macOS and Windows), call `TestWidgetsFlutterBinding.ensureInitialized()` and then `binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)`.

For `WindowFullscreen`, set `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` in `setUp` and stand a fake window on the `magic_device/window` channel through `TestDefaultBinaryMessengerBinding`, because the first use of `instance` on macOS reads the window over that channel. In `tearDown` call `WindowFullscreen.resetInstance()` first, then clear the mock handler, then set the override back to null; the other order leaves the channel handler installed. Inside `testWidgets` end the body with `resetInstance()` and `debugDefaultTargetPlatformOverride = null` instead, because the binding checks the override before `tearDown` runs.
