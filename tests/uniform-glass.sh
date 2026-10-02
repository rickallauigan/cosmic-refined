#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
theme=$repo/themes/uniform-glass
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
sed -e 's/name: "Uniform Glass Dark Performance"/name: "Uniform Glass Dark"/' \
    -e 's/is_frosted: false/is_frosted: true/' \
    "$theme/UniformGlassDarkPerformance.ron" > "$fixture/normalized.ron"
cmp "$theme/UniformGlassDark.ron" "$fixture/normalized.ron"
[[ $(sed -n '/name: "Uniform Glass Dark Performance"/p' "$theme/UniformGlassDarkPerformance.ron" | wc -l) = 1 ]]
[[ $(sed -n '/is_frosted: false/p' "$theme/UniformGlassDarkPerformance.ron" | wc -l) = 1 ]]
[[ -s $theme/LICENSE && -s $theme/README.md && -s $repo/LICENSE ]]
echo 'PASS: theme parity and license/attribution files'
