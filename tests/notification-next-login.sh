#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Offline legacy recovery/status fixtures. Never inspect the real host process namespace.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
helper=$repo/scripts/notification-next-login-test.sh
cat > "$fixture/harness" <<'HARNESS'
set -euo pipefail
source "$helper"
user_home=$fixture/user
stock=$fixture/stock
patched=$user_home/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined
bindir=$user_home/.local/lib/cosmic-refined/notification-next-login-bin
legacy_profile=$user_home/.zlogin
state=$user_home/xdg-state/cosmic-refined
backups=$user_home/xdg-data/cosmic-refined/notification-next-login-backups
proc_root=$fixture/proc
main "$scenario"
HARNESS
export fixture helper
run() { scenario=$1 bash "$fixture/harness"; }
mkdir -p "$fixture/user" "$fixture/proc"
printf 'unchanged stock fixture\n' > "$fixture/stock"
# New prepare must refuse with zero effects, including when called repeatedly.
for ((attempt=0; attempt<2; attempt++)); do
    if run prepare > "$fixture/prepare.log" 2>&1; then echo 'Expected blocked prepare' >&2; exit 1; fi
    [[ ! -e $fixture/user/.zlogin && ! -e $fixture/user/xdg-state && ! -e $fixture/user/.config/environment.d ]]
