#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Package transactions only; no process control or graphical-session changes.
set -euo pipefail
umask 077
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stock_sha=621aaf544003357b53bf824a738021b37c72293deacc7c7ec04043306794af14
name=cosmic-applets-refined
cache=/var/cache/pacman/pkg
proc_root=/proc
validate_package() {
    local package=$1 listing info dependencies
    [[ -f $package && ! -L $package ]] || return 1
    info=$(bsdtar -xOf "$package" .PKGINFO)
    [[ $(awk -F ' = ' '$1=="pkgname"{print $2}' <<< "$info") = "$name" ]] || return 1
    [[ $(awk -F ' = ' '$1=="pkgver"{print $2}' <<< "$info") = 1:1.9.0-1 ]] || return 1
    [[ $(awk -F ' = ' '$1=="provides"{print $2}' <<< "$info") = cosmic-applets=1:1.9.0 ]] || return 1
    [[ $(awk -F ' = ' '$1=="conflict"{print $2}' <<< "$info") = cosmic-applets ]] || return 1
    [[ $(awk -F ' = ' '$1=="arch"{print $2}' <<< "$info") = x86_64 ]] || return 1
    [[ $(awk -F ' = ' '$1=="license"{print $2}' <<< "$info") = GPL-3.0-only ]] || return 1
    dependencies=$(awk -F ' = ' '$1=="depend"{print $2}' <<< "$info" | LC_ALL=C sort)
    [[ $dependencies = "$(printf '%s\n' cosmic-icon-theme dbus libgcc glibc libinput libpipewire libpulse libxkbcommon systemd-libs util-linux | LC_ALL=C sort)" ]] || return 1
    [[ $(awk -F ' = ' '$1=="replaces"{print $2}' <<< "$info") = '' ]] || return 1
    listing=$(bsdtar -tf "$package")
    [[ $(printf '%s\n' "$listing" | LC_ALL=C sort | uniq -d) = '' ]] || return 1
    diff -u "$repo/packaging/arch/notification-center/stock-files.txt" \
        <(printf '%s\n' "$listing" | sed '/^\.PKGINFO$/d; /^\.BUILDINFO$/d; /^\.MTREE$/d' | LC_ALL=C sort) || return 1
    # Every symlink must retain the stock multicall executable target.
    local entry
    while IFS= read -r entry; do
        if [[ $entry = *' usr/bin/cosmic-applets' ]]; then
            [[ ${entry:0:1} = - && ${entry:3:1} = x ]] || return 1
        fi
        case ${entry:0:1} in
            -|d) ;;
            l) [[ $entry = *' -> /usr/bin/cosmic-applets' ]] || return 1 ;;
            *) return 1 ;;
        esac
    done < <(bsdtar -tvf "$package")
    [[ $(bsdtar -xOf "$package" usr/bin/cosmic-applets | { dd bs=1 count=4 status=none; cat > /dev/null; } | od -An -tx1) = ' 7f 45 4c 46' ]] || return 1
    printf 'Applet SHA256: '
    bsdtar -xOf "$package" usr/bin/cosmic-applets | sha256sum
}
verify_stock() {
    local expected_owner=cosmic-applets
    if [[ $(pacman -Q cosmic-applets 2>/dev/null || true) != 'cosmic-applets 1:1.9.0-1' ]]; then
        [[ ${1:-} = allow-refined && $(pacman -Q cosmic-applets-refined 2>/dev/null || true) = 'cosmic-applets-refined 1:1.9.0-1' ]] || { echo 'REFUSED: requires compatible COSMIC applets 1:1.9.0-1.' >&2; return 1; }
        expected_owner=cosmic-applets-refined
    fi
    [[ $(pacman -Qoq /usr/bin/cosmic-applets) = "$expected_owner" && $(pacman -Qoq /usr/bin/cosmic-applet-notifications) = "$expected_owner" ]] || { echo 'REFUSED: unexpected applet package ownership.' >&2; return 1; }
}
print_rollbacks() {
    printf 'Offline rollback (requires cached stock archive and signature): sudo pacman -U %q\n' "$cache/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst"
    echo 'Online rollback: sudo pacman -S extra/cosmic-applets'
    printf 'Preferred rollback: '; restore_command
}
host_build() (
    # Public HTTPS sources: isolate Git configuration in this subprocess only.
    # Ignore inherited command-line configuration as well as the global SSH rewrite.
    unset GIT_CONFIG_PARAMETERS GIT_CONFIG GIT_DIR GIT_WORK_TREE CARGO_TARGET_DIR
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0
    export CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_NET_OFFLINE=false
    export BUILDDIR="$1/build" SRCDEST="$1/sources" PKGDEST="$1"
    cd -- "$1"
    makepkg --cleanbuild --noconfirm
)
restore_command() {
    local archive="$cache/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst"
    if [[ -f $archive && -f $archive.sig ]]; then
        printf 'sudo pacman -U %q\n' "$archive"
    else
        printf 'sudo pacman -S extra/cosmic-applets\n'
    fi
}
main() {
    local command=${1:-status} package directory answer archive
    case $command in
        build)
            [[ $EUID != 0 ]] || { echo 'Run build as a regular user.' >&2; return 1; }
            verify_stock allow-refined || return 1
            directory=$(mktemp -d /tmp/cosmic-refined-center-package.XXXXXXXX)
            cp "$repo/packaging/arch/notification-center/PKGBUILD" "$directory/"
            cp "$repo/notifications/patches/cosmic-applets-1.9.0-refined-notification-center.patch" "$directory/"
            host_build "$directory" || return 1
            package="$directory/$name-1:1.9.0-1-x86_64.pkg.tar.zst"
            validate_package "$package" || return 1
            sha256sum "$package"
            printf 'Package: %s\n' "$package"; print_rollbacks
            ;;
        status)
            pacman -Q cosmic-applets cosmic-applets-refined 2>/dev/null || true
            pacman -Qo /usr/bin/cosmic-applets
            sha256sum /usr/bin/cosmic-applets
            local process executable command_line first
            for process in "$proc_root"/[0-9]*; do
                [[ -O $process && -r $process/cmdline ]] || continue
                first=
                IFS= read -r -d '' first < "$process/cmdline" || true
                [[ ${first##*/} = cosmic-applet-notifications ]] || continue
                executable=$(readlink "$process/exe" 2>/dev/null || true)
                command_line=$(tr '\0' ' ' < "$process/cmdline")
                printf 'Center PID: %s; executable: %s; command: %s\n' "${process##*/}" "$executable" "$command_line"
            done
            echo 'Package state does not establish which code is loaded in the current session.'
            ;;
        install)
            [[ $# = 2 && $EUID != 0 ]] || { echo 'Usage: notification-center-package-test.sh install PACKAGE' >&2; return 2; }
            package=$(readlink -f -- "$2") || return 1
            validate_package "$package" || return 1
            verify_stock || return 1
            [[ $(sha256sum /usr/bin/cosmic-applets | awk '{print $1}') = "$stock_sha" ]] || return 1
            [[ $(pacman -Q cosmic-session) = 'cosmic-session 1:1.9.0-1' ]] || return 1
            echo "Whole applets replacement: $package"
            print_rollbacks
            read -r -p 'Type INSTALL to confirm the pacman transaction: ' answer
            [[ $answer = INSTALL ]] || return 1
            sudo pacman -U -- "$package" || return 1
            echo 'Log out and back in manually when ready. No processes were restarted.'
            ;;
        restore-stock)
            [[ $EUID != 0 ]] || return 1
            print_rollbacks
            read -r -p 'Type RESTORE to confirm: ' answer
            [[ $answer = RESTORE ]] || return 1
            archive="$cache/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst"
            if [[ -f $archive && -f $archive.sig ]]; then sudo pacman -U -- "$archive" || return 1
            else sudo pacman -S extra/cosmic-applets || return 1; fi
            echo 'Log out and back in manually when ready. Refined banners remain installed.'
            ;;
        *) echo 'Usage: notification-center-package-test.sh {build|status|install PACKAGE|restore-stock}' >&2; return 2 ;;
    esac
}
if [[ ${BASH_SOURCE[0]} = "$0" ]]; then main "$@"; fi
