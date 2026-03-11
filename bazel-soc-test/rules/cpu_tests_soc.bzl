def define_soc_cpu_tests(test_srcs):
    image_targets = []
    run_targets = []

    for src in sorted(test_srcs):
        base = src.split("/")[-1]
        name = base[:-2]
        image_target = name + "_image"

        native.genrule(
            name = image_target,
            srcs = [
                src,
                ":common_inputs",
            ],
            tools = ["//scripts:build_cpu_test"],
            outs = [
                name + ".elf",
                name + ".bin",
                name + ".soc.bin",
                name + ".hex",
                name + ".mem",
                name + ".txt",
            ],
            cmd = "$(location //scripts:build_cpu_test) --src $(location {src}) --name {name} --out_dir $(@D)".format(
                src = src,
                name = name,
            ),
        )

        native.sh_test(
            name = name + "_run",
            srcs = ["//scripts:run_cpu_test.sh"],
            data = [
                ":sim_top",
                ":" + image_target,
                ":" + name + ".soc.bin",
            ],
            args = [
                "$(location :sim_top)",
                "$(location :{name}.soc.bin)".format(name = name),
            ],
            timeout = "short",
            tags = ["manual"],
        )

        image_targets.append(":" + image_target)
        run_targets.append(":" + name + "_run")

    native.filegroup(
        name = "cpu_tests_images",
        srcs = image_targets,
    )

    native.test_suite(
        name = "cpu_tests_suite",
        tests = run_targets,
    )
