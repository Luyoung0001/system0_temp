"""Simplified Chisel RTL generation"""

load("@rules_scala//scala:scala.bzl", "scala_binary", "scala_library")
load("//rules:generate.bzl", "chisel_verilog")

def gen_rtl_target(name, main_class, srcs, deps = [], resources = [], app_opts = []):
    """Generate RTL from Chisel sources

    Args:
        name: Target name
        main_class: Scala main class
        srcs: Scala source files
        deps: Dependencies
        resources: Resource files
        app_opts: Application options
    """

    # Compile Chisel to executable
    scala_binary(
        name = name,
        srcs = srcs,
        resources = resources,
        main_class = main_class,
        deps = deps + [
            "@maven//:org_chipsalliance_chisel_2_13",
            "@maven//:org_scala_lang_scala_library",
        ],
        scalacopts = ["-Xplugin:$(location @maven//:org_chipsalliance_chisel_plugin_2_13_17)"],
        plugins = ["@maven//:org_chipsalliance_chisel_plugin_2_13_17"],
    )

    # Generate Verilog
    chisel_verilog(
        name = name + "-verilog",
        generator = ":" + name,
        app_opts = app_opts,
        firtool_opts = [
            "--disable-all-randomization",
            "--lowering-options=disallowLocalVariables",
        ],
        visibility = ["//visibility:public"],
    )
