# Refined notification center: experimental

Popup banners are **live verified by the ThinkPad user**: wider cards, rounded
corners, larger icon/title/body, static timestamp, critical amber border and neutral
normal cards work without observed crashes or clipping. Screenshots have not yet
been supplied. Center visuals passed user review on the real COSMIC 1.9 session. Interaction review is recorded separately below.

## Exact source and boundaries

Arch `cosmic-applets 1:1.9.0-1` uses upstream `epoch-1.9.0`, annotated tag object
`40f3fab4140ffd764541df6b1e3e815f2c0217a9`, commit
`82e7cd814addb0641959b634227fe550374e195b`. The Git archive BLAKE2 checksum matches
Arch's recipe. See the retained [official recipe](../packaging/arch/notification-center/arch-upstream.PKGBUILD).
Its prepare step fetches locked dependencies and substitutes fat LTO with thin LTO;
the pinned source already specifies thin LTO. It applies no downstream source patch.
Arch links with mold; our recipe uses already-available lld and equivalent direct
Cargo/install commands instead of just. This is not a byte-identical distro build.

Renderer: `cosmic-applet-notifications/src/lib.rs::view_window` (upstream lines
385–537). Shared `libcosmic/src/widget/cards.rs` constructs stock stacked cards;
libcosmic is pinned at `03c8f93b294ad239ea935f6dd3c14a15acde8d0d` in Cargo.lock.
Our separate GPL-3.0-only patch replaces only that applet's rendering call with
`src/refined_center.rs::group`; it does not change shared libcosmic styles.

The upstream update handler groups by `app_name`, replaces matching IDs and appends
new notifications. Groups and contents render in reverse order. The patch leaves
that state/update logic unchanged. Collapsed groups show the newest notification
and the existing localized remaining count; clicking the card expands the group.
Expanded groups retain collapse/clear-group controls and newest-first cards.
Per-notification close controls still send `Dismissed`; expanded/single cards still
send `ActivateNotification`. That existing handler selects the default action, or
the first supplied action, and sends it over the original notification channel.
This patch does not add separate action buttons that stock history did not have.
Clear-all, DND configuration/watchers, notification subscriptions, activation tokens,
scrolling and history synchronization remain unchanged.

## Design comparison

| Detail | Verified banner | Experimental center |
| --- | --- | --- |
| Surface | Opaque, local high contrast | Matching local dark/light and hover/pressed colors |
| Corners / icon | 18px / 32px | 18px / 32px (expanded group control icon 24px) |
| Title / body | Bold 18px / 15px | Bold 18px / 15px, original markup conversion |
| Width | 380px | Up to 380px within native popup constraints |
| Spacing | Separate popup cards | 16px between groups, 8px within expanded groups, 16px padding |
| Timestamp | Static UTC receipt time | Original localized relative time |
| Critical cue | Amber border + “Critical notification” | Same amber family + compact “Critical” caption |

The critical caption uses Fluent's English fallback and can be translated without
new dependencies. It is a visible text cue, so urgency is not conveyed by color alone;
this does not claim new screen-reader support. Normal cards have a neutral border.
The working banner label is deliberately unchanged during center experimentation.

`duration_ago_msg` remains byte-for-byte unchanged: notification `duration_since()`
is converted into localized minutes/hours, including “Just now”. It refreshes when
existing applet events redraw/reopen the view, not on a new periodic clock. No UTC
replacement, polling, timers, processes, blur or animation framework is added.
The local group renderer changes expansion immediately rather than copying the
shared widget's animated stack. It keeps grouping, but does not draw decorative
collapsed back-card slivers.

Larger glyphs/icons and visible cards increase draw area and allocations while the
popup is open. Opaque surfaces avoid additional blur; there is no new idle workload.
Power/CPU/GPU impact has not been measured. Validate hover/keyboard interaction,
close buttons nested in cards, long text, scrolling and all grouping actions live.

## Package scope and independent rollback

`/usr/bin/cosmic-applet-notifications` is owned by cosmic-applets and is a symlink to
`/usr/bin/cosmic-applets`. The shared executable dispatches by argv[0], so a full
package rebuild is necessary with this distribution's unsplit ownership. A separate
`cosmic-applets-refined` package provides `cosmic-applets=1:1.9.0` and conflicts with
stock. It retains the full stock file inventory and existing status-notifier
services/network policy; it adds no service, autostart or environment file.
Only notification applet source is modified; other applets are rebuilt unchanged.
No cosmic-panel/session package, configuration or Vicinae files are changed.

Build without installation:

```sh
bash scripts/notification-center-package-test.sh build
bash scripts/notification-center-package-test.sh status
```

The host helper is ready for manual execution; this is not a claim that the center
has compiled or passed live visual review. `build` verifies stock or already-installed Refined applets at `1:1.9.0-1` and ownership of both the multicall binary and notification symlink.
It stages everything under `/tmp/cosmic-refined-center-package.XXXXXXXX/` and prints
the resulting archive path, package SHA256 and applet SHA256 after inventory checks.
The expected filename is `cosmic-applets-refined-1:1.9.0-1-x86_64.pkg.tar.zst`.

