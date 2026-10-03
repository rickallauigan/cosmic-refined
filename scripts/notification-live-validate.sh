#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Run on the host; read-only checks, with optional three local test notifications.
set -euo pipefail
case ${1:-} in ''|--test) ;; *) echo 'Usage: notification-live-validate.sh [--test]' >&2; exit 2;; esac
for dependency in pacman busctl readlink; do command -v "$dependency" >/dev/null; done
for package in cosmic-notifications-refined cosmic-applets-refined; do
    [[ $(pacman -Q "$package") = "$package 1:1.9.0-1" ]] || { echo "Unexpected package: $package" >&2; exit 1; }
done
[[ $(pacman -Qoq /usr/bin/cosmic-applets) = cosmic-applets-refined ]]
owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications)
owner=${owner#s \"}; owner=${owner%\"}
reply=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$owner")
pid=${reply#u }
[[ $pid =~ ^[0-9]+$ && $(readlink "/proc/$pid/exe") = /usr/bin/cosmic-notifications ]] || { echo 'Unexpected notification bus owner.' >&2; exit 1; }
printf 'Notification DBus owner: PID %s, /usr/bin/cosmic-notifications\n' "$pid"
found=false
for process in /proc/[0-9]*; do
    [[ -O $process && -r $process/cmdline ]] || continue
    first=
    IFS= read -r -d '' first < "$process/cmdline" || true
    if [[ ${first##*/} = cosmic-applet-notifications ]]; then
        printf 'Notification applet: PID %s, %s\n' "${process##*/}" "$(readlink "$process/exe")"
        found=true
    fi
done
[[ $found = true ]] || { echo 'Notification applet is not running.' >&2; exit 1; }
sha256sum /usr/bin/cosmic-applets /usr/bin/cosmic-notifications
if command -v systemctl >/dev/null; then
    echo 'mako unit state (the existing mask is never changed):'
    systemctl --user is-enabled mako.service || true
fi
if command -v journalctl >/dev/null; then
    echo 'Recent notification/applet errors (no matches is normal):'
    journalctl --user --since '5 minutes ago' --no-pager -p err _EXE=/usr/bin/cosmic-applets _EXE=/usr/bin/cosmic-notifications _EXE=/usr/bin/cosmic-panel || true
fi
if [[ ${1:-} = --test ]]; then
    command -v notify-send >/dev/null
    notify-send -a 'COSMIC Refined validation' -i dialog-information 'Refined center test 1' 'Normal card: inspect title, body, timestamp and dismissal.'
    notify-send -a 'COSMIC Refined validation' -i dialog-information 'Refined center test 2' 'Same app group: inspect count, expansion, scrolling and clear-group.'
    notify-send -a 'COSMIC Refined validation' -u critical -i dialog-warning 'Refined center critical' 'Critical border and text cue; normal cards should stay neutral.'
    echo 'Open notification history and inspect grouping, collapse/expand, dismissal, clear-all and DND. No notification action is supplied by notify-send in these tests.'
fi
