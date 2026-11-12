# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.2] - 2026-11-13

### Changed
- **The repository moved to `anilcancakir/magic_device`.** `homepage`, `documentation`, `repository` and `issue_tracker` in `pubspec.yaml` point at the new owner, and the LICENSE holder is now Anılcan Çakır. The package name, the API and the version line are unchanged.
- **The default branch is `master`**, protected: a pull request and a green `Lint & Test` are required, force pushes and deletion are blocked.
- **The publish workflow validates more and releases itself.** It runs `flutter pub publish --dry-run` and requires a matching CHANGELOG section before publishing, then creates the GitHub Release from that section once pub.dev accepts the tag. Every action is pinned by commit SHA and the workflows run with read-only permissions by default.

- **The release workflow checks its own inputs.** The tag, `pubspec.yaml` and the podspec must name one version, and the package must score the full 160 points on pana before anything is published.
- **Every change keeps the docs in step.** The post-change checklist in `CLAUDE.md` and the pull request template now require the changelog, README, `llms.txt`, `doc/` pages and the agent skill to match the change.
- **The package is no longer marked alpha.** The README banner and the SECURITY note are gone; the version line continues as `0.0.x`.

### Added
- `SECURITY.md`, issue forms for bugs and feature requests, and a pull request template.
- `llms.txt`: the package for an AI coding agent, with setup, the API, platform support and the rules an agent must follow.
- `skills/magic-device`: an agent skill for the package, installed with `npx skills add anilcancakir/magic_device`. It stays out of the pub.dev archive.
- The README opens with the Magic logo (`.github/magic-logo.svg`) and the centered header every Magic package uses.

## [0.0.1] - 2026-10-29

### Added
- **`DevicePower`**: whether the device is on mains power (`charging`) and whether the viewer is away (`idle`). Desktop idle polls the OS last-input clock; mobile idle follows the app lifecycle, seeded from the current lifecycle state at `start()` so an app started in the background reads idle at once. `television` is an injectable predicate that defaults to `() => false`.
- **`WindowFullscreen`**: whether the macOS window is fullscreen (`active`), where it is going (`target`, moved by AppKit's will-notification) and whether it is animating (`transitioning`), with `toggle()` to flip it. A press that the window never answers (AppKit ignores the call for an app that is not frontmost) ends after `pressTimeout` and re-reads the window, so it cannot hold every later toggle. One shared `instance`; listeners hear each change, whether it came from `toggle()`, the window's green button, Esc or the Window menu. `available` is true on macOS only. The native half is a macOS plugin (`MagicDevicePlugin`, channel `magic_device/window`) that finds the window holding the Flutter view on each call, so the host's Runner needs no edit.
- **`BatteryState` is exported from the barrel.** `DevicePower`'s `batteryState` reader returns it, so a host that supplies its own reader names the type without adding `battery_plus` as a direct dependency.
