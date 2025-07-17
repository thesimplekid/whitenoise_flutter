{
  description = "WhiteNoise Flutter development environment with Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        
        # Define the Rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = [
            "x86_64-unknown-linux-gnu"
            "aarch64-unknown-linux-gnu"
            "x86_64-apple-darwin"
            "aarch64-apple-darwin"
            "x86_64-pc-windows-gnu"
            "aarch64-linux-android"
            "armv7-linux-androideabi"
            "i686-linux-android"
            "x86_64-linux-android"
          ];
        };

        buildInputs = with pkgs; [
          # Rust toolchain
          rustToolchain
          rustup  # Required for cargokit
          
          # Flutter and Dart
          flutter

          # flutter_rust_bridge_codegen
          
          # Java - required for Android builds
          jdk17
          
          # Build tools
          cmake
          ninja
          pkg-config
          
          # Libraries
          openssl
          sqlite
          zlib
          
          # Development tools
          git
          just  # for justfile support
          
          # Platform-specific dependencies for Flutter desktop
          gtk3
          glib
          cairo
          pango
          gdk-pixbuf
          atk
          at-spi2-atk
          libepoxy
          xorg.libX11
          libxkbcommon
          wayland
          sysprof
          libsysprof-capture
          
          # Audio libraries (for whitenoise audio processing)
          alsa-lib
          pulseaudio
          
          # Security libraries (for flutter_secure_storage)
          libsecret
          
          # Additional useful tools
          curl
          wget
          unzip
          gnumake
        ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          # Linux-specific packages
          clang
          llvm
          libclang
          binutils
        ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
          # macOS-specific packages
          pkgs.darwin.apple_sdk.frameworks.Security
          pkgs.darwin.apple_sdk.frameworks.CoreServices
          pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          libiconv
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          
          # Environment variables
          shellHook = ''
            # Rust environment
            export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"
            export CARGO_HOME="$PWD/.cargo"
            export RUSTUP_HOME="$PWD/.rustup"
            
            # Flutter environment
            export FLUTTER_ROOT="${pkgs.flutter}"
            export DART_ROOT="${pkgs.flutter}/bin/cache/dart-sdk"
            export PATH="$FLUTTER_ROOT/bin:$DART_ROOT/bin:$PATH"
            
            # Java environment for Android builds
            export JAVA_HOME="${pkgs.jdk17}"
            export PATH="$JAVA_HOME/bin:$PATH"
            
            # Android SDK with NDK (from user's home directory)
            mkdir -p "$HOME/Android/Sdk"
            export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/29.0.13599879"
            
            # Override and prioritize our Android SDK paths
            export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/build-tools/34.0.0:$PATH"
            
            # Remove any Nix Android SDK paths from environment variables
            unset ANDROID_EMULATOR_USE_SYSTEM_LIBS
            
            # Accept all Android licenses automatically
            mkdir -p "$ANDROID_SDK_ROOT/licenses"
            echo "8933bad161af4178b1185d1a37fbf41ea5269c55" > "$ANDROID_SDK_ROOT/licenses/android-sdk-license"
            echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> "$ANDROID_SDK_ROOT/licenses/android-sdk-license"  
            echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" >> "$ANDROID_SDK_ROOT/licenses/android-sdk-license"
            echo "79120722343a6f314e0719f863036c702b0e6b2a" > "$ANDROID_SDK_ROOT/licenses/android-sdk-preview-license"
            echo "84831b9409646a918e30573bab4c9c91346d8abd" > "$ANDROID_SDK_ROOT/licenses/android-googletv-license"
            echo "33b6a2b64607f11b759f320ef9dff4ae5c47d97a" > "$ANDROID_SDK_ROOT/licenses/google-gdk-license"
            echo "d975f751698a77b662f1254ddbeed3901e976f5a" > "$ANDROID_SDK_ROOT/licenses/intel-android-extra-license"
            echo "e9acab5b5fbb560a72cfaecce8946896ff6aab9d" > "$ANDROID_SDK_ROOT/licenses/mips-android-sysimage-license"
            
            # Fix local.properties to use our Android SDK  
            if [ -f "android/local.properties" ]; then
              sed -i "s|sdk.dir=.*|sdk.dir=$ANDROID_SDK_ROOT|g" android/local.properties
            else
              echo "sdk.dir=$ANDROID_SDK_ROOT" > android/local.properties
            fi
            
            # Clean gradle cache of any Nix Android SDK references
            if [ -d "$HOME/.gradle" ]; then
              find "$HOME/.gradle" -name "*.properties" -exec grep -l "/nix/store.*android" {} \; | xargs -r rm -f
            fi
            
            # Ensure gradle uses our Android SDK
            export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            
            # Force gradle to not use system properties for Android SDK
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/34.0.0/aapt2"
            
            # Build environment
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPath "lib/pkgconfig" buildInputs}"
            export OPENSSL_DIR="${pkgs.openssl.dev}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            
            # Flutter Rust Bridge
            export FRB_LOG_LEVEL="info"
            
            # Override Flutter config to use local Android SDK
            export FLUTTER_GRADLE_PLUGIN_BUILDDIR="$PWD/build"
            flutter config --android-sdk "$ANDROID_SDK_ROOT" 2>/dev/null || true
            
            # Create a wrapper script for Flutter that ensures local Android SDK is used
            mkdir -p "$PWD/.bin"
            cat > "$PWD/.bin/flutter" << 'EOF'
