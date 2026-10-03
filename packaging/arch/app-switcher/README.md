# Arch native-switcher package

See [architecture, build, validation and independent rollback](../../../docs/app-switcher.md).

`cosmic-switcher-refined` replaces only `cosmic-launcher`. It preserves stock
runtime dependencies and the four-file stock inventory. The source pin is
`cc3d42bcc8fbcb67e6312f2766394e18b4d937d5`; the rendering-only patch is GPL-3.0-only.
The preserved Arch recipe comes from packaging commit
`d95e9a4657f8935ed435ee28746ebc038eb88cb5`. Its thin-LTO patch is retained;
`just`/`intltool` build requirements are avoided with equivalent direct commands.
No service, autostart, package hook, user config or environment override is added.

The Git source uses a fixed commit and verifies HEAD plus the original locked
Cargo hash; patch inputs have BLAKE2 checksums. Dependency versions never change.
Locked inputs do not guarantee byte-identical builds across different Rust,
linker or Arch build environments. Record each package and binary hash.

Run `bash scripts/app-switcher-package-test.sh build` without root. Actual host
installation requires the explicit `install PACKAGE` command and `INSTALL`
confirmation, only after CI and review. No automated live installation is provided.

Online rollback: `sudo pacman -S extra/cosmic-launcher`.
Offline rollback: `sudo pacman -U /var/cache/pacman/pkg/cosmic-launcher-1:1.9.0-1-x86_64.pkg.tar.zst`.
Do not bypass signatures, restart session processes or change Vicinae.
