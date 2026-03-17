# Bazel 零基础入门教程（结合 system0 项目，含文件与行号）

> 面向完全新手：你可以把这份文档当作“第一次接触 Bazel 的实操手册”。
> 教程目标不是背概念，而是跑通本仓库的真实构建链路，并能看懂关键 `MODULE.bazel` / `BUILD` / `*.bzl` 文件。

---

## 0. 先知道你要学什么

你会学会两件事：

1. Bazel 的最小必备概念（workspace、package、target、rule、macro、test）。
2. 在 `system0` 里把完整链路跑通：
   `Chisel/Scala -> Verilog -> Verilator 仿真器 -> cpu-tests`。

这条链路在仓库中的分层是明确写出来的：
- CL3 主线：`bazel-go`、`bazel-bin`、`bazel-test`（`Makefile:136`, `Makefile:156`, `Makefile:170`）
- SoC 进阶线：`bazel-soc-go`、`bazel-soc-bin`、`bazel-soc-test`（`Makefile:196`, `Makefile:253`, `Makefile:268`）

---

## 1. 这不是“一个 Bazel 工作区”，而是“多个子工作区”

很多新手会默认“仓库根目录只有一个 Bazel workspace”。这个项目不是这样。

`README` 直接列出了多个 Bazel 目录：
- `bazel-go/`
- `bazel-bin/`
- `bazel-test/`
- `bazel-soc-go/`
- `bazel-soc-bin/`
- `bazel-soc-test/`

每个目录都有自己的 `MODULE.bazel` 或 `BUILD`，而 `Makefile` 通过 `cd` 进入对应目录后再执行 Bazel：
- `cd bazel-go && ... bazel build //:cl3-verilog`（`Makefile:150`）
- `cd bazel-bin && ... bazel build //:top_bin`（`Makefile:164`）
- `cd bazel-test && ... bazel test //:cpu_tests_suite`（`Makefile:188`）

所以同样写 `//:xxx`，在不同目录中是不同目标。这一点非常关键。

---

## 2. 第一次上手前，先准备环境

### 2.1 进入开发环境

```bash
nix develop
```

这是项目官方 quick start 的第一步（`README.md:13`）。

### 2.2 为什么必须 `nix develop`

因为它一次性给你准备了 Bazel 与构建依赖：
- Bazel：`bazel_7`（`flake.nix:67`）
- Java/Scala：`jdk21`、`scala_3`（`flake.nix:70`, `flake.nix:71`）
- Verilator：`flake.nix:77`
- RISC-V 交叉编译工具链：`flake.nix:88`, `flake.nix:89`

并且设置了 Bazel 需要的环境变量：
- `JAVA_HOME`、`BAZEL_JAVA_HOME`（`flake.nix:99`, `flake.nix:100`）
- `CHISEL_FIRTOOL_PATH`、`CHISEL_FIRTOOL_PATH_SOC`（`flake.nix:101`, `flake.nix:102`）
- `RISCV_PREFIX`、`HEXDUMP_BIN`（`flake.nix:104`, `flake.nix:105`）

如果你跳过 Nix，后面大概率会遇到“找不到工具链”的错误。

---

## 3. Bazel 新手最小词汇表

### 3.1 `MODULE.bazel` 是“依赖与模块配置”

在 `bazel-go/MODULE.bazel` 里，你可以看到：
- 声明模块名：`module(name = "bazel-go")`（`bazel-go/MODULE.bazel:3` 到 `bazel-go/MODULE.bazel:5`）
- 声明 Bazel 依赖：`rules_jvm_external`、`rules_scala`、`bazel_skylib`（`bazel-go/MODULE.bazel:8` 到 `bazel-go/MODULE.bazel:10`）
- 配置 Scala 版本（`bazel-go/MODULE.bazel:13` 到 `bazel-go/MODULE.bazel:15`）
- 配置 Maven 安装与 lock 文件（`bazel-go/MODULE.bazel:47` 到 `bazel-go/MODULE.bazel:54`）

新手理解：`MODULE.bazel` 就是“这个工作区依赖哪些外部规则/库，以及怎么锁定版本”。

### 3.2 `BUILD` 是“目标定义”

比如 `bazel-go/BUILD`：
- 加载宏：`load("//rules:rules.bzl", "gen_rtl_target")`（`bazel-go/BUILD:1`）
- 定义目标：`gen_rtl_target(name = "cl3", ...)`（`bazel-go/BUILD:4` 到 `bazel-go/BUILD:13`）

