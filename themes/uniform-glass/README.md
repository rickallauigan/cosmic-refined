# Uniform Glass integration

These theme files derive from **xarbit's Uniform Glass Dark**, originally published
in [xarbit/cosmic-uniform-glass-theme](https://github.com/xarbit/cosmic-uniform-glass-theme).
They are MPL-2.0 derived work; the upstream [LICENSE](LICENSE) accompanies them.
See [project provenance](../../docs/provenance.md) for the intervening prototype fork.

- `UniformGlassDark.ron`: upstream-derived palette with COSMIC 1.9 frosting schema; opt-in glass-focused theme.
- `UniformGlassDarkPerformance.ron`: preferred performance integration. Its name and four frosting enable flags differ from the glass variant. All frosting flags, including `frosted_maximized_apps`, are false.

The variant keeps the neutral dark palette, blue accent, transparency, spacing,
corner radii and window gaps. It does not add a process or improve notification
contrast. Keeping the reference alongside it enables direct comparison on upstream
updates. Neither file has been renamed to imply COSMIC Refined authored the palette.

## Import and remove

In COSMIC Settings → Appearance, note your current theme and export it if supported,
then select Import and choose `themes/uniform-glass/UniformGlassDarkPerformance.ron`
from this checkout. Importing a theme does not run the layout installer.

To undo, select your previous theme or reimport your saved theme in Appearance.
Delete imported custom theme entries through Settings if that option is available.
Deleting these source files alone does not revert desktop appearance.

The COSMIC 1.9 schema is audited against libcosmic commit
`03c8f93b294ad239ea935f6dd3c14a15acde8d0d`, pinned by cosmic-applets epoch-1.9.0.
`ThemeBuilder` uses `frosted: Medium` and individual frosting flags; legacy
`is_frosted` is no longer a model field. The glass variant enables windows,
system interface, panel and applets; both variants explicitly disable frosting
maximized apps. `Medium` is the default blur strength, not an enable switch.
With every enable flag false, the performance variant requests no frosted effects.
Palette, spacing, geometry and alpha values are unchanged; AlphaMap uses the
release model's serde default. This is a documented schema adaptation of MPL-2.0
upstream work, not a byte-identical reference copy.

Importing a builder through COSMIC Settings lets native theme generation write
current Theme entries. Adding a field to a source RON does not repair an already
installed config; the user's existing Dark/Light `frosted_maximized_apps=false`
fix remains untouched. No live theme import was performed here. Verify Settings
blur switches after import; rendering and power savings are not measured.
