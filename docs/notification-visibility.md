# Notification visibility on COSMIC 1.9.0

**Result: documentation only.** Neither theme nor notification configuration is
changed by this work. Keep the existing lightweight `cosmic-notifications` daemon.
The layout preset preserves the notification tray and changes panel/dock geometry;
it does not restyle notification banners.

## How banners get their appearance

During the prototype investigation, the installed Arch packages inspected were `cosmic-notifications`, `cosmic-panel`
and `cosmic-applets` version `1:1.9.0-1`. The inspected local theme configuration had a builder
(`com.system76.CosmicTheme.Dark.Builder/v2`) and generated theme
(`com.system76.CosmicTheme.Dark/v2`), with shared `background`, `primary`,
`secondary`, component colors and separate frosted flags. No user notification
config directory was present during that investigation; absence means defaults, not a disabled daemon.

The [1.9.0 notification implementation](https://github.com/pop-os/cosmic-notifications/blob/epoch-1.9.0/src/app.rs)
builds banners with libcosmic's `cards` widget. The
[release lockfile](https://github.com/pop-os/cosmic-notifications/blob/epoch-1.9.0/Cargo.lock)
pins libcosmic to `d921602cde8248c070b493ce43b0edd388e19b9a`.
At that revision, [cards](https://github.com/pop-os/libcosmic/blob/d921602cde8248c070b493ce43b0edd388e19b9a/src/widget/cards.rs)
uses `theme::iced::Button::Card` for the front card. Its
[style implementation](https://github.com/pop-os/libcosmic/blob/d921602cde8248c070b493ce43b0edd388e19b9a/src/theme/style/iced.rs)
selects `theme.current_container().component`: `base` for its normal background,
`on` for text, `hover`/`pressed` for interaction, and `radius_xs` for corners.
The [stacked card style](https://github.com/pop-os/libcosmic/blob/d921602cde8248c070b493ce43b0edd388e19b9a/src/widget/card/style.rs)
also uses shared container hover/pressed colors according to the active theme layer.
Thus banner styling is not simply the theme's `bg_color` alpha.

The [notification v1 schema](https://github.com/pop-os/cosmic-notifications/blob/epoch-1.9.0/cosmic-notifications-config/src/lib.rs)
is `com.system76.CosmicNotifications/v1`. It exposes `do_not_disturb`, `anchor`,
`max_notifications`, `max_per_app`, and optional millisecond limits
`max_timeout_urgent`, `max_timeout_normal`, `max_timeout_low`. Default normal/low
limits are 5000/3000 ms; urgent has no configured cap. These are maximum limits,
not guarantees that every application's notification lasts that long. No
notification-specific surface, opacity, border, or text-color option exists there.
These findings come from matching release sources and local configuration,
not a rebuilt binary or a live notification rendering test.

## Why no extra theme variant was added

Changing builder background/container colors or generated shared component colors
would affect unrelated COSMIC UI. Editing generated theme keys directly can also
be overwritten when Appearance regenerates the theme. The original and performance
RON files therefore remain unchanged. No safely isolated notification-only theme
improvement was identified in this schema.

The existing performance variant differs only in name and `is_frosted: false`;
it does not increase notification contrast. The legacy import field should not be
confused with all the individual frosted switches in newer generated v2 themes.

## Clean optional approaches

For immediate visibility, use COSMIC Settings' notification controls to check
Do Not Disturb and application permissions. Keep the native notification tray
visible so missed banners can be reviewed. A quieter, darker wallpaper behind
banners can help when surfaces are translucent, without changing shared UI colors
or adding a process. None of these choices is applied automatically here.

For users comfortable managing native configuration, `anchor` and timeout caps
can be explored separately after backing up `com.system76.CosmicNotifications/v1`
if it exists. Supported anchors include `Top`, `Bottom`, `Left`, `Right` and the
four corner combinations. The daemon also follows panel/dock placement when it
finds the notification applet, so an anchor is not an unconditional positioning
override. Do not assume raising a maximum timeout overrides application timeouts.

For isolated visual styling, the cleanest future change is an upstream optional
notification-specific style/configuration in `cosmic-notifications`, retaining
current theme-derived defaults. An opt-in opaque neutral surface, contrasting
text and a subtle border could reuse native rendering without blur or another
daemon. This requires a versioned setting and testing of banners, hover, stacked
cards and dark/light themes; it is not a theme-only tweak. A private source patch
would carry release maintenance, so no patch or rebuild is included here.

Migrated from the old fork's `ed09a08` investigation; see [provenance](provenance.md).
This migration does not claim a fresh runtime investigation or broader version support.
For the independent project's proposed design, see [notification roadmap](../notifications/README.md).
