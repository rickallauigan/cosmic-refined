# Project scripts

This directory holds development validation tools. Small feature-specific
apply/restore utilities stay with their optional components, including
`presets/macos-performance/install.sh`. Backup-before-change, restore, rollback,
idempotence and fixture validation remain part of those utilities.

These scripts are not a standalone installer product or GUI. Run them explicitly
with Bash as your regular user; nothing runs automatically at login/startup.

For the manually invoked, temporary notification daemon test, see
[host-side helper instructions](../docs/notification-live-test.md). The helper
refuses unsupported/supervised launch mechanisms rather than restarting the panel.

For the normal COSMIC session-supervised daemon, next-login activation is blocked
until graphical-session environment delivery is verified. The
[next-login investigation and recovery helper](../docs/notification-next-login-test.md)
reports host status and safely removes the failed legacy profile override.

For an explicitly confirmed pacman-managed test, see the
[notification package workflow](../docs/notification-package-test.md). Building
does not install; installation and stock restoration are separate host commands.

The experimental `notification-center-package-test.sh` builds/validates a separate
whole-applets Arch package. Its explicit install/restore commands require confirmation
and never restart COSMIC processes. See [center scope and rollback](../docs/notification-center.md).

`notification-live-validate.sh --test` is a host-only verification action: it
checks the installed packages, notification bus owner and applet, reads recent
error logs and sends three notifications for visual review. It changes no services,
configuration or running processes. Automated tests mock all session interfaces.
