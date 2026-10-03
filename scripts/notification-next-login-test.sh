#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Host-only status/recovery. No verified graphical-login override is currently available.
set -euo pipefail
umask 077
script=$(readlink -f -- "${BASH_SOURCE[0]}")
user_home=${HOME:?}
stock=/usr/bin/cosmic-notifications
patched=$user_home/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined
bindir=$user_home/.local/lib/cosmic-refined/notification-next-login-bin
legacy_profile=$user_home/.zlogin
state=${XDG_STATE_HOME:-$user_home/.local/state}/cosmic-refined
backups=${XDG_DATA_HOME:-$user_home/.local/share}/cosmic-refined/notification-next-login-backups
proc_root=/proc
backup=
locked=false
begin='# BEGIN COSMIC Refined next-login notification test'
end='# END COSMIC Refined next-login notification test'

say() { printf '%s\n' "$*"; }
fail() { say "REFUSED: $*" >&2; return 1; }
checksum() { sha256sum -- "$1" | awk '{print $1}'; }
safe_path() {
    local path=$1
    [[ $user_home = /* && $user_home != / && -d $user_home && -O $user_home && ! -L $user_home ]] || { fail 'Unsafe home directory.'; return 1; }
    [[ $path = "$user_home/"* && $path != *$'\n'* && $path != */../* && $path != */./* ]] || { fail "Not a safe user-local path: $path"; return 1; }
    while [[ $path != "$user_home" ]]; do
        [[ ! -L $path ]] || { fail "Symlink refused: $path"; return 1; }
        [[ ! -e $path || -O $path ]] || { fail "Ownership mismatch: $path"; return 1; }
        path=${path%/*}
    done
}
lock_helper() {
    safe_path "$state"
    mkdir -p -- "$state"
    mkdir -- "$state/notification-next-login.lock" || { fail 'Helper lock exists; inspect before removing a stale lock.'; return 1; }
    locked=true
    trap 'on_exit $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
}
on_exit() {
    local result=$1
    trap - EXIT HUP INT TERM
    if $locked; then rmdir -- "$state/notification-next-login.lock" || true; fi
    exit "$result"
}
load_legacy_backup() {
    safe_path "$state/notification-next-login-active"
    [[ -f $state/notification-next-login-active ]] || { fail 'No recorded legacy backup pointer.'; return 1; }
    backup=$(cat "$state/notification-next-login-active")
    [[ $backup = "$backups/"* ]] || { fail 'Backup pointer is outside the backup directory.'; return 1; }
    safe_path "$backup"
    for file in format profile-path profile-existed profile.after; do
        safe_path "$backup/$file"
        [[ -f $backup/$file ]] || { fail "Missing legacy metadata: $file"; return 1; }
    done
    [[ $(cat "$backup/format") = cosmic-refined-next-login-v1 && $(cat "$backup/profile-path") = "$legacy_profile" ]] || { fail 'Unknown legacy metadata identity.'; return 1; }
    case $(cat "$backup/profile-existed") in
        yes) safe_path "$backup/profile.before"; [[ -f $backup/profile.before ]] || { fail 'Original profile backup missing.'; return 1; } ;;
        no) ;;
        *) fail 'Invalid original profile state.'; return 1 ;;
    esac
}
extract_block() {
    # Require one complete, ordered pair of whole-line markers, never a partial match.
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { if (starts++ || active || ends) bad=1; active=1 }
        active { print }
        $0 == end { if (!active || ends++) bad=1; active=0 }
        END { if (bad || starts!=1 || ends!=1 || active) exit 1 }
    ' "$1"
}
remove_legacy_block() {
    safe_path "$legacy_profile"
    [[ ! -e $legacy_profile || -f $legacy_profile ]] || { fail 'Legacy profile is not a regular file.'; return 1; }
    [[ -f $legacy_profile ]] || { say 'Legacy profile is absent.'; return; }
    local expected actual content cleaned staging recovery
    expected=$(extract_block "$backup/profile.after") || { fail 'Recorded profile has malformed/duplicate markers.'; return 1; }
    if ! grep -Fqx -- "$begin" "$legacy_profile" && ! grep -Fqx -- "$end" "$legacy_profile"; then
        say 'Legacy marked block already absent; user profile left intact.'
        return
    fi
    actual=$(extract_block "$legacy_profile") || { fail 'Current profile has malformed/duplicate markers; enable gate is off. Review manually.'; return 1; }
    [[ $actual = "$expected" ]] || { fail 'Marked block was edited; enable gate is off. Preserve edits and review manually.'; return 1; }
    # Back up the current file too: it may contain edits made after initial prepare.
    recovery=$(mktemp "$backup/profile.pre-cleanup.XXXXXXXX")
    cp -p -- "$legacy_profile" "$recovery"
    if cmp -s "$legacy_profile" "$backup/profile.after"; then
        # Exact equality proves no later edits are being discarded.
        if [[ $(cat "$backup/profile-existed") = no ]]; then
            rm -- "$legacy_profile"
            say 'Removed the unchanged, generated-only legacy profile.'
            return
        fi
        staging=$(mktemp "$user_home/.zlogin.refined-cleanup.XXXXXXXX")
        cp -p -- "$backup/profile.before" "$staging"
    else
        # Bash's NUL-delimited read preserves trailing newlines unlike command substitution.
        content=
        IFS= read -r -d '' content < "$legacy_profile" || true
        staging=$(mktemp "$user_home/.zlogin.refined-cleanup.XXXXXXXX")
        printf '%s' "$content" > "$staging"
        if ! cmp -s "$legacy_profile" "$staging"; then
            rm -- "$staging"
            fail 'Profile contains unsupported NUL data; enable gate is off. Review manually.'
            return 1
        fi
        local block=$actual
        [[ $content != *"$actual"$'\n'* ]] || block=$actual$'\n'
        cleaned=${content/"$block"/}
        cp -p -- "$legacy_profile" "$staging"
        printf '%s' "$cleaned" > "$staging"
    fi
    mv -- "$staging" "$legacy_profile"
    say "Removed only the recorded legacy change; later user edits preserved. Backup: $recovery"
}
prepare() {
    # Intentionally no build or configuration writes until the real startup chain is verified.
    fail 'No verified graphical-session environment mechanism. .zlogin activation is withdrawn; environment.d does not override the PATH already supplied to COSMIC by SDDM. Run status, and disable to clean up the legacy test. No new override was armed.'
}
disable() {
    [[ $EUID != 0 ]] || { fail 'Run as the same regular user; no root is required.'; return 1; }
    safe_path "$state"; safe_path "$bindir"; safe_path "$legacy_profile"
    safe_path "$state/notification-next-login-active"
    [[ ! -e $state/notification-next-login-active || -f $state/notification-next-login-active ]] || { fail 'Invalid metadata pointer.'; return 1; }
    local had_gate=false
    [[ ! -e $bindir/.enabled && ! -L $bindir/.enabled ]] || had_gate=true
    if [[ ! -f $state/notification-next-login-active && $had_gate = false ]]; then
        if [[ -f $legacy_profile ]] && grep -Fq -- "$begin" "$legacy_profile"; then
            fail 'Marked legacy block exists without recorded ownership metadata; preserve it and review manually.'
            return 1
        fi
        say 'No recorded legacy override. Nothing changed.'
        return
    fi
    lock_helper
    # Disarm even if other metadata is corrupt. Removing a symlink here removes only the link.
    rm -f -- "$bindir/.enabled"
    if [[ ! -f $state/notification-next-login-active ]]; then
        fail 'Removed enable gate, but no ownership metadata exists. Profile and wrapper preserved for manual review.'
        return 1
    fi
    load_legacy_backup
    remove_legacy_block
    if [[ -e $bindir/cosmic-notifications || -L $bindir/cosmic-notifications ]]; then
        safe_path "$bindir/cosmic-notifications"; safe_path "$backup/wrapper.sha256"
        [[ -f $backup/wrapper.sha256 && $(checksum "$bindir/cosmic-notifications") = "$(cat "$backup/wrapper.sha256")" ]] || { fail 'Changed/unrecorded wrapper preserved; enable gate is off.'; return 1; }
        rm -- "$bindir/cosmic-notifications"
    fi
    if [[ -d $bindir ]]; then
        # Never remove other files placed in this directory.
        rmdir -- "$bindir" || { fail 'Override directory contains other files; they were preserved.'; return 1; }
    fi
    rm -- "$state/notification-next-login-active"
    say "Legacy test disabled. Backups and compiled binary retained: $backup"
    say 'No running process was signaled or restarted; no new environment override was created.'
}
running_status() {
    local entry pid exe comm command item daemon_path count=0 env_readable
    for entry in "$proc_root"/[0-9]*; do
        [[ -d $entry && -O $entry ]] || continue
        pid=${entry##*/}
        [[ $pid =~ ^[0-9]+$ ]] || continue
        exe=$(readlink -f -- "$entry/exe" 2>/dev/null || true)
        comm=$(cat "$entry/comm" 2>/dev/null || true)
        command=
        IFS= read -r -d '' command < "$entry/cmdline" 2>/dev/null || true
        # Do not rely on pgrep's full-name matching: Linux comm has a 15-byte limit.
        if [[ $exe != "$stock" && $exe != "$patched" && ${command##*/} != cosmic-notifications && $comm != cosmic-notifica ]]; then continue; fi
        count=$((count+1))
        say "Current daemon PID: $pid"
        say "Current daemon executable: ${exe:-unreadable/exited}"
        case $exe in "$stock") say 'Current running state: stock' ;; "$patched") say 'Current running state: patched' ;; *) say 'Current running state: unrecognized/unreadable' ;; esac
        say "Current daemon command: ${command:-unreadable/exited}"
        local cards='not present' urgency='not present'
        daemon_path=
        env_readable=false
        if [[ -r $entry/environ ]]; then
            env_readable=true
            while IFS= read -r -d '' item; do
                case $item in
                    COSMIC_REFINED_NOTIFICATION_CARDS=*) cards=${item#*=} ;;
                    COSMIC_REFINED_NOTIFICATION_URGENCY=*) urgency=${item#*=} ;;
                    PATH=*) daemon_path=${item#*=} ;;
                esac
            done < "$entry/environ" || env_readable=false
        fi
        if $env_readable; then
            say "Current daemon Refined environment: CARDS=$cards URGENCY=$urgency"
            say "Current daemon PATH: ${daemon_path:-not present}"
            if [[ :$daemon_path: = *":$bindir:"* ]]; then
                say 'Current session inherited wrapper PATH: yes (presence only; not proof of binary selection)'
            else
                say 'Current session inherited wrapper PATH: no'
            fi
        else
            say 'Current daemon environment/PATH: unavailable; inheritance cannot be verified.'
        fi
    done
    say "Current daemon candidates: $count"
    [[ $count = 1 ]] || say 'WARNING: expected one daemon; namespace visibility or concurrent processes may differ.'
    say 'Read-only process information describes the current process namespace; run status on the host.'
}
status() {
    safe_path "$state"; safe_path "$bindir"
    say 'Supported next-login override: none verified; prepare is blocked.'
    if [[ -e $state/notification-next-login-active || -L $state/notification-next-login-active ]]; then
        if load_legacy_backup; then
            say "Configured override state: legacy .zlogin metadata present; this strategy failed on the host. Backup: $backup"
        else
            say 'Configured override state: invalid legacy metadata; do not infer successful activation.'
        fi
    else
        say 'Configured override state: no recorded legacy test.'
    fi
    if [[ -f $bindir/.enabled ]]; then say 'Legacy enable gate: present (not proof of session inheritance)'; else say 'Legacy enable gate: absent'; fi
    say "Wrapper location: $bindir/cosmic-notifications"
    say "Target binary: $patched"
    [[ ! -f $patched ]] || say "Target SHA256: $(checksum "$patched")"
    say "Stock binary: $stock"
    [[ ! -f $stock ]] || say "Stock SHA256: $(checksum "$stock")"
    printf 'Disable/recovery command: bash %q disable\n' "$script"
    running_status
}
main() {
    [[ $# = 1 ]] || { say 'Usage: notification-next-login-test.sh prepare|status|disable' >&2; return 2; }
    case $1 in prepare) prepare ;; status) status ;; disable) disable ;; *) fail 'Unknown command.'; return 2 ;; esac
}
if [[ ${BASH_SOURCE[0]} = "$0" ]]; then main "$@"; fi
