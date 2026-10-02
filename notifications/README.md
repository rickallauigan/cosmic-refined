# Notification design and visibility roadmap

Status: an [experimental optional banner source patch](patches/README.md) is now
available for the pinned 1.9.0 daemon. It is not compiled or live-rendering verified;
there is no notification installer or session override. Keep the existing
lightweight `cosmic-notifications` daemon in your live session. The migrated
[1.9.0 investigation](../docs/notification-visibility.md) found shared theme/card
colors and no clean isolated notification theme control. Changing shared surfaces
would also affect unrelated UI.

See [architecture and exact source locations](../docs/notification-architecture.md).
Banner geometry, local colors and static timestamps are implemented in the source
prototype. Center readability remains a separately documented follow-up.

## Design direction

Aim for a macOS-inspired card layout with **higher visibility than macOS**, rather
than reproducing its subtle contrast. This is a design goal to validate with users,
not a measured comparison or a shipped appearance.

- Large rounded notification card with a readable, sufficiently opaque surface
  and a subtle contrasting border; no external blur daemon.
- Clear app icon and app identity, with fallback labels when an icon is absent.
- Strong title hierarchy and readable body text, with wrapping and scaling that
  remain usable at larger accessibility font sizes.
- Timestamp so users can distinguish new and older notifications; update it only
  when needed, avoiding a continuously ticking per-card timer.
- Optional urgency accent alongside a text/icon cue, so color is never the only
  indication of importance. Normal notifications should remain easy to notice.
- Lightweight native rendering: static geometry, no perpetual animation, glow,
  magnification or polling service.

Respect dark/light themes, keyboard dismissal, screen scaling and reduced-motion
preferences. Check contrast over varied wallpapers and ensure stacked cards do not
hide essential content. Accessibility matters more than mimicking exact macOS sizes.

## Implementation direction

Prefer an upstream optional notification-specific style/configuration in the
existing COSMIC daemon, retaining current defaults for users who do not opt in.
Reuse COSMIC widgets and rendering where possible, without modifying the compositor
or introducing another background process. The timestamp, hierarchy and urgency
ideas require capability review and must not be described as current native settings.

Before implementation, confirm a small maintainable API, versioned configuration,
backup/removal behavior, and dark/light/hover/stacked-card coverage. Avoid a private
fork requiring repeated daemon rebuilds merely to change colors. If upstream does
not yet support isolation, continue documenting that limitation rather than silently
changing shared theme surfaces.

## Available today

Use COSMIC Settings to check notification permissions and Do Not Disturb, and keep
the native tray visible to review missed banners. The layout preset preserves its
applets. Placement and timeout options are discussed in the investigation, with
limitations; no notification configuration is automatically applied here.

Future work includes full integration compilation, native configuration/localization,
center rendering, manual usability verification and rendering/power measurements. No notification
visibility improvement is claimed by the migrated performance theme itself.