done
run disable
make_legacy() {
    mkdir -p "$fixture/user/xdg-state/cosmic-refined" "$fixture/user/xdg-data/cosmic-refined/notification-next-login-backups"
    backup=$(mktemp -d "$fixture/user/xdg-data/cosmic-refined/notification-next-login-backups/legacy.XXXXXXXX")
    printf '%s\n' "$backup" > "$fixture/user/xdg-state/cosmic-refined/notification-next-login-active"
    printf 'cosmic-refined-next-login-v1\n' > "$backup/format"
    printf '%s\n' "$fixture/user/.zlogin" > "$backup/profile-path"
    printf '%s\n' "$1" > "$backup/profile-existed"
    if [[ $1 = yes ]]; then
        cp -p "$fixture/user/.zlogin" "$backup/profile.before"
        cp -p "$fixture/user/.zlogin" "$backup/profile.after"
    else
        : > "$backup/profile.after"
    fi
    cat >> "$backup/profile.after" <<'PROFILE'

# BEGIN COSMIC Refined next-login notification test
if [[ ${ZSH_EXECUTION_STRING-} = "/usr/bin/start-cosmic --in-login-shell" ]]; then
    export PATH=/fixture/notification-next-login-bin:"$PATH"
fi
# END COSMIC Refined next-login notification test
PROFILE
    cp -p "$backup/profile.after" "$fixture/user/.zlogin"
    mkdir -p "$fixture/user/.local/lib/cosmic-refined/notification-next-login-bin"
    : > "$fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/.enabled"
    printf '# legacy wrapper fixture\n' > "$fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/cosmic-notifications"
    sha256sum "$fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/cosmic-notifications" | awk '{print $1}' > "$backup/wrapper.sha256"
}
printf '# original user config\n' > "$fixture/user/.zlogin"
cp "$fixture/user/.zlogin" "$fixture/original"
make_legacy yes
run disable
cmp "$fixture/user/.zlogin" "$fixture/original"
[[ -d $backup && -n $(find "$backup" -name 'profile.pre-cleanup.*' -print) ]]
run disable
# Preserve both before-block and after-block edits, including an unterminated final line.
make_legacy yes
{
    printf '# later prefix edit\n'
    cat "$fixture/user/.zlogin"
    printf '# later suffix edit without final newline'
} > "$fixture/edited"
cp "$fixture/edited" "$fixture/user/.zlogin"
{
    printf '# later prefix edit\n'
    cat "$fixture/original"
    printf '\n# later suffix edit without final newline'
} > "$fixture/expected"
run disable
cmp "$fixture/user/.zlogin" "$fixture/expected"
# Missing original profile returns to missing if unchanged.
rm "$fixture/user/.zlogin"
make_legacy no
run disable
[[ ! -e $fixture/user/.zlogin ]]
# A later user-created profile survives removal of the block.
make_legacy no
printf '# unrelated edit\n' >> "$fixture/user/.zlogin"
run disable
[[ $(cat "$fixture/user/.zlogin") = $'\n# unrelated edit' ]]
# Changed marked block: disarm first, refuse to delete unverified profile text.
make_legacy yes
sed -i 's/export PATH=/export PATH=\/edited:/' "$fixture/user/.zlogin"
cp "$fixture/user/.zlogin" "$fixture/malformed"
if run disable > "$fixture/refusal.log" 2>&1; then echo 'Expected edited block refusal' >&2; exit 1; fi
cmp "$fixture/user/.zlogin" "$fixture/malformed"
[[ ! -e $fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/.enabled ]]
cp "$backup/profile.after" "$fixture/user/.zlogin"
run disable
# Duplicate marker pairs are ambiguous: disarm and preserve the entire current file.
make_legacy yes
awk '/^# BEGIN COSMIC Refined next-login notification test$/ {active=1} active {print} /^# END COSMIC Refined next-login notification test$/ {active=0}' "$backup/profile.after" >> "$fixture/user/.zlogin"
cp "$fixture/user/.zlogin" "$fixture/duplicate-profile"
if run disable > "$fixture/duplicate.log" 2>&1; then echo 'Expected duplicate marker refusal' >&2; exit 1; fi
cmp "$fixture/user/.zlogin" "$fixture/duplicate-profile"
[[ ! -e $fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/.enabled ]]
cp "$backup/profile.after" "$fixture/user/.zlogin"
run disable
# Invalid metadata must not touch profile; it still removes the enable gate.
make_legacy yes
printf 'invalid\n' > "$backup/format"
cp "$fixture/user/.zlogin" "$fixture/invalid-profile"
if run disable > "$fixture/invalid.log" 2>&1; then echo 'Expected invalid metadata refusal' >&2; exit 1; fi
cmp "$fixture/user/.zlogin" "$fixture/invalid-profile"
[[ ! -e $fixture/user/.local/lib/cosmic-refined/notification-next-login-bin/.enabled ]]
printf 'cosmic-refined-next-login-v1\n' > "$backup/format"
run disable
# Read-only proc discovery must handle the real truncated comm, independently of pgrep.
mkdir -p "$fixture/proc/1234"
ln -s "$fixture/stock" "$fixture/proc/1234/exe"
printf 'cosmic-notifica\n' > "$fixture/proc/1234/comm"
printf 'cosmic-notifications\0' > "$fixture/proc/1234/cmdline"
printf 'PATH=/usr/bin\0OTHER=secret-not-to-print\0' > "$fixture/proc/1234/environ"
run status > "$fixture/status"
grep -q 'Current daemon PID: 1234' "$fixture/status"
grep -q 'Current running state: stock' "$fixture/status"
grep -q 'Current session inherited wrapper PATH: no' "$fixture/status"
if grep -q 'secret-not-to-print' "$fixture/status"; then echo 'Leaked unrelated environment' >&2; exit 1; fi
# Configuration and actual execution are reported separately; no activation claimed from files.
make_legacy yes
run status > "$fixture/status"
grep -q 'Configured override state: legacy .zlogin metadata present' "$fixture/status"
grep -q 'Current running state: stock' "$fixture/status"
printf 'PATH=%s:/usr/bin\0COSMIC_REFINED_NOTIFICATION_CARDS=1\0COSMIC_REFINED_NOTIFICATION_URGENCY=1\0' "$fixture/user/.local/lib/cosmic-refined/notification-next-login-bin" > "$fixture/proc/1234/environ"
mkdir -p "$fixture/user/.local/lib/cosmic-refined"
printf 'patched fixture\n' > "$fixture/user/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined"
rm "$fixture/proc/1234/exe"
ln -s "$fixture/user/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined" "$fixture/proc/1234/exe"
run status > "$fixture/status"
grep -q 'Current running state: patched' "$fixture/status"
grep -q 'Current daemon Refined environment: CARDS=1 URGENCY=1' "$fixture/status"
grep -q 'Current session inherited wrapper PATH: yes' "$fixture/status"
run disable
# No new environment file was created, and other login profiles were never accessed.
[[ ! -e $fixture/user/.config/environment.d && ! -e $fixture/user/.zprofile && ! -e $fixture/user/.profile && ! -e $fixture/user/.bash_profile ]]
[[ $(cat "$fixture/stock") = 'unchanged stock fixture' ]]
if grep -En '^[[:space:]]*(sudo|kill|pkill|killall|systemctl|loginctl|logout|reboot|shutdown|pgrep)([[:space:]]|$)' "$helper"; then
    echo 'Unexpected process-control/privilege command' >&2; exit 1
fi
echo 'PASS: blocked activation, legacy marker cleanup, backup/edit preservation, idempotent recovery, malformed metadata refusal, truncated-name proc status, no live controls'
