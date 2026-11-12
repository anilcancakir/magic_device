# Testing

Test code that depends on `DevicePower` and `WindowFullscreen` without a device, a plugin or a mocking library.

- [DevicePower](#devicepower)
- [Lifecycle](#lifecycle)
- [WindowFullscreen](#windowfullscreen)
- [Related Documentation](#related-documentation)

<a name="devicepower"></a>
## DevicePower

Every platform read is a constructor parameter, so a test needs no plugin. `idleDuration` returns milliseconds.

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

`BatteryState` comes from `package:magic_device/magic_device.dart`, so the test does not need `battery_plus` as a direct dependency.

<a name="lifecycle"></a>
## Lifecycle

The app lifecycle is the one read that cannot be injected. On every platform but macOS and Windows, drive it through the test binding:

```dart
final TestWidgetsFlutterBinding binding =
    TestWidgetsFlutterBinding.ensureInitialized();
final DevicePower power = DevicePower(platform: TargetPlatform.android)..start();

binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
expect(power.idle, isTrue);

binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
expect(power.idle, isFalse);

power.stop();
```

<a name="windowfullscreen"></a>
## WindowFullscreen

Set the platform override, stand a fake window on the `magic_device/window` channel, and undo all three in `tearDown` in this order:

```dart
const MethodChannel channel = MethodChannel('magic_device/window');

setUp(() {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method == 'isFullScreen') return false;
    return null; // toggleFullScreen
  });
});

tearDown(() {
  WindowFullscreen.resetInstance();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
  debugDefaultTargetPlatformOverride = null;
});
```

Reset the instance first, then clear the mock handler, then the override. Resetting the override first leaves the channel handler installed, and inside `testWidgets` an override that is never reset fails the binding's invariant check.

To play the window's side, deliver the notification the plugin would post:

```dart
await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .handlePlatformMessage(
  channel.name,
  const StandardMethodCodec().encodeMethodCall(
    const MethodCall('willEnterFullScreen'),
  ),
  (ByteData? _) {},
);
```

The four notifications are `willEnterFullScreen`, `didEnterFullScreen`, `willExitFullScreen` and `didExitFullScreen`.

<a name="related-documentation"></a>
## Related Documentation

- [DevicePower](../basics/device-power.md): the signals the readers replace.
- [WindowFullscreen](../basics/window-fullscreen.md): the state the notifications drive.
