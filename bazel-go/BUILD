load("//rules:rules.bzl", "gen_rtl_target")

# Generate CL3 Verilog
gen_rtl_target(
    name = "cl3",
    main_class = "Elaborate",
    srcs = glob(["src/**/*.scala"]),
    resources = glob(["resources/vsrc/**"]),
    deps = [
        "@maven//:com_lihaoyi_os_lib_2_13",
        "@maven//:io_github_alexarchambault_data_class_2_13",
    ],
)
