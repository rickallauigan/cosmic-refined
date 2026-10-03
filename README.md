# COSMIC Refined

A refined, performance-conscious COSMIC desktop experience with macOS-inspired styling, presets, and usability improvements.

COSMIC Refined is an independent collection of optional visual and usability
improvements for COSMIC Desktop. It focuses on notification visibility,
COSMIC-native visual refinements, panel/dock presets, app/window switching,
performance-conscious behavior and release polish. Accessibility remains a
first-class goal.

## Features and principles

- COSMIC-native configuration first, with optional features instead of invasive defaults.
- Minimal idle CPU/GPU overhead; no unnecessary services or animation daemons.
- No external compositor hacks, blur daemons or dock magnification services.
- Back up before changing configuration, support restore and easy removal.
- Preserve upstream compatibility and clearly attribute derived work.

## Launcher scope and coexistence

Launcher/search workflows are delegated to Vicinae, the user's chosen primary
launcher. Vicinae is intentionally outside COSMIC Refined's launcher scope;
COSMIC Refined should coexist with it. COSMIC launcher polish, redesign, search UI,
theming, integration and replacement work are excluded from this project's roadmap.

COSMIC Refined focuses on desktop visuals, notifications, panel/dock layout,
app switching, performance and usability. It does not add Vicinae as a dependency,
modify its configuration, or provide launcher hooks, plugins or wrappers.

App-switcher improvements remain a separate scope: window switching UX,
app/window preview styling and keyboard switching ergonomics. They must use
COSMIC-native facilities where practical and work independently of Vicinae,
without taking over launcher/search workflows. An experimental window-mode
source patch is available; compilation and live validation remain gated.

## Project roadmap

Priority order: **notifications (merged) → app switcher (current) → performance benchmark → polish/release**.

1. **Notifications:** merged and visually validated; preserve native integration
   and accessibility while tracking further interaction checks.
2. **App switcher:** validate the native window-mode refinement and keyboard
   ergonomics independently of launcher/search tools, without live thumbnails.
3. **Performance benchmark:** add opt-in measurements for idle CPU/GPU usage and
   visible rendering costs, without a persistent monitoring service.
4. **Polish/release:** refine theme and optional panel/dock variants, verify
   accessibility, and add screenshots, documentation and release structure.

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
rounded bottom dock preset. Its small `install.sh` apply/restore utility is explicitly
invoked by the user and backs up panel/dock configuration before changing managed
keys. Backup, restore, rollback, validation and idempotence remain feature-level
safety mechanisms. A standalone installer application, GUI or wizard is outside
project scope.

## Notification roadmap

[notifications/](notifications/README.md) tracks a more visible macOS-inspired card design using the existing
COSMIC daemon where possible. COSMIC 1.9.0 uses shared theme/card colors; no isolated
notification theme control was identified. An [optional banner source patch](notifications/patches/README.md) implements local
high-visibility rendering, with [full compilation verified](docs/notification-build-validation.md)
and popup visuals live verified by the ThinkPad user. An [Arch package test workflow](docs/notification-package-test.md)
keeps normal session supervision and enables cards only in the explicitly installed
custom package. A separate [experimental notification center patch and package](docs/notification-center.md) preserves grouping and native history behavior; the custom center package is installed and its applet runs, as reported by the user. Center visual review passed on COSMIC 1.9; additional live interaction checks remain separate. See [session conflict handling](docs/notification-session-conflicts.md).

## Component usage

Early development: components are opt-in and applied separately through their own
instructions and utilities. No project helper is added to startup; installed
packages use existing COSMIC launch mechanisms. Read each
component's instructions before applying it. Themes and panel/dock presets need no
root access or new packages. The optional Arch notification test builds a local
package and requires a separately confirmed privileged pacman transaction. Removing
this checkout does not undo previously imported settings or installed packages; use
the component's restore/removal instructions first.

## Screenshots

Placeholder: screenshots of COSMIC Refined will be added after manual visual
verification. Old fork screenshots are not presented as results of this project.

## Upstream acknowledgements and license

Uniform Glass Dark originates from
[xarbit/cosmic-uniform-glass-theme](https://github.com/xarbit/cosmic-uniform-glass-theme).
COSMIC Desktop and its native components are developed by System76 and contributors.
Theme/preset work uses MPL-2.0; the existing [LICENSE](LICENSE) is preserved.
The optional daemon/applet patches and upstream fixtures use GPL-3.0-only. See
[provenance](docs/provenance.md) for derived work and the prototype migration.

## Development status

Initial standalone integration. Fixture validation covers configuration safety;
live visual and accessibility verification and power measurements remain future work.
Development does not require changing the live desktop. See [validation](docs/validation.md).

The [native app/window switcher milestone](docs/app-switcher.md) now has an
experimental rendering-only source patch, pinned Arch package recipe and CI.
It preserves native window activation and reverse switching; Vicinae continues
to own launcher/search. Compilation and live validation are still required
before installation. No additional service or timer is introduced.
