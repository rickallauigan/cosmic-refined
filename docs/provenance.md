# Project provenance and scope

COSMIC Refined is an independent project with its own repository, history and
roadmap. Uniform Glass is one theme integration within a broader collection of
COSMIC-native usability improvements, rather than the identity of the entire project.

## Upstream and prototype

The original theme is from
[xarbit/cosmic-uniform-glass-theme](https://github.com/xarbit/cosmic-uniform-glass-theme),
licensed under MPL-2.0. The theme creator's attribution is retained as xarbit;
COSMIC itself is developed by System76 and contributors.

Prototype work was completed in
[rickallauigan/cosmic-uniform-glass-theme](https://github.com/rickallauigan/cosmic-uniform-glass-theme)
on `feat/macos-productivity-polish`:

- `5ef9f9b`: performance variant (name change and `is_frosted: false`).
- `8e997b3`: native macOS-inspired geometry preset and fixture tests.
- `ed09a08`: notification visibility investigation and limitations.

Content was intentionally copied and adapted into this existing repository.
No commits were cherry-picked and no source history was imported. The old fork
remains the prototype record; it is not a runtime, test or installation dependency.

## Derived and original work

- Both Uniform Glass RON files derive from xarbit's MPL-2.0 theme. The original
  is retained as a comparison/reference; the performance variant retains its palette,
  transparency and geometry. Palette and geometry are preserved from the prototype; frosting fields have
  been adapted to the pinned COSMIC 1.9 schema, including maximized frosting disabled.
- The preset, installer, fixture tests and notification investigation originate
  in the old fork's added prototype work, not in the original theme upstream.
  COSMIC Refined adapts paths, backup naming, documentation and validation.
- COSMIC Refined's independent project overview, integration documentation,
  validation entry point and future notification design direction are new here.
- Old screenshots, Zed/Vivaldi integrations and unrelated fork content are excluded.

Theme, preset and project documentation additions are distributed under MPL-2.0.
The optional cosmic-notifications patch, its added Rust module and upstream test
fixtures are GPL-3.0-only, matching the daemon; see
[patch licensing](../notifications/patches/README.md).
The root license is retained unchanged, and a copy accompanies the theme files.
Attribution does not imply endorsement by xarbit or System76. Future integrations
must retain their own upstream notices and identify their provenance.

Separating optional themes, presets and notification research makes upstream theme
updates easy to compare while allowing usability work to evolve independently.

The experimental notification center patch and applet fixtures derive from
[pop-os/cosmic-applets epoch-1.9.0](https://github.com/pop-os/cosmic-applets/tree/82e7cd814addb0641959b634227fe550374e195b),
Copyright System76 and contributors, GPL-3.0-only. The retained Arch upstream
recipe credits its maintainers/contributors verbatim; local packaging/helper files
use MPL-2.0 and package GPL-3.0-only upstream software. The center patch is separate
from the working notification-daemon patch and does not modify libcosmic.
