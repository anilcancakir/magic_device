import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Answered by the package's Android plugin from `UiModeManager`.
const MethodChannel _channel = MethodChannel('magic_device/television');

/// The process's one settled answer. Only a settled value is kept, never the
/// pending call: a call that never replies (a `testWidgets` body, whose
/// `FakeAsync` zone swallows the platform reply) would otherwise stay stored
/// and hang every later read in the isolate.
bool? _answer;

/// Whether this Android device is a television, as `UiModeManager` reports
/// its UI mode type.
///
/// Asked until it settles, then once per process: the form factor cannot
/// change while the app runs. A process with no Android plugin behind the
/// channel (a host that stripped the native half) answers false and keeps it.
/// A `PlatformException` answers false for that read only, so a later read
/// asks again; the television signal is best effort, and a device that cannot
/// answer is gated by its battery like any other.
Future<bool> isAndroidTelevision() async {
  final bool? settled = _answer;
  if (settled != null) return settled;

  try {
    return _answer = await _channel.invokeMethod<bool>('isTelevision') ?? false;
  } on MissingPluginException {
    return _answer = false;
  } on PlatformException {
    return false;
  }
}

/// Forgets the stored answer, so the next [isAndroidTelevision] asks again.
@visibleForTesting
void resetAndroidTelevision() => _answer = null;
