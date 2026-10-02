#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Run explicitly; never invoked by theme import.
set -euo pipefail
umask 077
preset=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config=${XDG_CONFIG_HOME:-${HOME:?HOME is required}/.config}/cosmic
[[ $config = /* ]] || { echo 'XDG_CONFIG_HOME must be absolute.' >&2; exit 1; }
action=${1:-apply}
case $action in
    apply) [[ $# -le 1 ]] || exit 2; source_dir=$preset ;;
    restore)
        [[ $# = 2 && -f $2/complete ]] || { echo 'Usage: install.sh restore BACKUP_DIRECTORY' >&2; exit 2; }
        source_dir=$(cd -- "$2" && pwd)
        [[ $(cat "$source_dir/complete") = macos-performance-v1 ]] || exit 2
        ;;
    *) echo 'Usage: install.sh [apply | restore BACKUP_DIRECTORY]' >&2; exit 2 ;;
esac
# Refuse unsupported/missing configurations and symbolic-link targets.
for part in Panel Dock; do
    target=$config/com.system76.CosmicPanel.$part/v1
    [[ -d $target && ! -L $target && ! -L ${target%/v1} ]] || { echo "Unsafe or missing directory: $target" >&2; exit 1; }
    for value in "$preset/$part"/*; do
        key=${value##*/}
        [[ -f $target/$key && ! -L $target/$key && -f $source_dir/$part/$key && ! -L $source_dir/$part/$key ]] || { echo "Unsafe or missing key: $part/$key" >&2; exit 1; }
    done
done
lock=$config/.macos-performance-lock
mkdir -- "$lock" || { echo 'Another operation is running, or a stale lock exists.' >&2; exit 1; }
backup=
changing=false
finished=false
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    if $changing && ! $finished; then
        echo "Operation failed; restoring managed keys from $backup" >&2
        for part in Panel Dock; do
            target=$config/com.system76.CosmicPanel.$part/v1
            for value in "$preset/$part"/*; do
                key=${value##*/}
                if ! cp -- "$backup/$part/$key" "$lock/value" || ! mv -f -- "$lock/value" "$target/$key"; then
                    echo "Rollback failed for $part/$key; keep backup: $backup" >&2
                fi
            done
        done
    fi
    rm -f -- "$lock/value"
    rmdir -- "$lock" || true
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
# A repeated apply/restore does not create a redundant backup.
same=true
for part in Panel Dock; do
    for value in "$preset/$part"/*; do
        key=${value##*/}
        cmp -s -- "$source_dir/$part/$key" "$config/com.system76.CosmicPanel.$part/v1/$key" || same=false
    done
done
if $same; then
    echo 'Managed keys already match; nothing changed.'
    exit 0
fi
mkdir -p -- "$config/cosmic-refined-backups"
backup=$(mktemp -d "$config/cosmic-refined-backups/macos-performance.XXXXXXXX")
# Both full directories must be copied successfully before any key is changed.
for part in Panel Dock; do
    cp -a -- "$config/com.system76.CosmicPanel.$part/v1" "$backup/$part"
done
printf '%s\n' macos-performance-v1 > "$backup/complete"
printf 'Backup: %s\n' "$backup"
changing=true
for part in Panel Dock; do
    target=$config/com.system76.CosmicPanel.$part/v1
    for value in "$preset/$part"/*; do
        key=${value##*/}
        cp -- "$source_dir/$part/$key" "$lock/value"
        mv -f -- "$lock/value" "$target/$key"
    done
done
finished=true
printf 'Completed %s. Log out and back in if COSMIC has not refreshed the layout.\n' "$action"
printf 'Restore managed keys: bash %q restore %q\n' "$preset/install.sh" "$backup"
