# Optional macOS-inspired performance layout

Designed from the native panel/dock v1 keys installed with COSMIC 1.9.0.
This is a geometry preset, independent of theme import. The original theme is
unchanged. Import `themes/uniform-glass/UniformGlassDarkPerformance.ron` separately in Appearance
if you want its frosted-blur opt-out.

| Setting | Top panel | Bottom dock |
| --- | --- | --- |
| Size | XS | M |
| Padding / item spacing | 2 / 4 | 6 / 4 |
| Margin / radius | 0 / 0 | 8 / 12 |
| Expand to edges | Yes | No |
| Anchor gap | No | Yes |
| Reserve space (exclusive zone) | Yes | Yes |
| Autohide | Never | Never |

Both use opacity 1.0, border width 0.0 and keep their style when a window is
maximized. Opacity 1.0 avoids additional panel-level fading; the theme can
still supply translucent surfaces. The floating dock reserves room for windows,
trading some workspace for predictable visibility. Your applets, their ordering,
clock, notification tray, pinned apps, output selection and background choice
are preserved. Existing per-section size overrides (`size_center`/`size_wings`)
are preserved too; set them to the default in COSMIC Settings if they override
the preset's size.

## Apply explicitly

From the repository root, as your regular desktop user:

```sh
bash presets/macos-performance/install.sh
```

The script requires existing Panel and Dock v1 directories and all managed
keys. Open COSMIC Settings → Desktop → Panel/Dock first if those are missing.
It refuses missing keys or symbolic-link targets rather than guessing another
schema. It honors an absolute `XDG_CONFIG_HOME`, defaulting to `~/.config`.
No root access or new packages are required: Bash and standard file tools only.

Before changing any key, it copies **both complete configuration directories**
to a private, unique directory under `~/.config/cosmic/cosmic-refined-backups/`
(or the corresponding XDG directory) and prints its path. Keep that path.
Reapplying identical managed values is a no-op. Each key is replaced atomically;
normal errors and interrupt/termination signals trigger rollback of managed keys.
The entire multi-key update is not atomic: sudden power loss or SIGKILL can
interrupt it. The backup remains available for recovery.

Close Panel/Dock settings while applying or restoring, to avoid concurrent writes.
COSMIC may refresh automatically; log out and back in if needed. The script
does not restart desktop processes. Remove a stale `.macos-performance-lock`
directory under the COSMIC config root only after checking no installer is running.

## Restore

Use the exact path printed during installation:

```sh
bash presets/macos-performance/install.sh restore /absolute/path/to/macos-performance.BACKUP_ID
```

Restore backs up the current configuration first, then restores only keys managed
by this preset. Later applet/pin changes are preserved. Full directory snapshots
are retained for manual recovery if you also want to undo unrelated changes;
copy them only while logged out of COSMIC to avoid competing writes.

## Performance and scope

Only native geometry and visibility settings change. No additional process,
polling, dock magnification, blur daemon, compositor patch, or animation service
is introduced. Autohide is disabled, so there are no autohide transitions.
This does not claim measured FPS or power savings on Intel Iris Xe: it avoids
adding background work. The legacy performance theme's `is_frosted: false`
intent is retained; newer COSMIC exports have separate frosted flags, so verify
blur switches in Appearance after importing on a newer schema.

Validated using temporary configuration fixtures; the live desktop was not
modified and visual results have not been tested in a live session.
Notification banner colors are unchanged; see [notification visibility](../../docs/notification-visibility.md).

Adapted from the old Uniform Glass fork prototype; see [provenance](../../docs/provenance.md).
Backups now use `cosmic-refined-backups`; the managed keys and restore format are unchanged.
To remove the preset, restore its backup first, then remove the checkout if desired.
Backups remain until you explicitly remove them after verifying recovery.
