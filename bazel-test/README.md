# bazel-test

`bazel-test` is the third stage in the split flow:

1. Build cpu-test images (`.elf/.bin/.hex/.mem/.txt`) with Bazel.
2. Run tests against `bazel-bin/top` + `riscv32-spike-so`.

## Inputs

- `tests/` -> symlink to `../tests/cpu-tests/tests`
- `include/` -> symlink to `../tests/cpu-tests/include`
- `common/` -> symlink to `../tests/common`
- `utils/` -> symlink to `../tests/utils`
- `sim/top` -> symlink to `../../bazel-bin/bazel-bin/top`

## Outputs

- `bazel-test/bazel-bin/<test>.elf|bin|hex|mem|txt`

## Build all images

```bash
make build-test
```

## Run one representative test

```bash
make test-run-add
```

For all runtime tests, extend `cpu_tests.bzl`/Makefile targets as needed.
