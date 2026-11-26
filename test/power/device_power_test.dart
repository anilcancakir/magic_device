import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show MagicPlatform;
import 'package:magic_device/src/power/android_television.dart';
import 'package:magic_device/src/power/device_power.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('charging', () {
    test('full, charging and connected not charging count as on mains', () {
      for (final BatteryState state in const [
        BatteryState.full,
        BatteryState.charging,
        BatteryState.connectedNotCharging,
      ]) {
        expect(DevicePower.isOnMains(state), isTrue, reason: state.name);
      }
    });

    test('discharging and unknown do not', () {
      for (final BatteryState state in const [
        BatteryState.discharging,
        BatteryState.unknown,
      ]) {
        expect(DevicePower.isOnMains(state), isFalse, reason: state.name);
      }
    });

    test('the reading goes through the injected battery source', () async {
      final DevicePower discharging = DevicePower(
        batteryState: () async => BatteryState.discharging,
      );

      expect(await discharging.charging, isFalse);
    });

    test('a television is on mains whatever the battery reports', () async {
      final DevicePower television = DevicePower(
        television: () => true,
        batteryState: () async => BatteryState.unknown,
      );

      expect(await television.charging, isTrue);
    });

    test('a platform with no television signal is not one', () async {
      final DevicePower power = DevicePower(
        batteryState: () async => BatteryState.unknown,
        platform: TargetPlatform.iOS,
      );

      expect(await power.charging, isFalse);
    });
  });

  group('television by default', () {
    const MethodChannel channel = MethodChannel('magic_device/television');
    final List<String> calls = [];
    int batteryReads = 0;

    Future<BatteryState> unknownBattery() async {
      batteryReads++;
      return BatteryState.unknown;
    }

    void answer(bool? television) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            television == null
                ? null
                : (MethodCall call) async {
                    calls.add(call.method);
                    return television;
                  },
          );
    }

    setUp(() {
      calls.clear();
      batteryReads = 0;
      resetAndroidTelevision();
    });

    tearDown(() {
      answer(null);
      resetAndroidTelevision();
    });

    test(
      'an Android television is on mains without reading the battery',
      () async {
        answer(true);
        final DevicePower power = DevicePower(
          platform: TargetPlatform.android,
          batteryState: unknownBattery,
        );

        expect(await power.charging, isTrue);
        expect(calls, ['isTelevision']);
        expect(batteryReads, 0);
      },
    );

    test('any other Android device reads the battery', () async {
      answer(false);
      final DevicePower power = DevicePower(
        platform: TargetPlatform.android,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isFalse);
      expect(calls, ['isTelevision']);
      expect(batteryReads, 1);
    });

    test('an Android without the native half reads the battery', () async {
      final DevicePower power = DevicePower(
        platform: TargetPlatform.android,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isFalse);
      expect(batteryReads, 1);
    });

    test('the channel is asked once however often charging is read', () async {
      answer(true);
      final DevicePower power = DevicePower(
        platform: TargetPlatform.android,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isTrue);
      expect(await power.charging, isTrue);
      expect(await power.charging, isTrue);
      expect(calls, ['isTelevision']);
    });

    for (final TargetPlatform platform in const [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      test('${platform.name} never asks the channel', () async {
        answer(true);
        final DevicePower power = DevicePower(
          platform: platform,
          batteryState: unknownBattery,
        );

        expect(await power.charging, isFalse);
        expect(calls, isEmpty);
        expect(batteryReads, 1);
      });
    }

    test(
      'an Apple TV is a television on mains without any native call',
      () async {
        answer(true);
        MagicPlatform.debugTvOSOverride = true;
        addTearDown(() => MagicPlatform.debugTvOSOverride = null);
        final DevicePower power = DevicePower(
          platform: TargetPlatform.iOS,
          batteryState: unknownBattery,
        );

        expect(await power.charging, isTrue);
        expect(calls, isEmpty);
        expect(batteryReads, 0);
      },
    );

    test('an injected television wins over the tvOS answer', () async {
      MagicPlatform.debugTvOSOverride = true;
      addTearDown(() => MagicPlatform.debugTvOSOverride = null);
      final DevicePower power = DevicePower(
        platform: TargetPlatform.iOS,
        television: () => false,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isFalse);
      expect(batteryReads, 1);
    });

    test('an injected television wins over the channel', () async {
      answer(true);
      final DevicePower power = DevicePower(
        platform: TargetPlatform.android,
        television: () => false,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isFalse);
      expect(calls, isEmpty);
    });

    test('an injected television may answer asynchronously', () async {
      final DevicePower power = DevicePower(
        platform: TargetPlatform.iOS,
        television: () async => true,
        batteryState: unknownBattery,
      );

      expect(await power.charging, isTrue);
      expect(batteryReads, 0);
    });
  });

  group('idle on desktop', () {
    for (final TargetPlatform platform in const [
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test('${platform.name} follows the OS idle duration', () async {
        int idleMs = 1000;
        final DevicePower power = DevicePower(
          platform: platform,
          idleDuration: () async => idleMs,
        );

        power.start();
        addTearDown(power.stop);

        await power.refreshIdle();
        expect(power.idle, isFalse);

        idleMs = DevicePower.idleThreshold.inMilliseconds;
        await power.refreshIdle();
        expect(power.idle, isTrue);

        idleMs = 1000;
        await power.refreshIdle();
        expect(power.idle, isFalse);
      });
    }
  });

  group('idle on mobile', () {
    test('idle whenever the lifecycle is not resumed', () {
      final DevicePower power = DevicePower(platform: TargetPlatform.android);

      power.start();
      addTearDown(power.stop);

      power.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(power.idle, isTrue);

      power.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(power.idle, isFalse);
    });

    test('starting while backgrounded reads idle at once', () {
      final WidgetsBinding binding = WidgetsBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      final DevicePower power = DevicePower(platform: TargetPlatform.android);

      power.start();
      addTearDown(power.stop);

      expect(power.idle, isTrue);
    });

    test('starting in front reads not idle', () {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      final DevicePower power = DevicePower(platform: TargetPlatform.iOS);

      power.start();
      addTearDown(power.stop);

      expect(power.idle, isFalse);
    });

    test('stopping forgets the last answer', () {
      final DevicePower power = DevicePower(platform: TargetPlatform.iOS);

      power.start();
      power.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(power.idle, isTrue);

      power.stop();
      expect(power.idle, isFalse);
    });
  });

  test('the FFI idle clock stays behind the conditional export', () {
    final String power = File('lib/src/power/device_power.dart')
        .readAsStringSync();
    final String gate = File('lib/src/power/os_idle.dart').readAsStringSync();

    expect(power, isNot(contains('flutter_inactive_timer')));
    expect(
      power,
      contains("import 'package:magic_device/src/power/os_idle.dart';"),
    );
    expect(
      gate,
      contains(
        "export 'os_idle_web.dart' if (dart.library.ffi) 'os_idle_native.dart';",
      ),
    );
  });

  test('the pubspec declares both packages as hosted carets', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('battery_plus: ^7.1.2'));
    expect(pubspec, contains('flutter_inactive_timer: ^4.0.0'));
  });
}
