# Notification source fixtures

The two Rust fixtures are unmodified upstream `src/app.rs` and `src/main.rs` from
[pop-os/cosmic-notifications](https://github.com/pop-os/cosmic-notifications/tree/aa4dac2702506395ab76da1f6755e03b2ccb0db8),
commit `aa4dac2702506395ab76da1f6755e03b2ccb0db8`, package version 1.9.0.
Upstream authorship belongs to System76 and contributors (the package lists
Ashley Wulber). These are **GPL-3.0-only** sources, not MPL-2.0 theme code.
The [upstream license](../../notifications/patches/LICENSE-GPL-3.0.txt) is preserved.

SHA-256:

```text
52e03a9c6334e8603c48658e4d8076312358ab8f9c2649d1f5d0718b71c66819  cosmic-notifications-1.9.0-app.rs
25b8649ff9e3d6e69a5635ab6ed4332ca6179f60bb156b7c1f12a7891f11ed62  cosmic-notifications-1.9.0-main.rs
```

Fixtures let patch/reverse tests run offline without a sibling source repository,
network access, user configuration or a live daemon. They are not built or shipped
as a separate notification daemon. Preserve them when updating a patch's target.
