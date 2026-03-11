# bazel-bin

`bazel-bin` is the second stage in the split flow:

1. `bazel-go` generates stable SystemVerilog into `bazel-go/bazel-bin/cl3-verilog`.
2. `bazel-bin` compiles that RTL + CL3 Verilator C++ testbench into a simulator executable.

## Inputs

- `rtl/` -> symlink to `../bazel-go/bazel-bin/cl3-verilog`
- `soc/` -> symlink to `../CL3/soc`
- `cc/` -> symlink to `../CL3/cl3/src/cc`

## Output

- `bazel-bin/top` (built by target `//:top_bin`)

## Build

From repo root:

```bash
make build-bin
```
