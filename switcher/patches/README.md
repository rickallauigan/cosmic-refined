# Native window-mode patch

`cosmic-launcher-1.9.0-refined-switcher.patch` derives from System76's
GPL-3.0-only cosmic-launcher at `cc3d42bcc8fbcb67e6312f2766394e18b4d937d5`
(`epoch-1.9.0`). Distribution must preserve upstream licensing.

Only `src/app.rs` changes: an early Alt+Tab renderer, conditional centered
layer anchoring/padding, and disabling blur only for that mode. Launcher/search
rendering, input, subscriptions, activation and state transitions stay native.
The custom Arch package enables this window-mode presentation by default.
