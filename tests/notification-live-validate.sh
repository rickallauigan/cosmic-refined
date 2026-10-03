#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/proc/123" "$fixture/proc/456"
printf 'cosmic-applet-notifications\0' > "$fixture/proc/456/cmdline"
ln -s /usr/bin/cosmic-notifications "$fixture/proc/123/exe"
ln -s /usr/bin/cosmic-applets "$fixture/proc/456/exe"
sed "s|/proc/|$fixture/proc/|g" "$repo/scripts/notification-live-validate.sh" > "$fixture/run.sh"
cat > "$fixture/bin/pacman" <<'MOCK'
#!/bin/bash
if [[ $1 = -Qoq ]]; then echo cosmic-applets-refined; else echo "$2 1:1.9.0-1"; fi
MOCK
cat > "$fixture/bin/busctl" <<'MOCK'
#!/bin/bash
if [[ $* = *GetNameOwner* ]]; then echo 's ":1.42"'; else echo 'u 123'; fi
MOCK
cat > "$fixture/bin/systemctl" <<'MOCK'
#!/bin/bash
echo masked
MOCK
cat > "$fixture/bin/journalctl" <<'MOCK'
#!/bin/bash
echo 'No entries'
MOCK
cat > "$fixture/bin/notify-send" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$test_notifications"
MOCK
cat > "$fixture/bin/sha256sum" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ $# = 2 && $1 = /usr/bin/cosmic-applets && $2 = /usr/bin/cosmic-notifications ]]
# Synthetic hashes; never read the host's packaged binaries.
printf '%064d  %s\n' 1 "$1" 2 "$2"
MOCK
chmod +x "$fixture/bin/"*
export test_notifications="$fixture/notifications"
PATH="$fixture/bin:$PATH" bash "$fixture/run.sh" --test > "$fixture/output"
[[ $(wc -l < "$fixture/notifications") = 3 ]]
grep -q 'Notification DBus owner: PID 123' "$fixture/output"
grep -q 'Notification applet: PID 456' "$fixture/output"
grep -q '^0000000000000000000000000000000000000000000000000000000000000001  /usr/bin/cosmic-applets$' "$fixture/output"
grep -q '^0000000000000000000000000000000000000000000000000000000000000002  /usr/bin/cosmic-notifications$' "$fixture/output"
rm "$fixture/proc/123/exe"
ln -s /usr/bin/mako "$fixture/proc/123/exe"
if PATH="$fixture/bin:$PATH" bash "$fixture/run.sh" > /dev/null 2>&1; then exit 1; fi
[[ $(wc -l < "$fixture/notifications") = 3 ]]
echo 'PASS: host evidence parsing, applet discovery, grouped tests and refusal of wrong DBus owner; no live session access'
