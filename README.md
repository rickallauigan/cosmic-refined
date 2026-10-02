# COSMIC Refined

A refined, performance-conscious COSMIC desktop experience with macOS-inspired styling, presets, and usability improvements.

COSMIC Refined is an independent collection of optional visual and usability
improvements for COSMIC Desktop. It combines native desktop configuration with
careful theme integration, with accessibility and notification visibility as
first-class goals.

## Features and principles

- COSMIC-native configuration first, with optional features instead of invasive defaults.
- Minimal idle CPU/GPU overhead; no unnecessary services or animation daemons.
- No external compositor hacks, blur daemons or dock magnification services.
- Back up before changing configuration, support restore and easy removal.
- Preserve upstream compatibility and clearly attribute derived work.

## Performance philosophy

Polish should come from readable surfaces, useful spacing and predictable behavior.
Prefer static geometry and existing COSMIC processes. Avoid adding background work
without clear value. Performance savings are not benchmarked; compatibility work
is based on COSMIC 1.9.0 on Wayland, including Intel Iris Xe.

## Themes

[themes/uniform-glass/](themes/uniform-glass/README.md) hosts the Uniform Glass performance integration, derived
from xarbit's Uniform Glass Dark. Theme imports are independent of layout presets.
Other themes can be added without changing the project's identity.

## Presets

[presets/macos-performance/](presets/macos-performance/README.md) contains the optional compact top panel and floating,
rounded bottom dock preset. Its installer is explicitly invoked by the user and
backs up panel/dock configuration before changing managed keys.

## Notification roadmap

[notifications/](notifications/README.md) tracks a more visible macOS-inspired card design using the existing
COSMIC daemon where possible. COSMIC 1.9.0 uses shared theme/card colors; no isolated
notification theme control was identified. An [optional banner source patch](notifications/patches/README.md) implements local
high-visibility rendering, pending full compilation and live testing. Notification
center improvements remain a roadmap.

## Installation status

Early development: components are opt-in and installed separately. There is no
all-in-one installer, startup hook or automatic desktop configuration. Read each
component's instructions before applying it. No root access or new packages are
required. Removing this checkout does not undo previously imported settings; use
the component's restore/removal instructions first.

## Screenshots

Placeholder: screenshots of COSMIC Refined will be added after manual visual
verification. Old fork screenshots are not presented as results of this project.

## Upstream acknowledgements and license

Uniform Glass Dark originates from
[xarbit/cosmic-uniform-glass-theme](https://github.com/xarbit/cosmic-uniform-glass-theme).
COSMIC Desktop and its native components are developed by System76 and contributors.
Theme/preset work uses MPL-2.0; the existing [LICENSE](LICENSE) is preserved.
The optional daemon patch and upstream fixtures use GPL-3.0-only. See
[provenance](docs/provenance.md) for derived work and the prototype migration.

## Development status

Initial standalone integration. Fixture validation covers configuration safety;
live visual and accessibility verification, power measurements and notification
implementation remain future work. Development does not require changing the live
desktop. See [validation](docs/validation.md).
