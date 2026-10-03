# High-visibility notification architecture

Research target: installed `cosmic-notifications` and `cosmic-applets`
`1:1.9.0-1` (Arch packages), COSMIC 1.9.0 on Wayland. Inspection was read-only.
The local theme has shared v2 container colors and a 2px `radius_xs`. No local
`com.system76.CosmicNotifications/v1` overrides were found. No configuration
mutation or daemon restart was performed.

## Source map

Release tag `epoch-1.9.0` resolves to notification daemon commit
`aa4dac2702506395ab76da1f6755e03b2ccb0db8`. The fetched upstream `master/src/app.rs`
was byte-identical to that release during this investigation; no newer control was
found in that file. This is not a promise about future upstream changes or proof
that the distribution binary has no downstream patches.

| Location | Responsibility / current behavior |
| --- | --- |
| `cosmic-notifications/src/app.rs:push_notification` (lines 270–562 in pinned source) | Layer surface and popup limits use 300px width. Banner header uses 16px icon; summary uses body style; markup body uses 12px. `cards` wraps content in shared styles. |
| Same file, `Application::init` (line 702) | Enables automatic popup/window blur and sets system app type. |
| Same file, `Message::PopupSize` (line 833) | Sends shared `radius_xs` as Wayland surface corners; must match drawn card radius. |
| `cosmic-notifications-config/src/lib.rs:NotificationsConfig` | v1 placement, limits and timeouts only; no visual overrides. |
| `cosmic-notifications-util/src/lib.rs:Notification` | Existing `time: SystemTime`, urgency hints, and icon selection; no new timestamp storage needed. |
| libcosmic `src/widget/cards.rs` | Front card uses `theme::iced::Button::Card`; shared stacking widget contains expansion animation machinery. |
| libcosmic `src/theme/style/iced.rs:Button::cosmic` | Card uses current shared container component colors and `radius_xs`. |
| `cosmic-applets/cosmic-applet-notifications/src/lib.rs:view_window` (lines 383–537) | Separate center/history renderer: 16px icon, 12px body, grouped `cards`, scrollable list with 8px gaps. |
| Same applet, `duration_ago_msg` (line 549) | Already shows localized relative timestamps on view rendering; no new clock service needed. |

Sources: [daemon](https://github.com/pop-os/cosmic-notifications/blob/aa4dac2702506395ab76da1f6755e03b2ccb0db8/src/app.rs),
[schema](https://github.com/pop-os/cosmic-notifications/blob/aa4dac2702506395ab76da1f6755e03b2ccb0db8/cosmic-notifications-config/src/lib.rs),
[notification model](https://github.com/pop-os/cosmic-notifications/blob/aa4dac2702506395ab76da1f6755e03b2ccb0db8/cosmic-notifications-util/src/lib.rs),
[center](https://github.com/pop-os/cosmic-applets/blob/epoch-1.9.0/cosmic-applet-notifications/src/lib.rs),
and [shared cards](https://github.com/pop-os/libcosmic/blob/d921602cde8248c070b493ce43b0edd388e19b9a/src/widget/cards.rs).

## Options and decision

1. Shared theme changes: small configuration edits, but affect unrelated UI and
   cannot isolate all banner properties. Rejected for this feature.
2. Upstream native style/schema option: best long-term maintenance; requires a
   daemon change and a separate applet change for the center. No such option was
   identified in the inspected 1.9.0 code.
3. Small opt-in daemon patch: selected experimental approach. Keep the stock path
   by default; add notification-local geometry, opaque colors and rendering.
   No compositor/libcosmic/theme patch, replacement daemon or new runtime crate.
4. Replacement daemon: conflicts with the goal of retaining native integration;
   unnecessary for banner styling.

Use a startup-only environment opt-in for the prototype rather than adding keys
that stock COSMIC Settings does not understand. A future upstream submission should
replace this with a versioned notification-specific configuration and localization.
The patch is an experimental source artifact, not a system installer. It requires
a pinned custom build and per-release revalidation; it must not silently override
a distribution package. Compilation and live Wayland tests are separate milestones.

## Center scope

Changing the daemon will not change the center. A small second applet patch could
increase icons/body sizes and spacing while preserving existing relative timestamps,
grouping, clear-all and actions. Truly isolated surfaces/18px corners require either
per-card local button styles or a notification-local grouped renderer; changing the
shared `cards` widget globally is inappropriate. Keep this as a separate follow-up
with expanded/collapsed groups, DND, history, keyboard and dark/light testing.

## Current center implementation

The original source table above describes stock release rendering. A separate
GPL-3.0-only center patch now replaces only its cards rendering call with an
applet-local renderer. Grouping state, messages, subscriptions and localized
relative-time function remain unchanged. The custom full applets package is
installed on the ThinkPad and its cached payload matches the live binary checksum.
The center has passed offline locked checking; visual/interaction review remains
pending. See notification-center.md and notification-session-conflicts.md. No
global card styles, session PATH, Vicinae or working banner code are changed.
