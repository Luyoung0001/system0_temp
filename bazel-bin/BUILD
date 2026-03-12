package(default_visibility = ["//visibility:public"])

filegroup(
    name = "sv_inputs",
    srcs = glob(["rtl/**/*.sv"]) + [
        "rtl/filelist.f",
        "soc/top/SimTop.sv",
    ],
)

filegroup(
    name = "cc_srcs",
    srcs = [
        "cc/verilator/main.cpp",
        "cc/verilator/difftest.cpp",
        "cc/verilator/lightsss.cpp",
        "cc/perf.cpp",
    ],
)

filegroup(
    name = "cc_hdrs",
    srcs = glob(["cc/verilator/include/**/*.h"]),
)

genrule(
    name = "top_bin",
    srcs = [
        ":sv_inputs",
        ":cc_srcs",
        ":cc_hdrs",
    ],
    outs = ["top"],
    cmd = """
set -euo pipefail

TMPDIR="top_build"
rm -rf "$$TMPDIR"
mkdir -p "$$TMPDIR"

SV_MAIN=$$(awk '{print "rtl/" $$0}' rtl/filelist.f | tr '\\n' ' ')
SV_EXTRA="rtl/difftest_info_pkg.sv rtl/difftest_wrapper.sv rtl/difftest.sv"
if [ -f rtl/mem_helper.sv ]; then
  SV_EXTRA="$$SV_EXTRA rtl/mem_helper.sv"
fi
CC_SRCS="$(locations :cc_srcs)"
CXXFLAGS_EXTRA="$${NIX_CFLAGS_COMPILE:-} -I../cc/verilator/include -DUSE_VERILATOR"
LDFLAGS_EXTRA=$$( (printf '%s\\n' "$${NIX_LDFLAGS:-}" | grep -oE -- '-L[^ ]+' | tr '\\n' ' ') || true )

verilator \
  $$SV_MAIN \
  $$SV_EXTRA \
  soc/top/SimTop.sv \
  --Wno-lint --Wno-UNOPTFLAT --Wno-BLKANDNBLK --Wno-COMBDLY --Wno-MODDUP \
  $$CC_SRCS \
  -Irtl \
  -Irtl/verification \
  -Irtl/verification/assert \
  -Irtl/verification/assume \
  -Irtl/verification/cover \
  -CFLAGS "$$CXXFLAGS_EXTRA" \
  -LDFLAGS "$$LDFLAGS_EXTRA" \
  --timescale 1ns/1ps \
  --autoflush \
  --trace --trace-fst \
  --build -j 12 --exe --timing --cc \
  --Mdir "$$TMPDIR" \
  --top-module top \
  -o top

cp "$$TMPDIR/top" "$@"
""",
)
