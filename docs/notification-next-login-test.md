# Notification next-login test: activation withdrawn

**No verified per-user graphical-login override has been established for this
host. `prepare` refuses activation and creates no configuration.** Do not log out
to test the previous `.zlogin` strategy again. The helper now provides read-only
host status and safe recovery of that legacy configuration.

The optional notification source patch remains compile-verified by its existing
CI workflow. This blocker concerns choosing the executable at login, not its card
rendering. No packaged binary, COSMIC component, Vicinae setting or current session
has been modified by this investigation.

## Why the earlier assumption was wrong

The user's post-login evidence shows the daemon still executing
`/usr/bin/cosmic-notifications`, parented by `/usr/bin/cosmic-session`, without either
Refined variable. Its PATH does not contain the wrapper directory. A generated
profile or an isolated zsh fixture therefore did **not** prove environment delivery
to the real graphical session. The earlier claim that the `.zlogin` facility was
verified was incorrect.

The exact reason the old guarded block did not run or propagate on that login
cannot be determined from that process snapshot alone. Installed startup sources
contain login-shell invocations, but those alone do not establish that the user's
actual profile, guard and startup path produced the intended environment. We do
not substitute another general shell profile or treat theoretical sourcing as
host verification.

## Installed graphical-login chain

The installed display-manager link resolves to `sddm.service`; this is SDDM
`0.21.0-7`, with COSMIC session/compositor/notifications `1:1.9.0-1`. The greeter's
own compositor is separate from the selected user session.

