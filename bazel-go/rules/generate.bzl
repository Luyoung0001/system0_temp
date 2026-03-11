"""Chisel Verilog generation rules"""

def _chisel_verilog_impl(ctx):
    """Generate Verilog from Chisel"""
    output = ctx.actions.declare_directory(ctx.attr.name)

    args = ctx.actions.args()

    # Application options
    args.add_all(ctx.attr.app_opts)

    # Chisel options
    args.add("--target-dir", output.path)
    args.add("--split-verilog")

    ctx.actions.run(
        arguments = [args],
        executable = ctx.executable.generator,
        inputs = [ctx.executable.generator],
        outputs = [output],
        mnemonic = "ChiselVerilog",
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(files = depset([output])),
    ]

chisel_verilog = rule(
    implementation = _chisel_verilog_impl,
    attrs = {
        "generator": attr.label(
            cfg = "exec",
            executable = True,
            mandatory = True,
        ),
        "app_opts": attr.string_list(default = []),
        "firtool_opts": attr.string_list(default = []),
    },
)
