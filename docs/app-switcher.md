# App/window switcher milestone — architecture investigation

Vicinae remains responsible for launcher/search. No switcher code is installed,
no keyboard binding or launcher setting is changed by this investigation.

The COSMIC 1.9 settings-daemon dependency pinned by applets, commit
ac6190062c67dd687c2c1ea66e6cbea4dc9261b9, declares WindowSwitcher and
WindowSwitcherPrevious in config/src/shortcuts/action.rs. Its
`data/system_actions.ron` maps them to `cosmic-launcher alt-tab` and
`cosmic-launcher shift-alt-tab`. The existing native switcher thus shares an
executable with COSMIC's launcher, but these are distinct window-switching modes.
This finding does not justify altering search/launcher behavior or Vicinae.

Smallest candidate: retain native shortcuts, window enumeration and activation,
and investigate only the native alt-tab renderer's geometry/selection affordances.
Before implementation, pin the installed switcher package/source and inspect its
window-only module and event subscriptions. Prefer supported settings; if absent,
a narrowly isolated window-mode patch needs its own package/rollback and must leave
launcher/search modes untouched. Do not create a second switcher daemon, replace
Vicinae, patch the compositor or use polling to enumerate windows.

Performance goal: no added idle process or wakeups; draw a compact opaque switcher
only while invoked, use app icons before considering expensive live thumbnails,
and avoid blur/animation loops. These are design constraints, not measured results.
Rollback must independently restore the stock owning package (or backed-up native
settings) without undoing notification packages. No experimental live installation
occurs before publication/CI review and notification interaction sanity checks.