1. [SDDM 0.21.0 Display.cpp](https://github.com/sddm/sddm/blob/v0.21.0/src/daemon/Display.cpp#L430)
   constructs the session environment and explicitly sets PATH from
   `Users.DefaultPath`. The installed default is
   `/usr/local/sbin:/usr/local/bin:/usr/bin`.
2. [PamBackend::openSession](https://github.com/sddm/sddm/blob/v0.21.0/src/helper/backend/PamBackend.cpp#L245)
   passes that environment into PAM and merges the resulting PAM environment.
   Installed `/etc/pam.d/sddm` includes `system-login` and `system-auth`.
   Their `pam_env.so` calls have no `user_readenv=1`. Installed PAM 1.7.2
   documentation says per-user `.pam_environment` reading defaults to **off**
   and is deprecated. Enabling it would require changing system PAM policy;
   we do not do that.
3. [UserSession::start](https://github.com/sddm/sddm/blob/v0.21.0/src/helper/UserSession.cpp#L115)
   starts the configured Wayland `SessionCommand` as a child process. The installed
   command is `/usr/share/sddm/scripts/wayland-session`. Its zsh branch runs a
   login shell, then executes the selected session command. This is not a systemd
   user service launch.
4. The packaged `/usr/share/wayland-sessions/cosmic.desktop` selects
   `/usr/bin/start-cosmic`. The installed script invokes a login shell and later
   `/usr/bin/cosmic-session`. It imports its environment **into** the systemd user
   manager; it does not export the user manager's PATH back into the session.
   Compare the [pinned startup source](https://github.com/pop-os/cosmic-session/blob/1e4f10b5821982688e4a8a39f819be0bc2ad3e74/data/start-cosmic).
5. [COSMIC session 1.9.0 main.rs](https://github.com/pop-os/cosmic-session/blob/1e4f10b5821982688e4a8a39f819be0bc2ad3e74/src/main.rs#L175)
   reads systemd's environment only for variables absent from its own environment.
   PATH is already present, so an environment.d PATH does not replace it.
6. Session main starts the bare `cosmic-notifications` command through
   [pinned launch-pad](https://github.com/pop-os/launch-pad/blob/5b516ee6a012b5ad4a5acc0cf51b4472fc6733af/src/lib.rs#L172).
   It is **PATH-resolved**, not hardcoded to `/usr/bin`, but needs the correct PATH
   in the session process. The daemon/panel are supervised together using an
   inherited socket; see [paired restart handling](https://github.com/pop-os/cosmic-session/blob/1e4f10b5821982688e4a8a39f819be0bc2ad3e74/src/notifications.rs).
   Killing the daemon can restart the panel and remains prohibited here.

The [Arch SDDM PKGBUILD](https://gitlab.archlinux.org/archlinux/packaging/packages/sddm/-/blob/main/PKGBUILD)
retrieved during this investigation matches installed `0.21.0-7`: it uses upstream
`v0.21.0` and a CMake-4 build fix, not a session environment.d-import patch.
Installed SDDM session directories are `/usr/local/share/wayland-sessions` and
`/usr/share/wayland-sessions`, not a user-local session directory. No supported
per-user core-component `.desktop` override was identified.

## Why environment.d is not the replacement

Installed systemd 262 `environment.d(5)` and
[upstream documentation](https://www.freedesktop.org/software/systemd/man/latest/environment.d.html)
explain that these files supply environment variables to services started by the
systemd user manager. An independently started graphical session inherits its
launcher's environment unless that launcher explicitly imports the user manager's
exported environment. The inspected SDDM startup chain does not do that.

The generator supports `$PATH`, `${PATH}`, `${PATH:-DEFAULT}` and
`${PATH:+ALTERNATE}` expansion. It does not execute shell constructs. A read-only
experiment invoked the installed `30-systemd-environment-d-generator` with a
private temporary XDG_CONFIG_HOME and input PATH `/usr/bin`. All of:

```text
REFINED_DOLLAR=/wrapper:$PATH
REFINED_BRACES=/wrapper:${PATH}
REFINED_COLON=/wrapper${PATH:+:${PATH}}
PATH=/wrapper:${PATH:-/usr/bin}
```

expanded to the appropriate `/wrapper:/usr/bin` value. This establishes **parsing**,
not graphical-session inheritance. The experiment wrote only temporary files and
printed generator output; it did not reload or change a service manager.

Consequently **no** `~/.config/environment.d/90-cosmic-refined-notifications.conf`
is created. `systemctl --user show-environment` would report manager state, not prove
the PATH used by the display-manager child. Do not run daemon-reload/import-environment
or add a PATH file as a purported fix for this startup chain.

## Commands and legacy recovery

Run from your normal host terminal, or a TTY as the same regular user:

```sh
cd ~/Projects/cosmic-refined
bash scripts/notification-next-login-test.sh status
bash scripts/notification-next-login-test.sh disable
```

`status` reports separately:

- Whether a supported override exists (currently none), legacy metadata and enable gate.
- Wrapper and target locations, available target/stock checksums and recovery command.
- Current daemon candidates, executable, stock/patched classification, opt-in values,
  actual process PATH and whether that PATH contains the wrapper directory.

Process discovery scans readable, user-owned `/proc` entries using executable,
command and the truncated `cosmic-notifica` comm. It does not use
`pgrep -x cosmic-notifications`. It prints only relevant variables, not the full
environment. In a sandbox, its process view is the sandbox's view: run on the host
to verify the actual session. PATH presence alone is not proof of selecting a binary.

`prepare` now exits nonzero, explaining the unverified environment chain. It does
not build, change profiles, create an environment.d file, arm a wrapper or ask you
to log out. Running it repeatedly is safe.

`disable` removes the old enable gate first, then uses the existing active-backup
pointer and `cosmic-refined-next-login-v1` metadata to remove only the recorded
`BEGIN/END COSMIC Refined next-login notification test` change from `.zlogin`.
It saves a new `profile.pre-cleanup.*` copy before editing. If the current profile
is byte-identical to recorded `profile.after`, restoring `profile.before` is safe
because no later changes exist. Otherwise it removes only the exact recorded
marked block and preserves surrounding edits, including trailing-newline state.
It never sources a profile or metadata.

Malformed, duplicate or edited markers and invalid/missing metadata are refused
after disarming; unrelated text is not deleted. An unchanged recorded wrapper is
removed, but changed wrappers and extra directory contents are preserved for
review. Original backups and compiled binaries are retained. Repeated successful
`disable` is a no-op. It requires no package-version match or graphical session bus.

Legacy paths:

```text
~/.local/lib/cosmic-refined/notification-next-login-bin/cosmic-notifications
~/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined
${XDG_STATE_HOME:-~/.local/state}/cosmic-refined/notification-next-login-active
${XDG_DATA_HOME:-~/.local/share}/cosmic-refined/notification-next-login-backups/
```

If recovery metadata is damaged or the checkout is unavailable, remove the old gate
from a TTY to neutralize the original generated wrapper:

```sh
rm -f -- "$HOME/.local/lib/cosmic-refined/notification-next-login-bin/.enabled"
```

Then review the marked block and backups manually. Do not blindly restore an old
whole profile over later changes. Neither recovery procedure signals a daemon,
restarts a component, logs out, reboots, modifies package files or requires sudo.
No new PATH injection is installed alongside the old mechanism.

## What remains

A replacement must demonstrate environment delivery **before cosmic-session starts**
and verify the eventual running executable/flags/PATH on the host. It cannot rely
on a file existing, a successful generator expansion or a mocked shell alone.
With the current constraints (no general-shell-profile workaround, no system PAM
or SDDM changes, no session/compositor patch and no package replacement), no such
mechanism was verified. Keep stock notifications as default. No new wrapper or
fallback implementation is activated while this prerequisite is unresolved.

Repository tests use private HOME/XDG equivalents and synthetic `/proc` entries.
They cover blocked preparation, exact legacy cleanup, backups, later edits,
malformed metadata/marker refusal, idempotence, truncated-name discovery, separate
configured/running status, and absence of live process controls. They do not claim
a working graphical-login override or a successful host live test.

For a separately authorized package-manager test that preserves the normal launch
path, see [notification package testing](notification-package-test.md). This does
not enable an environment override or change the blocked `prepare` command here.
