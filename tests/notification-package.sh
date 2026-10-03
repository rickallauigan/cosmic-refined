#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Offline recipe, source-policy and transaction fixtures. No pacman/sudo/process mutations.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/source/src" "$fixture/cache" "$fixture/proc/1234"
cp "$repo/tests/fixtures/cosmic-notifications-1.9.0-app.rs" "$fixture/source/src/app.rs"
cp "$repo/tests/fixtures/cosmic-notifications-1.9.0-main.rs" "$fixture/source/src/main.rs"
(
    source "$repo/packaging/arch/PKGBUILD"
    [[ $pkgname = cosmic-notifications-refined && $epoch = 1 && $pkgver = 1.9.0 && $pkgrel = 1 ]]
    [[ ${provides[*]} = cosmic-notifications=1:1.9.0 && ${conflicts[*]} = cosmic-notifications && ${#source[@]} = 3 ]]
    [[ ${source[0]} = *'#commit=aa4dac2702506395ab76da1f6755e03b2ccb0db8' ]]
    [[ $(b2sum "$repo/notifications/patches/${source[1]}" | awk '{print $1}') = "${b2sums[1]}" ]]
    [[ $(b2sum "$repo/packaging/arch/${source[2]}" | awk '{print $1}') = "${b2sums[2]}" ]]
)
(
    cd "$fixture/source"
    git apply --check "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch"
    git apply "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch"
    git apply --check "$repo/packaging/arch/refined-package-defaults.patch"
    git apply "$repo/packaging/arch/refined-package-defaults.patch"
    rustfmt --edition 2024 --config skip_children=true --check src/app.rs src/main.rs src/refined_cards.rs
    rustc --edition 2024 --test src/refined_cards.rs -o policy-tests
    ./policy-tests
    printf '#[path="%s"] mod cards;\nfn main() { let o=cards::Options::from_env(); println!("{} {} {}",o.enabled,o.urgency_accent,o.width()); }\n' "$fixture/source/src/refined_cards.rs" > "$fixture/policy.rs"
    rustc --edition 2024 -A dead_code "$fixture/policy.rs" -o "$fixture/policy"
    [[ $(env -u COSMIC_REFINED_NOTIFICATION_CARDS -u COSMIC_REFINED_NOTIFICATION_URGENCY "$fixture/policy") = 'true true 380' ]]
    [[ $(COSMIC_REFINED_NOTIFICATION_CARDS=0 COSMIC_REFINED_NOTIFICATION_URGENCY=0 "$fixture/policy") = 'false false 300' ]]
    git apply --reverse --check "$repo/packaging/arch/refined-package-defaults.patch"
    git apply --reverse "$repo/packaging/arch/refined-package-defaults.patch"
    git apply --reverse "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch"
    cmp src/app.rs "$repo/tests/fixtures/cosmic-notifications-1.9.0-app.rs"
)
helper=$repo/scripts/notification-package-test.sh
cat > "$fixture/harness" <<'HARNESS'
set -euo pipefail
source "$helper"
work=$fixture/work
cache=$fixture/cache
stock=$fixture/stock
stock_sha=$(checksum "$stock")
proc_root=$fixture/proc
pacman() {
    case $1 in
        -Qi) printf 'fixture official metadata\n' ;;
        -Qoq) printf 'cosmic-notifications\n' ;;
        -Q)
            [[ $2 != cosmic-notifications-refined || ${installed_refined:-0} = 1 ]] || return 1
            printf '%s 1:1.9.0-1\n' "$2" ;;
        -Qp) printf 'cosmic-notifications 1:1.9.0-1\n' ;;
        -Si) [[ ${repo_available:-1} = 1 ]] ;;
        *) printf 'Unexpected pacman call\n' >&2; return 1 ;;
    esac
}
sudo() { printf '%s\n' "$*" >> "$fixture/transactions"; }
makepkg() {
    [[ $* = '--cleanbuild --noconfirm' && -z ${CARGO_TARGET_DIR:-} ]]
    [[ $GIT_CONFIG_GLOBAL = /dev/null && $GIT_CONFIG_COUNT = 0 && $CARGO_NET_GIT_FETCH_WITH_CLI = true && $CARGO_NET_OFFLINE = false ]]
    printf '%s\n' "$*" > "$fixture/makepkg-args"
    [[ -f cosmic-notifications-1.9.0-refined-cards.patch && -f refined-package-defaults.patch ]]
    mkdir -p "$fixture/archive/usr/bin"
    cp "$stock" "$fixture/archive/usr/bin/cosmic-notifications"
    cat > "$fixture/archive/.PKGINFO" <<'INFO'
pkgname = cosmic-notifications-refined
pkgver = 1:1.9.0-1
arch = x86_64
license = GPL-3.0-only
depend = cosmic-icon-theme
depend = libgcc
depend = glibc
depend = libxkbcommon
depend = wayland
provides = cosmic-notifications=1:1.9.0
conflict = cosmic-notifications
INFO
    : > "$fixture/archive/.BUILDINFO"
    : > "$fixture/archive/.MTREE"
    bsdtar -cf "$PKGDEST/cosmic-notifications-refined-1:1.9.0-1-x86_64.pkg.tar.zst" -C "$fixture/archive" .PKGINFO .BUILDINFO .MTREE usr
}
case $scenario in
    reject-extra)
        package=$(cat "$work/latest-package")
        mkdir -p "$fixture/archive/usr/share/applications"
        printf 'forbidden\n' > "$fixture/archive/usr/share/applications/test.desktop"
        bsdtar -cf "$fixture/extra.pkg.tar" -C "$fixture/archive" .PKGINFO .BUILDINFO .MTREE usr
        package=$fixture/extra.pkg.tar
        validate_package ;;
    reject-link)
        rm -rf "$fixture/archive/usr/share"
        rm "$fixture/archive/usr/bin/cosmic-notifications"
        ln -s /etc/passwd "$fixture/archive/usr/bin/cosmic-notifications"
        bsdtar -cf "$fixture/link.pkg.tar" -C "$fixture/archive" .PKGINFO .BUILDINFO .MTREE usr
        package=$fixture/link.pkg.tar
        validate_package ;;
    reject-drift) printf 'changed\n' >> "$(cat "$work/latest-package")"; install_package ;;
    *) main "$scenario" ;;
