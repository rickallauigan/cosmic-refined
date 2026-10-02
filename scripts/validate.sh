#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Development checks only. Never apply a preset to the live desktop.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo"
case ${1:-} in
    "" | --notifications) [[ $# -le 1 ]] || exit 2 ;;
    *) echo "Usage: validate.sh [--notifications]" >&2; exit 2 ;;
esac
git diff --check
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(find scripts tests presets -type f -name '*.sh' -print0)
bash tests/uniform-glass.sh
bash tests/macos-performance.sh
bash tests/notification-host-helper.sh
if [[ ${1:-} = --notifications ]]; then
    bash tests/notification-cards.sh
fi
[[ -s LICENSE && -s docs/provenance.md && -s themes/uniform-glass/LICENSE ]]
echo 'PASS: whitespace, shell syntax, fixture tests and attribution files'
