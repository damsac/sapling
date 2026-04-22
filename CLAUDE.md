# Sapling — Claude Instructions

## Design System

**Always reference `/sapling/brand/design-system.md` before making any UI or visual changes.**

Key rules at a glance:
- Color palette: Forest Green `#4a6741` (brand), Amber `#c4863a` (accent), Parchment `#f4f0e8` (bg), Stone `#ede9e0` (surface), Ink `#2d2a22` (text)
- Font: SF Pro Rounded globally (`.fontDesign(.rounded)`)
- Shapes: Capsule badges, `RoundedRectangle(cornerRadius: 12–14)` buttons, 40pt circle map buttons
- The map must remain fully accurate and topographic — no stylized overlays
- Use system materials (`.regularMaterial`, `.thinMaterial`) for floating panels
- Screen edge padding: 16pt; major section spacing: 20pt

## Architecture

- **Rust core** (`sapling-core`) → **UniFFI FFI layer** (`sapling-ffi`) → **Swift bindings** (auto-generated)
- Build xcframework: run `./build-ios.sh` from `/sapling/` before building the Xcode project
- SQLite migrations live in `core/src/store.rs` — always add new columns via `M::up("ALTER TABLE ...")` at the end of the migrations array, never modify existing migrations
- All store methods return `Result<_, SaplingError>`; FFI layer converts via `From<SaplingError> for FfiError`

## iOS Build

- Team ID: `98GXNZ6NKZ`
- Bundle ID: `dev.damsac.sapling`
- Device ID: `00008140-000D39221EBA801C`
- Build command (device install):
  ```
  xcodebuild -project ios/sapling.xcodeproj -scheme sapling \
    -destination 'id=00008140-000D39221EBA801C' \
    -configuration Debug \
    DEVELOPMENT_TEAM="98GXNZ6NKZ" \
    CODE_SIGN_IDENTITY="Apple Development" \
    -skipMacroValidation \
    install
  ```

## Product Roadmap

**Always read `/sapling/ROADMAP.md` before starting any new feature work.**

Key rules:
- Features should fit into one of the four phases — if something doesn't map to a phase, flag it before building
- The fuzzy-location seed sharing mechanic is a core differentiator — never build a feature that publishes exact GPS coordinates of community seeds
- When in doubt about what to build next, use the three-question priority filter at the bottom of ROADMAP.md
- Update the `✅ / 🔨` status markers in ROADMAP.md when a phase or feature ships

## Session Skills

Three slash commands are available in this project — use them to keep sessions coordinated across collaborators:

- `/start` — Run at the beginning of every session. Pulls latest, summarizes what was last worked on, flags conflicts, and gives a recommended next step grounded in the roadmap.
- `/stop` — Run before ending a session. Commits staged work, runs build checks, pushes, updates the open PR, and updates ROADMAP.md status markers if anything shipped.
- `/sense-check` — Run any time the session feels unfocused or a feature request seems off-track. Takes a holistic look at what's being built vs. what the roadmap actually needs.

## Code Style

- No comments unless the WHY is non-obvious
- No error handling for impossible cases
- No feature flags or backwards-compat shims
- SwiftUI: `@Observable` view models, `@State` in views
- Rust: keep FFI types thin — logic belongs in `sapling-core`, not `sapling-ffi`
