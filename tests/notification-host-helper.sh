#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Source functions only; every process/bus/service operation below is mocked.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/apply-notification-test-host.sh
source "$repo/scripts/apply-notification-test-host.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
state=$fixture/state
backups=$fixture/backups
patched=$fixture/patched
stock=$fixture/stock
log=$fixture/test.log
printf 'stock fixture\n' > "$stock"
chmod 700 "$stock"
printf 'patched fixture\n' > "$patched"
stock_sha=$(checksum "$stock")
XDG_RUNTIME_DIR=$fixture/runtime
WAYLAND_DISPLAY=wayland-fixture
mock_version=1:1.9.0-1
mock_hook=
mock_parent=/usr/bin/cosmic-session
mock_multiple=false
mock_environment=()
process_environment() { printf '%s\0' "${mock_environment[@]}"; }
pacman() {
    case $1 in -Q) printf 'cosmic-notifications %s\n' "$mock_version" ;; -Qoq) echo cosmic-notifications ;; *) return 1 ;; esac
}
ps() { if [[ $* = *ppid=* ]]; then echo 20; else echo 'fixture process'; fi; }
snapshot() { echo 'fixture CPU/RSS snapshot'; }
find_daemons() {
    daemons=()
    if [[ -s $fixture/active ]]; then read -r mock_pid mock_executable < "$fixture/active"; daemons+=("$mock_pid"); fi
    if $mock_multiple; then daemons+=(999); fi
}
exe_of() {
    if [[ $1 = 20 ]]; then printf '%s\n' "$mock_parent"; else
        read -r mock_pid mock_executable < "$fixture/active"
        printf '%s\n' "$mock_executable"
    fi
}
identity_of() { echo 42; }
owner_pid() { read -r mock_pid mock_executable < "$fixture/active"; echo "$mock_pid"; }
kill() {
    [[ $1 = -TERM && $2 = 123 ]] || return 1
    echo 'kill patched only' >> "$fixture/events"
    rm "$fixture/active"
}
wait_gone() { [[ ! -e $fixture/active ]]; }
nohup() {
    [[ $1 = env && $2 = -i ]] || return 1
    echo 'launch original command' >> "$fixture/events"
    printf '123 %s\n' "$stock" > "$fixture/active"
}
verify_running() {
    wait # Wait only for the mocked nohup function's fixture-file write.
    find_daemons
    [[ ${#daemons[@]} = 1 && $(exe_of "${daemons[0]}") = "$1" ]] || return 1
    pid=${daemons[0]}
}
unit_property() {
    case $1 in
        LoadState) echo loaded ;;
        ExecStart) printf '{ path=%s ; argv[]=%s ; }\n' "$stock" "$stock" ;;
        MainPID) echo 123 ;;
        ExecStop) printf '%s' "$mock_hook" ;;
        *) : ;;
    esac
}
systemctl() {
    case $2 in
        cat) echo 'fixture unit definition' ;;
        start)
            [[ $3 = notification-fixture.service ]] || return 1
            echo 'start original unit' >> "$fixture/events"
            printf '123 %s\n' "$stock" > "$fixture/active" ;;
        *) return 1 ;;
    esac
}
: > "$fixture/events"
verify_package
mock_version=1:1.10.0-1
if verify_package > "$fixture/rejected" 2>&1; then exit 1; fi
mock_version=1:1.9.0-1
saved_sha=$stock_sha
stock_sha=wrong
if verify_package > "$fixture/rejected" 2>&1; then exit 1; fi
stock_sha=$saved_sha
# Required opt-ins and inherited socket rejection use synthetic NUL environments.
pid=123
mock_environment=(COSMIC_REFINED_NOTIFICATION_CARDS=1)
if verify_opt_in > "$fixture/rejected" 2>&1; then exit 1; fi
mock_environment+=(COSMIC_REFINED_NOTIFICATION_URGENCY=1)
verify_opt_in
mock_environment=("XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" 'PRIVATE_TOKEN=not-recorded')
read_original_environment
[[ ${#original_env[@]} = 2 ]]
mock_environment+=(DAEMON_NOTIFICATIONS_FD=99)
if read_original_environment > "$fixture/rejected" 2>&1; then exit 1; fi
# Session supervision must be rejected BEFORE inherited-FD reads or any signal.
pid=123
if detect_launch > "$fixture/rejected" 2>&1; then exit 1; fi
[[ ! -s $fixture/events ]]
# Unsafe service stop hooks must be rejected, including conditional invocation.
unit=notification-fixture.service
verify_unit
mock_hook='/usr/bin/killall cosmic-panel'
if verify_unit > "$fixture/rejected" 2>&1; then exit 1; fi
mock_hook=
if (
    # Invoked indirectly by the sourced verify_unit function.
    # shellcheck disable=SC2329
    unit_property() {
        case $1 in
            LoadState) echo loaded ;;
            ExecStart) printf '{ path=%s ; } { path=/unrelated ; }\n' "$stock" ;;
            *) : ;;
        esac
    }
    verify_unit
) > "$fixture/rejected" 2>&1; then exit 1; fi
# Rollback metadata uses NUL arrays, not sourced/evaluated shell commands.
private_dir "$state"
pid=123
parent=20
mechanism=manual
unit=
original_command=("$stock" 'argument with spaces')
original_env=("XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" "WAYLAND_DISPLAY=$WAYLAND_DISPLAY")
save_backup > "$fixture/save.log"
load_backup
[[ ${original_command[1]} = 'argument with spaces' ]]
[[ -f $backup/baseline.txt && -f $backup/restore-command.txt ]]
# Invalid rollback metadata must fail before any process action.
printf 'invalid format\n' > "$backup/format"
if restore_internal > "$fixture/rejected" 2>&1; then exit 1; fi
[[ ! -s $fixture/events ]]
printf 'cosmic-refined-host-test-v1\n' > "$backup/format"
# Existing stock daemon: restore is a no-op.
printf '123 %s\n' "$stock" > "$fixture/active"
restore_internal > "$fixture/restore.log"
[[ ! -s $fixture/events ]]
# Unknown executable or multiple daemons: do not kill anything.
printf '123 /unknown/program\n' > "$fixture/active"
if restore_internal > "$fixture/rejected" 2>&1; then exit 1; fi
mock_multiple=true
if restore_internal > "$fixture/rejected" 2>&1; then exit 1; fi
mock_multiple=false
[[ ! -s $fixture/events ]]
# Known test binary -> TERM only that process, then relaunch recorded stock.
printf '123 %s\n' "$patched" > "$fixture/active"
restore_internal > "$fixture/restore.log"
[[ $(cat "$fixture/events") = $'kill patched only\nlaunch original command' ]]
[[ -d $backup ]] # Metadata is never automatically deleted.
# Dedicated service restore preserves the service launch mechanism.
mechanism=systemd
unit=notification-fixture.service
save_backup > "$fixture/save.log"
printf '123 %s\n' "$patched" > "$fixture/active"
: > "$fixture/events"
restore_internal > "$fixture/restore.log"
[[ $(cat "$fixture/events") = $'kill patched only\nstart original unit' ]]
# A reused PID identity cannot be signaled.
if verify_current "$stock" 123 wrong > "$fixture/rejected" 2>&1; then exit 1; fi
# Apply failure trap attempts automatic restore; restore failure exits distinctly.
if (
    restore_internal() { echo restored > "$fixture/trap-restored"; }
    switching=true
    locked=false
    on_exit 7
) > "$fixture/trap.log" 2>&1; then exit 1; else [[ $? = 7 ]]; fi
[[ -f $fixture/trap-restored ]]
if (
    restore_internal() { return 1; }
    switching=true
    locked=false
    on_exit 7
) > "$fixture/trap.log" 2>&1; then exit 1; else [[ $? = 125 ]]; fi
echo 'PASS: package/checksum/opt-in guards, filtered environment, inherited-FD/supervised-launch refusal, unit safety, rollback metadata, duplicate/unknown/PID-reuse refusal, manual/service restore and failure traps'
