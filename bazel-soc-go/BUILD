load("@rules_scala//scala:scala.bzl", "scala_binary")

package(default_visibility = ["//visibility:public"])

scala_binary(
    name = "ysyxsoc_gen",
    srcs = glob([
        "src/**/*.scala",
        "tools/**/*.scala",
        "rocket-chip/src/main/scala/**/*.scala",
        "rocket-chip/dependencies/cde/cde/src/**/*.scala",
        "rocket-chip/dependencies/diplomacy/diplomacy/src/**/*.scala",
        "rocket-chip/dependencies/hardfloat/hardfloat/src/main/scala/**/*.scala",
    ]),
    resources = glob([
        "rocket-chip/src/main/resources/**",
    ]),
    main_class = "ysyx.BazelElaborate",
    deps = [
        "@maven//:com_lihaoyi_geny_2_13",
        "@maven//:com_lihaoyi_mainargs_2_13",
        "@maven//:com_lihaoyi_os_lib_2_13",
        "@maven//:com_lihaoyi_sourcecode_2_13",
        "@maven//:org_chipsalliance_chisel_2_13",
        "@maven//:org_json4s_json4s_ast_2_13",
        "@maven//:org_json4s_json4s_core_2_13",
        "@maven//:org_json4s_json4s_jackson_core_2_13",
        "@maven//:org_json4s_json4s_jackson_2_13",
        "@maven//:org_scala_lang_scala_library",
        "@maven//:org_scala_lang_modules_scala_collection_compat_2_13",
    ],
    scalacopts = [
        "-Xplugin:$(location @maven//:org_chipsalliance_chisel_plugin_2_13_12)",
    ],
    plugins = [
        "@maven//:org_chipsalliance_chisel_plugin_2_13_12",
    ],
)

genrule(
    name = "ysyxsoc-verilog",
    srcs = [],
    tools = [":ysyxsoc_gen"],
    outs = ["ysyxSoCFull.v"],
    cmd = """
set -euo pipefail

TMPDIR="ysyxsoc_gen_tmp"
rm -rf "$$TMPDIR"
mkdir -p "$$TMPDIR"

$(location :ysyxsoc_gen) --target-dir "$$TMPDIR"
test -f "$$TMPDIR/ysyxSoCTop.sv"
cp "$$TMPDIR/ysyxSoCTop.sv" "$@"
sed -i -e 's/_\\(aw\\|ar\\|w\\|r\\|b\\)_\\(\\|bits_\\)/_\\1/g' "$@"
sed -i '/firrtl_black_box_resource_files.f/, $$d' "$@"
""",
)
