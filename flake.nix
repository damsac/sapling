{
  description = "Sapling — Rust core + Android/iOS cross-platform trail app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Rust toolchain overlay — lets us pin stable + cross-compilation targets
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Android SDK/NDK packaged for Nix
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, android-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };

        # Stable Rust with cross-compilation targets for Android and iOS.
        # iOS targets are included so the toolchain is ready when we have Mac hardware,
        # but cross-compiling to iOS requires macOS + Xcode (won't work on this Linux VPS).
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = [
            # Android
            "aarch64-linux-android"
            "armv7-linux-androideabi"
            "x86_64-linux-android"
            # iOS (ready for Mac hardware)
            "aarch64-apple-ios"
            "aarch64-apple-ios-sim"
            "x86_64-apple-ios"
          ];
        };

        # Android SDK components needed for building and testing.
        androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          platform-tools
          build-tools-35-0-0
          platforms-android-35
          ndk-28-2-13676358
        ]);
      in {
        devShells.default = pkgs.mkShell {
          # macOS-only build inputs
          buildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ];

          packages = [
            rustToolchain
            androidSdk
            pkgs.cargo-ndk       # Cross-compile Rust for Android via cargo ndk
            pkgs.just             # Task runner (justfile)
            pkgs.jdk17_headless   # Gradle needs JDK 17
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.xcodegen        # iOS project generation (Mac only)
          ];

          shellHook = ''
            # Android SDK paths — needed by cargo-ndk, Gradle, and the Android toolchain
            export ANDROID_HOME="${androidSdk}/share/android-sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
            export JAVA_HOME="${pkgs.jdk17_headless}"

            # Put Android platform tools on PATH
            export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

            # macOS: fix libiconv for Rust builds
            if [ "$(uname -s)" = "Darwin" ]; then
              if [ -n "''${LIBRARY_PATH:-}" ]; then
                export LIBRARY_PATH="${pkgs.libiconv}/lib:$LIBRARY_PATH"
              else
                export LIBRARY_PATH="${pkgs.libiconv}/lib"
              fi
            fi

            # Generate android/local.properties so Gradle can find the SDK
            mkdir -p android
            cat > android/local.properties <<LOCALPROPS
sdk.dir=$ANDROID_HOME
LOCALPROPS

            echo ""
            echo "Sapling dev environment ready"
            echo "  Rust:    $(rustc --version)"
            echo "  Android: $ANDROID_HOME"
            echo "  NDK:     $ANDROID_NDK_HOME"
            echo "  Java:    $JAVA_HOME"
            echo ""
          '';
        };
      }
    );
}