esac
HARNESS
printf '#!/bin/sh\n' > "$fixture/stock"
chmod 700 "$fixture/stock"
ln -s "$fixture/stock" "$fixture/proc/1234/exe"
printf 'cosmic-notifica\n' > "$fixture/proc/1234/comm"
export fixture helper
run() { scenario=$1 bash "$fixture/harness"; }
CARGO_TARGET_DIR=$fixture/must-not-write run build
[[ ! -e $fixture/transactions && ! -e $fixture/must-not-write ]]
run status > "$fixture/status"
grep -q 'Installed package state: official/stock' "$fixture/status"
grep -q 'Current daemon PID: 1234' "$fixture/status"
installed_refined=1 run status > "$fixture/refined-status"
grep -q 'Installed package state: Refined' "$fixture/refined-status"
# A signed stock cache is present for deterministic offline rollback.
printf 'official cache fixture\n' > "$fixture/cache/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst"
printf 'signature fixture\n' > "$fixture/cache/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst.sig"
if printf 'no\n' | run install > "$fixture/cancel.log" 2>&1; then echo 'Expected canceled install' >&2; exit 1; fi
[[ ! -e $fixture/transactions ]]
printf 'INSTALL\n' | run install
[[ $(wc -l < "$fixture/transactions") = 1 ]]
grep -q 'pacman -U -- .*cosmic-notifications-refined' "$fixture/transactions"
if printf 'no\n' | run restore-stock > "$fixture/cancel-restore.log" 2>&1; then echo 'Expected canceled restore' >&2; exit 1; fi
[[ $(wc -l < "$fixture/transactions") = 1 ]]
printf 'RESTORE\n' | run restore-stock
[[ $(wc -l < "$fixture/transactions") = 2 ]]
grep -q "pacman -U -- $fixture/cache/cosmic-notifications-1:1.9.0-1-x86_64.pkg.tar.zst" "$fixture/transactions"
rm "$fixture/cache/"*
printf 'RESTORE\n' | run restore-stock
[[ $(tail -n 1 "$fixture/transactions") = 'pacman -S extra/cosmic-notifications' ]]
for scenario in reject-extra reject-link reject-drift; do
    if printf 'INSTALL\n' | run "$scenario" > "$fixture/refusal.log" 2>&1; then echo "Expected rejection: $scenario" >&2; exit 1; fi
done
[[ $(wc -l < "$fixture/transactions") = 3 ]]
if grep -En '^[[:space:]]*(kill|pkill|killall|systemctl|loginctl|logout|reboot|shutdown)([[:space:]]|$)' "$helper" "$repo/packaging/arch/PKGBUILD"; then echo 'Forbidden process control' >&2; exit 1; fi
if grep -En 'environment\.d|zlogin|zprofile|bash_profile|\.profile|autostart' "$helper" "$repo/packaging/arch/PKGBUILD"; then echo 'Unexpected session override' >&2; exit 1; fi
echo 'PASS: pinned recipe/patch checksums, default-on policy, archive restrictions, build/status, explicit install/restore confirmation, offline/online rollback, no session controls'
