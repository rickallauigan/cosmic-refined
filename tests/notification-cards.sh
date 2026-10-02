#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Offline source patch fixtures only; no desktop processes/configuration involved.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/src"
cp "$repo/tests/fixtures/cosmic-notifications-1.9.0-app.rs" "$fixture/src/app.rs"
cp "$repo/tests/fixtures/cosmic-notifications-1.9.0-main.rs" "$fixture/src/main.rs"
patch=$repo/notifications/patches/cosmic-notifications-1.9.0-refined-cards.patch
(
    cd "$fixture"
    git apply --check "$patch"
    git apply "$patch"
    # Reapplication must fail safely rather than duplicating source modifications.
    if git apply --check "$patch" 2>/dev/null; then
        echo 'Expected already-applied patch rejection' >&2; exit 1
    fi
    rustfmt --edition 2024 --config skip_children=true --check src/app.rs src/main.rs src/refined_cards.rs
    rustc --edition 2024 --test src/refined_cards.rs -o policy-tests
    ./policy-tests
    git apply --reverse --check "$patch"
    git apply --reverse "$patch"
)
cmp "$fixture/src/app.rs" "$repo/tests/fixtures/cosmic-notifications-1.9.0-app.rs"
cmp "$fixture/src/main.rs" "$repo/tests/fixtures/cosmic-notifications-1.9.0-main.rs"
[[ ! -e $fixture/src/refined_cards.rs ]]
# Different upstream source must be rejected, without writing anything.
printf 'unsupported upstream source\n' > "$fixture/src/app.rs"
if (cd "$fixture" && git apply --check "$patch" 2>/dev/null); then
    echo 'Expected incompatible-source rejection' >&2; exit 1
fi
[[ $(cat "$fixture/src/app.rs") = 'unsupported upstream source' ]]
echo 'PASS: source patch/reverse, reapply/drift rejection, Rust syntax and policy tests'
