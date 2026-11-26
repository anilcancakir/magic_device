# DevicePower

Know whether the device is on mains power and whether the viewer is away, so a heavy background job runs only when nobody will notice.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Charging](#charging)
- [Idle](#idle)
- [Televisions](#televisions)
- [Lifecycle](#lifecycle)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:magic_device/magic_device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final DevicePower power = DevicePower.instance;
  power.start();

  if (await power.charging && power.idle) {
    // Safe to run the heavy job.
  }

  power.stop();
}
```

Nothing is collected until `start()`: an instance that never starts holds no channel, no timer and no lifecycle observer.

<a name="quick-reference"></a>
## Quick Reference

| Member | Type | Meaning |
|:-------|:-----|:--------|
| `DevicePower({batteryState, idleDuration, platform, television})` | constructor | Every platform read is injectable. Omitted readers use `battery_plus`, the OS idle clock and `defaultTargetPlatform`; `television` defaults to the package's Android check on Android, to `true` on tvOS and to `false` everywhere else. |
| `DevicePower.instance` | `static final DevicePower` | Shared instance built with every default, so on Android it answers for a television. |
| `charging` | `Future<bool>` | On mains power. Asks the platform on every read. |
| `idle` | `bool` | Away. On native macOS and Windows: no input for `idleThreshold`. Everywhere else: any app lifecycle state but `resumed`, immediately, with no threshold. A cached flag: read it without awaiting. |
| `start()` | `void` | Begins collecting. Idempotent. |
| `stop()` | `void` | Stops collecting and resets `idle` to `false`. |
| `idleThreshold` | `static const Duration` | 2 minutes. |
| `pollInterval` | `static const Duration` | 30 seconds, the desktop poll. |

<a name="charging"></a>
## Charging

`await power.charging` answers whether the device draws from the mains.

| Battery state | Counts as mains |
|:--------------|:----------------|
| `full`, `charging`, `connectedNotCharging` | Yes. A Mac without a battery reports `connectedNotCharging`. |
| `discharging`, `unknown` | No. A batteryless Android reports `unknown`. |
| A platform with no `battery_plus` implementation | No. The read answers `false` instead of throwing. |
| A web browser without `navigator.getBattery` | No. `battery_plus` reports `unknown`. |

Only a missing plugin is turned into `false`. Any other error from `battery_plus` propagates from `charging`, so catch it where you await.

<a name="idle"></a>
## Idle

`power.idle` is `true` while the viewer is away. How that is measured depends on the platform, and only native macOS and Windows have a threshold.

| Platform | Source |
|:---------|:-------|
| Native macOS and Windows | The system-wide last-input clock: idle after `idleThreshold` (2 minutes) without input, read once at `start()` and then every `pollInterval` (30 seconds). Neither OS notifies "the user came back", so a poll is the only shape. |
| Every other platform, web included | The app lifecycle: idle whenever the state is not `resumed` (`inactive`, `hidden` and `paused` all count), with no threshold. There is no system-wide input clock to read, so on a phone idle means "the app is not in front", never "no touches for two minutes". |

The desktop poll is not guarded: if the OS idle read throws, the error surfaces as an uncaught async error.

<a name="televisions"></a>
## Televisions

A batteryless Android TV reports `unknown`, which would read as not charging forever and keep the gate closed on a box that never runs on anything else. On a television `charging` answers `true` without reading the battery.

| Platform | Default `television` answer |
|:---------|:----------------------------|
| Android | The package's Android plugin: `UiModeManager.currentModeType` is `UI_MODE_TYPE_TELEVISION`. Asked over the `magic_device/television` channel; a settled answer is reused for the isolate, since the form factor cannot change, though reads that start before the first reply may each ask. With no plugin behind the channel it settles on `false`; a `PlatformException`, or no Flutter binding yet, answers `false` for that read only and a later read asks again. |
| tvOS | `true`, without opening a channel. flutter-tvos reports an Apple TV as iOS, so the check goes through `MagicPlatform.isTvOS` from `magic` before the platform is read. |
| iOS, macOS, Linux, Windows, web | `false`, without opening a channel. |

`DevicePower.instance` uses that default, so it answers for an Android TV with no setup and no host code, provided the system reports the television UI mode (`UI_MODE_TYPE_TELEVISION`). A device that advertises the `leanback` feature but keeps another UI mode answers `false`, and `charging` falls back to the battery state, which a batteryless box reports as `unknown`: pass `television` for such a device. Pass `television` to use another signal, or to fix the answer in a test; an injected predicate replaces the default, and it may answer synchronously or with a `Future`.

```dart
import 'package:magic_device/magic_device.dart';

// Your own signal, here a --dart-define=KIOSK=true build flavour.
const bool isKiosk = bool.fromEnvironment('KIOSK');

void main() {
  final DevicePower power = DevicePower(television: () => isKiosk);
  power.start();
}
```

<a name="lifecycle"></a>
## Lifecycle

- `start()` is idempotent, and `stop()` resets `idle` to `false` so a stopped instance claims no stale signal.
- Let one component own `start()` and `stop()` of a shared instance. `stop()` has no reference count, so one consumer stopping `DevicePower.instance` closes every other consumer's idle gate.
- Outside native macOS and Windows, `start()` attaches a lifecycle observer and needs Flutter's binding: call it from the main isolate, not from a background isolate.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Reading `idle` before `start()` | It stays `false` until `start()`. |
| Awaiting `idle` or caching `charging` | `charging` is a `Future` that asks the platform each read; `idle` is a cached `bool`. |
| Reaching into `battery_plus` yourself to fake the read | Pass `batteryState:` to the constructor. |
| Expecting a grace period on a phone or on the web | `idle` flips as soon as the app leaves `resumed`: a control-centre pull or a window blur (`inactive`) counts. |
| Treating `BatteryState.unknown` as mains | An Android TV already answers through the default `television`; for any other box that never runs on a battery, pass `television` instead of widening the rule. |
| Carrying your own Android TV detector into `television` | Not needed: the default asks `UiModeManager` on Android. |
| Calling `stop()` from a second consumer | Keep one owner for `start()` and `stop()`. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): requirements and platform support.
- [WindowFullscreen](./window-fullscreen.md): the macOS window state.
- [Testing](../guides/testing.md): driving the readers and the lifecycle in tests.
