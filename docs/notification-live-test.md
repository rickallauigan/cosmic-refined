# Controlled host-side notification test

Run this helper **manually from your regular ThinkPad Wayland terminal**, not from
Codex or another sandbox. It prepares a temporary test of the existing notification
daemon's optional card patch. It has no GUI, permanent autostart, package replacement
or additional runtime service, and does not touch Vicinae or unrelated COSMIC config.

## Supported launch mechanisms and an important COSMIC 1.9.0 limitation

The helper must establish a deterministic restore path before building or signaling
anything. It accepts:

- A dedicated systemd user service whose sole process/MainPID is the packaged daemon,
  whose ExecStart directly names the stock binary, and which has no extra execution
  hooks or stop-propagation relationships. The service is stopped temporarily and
  later started from its unchanged definition; no override is written.
- A daemon launched directly from an interactive shell, with no script/command
  wrapper or inherited notification/Wayland socket descriptor. Its command arguments
  and filtered desktop environment are recorded and later relaunched with `nohup`.

**The normal COSMIC 1.9.0 session-managed launch is deliberately refused.** Upstream
`cosmic-session` creates an inherited socket between the panel and notification
daemon; its daemon exit handler can restart `cosmic-panel`. A naive kill/manual
relaunch would violate the requirement to leave the panel alone and can lose
notification-tray/history integration. See
[session launch](https://github.com/pop-os/cosmic-session/blob/epoch-1.9.0/src/main.rs),
[paired restart handler](https://github.com/pop-os/cosmic-session/blob/epoch-1.9.0/src/notifications.rs)
and [daemon socket setup](https://github.com/pop-os/cosmic-notifications/blob/aa4dac2702506395ab76da1f6755e03b2ccb0db8/src/subscriptions/applet.rs).

Unknown supervisors, wrapped autostarts, services containing unrelated processes,
and inherited `DAEMON_NOTIFICATIONS_FD`, `PANEL_NOTIFICATIONS_FD` or `WAYLAND_SOCKET`
are also refused. Autostart files/user units are inspected for context, but file
presence is not treated as proof of the running launch mechanism. Do not bypass
these refusals or kill the daemon yourself to make this helper work. A safe approach
for a session-managed daemon requires separate investigation and authorization;
it is not implemented here. A terminal's shared service cgroup can also cause a
conservative refusal, even if the user started a daemon manually.

## Commands

From the COSMIC Refined checkout:

```sh
bash scripts/apply-notification-test-host.sh check
bash scripts/apply-notification-test-host.sh apply
bash scripts/apply-notification-test-host.sh status
bash scripts/apply-notification-test-host.sh restore
```

`check` verifies the host session, package/binary, running process, bus ownership,
parent/cgroup and supported launch mechanism. It prints the restore strategy,
filtered environment, related unit/autostart evidence and CPU/RSS snapshots. It
writes nothing and stops nothing.

`apply` repeats those checks, then fetches official upstream commit
`aa4dac2702506395ab76da1f6755e03b2ccb0db8` into a fresh child directory under
`/tmp/cosmic-refined-notification-live-test`. It compares upstream files with pinned
fixtures, applies the patch, and runs:

```sh
cargo fmt --all -- --check
cargo check --locked
cargo build --locked --release
```

Normal Cargo dependency downloads use your existing toolchain/cache. Build outputs
are isolated in that temporary workspace, never in COSMIC Refined. The original
Cargo.lock checksum must remain unchanged. No packages are installed; missing
upstream native development prerequisites or any failed build stop the operation
before the stock daemon is touched. Read upstream build requirements if necessary;
this script does not acquire privileges or install prerequisites automatically.

The successful build is copied atomically to:

```text
~/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined
```

The packaged `/usr/bin/cosmic-notifications` is never overwritten. The installed
version must be `1:1.9.0-1` or equivalent version-1.9.0 packaging, **and** its SHA256
must exactly match:

```text
6ed809b720aa26676043acec96811b0dded10054b2e1c54f1cb15df8ced929d7
```

A package update with different bytes is refused even if its version looks compatible;
revalidate that build instead of editing the checksum blindly.

After rebuilding, process identity/launch safety is rechecked. Private timestamped
metadata is saved under `~/.local/share/cosmic-refined/notification-backups/`, including
both checksums, original PID/parent, command/environment, mechanism, restore command
and baseline snapshots. Arguments/environment use NUL-separated files, never `eval`
or sourced metadata. Only selected desktop/rendering/locale variables are retained;
full environments and secrets are not dumped. Keep metadata private and do not
commit it. The directory also identifies the original service definition by checksum.

Before stopping anything, the helper prints the exact command needed to restore.
Only the verified stock process or dedicated unit is stopped. A detached test binary
then starts with both flags:

```text
COSMIC_REFINED_NOTIFICATION_CARDS=1
COSMIC_REFINED_NOTIFICATION_URGENCY=1
```

Logs remain at `~/.local/state/cosmic-refined/cosmic-notifications-test.log`.
Startup verification checks a single daemon, its executable, bus ownership and both
opt-ins, then verifies it remains alive for five seconds. Finite startup/exit waits
are bounded; no monitoring process persists. If `apply` sees an already running,
matching test with valid rollback metadata, it returns without rebuilding or spamming
notifications. Run one helper at a time; stale lock directories require manual
inspection before removal.

`status` checks the host/package and reports stock/patched executable identity,
opt-ins for the patched daemon, and snapshots without changing anything.

## Visual review and performance

When available, `notify-send` sends normal, critical, long-content and three stacked
tests with short gaps and finite expiry times. This is a small burst; normal notify
limits may expire or hide some banners before all are visible. Missing notify-send
is reported rather than installed. Test unknown icons, close/dismiss and activation
manually as appropriate. Tray/history must be reviewed separately; this helper does
not repair inherited socket integration or claim center styling improvements.

Expected opted-in cards: approximately 380 logical pixels wide, 18px corners, 32px
notification/app icon (the existing lookup may prefer image hints), bold 18px title,
15px body, opaque high-contrast dark/light surface and static UTC receipt timestamp.
Only critical notifications should show the optional accent and a textual urgency
label; normal cards should remain neutral. Verify stacking, clipping, wrapping,
scaling, button behavior, timeouts and actual readability on your desktop.

The helper prints stock/patched PID, RSS, lifetime-average CPU %, elapsed time,
compositor snapshot, load and memory. Process ages differ and notifications/build
activity can bias readings: these are rough observations, not an idle benchmark.
No new GPU tool is installed and this helper does not collect GPU utilization.
For expected rendering costs and remaining checks, see
[build verification](notification-build-validation.md). No screenshot or live
performance result is claimed by the mocked repository tests.

## Rollback and failure handling

`restore` uses the latest recorded backup. You can select the exact recorded directory:

```sh
bash scripts/apply-notification-test-host.sh restore /absolute/path/to/notification-backups/TIMESTAMP.ID
```

It verifies the package/checksum, metadata and same desktop session, refuses multiple
or unrecognized daemons, and sends TERM only to the known test executable. It starts
the recorded original service or relaunches the recorded stock command/environment,
then verifies the stock executable owns `org.freedesktop.Notifications`. Existing
verified stock behavior is a no-op. No SIGKILL escalation or package replacement is
performed, and rollback metadata is never automatically deleted.

Once a switch begins, apply failures or handled interruption/termination signals
attempt this same restoration automatically. Exit code 125 means automatic restore
failed: inspect the log and keep the printed backup/restore command. SIGKILL, power
loss, concurrent session changes, inaccessible metadata or a newly upgraded stock
binary can prevent automatic rollback. Keep this checkout at the same path until
restoration is complete. Log out/back in only as a separately chosen recovery step;
the helper never restarts the COSMIC session or panel.

No persistent opt-in is created. A new normal COSMIC session still uses the packaged
daemon. After verified restoration, you may manually remove the test binary/logs and
temporary build workspace; retain backups until you no longer need them.
