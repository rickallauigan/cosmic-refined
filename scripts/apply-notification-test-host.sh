#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Run manually in the host Wayland terminal. Never invoked by theme/preset import.
set -euo pipefail
umask 077

script=$(readlink -f -- "${BASH_SOURCE[0]}")
repo=$(cd -- "$(dirname -- "$script")/.." && pwd)
stock=/usr/bin/cosmic-notifications
stock_sha=6ed809b720aa26676043acec96811b0dded10054b2e1c54f1cb15df8ced929d7
revision=aa4dac2702506395ab76da1f6755e03b2ccb0db8
patched=${HOME:?}/.local/lib/cosmic-refined/cosmic-notifications-1.9.0-refined
state=$HOME/.local/state/cosmic-refined
backups=$HOME/.local/share/cosmic-refined/notification-backups
log=$state/cosmic-notifications-test.log
work=/tmp/cosmic-refined-notification-live-test
backup=
mechanism=
unit=
switching=false
locked=false
pid=
identity=
parent=
original_env=()
original_command=()
daemons=()

say() { printf '%s\n' "$*"; }
fail() { say "REFUSED: $*" >&2; return 1; }
checksum() { sha256sum -- "$1" | awk '{print $1}'; }
exe_of() { readlink -f -- "/proc/$1/exe"; }
process_environment() { cat "/proc/$1/environ"; }
identity_of() {
    local value
    value=$(cat "/proc/$1/stat") || return 1
    value=${value##*) }
    local -a fields
    read -r -a fields <<< "$value"
    printf '%s\n' "${fields[19]}"
}
find_daemons() {
    # Linux comm is truncated to 15 bytes for both stock and patched filenames.
    mapfile -t daemons < <(pgrep -u "$UID" -x cosmic-notifica || true)
}
owner_pid() {
    local reply type number
    reply=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.Notifications) || return 1
    read -r type number <<< "$reply"
    [[ $type = u && $number =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$number"
}
snapshot() {
    ps -p "$1" -o pid=,ppid=,rss=,pcpu=,etime=,args=
    ps -C cosmic-comp -o pid=,rss=,pcpu=,etime= || true
    uptime
    free -m
}
verify_package() {
    local name version
    [[ -x $stock && ! -L $stock ]] || { fail 'Missing or symlinked stock binary.'; return 1; }
    read -r name version < <(pacman -Q cosmic-notifications)
    [[ $name = cosmic-notifications && $version =~ ^([0-9]+:)?1\.9\.0(-[0-9]+)?$ ]] || { fail "Unsupported version: ${version:-unknown}"; return 1; }
    [[ $(pacman -Qoq "$stock") = cosmic-notifications ]] || { fail 'Stock binary package ownership mismatch.'; return 1; }
    [[ $(checksum "$stock") = "$stock_sha" ]] || { fail 'Stock checksum mismatch; do not bypass this check.'; return 1; }
}
host_checks() {
    [[ $UID != 0 && $HOME = /* ]] || { fail 'Run as your regular desktop user with an absolute HOME.'; return 1; }
    for tool in pacman sha256sum pgrep ps busctl readlink awk free uptime; do
        command -v "$tool" >/dev/null || { fail "Missing required tool: $tool"; return 1; }
    done
    [[ ${XDG_SESSION_TYPE:-} = wayland && -n ${WAYLAND_DISPLAY:-} ]] || { fail 'Run directly in your Wayland desktop terminal.'; return 1; }
    [[ -d ${XDG_RUNTIME_DIR:-/nonexistent} && -O $XDG_RUNTIME_DIR ]] || { fail 'Runtime directory is unavailable or belongs to another user.'; return 1; }
    local socket=$WAYLAND_DISPLAY
    [[ $socket = /* ]] || socket=$XDG_RUNTIME_DIR/$socket
    [[ -S $socket ]] || { fail 'Wayland socket is unavailable.'; return 1; }
    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus ListNames >/dev/null || { fail 'User session bus is unavailable.'; return 1; }
    verify_package
}
read_original_environment() {
    original_env=()
    local item key
    while IFS= read -r -d '' item; do
        key=${item%%=*}
        case $key in
            DAEMON_NOTIFICATIONS_FD|PANEL_NOTIFICATIONS_FD|WAYLAND_SOCKET)
                fail "Inherited $key cannot be transferred safely; no manual switch is supported."; return 1 ;;
            COSMIC_REFINED_NOTIFICATION_CARDS|COSMIC_REFINED_NOTIFICATION_URGENCY)
                fail 'Stock daemon already has Refined overrides; restore those independently first.'; return 1 ;;
            HOME|USER|LOGNAME|PATH|DISPLAY|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|XDG_CONFIG_HOME|XDG_DATA_HOME|XDG_STATE_HOME|XDG_CACHE_HOME|XDG_CONFIG_DIRS|XDG_DATA_DIRS|COSMIC_VERSION|TZ|LANG|LANGUAGE|LC_*|FONTCONFIG_FILE|FONTCONFIG_PATH|XCURSOR_SIZE|XCURSOR_THEME|RUST_LOG|RUST_BACKTRACE)
                original_env+=("$item") ;;
        esac
    done < <(process_environment "$pid")
    local runtime=false display=false
    for item in "${original_env[@]}"; do
        [[ $item = "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" ]] && runtime=true
        [[ $item = "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" ]] && display=true
    done
    if ! $runtime || ! $display; then fail 'Daemon belongs to a different or unverifiable desktop session.'; return 1; fi
}
unit_property() { systemctl --user show "$unit" --property="$1" --value; }
verify_unit() {
    [[ $unit =~ ^[A-Za-z0-9_.@:-]+\.service$ ]] || { fail 'Invalid service identity.'; return 1; }
    [[ $(unit_property LoadState) = loaded ]] || { fail 'Service is not loaded.'; return 1; }
    local start
    start=$(unit_property ExecStart) || { fail 'Cannot inspect service command.'; return 1; }
    [[ $start = "{ path=$stock ; "* && ${start#*path=} != *path=* ]] || { fail 'Unit must have exactly one direct stock ExecStart.'; return 1; }
    local property value
    # These hooks/relationships could stop or start unrelated processes.
    for property in ExecCondition ExecStartPre ExecStartPost ExecStop ExecStopPost OnFailure OnSuccess PropagatesStopTo BoundBy ConsistsOf Triggers TriggeredBy; do
        value=$(unit_property "$property") || { fail "Cannot verify unit property: $property"; return 1; }
        [[ -z $value ]] || { fail "Unit has unsupported $property behavior."; return 1; }
    done
}
detect_launch() {
    local parent_exe leaf cgroup
    parent=$(ps -p "$pid" -o ppid= | tr -d ' ')
    [[ $parent =~ ^[0-9]+$ ]] || { fail 'Cannot read parent PID.'; return 1; }
    parent_exe=$(exe_of "$parent") || { fail 'Cannot inspect parent executable.'; return 1; }
    say "Parent: $parent $parent_exe"
    ps -p "$parent" -o pid=,ppid=,args=
    # Stopping this supervised child can indirectly restart cosmic-panel.
    [[ ${parent_exe##*/} != cosmic-session ]] || { fail 'COSMIC session supervises this daemon; stopping it can restart cosmic-panel.'; return 1; }
    read_original_environment || return 1
    say 'Filtered desktop environment (no full environment dump):'
    printf '%q\n' "${original_env[@]}"
    cgroup=$(awk -F: '$1 == "0" {print $3}' "/proc/$pid/cgroup")
    leaf=${cgroup##*/}
    if [[ $leaf = *.service ]]; then
        unit=$leaf
        command -v systemctl >/dev/null || { fail 'Cannot verify the supervising service.'; return 1; }
        [[ $(unit_property MainPID) = "$pid" ]] || { fail 'Daemon is not the service MainPID; stopping it may affect unrelated processes.'; return 1; }
        [[ $(unit_property ControlGroup) = "$cgroup" ]] || { fail 'Service cgroup mismatch.'; return 1; }
        [[ $(cat "/sys/fs/cgroup$cgroup/cgroup.procs") = "$pid" ]] || { fail 'Service contains additional processes.'; return 1; }
        verify_unit || return 1
        mechanism=systemd
    else
        # Only an unwrapped direct child of an interactive shell is reproducible.
        case ${parent_exe##*/} in bash|zsh|fish|dash|sh) ;; *) fail 'Unknown/autostart/session supervisor; no deterministic restore path.'; return 1 ;; esac
        local terminal
        terminal=$(ps -p "$parent" -o tty= | tr -d ' ')
        [[ -n $terminal && $terminal != '?' ]] || { fail 'Parent shell is not attached to a terminal.'; return 1; }
        local -a args
        mapfile -d '' -t args < "/proc/$parent/cmdline"
        local arg
        for arg in "${args[@]:1}"; do
            case $arg in -i|-l|-il|-li|--login) ;; *) fail 'Parent shell has script/command arguments; launch supervision is unknown.'; return 1 ;; esac
        done
        mechanism=manual
    fi
    mapfile -d '' -t original_command < "/proc/$pid/cmdline"
    [[ ${#original_command[@]} -gt 0 ]] || { fail 'Empty original command line.'; return 1; }
    original_command[0]=$stock
    identity=$(identity_of "$pid")
    say "Launch mechanism: $mechanism${unit:+ ($unit)}"
}
precheck() {
    host_checks
    find_daemons
    [[ ${#daemons[@]} = 1 ]] || { fail "Expected one daemon; found ${#daemons[@]}."; return 1; }
    pid=${daemons[0]}
    [[ $(exe_of "$pid") = "$stock" ]] || { fail 'Running daemon is not the verified stock binary.'; return 1; }
    [[ $(owner_pid) = "$pid" ]] || { fail 'Stock process does not own org.freedesktop.Notifications.'; return 1; }
    say "Stock PID: $pid"
    ps -p "$pid" -o pid=,ppid=,rss=,pcpu=,etime=,args=
    detect_launch
    say 'Verified restore strategy:'
    if [[ $mechanism = systemd ]]; then
        printf 'Stop only the test PID, then: systemctl --user start %q\n' "$unit"
    else
        printf 'Stop only the test PID, then execute the recorded stock command/environment: '
        printf '%q ' "${original_command[@]}"; printf '\n'
    fi
    if command -v systemctl >/dev/null; then
        say 'COSMIC user units (read-only):'
        systemctl --user list-units --all --no-pager --plain | sed -n '/[Cc][Oo][Ss][Mm][Ii][Cc]/p' || true
        systemctl --user list-unit-files --no-pager | sed -n '/[Cc][Oo][Ss][Mm][Ii][Cc]/p' || true
    fi
    say 'Session/autostart launch references (read-only; not used as proof of supervision):'
    local dir
    for dir in /etc/xdg/autostart /usr/share/wayland-sessions "$HOME/.config/autostart"; do
        [[ -d $dir ]] || continue
        find "$dir" -maxdepth 1 -type f -name '*.desktop' -exec \
            awk '/cosmic-notifications|cosmic-session/ {print FILENAME ":" $0}' {} +
    done
    snapshot "$pid"
}
private_dir() {
    [[ ! -L $1 ]] || { fail "Refusing symlink directory: $1"; return 1; }
    local ancestor=$1
    while [[ $ancestor != / && $ancestor != /tmp && $ancestor != "$HOME" ]]; do
        [[ ! -L $ancestor ]] || { fail "Refusing symlink ancestor: $ancestor"; return 1; }
        ancestor=${ancestor%/*}
    done
    mkdir -p -- "$1"
    [[ -d $1 && -O $1 ]] || { fail "Directory ownership mismatch: $1"; return 1; }
}
lock_helper() {
    private_dir "$state"
    mkdir -- "$state/notification-host-test.lock" || { fail 'Helper already running or stale lock exists; inspect before removing it.'; return 1; }
    locked=true
    trap 'on_exit $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
}
save_backup() {
    private_dir "$backups"
    backup=$(mktemp -d "$backups/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
    printf '%s\n' "$mechanism" > "$backup/mechanism"
    printf '%s\n' "$unit" > "$backup/unit"
    printf '%s\n' "$pid" > "$backup/original-pid"
    printf '%s\n' "$parent" > "$backup/original-parent"
    printf '%s\n' "$stock" > "$backup/stock-path"
    printf '%s\n' "$stock_sha" > "$backup/stock-sha256"
    checksum "$patched" > "$backup/patched-sha256"
    printf '%s\0' "${original_command[@]}" > "$backup/command.nul"
    printf '%s\0' "${original_env[@]}" > "$backup/environment.nul"
    pacman -Q cosmic-notifications > "$backup/package-version"
    stat "$stock" > "$backup/stock-metadata"
    ps -p "$parent" -o pid=,ppid=,args= > "$backup/parent-command"
    snapshot "$pid" > "$backup/baseline.txt"
    if [[ $mechanism = systemd ]]; then
        systemctl --user cat "$unit" | sha256sum | awk '{print $1}' > "$backup/unit-sha256"
    fi
    printf 'bash %q restore %q\n' "$script" "$backup" > "$backup/restore-command.txt"
    say "Rollback metadata: $backup"
    say 'Exact restore command (keep this checkout available):'
    cat "$backup/restore-command.txt"
    printf '%s\n' cosmic-refined-host-test-v1 > "$backup/format"
    [[ ! -L $state/active-backup ]] || { fail 'Refusing a symlinked backup pointer.'; return 1; }
    local pointer
    pointer=$(mktemp "$state/active-backup.XXXXXXXX")
    printf '%s\n' "$backup" > "$pointer"
    mv -- "$pointer" "$state/active-backup"
}
load_backup() {
    if [[ -z $backup ]]; then
        [[ -f $state/active-backup && ! -L $state/active-backup ]] || { fail 'No recorded rollback metadata.'; return 1; }
        backup=$(cat "$state/active-backup")
    fi
    [[ $backup = "$backups/"* && -d $backup && ! -L $backup && -O $backup ]] || { fail 'Unsafe backup path.'; return 1; }
    local file
    for file in format mechanism unit stock-path stock-sha256 patched-sha256 command.nul environment.nul baseline.txt restore-command.txt; do
        [[ -f $backup/$file && ! -L $backup/$file && -O $backup/$file ]] || { fail "Missing/unsafe rollback file: $file"; return 1; }
    done
    [[ $(cat "$backup/format") = cosmic-refined-host-test-v1 && $(cat "$backup/stock-path") = "$stock" && $(cat "$backup/stock-sha256") = "$stock_sha" ]] || { fail 'Rollback identity mismatch.'; return 1; }
    mechanism=$(cat "$backup/mechanism")
    unit=$(cat "$backup/unit")
    [[ $mechanism = systemd || $mechanism = manual ]] || { fail 'Invalid rollback launch mechanism.'; return 1; }
    mapfile -d '' -t original_command < "$backup/command.nul"
    mapfile -d '' -t original_env < "$backup/environment.nul"
    [[ ${original_command[0]:-} = "$stock" ]] || { fail 'Invalid original executable.'; return 1; }
    local item runtime=false display=false
    for item in "${original_env[@]}"; do
        [[ $item = "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" ]] && runtime=true
        [[ $item = "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" ]] && display=true
    done
    if ! $runtime || ! $display; then fail 'Restore must run in the same desktop session.'; return 1; fi
    if [[ $mechanism = systemd ]]; then
        [[ -f $backup/unit-sha256 && ! -L $backup/unit-sha256 && -O $backup/unit-sha256 ]] || { fail 'Unsafe unit definition checksum file.'; return 1; }
        verify_unit || return 1
        [[ $(systemctl --user cat "$unit" | sha256sum | awk '{print $1}') = "$(cat "$backup/unit-sha256")" ]] || { fail 'Original service definition changed; refusing an unverified restart.'; return 1; }
    fi
}
verify_current() {
    local expected=$1 expected_pid=$2 expected_identity=$3
    find_daemons
    [[ ${#daemons[@]} = 1 && ${daemons[0]} = "$expected_pid" && $(exe_of "$expected_pid") = "$expected" && $(identity_of "$expected_pid") = "$expected_identity" ]] || { fail 'Daemon identity changed; refusing to signal it.'; return 1; }
}
wait_gone() {
    local target=$1 start=$2 i
    for ((i=0; i<30; i++)); do
        [[ $(identity_of "$target" 2>/dev/null || true) = "$start" ]] || return 0
        sleep 0.2
    done
    fail 'Daemon did not exit after TERM; no SIGKILL escalation performed.'
}
verify_running() {
    local expected=$1 i current
    # Finite startup verification, not a background polling service.
    for ((i=0; i<25; i++)); do
        sleep 0.2
        find_daemons
        [[ ${#daemons[@]} -le 1 ]] || { fail 'Multiple daemons appeared; refusing further signals.'; return 1; }
        if [[ ${#daemons[@]} = 1 ]]; then
            current=${daemons[0]}
            [[ $(exe_of "$current") = "$expected" ]] || { fail 'Unexpected daemon started.'; return 1; }
            [[ $(owner_pid 2>/dev/null || true) = "$current" ]] && { pid=$current; return 0; }
        fi
    done
    fail 'Daemon did not claim the notification bus name.'
}
verify_opt_in() {
    local item cards=false urgency=false
    while IFS= read -r -d '' item; do
        [[ $item = COSMIC_REFINED_NOTIFICATION_CARDS=1 ]] && cards=true
        [[ $item = COSMIC_REFINED_NOTIFICATION_URGENCY=1 ]] && urgency=true
    done < <(process_environment "$pid")
    if ! $cards || ! $urgency; then fail 'Patched daemon opt-in variables are missing.'; return 1; fi
}
restore_internal() {
    load_backup || return 1
    verify_package || return 1
    find_daemons
    [[ ${#daemons[@]} -le 1 ]] || { fail 'Multiple daemons; automatic restore refuses to kill ambiguous processes.'; return 1; }
    if [[ ${#daemons[@]} = 1 ]]; then
        local current=${daemons[0]} current_exe
        current_exe=$(exe_of "$current") || return 1
        if [[ $current_exe = "$stock" ]]; then
            [[ $(owner_pid) = "$current" ]] || return 1
            if [[ $mechanism = systemd ]]; then
                [[ $(unit_property MainPID) = "$current" ]] || { fail 'Stock daemon is not owned by the original service.'; return 1; }
            fi
            say 'Stock daemon is already running; nothing stopped.'
            return 0
        fi
        [[ $current_exe = "$patched" && $(checksum "$patched") = "$(cat "$backup/patched-sha256")" ]] || { fail 'Refusing to stop an unrecognized executable.'; return 1; }
        local current_identity
        current_identity=$(identity_of "$current") || return 1
        verify_current "$patched" "$current" "$current_identity" || return 1
        say "Stopping only patched PID $current"
        kill -TERM "$current" || return 1
        wait_gone "$current" "$current_identity" || return 1
    fi
    if [[ $mechanism = systemd ]]; then
        say "Restoring original user service: $unit"
        systemctl --user start "$unit" || return 1
    else
        say 'Restoring the recorded stock command and filtered desktop environment.'
        nohup env -i "${original_env[@]}" "${original_command[@]}" >> "$log" 2>&1 < /dev/null &
    fi
    verify_running "$stock" || return 1
    if [[ $mechanism = systemd ]]; then
        [[ $(unit_property MainPID) = "$pid" ]] || { fail 'Restored daemon is not the original service MainPID.'; return 1; }
    fi
    say "Stock daemon restored: PID $pid"
}
on_exit() {
    local result=$1
    trap - EXIT HUP INT TERM
    if $switching; then
        say 'Apply failed or was interrupted after switching began. Restoring stock.' >&2
        if ! restore_internal; then
            say "AUTOMATIC RESTORE FAILED. Keep metadata at $backup and inspect the log: $log" >&2
            say "Restore command: bash $script restore $backup" >&2
            result=125
        fi
    fi
    if $locked; then rmdir -- "$state/notification-host-test.lock" || true; fi
    exit "$result"
}
build_binary() {
    for tool in git cargo; do
        command -v "$tool" >/dev/null || { fail "Missing build tool: $tool"; return 1; }
    done
    private_dir "$work"
    local build lock_sha
    build=$(mktemp -d "$work/build.XXXXXX")
    say "Building exact upstream revision in $build/source"
    git init -q "$build/source"
    git -C "$build/source" remote add origin https://github.com/pop-os/cosmic-notifications
    git -C "$build/source" fetch --depth=1 origin "$revision"
    git -C "$build/source" checkout --detach FETCH_HEAD
    [[ $(git -C "$build/source" rev-parse HEAD) = "$revision" ]] || { fail 'Upstream revision mismatch.'; return 1; }
    lock_sha=$(checksum "$build/source/Cargo.lock")
    cmp "$repo/tests/fixtures/cosmic-notifications-1.9.0-app.rs" "$build/source/src/app.rs"
    cmp "$repo/tests/fixtures/cosmic-notifications-1.9.0-main.rs" "$build/source/src/main.rs"
    git -C "$build/source" apply --check "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch"
    git -C "$build/source" apply "$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch"
    (
        cd -- "$build/source"
        export CARGO_TARGET_DIR="$build/target"
        cargo fmt --all -- --check
        cargo check --locked
        cargo build --locked --release
    )
    [[ $(checksum "$build/source/Cargo.lock") = "$lock_sha" ]] || { fail 'Upstream lockfile changed.'; return 1; }
    private_dir "${patched%/*}"
    [[ ! -L $patched ]] || { fail 'Refusing a symlinked test binary path.'; return 1; }
    local staging
    staging=$(mktemp "${patched%/*}/binary.XXXXXXXX")
    cp -- "$build/target/release/cosmic-notifications" "$staging"
    chmod 700 "$staging"
    mv -- "$staging" "$patched"
    say "Patched binary SHA256: $(checksum "$patched")"
}
apply_test() {
    host_checks
    find_daemons
    [[ ${#daemons[@]} = 1 ]] || { fail "Expected one daemon; found ${#daemons[@]}."; return 1; }
    if [[ $(exe_of "${daemons[0]}") = "$patched" ]]; then
        pid=${daemons[0]}
        load_backup
        [[ $(checksum "$patched") = "$(cat "$backup/patched-sha256")" && $(owner_pid) = "$pid" ]] || { fail 'Running test does not match rollback metadata.'; return 1; }
        verify_opt_in
        say "Patched daemon already running: PID $pid. No rebuild or new notifications."
        return 0
    fi
    precheck
    lock_helper
    build_binary
    # A long build must not leave us signaling a changed/reused process identity.
    verify_current "$stock" "$pid" "$identity"
    detect_launch
    save_backup
    load_backup
    [[ ! -L $log ]] || { fail 'Refusing a symlinked log path.'; return 1; }
    switching=true
    if [[ $mechanism = systemd ]]; then
        say "Stopping dedicated user service: $unit"
        systemctl --user stop "$unit"
    else
        say "Stopping only stock PID $pid"
        kill -TERM "$pid"
    fi
    wait_gone "$pid" "$identity"
    find_daemons
    [[ ${#daemons[@]} = 0 ]] || { fail 'Stock daemon respawned; refusing duplicate launch.'; return 1; }
    say "Launching patched daemon; logs: $log"
    nohup env -i "${original_env[@]}" COSMIC_REFINED_NOTIFICATION_CARDS=1 \
        COSMIC_REFINED_NOTIFICATION_URGENCY=1 "$patched" >> "$log" 2>&1 < /dev/null &
    verify_running "$patched"
    local running_pid=$pid running_identity
    running_identity=$(identity_of "$pid")
    verify_opt_in
    sleep 5
    verify_current "$patched" "$running_pid" "$running_identity"
    [[ $(owner_pid) = "$pid" ]] || { fail 'Patched daemon lost the notification bus name.'; return 1; }
    if command -v notify-send >/dev/null; then
        notify-send -t 5000 'COSMIC Refined' 'Normal notification test'
        sleep 2
        notify-send -u critical -t 5000 'COSMIC Refined Critical' 'Critical notification accent test'
        sleep 2
        notify-send -t 5000 'COSMIC Refined long title test for wrapping' \
            'This is a longer body used to verify spacing, wrapping, readability, and card width.'
        local n
        for n in 1 2 3; do
            notify-send -t 8000 "COSMIC Refined stack $n" 'Distinct notification card test'
            sleep 2
        done
    else
        say 'notify-send unavailable; send notifications manually.'
    fi
    verify_current "$patched" "$running_pid" "$running_identity"
    [[ $(owner_pid) = "$pid" ]] || { fail 'Notification bus ownership changed during tests.'; return 1; }
    snapshot "$pid" > "$backup/patched-snapshot.txt"
    say 'Stock baseline (CPU % is lifetime average, not a benchmark):'
    cat "$backup/baseline.txt"
    say 'Patched snapshot (different process ages; compare only rough RSS/CPU):'
    cat "$backup/patched-snapshot.txt"
    say "Patched PID: $pid; both opt-in flags verified."
    say 'Visually inspect corners, width, icon/title/body, timestamp, urgency, stacks and close button.'
    say 'Exact restore command:'
    cat "$backup/restore-command.txt"
    switching=false
}
status_test() {
    find_daemons
    if [[ ${#daemons[@]} = 0 ]]; then say 'No notification daemon found.'; return 0; fi
    [[ ${#daemons[@]} = 1 ]] || { fail "Multiple notification daemons: ${daemons[*]}"; return 1; }
    pid=${daemons[0]}
    local executable
    executable=$(exe_of "$pid")
    case $executable in
        "$stock") say "Stock daemon: PID $pid" ;;
        "$patched") say "Patched daemon: PID $pid"; verify_opt_in ;;
        *) fail "Unknown daemon executable: $executable" ;;
    esac
    snapshot "$pid"
}
main() {
    [[ $# -ge 1 && $# -le 2 ]] || { say 'Usage: apply-notification-test-host.sh check|apply|status|restore [BACKUP_DIRECTORY]'; return 2; }
    [[ $# = 1 || $1 = restore ]] || { fail 'Only restore accepts a backup directory.'; return 1; }
    case $1 in
        check) precheck ;;
        apply) apply_test ;;
        status) host_checks; status_test ;;
        restore)
            host_checks
            backup=${2:-}
            lock_helper
            [[ ! -L $log ]] || { fail 'Refusing a symlinked log path.'; return 1; }
            restore_internal ;;
        *) fail 'Unknown subcommand.' ;;
    esac
}
if [[ ${BASH_SOURCE[0]} = "$0" ]]; then main "$@"; fi
