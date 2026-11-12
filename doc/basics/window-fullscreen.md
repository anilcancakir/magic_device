# WindowFullscreen

Know whether the macOS window is fullscreen, follow it as it changes, and flip it with one call.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Reading the State](#reading-the-state)
- [Toggling](#toggling)
- [Following the Window](#following-the-window)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

A fullscreen button that follows the window. `ListenableBuilder` adds and removes the listener itself, and the handler catches the one refusal a user can cause.

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

<a name="quick-reference"></a>
## Quick Reference

| Member | Type | Meaning |
|:-------|:-----|:--------|
| `WindowFullscreen.instance` | `static WindowFullscreen` | The app's one reader, made on first use. On macOS the first use reads the window once, so a window that opens already fullscreen is picked up. |
| `available` | `bool` | `true` on macOS only (never on web). Gate the control on it. |
| `active` | `bool` | Fullscreen, as the window last confirmed (AppKit's did-notification). |
| `target` | `bool` | Fullscreen or on its way there. Moves on the will-notification, ahead of `active`. |
| `transitioning` | `bool` | Between the will- and the did-notification. |
| `toggle()` | `Future<void>` | Asks the window to enter or leave fullscreen. |
| `pressTimeout` | `static const Duration` | 1 second. |
| `resetInstance()` | `static void` | Test-only: drops the shared reader. |

<a name="reading-the-state"></a>
## Reading the State

One state, two readings. `target` is where the window is going, and `active` is what it confirmed. `transitioning` covers the gap.

| Moment | `active` | `target` | `transitioning` |
|:-------|:---------|:---------|:----------------|
| Windowed | `false` | `false` | `false` |
| Entering, animation under way | `false` | `true` | `true` |
| Fullscreen | `true` | `true` | `false` |
| Leaving, animation under way | `true` | `false` | `true` |

Follow `target` to animate a layout with the window, and `active` for what the window really is. During `transitioning` the window's size changes on every frame, so hold off size-sensitive work.

<a name="toggling"></a>
## Toggling

`toggle()` is a request, not a guarantee.

- It is ignored while a press or a transition is under way, so a double press cannot undo itself.
- It throws a `PlatformException` with code `no_window` when the Flutter view is not in a window. That refusal releases the press, so catch it where a user can trigger it.
- AppKit silently ignores the call for an app that is not frontmost and posts nothing. One second (`pressTimeout`) after the call returns, the window is read again and that reading ends the press. Treat a missing change as normal, not as an error.
- Anywhere but macOS, `toggle()` sends nothing.

<a name="following-the-window"></a>
## Following the Window

The state follows the window, not the calls. The plugin forwards the will- and did-notifications for every change, so the green button, Esc and the Window menu notify listeners exactly as `toggle()` does, and listeners hear only real changes.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Building a second `WindowFullscreen` | There is no public constructor: the channel takes one handler. Use `instance`. |
| Disposing the shared instance from a view | A view adds and removes a listener and never disposes it, or every other reader is left on a disposed notifier. |
| Showing a fullscreen control everywhere | Gate it on `available`. |
| Animating the layout off `active` | `active` changes only once the window lands. Follow `target`. |
| Editing `MainFlutterWindow.swift` to add a channel | Not needed: the package's macOS plugin registers `magic_device/window` and finds the window on each call. |

<a name="related-documentation"></a>
## Related Documentation

- [Installation](../getting-started/installation.md): requirements and platform support.
- [DevicePower](./device-power.md): mains power and viewer idle.
- [Testing](../guides/testing.md): a fake window on the channel.
