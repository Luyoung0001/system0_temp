package(default_visibility = ["//visibility:public"])

filegroup(
    name = "sv_inputs",
    srcs = [
        "soc-integration/ysyxSoCFull.v",
        "soc-integration/ysyx_00000000.sv",
    ] + glob(["soc-integration/cl3-verilog/**/*.sv"]) + glob(["soc-integration/cl3-verilog/**/*.v"]) + glob(["soc-integration/perip/**/*.v"]),
)

filegroup(
    name = "cc_srcs",
    srcs = [
        "sim/dpi_mem.cpp",
        "sim/main.cpp",
    ],
)

filegroup(
    name = "cc_headers",
    srcs = ["sim/dpi_mem.h"],
)

genrule(
    name = "soc_top_bin",
    srcs = [
        ":sv_inputs",
        ":cc_srcs",
        ":cc_headers",
    ],
    outs = ["soc_top"],
    cmd = """
set -euo pipefail

TMPDIR="soc_top_build"
rm -rf "$$TMPDIR"
mkdir -p "$$TMPDIR"

SV_INPUTS="$(locations :sv_inputs)"
CC_SRCS="$(locations :cc_srcs)"
CXXFLAGS_EXTRA="$${NIX_CFLAGS_COMPILE:-} -std=c++17 -I.."
LDFLAGS_EXTRA=$$( (printf '%s\\n' "$${NIX_LDFLAGS:-}" | grep -oE -- '-L[^ ]+' | tr '\\n' ' ') || true )

verilator \
  $$SV_INPUTS \
  $$CC_SRCS \
  -Isoc-integration/perip/spi/rtl \
  -Isoc-integration/perip/uart16550/rtl \
  -Isoc-integration/cl3-verilog \
  -Isoc-integration/cl3-verilog/verification \
  --Wno-lint --Wno-UNOPTFLAT --Wno-BLKANDNBLK --Wno-COMBDLY --Wno-MODDUP \
  -CFLAGS "$$CXXFLAGS_EXTRA" \
  -LDFLAGS "$$LDFLAGS_EXTRA" \
  --timescale 1ns/1ps \
  --autoflush \
  --trace \
  --build -j 12 --exe --timing --cc \
  --Mdir "$$TMPDIR" \
  --top-module ysyxSoCTop \
  -o soc_top

cp "$$TMPDIR/soc_top" "$@"
""",
)