Normal Cargo network access is enabled for the build, with
`CARGO_NET_GIT_FETCH_WITH_CLI=true` and `CARGO_NET_OFFLINE=false`. Only the build
subprocess ignores global/system Git configuration and inherited command-line Git
configuration (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`,
`GIT_CONFIG_COUNT=0`). This prevents the user's HTTPS-to-SSH GitHub rewrite from
breaking public dependency fetches. No Git config file is edited; the parent
terminal keeps its configuration. Global credential helpers/proxies are also
ignored during this public-source build. Source commit and checksums remain pinned.

Build tools must already be available; the helper never installs dependencies.
The pinned Cargo.lock stays unchanged. Package construction must pass formatting,
locked check/build and exact installed-file inventory validation. Until these finish
successfully, do not install the experimental package. After successful validation,
explicit host installation takes a package path and requires typing INSTALL:

```sh
bash scripts/notification-center-package-test.sh install /tmp/BUILD/cosmic-applets-refined-1:1.9.0-1-x86_64.pkg.tar.zst
```

The helper prints rollback first and uses normal interactive pacman safeguards.
No automatic restart or logout occurs; manually log out/in when ready. Official
package upgrades should be restored before changing COSMIC versions.

Online rollback (verify the repository offers a compatible COSMIC stack first):

```sh
sudo pacman -S extra/cosmic-applets
```

The inspected cache contains the stock archive and detached signature at these
paths; they are not readable in Codex, so the cached contents/signature have not
been verified here. Root pacman performs normal signature verification:

```sh
sudo pacman -U '/var/cache/pacman/pkg/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst'
```

Or use `bash scripts/notification-center-package-test.sh restore-stock` and type
RESTORE. Center rollback leaves `cosmic-notifications-refined` installed and banners
unchanged. Save the stock archive AND `.sig` somewhere durable before installation;
the package cache is not a guaranteed backup and may be cleaned.

If COSMIC is unhealthy, switch to a TTY with Ctrl+Alt+F3, sign in normally and run
one of those rollback commands. Then start a fresh graphical login yourself. No
working graphical terminal, session environment override or process-killing helper
is needed. Keep package-manager signature checks enabled.

## Validation checkpoint

On 2026-10-02, exact source/tag and Arch source archive checksum were verified.
`cargo fmt --all -- --check` passed. Offline `cargo check --locked -p
cosmic-applet-notifications` and `cargo build --locked` stop during dependency
resolution: `xdgen` is absent from the crates.io cache. Online Cargo attempts fail
DNS in the sandbox. Exact Git dependencies were fetched into temporary build
caches; Cargo.lock was not changed. `makepkg --cleanbuild --holdver --noconfirm` verified source and patch checksums,
then stopped in prepare at the same missing dependency. No compiler diagnostics
were reached, so API
compatibility and full package build remain unverified. Do not install this center
until the locked build succeeds on a network-capable host.

Patch apply/reverse, touched-source drift rejection, Rust formatting, unchanged
state/subscription/relative-time function comparisons, mocked helper transactions
and strict package inventory fixtures pass. A staged packaging-layout check using
the actual upstream data and a placeholder executable matches the full official
file inventory; that is not a compiled package. Existing project validation passes.
No center package artifact or patched executable checksum can be reported yet.

The checkout's `.git` is read-only in this environment. The requested
`feat/notification-center` branch creation failed; no commit or push was possible.
Existing uncommitted helper/packaging work was retained. Resume by creating that
branch in a writable host checkout, resolving the locked dependency downloads,
rerunning validation/build and committing/pushing without merging.

## 2026-10-03 host evidence and audit

The user reports both Refined packages installed, applet running and COSMIC owning
`org.freedesktop.Notifications` after masking mako. Read-only pacman inspection
confirms package versions 1:1.9.0-1. `/usr/bin/cosmic-applets` checksum is
`435a58a6b5ceb004425d496bcd89eb403c66e4fb575c2db339408efbbdd77d3d`.
The cached package in a host `/tmp/cosmic-refined-center-package.<id>/` workspace passes strict
metadata/inventory checks and contains that same binary. Its Cargo.lock matches
upstream exactly, and notification renderer source matches this patch. This
supersedes the earlier lack of a built artifact. User reports are distinct from
independent live verification: sandbox bus access returns Operation not permitted.

The renderer audit found no new subscriptions, timers, services or perpetual
redraws. It retains the existing action/dismissal/state handlers. It still builds
elements for collapsed history before rendering only the newest, following the
stock allocation pattern; a speculative allocation refactor was avoided. Native
nested-button dismissal and all history interactions still need visual validation.
The working banner patch and packages have not been replaced. See
[session conflict evidence and host validation](notification-session-conflicts.md).

Notifications are not declared complete until grouped history, clear-all, DND,
dismissal and application actions are confirmed on the host. App-switcher work
remains gated on that confirmation. Git publication is also blocked by the
read-only .git mount; no commit/PR/CI result is claimed.

Offline `cargo fmt --all -- --check` and full-workspace `cargo check --locked`
passed on 2026-10-03 after copying the host cache to a writable temporary Cargo
home. Only existing upstream warnings were emitted. Both adapted theme RON files
were deserialized and built against the exact pinned cosmic-theme release model;
the generated performance theme disables all frosting. No live config was changed.

A fresh duplicate release rebuild was started offline, then interrupted after an
extended final compilation with no new diagnostic. Do not confuse the successful
locked check and validated existing release package with a completed fresh rebuild.
The existing host-built artifact remains intact; no package installation occurred.

## Live visual review passed

The user confirms normal and critical history cards, amber treatment, rounded
corners, icon/title/body hierarchy, visible timestamps/critical label, coexistence,
scrolling and no visual crash/layout corruption. Test commands were `notify-send
"COSMIC Refined" "Normal notification test"` and the equivalent critical-urgency
notification. Screenshots are not required to accept that user confirmation.

The user reported a UTC timestamp. The pinned center source still uses localized
relative timestamps; banners use UTC. We preserve the reported visual observation
without claiming the center renderer implements UTC. No timestamp code is changed.
Grouping counts/expansion, dismissal, clear-all, DND and real application activation
remain source/fixture verified; these specific live interactions were not explicitly
confirmed by the two notify-send tests. No session restart is needed for this review.
