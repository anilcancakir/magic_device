# Magic Device Plugin

Device signals for Flutter apps and the Magic Framework: mains power and viewer-away (`DevicePower`, Dart only) and the macOS window fullscreen state (`WindowFullscreen`, backed by this package's own macOS plugin, `MagicDevicePlugin`).

**Version:** 0.0.2 · **Dart:** >=3.6.0 · **Flutter:** >=3.27.0

## Commands

| Command | Description |
|---------|-------------|
| `flutter test --coverage` | Run all tests with coverage |
| `flutter analyze --no-fatal-infos` | Static analysis |
| `dart format .` | Format all code |
| `flutter pub publish --dry-run` | Pre-publish check |
| `python3 tool/check-docs.py` | Docs structure, links, fragments and ToC anchors; run it after any `doc/` change |

## Architecture

```
lib/
├── magic_device.dart     # Barrel export, the only public API
└── src/
    └── power/            # DevicePower: mains power and viewer-away signals
        ├── device_power.dart
        ├── os_idle.dart          # Conditional export: web arm, or the FFI arm when dart:ffi exists
        ├── os_idle_native.dart   # flutter_inactive_timer (macOS and Windows)
        └── os_idle_web.dart      # Throws: the web has no system-wide input clock
    └── window/           # WindowFullscreen: macOS window fullscreen state and toggle
        └── window_fullscreen.dart  # One shared instance over the `magic_device/window` channel

macos/                    # The macOS plugin, WindowFullscreen's native half
├── magic_device.podspec  # CocoaPods
└── magic_device/
    ├── Package.swift     # Swift Package Manager
    └── Sources/magic_device/MagicDevicePlugin.swift  # Finds the window holding the Flutter view on each call

example/                  # macOS app: toggles the window and logs each notification
doc/                      # User docs, published by the docs site: getting-started/, basics/, guides/
skills/magic-device/      # Agent skill, installed with `npx skills add anilcancakir/magic_device`
tool/check-docs.py        # Offline docs gate, run by docs-link-check.yml
```

## Post-Change Checklist

After ANY source code change, sync **before committing**. A change is not done while one of these is stale:

1. **`CHANGELOG.md`**: Add entry under `[Unreleased]` section
2. **`README.md`, `llms.txt` and the `doc/` pages (when present)**: Update if features, API, or usage changes
3. **`skills/magic-device/SKILL.md`**: Update when the API, a rule or a gotcha changes; its `version:` moves with the release, and the publish check compares it with the tag
4. **`CLAUDE.md`**: Update the architecture tree when files move

## Development Flow (TDD)

Every feature, fix, or refactor must go through the red-green-refactor cycle:

1. **Red**: Write a failing test that describes the expected behavior
2. **Green**: Write the minimum code to make the test pass
3. **Refactor**: Clean up while keeping tests green

**Rules:**
- No production code without a failing test first
- Run `flutter test` after every change: all tests must stay green
- Run `dart analyze` after every change: zero warnings, zero errors
- Run `dart format .` before committing: zero formatting issues

## Testing

- Inject every platform read through the `DevicePower` constructor (`batteryState`, `idleDuration`, `platform`, `television`); no mocking library
- `WindowFullscreen` tests stand a fake window on `magic_device/window` through `TestDefaultBinaryMessengerBinding`, and call `WindowFullscreen.resetInstance()` in `tearDown`
- Tests mirror `lib/src/` structure in `test/`
- Import from `package:magic_device/src/...` in tests, not the barrel

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Reaching into `battery_plus` to fake the battery read | Pass `batteryState:` to the constructor; `Battery()` is a singleton in battery_plus 7 and `DevicePower` holds it |
| Importing `flutter_inactive_timer` from `device_power.dart` | Go through `os_idle.dart`, so `dart:ffi` never reaches the web compiler |
| Treating `unknown` as mains | A batteryless Android reports `unknown`; the host passes `television` to answer true on a box that never runs on a battery |
| Referencing an app type in the package | The `television` predicate is the seam; the default is `() => false` |
| A second `WindowFullscreen` object | Use `WindowFullscreen.instance`: the channel takes one handler, and a second object would replace the first one's |
| Editing the host's `MainFlutterWindow.swift` for fullscreen | Not needed: `MagicDevicePlugin` finds the window holding the Flutter view on each call |
| Relative paths in `pubspec_overrides.yaml` | Use ABSOLUTE ones; the file is never committed |

## Release

1. Open a `release:` PR that bumps `pubspec.yaml`, `macos/magic_device.podspec`, `skills/magic-device/SKILL.md` and the `Version:` line above, and promotes `[Unreleased]` in `CHANGELOG.md`.
2. After it merges, tag the merge commit with the bare version (`git tag 0.0.3 && git push origin 0.0.3`, no `v`). `publish.yml` runs from the tag; the pub.dev Admin tab holds repository `anilcancakir/magic_device`, tag pattern `{{version}}` and push events only.
3. A failed `validate` is fixed forward: delete the tag (`git push --delete origin <tag>` and `git tag -d <tag>`), fix it on a PR and tag the new merge commit, because a re-run builds the same commit. If only `github-release` fails after pub.dev accepted the version, use "Re-run failed jobs" (never "Re-run all jobs", where `publish` is rejected as a duplicate) or run `gh release create <tag> --title <tag> --latest --verify-tag --notes-file <file>`.

The first publish (0.0.1) was a manual `flutter pub publish`, since tag-triggered OIDC cannot create a package.

## CI

- `ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage` → codecov upload
- `changelog.yml`: a PR that changes `lib/` or `macos/` must also change `CHANGELOG.md`; Dependabot, `release:` PRs and the `skip-changelog` label are exempt
- `docs-link-check.yml`: every PR runs `python3 tool/check-docs.py` and an offline lychee pass; Mondays an external-link pass
- `publish.yml`: tag on master → version stamps (tag, pubspec, podspec, skill) → analyze, format, test, dry-run, pana 160/160, changelog section → OIDC publish → GitHub Release
