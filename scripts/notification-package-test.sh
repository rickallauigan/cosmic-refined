#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Explicit host package transactions only; never signal COSMIC processes.
set -euo pipefail
umask 077
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=${COSMIC_REFINED_PACKAGE_WORKDIR:-/tmp/cosmic-refined-notification-package}
cache=/var/cache/pacman/pkg
stock=/usr/bin/cosmic-notifications
stock_sha=6ed809b720aa26676043acec96811b0dded10054b2e1c54f1cb15df8ced929d7
name=cosmic-notifications-refined
version=1:1.9.0-1
proc_root=/proc
package=
rollback=

say() { printf '%s\n' "$*"; }
fail() { say "REFUSED: $*" >&2; return 1; }
checksum() { sha256sum -- "$1" | awk '{print $1}'; }
regular_user() { [[ $EUID != 0 ]] || { fail 'Run this helper as your regular user; it invokes sudo only for an explicitly confirmed pacman transaction.'; return 1; }; }
private_work() {
    [[ $work = /tmp/* || $work = "${HOME:?}/"* ]] || { fail 'Build workspace must be under /tmp or your home.'; return 1; }
    [[ $work != *$'\n'* && $work != */../* && $work != */./* ]] || { fail 'Invalid workspace path.'; return 1; }
    local path=$work
    while [[ $path != /tmp && $path != "$HOME" ]]; do
        [[ ! -L $path ]] || { fail "Symlinked workspace ancestor: $path"; return 1; }
        [[ ! -e $path || -O $path ]] || { fail "Workspace ancestor owned by another user: $path"; return 1; }
        path=${path%/*}
    done
    mkdir -p -- "$work"
}
field() { awk -F ' = ' -v key="$2" '$1==key {print $2}' "$1"; }
validate_package() {
    [[ -f $package && ! -L $package ]] || { fail 'Missing or symlinked package.'; return 1; }
    local info files entry mode binary_count=0
    info=$(mktemp); files=$(mktemp)
    if ! bsdtar -xOf "$package" .PKGINFO > "$info" || ! bsdtar -tf "$package" > "$files"; then
        rm -f -- "$info" "$files"; fail 'Cannot inspect package archive.'; return 1
    fi
    local expected_dependencies
    expected_dependencies=$(printf '%s\n' cosmic-icon-theme glibc libgcc libxkbcommon wayland | LC_ALL=C sort)
    if [[ $(field "$info" pkgname) != "$name" || $(field "$info" pkgver) != "$version" || $(field "$info" arch) != x86_64 || $(field "$info" provides) != cosmic-notifications=1:1.9.0 || $(field "$info" conflict) != cosmic-notifications || $(field "$info" license) != GPL-3.0-only || $(field "$info" depend | LC_ALL=C sort) != "$expected_dependencies" ]]; then
        rm -f -- "$info" "$files"; fail 'Package identity/provides/conflicts mismatch.'; return 1
    fi
    local -A seen=()
    # Refusal removes temporary listings after their open descriptor is no longer needed.
    # shellcheck disable=SC2094
    while IFS= read -r entry; do
        if [[ -n ${seen[$entry]:-} ]]; then rm -f -- "$info" "$files"; fail 'Duplicate archive entry.'; return 1; fi
        seen[$entry]=1
        case $entry in
            .PKGINFO|.BUILDINFO|.MTREE|usr/|usr/bin/) ;;
            usr/bin/cosmic-notifications) binary_count=$((binary_count+1)) ;;
            *) rm -f -- "$info" "$files"; fail "Unexpected archive path: $entry"; return 1 ;;
        esac
    done < "$files"
    rm -f -- "$info" "$files"
    [[ $binary_count = 1 ]] || { fail 'Package must contain exactly one notification binary.'; return 1; }
    while IFS= read -r entry; do
        mode=${entry:0:1}
        [[ $mode = '-' || $mode = d ]] || { fail 'Archive contains a link or special file.'; return 1; }
        if [[ ${entry##* } = usr/bin/cosmic-notifications ]]; then
            [[ $mode = '-' && ${entry:3:1} = x ]] || { fail 'Notification payload must be an executable regular file.'; return 1; }
        fi
    done < <(bsdtar -tvf "$package")
}
binary_checksum() { bsdtar -xOf "$package" usr/bin/cosmic-notifications | sha256sum | awk '{print $1}'; }
choose_rollback() {
    # A stock signed cache is preferable to a network transaction. Pacman verifies it as root.
    rollback=
    local candidate
    for candidate in "$cache/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst" "$cache"/cosmic-notifications-*.pkg.tar.zst; do
        [[ -f $candidate && ! -L $candidate && -f $candidate.sig ]] || continue
        if [[ -r $candidate ]]; then
            local metadata
            metadata=$(pacman -Qp "$candidate" 2>/dev/null) || continue
            [[ $metadata = 'cosmic-notifications '* ]] || continue
        elif [[ ${candidate##*/} != cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst ]]; then
            continue # Do not guess the identity of other unreadable cache files.
        fi
        rollback=$candidate
        return
    done
    pacman -Si extra/cosmic-notifications >/dev/null || { fail 'No signed stock cache or official repository rollback metadata available.'; return 1; }
}
print_rollback() {
    if [[ -n $rollback ]]; then printf 'Rollback: sudo pacman -U -- %q\n' "$rollback";
    else say 'Rollback: sudo pacman -S extra/cosmic-notifications (requires repository/network availability)'; fi
}
confirm() {
    local reply
    printf 'Type %s to confirm this package transaction: ' "$1"
    IFS= read -r reply || { fail 'Confirmation was not supplied.'; return 1; }
    [[ $reply = "$1" ]] || { fail 'Transaction canceled.'; return 1; }
}
build() {
    regular_user
    for tool in makepkg git cargo bsdtar sha256sum; do command -v "$tool" >/dev/null || { fail "Missing build tool: $tool"; return 1; }; done
    private_work
    local workspace
    workspace=$(mktemp -d "$work/build.XXXXXXXX")
    mkdir -p "$workspace/packaging/arch" "$workspace/out"
    cp "$repo/packaging/arch/PKGBUILD" "$repo/packaging/arch/refined-package-defaults.patch" "$workspace/packaging/arch/"
    cp "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch" "$workspace/packaging/arch/"
    say "Building only, without root or dependency installation: $workspace"
    (
        cd -- "$workspace/packaging/arch"
        export BUILDDIR="$workspace/build" SRCDEST="$workspace/source-cache" PKGDEST="$workspace/out"
        unset CARGO_TARGET_DIR GIT_CONFIG_PARAMETERS GIT_CONFIG GIT_DIR GIT_WORK_TREE
        # Match the center helper: HTTPS fetching only in this build subprocess.
        export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0
        export CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_NET_OFFLINE=false
        mkdir -p "$BUILDDIR" "$SRCDEST"
        makepkg --cleanbuild --noconfirm
    )
    record_build "$workspace"
}
record_build() {
    local workspace=$1 pointer
    [[ $workspace = "$work/"* && -d $workspace && ! -L $workspace ]] || { fail 'Build record outside workspace.'; return 1; }
    local -a artifacts
    mapfile -t artifacts < <(find "$workspace/out" -maxdepth 1 -type f -name "$name-*.pkg.tar.*" ! -name '*.sig' | sort)
    [[ ${#artifacts[@]} = 1 ]] || { fail 'Expected exactly one built package.'; return 1; }
    package=${artifacts[0]}
    validate_package
    checksum "$package" > "$workspace/package.sha256"
    binary_checksum > "$workspace/binary.sha256"
    pacman -Qi cosmic-notifications > "$workspace/stock-package.txt" 2>/dev/null || true
    [[ ! -f $stock ]] || checksum "$stock" > "$workspace/prebuild-stock.sha256"
    # Publish a successfully validated artifact atomically. Failed builds keep the previous pointer.
    [[ ! -L $work/latest-package ]] || { fail 'Symlinked artifact pointer.'; return 1; }
    pointer=$(mktemp "$work/latest.XXXXXXXX")
    printf '%s\n' "$package" > "$pointer"
    mv -- "$pointer" "$work/latest-package"
    say "Package: $package"
    say "Package SHA256: $(checksum "$package")"
    say "Packaged binary SHA256: $(binary_checksum)"
    say 'No installation occurred. Next: explicitly run this helper with install on the host.'
}
load_built() {
    private_work
    [[ -f $work/latest-package && ! -L $work/latest-package ]] || { fail 'Build a package with this helper first.'; return 1; }
    package=$(cat "$work/latest-package")
    [[ $package = "$work/"* && $package != */../* && $package != *$'\n'* ]] || { fail 'Artifact pointer outside build workspace.'; return 1; }
    local manifest=${package%/out/*}
    [[ -f $manifest/package.sha256 && ! -L $manifest/package.sha256 && $(checksum "$package") = "$(cat "$manifest/package.sha256")" ]] || { fail 'Built package checksum changed.'; return 1; }
    validate_package
}
verify_stock_installation() {
    local pkg v
    for pkg in cosmic-session cosmic-comp cosmic-notifications; do
        v=$(pacman -Q "$pkg")
        [[ $v =~ ^${pkg}\ ([0-9]+:)?1\.9\.0(-[0-9]+)?$ ]] || { fail "Incompatible installed package: $v"; return 1; }
    done
    [[ -x $stock && ! -L $stock && $(pacman -Qoq "$stock") = cosmic-notifications && $(checksum "$stock") = "$stock_sha" ]] || { fail 'Stock executable ownership/checksum mismatch.'; return 1; }
}
install_package() {
    regular_user
    load_built
    verify_stock_installation
    choose_rollback
    say "Install package: $package"
    say "Package SHA256: $(checksum "$package")"
    print_rollback
    say 'Pacman will replace stock with the conflicting Refined package. No daemon restart is performed.'
    confirm INSTALL
    # Record rollback selection before the transaction; no install hook is used.
    local manifest=${package%/out/*}
    { print_rollback; say 'After rollback, choose a new login manually; never kill the supervised daemon.'; } > "$manifest/rollback.txt"
    sudo pacman -U -- "$package"
    say 'Package transaction completed. Choose when to log out/in to start the new binary.'
}
restore_stock() {
    regular_user
    choose_rollback
    print_rollback
    say 'Pacman may ask to remove cosmic-notifications-refined because it conflicts with stock.'
    confirm RESTORE
    if [[ -n $rollback ]]; then sudo pacman -U -- "$rollback";
    else sudo pacman -S extra/cosmic-notifications; fi
    say 'Stock package restored. Choose when to log out/in; the current daemon was not signaled.'
}
status() {
    if pacman -Q "$name" 2>/dev/null; then say 'Installed package state: Refined (cards default on)';
    elif pacman -Q cosmic-notifications 2>/dev/null; then say 'Installed package state: official/stock name (verify repository provenance separately)';
    else say 'Installed package state: neither package found'; fi
    [[ ! -f $stock ]] || say "Installed binary SHA256: $(checksum "$stock")"
    local entry exe comm count=0
    for entry in "$proc_root"/[0-9]*; do
        [[ -d $entry && -O $entry ]] || continue
        exe=$(readlink -- "$entry/exe" 2>/dev/null || true)
        comm=$(cat "$entry/comm" 2>/dev/null || true)
        [[ $exe = "$stock" || $exe = "$stock (deleted)" || $comm = cosmic-notifica ]] || continue
        count=$((count+1))
        say "Current daemon PID: ${entry##*/}; executable: ${exe:-unreadable/exited}"
    done
    say "Current daemon candidates: $count (run on host; package state is distinct from running binary state)"
    [[ ! -f $work/latest-package ]] || say "Last built package: $(cat "$work/latest-package")"
}
main() {
    [[ $# = 1 ]] || { say 'Usage: notification-package-test.sh build|status|install|restore-stock' >&2; return 2; }
    case $1 in build) build ;; status) status ;; install) install_package ;; restore-stock) restore_stock ;; *) fail 'Unknown command.'; return 2 ;; esac
}
if [[ ${BASH_SOURCE[0]} = "$0" ]]; then main "$@"; fi
