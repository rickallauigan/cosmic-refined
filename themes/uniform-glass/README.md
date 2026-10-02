# Uniform Glass integration

These theme files derive from **xarbit's Uniform Glass Dark**, originally published
in [xarbit/cosmic-uniform-glass-theme](https://github.com/xarbit/cosmic-uniform-glass-theme).
They are MPL-2.0 derived work; the upstream [LICENSE](LICENSE) accompanies them.
See [project provenance](../../docs/provenance.md) for the intervening prototype fork.

- `UniformGlassDark.ron`: unchanged original reference, opt-in glass-focused theme.
- `UniformGlassDarkPerformance.ron`: preferred performance integration. Only its
  name and `is_frosted: false` differ from the original.

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

The files retain the prototype's legacy `is_frosted` import field. COSMIC's newer
v2 exports contain separate frosted flags; verify the Appearance blur switches
following import. No live import or rendering validation has been performed by
this migration. Translucency still depends on what appears behind the surface;
readability and power savings are not guaranteed by disabling frosted blur.
