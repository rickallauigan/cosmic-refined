# Experimental high-visibility banner patch

**Compile-verified source prototype, not an installable release.** The pinned daemon
passed full formatting, `cargo check --locked` and `cargo build --locked` on a
disposable CI runner. See [build evidence](../../docs/notification-build-validation.md).
Live Wayland rendering remains unverified. The earlier local offline attempt was
blocked by missing libcosmic dependencies; CI resolved them through normal Cargo.
A binary was built only on that runner; nothing was installed, replaced or started.

Target: `pop-os/cosmic-notifications` commit
`aa4dac2702506395ab76da1f6755e03b2ccb0db8` (`epoch-1.9.0`). The patch changes only
`src/app.rs`, registers `src/refined_cards.rs` in `src/main.rs`, and adds that
notification-local policy module. It does not change Cargo dependencies, libcosmic,
COSMIC theme configuration, notification config schema, DBus protocol or compositor.

## Implemented in the optional source path

- 380 logical-pixel width across layer surface, popup limits and card layout.
- 18px drawn and Wayland surface corners, 16px inner padding, 8px content gaps.
- 32px notification/app icon using the daemon's existing lookup, with a symbolic
  fallback. The existing lookup may prefer an image hint over the app icon.
- Full wrapping summary with 18px bold title, 15px markup body, 14px app label.
- Opaque notification-local dark/light colors and contrasting borders. Contrast
  tests verify at least 7:1 text and 3:1 border against each interaction surface;
  these tests do not establish complete accessibility of rendered markup/icons.
- Fixed UTC receipt time (`HH:MM UTC`), derived from existing `Notification.time`.
  No ticking clock, timezone package or timer. Date/local-time localization remains
  future work; times alone can be ambiguous across days, especially for history.
- Critical notifications have a text label; an optional amber border supplements it.
- Each existing popup renders a distinct bordered card using native buttons instead
  of the shared animated `cards` widget. Existing 8px inter-popup offsets remain.
  No changes to urgency ordering, timeouts, limits, dismissal, activation or history.
- Automatic blur is disabled only for the opted-in daemon rendering path.

The stock renderer remains selected unless `COSMIC_REFINED_NOTIFICATION_CARDS=1`
is present **when the patched daemon starts**. Urgency coloring is independently
opt-in via `COSMIC_REFINED_NOTIFICATION_URGENCY=1`. Unknown values leave options off.
There is no environment polling or visual-config watcher added. The fixed font
sizes/380px width need accessibility and small-output testing; they are not a
complete scaling-aware design. The new fallback/critical labels are English-only.

## Review/apply to a disposable source checkout

These are developer commands, not a desktop installation workflow. Use an isolated
checkout with no unrelated changes, preserving the packaged daemon and current
session. Source control retains the original files for recovery. No root needed.

```sh
git clone https://github.com/pop-os/cosmic-notifications /tmp/cosmic-notifications-refined
cd /tmp/cosmic-notifications-refined
git checkout --detach aa4dac2702506395ab76da1f6755e03b2ccb0db8
# Use the absolute path to your COSMIC Refined checkout here:
git apply --check /path/to/cosmic-refined/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch
git apply /path/to/cosmic-refined/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch
cargo check --locked
```

Build prerequisites are the upstream Rust/native development requirements; do not
install packages blindly. This repository provides no build automation or system
installation. The full locked graph now compiles; before a release, verify in an
isolated COSMIC session: dark/light, stacked popups, missing icons, markup, long
content, font scaling, narrow outputs, dismissal, activation, DND, timeout and
history synchronization. Do not run two notification daemons in the live session.
Any later session override must separately back up the original launch configuration.
No override or persistent environment setting is created by this work.

To undo source changes, before making further edits:

```sh
git apply --reverse --check /path/to/cosmic-refined/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch
git apply --reverse /path/to/cosmic-refined/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch
```

Removing the opt-in environment variables from a future patched launch selects
stock rendering on its next start. Uninstalling a future custom binary would mean
restoring the distribution daemon and its original launch path; no such binary or
launch change exists yet.

## Tests, maintenance and license

```sh
# From COSMIC Refined; Rust compiler + rustfmt are development-only prerequisites.
bash scripts/validate.sh --notifications
```

Tests apply/reverse the patch to bundled pinned fixtures in temporary directories,
reject reapplication/source drift, check Rust formatting/syntax, and compile/run
three std-only policy tests. They do not compile the COSMIC widget integration,
start a daemon or read/write live configuration. The standalone module test binary
is temporary. No runtime dependency is added.

The patch and its added Rust module are **GPL-3.0-only**, matching the upstream daemon.
The upstream fixture sources are GPL-3.0-only too, preserving their contents and
upstream authorship; see [fixture provenance](../../tests/fixtures/README.md).
The upstream license text is retained in [LICENSE-GPL-3.0.txt](LICENSE-GPL-3.0.txt).
Other COSMIC Refined material retains its existing MPL-2.0 licensing. Revalidate the
patch against each upstream release; do not apply it by line number or use fuzzy
patching across versions. An upstream optional style API is the long-term direction.
