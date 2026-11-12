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
import 'package:magic_device/magic_device.dart';

final DevicePower power = DevicePower(television: () => isTelevision);
power.start();

if (await power.charging && power.idle) {
  // Safe to run the heavy job.
}

power.stop();
```

Nothing is collected until `start()`: an instance that never starts holds no channel, no timer and no lifecycle observer.

<a name="quick-reference"></a>
## Quick Reference

| Member | Type | Meaning |
|:-------|:-----|:--------|
| `DevicePower({batteryState, idleDuration, platform, television})` | constructor | Every platform read is injectable. Omitted readers use `battery_plus`, the OS idle clock and `defaultTargetPlatform`; `television` defaults to `() => false`. |
| `DevicePower.instance` | `static final DevicePower` | Shared instance built with every default, so it can never answer for a television. |
| `charging` | `Future<bool>` | On mains power. Asks the platform on every read. |
| `idle` | `bool` | Away for at least `idleThreshold`. A cached flag: read it without awaiting. |
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

<a name="idle"></a>
## Idle

`power.idle` is `true` once the viewer has been away for `idleThreshold` (2 minutes). How it is measured depends on the platform.

| Platform | Source |
|:---------|:-------|
| Native macOS and Windows | The system-wide last-input clock, read once at `start()` and then every `pollInterval` (30 seconds). Neither OS notifies "the user came back", so a poll is the only shape. |
| Every other platform, web included | The app lifecycle: idle whenever the state is not `resumed`. There is no system-wide input clock to read, so on a phone idle means "the app is not in front", never "no touches for two minutes". |

<a name="televisions"></a>
## Televisions

A batteryless Android TV reports `unknown`, which would read as not charging forever and keep the gate closed on a box that never runs on anything else. Pass a `television` predicate and `charging` answers `true` without asking the platform.

```dart
final DevicePower power = DevicePower(television: () => isTelevision);
```

The package cannot detect a television, so `isTelevision` is the host's own signal. `DevicePower.instance` takes no arguments and therefore cannot answer for a television: build and hold your own instance on those builds.

<a name="lifecycle"></a>
## Lifecycle

- `start()` is idempotent, and `stop()` resets `idle` to `false` so a stopped instance claims no stale signal.
- Let one component own `start()` and `stop()` of a shared instance. `stop()` has no reference count, so one consumer stopping `DevicePower.instance` closes every other consumer's idle gate.
- Outside macOS and Windows, `start()` attaches a lifecycle observer and needs Flutter's binding: call it from the main isolate, not from a background isolate.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Reading `idle` before `start()` | It stays `false` until `start()`. |
| Awaiting `idle` or caching `charging` | `charging` is a `Future` that asks the platform each read; `idle` is a cached `bool`. |
| Constructing a `Battery()` beside `DevicePower` | `DevicePower` holds the process's one instance, and a second one steals its EventChannel subscription. Pass `batteryState:` to replace the read. |
| Treating `BatteryState.unknown` as mains | Pass `television` instead of widening the rule. |
| Using `DevicePower.instance` on a television build | Build your own `DevicePower(television: ...)`. |
| Calling `stop()` from a second consumer | Keep one owner for `start()` and `stop()`. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): requirements and platform support.
- [WindowFullscreen](./window-fullscreen.md): the macOS window state.
- [Testing](../guides/testing.md): driving the readers and the lifecycle in tests.
