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
