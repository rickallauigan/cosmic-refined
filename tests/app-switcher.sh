#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/source/src"
original="$repo/tests/fixtures/cosmic-launcher-1.9.0/app.rs"
patch="$repo/switcher/patches/cosmic-launcher-1.9.0-refined-switcher.patch"
cp "$original" "$temporary/source/src/app.rs"
git -C "$temporary/source" apply --check "$patch"
git -C "$temporary/source" apply "$patch"
rustfmt --edition 2024 --config skip_children=true --check "$temporary/source/src/app.rs"
python3 - "$repo" "$temporary/source/src/app.rs" <<'PY'
import hashlib, pathlib, re, sys
repo=pathlib.Path(sys.argv[1]); updated=pathlib.Path(sys.argv[2]).read_text()
original=(repo/'tests/fixtures/cosmic-launcher-1.9.0/app.rs').read_text()
# Remove only the presentation additions; every other byte must remain native.
restored=re.sub(r'    // Window-only presentation\..*?(?=    fn layer_padding)', '', updated, flags=re.S)
restored=restored.replace('                anchor: if app.alt_tab {\n                    Anchor::empty()\n                } else {\n                    Anchor::TOP\n                },','                anchor: Anchor::TOP,')
restored=restored.replace('!self.alt_tab && self.core.system_theme()', 'self.core.system_theme()')
restored=restored.replace('        if self.alt_tab {\n            return IcedMargin::default();\n        }\n','')
restored=restored.replace('            if self.alt_tab {\n                return self.refined_switcher();\n            }\n','')
assert restored == original, 'Unexpected change to native launcher/state/activation/subscriptions'
for token in ['const PAGE_SIZE: usize = 4;', '.size(48)', 'radius: 18.0.into()', 'Message::Activate(Some(i))', 'Message::Context(i)', 'if !self.alt_tab &&']:
    assert token in updated, token
recipe=(repo/'packaging/arch/app-switcher/PKGBUILD').read_text()
assert '_revision=cc3d42bcc8fbcb67e6312f2766394e18b4d937d5' in recipe
for file in [repo/'switcher/patches/cosmic-launcher-1.9.0-refined-switcher.patch',repo/'packaging/arch/app-switcher/arch-lto.patch']:
    assert hashlib.blake2b(file.read_bytes()).hexdigest() in recipe
assert 'provides=("cosmic-launcher=${epoch}:${pkgver}")' in recipe
assert 'conflicts=(cosmic-launcher)' in recipe
assert len(re.findall(r'^diff --git ', (repo/'switcher/patches/cosmic-launcher-1.9.0-refined-switcher.patch').read_text(), re.M)) == 1
for script in ['app-switcher-package-test.sh','app-switcher-host-validate.sh']:
    source=(repo/'scripts'/script).read_text()
    assert not re.search(r'\b(kill|pkill|killall|reboot|shutdown|loginctl|systemctl)\b',source)
    assert not re.search(r'\.(zlogin|zprofile|profile)|environment\.d|Vicinae|vicinae',source)
