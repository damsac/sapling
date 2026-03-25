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
