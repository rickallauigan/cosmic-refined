# Development checkpoint — 2026-10-03

## Completed and validated

- Preserved all legitimate uncommitted migration, package and helper work.
- Audited notification-local center rendering. Stock state/subscriptions, grouping,
  relative timestamps, actions, dismissal, clear-all and DND handlers remain intact;
  no new timers, polling, process, blur or animation framework.
- Confirmed installed Refined package versions through read-only pacman metadata.
  Cached center package metadata/inventory pass; its binary matches the reported
  live SHA256 435a58a6b5ceb004425d496bcd89eb403c66e4fb575c2db339408efbbdd77d3d.
- Center cargo fmt and full cargo check --locked pass offline using the host cache
  copied into a temporary writable Cargo home. Cargo.lock matches upstream.
- Updated both themes to the pinned 1.9 ThemeBuilder frosting schema. Actual
  deserialization and generation using the pinned cosmic-theme rlibs pass; the
  performance variant disables all frosting, including maximized apps.
- Host diagnostic command and isolated fixtures added; no live service/config or
  Vicinae changes. Mako remains masked. Package helpers keep normal pacman rollback
  and do not restart processes; Git configuration isolation is build-local.
- Repository tests, shell syntax, relevant ShellCheck, workflow YAML parsing and
  diff whitespace checks pass. Center/theme CI is prepared, not remotely run.

## Blocked / remaining

- The sandbox cannot connect to the user bus (Operation not permitted); direct
  live DBus/process/log and interactive history validation are not established.
- .git is mounted read-only. Branch remains feat/notification-host-test-script;
  no finalize commit, push, PR or remote CI was possible. Existing work was not
  discarded and no API workaround was used to bypass the local restriction.
- Required host review: run `bash scripts/notification-live-validate.sh --test`,
  inspect notification history and confirm grouping/expansion, dismissal, clear-all,
  DND and a real application's notification action. The helper does not supply
  notification actions itself or erase the user's history automatically.
- Notifications are not marked complete yet. App-switcher implementation,
  stock-versus-Refined measurements and release approval remain gated on it.
  Vicinae launcher/search is outside scope.

Once live evidence and writable Git access are available, organize focused commits
for notification center/package work, theme schema adaptation and validation/docs;
open the requested feature PR, review the whole diff and wait for actual CI before
merging. Do not restart/logout automatically or change the working mako mask.

The duplicate release rebuild was interrupted after an extended final compilation
without a new diagnostic, to avoid redundant resource use. No fresh release-build
success is claimed. The existing host-built release package has been independently
validated against the stock file inventory and the actual installed binary hash;
its pinned lockfile and renderer source match. This artifact was preserved.

## Latest user confirmation

Center visual validation PASSED: normal/critical history, amber accent, rounded
cards, icon/title/body hierarchy, timestamp/critical label, coexistence and
scrolling, without visible corruption/crash. Record interaction tests separately;
notify-send did not exercise application actions, DND or all dismissal/group controls.
Git is still read-only. The host publication helper creates focused commits and
a PR without automatic merging. CI and full diff review remain required.
App-switcher source research has begun without live installation or launcher changes.
