load("//rules:cpu_tests.bzl", "define_cpu_tests")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "common_inputs",
    srcs = glob([
        "common/**/*.c",
        "common/**/*.S",
        "common/**/*.h",
        "common/linker.ld",
        "include/**/*.h",
    ]),
)

filegroup(
    name = "sim_top",
    srcs = ["sim/top"],
)

filegroup(
    name = "ref_so",
    srcs = ["utils/riscv32-spike-so"],
)

define_cpu_tests(glob(["tests/*.c"]))
