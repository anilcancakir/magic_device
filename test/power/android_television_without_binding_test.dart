import 'package:flutter_test/flutter_test.dart';
import 'package:magic_device/src/power/android_television.dart';

/// No `TestWidgetsFlutterBinding` is created in this file, which is the state
/// of a plain `test()` that builds a `DevicePower` and never touches one.
void main() {
  test('answers false instead of throwing when no binding exists', () async {
    expect(await isAndroidTelevision(), isFalse);
  });
}
