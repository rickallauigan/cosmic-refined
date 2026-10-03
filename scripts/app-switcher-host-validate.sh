#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Explicit host snapshots only; no launch, signals, subscriptions or timers.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
proc_root=${COSMIC_REFINED_TEST_PROC:-/proc}
expected_runtime_sha=
stock_sha=3161e8c11eac76766efa60c3403d7b0a7d2b5acda151539bf8f1293573772d68
snapshot() {
    local process executable digest
    printf 'Snapshot UTC: '; date -u +%FT%TZ
    pacman -Qo /usr/bin/cosmic-launcher
    sha256sum /usr/bin/cosmic-launcher
    for process in "$proc_root"/[0-9]*; do
        [[ -O $process ]] || continue
        executable=$(readlink "$process/exe" 2>/dev/null || true)
        case ${executable##*/} in
            cosmic-launcher|'cosmic-launcher (deleted)'|pop-launcher|cosmic-toplevel)
                printf 'Native component: %s\n' "$executable"
                ps -p "${process##*/}" -o pid,ppid,etimes,rss,pcpu,args || echo 'Process exited during snapshot.'
                if [[ -n $expected_runtime_sha && $executable = /usr/bin/cosmic-launcher* ]]; then
                    if digest=$(sha256sum "$process/exe" 2>/dev/null); then
                        [[ ${digest%% *} = "$expected_runtime_sha" ]] || {
                            echo 'Loaded frontend differs from the package; manual logout/login is required.' >&2
                            return 1
                        }
                    else
                        echo 'Frontend exited during checksum snapshot; verify again after invocation.'
                    fi
                fi
                ;;
        esac
    done
    echo 'RSS is KiB; CPU is lifetime-average, not an idle interval measurement.'
    echo 'Compare idle/open/dismissed snapshots; native frontend may remain resident.'
}
case ${1:-status} in
    status) [[ $# -le 1 ]]; snapshot;;
    baseline)
        [[ $# = 2 && ! -e $2 && ! -L $2 ]] || { echo 'Usage: baseline NEW_FILE' >&2; exit 2; }
        [[ $(pacman -Q cosmic-launcher) = 'cosmic-launcher 1:1.9.0-1' ]]
        [[ $(sha256sum /usr/bin/cosmic-launcher | awk '{print $1}') = "$stock_sha" ]]
        # Noclobber prevents replacing an existing baseline even in a race.
        (umask 077; set -C; snapshot > "$2")
        echo "Stock snapshot: $2. Repeat status while holding Alt+Tab, then after dismissal."
        ;;
    verify)
        [[ $# = 3 && $2 =~ ^[0-9a-f]{64}$ && -f $3 ]] || { echo 'Usage: verify EXPECTED_BINARY_SHA256 BASELINE_FILE' >&2; exit 2; }
        [[ $(pacman -Q cosmic-switcher-refined) = 'cosmic-switcher-refined 1:1.9.0-1' ]]
        [[ $(pacman -Qoq /usr/bin/cosmic-launcher) = cosmic-switcher-refined ]]
        [[ $(sha256sum /usr/bin/cosmic-launcher | awk '{print $1}') = "$2" ]]
        expected_runtime_sha=$2
        echo 'Baseline:'; cat -- "$3"
        echo 'Current:'; snapshot
        echo 'Package inventory must match stock; no additional service/autostart is allowed.'
        echo 'Snapshots expose native process presence; they cannot prove the absence of every unrelated process.'
        bash "$repo/scripts/app-switcher-package-test.sh" status
        ;;
    *) echo 'Usage: app-switcher-host-validate.sh {status|baseline NEW_FILE|verify SHA256 BASELINE_FILE}' >&2; exit 2;;
esac
