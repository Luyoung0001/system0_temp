{
  description = "Chisel development environment with Bazel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              espresso = prev.espresso.overrideAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                  # glibc already declares random/srandom; old K&R-style redeclarations conflict.
                  substituteInPlace utility/port.h \
                    --replace-fail "extern VOID_HACK srandom();" "" \
                    --replace-fail "extern long random();" ""
                '';
              });
            })
          ];
        };

        firtool_1_105_0 = pkgs.stdenvNoCC.mkDerivation {
          pname = "firtool";
          version = "1.105.0";
          src = pkgs.fetchurl {
            url = "https://github.com/llvm/circt/releases/download/firtool-1.105.0/firrtl-bin-linux-x64.tar.gz";
            hash = "sha256-1zpJ6EE4Xw99Ktb8+JHIL4iZDj/gemi2tJBtBmF7X4Q=";
          };
          dontConfigure = true;
          dontBuild = true;
          sourceRoot = "firtool-1.105.0";
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
            chmod +x $out/bin/firtool
          '';
        };

        firtool_1_62_1 = pkgs.stdenvNoCC.mkDerivation {
          pname = "firtool";
          version = "1.62.1";
          src = pkgs.fetchurl {
            url = "https://github.com/llvm/circt/releases/download/firtool-1.62.1/firrtl-bin-linux-x64.tar.gz";
            hash = "sha256-w4gVhQ5javniWzHlGXCaUZ70r5cX3Rx7c+26wkDnI3A=";
          };
          dontConfigure = true;
          dontBuild = true;
          sourceRoot = "firtool-1.62.1";
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
            chmod +x $out/bin/firtool
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Bazel
            bazel_7

            # Java/Scala
            jdk21
            scala_3
            mill

            # Fixed firtool
            firtool_1_105_0
            firtool_1_62_1
            verilator

            # Build tools
            git
            gcc
            binutils
            util-linux
            zlib
            espresso

            # Pinned RISC-V cross toolchain for cpu-tests
            pkgsCross.riscv64-embedded.stdenv.cc
            pkgsCross.riscv64-embedded.buildPackages.binutils
          ];

          shellHook = ''
            echo "Chisel + Bazel development environment"
            echo "Bazel version: $(bazel --version)"
            echo "Scala version: $(scala -version 2>&1)"
            echo "Java version: $(java -version 2>&1 | head -n 1)"
            # Nix OpenJDK layout keeps jrt-fs.jar under lib/openjdk/lib.
            # Export JAVA_HOME to that exact root to satisfy rules_java local_jdk lookup.
            export JAVA_HOME="${pkgs.jdk21}/lib/openjdk"
            export BAZEL_JAVA_HOME="$JAVA_HOME"
            export CHISEL_FIRTOOL_PATH="$(dirname "$(command -v firtool)")"
            export CHISEL_FIRTOOL_PATH_SOC="${firtool_1_62_1}/bin"
            export MILL_BIN="$(command -v mill)"
            export RISCV_PREFIX="riscv64-none-elf-"
            export HEXDUMP_BIN="$(command -v hexdump)"
            export COURSIER_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/coursier"
            mkdir -p "$COURSIER_CACHE" 2>/dev/null || {
              export COURSIER_CACHE="/tmp/coursier-''${USER:-nix}"
              mkdir -p "$COURSIER_CACHE"
            }
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export LC_ALL=C
            export TZ=UTC
            echo "firtool available: $(command -v firtool)"
            echo "firtool version: $(firtool --version 2>&1 | head -n 1)"
            echo "soc firtool path: $CHISEL_FIRTOOL_PATH_SOC"
            echo "JAVA_HOME: $JAVA_HOME"
            echo "CHISEL_FIRTOOL_PATH: $CHISEL_FIRTOOL_PATH"
            echo "mill available: $MILL_BIN"
            echo "verilator available: $(command -v verilator)"
            echo "RISCV_PREFIX: $RISCV_PREFIX"
            echo "riscv gcc available: $(command -v ''${RISCV_PREFIX}gcc || echo MISSING)"
            echo "HEXDUMP_BIN: $HEXDUMP_BIN"
            echo "COURSIER_CACHE: $COURSIER_CACHE"
            echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
          '';
        };
      }
    );
}
