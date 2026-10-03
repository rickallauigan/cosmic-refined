#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/proc/123"
ln -s /usr/bin/cosmic-launcher "$fixture/proc/123/exe"
cat > "$fixture/bin/pacman" <<'MOCK'
#!/bin/bash
case "$1" in
    -Q) printf '%s 1:1.9.0-1\n' "$2";;
    -Qoq) echo cosmic-switcher-refined;;
    *) echo 'fixture package owner';;
esac
MOCK
cat > "$fixture/bin/sha256sum" <<'MOCK'
#!/bin/bash
[[ $# = 1 ]] || exit 1
case "$1" in
    /usr/bin/cosmic-launcher) printf '%s  %s\n' "$fixture_sha" "$1";;
    "$COSMIC_REFINED_TEST_PROC/123/exe") printf '%s  %s\n' "$fixture_live_sha" "$1";;
    *) exit 1;;
esac
MOCK
cat > "$fixture/bin/ps" <<'MOCK'
#!/bin/bash
printf '123 100 45 1024 0.0 cosmic-launcher\n'
MOCK
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH" COSMIC_REFINED_TEST_PROC="$fixture/proc"
export fixture_sha=3161e8c11eac76766efa60c3403d7b0a7d2b5acda151539bf8f1293573772d68
bash "$repo/scripts/app-switcher-host-validate.sh" baseline "$fixture/baseline" > /dev/null
if bash "$repo/scripts/app-switcher-host-validate.sh" baseline "$fixture/baseline" >/dev/null 2>&1; then exit 1; fi
bash "$repo/scripts/app-switcher-host-validate.sh" status > "$fixture/status"
grep -q 'Native component: /usr/bin/cosmic-launcher' "$fixture/status"
# Verify fails before any package/status helper call on checksum mismatch.
export fixture_sha=0000000000000000000000000000000000000000000000000000000000000000
if bash "$repo/scripts/app-switcher-host-validate.sh" verify 1111111111111111111111111111111111111111111111111111111111111111 "$fixture/baseline" >/dev/null 2>&1; then exit 1; fi
# Package status is tested separately; isolate that subprocess for host-check fixtures.
# Match the literal variable in the script, not this fixture's repo path.
# shellcheck disable=SC2016
sed 's|bash "$repo/scripts/app-switcher-package-test.sh" status|echo fixture-package-status|' \
    "$repo/scripts/app-switcher-host-validate.sh" > "$fixture/run.sh"
export fixture_live_sha=$fixture_sha
bash "$fixture/run.sh" verify "$fixture_sha" "$fixture/baseline" > "$fixture/verified"
grep -q 'fixture-package-status' "$fixture/verified"
export fixture_live_sha=1111111111111111111111111111111111111111111111111111111111111111
if bash "$fixture/run.sh" verify "$fixture_sha" "$fixture/baseline" > "$fixture/stale" 2>&1; then exit 1; fi
grep -q 'Loaded frontend differs' "$fixture/stale"
echo 'PASS: host snapshots use fixture processes/checksums, preserve baselines and reject mismatched binaries'
