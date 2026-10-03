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

- Main synchronized to the merged commit; working files prepared for `feat/app-switcher`.
- Exact COSMIC launcher source pinned to `cc3d42bcc8fbcb67e6312f2766394e18b4d937d5`.
  Native frontend is resident/single-instance; metadata is event-driven. No new
  idle process or wakeups are introduced by the rendering-only proposal.
- Isolated window-mode patch, stock-inventory Arch recipe, independent rollback,
  host process/checksum snapshots and pinned CI workflow implemented.
- Full repository fixtures, source apply/reverse/drift tests, formatting, ShellCheck,
  syntax, workflow YAML and whitespace checks (including new files) pass locally.
- Local Cargo check stopped before compilation at uncached dependencies; the
  isolated makepkg attempt stopped at GitHub DNS failure. No build/package success
  is claimed. No live installation or host Alt+Tab benchmark was performed.
- Sandbox .git remains read-only for branch creation/commits. The single host
  helper `bash scripts/publish-app-switcher.sh` gates publication on an actual
  host package build, captures an idle stock snapshot, creates focused commits,
  pushes and opens a PR. It performs no installation or automatic merge.

After publication, review the full PR diff and all CI checks. Offer an explicit
package installation only after build, inventory, CI and review pass. A manual
logout/login and visual forward/reverse switching review are then required.
Next milestones remain performance measurement and polish/release. No launcher
work or extra persistent service is planned.
