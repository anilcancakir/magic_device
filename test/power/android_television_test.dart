import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_device/src/power/android_television.dart';

const MethodChannel _channel = MethodChannel('magic_device/television');

/// Stands in for the Android plugin: answers [television] and counts the
/// calls, or answers nothing at all when [television] is null.
void _answer(bool? television, List<String> calls) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _channel,
        television == null
            ? null
            : (MethodCall call) async {
                calls.add(call.method);
                return television;
              },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> calls = [];

  setUp(() {
    calls.clear();
    resetAndroidTelevision();
  });

  tearDown(() {
    _answer(null, calls);
    resetAndroidTelevision();
  });

  test('a television says so', () async {
    _answer(true, calls);

    expect(await isAndroidTelevision(), isTrue);
    expect(calls, ['isTelevision']);
  });

  test('anything else does not', () async {
    _answer(false, calls);

    expect(await isAndroidTelevision(), isFalse);
  });

  test('no native half answers false', () async {
    expect(await isAndroidTelevision(), isFalse);
  });

  test('the channel is asked once a read has settled', () async {
    _answer(true, calls);

    final List<bool> answers = [
      await isAndroidTelevision(),
      await isAndroidTelevision(),
      await isAndroidTelevision(),
    ];

    expect(answers, [true, true, true]);
    expect(calls, ['isTelevision']);
  });

  test('a failed read answers false and is asked again next time', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (MethodCall call) async =>
              throw PlatformException(code: 'unavailable'),
        );

    expect(await isAndroidTelevision(), isFalse);

    _answer(true, calls);

    expect(await isAndroidTelevision(), isTrue);
  });
}
