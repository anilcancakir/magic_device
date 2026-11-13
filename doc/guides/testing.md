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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_device/magic_device.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  test('idle follows the app lifecycle', () {
    final DevicePower power = DevicePower(platform: TargetPlatform.android)
      ..start();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(power.idle, isTrue);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(power.idle, isFalse);

    power.stop();
  });
}
```

<a name="windowfullscreen"></a>
## WindowFullscreen

On macOS the first use of `WindowFullscreen.instance` asks the window for its state over the `magic_device/window` channel, so any test that reaches it under a macOS override needs a fake window on that channel. Set the override and the fake in `setUp`, and undo both in `tearDown` in this order:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_device/magic_device.dart';

const MethodChannel channel = MethodChannel('magic_device/window');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('the will-notification moves target ahead of active', () async {
    final WindowFullscreen window = WindowFullscreen.instance;
    await Future<void>.delayed(Duration.zero); // let the first read settle

    // Deliver the notification the plugin would post.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('willEnterFullScreen'),
      ),
      (ByteData? _) {},
    );

    expect(
      (window.active, window.target, window.transitioning),
      (false, true, true),
    );
  });
}
```

Reset the instance first, then clear the mock handler, then the override. Resetting the override first leaves the channel handler installed, because the reader only clears its handler while `available` is true.

That `tearDown` order is for plain `test()`. Inside `testWidgets` the binding checks that every foundation debug variable is unset at the end of the test body, before `tearDown` runs, so with the override set in `setUp` end the body with `WindowFullscreen.resetInstance();` and `debugDefaultTargetPlatformOverride = null;`. If you use `variant: TargetPlatformVariant.only(TargetPlatform.macOS)` instead, leave the override out of `setUp` (the variant sets it and clears it before `tearDown`) and still end the body with `WindowFullscreen.resetInstance();`, so the reader drops its channel handler while the platform is macOS.

The four notifications the plugin posts are `willEnterFullScreen`, `didEnterFullScreen`, `willExitFullScreen` and `didExitFullScreen`.

<a name="related-documentation"></a>
## Related Documentation

- [DevicePower](../basics/device-power.md): the signals the readers replace.
- [WindowFullscreen](../basics/window-fullscreen.md): the state the notifications drive.
