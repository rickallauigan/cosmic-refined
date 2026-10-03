// SPDX-License-Identifier: MPL-2.0
// Link against the pinned COSMIC 1.9 cosmic-theme/ron build artifacts.
fn main() {
    for filename in std::env::args().skip(1) {
        let input = std::fs::read_to_string(&filename).expect("read theme");
        let builder: cosmic_theme::ThemeBuilder =
            ron::from_str(&input).expect("COSMIC 1.9 ThemeBuilder");
        assert!(!builder.frosted_maximized_apps);
        if filename.contains("Performance") {
            assert!(!builder.frosted_windows);
            assert!(!builder.frosted_system_interface);
            assert!(!builder.frosted_panel);
            assert!(!builder.frosted_applets);
        }
        let theme = builder.build();
        assert!(!theme.frosted_maximized_apps);
        if filename.contains("Performance") {
            assert!(
                !theme.frosted_windows
                    && !theme.frosted_system_interface
                    && !theme.frosted_panel
                    && !theme.frosted_applets
            );
        }
        println!("PASS: pinned schema deserialization and generated frosting flags: {filename}");
    }
}
