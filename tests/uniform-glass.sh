#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
theme=$repo/themes/uniform-glass
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
sed -e 's/name: "Uniform Glass Dark Performance"/name: "Uniform Glass Dark"/' \
    -e 's/frosted_windows: false/frosted_windows: true/' \
    -e 's/frosted_system_interface: false/frosted_system_interface: true/' \
    -e 's/frosted_panel: false/frosted_panel: true/' \
    -e 's/frosted_applets: false/frosted_applets: true/' \
    "$theme/UniformGlassDarkPerformance.ron" > "$fixture/normalized.ron"
cmp "$theme/UniformGlassDark.ron" "$fixture/normalized.ron"
[[ $(sed -n '/name: "Uniform Glass Dark Performance"/p' "$theme/UniformGlassDarkPerformance.ron" | wc -l) = 1 ]]
for key in frosted_windows frosted_system_interface frosted_panel frosted_applets frosted_maximized_apps; do
    [[ $(sed -n "/^    $key: false,$/p" "$theme/UniformGlassDarkPerformance.ron" | wc -l) = 1 ]]
done
[[ $(sed -n '/^    frosted_maximized_apps: false,$/p' "$theme/UniformGlassDark.ron" | wc -l) = 1 ]]
if grep -q 'is_frosted:' "$theme"/*.ron; then exit 1; fi
[[ -s $theme/LICENSE && -s $theme/README.md && -s $repo/LICENSE ]]
echo 'PASS: theme parity and license/attribution files'
