# Refined native app/window switcher

Vicinae owns launcher/search. Refined changes only COSMIC's existing window-mode
presentation; it adds no launcher, keyboard binding, daemon or session override.
This milestone is experimental: pinned compilation and package-inventory CI
pass. Controlled live visual and performance validation remain pending; no
switcher package has been installed.

## Pinned architecture

Installed Arch package: `cosmic-launcher 1:1.9.0-1`, owner of
`/usr/bin/cosmic-launcher`. Upstream `epoch-1.9.0` resolves to
[`cc3d42bcc8fbcb67e6312f2766394e18b4d937d5`](https://github.com/pop-os/cosmic-launcher/tree/cc3d42bcc8fbcb67e6312f2766394e18b4d937d5).
Arch recipe commit `d95e9a4657f8935ed435ee28746ebc038eb88cb5` packages that tag
and applies a thin-LTO profile patch. Copies of its recipe and patch accompany
our packaging. That historical patch applies with fuzz 2 to this release;
our rendering patch applies strictly, without fuzz. Cargo.lock stays unchanged
(SHA256 `f1210ef400d242444e9da5ce32b0e40bc5c33b4dac5fc91aeff1e43e82bf88f9`).

- `src/app.rs`: `LauncherTasks`, `dbus_activation`, `view_window`, surface
  placement, forward/reverse selection and Alt-release activation.
- `src/subscriptions/launcher.rs`: asynchronous requests/responses to the
  existing pop-launcher IPC service, lazily initialized on a request.
- Locked pop-os/launcher revision `6390080a98a4a59b4e8196d28de97d3cb4d138ec`,
  `plugins/src/cosmic_toplevel/mod.rs`: app ID, title, desktop icon and native
  window handle; one result per toplevel. Its `toplevel_handler.rs` listens to
  Wayland/calloop events, blocking in `dispatch(None, ...)`, and activates through
  the COSMIC toplevel-management protocol. No new enumeration or polling is needed.
- Native settings-daemon actions `WindowSwitcher` and `WindowSwitcherPrevious`
  invoke `cosmic-launcher alt-tab` and `cosmic-launcher shift-alt-tab` respectively.

The frontend uses `run_single_instance` and `exit_on_close(false)`: it remains
resident after the overlay is dismissed. It is **not** a short-lived process.
Repeated invocations use native D-Bus activation. Refined preserves this lifecycle
rather than introducing another resident component. Backend child lifetime must
be measured on the host; it is not inferred from frontend residency.

Native selection is window-oriented, not macOS app grouping. We retain the entire
native result list, its ordering, any backend fallback entries, focus wrapping,
workspace behavior, activation, context actions and the Alt-release race handling.
No changes are made to Input/search handling or the original search renderer.

## First-version rendering boundary

The separate GPL-3.0-only patch is
`switcher/patches/cosmic-launcher-1.9.0-refined-switcher.patch`.
Only `src/app.rs` changes. An early `self.alt_tab` branch renders an opaque
18px-rounded dark/light card with 48px icons, readable app names, a bold selected
window title, and a thick accent outline to distinguish selection by geometry
as well as color. Missing icons use the native executable icon fallback.

The centered row shows at most four entries. Cycling naturally selects the next
page, keeping the selected entry visible without thumbnails or a scrolling/timer
controller. Surface anchoring and padding change only in Alt+Tab mode. Blur is
explicitly disabled for this mode even with a frosted global theme. Search mode
retains its original surface and styling. Native forward/reverse and release logic
are byte-preserved by the fixture test.

No new thread, process, subscription, timer, animation or idle allocation path is
added. Up to four tiles and one title are built while rendering the open overlay;
icon handles reuse the native metadata cache. Expected added idle wakeups: none.
Actual CPU/RSS differences remain unmeasured; the stock resident process and GPU
renderer continue to have their existing costs. No claim of zero total idle RAM.

## Build and package safety

```bash
bash scripts/app-switcher-package-test.sh build
```

The helper uses a fresh `/tmp/cosmic-refined-switcher-package.XXXXXXXX` workspace,
normal locked Cargo resolution, and subprocess-only Git config isolation to keep
GitHub HTTPS dependencies from being rewritten to SSH. It changes no global Git
config and installs no dependencies or packages. PKGBUILD runs formatting,
`cargo check --locked`, and `cargo build --locked --release`, then verifies the
unchanged lock and stock file inventory. The host Arch build has passed; its
source, unchanged lock, package metadata and payload were independently checked.
Ubuntu CI also passed the real staging function against that same inventory.

Package: `cosmic-switcher-refined 1:1.9.0-1`, providing
`cosmic-launcher=1:1.9.0`, conflicting only with `cosmic-launcher`. It replaces the
owning executable through pacman, preserving cosmic-session launch paths and all
stock desktop metadata. It has the same runtime dependencies as stock, including
existing pop-launcher; it does not replace that backend or any notification package.
It ships the same four files: executable, desktop file, metainfo and icon.

Do not install until pinned CI, package validation and PR review pass. The explicit
`install PACKAGE` helper command requires typing `INSTALL`, stock ownership/version
and SHA256 checks, and prints rollback first. It never starts/restarts the switcher
or COSMIC. Plan a manual logout/login afterward so the persistent frontend loads
the new binary. No live installation has occurred in this milestone.

## Stock baseline and controlled host validation

Run on the actual host before replacing stock:

```bash
bash scripts/app-switcher-host-validate.sh baseline /tmp/refined-switcher-stock-baseline.txt
```

From another terminal, capture the same `status` command when idle, while holding
Alt+Tab, and after dismissal. Repeat once after warm-up. The helper does not invoke
Alt+Tab, launch a component or monitor continuously. It matches full executable
paths through `/proc`, so truncated process comm names do not affect discovery.
It records PID/parent, elapsed time, RSS (KiB) and lifetime-average CPU. These are
snapshots, not precise wakeup or idle CPU benchmarks. Native children are included
when their executable is cosmic-launcher, pop-launcher or cosmic-toplevel.

Optional existing tools only: `pidstat -p PID 1 5` for a short interval CPU sample;
`ps -p PID -o pid,ppid,etimes,rss,pcpu,args` for an open-overlay sample. Do not install
monitoring tools or leave a benchmark running. Wakeups require suitable existing
instrumentation and permission; otherwise leave them unmeasured. Sandbox `/proc`
is not evidence of host process presence or lifetime.

After approved installation and manual login, use the exact packaged binary SHA256
printed by build, rather than guessing a universal hash:

```bash
bash scripts/app-switcher-host-validate.sh verify BINARY_SHA256 /tmp/refined-switcher-stock-baseline.txt
```

This verifies package ownership/checksum and checks any resident frontend
against that same checksum, including an executable marked deleted after a package
transaction. It prints comparable native-process snapshots. It cannot prove that every unrelated background process is absent;
no-extra-service guarantees also come from unchanged subscriptions and strict
package inventory tests. Test Alt+Tab and Shift+Alt+Tab, release Alt quickly, wrap
across more than four windows, use multiple windows from one app and multiple
workspaces, test long titles/missing icons and mouse activation/context actions.
Provide a screenshot and behavior notes. Visual and host performance validation
remain pending; notifications and the mako mask remain untouched.

## Independent rollback and TTY recovery

Online:

```bash
sudo pacman -S extra/cosmic-launcher
```

Cached stock archive and signature are present on the inspected host. Offline:

```bash
sudo pacman -U /var/cache/pacman/pkg/cosmic-launcher-1:1.9.0-1-x86_64.pkg.tar.zst
```

Pacman validates the package normally; do not disable safeguards. The
`restore-stock` helper prefers the cached archive plus signature and requires
`RESTORE`. It does not signal any process. From a TTY, reinstall stock with either
command and return to a fresh graphical login manually. Never kill cosmic-session,
restart cosmic-panel, or alter Vicinae to recover this package.

## Validation status

Patch apply/reverse/drift, unchanged native logic, Rust formatting, package
inventory and mock transaction/host snapshot tests run in repository validation.
The earlier sandbox check and makepkg attempt stopped before compilation because
of uncached dependencies and unavailable GitHub DNS. Those historical attempts
are superseded by the successful host Arch build and CI at PR #3 head
`dd14bcc48f9c2732cc227e3b5f206978a22e1380`:

- [Native switcher patch build](https://github.com/rickallauigan/cosmic-refined/actions/runs/37092505177): fixtures/lint, exact pinned source, formatting,
  `cargo check --locked`, `cargo build --locked --release`, unchanged Cargo.lock
  and real package-staging inventory all passed.
- [Notification center patch build](https://github.com/rickallauigan/cosmic-refined/actions/runs/37092505208): fixtures, pinned build and theme-schema checks passed.

Final diff review found no source/package blocker: search rendering, native
forward/reverse selection, Alt-release activation, multi-window ordering and
subscriptions remain unchanged. No periodic work, additional process, global Git
config mutation or unrelated settings change is introduced. Stock rollback remains
`sudo pacman -S extra/cosmic-launcher`. The installed launcher remains stock.
PR #3 is open and unmerged; merge requires explicit user authorization. Live
visual/interaction and comparative performance evidence remain pending.
