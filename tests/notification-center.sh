#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Fixture mocks are invoked indirectly by the sourced helper; sudo is mocked.
# shellcheck disable=SC2031,SC2032,SC2329
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/cosmic-applet-notifications/src" "$temporary/cosmic-applet-notifications/i18n/en"
cp "$repo/tests/fixtures/cosmic-applets-1.9.0/lib.rs" "$temporary/cosmic-applet-notifications/src/lib.rs"
cp "$repo/tests/fixtures/cosmic-applets-1.9.0/en.ftl" "$temporary/cosmic-applet-notifications/i18n/en/cosmic_applet_notifications.ftl"
patch_file="$repo/notifications/patches/cosmic-applets-1.9.0-refined-notification-center.patch"
(cd "$temporary"; git apply --check "$patch_file"; git apply --whitespace=error "$patch_file")
rustfmt --edition 2024 --check --config skip_children=true "$temporary/cosmic-applet-notifications/src/lib.rs" "$temporary/cosmic-applet-notifications/src/refined_center.rs"
python3 - "$repo" "$temporary" <<'PY'
import pathlib,sys,re,hashlib
repo,tmp=map(pathlib.Path,sys.argv[1:])
base=(repo/'tests/fixtures/cosmic-applets-1.9.0/lib.rs').read_text()
changed=(tmp/'cosmic-applet-notifications/src/lib.rs').read_text()
local=(tmp/'cosmic-applet-notifications/src/refined_center.rs').read_text()
# State, subscriptions, grouping/order update, DND, dismissal, actions and clear-all
# are unchanged, rather than merely checking that their names still occur.
start='    fn subscription(&self)'
end='    fn view_window('
assert base[base.index(start):base.index(end)] == changed[changed.index(start):changed.index(end)]
assert base[base.index('fn duration_ago_msg'):]==changed[changed.index('fn duration_ago_msg'):]
assert 'duration_since()' in changed and 'scrollable(' in changed
assert 'Message::Dismissed(n.id)' in changed and 'Message::ActivateNotification(ids[id])' in changed
assert 'iter().rev().map(|n| n.urgency() == 2)' in changed
assert 'icon.size(32)' in changed and '.size(18)' in changed and '.size(15.0)' in changed
assert '.push_maybe(' in changed and 'refined-critical' in changed
assert 'toggle.as_ref().map(|f| f(true))' in local
assert 'toggle.as_ref().map(|f| f(false))' in local
assert 'activate.as_ref().map(|f| f(i))' in local
assert 'if !expanded && i > 0' in local and 'text::caption(more)' in local
assert '.on_press(clear)' in local and '18.0.into()' in local
assert not re.search(r'tokio|interval|sleep|Instant|SystemTime|subscription|animation|blur',local)
patch=(repo/'notifications/patches/cosmic-applets-1.9.0-refined-notification-center.patch').read_bytes()
recipe=(repo/'packaging/arch/notification-center/PKGBUILD').read_text()
assert '82e7cd814addb0641959b634227fe550374e195b' in recipe
assert hashlib.blake2b(patch).hexdigest() in recipe
assert 'pkgname=cosmic-applets-refined' in recipe
assert 'cosmic-applets=${epoch}:${pkgver}' in recipe and 'conflicts=(cosmic-applets)' in recipe
assert 'cargo check --locked' in recipe and 'cargo build --locked --release' in recipe
assert all(x.startswith('cosmic-applet-notifications/') for x in re.findall(r'^\+\+\+ b/(.*)$',patch.decode(),re.M))
helper=(repo/'scripts/notification-center-package-test.sh').read_text()
assert "answer = INSTALL" in helper and "answer = RESTORE" in helper
assert 'restore_command' in helper and 'pacman -U' in helper and 'pacman -S extra/cosmic-applets' in helper
assert not re.search(r'\b(kill|pkill|killall|reboot|shutdown|loginctl|systemctl)\b',helper)
assert not re.search(r'\.zlogin|\.profile|environment\.d|Vicinae|LD_PRELOAD',helper+recipe)
print('PASS: local style isolation; unchanged grouping/state/actions/DND/relative time; recipe pin and transaction safety')
PY
(cd "$temporary"; git apply --reverse --check "$patch_file"; git apply --reverse "$patch_file")
cmp "$temporary/cosmic-applet-notifications/src/lib.rs" "$repo/tests/fixtures/cosmic-applets-1.9.0/lib.rs"
printf '\n// drift\n' >> "$temporary/cosmic-applet-notifications/src/lib.rs"
# Full fixture checksum is the drift gate, including drift outside touched hunks.
if cmp -s "$temporary/cosmic-applet-notifications/src/lib.rs" "$repo/tests/fixtures/cosmic-applets-1.9.0/lib.rs"; then exit 1; fi
sed -i 's/text::caption(Cow::from(\&n.app_name))/text::caption("drift")/' "$temporary/cosmic-applet-notifications/src/lib.rs"
if (cd "$temporary"; git apply --check "$patch_file" 2>/dev/null); then echo 'FAIL: touched source drift accepted'; exit 1; fi
# Exercise helper status/build/confirmation without touching live config/packages.
(
    source "$repo/scripts/notification-center-package-test.sh"
    sudo() { echo 'FAIL: unconfirmed privileged transaction'; return 99; }
    pacman() { printf '%s\n' 'mock package status'; }
    sha256sum() { printf '%s\n' 'mock binary checksum'; }
    proc_root="$temporary/proc"; mkdir -p "$proc_root"
    main status > "$temporary/status"
    grep -q 'does not establish' "$temporary/status"
    main restore-stock <<< CANCEL && exit 1
    true
)
python3 - "$repo" "$temporary/payload" <<'PYFIXTURE'
import pathlib,sys
repo,root=map(pathlib.Path,sys.argv[1:]);root.mkdir()
for entry in (repo/'packaging/arch/notification-center/stock-files.txt').read_text().splitlines():
    target=root/entry
    if entry.endswith('/'): target.mkdir(parents=True,exist_ok=True)
    elif entry.startswith('usr/bin/') and entry!='usr/bin/cosmic-applets': target.symlink_to('/usr/bin/cosmic-applets')
    else:
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(b'\x7fELFfixture' if entry=='usr/bin/cosmic-applets' else b'fixture')
(root/'usr/bin/cosmic-applets').chmod(0o755)
(root/'.PKGINFO').write_text('pkgname = cosmic-applets-refined\npkgver = 1:1.9.0-1\narch = x86_64\nlicense = GPL-3.0-only\nprovides = cosmic-applets=1:1.9.0\nconflict = cosmic-applets\n'+''.join('depend = '+x+'\n' for x in 'cosmic-icon-theme dbus libgcc glibc libinput libpipewire libpulse libxkbcommon systemd-libs util-linux'.split()))
PYFIXTURE
(cd "$temporary/payload"; bsdtar -cf "$temporary/fixture.pkg.tar" .PKGINFO usr)
(
    source "$repo/scripts/notification-center-package-test.sh"
    cache="$temporary/cache"; mkdir -p "$cache"
    validate_package "$temporary/fixture.pkg.tar" > /dev/null
    [[ $(restore_command) = 'sudo pacman -S extra/cosmic-applets' ]]
    touch "$cache/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst" "$cache/cosmic-applets-1:1.9.0-1-x86_64.pkg.tar.zst.sig"
    [[ $(restore_command) = *'pacman -U'* ]]
    sudo() { touch "$temporary/transaction"; return 99; }
    pacman() { case "$*" in '-Q cosmic-applets') echo "cosmic-applets ${mock_version:-1:1.9.0-1}";; '-Q cosmic-session') echo 'cosmic-session 1:1.9.0-1';; '-Qoq /usr/bin/cosmic-applets'|'-Qoq /usr/bin/cosmic-applet-notifications') echo "${mock_owner:-cosmic-applets}";; esac; }
    sha256sum() { if [[ ${1:-} = /usr/bin/cosmic-applets ]]; then echo mismatch; else command sha256sum "$@"; fi; }
    # Installation fails closed on incompatible stock checksum before any transaction.
    if main install "$temporary/fixture.pkg.tar" <<< INSTALL > /dev/null 2>&1; then exit 1; fi
    sha256sum() { if [[ ${1:-} = /usr/bin/cosmic-applets ]]; then echo "$stock_sha"; else command sha256sum "$@"; fi; }
    if main install "$temporary/fixture.pkg.tar" <<< CANCEL > /dev/null 2>&1; then exit 1; fi
    [[ ! -e $temporary/transaction ]]
    makepkg() {
        [[ $* = '--cleanbuild --noconfirm' ]] || return 1
        [[ $GIT_CONFIG_GLOBAL = /dev/null && $GIT_CONFIG_NOSYSTEM = 1 && $GIT_CONFIG_COUNT = 0 ]] || return 1
        [[ $CARGO_NET_GIT_FETCH_WITH_CLI = true && $CARGO_NET_OFFLINE = false ]] || return 1
        [[ $(git ls-remote --get-url https://github.com/pop-os/cosmic-applets.git) = https://github.com/pop-os/cosmic-applets.git ]] || return 1
        cp "$temporary/fixture.pkg.tar" "$PWD/cosmic-applets-refined-1:1.9.0-1-x86_64.pkg.tar.zst"
    }
    printf '[url "git@github.com:"]\n    insteadOf = https://github.com/\n' > "$temporary/global.gitconfig"
    export GIT_CONFIG_GLOBAL="$temporary/global.gitconfig"
    [[ $(git ls-remote --get-url https://github.com/pop-os/cosmic-applets.git) = git@github.com:pop-os/cosmic-applets.git ]]
    mock_version=1:1.10.0-1
    if main build > /dev/null 2>&1; then exit 1; fi
    unset mock_version
    mock_owner=unrelated-package
    if main build > /dev/null 2>&1; then exit 1; fi
    unset mock_owner
    main build > "$temporary/build-result"
    (
        pacman() {
            case "$*" in
                '-Q cosmic-applets') return 1;;
                '-Q cosmic-applets-refined') echo 'cosmic-applets-refined 1:1.9.0-1';;
                '-Qoq /usr/bin/cosmic-applets'|'-Qoq /usr/bin/cosmic-applet-notifications') echo cosmic-applets-refined;;
            esac
        }
        verify_stock allow-refined
        if verify_stock > /dev/null 2>&1; then exit 1; fi
    )
    [[ $GIT_CONFIG_GLOBAL = "$temporary/global.gitconfig" ]]
    [[ $(git ls-remote --get-url https://github.com/pop-os/cosmic-applets.git) = git@github.com:pop-os/cosmic-applets.git ]]
    grep -q '^Package: /tmp/cosmic-refined-center-package.' "$temporary/build-result"
    built_directory=$(sed -n 's|^Package: \(.*\)/cosmic-applets-refined.*|\1|p' "$temporary/build-result")
    rm -rf -- "$built_directory"
    printf 'unexpected' > "$temporary/payload/usr/bin/unrelated"
    (cd "$temporary/payload"; bsdtar -cf "$temporary/bad.pkg.tar" .PKGINFO usr)
    if validate_package "$temporary/bad.pkg.tar" > /dev/null 2>&1; then exit 1; fi
)
echo 'PASS: patch apply/reverse/drift, formatting, helper build/status, strict package payload and rollback refusal'