`bazel-bin/BUILD`：
- 定义输入文件组 `filegroup`（`bazel-bin/BUILD:3`, `bazel-bin/BUILD:11`, `bazel-bin/BUILD:21`）
- 定义可执行构建目标 `genrule(name = "top_bin", ...)`（`bazel-bin/BUILD:26` 到 `bazel-bin/BUILD:73`）

新手理解：`BUILD` 负责告诉 Bazel“有哪些目标、每个目标依赖什么、怎样产出文件”。

### 3.3 target 标签怎么读

`//:cl3-verilog` 的意思是：
- `//`：当前工作区根 package
- `cl3-verilog`：目标名字

在本仓库中，`Makefile` 先 `cd bazel-go` 再执行，所以 `//:cl3-verilog` 实际是 `bazel-go/BUILD` 里生成的目标（`Makefile:150`, `bazel-go/rules/rules.bzl:34`）。

### 3.4 rule 与 macro 的区别

- `rule`：底层规则，直接描述 action。
  例如 `chisel_verilog = rule(...)`（`bazel-go/rules/generate.bzl:31`）。
- `macro`：Starlark 函数，用来拼装多个目标。
  例如 `gen_rtl_target(...)`（`bazel-go/rules/rules.bzl:6`）。

`gen_rtl_target` 宏先定义 `scala_binary`（`bazel-go/rules/rules.bzl:19`），再定义 `chisel_verilog`（`bazel-go/rules/rules.bzl:33`）。

### 3.5 `srcs` / `deps` / `tools` / `outs`

你在这个项目里会频繁见到这些属性：
- `srcs`：输入源文件（如 `bazel-go/BUILD:7`）
- `deps`：编译依赖（如 `bazel-go/BUILD:9`，`bazel-go/rules/rules.bzl:24`）
- `tools`：构建时工具（如 `bazel-test/rules/cpu_tests.bzl:16`）
- `outs`：输出产物（如 `bazel-test/rules/cpu_tests.bzl:17` 到 `bazel-test/rules/cpu_tests.bzl:23`）

### 3.6 `genrule` 是“壳命令打包器”

`bazel-bin/BUILD` 的 `top_bin` 本质是调用 `verilator`，再复制产物到 `$@`（`bazel-bin/BUILD:50` 到 `bazel-bin/BUILD:71`）。

新手建议：先把 `genrule` 看成“可缓存、可追踪输入输出的 shell 脚本目标”。

### 3.7 Bazel 里的测试目标

`bazel-test/rules/cpu_tests.bzl` 中：
- 每个 C 测试会生成一个 `sh_test`（`bazel-test/rules/cpu_tests.bzl:30`）
- 最后聚合成 `test_suite`（`bazel-test/rules/cpu_tests.bzl:56`）

所以你可以跑单测（如 `//:add_run`，见 `Makefile:185`），也可以跑测试集（`//:cpu_tests_suite`，见 `Makefile:188`）。

---

## 4. 跑通第一条链路（CL3）

下面这部分是新手最重要的“第一次成功”路径。

### Step 1: 初始化依赖（首次）

```bash
make init-go
```

这条命令背后做了两件事：

1. 先做 `setup-go`，把 CL3 源码和资源目录软链接到 `bazel-go`（`Makefile:138` 到 `Makefile:140`）。
2. 在 `bazel-go` 里执行 `bazel run @maven//:pin` 生成/更新 Maven lock（`Makefile:145`）。

> 新手提示：`@maven//:pin` 来自 `MODULE.bazel` 里的 `maven.install(...)`（`bazel-go/MODULE.bazel:46` 到 `bazel-go/MODULE.bazel:58`）。

### Step 2: 生成 CL3 Verilog

```bash
make build-go
```

核心动作：
- `cd bazel-go && bazel build //:cl3-verilog`（`Makefile:150`）

这个目标来自宏 `gen_rtl_target(name = "cl3", ...)`，它会额外生成 `name + "-verilog"` 目标（`bazel-go/rules/rules.bzl:34`）。

底层如何生成：
- `chisel_verilog` rule 声明输出目录（`bazel-go/rules/generate.bzl:5`）
- 加上 `--target-dir`、`--split-verilog` 参数（`bazel-go/rules/generate.bzl:13`, `bazel-go/rules/generate.bzl:14`）
- 调用 generator 可执行程序（`bazel-go/rules/generate.bzl:18`）

