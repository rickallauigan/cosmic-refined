#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Host Git publication only. Never installs or launches a desktop component.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo"
branch=feat/app-switcher
[[ $# = 0 ]] || exit 2
case $(git remote get-url origin) in
    git@github.com:rickallauigan/cosmic-refined.git|https://github.com/rickallauigan/cosmic-refined|https://github.com/rickallauigan/cosmic-refined.git) ;;
    *) echo 'REFUSED: unexpected origin.' >&2; exit 1;;
esac
git diff --cached --quiet || { echo 'REFUSED: inspect existing staged changes first.' >&2; exit 1; }
current=$(git branch --show-current)
[[ $current = main || $current = "$branch" ]] || { echo 'REFUSED: requires merged main or the switcher branch.' >&2; exit 1; }
bash scripts/validate.sh --notifications
shellcheck scripts/app-switcher-package-test.sh scripts/app-switcher-host-validate.sh scripts/publish-app-switcher.sh tests/app-switcher.sh tests/app-switcher-host.sh packaging/arch/app-switcher/PKGBUILD
# The host has normal Cargo network/cache access; gate publication on a real build.
build_log=$(mktemp /tmp/refined-switcher-host-build.XXXXXXXX)
if ! bash scripts/app-switcher-package-test.sh build > "$build_log" 2>&1; then
    tail -n 80 "$build_log"
    echo "Build failed; nothing was published. Full log: $build_log" >&2
    exit 1
fi
cat -- "$build_log"
baseline_dir=$(mktemp -d /tmp/refined-switcher-stock.XXXXXXXX)
bash scripts/app-switcher-host-validate.sh baseline "$baseline_dir/baseline.txt"
git fetch origin
git merge-base --is-ancestor dda24527e078d7e765b084016a2412610d7f387d HEAD
if [[ $current = main ]]; then
    [[ $(git rev-parse HEAD) = "$(git rev-parse origin/main)" ]] || { echo 'REFUSED: main changed; review/rebase explicitly first.' >&2; exit 1; }
    git switch -c "$branch"
fi
commit_group() {
    local message=$1; shift
    if git diff HEAD --quiet -- "$@" && [[ -z $(git ls-files --others --exclude-standard -- "$@") ]]; then return; fi
    git add -- "$@"
    git diff --cached --check
    git commit -m "$message"
}
commit_group 'Add native window-mode Refined switcher patch' switcher tests/fixtures/cosmic-launcher-1.9.0 tests/app-switcher.sh
commit_group 'Add reversible Arch switcher package and host validation' packaging/arch/app-switcher scripts/app-switcher-package-test.sh scripts/app-switcher-host-validate.sh tests/app-switcher-host.sh
commit_group 'Document switcher architecture and add pinned build CI' .github/workflows/app-switcher-build.yml scripts/validate.sh scripts/publish-app-switcher.sh docs/app-switcher.md docs/development-status.md docs/provenance.md README.md
git push -u origin "$branch"
if [[ -z $(gh pr list --head "$branch" --base main --json number --jq '.[].number') ]]; then
    body=$(mktemp)
    trap 'rm -f -- "$body"' EXIT
    cat > "$body" <<'BODY'
Refine only COSMIC 1.9's native Alt+Tab window-mode presentation: centered opaque cards, large app icons, visible selection and window title. Native search rendering, metadata, activation, reverse switching and resident lifecycle stay unchanged. Vicinae remains launcher/search.

Adds pinned Arch packaging, independent stock rollback, host snapshot/checksum tooling and source/payload fixtures. No live installation, session restart, timers or new service. Repository fixtures/lint and the host package build pass; pinned CI must also pass. The sandbox check was blocked by uncached Cargo dependencies. The stock host snapshot and build artifacts stay outside Git. Do not merge or install until CI and complete diff review pass.
BODY
    gh pr create --base main --head "$branch" --title 'Add Refined native COSMIC window switcher' --body-file "$body"
fi
gh pr view "$branch" --json url --jq .url
echo 'Publication complete. CI and full diff review remain required; no automatic merge or installation.'