#!/bin/bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
exec ${pkgs.flutter}/bin/flutter "$@"
EOF
            chmod +x "$PWD/.bin/flutter"
            export PATH="$PWD/.bin:$PATH"
            
            # Also create gradle wrapper to ensure local Android SDK
            cat > "$PWD/.bin/gradle" << 'EOF'
#!/bin/bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
unset ANDROID_EMULATOR_USE_SYSTEM_LIBS
exec gradle "$@"
EOF
            chmod +x "$PWD/.bin/gradle"
            
            echo "🦀 Rust toolchain: $(rustc --version)"
            echo "🎯 Dart SDK: $(dart --version 2>&1 | head -1)"
            echo "📱 Flutter: $(flutter --version | head -1)"
            echo "☕ Java: $(java -version 2>&1 | head -1)"
            echo ""
            echo "📱 Android SDK: $ANDROID_SDK_ROOT"
            echo "📱 Android NDK: $ANDROID_NDK_ROOT"
            echo "Available Rust targets:"
            echo "  • Linux: x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu"
            echo "  • macOS: x86_64-apple-darwin, aarch64-apple-darwin"
            echo "  • Android: aarch64-linux-android, armv7-linux-androideabi"
            echo "  • Windows: x86_64-pc-windows-gnu"
            echo ""
            if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools" ]; then
              echo "⚠️  Android SDK not fully installed. You may need to install it manually or use Android Studio."
              echo "   Run: flutter doctor --android-licenses"
            fi
            echo ""
            echo "🛠️  Development environment ready!"
            echo "💡 Use 'just --list' to see available commands"
          '';
          
          # Additional environment variables
          RUST_BACKTRACE = "1";
          RUST_LOG = "debug";
          
          # Library path for dynamic linking
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
          
          # Ensure we have the right C compiler
          CC = "${pkgs.clang}/bin/clang";
          CXX = "${pkgs.clang}/bin/clang++";
        };

        # FHS environment for Android development
        devShells.fhs = (pkgs.buildFHSEnv {
          name = "whitenoise-fhs";
          targetPkgs = pkgs: buildInputs ++ (with pkgs; [
            # FHS-compatible libraries needed for Android NDK
            zlib
            ncurses5
            stdenv.cc.cc
            stdenv.cc.cc.lib
          libsecret
          ]);
          runScript = pkgs.writeScript "init" ''
            export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"
            export CARGO_HOME="$PWD/.cargo"
            export RUSTUP_HOME="$PWD/.rustup"
            
            # Flutter environment
            export FLUTTER_ROOT="${pkgs.flutter}"
            export DART_ROOT="${pkgs.flutter}/bin/cache/dart-sdk"
            export PATH="$FLUTTER_ROOT/bin:$DART_ROOT/bin:$PATH"
            
            # Java environment for Android builds
            export JAVA_HOME="${pkgs.jdk17}"
            export PATH="$JAVA_HOME/bin:$PATH"
            
            # Android SDK (if available in user's home)
            if [ -d "$HOME/Android/Sdk" ]; then
              export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
              export ANDROID_HOME="$HOME/Android/Sdk"
              export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
            fi
            
            # Build environment
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPath "lib/pkgconfig" buildInputs}"
            export OPENSSL_DIR="${pkgs.openssl.dev}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            
            # Flutter Rust Bridge
            export FRB_LOG_LEVEL="info"
            
            # Additional environment variables
            export RUST_BACKTRACE="1"
            export RUST_LOG="debug"
            
            echo "🚀 FHS Environment for Android Development"
            echo "🦀 Rust toolchain: $(rustc --version)"
            echo "🎯 Dart SDK: $(dart --version 2>&1 | head -1)"
            echo "📱 Flutter: $(flutter --version | head -1)"
            echo "☕ Java: $(java -version 2>&1 | head -1)"
            echo ""
            echo "📱 Android SDK: $ANDROID_SDK_ROOT"
            echo ""
            echo "🛠️  FHS Development environment ready!"
            echo "💡 Use 'just --list' to see available commands"
            exec bash
          '';
        }).env;
        
        # Formatter for the flake
        formatter = pkgs.nixpkgs-fmt;
        
        # Development packages that can be installed
        packages = {
          rust-toolchain = rustToolchain;
        };
      });
}

