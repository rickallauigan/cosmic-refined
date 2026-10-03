# Notification daemon ownership across sessions

The ThinkPad user reports mako previously owned `org.freedesktop.Notifications`,
preventing the COSMIC notification applet from starting. The user's mako mask
resolved the conflict. Keep that mask while using COSMIC; this project never
unmasks, enables, starts or stops mako automatically.

The installed mako unit is `Type=dbus`, claims `org.freedesktop.Notifications`,
and uses only `WAYLAND_DISPLAY` as its ExecCondition. That condition accepts both
COSMIC and Hyprland. Its D-Bus activation file names `mako.service`, but also has
a direct `Exec=/usr/bin/mako` fallback. Enabling mako for graphical-session.target
is therefore not a session selector. COSMIC supervises its own daemon directly.
Both cannot own the same notification name on one user bus.

A desktop-specific systemd condition alone is insufficient without proving which
session environment the user manager inherits and whether D-Bus uses systemd
activation or its direct fallback. Concurrent sessions for the same user generally
share a user bus, so separate Wayland displays do not isolate notification ownership.
We have not verified a reliable session-specific activation chain on this host.
No speculative drop-in, desktop override, environment hook or polling service is
introduced. Keep mako masked for COSMIC. Session-aware Hyprland handling remains
future work requiring explicit lifecycle and D-Bus-activation verification.

For host evidence and three safe local notifications, run:

```sh
bash scripts/notification-live-validate.sh --test
```

This checks package versions, owner executable, applet process and recent error
logs. It only reads session state and optionally sends notifications. It does not
change DND, configuration, service masks, packages or running processes. Inspect
history visually afterward; notification activation needs a real application
with supplied actions and is not established by these notify-send tests.
