fn main() {
    // Local bindgen binary so we don't need a global install.
    // Usage: cargo run -p uniffi-bindgen -- generate --library <lib> --language kotlin ...
    uniffi::uniffi_bindgen_main()
}