print('PASS: rendering-only boundary, native state/activation/subscriptions, pins and no session controls')
PY
git -C "$temporary/source" apply --reverse --check "$patch"
git -C "$temporary/source" apply --reverse "$patch"
cmp "$original" "$temporary/source/src/app.rs"
sed -i 's/anchor: Anchor::TOP,/anchor: Anchor::BOTTOM,/' "$temporary/source/src/app.rs"
if git -C "$temporary/source" apply --check "$patch" >/dev/null 2>&1; then exit 1; fi
# Synthetic stock inventory: never inspect or extract installed host binaries.
python3 - "$repo" "$temporary" <<'PY'
import pathlib, sys
repo,tmp=map(pathlib.Path,sys.argv[1:]); root=tmp/'payload'
for entry in (repo/'packaging/arch/app-switcher/stock-files.txt').read_text().splitlines():
    target=root/entry
    if entry.endswith('/'): target.mkdir(parents=True,exist_ok=True)
    else:
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(b'\x7fELFfixture' if entry=='usr/bin/cosmic-launcher' else b'fixture')
(root/'usr/bin/cosmic-launcher').chmod(0o755)
(root/'.PKGINFO').write_text('pkgname = cosmic-switcher-refined\npkgver = 1:1.9.0-1\narch = x86_64\nlicense = GPL-3.0-only\nprovides = cosmic-launcher=1:1.9.0\nconflict = cosmic-launcher\n'+''.join('depend = '+x+'\n' for x in 'cosmic-icon-theme libgcc glibc libxkbcommon pop-launcher wayland'.split()))
PY
(cd "$temporary/payload"; bsdtar -cf "$temporary/fixture.pkg.tar" .PKGINFO usr)
(
    source "$repo/scripts/app-switcher-package-test.sh"
    cache="$temporary/cache"; mkdir -p "$cache"
    proc_root="$temporary/proc"; mkdir -p "$proc_root/123"
    printf 'cosmic-launcher\0' > "$proc_root/123/cmdline"
    ln -s /usr/bin/cosmic-launcher "$proc_root/123/exe"
    # All transactions use the sudo mock below, not the external sudo command.
    # shellcheck disable=SC2032
    pacman() {
        case "$*" in
            '-Q cosmic-launcher') echo "cosmic-launcher ${mock_version:-1:1.9.0-1}";;
            '-Q cosmic-session') echo 'cosmic-session 1:1.9.0-1';;
            *) echo cosmic-launcher;;
        esac
    }
    sha256sum() {
        if [[ ${1:-} = /usr/bin/cosmic-launcher ]]; then echo "$stock_sha  $1";
        else command sha256sum "$@"; fi
    }
    sudo() { touch "$temporary/transaction"; return 99; }
    # Invoked inside host_build: the subprocess-local Git environment is intentional.
    # shellcheck disable=SC2317,SC2031
    makepkg() {
        [[ $* = '--cleanbuild --noconfirm' && $GIT_CONFIG_GLOBAL = /dev/null && $GIT_CONFIG_COUNT = 0 ]]
        cp "$temporary/fixture.pkg.tar" "$PWD/cosmic-switcher-refined-1:1.9.0-1-x86_64.pkg.tar.zst"
    }
    validate_package "$temporary/fixture.pkg.tar" >/dev/null
    main status > "$temporary/status"
    grep -q 'Native switcher PID: 123' "$temporary/status"
    [[ $(restore_command) = 'sudo pacman -S extra/cosmic-launcher' ]]
    touch "$cache/cosmic-launcher-1:1.9.0-1-x86_64.pkg.tar.zst" "$cache/cosmic-launcher-1:1.9.0-1-x86_64.pkg.tar.zst.sig"
    [[ $(restore_command) = *'pacman -U'* ]]
    if main install "$temporary/fixture.pkg.tar" <<< CANCEL >/dev/null 2>&1; then exit 1; fi
    if main restore-stock <<< CANCEL >/dev/null 2>&1; then exit 1; fi
    [[ ! -e $temporary/transaction ]]
    mock_version=1:1.10.0-1
    if main build >/dev/null 2>&1; then exit 1; fi
    unset mock_version
    main build > "$temporary/build"
    grep -q 'Package:' "$temporary/build"
    rm -rf -- "$(sed -n 's/^Package: //p' "$temporary/build" | xargs dirname)"
    touch "$temporary/payload/usr/unexpected"
    (cd "$temporary/payload"; bsdtar -cf "$temporary/bad.pkg.tar" .PKGINFO usr)
    if validate_package "$temporary/bad.pkg.tar" >/dev/null 2>&1; then exit 1; fi
)
echo 'PASS: apply/reverse/drift, formatting, package inventory, mocked build/status and confirmation/rollback safety'
