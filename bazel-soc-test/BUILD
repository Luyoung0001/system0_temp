load("//rules:cpu_tests_soc.bzl", "define_soc_cpu_tests")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "common_inputs",
    srcs = glob([
        "common/**/*.c",
        "common/**/*.S",
        "common/**/*.h",
        "common/linker.ld",
        "common/soc_bootloader.ld",
        "include/**/*.h",
    ]),
)

filegroup(
    name = "sim_top",
    srcs = ["sim/top"],
)

define_soc_cpu_tests(glob(["tests/*.c"]))
