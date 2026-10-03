#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Explicit host Git publication; never installs/restarts desktop components.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo"
branch=feat/notification-center-finalize
resume=false
case ${1:-} in
    '') [[ $# = 0 ]] || exit 2;;
    --resume) [[ $# = 1 ]] || exit 2; resume=true;;
    *) echo 'Usage: publish-notification-finalize.sh [--resume]' >&2; exit 2;;
esac
if [[ $resume = true && $(git branch --show-current) != "$branch" ]]; then
    echo 'REFUSED: --resume requires the existing finalize branch.' >&2; exit 1
fi
remote=$(git remote get-url origin)
case $remote in
    git@github.com:rickallauigan/cosmic-refined.git|https://github.com/rickallauigan/cosmic-refined|https://github.com/rickallauigan/cosmic-refined.git) ;;
    *) echo 'REFUSED: unexpected origin.' >&2; exit 1;;
esac
[[ -w $(git rev-parse --git-dir) ]] || { echo 'REFUSED: run on a host with writable .git.' >&2; exit 1; }
command -v gh >/dev/null
gh auth status >/dev/null
if [[ $resume = false ]]; then
    git diff --cached --quiet || { echo 'REFUSED: use --resume for an interrupted publication on the finalize branch.' >&2; exit 1; }
fi
bash scripts/validate.sh --notifications
shellcheck scripts/notification-package-test.sh scripts/notification-center-package-test.sh scripts/notification-live-validate.sh scripts/publish-notification-finalize.sh tests/notification-package.sh tests/notification-center.sh tests/notification-live-validate.sh tests/uniform-glass.sh packaging/arch/PKGBUILD packaging/arch/notification-center/PKGBUILD
git fetch origin
if [[ $(git branch --show-current) != "$branch" ]]; then
    git show-ref --verify --quiet "refs/heads/$branch" && { echo 'REFUSED: existing finalize branch; inspect before switching dirty work.' >&2; exit 1; }
    git switch -c "$branch"
fi
commit_group() {
    local message=$1; shift
    # Skip already committed groups even when a later group is staged.
    if git diff HEAD --quiet -- "$@" && [[ -z $(git ls-files --others --exclude-standard -- "$@") ]]; then return 0; fi
    local staged allowed candidate
    while IFS= read -r staged; do
        allowed=false
        for candidate in "$@"; do [[ $staged != "$candidate" ]] || allowed=true; done
        [[ $allowed = true ]] || { echo "REFUSED: staged path outside current commit group: $staged" >&2; return 1; }
    done < <(git diff --cached --name-only)
    git add -- "$@"
    git diff --cached --check
    if ! git diff --cached --quiet; then git commit -m "$message"; fi
}
commit_group 'Add Refined notification center source patch' \
    notifications/patches/cosmic-applets-1.9.0-refined-notification-center.patch \
    tests/fixtures/cosmic-applets-1.9.0/lib.rs tests/fixtures/cosmic-applets-1.9.0/en.ftl \
    tests/fixtures/cosmic-applets-1.9.0/README.md
commit_group 'Add reversible Arch notification package workflows' \
    packaging/arch/PKGBUILD packaging/arch/README.md packaging/arch/refined-package-defaults.patch \
    packaging/arch/notification-center/PKGBUILD packaging/arch/notification-center/README.md \
    packaging/arch/notification-center/arch-upstream.PKGBUILD packaging/arch/notification-center/stock-files.txt \
    scripts/notification-package-test.sh scripts/notification-center-package-test.sh \
    scripts/notification-next-login-test.sh tests/notification-package.sh tests/notification-center.sh \
    tests/notification-next-login.sh docs/notification-package-test.md docs/notification-next-login-test.md
commit_group 'Adapt Uniform Glass themes to COSMIC 1.9 frosting schema' \
    themes/uniform-glass/UniformGlassDark.ron themes/uniform-glass/UniformGlassDarkPerformance.ron \
    themes/uniform-glass/README.md tests/uniform-glass.sh tests/theme-schema.rs
commit_group 'Record live notification validation and add CI coverage' \
    README.md CHANGELOG.md docs/development-status.md docs/app-switcher.md \
    docs/notification-center.md docs/notification-session-conflicts.md docs/notification-architecture.md \
    docs/notification-build-validation.md docs/notification-live-test.md docs/notification-visibility.md \
    docs/provenance.md docs/validation.md notifications/README.md notifications/patches/README.md \
    scripts/README.md scripts/validate.sh scripts/notification-live-validate.sh \
    scripts/publish-notification-finalize.sh tests/notification-live-validate.sh \
    .github/workflows/notification-center-build.yml
git diff --exit-code
git push -u origin "$branch"
existing=$(gh pr list --repo rickallauigan/cosmic-refined --head "$branch" --base main --state open --json url --jq '.[0].url // empty')
if [[ -n $existing ]]; then
    printf 'PR: %s\n' "$existing"
else
    body=$(mktemp)
    trap 'rm -f -- "$body"' EXIT
    cat > "$body" <<'BODY'
Refined notification history now has notification-local cards while preserving native grouping, actions, DND and relative-time logic. The user has passed visual validation on COSMIC 1.9; detailed live interaction checks remain separate.

Includes reversible pinned Arch package workflows, supported COSMIC 1.9 frosting fields (performance effects disabled), host diagnostics, session-conflict documentation and pinned center/theme CI. No live session changes, Vicinae changes, polling services or automatic restarts.

Validation: repository fixtures, ShellCheck, syntax and whitespace pass; pinned theme deserialization and locked center check pass. Existing built package matches the live binary; a duplicate release rebuild was interrupted. CI and full diff review are required before merge. Switcher work is architecture investigation only.
BODY
    gh pr create --repo rickallauigan/cosmic-refined --base main --head "$branch" \
        --title 'Finalize Refined notifications, Arch packaging and COSMIC 1.9 themes' --body-file "$body"
fi
git log --oneline -5
git status --short
echo 'Published without merging. Review CI and the complete PR diff before merge.'