### Step 3: 生成 Verilator 仿真器

```bash
make build-bin
```

核心动作分两段：

1. `setup-bin` 准备输入软链接（`Makefile:158`）：
   - `rtl -> ../bazel-go/bazel-bin/cl3-verilog`（`Makefile:159`）
   - `soc -> ../CL3/soc`（`Makefile:160`）
   - `cc -> ../CL3/cl3/src/cc`（`Makefile:161`）

2. 构建 `top_bin`（`Makefile:164`），其定义在 `bazel-bin/BUILD`：
   - 输入 filegroup：`sv_inputs`、`cc_srcs`、`cc_hdrs`（`bazel-bin/BUILD:3`, `bazel-bin/BUILD:11`, `bazel-bin/BUILD:21`）
   - `genrule(name = "top_bin")`（`bazel-bin/BUILD:26`）
   - 调用 `verilator`（`bazel-bin/BUILD:50`）
   - 输出 `top`（`bazel-bin/BUILD:33`, `bazel-bin/BUILD:71`）

### Step 4: 构建测试镜像

```bash
make build-test
```

先执行 `setup-test`（`Makefile:172`）：
- 检查 CL3 仿真模式必须是 `DPI-C`（`Makefile:126` 到 `Makefile:133`）
- 检查测试资源存在（`Makefile:100` 到 `Makefile:124`）
- 链接 `tests/include/common/utils` 到 `bazel-test`（`Makefile:173` 到 `Makefile:177`）
- 链接 `sim/top` 到 `bazel-bin` 产物（`Makefile:178`）

然后执行：
- `cd bazel-test && bazel build //:cpu_tests_images`（`Makefile:181`）

这个目标是由 `define_cpu_tests` 宏自动聚合出来的（`bazel-test/rules/cpu_tests.bzl:51` 到 `bazel-test/rules/cpu_tests.bzl:54`）。

### Step 5: 运行测试

运行一个代表性测试：

```bash
make test-run-add
```

对应：
- `cd bazel-test && bazel test //:add_run`（`Makefile:185`）

运行全部测试：

```bash
make test-run-all
```

对应：
- `cd bazel-test && bazel test //:cpu_tests_suite`（`Makefile:188`）

`sh_test` 最终执行的脚本是 `run_cpu_test.sh`，调用方式：
- `"$SIM_BIN" --diff --ref "$REF_SO" --image "$IMAGE_BIN"`（`bazel-test/scripts/run_cpu_test.sh:13`）

---

## 5. 新手最该读懂的 4 个文件

### 5.1 `bazel-go/MODULE.bazel`：依赖与版本锁

重点看三段：

1. Bazel 规则依赖声明（`bazel-go/MODULE.bazel:8` 到 `bazel-go/MODULE.bazel:10`）
2. Scala 版本配置（`bazel-go/MODULE.bazel:13` 到 `bazel-go/MODULE.bazel:15`）
3. Maven install + lock_file（`bazel-go/MODULE.bazel:47` 到 `bazel-go/MODULE.bazel:54`）

你可以把它理解为“Bazel 生态里的 `package manager + lock` 入口”。

### 5.2 `bazel-go/rules/rules.bzl`：宏把复杂目标封装成一个入口

`gen_rtl_target` 做了两件新手通常会手写很久的事：

1. 定义 `scala_binary`：把 Chisel 代码编译成可执行生成器（`bazel-go/rules/rules.bzl:19` 到 `bazel-go/rules/rules.bzl:30`）
2. 定义 `chisel_verilog`：运行生成器并导出 Verilog（`bazel-go/rules/rules.bzl:33` 到 `bazel-go/rules/rules.bzl:42`）

这就是“宏”的价值：减少重复、统一参数。

### 5.3 `bazel-bin/BUILD`：典型 `genrule` 工程用法

你可以把这个文件看成“把 RTL 和 C++ testbench 交给 Verilator 的完整配方”：

- `filegroup` 聚合输入（`bazel-bin/BUILD:3` 到 `bazel-bin/BUILD:24`）
- `genrule` 用 shell 命令组织构建（`bazel-bin/BUILD:26` 到 `bazel-bin/BUILD:73`）
- `$(locations :cc_srcs)` 取工具输入路径（`bazel-bin/BUILD:46`）
- 产物复制到 `$@` 作为 Bazel 输出（`bazel-bin/BUILD:71`）

