# Arch / EndeavourOS Refined notification package

This directory contains a **local test package**, not an official Arch package or
an AUR release. Build as your regular user. Installation is a separately confirmed
pacman transaction; no source build installs anything.

Before installing, keep the official package and its signature available. On the
inspected machine the cache contains:

```sh
sudo pacman -U -- '/var/cache/pacman/pkg/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst'
```

The sandbox could list/stat these files but could not read their contents because
of cache permissions. The host helper selects a signed stock cache, and pacman
checks it during the privileged transaction. Do not remove package signatures or
weaken signature requirements. If a usable cache is absent, online rollback is:

```sh
sudo pacman -S extra/cosmic-notifications
```

Pacman will ask to remove the conflicting Refined package. Accept that replacement.
Neither command restarts the daemon; choose a new login yourself afterward.

## Official package comparison

Installed and repository metadata match `extra/cosmic-notifications 1:1.9.0-1`,
`x86_64`, GPL-3.0-only. The package has no install script, provides, conflicts or
replaces entry. It belongs to the `cosmic` group, is required by `cosmic-session`,
and its payload is just `/usr/bin/cosmic-notifications` plus parent directories.

Runtime dependencies are preserved: `cosmic-icon-theme`, `libgcc`, `glibc`,
`libxkbcommon`, `wayland`.

The retrieved [Arch PKGBUILD](https://gitlab.archlinux.org/archlinux/packaging/packages/cosmic-notifications/-/blob/main/PKGBUILD)
matched this exact version/release. Maintainers are Maxime Gauduin and Peter Jung;
contributors credited there are Mark Wagie and soloturn. It fetches upstream tag
`epoch-1.9.0`, runs `cargo fetch --locked`, sets `RUST_MIN_STACK=33554432`, then uses
`just build-release --frozen` and `just rootdir="$pkgdir" install`. No downstream
source patch appears in that recipe.

The tag resolves to `aa4dac2702506395ab76da1f6755e03b2ccb0db8`. A local
`git archive` of that exact commit matches Arch's BLAKE2 source checksum:

```text
f79bd6746251ed85c69320a7ec907149a6f5c19692683e0b334e0924553afe7ba8ab52da51fdc497988845818c2cab97b415bd5b82f044dedece36b4e3e2d052
```

That establishes source matching, **not byte-identical builds**. Toolchain, makepkg
flags/stripping and build environments affect the binary. The stock cached
`.BUILDINFO` was not readable in the sandbox; its precise build environment was not
independently inspected. Do not claim a reproduced stock binary from this recipe.

## Why a separate package name

The local package is `cosmic-notifications-refined 1:1.9.0-1`, with:

```sh
provides=('cosmic-notifications=1:1.9.0')
conflicts=('cosmic-notifications')
```

The **epoch is included** in the provided version. This satisfies the normal
COSMIC dependency while leaving a clear installed-package identity. There is no
`replaces` field, so installation is explicit rather than advertised as a routine
repository replacement. It does not join the `cosmic` group as another ambiguous
provider.

A same-name local pkgrel rebuild would hide whether this is the official package
and complicate upgrade/rollback version comparisons. With separate names, rollback
is a normal conflicting-package replacement: no forced file overwrite, dependency
removal, IgnorePkg rule or package-management safeguard change is needed.

## Package-local defaults and recipe differences

The recipe pins the commit, verifies the same upstream source checksum and both
patch checksums, then applies:

1. The unchanged canonical
   `notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch`.
2. `refined-package-defaults.patch`, which defaults the two notification options
   to `1` when their environment variables are absent. Explicit existing values
   continue to use the original parser; `0` disables the corresponding behavior.

No session environment manipulation is required. The portable/source prototype
remains opt-in; default-on behavior belongs only to this custom package. Reinstall
stock to remove it completely. No new configuration key, dependency or service is
introduced.

Normal Cargo resolution is retained and Cargo.lock is checked for byte identity.
The native x86_64 Linux target is fetched explicitly to avoid unnecessary downloads
for other platforms. The recipe runs fmt, check and release build with `--locked`.
It preserves Arch's stack-size workaround and upstream justfile linker/tokio flags,
but invokes Cargo directly so `just` is not a build prerequisite. `cargo`, `git` and
`lld` remain build requirements. Standard Arch makepkg stripping is retained;
`!debug` and `!lto` make the single-payload intent explicit. No dependencies are
vendored or upgraded.

`package()` installs exactly one executable. There are no service units, desktop
entries, autostarts, environment files, profile edits or package scriptlets.
The upstream executable/source and rendering patches are GPL-3.0-only; metadata
preserves that license. This project distributes the pinned recipe and source
patches with upstream attribution, not an unrelated theme license for the daemon.

## Build and inspect

Recommended from the repository root:

```sh
bash scripts/notification-package-test.sh build
bash scripts/notification-package-test.sh status
```

The helper creates a fresh workspace below `/tmp/cosmic-refined-notification-package`,
copies the recipe and both patches there, and invokes `makepkg --cleanbuild` without
`--syncdeps` or `--install`. Missing build prerequisites stop the build; none are
installed automatically. It verifies the archive identity and allowlisted payload,
then prints package and packaged-binary SHA256 values. It records the last successful
artifact; a failed build does not replace that pointer.

For a manual build, stage the recipe, defaults patch and canonical rendering patch
in an empty directory outside the repository:

```sh
makepkg --cleanbuild
```

The canonical patch must be copied beside PKGBUILD before invoking makepkg; it is
not duplicated permanently in this packaging directory. Do not bypass checksum checks.
Use `pacman -Qip PACKAGE` and `bsdtar -tf PACKAGE` to inspect the result. Archive
metadata `.PKGINFO`, `.BUILDINFO`, `.MTREE` is expected, alongside `usr/`, `usr/bin/`
and `usr/bin/cosmic-notifications`; no other payload or links are accepted by the helper.

See [controlled package test](../../docs/notification-package-test.md) for explicit
installation, confirmation, verification and TTY recovery. This pinned package is
for controlled testing; restore the official package before a COSMIC stack upgrade
unless the custom package has been revalidated for that stack.

## Build verification

The complete recipe was built successfully with makepkg in a fresh temporary build
workspace. Restricted DNS blocked the initial network source retrieval; a verified
local upstream Git mirror and writable copies of existing Cargo caches were then
used with `makepkg --cleanbuild --holdver` and Cargo offline resolution. `--holdver`
avoided refreshing the pinned mirror; all three source/patch checksums still passed.
Native-only fetch avoided uncached non-Linux dependencies without changing Cargo.lock.
No checksum, dependency or signature safeguard was disabled, and no packages were
installed to obtain prerequisites.

`cargo fmt --all -- --check`, `cargo check --locked` and
`cargo build --locked --release` passed. Cargo.lock verification passed. The three
warnings were the pre-existing unused Surface variant and two elided-lifetime
warnings in upstream code, not new patch errors. The packaged archive passed
identity/dependency/license and payload validation: one regular executable, no
links, no install script and no unexpected paths. No clean-chroot tool was available;
this validates a native Arch build, not an independently reproduced distribution
build or a live graphical session. The stock executable's checksum remained unchanged.

The local package is unsigned. If your configured pacman policy requires signed
local packages, sign it with your trusted packaging key; do not weaken that policy.
