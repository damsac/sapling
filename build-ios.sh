#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build-ios.sh [--release|--debug]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_MODE="${1:---release}"
case "$BUILD_MODE" in
  --release) PROFILE="release"; CARGO_RELEASE_FLAG="--release" ;;
  --debug)   PROFILE="debug";   CARGO_RELEASE_FLAG="" ;;
  *)         echo "Usage: $0 [--release|--debug]"; exit 1 ;;
esac

TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim)
FFI_CRATE="sapling-ffi"
LIB_NAME="libsapling.a"
FRAMEWORK_NAME="SaplingCore"
BINDINGS_DIR="$SCRIPT_DIR/ios/Bindings"
FRAMEWORK_DIR="$SCRIPT_DIR/ios/Frameworks"
STAGING_DIR="$SCRIPT_DIR/target/uniffi-xcframework-staging"

echo "=== Sapling iOS build ==="

# ----- Nix dev shell compatibility -----
# When running inside a Nix dev shell on macOS, several environment variables
# point to Nix-provided SDK paths that only contain macOS headers/libraries.
# These break iOS cross-compilation because:
#   - SDKROOT / DEVELOPER_DIR point to Nix's macOS-only SDK, not Xcode's
#   - NIX_CFLAGS_COMPILE injects -mmacosx-version-min, conflicting with iOS targets
#   - NIX_LDFLAGS links against macOS-only libraries (e.g. libiconv.dylib)
#   - LIBRARY_PATH adds Nix library paths that confuse the iOS linker
#
# The fix: detect Nix, unset the problematic vars, and point CC/linker
# to the system clang which knows how to cross-compile for iOS via Xcode.
if [ -n "${NIX_CC:-}" ] && [ "$(uname -s)" = "Darwin" ]; then
  echo "Nix dev shell detected — fixing env for iOS cross-compilation"

  # Nix provides its own xcrun/SDK that only knows macOS. Unset its SDK vars
  # so the cc-rs crate (used by libsqlite3-sys etc.) finds the real Xcode iOS SDK.
  unset SDKROOT
  unset DEVELOPER_DIR  # must unset BEFORE calling xcode-select (it reads this var)
  unset NIX_CFLAGS_COMPILE
  unset NIX_LDFLAGS
  unset LIBRARY_PATH
  unset NIX_CC
  unset NIX_CC_WRAPPER_TARGET_HOST_x86_64_apple_darwin
  unset NIX_CC_WRAPPER_TARGET_HOST_aarch64_apple_darwin

  # Point DEVELOPER_DIR to real Xcode so xcrun can find iphoneos SDK.
  # Must use /usr/bin/xcode-select (not Nix's) and call AFTER unsetting DEVELOPER_DIR.
  XCODE_DEV_DIR=$(/usr/bin/xcode-select -p 2>/dev/null || true)
  if [ -n "$XCODE_DEV_DIR" ] && [ -d "$XCODE_DEV_DIR" ]; then
    export DEVELOPER_DIR="$XCODE_DEV_DIR"
  else
    echo "error: Xcode not found. Install Xcode and run xcode-select --install."
    exit 1
  fi

  # Put /usr/bin first so the real xcrun is found instead of Nix's wrapper
  export PATH="/usr/bin:$PATH"

  # Use system clang for iOS cross-compilation (Nix clang can't target iOS)
  export CC="/usr/bin/clang"
  export CXX="/usr/bin/clang++"
  export AR="/usr/bin/ar"

  # Cargo linker config for iOS targets — must use system clang
  export CARGO_TARGET_AARCH64_APPLE_IOS_LINKER="/usr/bin/clang"
  export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_LINKER="/usr/bin/clang"
  export CARGO_TARGET_X86_64_APPLE_IOS_LINKER="/usr/bin/clang"
fi

# Step 1: Cross-compile for each iOS target
for target in "${TARGETS[@]}"; do
  echo "Building $FFI_CRATE for $target ($PROFILE)..."
  cargo build -p "$FFI_CRATE" --lib $CARGO_RELEASE_FLAG --target "$target"
done

# Step 2: Build host library for UniFFI binding generation (always release for metadata extraction)
echo "Building host library for UniFFI..."
cargo build -p "$FFI_CRATE" --release

# Step 3: Generate Swift bindings
echo "Generating Swift bindings..."
mkdir -p "$BINDINGS_DIR"

# Find host library (dylib on macOS, so on Linux)
HOST_LIB=""
for lib in target/release/libsapling.dylib target/release/libsapling.so; do
  if [ -f "$lib" ]; then
    HOST_LIB="$lib"
    break
  fi
done
if [ -z "$HOST_LIB" ]; then
  echo "error: no host cdylib found at target/release/libsapling.{dylib,so}"
  exit 1
fi

cargo run -q -p uniffi-bindgen -- generate \
  --library "$HOST_LIB" \
  --language swift \
  --out-dir "$BINDINGS_DIR" \
  --config ffi/uniffi.toml

# Step 4: Stage headers for XCFramework
echo "Staging headers..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
# The UniFFI-generated files are named based on the module: SaplingCoreFFI
cp "$BINDINGS_DIR/SaplingCoreFFI.h" "$STAGING_DIR/"
cp "$BINDINGS_DIR/SaplingCoreFFI.modulemap" "$STAGING_DIR/module.modulemap"

# Step 5: Create XCFramework
echo "Creating XCFramework..."
rm -rf "$FRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"
mkdir -p "$FRAMEWORK_DIR"

xcodebuild -create-xcframework \
  -library "target/aarch64-apple-ios/$PROFILE/$LIB_NAME" \
    -headers "$STAGING_DIR" \
  -library "target/aarch64-apple-ios-sim/$PROFILE/$LIB_NAME" \
    -headers "$STAGING_DIR" \
  -output "$FRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"

echo ""
echo "=== Done ==="
echo "XCFramework: $FRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"
echo "Bindings:    $BINDINGS_DIR/SaplingCore.swift"
