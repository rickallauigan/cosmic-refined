# Controlled notification package test

The package workflow keeps COSMIC's normal launch command and supervision:
`cosmic-session` starts `/usr/bin/cosmic-notifications` through its normal PATH.
Pacman owns and replaces the file. No manual system-binary copy, COSMIC/session
patch, SDDM/PAM change, user autostart, profile or PATH injection is used.
Vicinae, shared themes and notification center styling stay outside this workflow.

The earlier `.zlogin` test did not reach the daemon on the real host.
`environment.d` was not verified as an alternative in the SDDM startup chain.
See [environment investigation and legacy cleanup](notification-next-login-test.md).
Keep that test disabled; do not combine it with package replacement.

## Rollback first

Retain a signed official package in the pacman cache before installing the test.
For the inspected official version, offline rollback is:

```sh
sudo pacman -U -- '/var/cache/pacman/pkg/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst'
```

Online rollback is:

```sh
sudo pacman -S extra/cosmic-notifications
```

Pacman may ask to remove `cosmic-notifications-refined`; approve replacing it with
stock. Do not use `--overwrite`, `--nodeps`, forced database operations or disable
signature verification. Cache permissions can prevent unprivileged inspection;
pacman performs the actual verification/transaction under sudo. A signature sidecar
is required for the helper's cached-stock selection. If no signed cache exists,
repository metadata alone cannot guarantee network availability later: obtain and
retain a verified official package before relying on offline recovery.

Package transactions alone do not restart the supervised daemon. After installing
or restoring, choose when to log out/in yourself. Never kill the daemon or panel to
force the new binary into the active session.

## Build only

Run as your regular user from the checkout:

```sh
bash scripts/notification-package-test.sh build
```

This copies a pinned recipe and both patches into a fresh temporary workspace and
runs makepkg without sudo, dependency installation or package installation. The
upstream commit is `aa4dac2702506395ab76da1f6755e03b2ccb0db8`; source/patch checksums
and unchanged Cargo.lock are required. It runs fmt, check and release build.
Source/Cargo downloads use normal resolution and caches. Nothing is built into Git.
For dependencies, packaging comparison, licensing and manual build details, see
[Arch package README](../packaging/arch/README.md).

The default work root is `/tmp/cosmic-refined-notification-package`. If temporary
storage will not survive your testing window, set `COSMIC_REFINED_PACKAGE_WORKDIR`
to a private absolute directory inside your home, using the same value for later
commands. This is a helper build-storage setting, not a desktop environment override.
The helper refuses root builds, symlinked/foreign-owned workspace ancestors and
unexpected archive payloads. Build records contain package/binary checksums and
available pre-build stock metadata. Keep the artifact until you finish testing.

## Explicit installation

```sh
bash scripts/notification-package-test.sh install
```

Only run this command on the real host. It selects the last successfully recorded
artifact, verifies its checksum and archive, and checks the installed stock binary
ownership/checksum and COSMIC 1.9.0 versions. It prints the package path and cached
or online rollback command **before** asking you to type `INSTALL`. Without that
exact confirmation, no sudo command runs. Pacman then performs its normal `-U`
transaction, including the conflict-removal question and any authentication prompt.
The rollback selection is saved beside the built package before the transaction.
No hook, restart, logout or reboot is performed.

The local name is `cosmic-notifications-refined`, provides epoch-aware
`cosmic-notifications=1:1.9.0`, and conflicts with stock. Installing it removes the
stock package through normal package management while preserving the dependency
required by cosmic-session. The only payload is `/usr/bin/cosmic-notifications`.

The package-specific second patch enables Refined cards and critical urgency accents
by default, without session variables. The original source patch stays opt-in for
other use cases. This means the already-built user-local prototype is **not** the
package binary: that prototype requires opt-ins and its checksum must not be used
to identify this newly built, stripped/default-on artifact.

## Verify after your next login

```sh
bash scripts/notification-package-test.sh status
pacman -Q cosmic-notifications-refined
pacman -Qo /usr/bin/cosmic-notifications
notify-send 'COSMIC Refined' 'Normal notification test'
notify-send -u critical 'COSMIC Refined Critical' 'Critical notification accent test'
```

`status` reports installed package identity/checksum separately from daemon PID and
executable, scanning readable user-owned `/proc` entries rather than relying on a
full Linux comm name. A currently running old daemon may show `/usr/bin/cosmic-notifications
(deleted)` after a package transaction; that does not prove the new binary is running.
Run status in your host terminal, not a sandbox, and confirm after a new login.
No Refined environment variables are required by this package.

Review 380px cards, 18px corners, 32px icons, bold titles, readable body, opaque
contrast, UTC receipt timestamp, neutral normal cards and critical-only accents.
Check wrapping, stacking, close/activation, timeouts and tray/history behavior.
No notification-center redesign is included. Existing daemon rendering remains
responsible for notifications; there is no new runtime dependency or process,
polling, blur daemon or animation service. Live performance/visual results are
not established by package fixtures.

## Restore and TTY recovery

```sh
bash scripts/notification-package-test.sh restore-stock
```

It prints the selected signed cache or online command and asks for `RESTORE` before
sudo. It does not require a working session bus, the old COSMIC version or a running
daemon. It leaves current processes alone and tells you to choose a new login.

If the graphical session is unhealthy, switch to a TTY (for example Ctrl+Alt+F3),
log in as your regular user and run the helper from the checkout. If the checkout
or temporary workspace is unavailable, use the direct cached-stock `pacman -U`
command above; it needs neither the graphical session nor network. Otherwise use
the online `pacman -S` command when the repository/network is available.

This workflow restores the package; it does not automatically end an unhealthy
session. Use your normal session recovery procedure after the stock transaction.
Keep the signed stock cache and avoid deleting rollback records until recovery is
verified. This is a temporary pinned package, not an automatic maintenance channel.

Both package helpers ignore global/system Git configuration only inside the build
subprocess, use CLI Git fetching and enable normal Cargo network resolution. The
user's global GitHub SSH rewrite is not modified. The installed banner package,
daemon patch and default-on package patch are unchanged by this helper cleanup.
