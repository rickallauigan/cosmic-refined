# Project scripts

This directory holds development validation tools. Small feature-specific
apply/restore utilities stay with their optional components, including
`presets/macos-performance/install.sh`. Backup-before-change, restore, rollback,
idempotence and fixture validation remain part of those utilities.

These scripts are not a standalone installer product or GUI. Run them explicitly
with Bash as your regular user; nothing runs automatically at login/startup.
