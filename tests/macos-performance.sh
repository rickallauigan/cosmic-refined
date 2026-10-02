#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export XDG_CONFIG_HOME=$fixture/config
preset=$repo/presets/macos-performance
for part in Panel Dock; do
    mkdir -p "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part"
    cp -a "$preset/$part" "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1"
    printf '20\n' > "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1/margin"
    printf 'keep me\n' > "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1/unmanaged"
done
cp -a "$XDG_CONFIG_HOME" "$fixture/original"
bash "$preset/install.sh" > "$fixture/apply.log"
backup=$(sed -n 's/^Backup: //p' "$fixture/apply.log")
for part in Panel Dock; do
    diff -r "$backup/$part" "$fixture/original/cosmic/com.system76.CosmicPanel.$part/v1"
    for value in "$preset/$part"/*; do
        cmp "$value" "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1/${value##*/}"
    done
done
output=$(bash "$preset/install.sh")
[[ $output = *'nothing changed'* ]]
[[ $(find "$XDG_CONFIG_HOME/cosmic/cosmic-refined-backups" -mindepth 1 -maxdepth 1 -type d | wc -l) = 1 ]]
bash "$preset/install.sh" restore "$backup" > "$fixture/restore.log"
for part in Panel Dock; do
    diff -r "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1" "$fixture/original/cosmic/com.system76.CosmicPanel.$part/v1"
done
# Fail one atomic replacement after a previous key changed; rollback must recover.
mkdir "$fixture/bin"
real_mv=$(command -v mv)
cat > "$fixture/bin/mv" <<EOF_MV
#!/usr/bin/env bash
if [[ \${*: -1} = */border_radius && ! -e '$fixture/failed' ]]; then
    touch '$fixture/failed'
    exit 1
fi
exec '$real_mv' "\$@"
EOF_MV
chmod +x "$fixture/bin/mv"
if PATH="$fixture/bin:$PATH" bash "$preset/install.sh" > "$fixture/failure.log" 2>&1; then
    echo 'Expected simulated write failure' >&2; exit 1
fi
for part in Panel Dock; do
    diff -r "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1" "$fixture/original/cosmic/com.system76.CosmicPanel.$part/v1"
done
[[ ! -e $XDG_CONFIG_HOME/cosmic/.macos-performance-lock ]]
# A failed second directory backup must never change either live fixture directory.
real_cp=$(command -v cp)
cat > "$fixture/bin/cp" <<EOF_CP
#!/usr/bin/env bash
if [[ \${*: -1} = */Dock ]]; then exit 1; fi
exec '$real_cp' "\$@"
EOF_CP
chmod +x "$fixture/bin/cp"
if PATH="$fixture/bin:$PATH" bash "$preset/install.sh" > "$fixture/backup-failure.log" 2>&1; then exit 1; fi
for part in Panel Dock; do
    diff -r "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.$part/v1" "$fixture/original/cosmic/com.system76.CosmicPanel.$part/v1"
done
[[ ! -e $XDG_CONFIG_HOME/cosmic/.macos-performance-lock ]]
rm "$fixture/bin/cp"
# Reject a symbolic-link managed key before any writes.
target=$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.Dock/v1
mv "$target/size" "$fixture/saved-size"
ln -s "$fixture/saved-size" "$target/size"
cp -a "$XDG_CONFIG_HOME" "$fixture/before-symlink"
if bash "$preset/install.sh" > "$fixture/symlink.log" 2>&1; then exit 1; fi
diff -r "$XDG_CONFIG_HOME" "$fixture/before-symlink"
rm "$target/size"
mv "$fixture/saved-size" "$target/size"
# Missing key: no writes or backup should occur.
rm "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.Dock/v1/size"
cp -a "$XDG_CONFIG_HOME" "$fixture/before-rejection"
if bash "$preset/install.sh" > "$fixture/rejection.log" 2>&1; then exit 1; fi
diff -r "$XDG_CONFIG_HOME" "$fixture/before-rejection"
echo 'PASS: backup, apply, idempotence, restore, write-failure rollback, backup-failure safety, symlink/missing-key rejection'