### 5.4 `bazel-test/rules/cpu_tests.bzl`：批量生成测试目标

这个宏对 `tests/*.c` 做循环（`bazel-test/rules/cpu_tests.bzl:5`）：

1. 先 `genrule` 生成 `.elf/.bin/.hex/.mem/.txt`（`bazel-test/rules/cpu_tests.bzl:10` 到 `bazel-test/rules/cpu_tests.bzl:28`）
2. 再 `sh_test` 运行仿真（`bazel-test/rules/cpu_tests.bzl:30` 到 `bazel-test/rules/cpu_tests.bzl:46`）
3. 最后输出聚合目标 `cpu_tests_images` 和 `cpu_tests_suite`（`bazel-test/rules/cpu_tests.bzl:51` 到 `bazel-test/rules/cpu_tests.bzl:58`）

---

## 6. 常见错误与定位方法

### 6.1 “CL3 test-run requires DPI-C mode”

来源：`check-cl3-dpic-mode`（`Makefile:126` 到 `Makefile:133`）。

这不是 Bazel 本身报错，而是 Make 预检失败。按提示修改 `CL3Config.scala`。

### 6.2 “missing tests/...”

来源：`check-test-assets`（`Makefile:100` 到 `Makefile:124`）。

说明测试资源目录/文件缺失，先修复测试资产再跑 Bazel。

### 6.3 “No RISC-V GCC toolchain found in PATH”

来源：`bazel-test/scripts/build_cpu_test.sh:49`。
脚本会优先使用 `RISCV_PREFIX`（`bazel-test/scripts/build_cpu_test.sh:38`），再自动探测若干前缀（`bazel-test/scripts/build_cpu_test.sh:40` 到 `bazel-test/scripts/build_cpu_test.sh:47`）。

### 6.4 “hexdump tool not found”

来源：`bazel-test/scripts/build_cpu_test.sh:63` 到 `bazel-test/scripts/build_cpu_test.sh:67`。
`flake.nix` 已导出 `HEXDUMP_BIN`（`flake.nix:105`），所以优先确认你是否在 `nix develop` 环境内。

### 6.5 SoC 线专属缺失问题

常见预检点都写在 `Makefile`：
- `SOC_GO_WS` 缺失（`Makefile:197` 到 `Makefile:202`）
- ysyxSoC 子模块未初始化完整（`Makefile:211` 到 `Makefile:227`）
- 缺 `maven_install.json`（`Makefile:229` 到 `Makefile:233`）
- 缺 CPU wrapper（`Makefile:237` 到 `Makefile:242`）

---

## 7. SoC 进阶线

如果你先跑通 CL3 主线，再看 SoC 会更容易：

1. `bazel-soc-go`：生成 `ysyxSoCFull.v`（`bazel-soc-go/BUILD:40` 到 `bazel-soc-go/BUILD:45`）
2. `setup-soc-int`：把 CL3 Verilog、SoC Verilog、wrapper、perip 汇总到 `soc-integration`（`Makefile:245` 到 `Makefile:251`）
3. `bazel-soc-bin`：编译 `soc_top`（`bazel-soc-bin/BUILD:24` 到 `bazel-soc-bin/BUILD:32`，`bazel-soc-bin/BUILD:44` 到 `bazel-soc-bin/BUILD:65`）
4. `bazel-soc-test`：构建 `.soc.bin` 并运行（`bazel-soc-test/rules/cpu_tests_soc.bzl:20`, `bazel-soc-test/rules/cpu_tests_soc.bzl:31`）

---

## 8. 命令与目标对照表

| 你执行的命令 | 实际 Bazel 目标 | 证据 |
|---|---|---|
| `make init-go` | `@maven//:pin` | `Makefile:145` |
| `make build-go` | `//:cl3-verilog`（在 `bazel-go`） | `Makefile:150` |
| `make build-bin` | `//:top_bin`（在 `bazel-bin`） | `Makefile:164` |
| `make build-test` | `//:cpu_tests_images`（在 `bazel-test`） | `Makefile:181` |
| `make test-run-add` | `//:add_run`（在 `bazel-test`） | `Makefile:185` |
| `make test-run-all` | `//:cpu_tests_suite`（在 `bazel-test`） | `Makefile:188` |
| `make build-soc-bin` | `$(SOC_BIN_TARGET)`（默认 `//:soc_top_bin`） | `Makefile:21`, `Makefile:266` |
