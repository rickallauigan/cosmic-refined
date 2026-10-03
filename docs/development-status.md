# Development checkpoint — 2026-10-03

## Notifications milestone

PR #2 is merged into main at `dda24527e078d7e765b084016a2412610d7f387d`.
The user confirmed Refined banners and center visuals on COSMIC 1.9, including
normal/critical cards, spacing, hierarchy, timestamp, coexistence and scrolling.
Native grouping/state/actions/DND/relative-time handlers are preserved in source.
Detailed real-app activation and every interaction were not separately live-proven;
these remain follow-up checks, not a gate on beginning the switcher milestone.
Notification packages, theme configuration, Vicinae and the mako mask are untouched.

The earlier center build checkpoint remains historical: locked check and theme
schema deserialization passed using a temporary writable Cargo cache; the existing
host-built release package matched the live binary. A duplicate release rebuild
was interrupted, not counted as a fresh successful build. Subsequently published
CI and the merged PR supersede the earlier publication blocker.

## Current app/window switcher work

- PR #3 is published on `feat/app-switcher`, based on the merged main.
  Reviewed build head: `dd14bcc48f9c2732cc227e3b5f206978a22e1380`.
- Exact COSMIC launcher source pinned to `cc3d42bcc8fbcb67e6312f2766394e18b4d937d5`.
  Native frontend is resident/single-instance; metadata is event-driven. No new
  idle process or wakeups are introduced by the rendering-only proposal.
- Isolated window-mode patch, stock-inventory Arch recipe, independent rollback,
  host process/checksum snapshots and pinned CI workflow implemented.
- Full repository fixtures, source apply/reverse/drift tests, formatting, ShellCheck,
  syntax, workflow YAML and whitespace checks (including new files) pass locally.
- Earlier sandbox check/makepkg failures were network/cache prerequisites, not
  compiler failures. A real host Arch build passed; its source, unchanged lock,
  package metadata and stock payload inventory were independently verified.
- Native switcher CI run `37092505177` passed formatting, locked check/release
  build, lockfile preservation and real package staging. Notification center CI
  run `37092505208` also passed, including theme-schema validation.
- Final diff audit found no source/package blocker. Search mode, native selection,
  reverse switching, Alt-release activation, metadata/subscriptions and window
  ordering remain intact. No new process, periodic work or global Git config
  change. No notification/Vicinae/mako behavior changed.
- Sandbox .git is read-only during this review; the documentation correction
  needs a host commit/push. No live installation or session change was performed.

PR #3 remains open and unmerged. Merge requires explicit user authorization and
passing checks on the final published head. After approval, controlled live
switcher validation still needs a manual login and visual forward/reverse review.
Host idle snapshot capture is recorded by the publication helper; open-overlay
and comparative performance measurements remain pending. Next milestones remain
performance measurement and polish/release; no launcher work or extra service.
