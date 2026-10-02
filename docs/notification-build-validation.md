# Pinned notification patch build verification

**Patch fully compiles and is ready for controlled live testing.** This means the
source compilation prerequisite is met, not that live rendering is tested or that
installation has been authorized. No installed daemon, live session or user COSMIC
configuration was changed. Notification-center improvements remain documentation-only.

## Evidence and reproduction

[Passing CI run](https://github.com/rickallauigan/cosmic-refined/actions/runs/36972471074)
validated commit `907709d3794ddca8d341487049a4adebb52d9ad0` on 2026-10-02:

| Check | Result |
| --- | --- |
| Exact upstream source and both bundled fixture comparisons | Pass |
| Patch application | Pass |
| `cargo +1.93.0 fmt --all -- --check` | Pass |
| `cargo +1.93.0 check --locked` | Pass (1m 54s) |
| `cargo +1.93.0 build --locked` | Pass (3m 07s) |

No patch-caused compiler errors were found and no patch changes were needed. Three
warnings point to unchanged upstream code: unused `Message::Surface`, and hidden
elided lifetimes in `view` and `view_window`. They were inspected rather than
suppressed or fixed as unrelated refactoring.

The build used official daemon release `epoch-1.9.0`, commit
`aa4dac2702506395ab76da1f6755e03b2ccb0db8`, and its original `Cargo.lock` without
updates. The release tag's annotated Git object resolves to that commit, and the
source package declares version 1.9.0. The installed Arch extra package was confirmed
as `cosmic-notifications 1:1.9.0-1`; panel and applets also report `1:1.9.0-1`.
This verifies the matching upstream release, not a byte-for-byte reproduction of
Arch's distribution binary or proof of the absence of downstream packaging changes.

Key locked dependencies:

- libcosmic: `d921602cde8248c070b493ce43b0edd388e19b9a`.
- cosmic-panel: `15ba731b0850e5733a1f3bb51d5d48d58e6ce35b`.
- cosmic-protocols: `c0cff4db14c37ed954983158e4055aa94c7741d9`.

The upstream lockfile contains 598 registry packages and 12 distinct Git sources;
Cargo fetches the subset needed by the enabled target/features normally. CI logs
record the downloads and Git sources (including the pinned COSMIC winit, clipboard,
softbuffer, accesskit and supporting crates). No dependency was vendored into COSMIC
Refined or added to its runtime requirements.

The runner was Ubuntu 24.04, using upstream Rust 1.93.0 and its rustfmt. xkbcommon/
Wayland development headers and pkg-config were installed only on that disposable
runner. Cargo cache, upstream checkout and build outputs were placed in runner
`RUNNER_TEMP`, outside COSMIC Refined. The local toolchain is Rust 1.98.1; local
compilation was blocked by a read-only default Cargo cache and unavailable GitHub
DNS from the temporary cache environment. CI compilation does not substitute for
runtime testing on this machine's compositor/GPU.

The workflow can be dispatched manually or reruns for PR source-patch, fixture or
workflow changes. Documentation-only edits do not require another full build.
Use the commands in the [patch instructions](../notifications/patches/README.md)
with the exact source and original lockfile to reproduce the compilation.

## API and behavior review

- Urgency: existing `Notification::urgency()` maps critical to `2`. Only critical
  notifications receive the textual label; only critical plus explicit
  `COSMIC_REFINED_NOTIFICATION_URGENCY=1` receives the accent. Normal notifications
  keep a neutral border. No animation is added.
- Arrival time: existing `Notification.time: SystemTime` provides the receipt time.
  Static `HH:MM UTC` remains for now. Relative `now`/`2m` could be derived on rendering
  with `duration_since`, but without refresh events long-lived critical banners would
  show stale ages. A timer to keep ages current would add wakeups; no such timer is
  justified here. Local absolute time, localization and date handling remain UX work.
- Rendering: native iced `Button::Custom`, `Style`, `Border`, icon/text sizing and
  font APIs compile against the locked libcosmic stack. The outer card owns its
  opaque dark/light palette; no shared theme surfaces are modified.
- Geometry: 380px width is applied to layer size, popup limits and card layout; 18px
  radius is applied to both drawn borders and Wayland corner hints, including popup
  size updates. Long content, font scaling and narrow displays still need live checks.
- Opt-in: environment flags are read once at daemon initialization, requiring literal
  `1`. Without the card opt-in the existing stock path, geometry and automatic blur
  behavior remain. No schema keys, configuration writes or watchers are added.

## Expected performance and limits

There is no extra daemon/process, periodic timestamp task, polling script, animation
framework or external blur. The optional path avoids shared card expansion animation
and disables automatic blur for these daemon surfaces.

380px is about 27% wider than the stock 300px card. Larger text/padding can also
increase height, so visible rasterization/composition work may rise; no FPS or power
saving is claimed. 32px icons cover four times the area of 16px icons, although the
existing image lookup still controls source decoding. Rounded corners and borders
add edge rendering, but no work that should run continuously while idle. Opaque
surfaces remove wallpaper-dependent contrast and blur requirements; opacity does
not by itself guarantee lower GPU usage. Idle CPU/GPU and active rendering costs
must be measured during controlled testing.

Remaining checks: dark/light appearance, multiple popups, missing icons, markup,
long content, scaling/accessibility, dismissal/activation, DND/timeouts/history,
actual Intel Iris Xe rendering and idle behavior. Keep the packaged daemon as the
live default until a separately authorized test. No installation or restart script
is provided by this verification.
