# Development validation

Run from the repository root:

```sh
bash scripts/validate.sh
```

This checks whitespace, every shell script's Bash syntax, theme parity, license
and attribution file presence, and the migrated preset fixture tests. Use
`git diff --cached --check` before committing staged changes too.

Tests require only Bash, Git and standard file tools; no ripgrep or additional
package is required. They allocate temporary directories with `mktemp`, and the
preset tests export `XDG_CONFIG_HOME` pointing inside their fixture **before**
invoking the installer. The fixture includes panel/dock managed values and an
unmanaged key. Neither test reads or writes live COSMIC configuration.

Coverage includes complete backups before writes, application of managed values,
idempotence without redundant backups, restore, preservation of unmanaged keys,
rollback after an injected replacement failure, failure during the second directory
backup, and rejection of missing or symlink keys. Validation never invokes an
installer outside these fixtures. No root commands, autostart files, package
installation, daemon restart or notification rebuild are included.

Limitations: per-key replacements are atomic, but the complete update is not.
SIGKILL/power loss and concurrent COSMIC Settings writes are not simulated. Keep
the backup and avoid editing panel/dock settings during an operation. Live geometry,
accessibility, theme import compatibility and power measurements require explicit
manual testing later.

## Optional notification source validation

With an already installed Rust compiler and rustfmt, run:

```sh
bash scripts/validate.sh --notifications
```

This also applies/reverses the pinned source patch in temporary fixtures, checks
reapply/drift rejection, parses/formats changed Rust files, and compiles/runs the
std-only policy tests for explicit opt-in, geometry, timestamp rollover and palette
contrast. No Cargo dependencies are needed for those tests. Full libcosmic/daemon
integration compilation has since passed on the disposable CI runner; the local
offline attempt was blocked by an uncached libcosmic dependency. No new runtime
package is introduced. See [patch status](../notifications/patches/README.md).

## Full pinned daemon build

The `Notification patch build` GitHub Actions workflow uses a disposable Ubuntu
24.04 runner, upstream Rust 1.93.0, and daemon commit
`aa4dac2702506395ab76da1f6755e03b2ccb0db8`. It checks fixture provenance, applies
the patch, then runs `cargo fmt --all -- --check`, `cargo check --locked` and
`cargo build --locked`. Normal Cargo downloads remain in runner-local temporary
storage; nothing is vendored into this project. Upstream Wayland/xkbcommon build
headers are installed only on that disposable runner, not on the user's machine.
The workflow neither starts nor installs a daemon. A passing run verifies compilation
on that runner; controlled COSMIC/Wayland testing is still a separate milestone.

See [recorded build evidence](notification-build-validation.md) for the passing run,
exact source/dependency revisions, warnings and remaining runtime limitations.

## Current notification/theme validation

`bash scripts/validate.sh --notifications` includes patch fixtures, package inventory,
confirmation/rollback safety, host diagnostic mocks and both theme variants.
Notification tests also need rustc/rustfmt, Python 3, bsdtar and the existing package
build tools used by their fixtures. These are development prerequisites, not new
runtime dependencies. ShellCheck is an additional development check.

`tests/theme-schema.rs` deserializes and builds both themes against cosmic-theme
and ron artifacts from the pinned 1.9 release build. This was run locally using
cached release rlibs: both the builder and generated performance theme have every
frosting flag disabled. The shell fixture preserves palette/geometry parity.

A separate notification-center CI workflow fetches the exact release and compares
fixtures before locked formatting/check/build. It has not run remotely while .git
is read-only. Local compiled/package evidence is documented in notification-center.md.
Live validation uses the host helper only; automated tests replace busctl, pacman,
journalctl, systemctl and notify-send and use temporary process fixtures.
