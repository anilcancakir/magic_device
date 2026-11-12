# Installation

Add `magic_device` to a Flutter app, check that it answers, and know what it does not need.

- [Install](#install)
- [Requirements](#requirements)
- [What You Do Not Need](#what-you-do-not-need)
- [Verify](#verify)
- [Platforms](#platforms)
- [Related Documentation](#related-documentation)

<a name="install"></a>
## Install

```bash
flutter pub add magic_device
```

```dart
import 'package:magic_device/magic_device.dart';
```

The barrel is the only import; everything under `src/` is private. `BatteryState` is re-exported from it, so a custom `batteryState` reader names the type without adding `battery_plus` to the app's own dependencies.

<a name="requirements"></a>
## Requirements

| Requirement | Value |
|:------------|:------|
| Dart | `>=3.6.0` |
| Flutter | `>=3.27.0` |
| Dependencies | `battery_plus` and `flutter_inactive_timer`, pulled in automatically; `WindowFullscreen` uses the Flutter SDK only |
| Flutter binding | Outside macOS and Windows, `DevicePower.start()` attaches a lifecycle observer, so call it from the main isolate once Flutter's binding exists |

<a name="what-you-do-not-need"></a>
## What You Do Not Need

- No service provider, config file, facade or CLI command, and no dependency on `magic`. Construct the classes where you need them: a controller, a provider's `boot()` or a background job.
- No `plugin:install` step.
- No Runner edit. The package's macOS plugin registers the `magic_device/window` channel itself, so the host's `MainFlutterWindow.swift` stays Flutter's stock one.

<a name="verify"></a>
## Verify

```dart
import 'package:flutter/widgets.dart';
import 'package:magic_device/magic_device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final DevicePower power = DevicePower()..start();
  debugPrint('on mains: ${await power.charging}, away: ${power.idle}');
  power.stop();

  debugPrint('fullscreen available: ${WindowFullscreen.instance.available}');
}
```

On a laptop on battery this prints `on mains: false`. `fullscreen available` is `true` on macOS and `false` everywhere else.

<a name="platforms"></a>
## Platforms

| Signal | Source |
|:-------|:-------|
| `DevicePower.charging` | `battery_plus`. A platform with no implementation answers `false`, and a web browser without `navigator.getBattery` reports `unknown`, which also reads as `false`. |
| `DevicePower.idle` on native macOS and Windows | The system-wide last-input clock. |
| `DevicePower.idle` everywhere else, web included | The app lifecycle: idle whenever the app is not in front. |
| `WindowFullscreen` | macOS only. `available` is `false` elsewhere and `toggle()` sends nothing. |

<a name="related-documentation"></a>
## Related Documentation

- [DevicePower](../basics/device-power.md): mains power and viewer idle.
- [WindowFullscreen](../basics/window-fullscreen.md): the macOS window state and its toggle.
- [Testing](../guides/testing.md): injecting every platform read.
