# system0

`system0` is a Nix-pinned integration repo for `CL3` and `ysyxSoC`.
It keeps the toolchain, submodule revisions, and build flow reproducible.

## Quick Start

```bash
git clone --recurse-submodules git@github.com:Luyoung0001/system0_temp.git
cd system0_temp
git submodule sync --recursive
git submodule update --init --recursive --checkout
nix develop
make build-soc-bin
make test-run-soc-all
```

## Repository Tree

```text
.
├── .gitmodules
├── .gitignore
├── flake.nix
├── flake.lock
├── Makefile
├── README.md
├── COLLABORATION.md
├── scripts/
├── tests/
├── CL3/
├── ysyxSoC/
├── bazel-go/
├── bazel-bin/
├── bazel-test/
├── bazel-soc-go/
├── bazel-soc-bin/
├── bazel-soc-test/
├── soc-integration/
├── out/
└── packages/
```

## Top-Level Paths

- `.gitmodules`: submodule definitions for `CL3/` and `ysyxSoC/`.
- `.gitignore`: ignore rules for local build outputs, caches, symlinks, and packages.
- `flake.nix`: Nix development shell definition. This is the main toolchain entry point.
- `flake.lock`: pinned Nix inputs for reproducible tool versions.
- `Makefile`: top-level entry point for all build, test, packaging, and dependency-check commands.
- `README.md`: this file.
- `COLLABORATION.md`: team workflow, branching, fork, and PR notes.

## Source Repositories

- `CL3/`: CL3 git submodule. Source of the CPU Chisel/Scala code and CL3-side C++ simulation code.
- `ysyxSoC/`: ysyxSoC git submodule. Source of the SoC Chisel/Scala code, peripherals, and `rocket-chip` submodule.
- `tests/`: shared test assets moved out of `CL3/sw/`.

## Utility Paths

- `scripts/`: helper scripts used by the top-level flow.
  Key file: `scripts/check_locked_deps.sh` checks that submodules match the SHA locked by `system0`.
- `soc-integration/`: generated integration staging area. It links CL3 Verilog, SoC Verilog, wrapper RTL, and peripheral RTL into one place.
- `out/`: local cache area for Bazel and Mill. Not source of truth.
- `packages/`: output directory for `make package`.

## Test Assets

- `tests/cpu-tests/`: CPU test programs.
- `tests/common/`: shared runtime code, linker scripts, and support code.
- `tests/utils/`: helper binaries and utilities used by the test flow.

## Bazel Workspaces

- `bazel-go/`: CL3 Chisel/Scala to SystemVerilog.
  Key files:
  `bazel-go/BUILD`: CL3 generator target.
  `bazel-go/MODULE.bazel`: Bazel module dependencies for the CL3 generator.
  `bazel-go/rules/`: custom Bazel rules for Verilog generation.

- `bazel-bin/`: CL3 SystemVerilog to Verilator executable.
  Key files:
  `bazel-bin/BUILD`: builds `top`.
  `bazel-bin/cc/`: symlink to CL3 C++ simulator sources.
  `bazel-bin/rtl/`: symlink to generated CL3 Verilog.
  `bazel-bin/soc/`: symlink to CL3 SoC wrapper files.

- `bazel-test/`: CL3-only cpu-tests build and run workspace.
  Key files:
  `bazel-test/BUILD`: defines test images and test targets.
  `bazel-test/rules/`: Bazel rules for CPU tests.
  `bazel-test/scripts/`: test image build and run scripts.

- `bazel-soc-go/`: ysyxSoC Chisel/Scala to SoC Verilog.
  Key files:
  `bazel-soc-go/BUILD`: builds `ysyxSoCFull.v`.
  `bazel-soc-go/MODULE.bazel`: Bazel module dependencies for SoC generation.
  `bazel-soc-go/tools/`: Scala entry point for Bazel-side SoC elaboration.

- `bazel-soc-bin/`: integrated SoC + CL3 Verilog to Verilator executable.
  Key files:
  `bazel-soc-bin/BUILD`: builds `soc_top`.
  `bazel-soc-bin/sim/`: SoC-side simulator support code.
  `bazel-soc-bin/soc-integration/`: symlink to the staged integration inputs.

- `bazel-soc-test/`: SoC+CL3 cpu-tests build and run workspace.
  Key files:
  `bazel-soc-test/BUILD`: defines SoC test images and test targets.
  `bazel-soc-test/rules/`: Bazel rules for SoC cpu-tests.
  `bazel-soc-test/scripts/`: SoC image build and run scripts.

## Build Flow

- `make build`: generate CL3 Verilog in `bazel-go/bazel-bin/cl3-verilog/`.
- `make build-bin`: build the CL3 Verilator binary in `bazel-bin/bazel-bin/top`.
- `make test-run-all`: run CL3-only cpu-tests.
- `make build-soc-bin`: build the integrated SoC binary in `bazel-soc-bin/bazel-bin/soc_top`.
- `make test-run-soc-all`: run SoC+CL3 cpu-tests.

## Notes

- Use `nix develop` before running `make`.
- `CL3/` and `ysyxSoC/` are locked by submodule SHA, not by branch name.
- Generated symlinks and build outputs inside `bazel-*`, `out/`, `soc-integration/`, and `packages/` are not source files.
