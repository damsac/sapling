set shell := ["bash", "-c"]

# List available recipes
default:
  @just --list

# ── Core ────────────────────────────────────────────────────────────────────

# Run all workspace tests
test *ARGS:
  cargo test --workspace {{ARGS}}

# Build all workspace crates
build *ARGS:
  cargo build --workspace {{ARGS}}

# Type-check without building
check:
  cargo check --workspace

# Lint with clippy
clippy *ARGS:
  cargo clippy --workspace {{ARGS}} -- -D warnings

# Check formatting
fmt:
  cargo fmt --all --check

# Format code (fix)
fmt-fix:
  cargo fmt --all

# ── Binding generation ──────────────────────────────────────────────────────
# UniFFI generates Kotlin/Swift wrappers from the compiled cdylib.
# We build for the host first, then run uniffi-bindgen against the output.

# Build the FFI cdylib for the host platform
build-host:
  cargo build -p sapling-ffi --release

# Generate Kotlin bindings from the host cdylib
gen-kotlin: build-host
  mkdir -p android/app/src/main/java/dev/damsac/sapling/rust
  LIB=$( \
    ls -1 \
      target/release/libsapling.dylib \
      target/release/libsapling.so \
      target/release/libsapling.dll \
    2>/dev/null | head -n 1 \
  ); \
  if [ -z "$LIB" ]; then \
    echo "error: no built cdylib found at target/release/libsapling.*"; \
    exit 1; \
  fi; \
  cargo run -q -p uniffi-bindgen -- generate \
    --library "$LIB" \
    --language kotlin \
    --out-dir android/app/src/main/java \
    --no-format \
    --config ffi/uniffi.toml

# Generate Swift bindings from the host cdylib
gen-swift: build-host
  mkdir -p ios/Bindings
  LIB=$( \
    ls -1 \
      target/release/libsapling.dylib \
      target/release/libsapling.so \
      target/release/libsapling.dll \
    2>/dev/null | head -n 1 \
  ); \
  if [ -z "$LIB" ]; then \
    echo "error: no built cdylib found at target/release/libsapling.*"; \
    exit 1; \
  fi; \
  cargo run -q -p uniffi-bindgen -- generate \
    --library "$LIB" \
    --language swift \
    --out-dir ios/Bindings \
    --config ffi/uniffi.toml

# ── Android ─────────────────────────────────────────────────────────────────

# Cross-compile Rust core for Android (arm64 + x86_64)
android-rust:
  mkdir -p android/app/src/main/jniLibs
  cargo ndk -o android/app/src/main/jniLibs \
    -t arm64-v8a -t x86_64 \
    build -p sapling-ffi --release

# Write android/local.properties (called by shell hook, but available standalone)
android-local-properties:
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"; \
  if [ -z "$SDK" ]; then \
    echo "error: ANDROID_HOME not set (run inside nix develop)"; \
    exit 1; \
  fi; \
  printf "sdk.dir=%s\n" "$SDK" > android/local.properties

# Build Android debug APK (requires gen-kotlin + android-rust first)
android-build: gen-kotlin android-rust android-local-properties
  cd android && ./gradlew :app:assembleDebug

# Full Android pipeline: generate bindings, cross-compile, build APK
android-apk: android-build
  @echo ""
  @echo "APK built at: android/app/build/outputs/apk/debug/app-debug.apk"

# Install debug APK on connected device/emulator
android-install: android-build
  cd android && ./gradlew :app:installDebug

# ── iOS (future — requires macOS + Xcode) ───────────────────────────────────

# Cross-compile Rust core for iOS device + simulator
ios-rust:
  @echo "iOS cross-compilation requires macOS + Xcode."
  @echo "Targets: aarch64-apple-ios, aarch64-apple-ios-sim, x86_64-apple-ios"
  @echo ""
  @echo "When on Mac hardware, run:"
  @echo "  cargo build -p sapling-ffi --release --target aarch64-apple-ios"
  @echo "  cargo build -p sapling-ffi --release --target aarch64-apple-ios-sim"
  @echo "  cargo build -p sapling-ffi --release --target x86_64-apple-ios"

# Build SaplingCore.xcframework (future — requires macOS + Xcode)
ios-xcframework: gen-swift ios-rust
  @echo "xcframework creation requires macOS + Xcode."
  @echo "Steps: lipo sim slices, xcodebuild -create-xcframework"

# ── CI / QA ─────────────────────────────────────────────────────────────────

# Pre-merge checks: fmt, clippy, tests
pre-merge: fmt clippy test
  @echo "pre-merge complete"
