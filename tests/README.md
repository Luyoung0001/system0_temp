# tests

This directory is the standalone test asset source for `system0`.

- `cpu-tests/tests`: test case sources (`*.c`)
- `cpu-tests/include`: test headers
- `common`: runtime/startup/linker/common libs used by test builds
- `utils/riscv32-spike-so`: reference shared library for CL3-only difftest

`bazel-test/` and `bazel-soc-test/` do not own these files.  
Their `setup-*` targets only create symlinks pointing to this directory.

These assets are now maintained directly in this repository.
